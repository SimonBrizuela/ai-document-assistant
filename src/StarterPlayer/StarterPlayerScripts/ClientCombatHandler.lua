--[[
	ClientCombatHandler - Manejo de combate del lado del cliente
	
	Gestiona inputs de combate, animaciones y feedback visual.
	Valida en servidor para evitar exploits.
	
	Autor: 4GP
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local ClientCombatHandler = {}

-- Estado local
local isAttacking = false
local lastAttackTime = 0
local comboCount = 0

-- Configuración
local CONFIG = {
	AttackCooldown = 0.5,
	ComboResetTime = 2
}

-- Realizar ataque
function ClientCombatHandler:PerformAttack(target)
	local currentTime = tick()
	
	-- Verificar cooldown local
	if currentTime - lastAttackTime < CONFIG.AttackCooldown then
		return
	end
	
	if isAttacking then
		return
	end
	
	isAttacking = true
	lastAttackTime = currentTime
	
	-- Actualizar combo
	if currentTime - lastAttackTime > CONFIG.ComboResetTime then
		comboCount = 0
	end
	comboCount = comboCount + 1
	
	-- Reproducir animación (placeholder)
	self:PlayAttackAnimation(comboCount)
	
	-- Enviar al servidor
	local attackEvent = remoteEvents:FindFirstChild("MeleeAttack")
	if attackEvent then
		attackEvent:FireServer(target)
	end
	
	task.wait(CONFIG.AttackCooldown)
	isAttacking = false
end

-- Reproducir animación de ataque
function ClientCombatHandler:PlayAttackAnimation(comboIndex)
	-- Aquí cargarías y reproducirías animaciones reales
	print(("[ClientCombat] Ataque #%d"):format(comboIndex))
end

-- Detectar target bajo el mouse
function ClientCombatHandler:GetTargetUnderMouse()
	local mouse = player:GetMouse()
	local target = mouse.Target
	
	if target then
		local model = target:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") and model ~= character then
			return model
		end
	end
	
	return nil
end

-- Setup de inputs
function ClientCombatHandler:SetupInputs()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local target = self:GetTargetUnderMouse()
			self:PerformAttack(target)
		end
	end)
end

-- Inicializar
function ClientCombatHandler:Initialize()
	self:SetupInputs()
	print("[ClientCombat] Inicializado")
end

return ClientCombatHandler
