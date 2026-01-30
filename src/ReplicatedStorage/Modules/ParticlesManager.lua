--[[
	ParticlesManager - Sistema de efectos visuales
	
	Usa object pooling para no crear partículas todo el tiempo y evitar lag.
	Incluye presets para efectos comunes y limpieza automática.
	
	Features:
	- Pool de attachments reutilizables
	- Presets configurables (Hit, Heal, LevelUp, etc)
	- Limpieza automática después de X tiempo
	- Límite de partículas activas
	
	Por: 4GP
	v2.1.0
]]

local ParticlesManager = {}
ParticlesManager.__index = ParticlesManager

-- Servicios
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Configuración
local CONFIG = {
	PoolSize = 20,
	DefaultLifetime = 3,
	CleanupInterval = 5,
	MaxActiveParticles = 100
}

-- Pool de partículas reutilizables
local particlePool = {}
local activeParticles = {}
local particleCount = 0

-- Presets de efectos comunes
local EFFECT_PRESETS = {
	Hit = {
		Type = "ParticleEmitter",
		Properties = {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Rate = 50,
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(5, 10),
			SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new(Color3.fromRGB(255, 100, 100)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			}),
			EmissionDirection = Enum.NormalId.Top,
			Enabled = false
		},
		Duration = 0.2
	},
	
	Heal = {
		Type = "ParticleEmitter",
		Properties = {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 30,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(45, 45),
			Color = ColorSequence.new(Color3.fromRGB(100, 255, 100)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.5, 0.5),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1)
			}),
			EmissionDirection = Enum.NormalId.Top,
			Enabled = false
		},
		Duration = 0.3
	},
	
	LevelUp = {
		Type = "ParticleEmitter",
		Properties = {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 100,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(3, 8),
			SpreadAngle = Vector2.new(360, 360),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 0))
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.8),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.7, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			}),
			EmissionDirection = Enum.NormalId.Top,
			Enabled = false
		},
		Duration = 0.5
	},
	
	Explosion = {
		Type = "ParticleEmitter",
		Properties = {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Rate = 200,
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(10, 20),
			SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 50, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 0, 0))
			}),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 2),
				NumberSequenceKeypoint.new(1, 0)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 1)
			}),
			EmissionDirection = Enum.NormalId.Top,
			Enabled = false
		},
		Duration = 0.3
	}
}

-- Inicializa el pool de partículas
function ParticlesManager:Initialize()
	-- Pre-crear objetos en el pool
	for i = 1, CONFIG.PoolSize do
		local attachment = Instance.new("Attachment")
		attachment.Name = "VFXAttachment"
		table.insert(particlePool, attachment)
	end
	
	-- Iniciar limpieza automática
	self:StartCleanupLoop()
	
	print("[ParticlesManager] Inicializado con pool de", CONFIG.PoolSize)
end

-- Obtiene attachment del pool (o crea uno nuevo si está vacío)
function ParticlesManager:GetFromPool()
	if #particlePool > 0 then
		return table.remove(particlePool)
	else
		warn("[ParticlesManager] Pool vacío, creando nuevo attachment")
		return Instance.new("Attachment")
	end
end

-- Devuelve un attachment al pool para reutilizarlo
function ParticlesManager:ReturnToPool(attachment)
	if not attachment or not attachment:IsA("Attachment") then
		return
	end
	
	-- Limpiar todos los emisores
	for _, child in ipairs(attachment:GetChildren()) do
		child:Destroy()
	end
	
	-- Desconectar del parent
	attachment.Parent = nil
	
	-- Devolver al pool si no está lleno
	if #particlePool < CONFIG.PoolSize then
		table.insert(particlePool, attachment)
	else
		attachment:Destroy()
	end
end

--[[ 
	Crea un emisor de partículas desde un preset
	@param presetName string - Nombre del preset
	@return ParticleEmitter
]]
function ParticlesManager:CreateEmitterFromPreset(presetName)
	local preset = EFFECT_PRESETS[presetName]
	if not preset then
		warn("[ParticlesManager] Preset no encontrado:", presetName)
		return nil
	end
	
	local emitter = Instance.new(preset.Type)
	
	-- Aplicar propiedades
	for property, value in pairs(preset.Properties) do
		emitter[property] = value
	end
	
	return emitter
end

