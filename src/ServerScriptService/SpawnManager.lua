--[[
	SpawnManager - Sistema de oleadas de enemigos
	
	Spawnea enemigos con dificultad que escala según la oleada y cantidad de jugadores.
	Usa múltiples zonas de spawn y tiene sistema de boss cada X oleadas.
	
	Features:
	- Oleadas con dificultad que aumenta
	- Se balancea según jugadores en el server
	- Spawn zones con load balancing
	- Spawn rate que se acelera con oleadas altas
	- Boss cada 10 oleadas
	
	Por: 4GP
	v1.8.0
]]

local SpawnManager = {}
SpawnManager.__index = SpawnManager

-- Servicios
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Configuración
local CONFIG = {
	MaxEnemiesPerWave = 50,
	BaseSpawnInterval = 3,
	MinSpawnInterval = 0.8,
	WaveCooldown = 15,
	DifficultyScaling = 1.2,
	PlayerScaling = 0.5, -- +50% enemigos por cada jugador extra
}

-- Estado del sistema
local currentWave = 0
local isWaveActive = false
local activeEnemies = {}
local spawnZones = {}
local waveConfig = {}

-- Templates de enemigos
local ENEMY_TEMPLATES = {
	Zombie = {
		Health = 100,
		Damage = 10,
		Speed = 12,
		Reward = 50,
		Model = "ZombieModel", -- Nombre del modelo en ReplicatedStorage
		AIType = "Melee",
		SpawnWeight = 10
	},
	
	FastZombie = {
		Health = 60,
		Damage = 8,
		Speed = 20,
		Reward = 75,
		Model = "FastZombieModel",
		AIType = "Melee",
		SpawnWeight = 7
	},
	
	TankZombie = {
		Health = 300,
		Damage = 20,
		Speed = 8,
		Reward = 150,
		Model = "TankZombieModel",
		AIType = "Melee",
		SpawnWeight = 3
	},
	
	RangedEnemy = {
		Health = 80,
		Damage = 15,
		Speed = 10,
		Reward = 100,
		Model = "RangedEnemyModel",
		AIType = "Ranged",
		Range = 50,
		SpawnWeight = 5
	},
	
	Boss = {
		Health = 2000,
		Damage = 50,
		Speed = 15,
		Reward = 1000,
		Model = "BossModel",
		AIType = "Boss",
		SpawnWeight = 0 -- No se spawnea aleatoriamente
	}
}

