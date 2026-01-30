--[[
	SkillsModule - Sistema de habilidades y skills
	
	Gestiona habilidades activables con cooldowns, costos de recursos,
	efectos y progresión de niveles.
	
	Autor: 4GP
]]

local SkillsModule = {}
SkillsModule.__index = SkillsModule

-- Definiciones de habilidades
local SKILL_DEFINITIONS = {
	["fireball"] = {
		Name = "Fireball",
		Description = "Lanza una bola de fuego",
		Cooldown = 5,
		ManaCost = 20,
		Range = 100,
		Damage = 35,
		Level = 1,
		MaxLevel = 10,
		UpgradeBonus = {
			Damage = 5,
			ManaCost = -1
		}
	},
	["heal"] = {
		Name = "Heal",
		Description = "Cura al jugador",
		Cooldown = 8,
		ManaCost = 30,
		HealAmount = 50,
		Level = 1,
		MaxLevel = 10,
		UpgradeBonus = {
			HealAmount = 10,
			Cooldown = -0.5
		}
	},
	["dash"] = {
		Name = "Dash",
		Description = "Dash rápido hacia adelante",
		Cooldown = 3,
		StaminaCost = 25,
		Distance = 30,
		Speed = 100,
		Level = 1,
		MaxLevel = 5,
		UpgradeBonus = {
			Distance = 5,
			StaminaCost = -3
		}
	},
	["shield"] = {
		Name = "Shield",
		Description = "Crea un escudo temporal",
		Cooldown = 15,
		ManaCost = 40,
		Duration = 5,
		DamageReduction = 0.5,
		Level = 1,
		MaxLevel = 8,
		UpgradeBonus = {
			Duration = 0.5,
			DamageReduction = 0.05
		}
	},
	["area_attack"] = {
		Name = "Area Attack",
		Description = "Ataque en área",
		Cooldown = 10,
		StaminaCost = 50,
		Radius = 15,
		Damage = 40,
		Level = 1,
		MaxLevel = 10,
		UpgradeBonus = {
			Damage = 8,
			Radius = 2
		}
	}
}

-- Storage de cooldowns y estados activos
local skillCooldowns = {}
local activeEffects = {}
local playerSkills = {}

-- Crear nueva instancia del sistema
function SkillsModule.new()
	local self = setmetatable({}, SkillsModule)
	return self
end

-- Inicializar skills del jugador
function SkillsModule:InitializePlayerSkills(playerId, savedSkills)
	playerSkills[playerId] = {}
	
	if savedSkills then
		for skillId, skillData in pairs(savedSkills) do
			playerSkills[playerId][skillId] = {
				Level = skillData.Level or 1,
				Experience = skillData.Experience or 0,
				IsEquipped = skillData.IsEquipped or false
			}
		end
	end
end

-- Obtener skill info con bonuses de nivel
function SkillsModule:GetSkillInfo(skillId, level)
	local baseDef = SKILL_DEFINITIONS[skillId]
	if not baseDef then return nil end
	
	level = level or baseDef.Level
	local info = {}
	
	-- Copiar valores base
	for key, value in pairs(baseDef) do
		info[key] = value
	end
	
	-- Aplicar bonuses por nivel
	if level > 1 and baseDef.UpgradeBonus then
		local levelsGained = level - 1
		for stat, bonus in pairs(baseDef.UpgradeBonus) do
			if type(info[stat]) == "number" then
				info[stat] = info[stat] + (bonus * levelsGained)
			end
		end
	end
	
	info.Level = level
	return info
end

-- Verificar si la skill está en cooldown
function SkillsModule:IsOnCooldown(playerId, skillId)
	local key = playerId .. "_" .. skillId
	local cooldownEnd = skillCooldowns[key]
	
	if cooldownEnd and os.clock() < cooldownEnd then
		return true, math.ceil(cooldownEnd - os.clock())
	end
	
	return false, 0
end

-- Verificar recursos (mana, stamina)
function SkillsModule:HasResources(player, skillInfo)
	if skillInfo.ManaCost then
		local mana = player:GetAttribute("Mana") or 0
		if mana < skillInfo.ManaCost then
			return false, "Mana insuficiente"
		end
	end
	
	if skillInfo.StaminaCost then
		local stamina = player:GetAttribute("Stamina") or 0
		if stamina < skillInfo.StaminaCost then
			return false, "Stamina insuficiente"
		end
	end
	
	return true
end

