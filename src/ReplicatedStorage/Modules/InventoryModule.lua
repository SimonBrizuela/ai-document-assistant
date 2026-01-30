--[[
	InventoryModule - Sistema de inventario modular
	
	Gestiona items, slots, stack limits y operaciones de inventario.
	Compatible con cualquier tipo de item (armas, consumibles, materiales, etc).
	
	Autor: 4GP
]]

local InventoryModule = {}
InventoryModule.__index = InventoryModule

-- Configuración por defecto
local DEFAULT_CONFIG = {
	MaxSlots = 20,
	DefaultStackLimit = 99
}

-- Definición de items (esto normalmente vendría de un módulo separado)
local ITEM_REGISTRY = {
	["health_potion"] = {
		Name = "Health Potion",
		Description = "Restaura 50 HP",
		MaxStack = 10,
		Type = "Consumable",
		Rarity = "Common"
	},
	["iron_sword"] = {
		Name = "Iron Sword",
		Description = "Una espada básica de hierro",
		MaxStack = 1,
		Type = "Weapon",
		Rarity = "Common",
		Damage = 25
	},
	["gold_coin"] = {
		Name = "Gold Coin",
		Description = "Moneda de oro",
		MaxStack = 999,
		Type = "Currency",
		Rarity = "Common"
	},
	["diamond"] = {
		Name = "Diamond",
		Description = "Gema preciosa",
		MaxStack = 64,
		Type = "Material",
		Rarity = "Rare"
	}
}

-- Crear nueva instancia de inventario
function InventoryModule.new(config)
	local self = setmetatable({}, InventoryModule)
	
	config = config or {}
	self.MaxSlots = config.MaxSlots or DEFAULT_CONFIG.MaxSlots
	self.DefaultStackLimit = config.DefaultStackLimit or DEFAULT_CONFIG.DefaultStackLimit
	self.Slots = {}
	
	-- Inicializar slots vacíos
	for i = 1, self.MaxSlots do
		self.Slots[i] = {
			ItemId = nil,
			Quantity = 0,
			Metadata = {}
		}
	end
	
	return self
end

-- Cargar inventario desde datos guardados
function InventoryModule:LoadFromData(data)
	if not data or type(data) ~= "table" then return end
	
	for i, slotData in pairs(data) do
		if self.Slots[i] then
			self.Slots[i] = {
				ItemId = slotData.ItemId,
				Quantity = slotData.Quantity or 0,
				Metadata = slotData.Metadata or {}
			}
		end
	end
end

-- Exportar inventario a formato guardable
function InventoryModule:ExportData()
	local data = {}
	
	for i, slot in pairs(self.Slots) do
		if slot.ItemId then
			data[i] = {
				ItemId = slot.ItemId,
				Quantity = slot.Quantity,
				Metadata = slot.Metadata
			}
		end
	end
	
	return data
end

-- Obtener información de un item
function InventoryModule:GetItemInfo(itemId)
	return ITEM_REGISTRY[itemId]
end

-- Verificar si un item existe
function InventoryModule:ItemExists(itemId)
	return ITEM_REGISTRY[itemId] ~= nil
end

-- Añadir item al inventario
function InventoryModule:AddItem(itemId, quantity, metadata)
	if not self:ItemExists(itemId) then
		warn(("[InventoryModule] Item no existe: %s"):format(tostring(itemId)))
		return false, "Item no existe"
	end
	
	quantity = quantity or 1
	metadata = metadata or {}
	
	local itemInfo = self:GetItemInfo(itemId)
	local maxStack = itemInfo.MaxStack or self.DefaultStackLimit
	local remainingQuantity = quantity
	
	-- Primero intentar añadir a stacks existentes
	for i, slot in ipairs(self.Slots) do
		if slot.ItemId == itemId and slot.Quantity < maxStack then
			local canAdd = math.min(maxStack - slot.Quantity, remainingQuantity)
			slot.Quantity = slot.Quantity + canAdd
			remainingQuantity = remainingQuantity - canAdd
			
			if remainingQuantity <= 0 then
				return true, "Item añadido"
			end
		end
	end
	
	-- Luego usar slots vacíos
	for i, slot in ipairs(self.Slots) do
		if not slot.ItemId or slot.Quantity == 0 then
			local canAdd = math.min(maxStack, remainingQuantity)
			slot.ItemId = itemId
			slot.Quantity = canAdd
			slot.Metadata = metadata
			remainingQuantity = remainingQuantity - canAdd
			
			if remainingQuantity <= 0 then
				return true, "Item añadido"
			end
		end
	end
	
	if remainingQuantity > 0 then
		return false, "Inventario lleno", (quantity - remainingQuantity)
	end
	
	return true, "Item añadido"
