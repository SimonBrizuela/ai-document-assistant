--[[
	AchievementManager - Sistema de logros
	
	Trackea progreso de jugadores y desbloquea achievements. Se integra con
	BadgeService de Roblox y guarda todo en DataStore. Incluye sistema de recompensas.
	
	Features:
	- Tracking automático de stats
	- Badges de Roblox
	- 3 tipos: Counter, Threshold, Boolean
	- Se guarda en DataStore
	- Recompensas automáticas (coins, XP, items)
	- Events para actualizar UI en tiempo real
	
	Por: 4GP
	v2.0.0
]]

local AchievementManager = {}
AchievementManager.__index = AchievementManager

-- Servicios
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- DataStore
local achievementStore = DataStoreService:GetDataStore("PlayerAchievements_v2")

-- Estado del sistema
local playerProgress = {} -- [userId] = { achievementId = progress }
local playerUnlocked = {} -- [userId] = { achievementId = true }

-- Definición de achievements
local ACHIEVEMENTS = {
	FirstKill = {
		Id = "FirstKill",
		Name = "Primera Sangre",
		Description = "Derrota tu primer enemigo",
		Icon = "rbxassetid://123456789",
		BadgeId = nil, -- ID del badge de Roblox (opcional)
		Type = "Counter",
		Goal = 1,
		Stat = "EnemiesKilled",
		Rewards = {
			Coins = 100,
			XP = 50
		},
		Hidden = false
	},
	
	Slayer = {
		Id = "Slayer",
		Name = "Asesino",
		Description = "Derrota 100 enemigos",
		Icon = "rbxassetid://123456790",
		BadgeId = nil,
		Type = "Counter",
		Goal = 100,
		Stat = "EnemiesKilled",
		Rewards = {
			Coins = 1000,
			XP = 500,
			Item = "LegendarySword"
		},
		Hidden = false
	},
	
	Survivor = {
		Id = "Survivor",
		Name = "Superviviente",
		Description = "Completa 10 oleadas sin morir",
		Icon = "rbxassetid://123456791",
		BadgeId = nil,
		Type = "Counter",
		Goal = 10,
		Stat = "WavesSurvived",
		Rewards = {
			Coins = 2000,
			XP = 1000
		},
		Hidden = false
	},
	
	Collector = {
		Id = "Collector",
		Name = "Coleccionista",
		Description = "Colecciona 50 items únicos",
		Icon = "rbxassetid://123456792",
		BadgeId = nil,
		Type = "Counter",
		Goal = 50,
		Stat = "UniqueItemsCollected",
		Rewards = {
			Coins = 1500,
			XP = 750
		},
		Hidden = false
	},
	
	Wealthy = {
		Id = "Wealthy",
		Name = "Rico",
		Description = "Acumula 10,000 monedas",
		Icon = "rbxassetid://123456793",
		BadgeId = nil,
		Type = "Threshold",
		Goal = 10000,
		Stat = "TotalCoins",
		Rewards = {
			XP = 2000
		},
		Hidden = false
	},
	
	QuestMaster = {
		Id = "QuestMaster",
		Name = "Maestro de Misiones",
		Description = "Completa 25 misiones",
		Icon = "rbxassetid://123456794",
		BadgeId = nil,
		Type = "Counter",
		Goal = 25,
		Stat = "QuestsCompleted",
		Rewards = {
			Coins = 5000,
			XP = 2500,
			Title = "Quest Master"
		},
		Hidden = false
	},
	
	LevelTen = {
		Id = "LevelTen",
		Name = "Nivel 10",
		Description = "Alcanza el nivel 10",
		Icon = "rbxassetid://123456795",
		BadgeId = nil,
		Type = "Threshold",
		Goal = 10,
		Stat = "Level",
		Rewards = {
			Coins = 500,
			Item = "SpecialArmor"
		},
		Hidden = false
	},
	
	SecretExplorer = {
		Id = "SecretExplorer",
		Name = "???",
		Description = "Encuentra el área secreta",
		Icon = "rbxassetid://123456796",
		BadgeId = nil,
		Type = "Boolean",
		Stat = "FoundSecretArea",
		Rewards = {
			Coins = 10000,
			XP = 5000,
			Item = "MysticalAmulet"
		},
		Hidden = true -- No se muestra hasta desbloquearlo
	},
	
	SpeedRunner = {
		Id = "SpeedRunner",
		Name = "Corredor Veloz",
		Description = "Completa una oleada en menos de 2 minutos",
		Icon = "rbxassetid://123456797",
		BadgeId = nil,
		Type = "Boolean",
		Stat = "FastWaveCompleted",
		Rewards = {
			Coins = 3000,
			XP = 1500
		},
		Hidden = false
	},
	
	Perfectionist = {
		Id = "Perfectionist",
		Name = "Perfeccionista",
		Description = "Completa una oleada sin recibir daño",
		Icon = "rbxassetid://123456798",
		BadgeId = nil,
		Type = "Boolean",
		Stat = "NoDamageWave",
		Rewards = {
			Coins = 5000,
			XP = 2000,
			Title = "The Untouchable"
		},
		Hidden = false
	}
}

