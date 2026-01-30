--[[
	DataManager - Sistema de persistencia de datos
	
	Maneja el guardado y carga de datos del jugador usando DataStores.
	Incluye autosave, manejo de errores y cache en memoria.
	
	Autor: 4GP
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}
DataManager.__index = DataManager

-- Configuración
local CONFIG = {
	DataStoreName = "PlayerData_v1",
	AutoSaveInterval = 180, -- 3 minutos
	MaxRetries = 3,
	RetryDelay = 1
}

-- Template de datos por defecto
local DEFAULT_DATA = {
	Coins = 0,
	Level = 1,
	Experience = 0,
	Inventory = {},
	Stats = {
		Health = 100,
		Stamina = 100,
		Strength = 10,
		Defense = 5
	},
	Settings = {
		MusicEnabled = true,
		SFXEnabled = true
	},
	LastLogin = 0
}

-- Cache de datos en memoria
local playerDataCache = {}
local dataStore = DataStoreService:GetDataStore(CONFIG.DataStoreName)

-- Función auxiliar para copiar tablas profundamente
local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Función para mergear datos guardados con el template
local function mergeData(savedData, template)
	local merged = deepCopy(template)
	
	if not savedData then
		return merged
	end
	
	for key, value in pairs(savedData) do
		if type(value) == "table" and type(merged[key]) == "table" then
			merged[key] = mergeData(value, merged[key])
		else
			merged[key] = value
		end
	end
	
	return merged
end

-- Cargar datos con reintentos
function DataManager:LoadData(player)
	local userId = player.UserId
	local key = "Player_" .. userId
	
	for attempt = 1, CONFIG.MaxRetries do
		local success, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		
		if success then
			local data = mergeData(result, DEFAULT_DATA)
			data.LastLogin = os.time()
			playerDataCache[userId] = data
			
			print(("[DataManager] Datos cargados para %s (Intento %d)"):format(player.Name, attempt))
			return data
		else
			warn(("[DataManager] Error cargando datos para %s (Intento %d): %s"):format(player.Name, attempt, tostring(result)))
			
			if attempt < CONFIG.MaxRetries then
				task.wait(CONFIG.RetryDelay * attempt)
			end
		end
	end
	
	-- Si falla, usar datos por defecto
	warn(("[DataManager] Usando datos por defecto para %s"):format(player.Name))
	playerDataCache[userId] = deepCopy(DEFAULT_DATA)
	return playerDataCache[userId]
end

-- Guardar datos con reintentos
function DataManager:SaveData(player)
	local userId = player.UserId
	local data = playerDataCache[userId]
	
	if not data then
		warn(("[DataManager] No hay datos en cache para %s"):format(player.Name))
		return false
	end
	
	local key = "Player_" .. userId
	
	for attempt = 1, CONFIG.MaxRetries do
		local success, error = pcall(function()
			dataStore:SetAsync(key, data)
		end)
		
		if success then
			print(("[DataManager] Datos guardados para %s (Intento %d)"):format(player.Name, attempt))
			return true
		else
			warn(("[DataManager] Error guardando datos para %s (Intento %d): %s"):format(player.Name, attempt, tostring(error)))
			
			if attempt < CONFIG.MaxRetries then
				task.wait(CONFIG.RetryDelay * attempt)
			end
		end
	end
	
	return false
end

-- Obtener datos del cache
function DataManager:GetData(player)
	return playerDataCache[player.UserId]
end

-- Actualizar un valor específico
function DataManager:UpdateValue(player, path, value)
	local data = playerDataCache[player.UserId]
	if not data then return false end
	
	local keys = string.split(path, ".")
	local current = data
	
	for i = 1, #keys - 1 do
		if not current[keys[i]] then
			current[keys[i]] = {}
		end
		current = current[keys[i]]
	end
	
	current[keys[#keys]] = value
	return true
end

-- Incrementar un valor numérico
function DataManager:IncrementValue(player, path, amount)
	local data = playerDataCache[player.UserId]
	if not data then return false end
	
	local keys = string.split(path, ".")
	local current = data
	
	for i = 1, #keys - 1 do
		if not current[keys[i]] then
			return false
		end
		current = current[keys[i]]
	end
	
	local key = keys[#keys]
	if type(current[key]) ~= "number" then
		return false
	end
	
	current[key] = current[key] + amount
	return true
end

-- Inicializar sistema
function DataManager:Initialize()
	-- Manejar jugadores que se unen
	Players.PlayerAdded:Connect(function(player)
		self:LoadData(player)
	end)
	
	-- Manejar jugadores que salen
	Players.PlayerRemoving:Connect(function(player)
		self:SaveData(player)
		playerDataCache[player.UserId] = nil
	end)
	
	-- Autosave periódico
	task.spawn(function()
		while task.wait(CONFIG.AutoSaveInterval) do
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					self:SaveData(player)
				end)
			end
			print("[DataManager] Autosave completado")
		end
	end)
	
	-- Guardar todos los datos antes de cerrar el servidor
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:SaveData(player)
		end
		task.wait(3)
	end)
	
	print("[DataManager] Sistema inicializado")
end

return DataManager
