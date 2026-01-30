--[[
	ServerInit - Script principal del servidor
	
	Inicializa todos los sistemas y maneja la lógica central del servidor.
	
	Autor: 4GP
]]

local ServerScriptService = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cargar módulos
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local EventsManager = require(ServerScriptService:WaitForChild("EventsManager"))
local CombatModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CombatModule"))
local InventoryModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("InventoryModule"))
local SkillsModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SkillsModule"))

-- Inicializar sistemas
DataManager:Initialize()
EventsManager:Initialize()

-- Storage de instancias de jugadores
local playerInventories = {}
local playerSkills = {}

print("[ServerInit] Sistemas inicializados")

-- Configurar eventos de inventario
EventsManager:CreateFunction("GetInventory", function(player)
	local inventory = playerInventories[player.UserId]
	
	if not inventory then
		return { Success = false, Message = "Inventario no encontrado" }
	end
	
	return {
		Success = true,
		Inventory = inventory:ExportData()
	}
end)

EventsManager:CreateEvent("UseItem", function(player, slotIndex)
	local inventory = playerInventories[player.UserId]
	if not inventory then return end
	
	local slot = inventory.Slots[slotIndex]
	if not slot or not slot.ItemId then return end
	
	print(("[ServerInit] %s usó item: %s"):format(player.Name, slot.ItemId))
	
	-- Aquí implementarías la lógica de usar el item
end)

EventsManager:CreateEvent("MoveItem", function(player, fromSlot, toSlot)
	local inventory = playerInventories[player.UserId]
	if not inventory then return end
	
	local success, message = inventory:MoveItem(fromSlot, toSlot)
	
	if success then
		-- Actualizar datos guardados
		local data = DataManager:GetData(player)
		if data then
			data.Inventory = inventory:ExportData()
		end
		
		-- Notificar al cliente
		EventsManager:FireClient("InventoryUpdated", player, inventory:ExportData())
	end
end)

-- Configurar eventos de combate
EventsManager:CreateEvent("MeleeAttack", function(player, target)
	local character = player.Character
	if not character then return end
	
	if not target or not target:IsA("Model") then return end
	
	-- Validar distancia
	local playerHRP = character:FindFirstChild("HumanoidRootPart")
	local targetHRP = target:FindFirstChild("HumanoidRootPart")
	
	if not playerHRP or not targetHRP then return end
	
	local distance = (playerHRP.Position - targetHRP.Position).Magnitude
	if distance > 10 then return end -- Anti-exploit: máxima distancia
	
	-- Realizar ataque
	local success, message, info = CombatModule:MeleeAttack(character, target, nil, 1)
	
	if success then
		-- Notificar al cliente sobre el hit
		EventsManager:FireClient("AttackHit", player, {
			Target = target.Name,
			Damage = info.Damage,
			Critical = info.DamageInfo.IsCritical,
			Combo = info.DamageInfo.ComboCount
		})
	end
end)

-- Configurar eventos de skills
EventsManager:CreateEvent("ActivateSkill", function(player, skillId, targetData)
	local skills = playerSkills[player.UserId]
	if not skills then return end
	
	local success, message, info = skills:ActivateSkill(player, skillId, targetData)
	
	if success then
		EventsManager:FireClient("SkillActivated", player, {
			SkillId = skillId,
			Info = info
		})
	else
		EventsManager:FireClient("SkillFailed", player, {
			SkillId = skillId,
			Reason = message
		})
	end
end)

EventsManager:CreateFunction("GetPlayerSkills", function(player)
	local skills = playerSkills[player.UserId]
	if not skills then
		return { Success = false }
	end
	
	return {
		Success = true,
		Skills = skills:GetPlayerSkills(player.UserId)
	}
end)

-- Manejar jugadores
game.Players.PlayerAdded:Connect(function(player)
	print(("[ServerInit] Jugador conectado: %s"):format(player.Name))
	
	-- Cargar datos
	local data = DataManager:LoadData(player)
	
	-- Crear inventario
	local inventory = InventoryModule.new({ MaxSlots = 20 })
	if data.Inventory then
		inventory:LoadFromData(data.Inventory)
	end
	playerInventories[player.UserId] = inventory
	
	-- Crear sistema de skills
	local skills = SkillsModule.new()
	skills:InitializePlayerSkills(player.UserId, data.Skills)
	playerSkills[player.UserId] = skills
	
	-- Configurar atributos del jugador
	player:SetAttribute("Mana", 100)
	player:SetAttribute("MaxMana", 100)
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("MaxStamina", 100)
	
	-- Esperar a que el personaje cargue
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		
		-- Aplicar stats guardadas
		if data.Stats then
			humanoid.MaxHealth = data.Stats.Health or 100
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end)

game.Players.PlayerRemoving:Connect(function(player)
	print(("[ServerInit] Jugador desconectado: %s"):format(player.Name))
	
	-- Guardar inventario
	local inventory = playerInventories[player.UserId]
	if inventory then
		local data = DataManager:GetData(player)
		if data then
			data.Inventory = inventory:ExportData()
		end
	end
	
	-- Guardar skills
	local skills = playerSkills[player.UserId]
	if skills then
		local data = DataManager:GetData(player)
		if data then
			data.Skills = skills:GetPlayerSkills(player.UserId)
		end
	end
	
	-- Limpiar
	playerInventories[player.UserId] = nil
	playerSkills[player.UserId] = nil
end)

-- Regeneración de mana/stamina
task.spawn(function()
	while task.wait(1) do
		for _, player in ipairs(game.Players:GetPlayers()) do
			local mana = player:GetAttribute("Mana") or 0
			local maxMana = player:GetAttribute("MaxMana") or 100
			local stamina = player:GetAttribute("Stamina") or 0
			local maxStamina = player:GetAttribute("MaxStamina") or 100
			
			-- Regenerar mana (5 por segundo)
			if mana < maxMana then
				player:SetAttribute("Mana", math.min(mana + 5, maxMana))
			end
			
			-- Regenerar stamina (10 por segundo)
			if stamina < maxStamina then
				player:SetAttribute("Stamina", math.min(stamina + 10, maxStamina))
			end
		end
	end
end)

-- Cleanup periódico
task.spawn(function()
	while task.wait(30) do
		CombatModule:CleanupCooldowns()
		EventsManager:CleanupRateLimits()
	end
end)

print("[ServerInit] Servidor listo")