-- Consumir recursos
function SkillsModule:ConsumeResources(player, skillInfo)
	if skillInfo.ManaCost then
		local currentMana = player:GetAttribute("Mana") or 0
		player:SetAttribute("Mana", math.max(0, currentMana - skillInfo.ManaCost))
	end
	
	if skillInfo.StaminaCost then
		local currentStamina = player:GetAttribute("Stamina") or 0
		player:SetAttribute("Stamina", math.max(0, currentStamina - skillInfo.StaminaCost))
	end
end

-- Activar skill
function SkillsModule:ActivateSkill(player, skillId, targetData)
	local playerId = player.UserId
	
	-- Obtener nivel del skill
	local playerSkillData = playerSkills[playerId] and playerSkills[playerId][skillId]
	local skillLevel = playerSkillData and playerSkillData.Level or 1
	
	-- Obtener info del skill
	local skillInfo = self:GetSkillInfo(skillId, skillLevel)
	if not skillInfo then
		return false, "Skill no existe"
	end
	
	-- Verificar cooldown
	local onCooldown, remaining = self:IsOnCooldown(playerId, skillId)
	if onCooldown then
		return false, "En cooldown", { Remaining = remaining }
	end
	
	-- Verificar recursos
	local hasResources, message = self:HasResources(player, skillInfo)
	if not hasResources then
		return false, message
	end
	
	-- Consumir recursos
	self:ConsumeResources(player, skillInfo)
	
	-- Iniciar cooldown
	local key = playerId .. "_" .. skillId
	skillCooldowns[key] = os.clock() + skillInfo.Cooldown
	
	-- Ejecutar efecto del skill
	local effectResult = self:ExecuteSkillEffect(player, skillId, skillInfo, targetData)
	
	-- Dar experiencia al skill
	if playerSkillData then
		self:AddSkillExperience(playerId, skillId, 10)
	end
	
	return true, "Skill activado", {
		SkillInfo = skillInfo,
		EffectResult = effectResult,
		Cooldown = skillInfo.Cooldown
	}
end

-- Ejecutar efecto específico del skill
function SkillsModule:ExecuteSkillEffect(player, skillId, skillInfo, targetData)
	if skillId == "fireball" then
		return self:FireballEffect(player, skillInfo, targetData)
		
	elseif skillId == "heal" then
		return self:HealEffect(player, skillInfo)
		
	elseif skillId == "dash" then
		return self:DashEffect(player, skillInfo, targetData)
		
	elseif skillId == "shield" then
		return self:ShieldEffect(player, skillInfo)
		
	elseif skillId == "area_attack" then
		return self:AreaAttackEffect(player, skillInfo, targetData)
	end
	
	return { Success = false, Message = "Efecto no implementado" }
end

-- Efecto: Fireball
function SkillsModule:FireballEffect(player, skillInfo, targetData)
	local character = player.Character
	if not character then return { Success = false } end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return { Success = false } end
	
	-- Crear proyectil (normalmente usarías un modelo real)
	local direction = targetData and targetData.Direction or hrp.CFrame.LookVector
	local origin = hrp.Position + Vector3.new(0, 2, 0)
	
	-- Raycast para detectar impacto
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	
	local result = workspace:Raycast(origin, direction * skillInfo.Range, raycastParams)
	
	if result then
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		if hitModel and hitModel:FindFirstChildOfClass("Humanoid") then
			local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
			humanoid:TakeDamage(skillInfo.Damage)
			
			return {
				Success = true,
				Target = hitModel.Name,
				Damage = skillInfo.Damage,
				HitPosition = result.Position
			}
		end
	end
	
	return { Success = true, Message = "Proyectil lanzado" }
end

-- Efecto: Heal
function SkillsModule:HealEffect(player, skillInfo)
	local character = player.Character
	if not character then return { Success = false } end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return { Success = false } end
	
	local oldHealth = humanoid.Health
	humanoid.Health = math.min(humanoid.Health + skillInfo.HealAmount, humanoid.MaxHealth)
	local actualHealed = humanoid.Health - oldHealth
	
	return {
		Success = true,
		HealAmount = actualHealed,
		CurrentHealth = humanoid.Health,
		MaxHealth = humanoid.MaxHealth
	}
end

-- Efecto: Dash
function SkillsModule:DashEffect(player, skillInfo, targetData)
	local character = player.Character
	if not character then return { Success = false } end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return { Success = false } end
	
	local direction = targetData and targetData.Direction or hrp.CFrame.LookVector
	local targetPosition = hrp.Position + (direction * skillInfo.Distance)
	
	-- Crear BodyVelocity para el dash
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction * skillInfo.Speed
	bodyVelocity.MaxForce = Vector3.new(4000, 0, 4000)
	bodyVelocity.Parent = hrp
	
	game:GetService("Debris"):AddItem(bodyVelocity, 0.3)
	
	return {
		Success = true,
		Distance = skillInfo.Distance,
		Direction = direction
	}