end

-- Remover item del inventario
function InventoryModule:RemoveItem(itemId, quantity)
	quantity = quantity or 1
	local removedQuantity = 0
	
	for i, slot in ipairs(self.Slots) do
		if slot.ItemId == itemId then
			local toRemove = math.min(slot.Quantity, quantity - removedQuantity)
			slot.Quantity = slot.Quantity - toRemove
			removedQuantity = removedQuantity + toRemove
			
			if slot.Quantity <= 0 then
				slot.ItemId = nil
				slot.Quantity = 0
				slot.Metadata = {}
			end
			
			if removedQuantity >= quantity then
				return true, "Item removido"
			end
		end
	end
	
	if removedQuantity > 0 then
		return false, "Cantidad insuficiente", removedQuantity
	end
	
	return false, "Item no encontrado"
end

-- Verificar si tiene item
function InventoryModule:HasItem(itemId, quantity)
	quantity = quantity or 1
	local total = 0
	
	for _, slot in ipairs(self.Slots) do
		if slot.ItemId == itemId then
			total = total + slot.Quantity
		end
	end
	
	return total >= quantity, total
end

-- Contar cantidad de un item
function InventoryModule:CountItem(itemId)
	local total = 0
	
	for _, slot in ipairs(self.Slots) do
		if slot.ItemId == itemId then
			total = total + slot.Quantity
		end
	end
	
	return total
end

-- Mover item entre slots
function InventoryModule:MoveItem(fromSlot, toSlot)
	if fromSlot < 1 or fromSlot > self.MaxSlots or toSlot < 1 or toSlot > self.MaxSlots then
		return false, "Slot inválido"
	end
	
	local from = self.Slots[fromSlot]
	local to = self.Slots[toSlot]
	
	if not from.ItemId then
		return false, "Slot origen vacío"
	end
	
	-- Si el slot destino está vacío, mover todo
	if not to.ItemId then
		to.ItemId = from.ItemId
		to.Quantity = from.Quantity
		to.Metadata = from.Metadata
		
		from.ItemId = nil
		from.Quantity = 0
		from.Metadata = {}
		
		return true, "Item movido"
	end
	
	-- Si son el mismo item, intentar stackear
	if to.ItemId == from.ItemId then
		local itemInfo = self:GetItemInfo(to.ItemId)
		local maxStack = itemInfo.MaxStack or self.DefaultStackLimit
		
		local canAdd = math.min(maxStack - to.Quantity, from.Quantity)
		to.Quantity = to.Quantity + canAdd
		from.Quantity = from.Quantity - canAdd
		
		if from.Quantity <= 0 then
			from.ItemId = nil
			from.Quantity = 0
			from.Metadata = {}
		end
		
		return true, "Items stackeados"
	end
	
	-- Intercambiar slots
	local tempId = to.ItemId
	local tempQuantity = to.Quantity
	local tempMetadata = to.Metadata
	
	to.ItemId = from.ItemId
	to.Quantity = from.Quantity
	to.Metadata = from.Metadata
	
	from.ItemId = tempId
	from.Quantity = tempQuantity
	from.Metadata = tempMetadata
	
	return true, "Items intercambiados"
end

-- Obtener slots vacíos
function InventoryModule:GetEmptySlots()
	local empty = 0
	
	for _, slot in ipairs(self.Slots) do
		if not slot.ItemId or slot.Quantity == 0 then
			empty = empty + 1
		end
	end
	
	return empty
end

-- Limpiar inventario
function InventoryModule:Clear()
	for i = 1, self.MaxSlots do
		self.Slots[i] = {
			ItemId = nil,
			Quantity = 0,
			Metadata = {}
		}
	end
end

-- Obtener todos los items
function InventoryModule:GetAllItems()
	local items = {}
	
	for i, slot in ipairs(self.Slots) do
		if slot.ItemId then
			table.insert(items, {
				Slot = i,
				ItemId = slot.ItemId,
				Quantity = slot.Quantity,
				Metadata = slot.Metadata,
				Info = self:GetItemInfo(slot.ItemId)
			})
		end
	end
	
	return items
end

return InventoryModule
