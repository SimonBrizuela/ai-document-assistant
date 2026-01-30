--[[
	CombatModule - Sistema de combate
	
	Maneja daño, cooldowns, críticos, y efectos de combate.
	Optimizado para servidor con validación anti-exploits.
	
	Autor: 4GP
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatModule = {}
CombatModule.__index = CombatModule

-- Configuración
local CONFIG = {
	BaseDamage = 10,
	CriticalChance = 0.15, -- 15%
	CriticalMultiplier = 1.5,
	DefaultCooldown = 1,
	MaxComboTime = 3, -- segundos para mantener combo
	ComboMultiplier = 0.1 -- 10% más daño por combo
}

-- Storage de cooldowns activos
local activeCooldowns = {}
local comboCounts = {}
local lastHitTime = {}

-- Verificar si está en cooldown
function CombatModule:IsOnCooldown(entityId, actionName)
	local key = entityId .. "_" .. actionName
	local cooldownEnd = activeCooldowns[key]
	
	if cooldownEnd and os.clock() < cooldownEnd then
		return true, cooldownEnd - os.clock()
	end
	
	return false, 0
end

-- Iniciar cooldown
function CombatModule:StartCooldown(entityId, actionName, duration)
	local key = entityId .. "_" .. actionName
	activeCooldowns[key] = os.clock() + duration
end

-- Calcular daño
function CombatModule:CalculateDamage(attacker, target, baseDamage, options)
	options = options or {}
	
	-- Daño base
	local damage = baseDamage or CONFIG.BaseDamage
	
	-- Stats del atacante
	if attacker:FindFirstChild("Stats") then
		local strength = attacker.Stats:FindFirstChild("Strength")
		if strength then
			damage = damage + (strength.Value * 0.5)
		end
	end
	
	-- Defensa del objetivo
	if target:FindFirstChild("Stats") then
		local defense = target.Stats:FindFirstChild("Defense")
		if defense then
			local reduction = defense.Value / (defense.Value + 100)
			damage = damage * (1 - reduction)
		end
	end
	
	-- Sistema de combo
	local attackerId = attacker:GetAttribute("EntityId") or attacker.Name
	local currentTime = os.clock()
	
	if lastHitTime[attackerId] and (currentTime - lastHitTime[attackerId]) < CONFIG.MaxComboTime then
		comboCounts[attackerId] = (comboCounts[attackerId] or 0) + 1
	else
		comboCounts[attackerId] = 1
	end
	
	lastHitTime[attackerId] = currentTime
	
	-- Bonus de combo
	local comboBonus = 1 + ((comboCounts[attackerId] - 1) * CONFIG.ComboMultiplier)
	damage = damage * comboBonus
	
	-- Crítico
	local isCritical = false
	if math.random() < CONFIG.CriticalChance then
		damage = damage * CONFIG.CriticalMultiplier
		isCritical = true
	end
	
	-- Modificadores adicionales
	if options.DamageMultiplier then
		damage = damage * options.DamageMultiplier
	end
	
	if options.BonusDamage then
		damage = damage + options.BonusDamage
	end
	
	return math.floor(damage), {
		IsCritical = isCritical,
		ComboCount = comboCounts[attackerId],
		BaseDamage = baseDamage,
		FinalDamage = math.floor(damage)
	}
end

-- Aplicar daño a una entidad
function CombatModule:ApplyDamage(target, damage, attacker, options)
	options = options or {}
	
	-- Validar que el objetivo tenga humanoid
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Objetivo inválido"
	end
	
	-- Aplicar daño
	humanoid:TakeDamage(damage)
	
	-- Registrar el atacante
	if attacker then
		humanoid:SetAttribute("LastAttacker", attacker.Name)
		humanoid:SetAttribute("LastAttackTime", os.clock())
	end
	
	-- Knockback
	if options.Knockback and target:FindFirstChild("HumanoidRootPart") then
		local hrp = target.HumanoidRootPart
		local direction = options.KnockbackDirection or (hrp.CFrame.LookVector * -1)
		local force = options.KnockbackForce or 50
		
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = direction * force
		bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
		bodyVelocity.Parent = hrp
		
		game:GetService("Debris"):AddItem(bodyVelocity, 0.1)
	end
	
	-- Efecto de stun
	if options.StunDuration and options.StunDuration > 0 then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		
		task.delay(options.StunDuration, function()
			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
			end
		end)
	end
	
	return true, "Daño aplicado", {
		RemainingHealth = humanoid.Health,
		MaxHealth = humanoid.MaxHealth,
		IsDead = humanoid.Health <= 0
	}
end

-- Ataque melee
function CombatModule:MeleeAttack(attacker, target, weapon, cooldown)
	local attackerId = attacker:GetAttribute("EntityId") or attacker.Name
	cooldown = cooldown or CONFIG.DefaultCooldown
	
	-- Verificar cooldown
	local onCooldown, remaining = self:IsOnCooldown(attackerId, "melee")
	if onCooldown then
		return false, "En cooldown", { Remaining = remaining }
	end
	
	-- Calcular daño
	local baseDamage = weapon and weapon:GetAttribute("Damage") or CONFIG.BaseDamage
	local damage, damageInfo = self:CalculateDamage(attacker, target, baseDamage)
	
	-- Aplicar daño
	local success, message, targetInfo = self:ApplyDamage(target, damage, attacker, {
		Knockback = true,
		KnockbackForce = 30
	})
	
	if success then
		-- Iniciar cooldown
		self:StartCooldown(attackerId, "melee", cooldown)
	end
	
	return success, message, {
		Damage = damage,
		DamageInfo = damageInfo,
		TargetInfo = targetInfo,
		Cooldown = cooldown
	}
end

-- Ataque ranged
function CombatModule:RangedAttack(attacker, origin, direction, weapon, range)
	local attackerId = attacker:GetAttribute("EntityId") or attacker.Name
	range = range or 100
	
	-- Verificar cooldown
	local onCooldown, remaining = self:IsOnCooldown(attackerId, "ranged")
	if onCooldown then
		return false, "En cooldown", { Remaining = remaining }
	end
	
	-- Raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {attacker}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	
	local result = workspace:Raycast(origin, direction * range, raycastParams)
	
	if result then
		local target = result.Instance
		local targetModel = target:FindFirstAncestorOfClass("Model")
		
		if targetModel and targetModel:FindFirstChildOfClass("Humanoid") then
			-- Calcular daño
			local baseDamage = weapon and weapon:GetAttribute("Damage") or CONFIG.BaseDamage
			local damage, damageInfo = self:CalculateDamage(attacker, targetModel, baseDamage)
			
			-- Aplicar daño
			local success, message, targetInfo = self:ApplyDamage(targetModel, damage, attacker)
			
			if success then
				-- Iniciar cooldown
				self:StartCooldown(attackerId, "ranged", weapon and weapon:GetAttribute("Cooldown") or CONFIG.DefaultCooldown)
			end
			
			return success, message, {
				Damage = damage,
				DamageInfo = damageInfo,
				TargetInfo = targetInfo,
				HitPosition = result.Position,
				HitPart = result.Instance
			}
		end
	end
	
	return false, "No golpeó objetivo"
end

-- Obtener combo actual
function CombatModule:GetComboCount(entityId)
	return comboCounts[entityId] or 0
end

-- Resetear combo
function CombatModule:ResetCombo(entityId)
	comboCounts[entityId] = 0
	lastHitTime[entityId] = nil
end

-- Limpiar cooldowns expirados (llamar periódicamente)
function CombatModule:CleanupCooldowns()
	local currentTime = os.clock()
	
	for key, endTime in pairs(activeCooldowns) do
		if currentTime >= endTime then
			activeCooldowns[key] = nil
		end
	end
end

-- Aplicar efecto de daño con el tiempo (DOT)
function CombatModule:ApplyDOT(target, damage, duration, tickRate, attacker)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	
	tickRate = tickRate or 1
	local ticks = duration / tickRate
	local damagePerTick = damage / ticks
	
	task.spawn(function()
		for i = 1, ticks do
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(damagePerTick)
				task.wait(tickRate)
			else
				break
			end
		end
	end)
	
	return true
end

-- Curar entidad
function CombatModule:Heal(target, amount, isPercentage)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false, "No humanoid encontrado" end
	
	local healAmount = amount
	if isPercentage then
		healAmount = humanoid.MaxHealth * (amount / 100)
	end
	
	humanoid.Health = math.min(humanoid.Health + healAmount, humanoid.MaxHealth)
	
	return true, "Curado", {
		HealAmount = healAmount,
		CurrentHealth = humanoid.Health,
		MaxHealth = humanoid.MaxHealth
	}
end

return CombatModule