--[[ 
	Inicializa el sistema de achievements
]]
function AchievementManager:Initialize()
	-- Setup eventos
	self:SetupEvents()
	
	-- Conectar jugadores
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayerAchievements(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayerAchievements(player)
	end)
	
	-- Cargar jugadores existentes
	for _, player in ipairs(Players:GetPlayers()) do
		self:LoadPlayerAchievements(player)
	end
	
	print("[AchievementManager] Inicializado con", self:GetAchievementCount(), "achievements")
end

--[[ 
	Setup de eventos remotos
]]
function AchievementManager:SetupEvents()
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = ReplicatedStorage
	end
	
	-- Evento para notificar desbloqueo
	if not remoteEvents:FindFirstChild("AchievementUnlocked") then
		local event = Instance.new("RemoteEvent")
		event.Name = "AchievementUnlocked"
		event.Parent = remoteEvents
	end
	
	-- Evento para actualizar progreso
	if not remoteEvents:FindFirstChild("AchievementProgress") then
		local event = Instance.new("RemoteEvent")
		event.Name = "AchievementProgress"
		event.Parent = remoteEvents
	end
	
	-- Función remota para obtener achievements
	if not remoteEvents:FindFirstChild("GetAchievements") then
		local func = Instance.new("RemoteFunction")
		func.Name = "GetAchievements"
		func.OnServerInvoke = function(player)
			return self:GetPlayerAchievements(player)
		end
		func.Parent = remoteEvents
	end
end

--[[ 
	Carga los achievements de un jugador desde DataStore
	@param player Player
]]
function AchievementManager:LoadPlayerAchievements(player)
	local userId = player.UserId
	
	local success, data = pcall(function()
		return achievementStore:GetAsync("Player_" .. userId)
	end)
	
	if success and data then
		playerProgress[userId] = data.Progress or {}
		playerUnlocked[userId] = data.Unlocked or {}
		print(("[AchievementManager] Cargado progreso para %s"):format(player.Name))
	else
		-- Inicializar vacío
		playerProgress[userId] = {}
		playerUnlocked[userId] = {}
		print(("[AchievementManager] Nuevo jugador: %s"):format(player.Name))
	end
end

--[[ 
	Guarda los achievements de un jugador en DataStore
	@param player Player
]]
function AchievementManager:SavePlayerAchievements(player)
	local userId = player.UserId
	
	if not playerProgress[userId] then
		return
	end
	
	local data = {
		Progress = playerProgress[userId],
		Unlocked = playerUnlocked[userId],
		LastSaved = os.time()
	}
	
	local success, err = pcall(function()
		achievementStore:SetAsync("Player_" .. userId, data)
	end)
	
	if success then
		print(("[AchievementManager] Guardado progreso para %s"):format(player.Name))
	else
		warn(("[AchievementManager] Error guardando para %s: %s"):format(player.Name, tostring(err)))
	end
end