--[[ 
	Reproduce un efecto de partículas en una posición
	@param presetName string - Nombre del preset a usar
	@param position Vector3 - Posición donde reproducir
	@param parent Instance? - Parent opcional (default: Workspace)
	@param lifetime number? - Tiempo antes de limpiar (default: CONFIG.DefaultLifetime)
	@return Attachment - El attachment creado
]]
function ParticlesManager:PlayEffect(presetName, position, parent, lifetime)
	-- Verificar límite de partículas activas
	if particleCount >= CONFIG.MaxActiveParticles then
		warn("[ParticlesManager] Límite de partículas alcanzado")
		return nil
	end
	
	local preset = EFFECT_PRESETS[presetName]
	if not preset then
		warn("[ParticlesManager] Preset no encontrado:", presetName)
		return nil
	end
	
	-- Obtener attachment del pool
	local attachment = self:GetFromPool()
	attachment.Name = "VFX_" .. presetName
	attachment.WorldPosition = position
	attachment.Parent = parent or workspace
	
	-- Crear emisor
	local emitter = self:CreateEmitterFromPreset(presetName)
	if not emitter then
		self:ReturnToPool(attachment)
		return nil
	end
	
	emitter.Parent = attachment
	
	-- Emitir partículas
	emitter:Emit(emitter.Rate * (preset.Duration or 0.2))
	
	-- Registrar como activo
	particleCount = particleCount + 1
	table.insert(activeParticles, {
		attachment = attachment,
		timestamp = tick(),
		lifetime = lifetime or CONFIG.DefaultLifetime
	})
	
	return attachment
end

--[[ 
	Reproduce un efecto en un objeto específico
	@param presetName string - Nombre del preset
	@param instance Instance - Objeto donde adjuntar el efecto
	@param attachmentName string? - Nombre del attachment en el objeto
	@param lifetime number? - Tiempo de vida del efecto
]]
function ParticlesManager:PlayEffectOnObject(presetName, instance, attachmentName, lifetime)
	if not instance then
		warn("[ParticlesManager] Instance inválido")
		return
	end
	
	-- Buscar attachment existente o usar posición del objeto
	local targetAttachment = nil
	if attachmentName then
		targetAttachment = instance:FindFirstChild(attachmentName, true)
	end
	
	local position = targetAttachment and targetAttachment.WorldPosition or instance.Position
	return self:PlayEffect(presetName, position, instance, lifetime)
end

--[[ 
	Crea un efecto personalizado con propiedades específicas
	@param properties table - Tabla de propiedades del emisor
	@param position Vector3 - Posición del efecto
	@param parent Instance? - Parent del efecto
	@param emitCount number? - Cantidad de partículas a emitir
	@param lifetime number? - Tiempo de vida
	@return Attachment
]]
function ParticlesManager:CreateCustomEffect(properties, position, parent, emitCount, lifetime)
	local attachment = self:GetFromPool()
	attachment.WorldPosition = position
	attachment.Parent = parent or workspace
	
	local emitter = Instance.new("ParticleEmitter")
	
	-- Aplicar propiedades personalizadas
	for property, value in pairs(properties) do
		pcall(function()
			emitter[property] = value
		end)
	end
	
	emitter.Parent = attachment
	emitter:Emit(emitCount or 20)
	
	-- Registrar y programar limpieza
	particleCount = particleCount + 1
	table.insert(activeParticles, {
		attachment = attachment,
		timestamp = tick(),
		lifetime = lifetime or CONFIG.DefaultLifetime
	})
	
	return attachment
end

--[[ 
	Loop de limpieza automática de partículas expiradas
]]
function ParticlesManager:StartCleanupLoop()
	task.spawn(function()
		while true do
			task.wait(CONFIG.CleanupInterval)
			self:CleanupExpiredParticles()
		end
	end)
end

--[[ 
	Limpia partículas que han excedido su lifetime
]]
function ParticlesManager:CleanupExpiredParticles()
	local currentTime = tick()
	local i = 1
	
	while i <= #activeParticles do
		local data = activeParticles[i]
		
		if currentTime - data.timestamp >= data.lifetime then
			-- Devolver al pool
			self:ReturnToPool(data.attachment)
			table.remove(activeParticles, i)
			particleCount = particleCount - 1
		else
			i = i + 1
		end
	end
end

--[[ 
	Limpia todas las partículas activas inmediatamente
]]
function ParticlesManager:CleanupAll()
	for _, data in ipairs(activeParticles) do
		self:ReturnToPool(data.attachment)
	end
	
	activeParticles = {}
	particleCount = 0
	print("[ParticlesManager] Todas las partículas limpiadas")
end

--[[ 
	Obtiene estadísticas del sistema
	@return table - Estadísticas actuales
]]
function ParticlesManager:GetStats()
	return {
		ActiveParticles = particleCount,
		PoolSize = #particlePool,
		MaxParticles = CONFIG.MaxActiveParticles,
		AvailablePresets = #EFFECT_PRESETS
	}
end

return ParticlesManager
