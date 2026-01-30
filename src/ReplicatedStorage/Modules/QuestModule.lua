--[[
	QuestModule - Sistema de misiones
	
	Gestiona misiones, objetivos, progreso y recompensas.
	
	Autor: 4GP
]]

local QuestModule = {}
QuestModule.__index = QuestModule

-- Definiciones de misiones
local QUEST_DEFINITIONS = {
	["tutorial_quest"] = {
		Name = "Tutorial Básico",
		Description = "Completa los pasos básicos del juego",
		Type = "Tutorial",
		Objectives = {
			{
				Id = "move",
				Description = "Muévete 50 studs",
				Type = "Distance",
				Required = 50,
				Current = 0
			},
			{
				Id = "collect_coins",
				Description = "Recolecta 10 monedas",
				Type = "Collect",
				ItemId = "gold_coin",
				Required = 10,
				Current = 0
			}
		},
		Rewards = {
			Coins = 100,
			Experience = 50,
			Items = {
				{ ItemId = "health_potion", Quantity = 3 }
			}
		},
		AutoAccept = true
	},
	["defeat_enemies"] = {
		Name = "Cazador de Monstruos",
		Description = "Derrota 20 enemigos",
		Type = "Combat",
		Objectives = {
			{
				Id = "kill_enemies",
				Description = "Derrota enemigos",
				Type = "Kill",
				Required = 20,
				Current = 0
			}
		},
		Rewards = {
			Coins = 250,
			Experience = 150,
			Items = {
				{ ItemId = "iron_sword", Quantity = 1 }
			}
		},
		RequiredLevel = 2
	},
	["master_skills"] = {
		Name = "Maestro de Habilidades",
		Description = "Usa habilidades 50 veces",
		Type = "Skills",
		Objectives = {
			{
				Id = "use_skills",
				Description = "Usa cualquier habilidad",
				Type = "UseSkill",
				Required = 50,
				Current = 0
			}
		},
		Rewards = {
			Coins = 500,
			Experience = 300
		},
		RequiredLevel = 5
	}
}

-- Storage de progreso de jugadores
local playerQuests = {}

-- Crear nueva instancia
function QuestModule.new()
	local self = setmetatable({}, QuestModule)
	return self
end

-- Inicializar quests de un jugador
function QuestModule:InitializePlayerQuests(playerId, savedQuests)
	playerQuests[playerId] = {
		Active = {},
		Completed = {}
	}
	
	if savedQuests then
		if savedQuests.Active then
			for questId, questData in pairs(savedQuests.Active) do
				playerQuests[playerId].Active[questId] = questData
			end
		end
		
		if savedQuests.Completed then
			playerQuests[playerId].Completed = savedQuests.Completed
		end
	end
	
	-- Auto-aceptar quests
	for questId, questDef in pairs(QUEST_DEFINITIONS) do
		if questDef.AutoAccept and not self:HasQuest(playerId, questId) then
			self:AcceptQuest(playerId, questId)
		end
	end
end

-- Aceptar una quest
function QuestModule:AcceptQuest(playerId, questId)
	local questDef = QUEST_DEFINITIONS[questId]
	if not questDef then
		return false, "Quest no existe"
	end
	
	if not playerQuests[playerId] then
		return false, "Jugador no inicializado"
	end
	
	if playerQuests[playerId].Active[questId] then
		return false, "Quest ya activa"
	end
	
	if self:IsCompleted(playerId, questId) then
		return false, "Quest ya completada"
	end
	
	-- Copiar quest con progreso inicial
	local quest = {
		QuestId = questId,
		Name = questDef.Name,
		Description = questDef.Description,
		Type = questDef.Type,
		Objectives = {},
		AcceptedTime = os.time()
	}
	
	-- Copiar objetivos
	for _, obj in ipairs(questDef.Objectives) do
		table.insert(quest.Objectives, {
			Id = obj.Id,
			Description = obj.Description,
			Type = obj.Type,
			ItemId = obj.ItemId,
			Required = obj.Required,
			Current = 0,
			Completed = false
		})
	end
	
	playerQuests[playerId].Active[questId] = quest
	
	return true, "Quest aceptada", quest
end

-- Actualizar progreso de objetivo
function QuestModule:UpdateObjective(playerId, questId, objectiveId, amount)
	if not playerQuests[playerId] then return false end
	
	local quest = playerQuests[playerId].Active[questId]
	if not quest then return false end
	
	-- Encontrar objetivo
	local objective = nil
	for _, obj in ipairs(quest.Objectives) do
		if obj.Id == objectiveId then
			objective = obj
			break
		end
	end
	
	if not objective or objective.Completed then
		return false
	end
	
	-- Actualizar progreso
	objective.Current = math.min(objective.Current + amount, objective.Required)
	
	-- Verificar si se completó
	if objective.Current >= objective.Required then
		objective.Completed = true
	end
	
	-- Verificar si toda la quest se completó
	local allCompleted = true
	for _, obj in ipairs(quest.Objectives) do
		if not obj.Completed then
			allCompleted = false
			break
		end
	end
	
	if allCompleted then
		quest.AllObjectivesCompleted = true
	end
	
	return true, objective.Completed, allCompleted