--[[ 
	Actualiza el progreso de un stat para un jugador
	@param player Player
	@param statName string - Nombre del stat
	@param value number - Nuevo valor del stat
]]
function AchievementManager:UpdateStat(player, statName, value)
	local userId = player.UserId
	
	if not playerProgress[userId] then
		warn("[AchievementManager] Jugador no inicializado:", player.Name)
		return
	end
	
	-- Buscar achievements que tracken este stat
	for achievementId, achievement in pairs(ACHIEVEMENTS) do
		if achievement.Stat == statName and not self:IsUnlocked(player, achievementId) then
			-- Actualizar progreso
			local oldProgress = playerProgress[userId][achievementId] or 0
			local newProgress = value
			
			-- Para counters, incrementar; para thresholds, reemplazar
			if achievement.Type == "Counter" then
				newProgress = math.max(oldProgress, value)
			elseif achievement.Type == "Threshold" then
				newProgress = value
			elseif achievement.Type == "Boolean" then
				newProgress = value and 1 or 0
			end
			
			playerProgress[userId][achievementId] = newProgress
			
			-- Notificar progreso si cambió
			if newProgress ~= oldProgress then
				self:NotifyProgress(player, achievementId, newProgress, achievement.Goal)
			end
			
			-- Check si se completó
			if self:CheckAchievementCompletion(achievement, newProgress) then
				self:UnlockAchievement(player, achievementId)
			end
		end
	end
end

--[[ 
	Incrementa un stat contador para un jugador
	@param player Player
	@param statName string - Nombre del stat
	@param amount number? - Cantidad a incrementar (default: 1)
]]
function AchievementManager:IncrementStat(player, statName, amount)
	local userId = player.UserId
	amount = amount or 1
	
	if not playerProgress[userId] then
		return
	end
	
	-- Buscar achievements que tracken este stat
	for achievementId, achievement in pairs(ACHIEVEMENTS) do
		if achievement.Stat == statName and achievement.Type == "Counter" then
			if not self:IsUnlocked(player, achievementId) then
				local currentProgress = playerProgress[userId][achievementId] or 0
				local newProgress = currentProgress + amount
				
				playerProgress[userId][achievementId] = newProgress
				
				-- Notificar progreso
				self:NotifyProgress(player, achievementId, newProgress, achievement.Goal)
				
				-- Check completado
				if self:CheckAchievementCompletion(achievement, newProgress) then
					self:UnlockAchievement(player, achievementId)
				end
			end
		end
	end
end

--[[ 
	Marca un achievement booleano como completado
	@param player Player
	@param statName string - Nombre del stat booleano
]]
function AchievementManager:TriggerBooleanStat(player, statName)
	self:UpdateStat(player, statName, true)
end

--[[ 
	Verifica si un achievement está completado
	@param achievement table - Datos del achievement
	@param progress number - Progreso actual
	@return boolean
]]
function AchievementManager:CheckAchievementCompletion(achievement, progress)
	if achievement.Type == "Boolean" then
		return progress == 1 or progress == true
	else
		return progress >= achievement.Goal
	end
end

--[[ 
	Desbloquea un achievement para un jugador
	@param player Player
	@param achievementId string - ID del achievement
]]
function AchievementManager:UnlockAchievement(player, achievementId)
	local userId = player.UserId
	local achievement = ACHIEVEMENTS[achievementId]
	
	if not achievement then
		warn("[AchievementManager] Achievement no existe:", achievementId)
		return
	end
	
	if self:IsUnlocked(player, achievementId) then
		return -- Ya está desbloqueado
	end
	
	-- Marcar como desbloqueado
	playerUnlocked[userId][achievementId] = true
	
	print(("[AchievementManager] %s desbloqueó '%s'"):format(player.Name, achievement.Name))
	
	-- Otorgar badge de Roblox si existe
	if achievement.BadgeId then
		self:AwardBadge(player, achievement.BadgeId)
	end
	
	-- Otorgar recompensas
	if achievement.Rewards then
		self:GiveRewards(player, achievement.Rewards)
	end
	
	-- Notificar al cliente
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEvents and remoteEvents:FindFirstChild("AchievementUnlocked") then
		remoteEvents.AchievementUnlocked:FireClient(player, achievement)
	end
	
	-- Guardar inmediatamente
	self:SavePlayerAchievements(player)
end

