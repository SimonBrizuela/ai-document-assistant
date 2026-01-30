--[[
	EventsManager - Sistema de eventos del servidor
	
	Gestiona RemoteEvents y RemoteFunctions con validación,
	rate limiting y manejo de errores.
	
	Autor: 4GP
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventsManager = {}
EventsManager.__index = EventsManager

-- Configuración
local CONFIG = {
	RateLimitWindow = 1, -- segundos
	MaxRequestsPerWindow = 10,
	EnableLogging = true
}

-- Storage
local registeredEvents = {}
local rateLimitData = {}
local eventFolder

-- Inicializar carpeta de eventos
local function initializeEventFolder()
	eventFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not eventFolder then
		eventFolder = Instance.new("Folder")
		eventFolder.Name = "RemoteEvents"
		eventFolder.Parent = ReplicatedStorage
	end
end

-- Rate limiting
local function checkRateLimit(player, eventName)
	local key = player.UserId .. "_" .. eventName
	local currentTime = os.clock()
	
	if not rateLimitData[key] then
		rateLimitData[key] = {
			LastReset = currentTime,
			RequestCount = 0
		}
	end
	
	local data = rateLimitData[key]
	
	-- Reset si pasó la ventana
	if currentTime - data.LastReset >= CONFIG.RateLimitWindow then
		data.LastReset = currentTime
		data.RequestCount = 0
	end
	
	data.RequestCount = data.RequestCount + 1
	
	if data.RequestCount > CONFIG.MaxRequestsPerWindow then
		return false, "Rate limit excedido"
	end
	
	return true
end

-- Log de eventos
local function logEvent(eventType, eventName, player, success, message)
	if not CONFIG.EnableLogging then return end
	
	local timestamp = os.date("%H:%M:%S")
	local status = success and "✓" or "✗"
	local playerName = player and player.Name or "Server"
	
	print(("[%s] %s [%s] %s - %s - %s"):format(
		timestamp,
		status,
		eventType,
		eventName,
		playerName,
		message or "OK"
	))
end

-- Crear RemoteEvent
function EventsManager:CreateEvent(eventName, callback, options)
	if registeredEvents[eventName] then
		warn(("[EventsManager] Evento ya existe: %s"):format(eventName))
		return registeredEvents[eventName].Remote
	end
	
	options = options or {}
	
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = eventName
	remoteEvent.Parent = eventFolder
	
	registeredEvents[eventName] = {
		Type = "Event",
		Remote = remoteEvent,
		Callback = callback,
		RequireRateLimit = options.RequireRateLimit ~= false,
		ValidatePlayer = options.ValidatePlayer ~= false
	}
	
	-- Conectar callback
	remoteEvent.OnServerEvent:Connect(function(player, ...)
		local eventData = registeredEvents[eventName]
		
		-- Validar jugador
		if eventData.ValidatePlayer then
			if not player or not player:IsA("Player") or not player.Parent then
				logEvent("Event", eventName, player, false, "Jugador inválido")
				return
			end
		end
		
		-- Rate limiting
		if eventData.RequireRateLimit then
			local canProceed, message = checkRateLimit(player, eventName)
			if not canProceed then
				logEvent("Event", eventName, player, false, message)
				return
			end
		end
		
		-- Ejecutar callback con manejo de errores
		local success, result = pcall(eventData.Callback, player, ...)
		
		if not success then
			logEvent("Event", eventName, player, false, "Error: " .. tostring(result))
			warn(("[EventsManager] Error en evento %s: %s"):format(eventName, tostring(result)))
		else
			logEvent("Event", eventName, player, true)
		end
	end)
	
	print(("[EventsManager] Evento creado: %s"):format(eventName))
	return remoteEvent
end

-- Crear RemoteFunction
function EventsManager:CreateFunction(functionName, callback, options)
	if registeredEvents[functionName] then
		warn(("[EventsManager] Función ya existe: %s"):format(functionName))
		return registeredEvents[functionName].Remote
	end
	
	options = options or {}
	
	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = functionName
	remoteFunction.Parent = eventFolder
	
	registeredEvents[functionName] = {
		Type = "Function",
		Remote = remoteFunction,
		Callback = callback,
		RequireRateLimit = options.RequireRateLimit ~= false,
		ValidatePlayer = options.ValidatePlayer ~= false,
		Timeout = options.Timeout or 5
	}
	
	-- Conectar callback
	remoteFunction.OnServerInvoke = function(player, ...)
		local eventData = registeredEvents[functionName]
		
		-- Validar jugador
		if eventData.ValidatePlayer then
			if not player or not player:IsA("Player") or not player.Parent then
				logEvent("Function", functionName, player, false, "Jugador inválido")
				return { Success = false, Message = "Jugador inválido" }
			end
		end
		
		-- Rate limiting
		if eventData.RequireRateLimit then
			local canProceed, message = checkRateLimit(player, functionName)
			if not canProceed then
				logEvent("Function", functionName, player, false, message)
				return { Success = false, Message = message }
			end
		end
		
		-- Ejecutar callback con timeout
		local result
		local completed = false
		
		task.spawn(function()
			local success, callbackResult = pcall(eventData.Callback, player, ...)
			
			if success then
				result = callbackResult
				logEvent("Function", functionName, player, true)
			else
				result = { Success = false, Message = "Error interno" }
				logEvent("Function", functionName, player, false, "Error: " .. tostring(callbackResult))
				warn(("[EventsManager] Error en función %s: %s"):format(functionName, tostring(callbackResult)))
			end
			
			completed = true
		end)
		
		-- Esperar con timeout
		local startTime = os.clock()
		while not completed and (os.clock() - startTime) < eventData.Timeout do
			task.wait()
		end
		
		if not completed then
			logEvent("Function", functionName, player, false, "Timeout")
			return { Success = false, Message = "Timeout" }
		end
		
		return result
	end
	
	print(("[EventsManager] Función creada: %s"):format(functionName))
	return remoteFunction
end

-- Enviar evento a jugador
function EventsManager:FireClient(eventName, player, ...)
	local eventData = registeredEvents[eventName]
	
	if not eventData then
		warn(("[EventsManager] Evento no existe: %s"):format(eventName))
		return false
	end
	
	if eventData.Type ~= "Event" then
		warn(("[EventsManager] %s no es un RemoteEvent"):format(eventName))
		return false
	end
	
	eventData.Remote:FireClient(player, ...)
	return true
end

-- Enviar evento a todos los jugadores
function EventsManager:FireAllClients(eventName, ...)
	local eventData = registeredEvents[eventName]
	
	if not eventData then
		warn(("[EventsManager] Evento no existe: %s"):format(eventName))
		return false
	end
	
	if eventData.Type ~= "Event" then
		warn(("[EventsManager] %s no es un RemoteEvent"):format(eventName))
		return false
	end
	
	eventData.Remote:FireAllClients(...)
	return true
end

-- Enviar evento a jugadores excepto uno
function EventsManager:FireAllClientsExcept(eventName, excludePlayer, ...)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excludePlayer then
			self:FireClient(eventName, player, ...)
		end
	end
end

-- Obtener remote
function EventsManager:GetRemote(name)
	local eventData = registeredEvents[name]
	return eventData and eventData.Remote
end

-- Verificar si existe
function EventsManager:Exists(name)
	return registeredEvents[name] ~= nil
end

-- Remover evento (con cuidado)
function EventsManager:RemoveEvent(eventName)
	local eventData = registeredEvents[eventName]
	
	if eventData then
		eventData.Remote:Destroy()
		registeredEvents[eventName] = nil
		print(("[EventsManager] Evento removido: %s"):format(eventName))
		return true
	end
	
	return false
end

-- Limpiar rate limits expirados
function EventsManager:CleanupRateLimits()
	local currentTime = os.clock()
	
	for key, data in pairs(rateLimitData) do
		if currentTime - data.LastReset >= CONFIG.RateLimitWindow * 2 then
			rateLimitData[key] = nil
		end
	end
end

-- Obtener estadísticas
function EventsManager:GetStats()
	local stats = {
		TotalEvents = 0,
		TotalFunctions = 0,
		Events = {},
		Functions = {}
	}
	
	for name, data in pairs(registeredEvents) do
		if data.Type == "Event" then
			stats.TotalEvents = stats.TotalEvents + 1
			table.insert(stats.Events, name)
		else
			stats.TotalFunctions = stats.TotalFunctions + 1
			table.insert(stats.Functions, name)
		end
	end
	
	return stats
end

-- Inicializar sistema
function EventsManager:Initialize()
	initializeEventFolder()
	
	-- Cleanup periódico
	task.spawn(function()
		while task.wait(60) do
			self:CleanupRateLimits()
		end
	end)
	
	print("[EventsManager] Sistema inicializado")
end

return EventsManager