end

-- Efecto: Shield
function SkillsModule:ShieldEffect(player, skillInfo)
	local playerId = player.UserId
	
	-- Registrar efecto activo
	local key = playerId .. "_shield"
	activeEffects[key] = {
		StartTime = os.clock(),
		Duration = skillInfo.Duration,
		DamageReduction = skillInfo.DamageReduction
	}
	
	-- Dar atributo temporal
	player:SetAttribute("ShieldActive", true)
	player:SetAttribute("DamageReduction", skillInfo.DamageReduction)
	
	-- Remover después de la duración
	task.delay(skillInfo.Duration, function()
		activeEffects[key] = nil
		if player and player.Parent then
			player:SetAttribute("ShieldActive", false)
			player:SetAttribute("DamageReduction", 0)
		end
	end)
	
	return {
		Success = true,
		Duration = skillInfo.Duration,
		DamageReduction = skillInfo.DamageReduction
	}
end

-- Efecto: Area Attack
function SkillsModule:AreaAttackEffect(player, skillInfo, targetData)
	local character = player.Character
	if not character then return { Success = false } end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return { Success = false } end
	
	local hitTargets = {}
	local centerPosition = hrp.Position
	
	-- Detectar todos los modelos en el radio
	for _, model in pairs(workspace:GetDescendants()) do
		if model:IsA("Model") and model ~= character then
			local enemyHrp = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			
			if enemyHrp and humanoid and humanoid.Health > 0 then
				local distance = (enemyHrp.Position - centerPosition).Magnitude
				
				if distance <= skillInfo.Radius then
					humanoid:TakeDamage(skillInfo.Damage)
					table.insert(hitTargets, {
						Name = model.Name,
						Damage = skillInfo.Damage
					})
				end
			end
		end
	end
	
	return {
		Success = true,
		TargetsHit = #hitTargets,
		Targets = hitTargets,
		Radius = skillInfo.Radius
	}
end

-- Añadir experiencia a un skill
function SkillsModule:AddSkillExperience(playerId, skillId, amount)
	if not playerSkills[playerId] or not playerSkills[playerId][skillId] then
		return false
	end
	
	local skillData = playerSkills[playerId][skillId]
	local skillDef = SKILL_DEFINITIONS[skillId]
	
	if skillData.Level >= skillDef.MaxLevel then
		return false, "Nivel máximo alcanzado"
	end
	
	skillData.Experience = skillData.Experience + amount
	
	-- Calcular XP necesaria para subir de nivel
	local xpNeeded = 100 * skillData.Level
	
	if skillData.Experience >= xpNeeded then
		skillData.Level = skillData.Level + 1
		skillData.Experience = skillData.Experience - xpNeeded
		return true, "Nivel subido", { NewLevel = skillData.Level }
	end
	
	return true, "Experiencia añadida"
end

-- Obtener skills del jugador
function SkillsModule:GetPlayerSkills(playerId)
	return playerSkills[playerId] or {}
end

-- Equipar/desequipar skill
function SkillsModule:ToggleSkillEquip(playerId, skillId)
	if not playerSkills[playerId] then
		playerSkills[playerId] = {}
	end
	
	if not playerSkills[playerId][skillId] then
		playerSkills[playerId][skillId] = {
			Level = 1,
			Experience = 0,
			IsEquipped = false
		}
	end
	
	local skillData = playerSkills[playerId][skillId]
	skillData.IsEquipped = not skillData.IsEquipped
	
	return skillData.IsEquipped
end

-- Verificar si tiene efecto activo
function SkillsModule:HasActiveEffect(playerId, effectName)
	local key = playerId .. "_" .. effectName
	local effect = activeEffects[key]
	
	if effect then
		local elapsed = os.clock() - effect.StartTime
		if elapsed < effect.Duration then
			return true, effect.Duration - elapsed, effect
		else
			activeEffects[key] = nil
		end
	end
	
	return false, 0, nil
end

-- Limpiar cooldowns expirados
function SkillsModule:Cleanup()
	local currentTime = os.clock()
	
	for key, endTime in pairs(skillCooldowns) do
		if currentTime >= endTime then
			skillCooldowns[key] = nil
		end
	end
	
	for key, effect in pairs(activeEffects) do
		if currentTime - effect.StartTime >= effect.Duration then
			activeEffects[key] = nil
		end
	end
end

return SkillsModule