end

-- Completar quest y dar recompensas
function QuestModule:CompleteQuest(playerId, questId, rewardCallback)
	if not playerQuests[playerId] then
		return false, "Jugador no inicializado"
	end
	
	local quest = playerQuests[playerId].Active[questId]
	if not quest then
		return false, "Quest no activa"
	end
	
	if not quest.AllObjectivesCompleted then
		return false, "Objetivos no completados"
	end
	
	-- Obtener definición para recompensas
	local questDef = QUEST_DEFINITIONS[questId]
	if not questDef then
		return false, "Quest no existe"
	end
	
	-- Dar recompensas
	local rewards = questDef.Rewards
	if rewardCallback and rewards then
		rewardCallback(rewards)
	end
	
	-- Mover a completadas
	table.insert(playerQuests[playerId].Completed, questId)
	playerQuests[playerId].Active[questId] = nil
	
	return true, "Quest completada", rewards
end

-- Verificar si tiene quest
function QuestModule:HasQuest(playerId, questId)
	if not playerQuests[playerId] then return false end
	
	return playerQuests[playerId].Active[questId] ~= nil
end

-- Verificar si completó quest
function QuestModule:IsCompleted(playerId, questId)
	if not playerQuests[playerId] then return false end
	
	for _, completedId in ipairs(playerQuests[playerId].Completed) do
		if completedId == questId then
			return true
		end
	end
	
	return false
end

-- Obtener todas las quests activas
function QuestModule:GetActiveQuests(playerId)
	if not playerQuests[playerId] then return {} end
	
	local quests = {}
	for questId, quest in pairs(playerQuests[playerId].Active) do
		table.insert(quests, quest)
	end
	
	return quests
end

-- Obtener quests disponibles
function QuestModule:GetAvailableQuests(playerId, playerLevel)
	local available = {}
	
	for questId, questDef in pairs(QUEST_DEFINITIONS) do
		local canAccept = true
		
		-- Verificar nivel requerido
		if questDef.RequiredLevel and playerLevel < questDef.RequiredLevel then
			canAccept = false
		end
		
		-- Verificar si ya está activa o completada
		if self:HasQuest(playerId, questId) or self:IsCompleted(playerId, questId) then
			canAccept = false
		end
		
		if canAccept then
			table.insert(available, {
				QuestId = questId,
				Name = questDef.Name,
				Description = questDef.Description,
				Type = questDef.Type,
				RequiredLevel = questDef.RequiredLevel or 1,
				Rewards = questDef.Rewards
			})
		end
	end
	
	return available
end

-- Progreso por tipo de evento
function QuestModule:OnPlayerKill(playerId, targetName)
	if not playerQuests[playerId] then return end
	
	for questId, quest in pairs(playerQuests[playerId].Active) do
		for _, objective in ipairs(quest.Objectives) do
			if objective.Type == "Kill" and not objective.Completed then
				self:UpdateObjective(playerId, questId, objective.Id, 1)
			end
		end
	end
end

function QuestModule:OnItemCollected(playerId, itemId, quantity)
	if not playerQuests[playerId] then return end
	
	for questId, quest in pairs(playerQuests[playerId].Active) do
		for _, objective in ipairs(quest.Objectives) do
			if objective.Type == "Collect" and objective.ItemId == itemId and not objective.Completed then
				self:UpdateObjective(playerId, questId, objective.Id, quantity)
			end
		end
	end
end

function QuestModule:OnSkillUsed(playerId, skillId)
	if not playerQuests[playerId] then return end
	
	for questId, quest in pairs(playerQuests[playerId].Active) do
		for _, objective in ipairs(quest.Objectives) do
			if objective.Type == "UseSkill" and not objective.Completed then
				self:UpdateObjective(playerId, questId, objective.Id, 1)
			end
		end
	end
end

function QuestModule:OnDistanceTraveled(playerId, distance)
	if not playerQuests[playerId] then return end
	
	for questId, quest in pairs(playerQuests[playerId].Active) do
		for _, objective in ipairs(quest.Objectives) do
			if objective.Type == "Distance" and not objective.Completed then
				self:UpdateObjective(playerId, questId, objective.Id, distance)
			end
		end
	end
end

-- Exportar datos
function QuestModule:ExportPlayerData(playerId)
	if not playerQuests[playerId] then return nil end
	
	return {
		Active = playerQuests[playerId].Active,
		Completed = playerQuests[playerId].Completed
	}
end

return QuestModule
