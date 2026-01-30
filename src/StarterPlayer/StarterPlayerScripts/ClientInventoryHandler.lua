--[[
	ClientInventoryHandler - Manejo de inventario del lado del cliente
	
	Gestiona la interfaz y las interacciones del inventario.
	Se comunica con el servidor para operaciones seguras.
	
	Autor: 4GP
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local ClientInventoryHandler = {}

-- Cache local del inventario
local inventoryCache = {}
local isInventoryOpen = false

-- Inicializar
function ClientInventoryHandler:Initialize()
	-- Solicitar inventario inicial
	self:RequestInventoryUpdate()
	
	print("[ClientInventory] Inicializado")
end

-- Solicitar actualización del inventario
function ClientInventoryHandler:RequestInventoryUpdate()
	local getInventoryFunction = remoteEvents:WaitForChild("GetInventory", 5)
	if not getInventoryFunction then return end
	
	local result = getInventoryFunction:InvokeServer()
	
	if result and result.Success then
		inventoryCache = result.Inventory
		self:UpdateUI()
	end
end

-- Usar item
function ClientInventoryHandler:UseItem(slotIndex)
	local useItemEvent = remoteEvents:WaitForChild("UseItem", 5)
	if not useItemEvent then return end
	
	useItemEvent:FireServer(slotIndex)
end

-- Mover item
function ClientInventoryHandler:MoveItem(fromSlot, toSlot)
	local moveItemEvent = remoteEvents:WaitForChild("MoveItem", 5)
	if not moveItemEvent then return end
	
	moveItemEvent:FireServer(fromSlot, toSlot)
end

-- Actualizar UI (placeholder - implementarías tu UI aquí)
function ClientInventoryHandler:UpdateUI()
	-- Aquí irían las actualizaciones de tu GUI
	print("[ClientInventory] UI actualizada")
end

-- Toggle inventario
function ClientInventoryHandler:ToggleInventory()
	isInventoryOpen = not isInventoryOpen
	-- Mostrar/ocultar GUI
end

return ClientInventoryHandler