--[[ 
	Otorga un badge de Roblox a un jugador
	@param player Player
	@param badgeId number - ID del badge
]]
function AchievementManager:AwardBadge(player, badgeId)
	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)
	
	if success and not hasBadge then
		local awarded, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		
		if awarded then
			print(("[AchievementManager] Badge %d otorgado a %s"):format(badgeId, player.Name))
		else
			warn(("[AchievementManager] Error otorgando badge: %s"):format(tostring(err)))
		end
	end
end

--[[ 
	Otorga recompensas al jugador
	@param player Player
	@param rewards table - Tabla de recompensas
]]
function AchievementManager:GiveRewards(player, rewards)
	-- Aquí integrarías con tus otros sistemas (InventoryModule, DataManager, etc)
	
	if rewards.Coins then
		-- Ejemplo: player.leaderstats.Coins.Value += rewards.Coins
		print(("[AchievementManager] +%d coins para %s"):format(rewards.Coins, player.Name))
	end
	
	if rewards.XP then
		-- Ejemplo: XPSystem:AddXP(player, rewards.XP)
		print(("[AchievementManager] +%d XP para %s"):format(rewards.XP, player.Name))
	end
	
	if rewards.Item then
		-- Ejemplo: InventoryModule:AddItem(player, rewards.Item)
		print(("[AchievementManager] Item '%s' para %s"):format(rewards.Item, player.Name))
	end
	
	if rewards.Title then
		-- Ejemplo: TitleSystem:UnlockTitle(player, rewards.Title)
		print(("[AchievementManager] Título '%s' para %s"):format(rewards.Title, player.Name))
	end
end

--[[ 
	Verifica si un jugador ha desbloqueado un achievement
	@param player Player
	@param achievementId string
	@return boolean
]]
function AchievementManager:IsUnlocked(player, achievementId)
	local userId = player.UserId
	return playerUnlocked[userId] and playerUnlocked[userId][achievementId] == true
end

--[[ 
	Obtiene el progreso de un achievement
	@param player Player
	@param achievementId string
	@return number
]]
function AchievementManager:GetProgress(player, achievementId)
	local userId = player.UserId
	return (playerProgress[userId] and playerProgress[userId][achievementId]) or 0
end

--[[ 
	Notifica al cliente sobre progreso de achievement
	@param player Player
	@param achievementId string
	@param current number
	@param goal number
]]
function AchievementManager:NotifyProgress(player, achievementId, current, goal)
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEvents and remoteEvents:FindFirstChild("AchievementProgress") then
		remoteEvents.AchievementProgress:FireClient(player, achievementId, current, goal)
	end
end

--[[ 
	Obtiene todos los achievements del jugador con su progreso
	@param player Player
	@return table - Lista de achievements con progreso
]]
function AchievementManager:GetPlayerAchievements(player)
	local userId = player.UserId
	local result = {}
	
	for achievementId, achievement in pairs(ACHIEVEMENTS) do
		-- No incluir hidden achievements que no están desbloqueados
		if not achievement.Hidden or self:IsUnlocked(player, achievementId) then
			table.insert(result, {
				Id = achievement.Id,
				Name = achievement.Name,
				Description = achievement.Description,
				Icon = achievement.Icon,
				Type = achievement.Type,
				Goal = achievement.Goal,
				Progress = self:GetProgress(player, achievementId),
				Unlocked = self:IsUnlocked(player, achievementId),
				Rewards = achievement.Rewards
			})
		end
	end
	
	return result
end

--[[ 
	Obtiene el número total de achievements
	@return number
]]
function AchievementManager:GetAchievementCount()
	local count = 0
	for _ in pairs(ACHIEVEMENTS) do
		count = count + 1
	end
	return count
end

--[[ 
	Obtiene estadísticas de un jugador
	@param player Player
	@return table
]]
function AchievementManager:GetPlayerStats(player)
	local userId = player.UserId
	local totalAchievements = self:GetAchievementCount()
	local unlockedCount = 0
	
	if playerUnlocked[userId] then
		for _ in pairs(playerUnlocked[userId]) do
			unlockedCount = unlockedCount + 1
		end
	end
	
	return {
		TotalAchievements = totalAchievements,
		UnlockedCount = unlockedCount,
		CompletionPercent = math.floor((unlockedCount / totalAchievements) * 100)
	}
end

return AchievementManager