-- Inicializa el sistema de spawns
function SpawnManager:Initialize()
	-- Buscar zonas de spawn en el workspace
	self:LoadSpawnZones()
	
	-- Setup eventos
	self:SetupEvents()
	
	print(("[SpawnManager] Inicializado con %d zonas de spawn"):format(#spawnZones))
end

-- Carga todas las zonas de spawn del mapa (deben tener tag "SpawnZone")
function SpawnManager:LoadSpawnZones()
	spawnZones = {}
	
	-- Buscar por tag
	local zones = CollectionService:GetTagged("SpawnZone")
	for _, zone in ipairs(zones) do
		if zone:IsA("BasePart") or zone:IsA("Model") then
			table.insert(spawnZones, {
				Instance = zone,
				Position = zone:IsA("Model") and zone:GetPivot().Position or zone.Position,
				Size = zone:IsA("Model") and zone:GetExtentsSize() or zone.Size,
				Active = true,
				SpawnCount = 0
			})
		end
	end
	
	-- Si no hay zonas, crear zona por defecto
	if #spawnZones == 0 then
		warn("[SpawnManager] No se encontraron zonas de spawn, usando zona por defecto")
		table.insert(spawnZones, {
			Position = Vector3.new(0, 5, 0),
			Size = Vector3.new(50, 1, 50),
			Active = true,
			SpawnCount = 0
		})
	end
end

--[[ 
	Setup de eventos remotos
]]
function SpawnManager:SetupEvents()
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = ReplicatedStorage
	end
	
	-- Evento para notificar inicio de oleada
	if not remoteEvents:FindFirstChild("WaveStarted") then
		local event = Instance.new("RemoteEvent")
		event.Name = "WaveStarted"
		event.Parent = remoteEvents
	end
	
	-- Evento para notificar fin de oleada
	if not remoteEvents:FindFirstChild("WaveCompleted") then
		local event = Instance.new("RemoteEvent")
		event.Name = "WaveCompleted"
		event.Parent = remoteEvents
	end
end

--[[ 
	Inicia una nueva oleada
	@param waveNumber number? - Número de oleada (auto-incrementa si es nil)
	@param customConfig table? - Configuración custom para la oleada
]]
function SpawnManager:StartWave(waveNumber, customConfig)
	if isWaveActive then
		warn("[SpawnManager] Ya hay una oleada activa")
		return false
	end
	
	currentWave = waveNumber or (currentWave + 1)
	isWaveActive = true
	
	-- Configurar oleada
	waveConfig = customConfig or self:GenerateWaveConfig(currentWave)
	
	print(("[SpawnManager] Iniciando oleada %d - %d enemigos"):format(currentWave, waveConfig.TotalEnemies))
	
	-- Notificar clientes
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEvents and remoteEvents:FindFirstChild("WaveStarted") then
		remoteEvents.WaveStarted:FireAllClients(currentWave, waveConfig)
	end
	
	-- Comenzar spawn
	task.spawn(function()
		self:SpawnWaveEnemies(waveConfig)
	end)
	
	return true
end

--[[ 
	Genera configuración para una oleada basada en el número
	@param waveNum number - Número de oleada
	@return table - Configuración de la oleada
]]
function SpawnManager:GenerateWaveConfig(waveNum)
	local playerCount = #game.Players:GetPlayers()
	local difficultyMult = math.pow(CONFIG.DifficultyScaling, waveNum - 1)
	local playerMult = 1 + ((playerCount - 1) * CONFIG.PlayerScaling)
	
	-- Calcular cantidad de enemigos
	local baseEnemies = 10 + (waveNum * 2)
	local totalEnemies = math.floor(baseEnemies * difficultyMult * playerMult)
	totalEnemies = math.min(totalEnemies, CONFIG.MaxEnemiesPerWave)
	
	-- Determinar tipos de enemigos según la oleada
	local enemyTypes = {"Zombie"}
	
	if waveNum >= 3 then
		table.insert(enemyTypes, "FastZombie")
	end
	
	if waveNum >= 5 then
		table.insert(enemyTypes, "TankZombie")
	end
	
	if waveNum >= 7 then
		table.insert(enemyTypes, "RangedEnemy")
	end
	
	-- Boss cada 10 oleadas
	local hasBoss = (waveNum % 10 == 0)
	
	-- Calcular intervalo de spawn (más rápido con oleadas altas)
	local spawnInterval = math.max(
		CONFIG.MinSpawnInterval,
		CONFIG.BaseSpawnInterval - (waveNum * 0.1)
	)
	
	return {
		WaveNumber = waveNum,
		TotalEnemies = totalEnemies,
		EnemyTypes = enemyTypes,
		HasBoss = hasBoss,
		SpawnInterval = spawnInterval,
		DifficultyMultiplier = difficultyMult
	}
end

--[[ 
	Spawnea los enemigos de una oleada
	@param config table - Configuración de la oleada
]]
function SpawnManager:SpawnWaveEnemies(config)
	local enemiesSpawned = 0
	
	-- Spawn enemigos regulares
	while enemiesSpawned < config.TotalEnemies and isWaveActive do
		local enemyType = self:SelectRandomEnemyType(config.EnemyTypes)
		self:SpawnEnemy(enemyType, config.DifficultyMultiplier)
		
		enemiesSpawned = enemiesSpawned + 1
		task.wait(config.SpawnInterval)
	end
	
	-- Spawn boss si corresponde
	if config.HasBoss then
		task.wait(2)
		self:SpawnEnemy("Boss", config.DifficultyMultiplier)
		print("[SpawnManager] ¡Boss spawneado!")
	end
	
	-- Esperar a que todos los enemigos sean derrotados
	self:WaitForWaveCompletion()
end

--[[ 
	Selecciona un tipo de enemigo aleatorio basado en pesos
	@param allowedTypes table - Tipos permitidos para esta oleada
	@return string - Tipo de enemigo seleccionado
]]
function SpawnManager:SelectRandomEnemyType(allowedTypes)
	-- Calcular peso total
	local totalWeight = 0
	for _, enemyType in ipairs(allowedTypes) do
		local template = ENEMY_TEMPLATES[enemyType]
		if template then
			totalWeight = totalWeight + template.SpawnWeight
		end
	end
	
	-- Selección por peso
	local roll = math.random() * totalWeight
	local currentWeight = 0
	
	for _, enemyType in ipairs(allowedTypes) do
		local template = ENEMY_TEMPLATES[enemyType]
		if template then
			currentWeight = currentWeight + template.SpawnWeight
			if roll <= currentWeight then
				return enemyType
			end
		end
	end
	
	-- Fallback
	return allowedTypes[1]
end

--[[ 
	Spawnea un enemigo individual
	@param enemyType string - Tipo de enemigo a spawnear
	@param difficultyMult number - Multiplicador de dificultad
	@return Model? - El modelo del enemigo spawneado
]]
function SpawnManager:SpawnEnemy(enemyType, difficultyMult)
	local template = ENEMY_TEMPLATES[enemyType]
	if not template then
		warn("[SpawnManager] Template no encontrado:", enemyType)
		return nil
	end
	
	-- Seleccionar zona de spawn
	local spawnZone = self:SelectSpawnZone()
	if not spawnZone then
		warn("[SpawnManager] No hay zonas de spawn disponibles")
		return nil
	end
	
	-- Calcular posición de spawn
	local spawnPosition = self:GetRandomPositionInZone(spawnZone)
	
	-- Crear enemigo (placeholder - en un juego real cargarías el modelo)
	local enemy = Instance.new("Model")
	enemy.Name = enemyType
	
	local part = Instance.new("Part")
	part.Name = "HumanoidRootPart"
	part.Size = Vector3.new(2, 5, 2)
	part.Position = spawnPosition
	part.Anchored = false
	part.Parent = enemy
	
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = template.Health * difficultyMult
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = template.Speed
	humanoid.Parent = enemy
	
	-- Atributos custom
	enemy:SetAttribute("EnemyType", enemyType)
	enemy:SetAttribute("Damage", template.Damage * difficultyMult)
	enemy:SetAttribute("Reward", template.Reward)
	enemy:SetAttribute("AIType", template.AIType)
	
	enemy.Parent = workspace
	
	-- Registrar enemigo activo
	table.insert(activeEnemies, enemy)
	spawnZone.SpawnCount = spawnZone.SpawnCount + 1
	
	-- Conectar muerte
	humanoid.Died:Connect(function()
		self:OnEnemyDied(enemy)
	end)
	
	return enemy
end

--[[ 
	Selecciona una zona de spawn (balanceo de carga)
	@return table? - Zona de spawn seleccionada
]]
function SpawnManager:SelectSpawnZone()
	if #spawnZones == 0 then
		return nil
	end
	
	-- Filtrar zonas activas
	local activeZones = {}
	for _, zone in ipairs(spawnZones) do
		if zone.Active then
			table.insert(activeZones, zone)
		end
	end
	
	if #activeZones == 0 then
		return nil
	end
	
	-- Seleccionar zona con menos spawns (load balancing)
	table.sort(activeZones, function(a, b)
		return a.SpawnCount < b.SpawnCount
	end)
	
	return activeZones[1]
end

--[[ 
	Obtiene una posición aleatoria dentro de una zona
	@param zone table - Zona de spawn
	@return Vector3 - Posición de spawn
]]
function SpawnManager:GetRandomPositionInZone(zone)
	local halfSize = zone.Size * 0.5
	local randomX = zone.Position.X + math.random(-halfSize.X, halfSize.X)
	local randomZ = zone.Position.Z + math.random(-halfSize.Z, halfSize.Z)
	
	return Vector3.new(randomX, zone.Position.Y, randomZ)
end

--[[ 
	Callback cuando un enemigo muere
	@param enemy Model - Enemigo que murió
]]
function SpawnManager:OnEnemyDied(enemy)
	-- Remover de lista activa
	for i, activeEnemy in ipairs(activeEnemies) do
		if activeEnemy == enemy then
			table.remove(activeEnemies, i)
			break
		end
	end
	
	-- Limpiar después de 5 segundos
	task.delay(5, function()
		if enemy and enemy.Parent then
			enemy:Destroy()
		end
	end)
end

--[[ 
	Espera a que todos los enemigos de la oleada mueran
]]
function SpawnManager:WaitForWaveCompletion()
	while #activeEnemies > 0 do
		task.wait(1)
	end
	
	-- Oleada completada
	self:OnWaveCompleted()
end

--[[ 
	Callback cuando una oleada se completa
]]
function SpawnManager:OnWaveCompleted()
	isWaveActive = false
	
	print(("[SpawnManager] Oleada %d completada"):format(currentWave))
	
	-- Notificar clientes
	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if remoteEvents and remoteEvents:FindFirstChild("WaveCompleted") then
		remoteEvents.WaveCompleted:FireAllClients(currentWave)
	end
	
	-- Reset spawn counts
	for _, zone in ipairs(spawnZones) do
		zone.SpawnCount = 0
	end
end

--[[ 
	Detiene la oleada actual
]]
function SpawnManager:StopWave()
	isWaveActive = false
	
	-- Destruir todos los enemigos activos
	for _, enemy in ipairs(activeEnemies) do
		if enemy and enemy.Parent then
			enemy:Destroy()
		end
	end
	
	activeEnemies = {}
	print("[SpawnManager] Oleada detenida")
end

--[[ 
	Obtiene estadísticas del sistema
	@return table - Estadísticas actuales
]]
function SpawnManager:GetStats()
	return {
		CurrentWave = currentWave,
		IsWaveActive = isWaveActive,
		ActiveEnemies = #activeEnemies,
		SpawnZones = #spawnZones,
		WaveConfig = waveConfig
	}
end

return SpawnManager
