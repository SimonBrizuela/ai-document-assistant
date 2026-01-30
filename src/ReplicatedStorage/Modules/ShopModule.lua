--[[
	ShopModule - Sistema de tienda
	
	Gestiona compras, ventas, monedas y verificación de transacciones.
	
	Autor: 4GP
]]

local ShopModule = {}
ShopModule.__index ShopModule

-- Catálogo de items en la tienda
local SHOP_CATALOG = {
	{
		ItemId = "health_potion",
		Price = 50,
		Currency = "Coins",
		Category = "Consumables",
		Stock = -1, -- -1 = infinito
		Discount = 0
	},
	{
		ItemId = "iron_sword",
		Price = 500,
		Currency = "Coins",
		Category = "Weapons",
		Stock = -1,
		Discount = 0
	},
	{
		ItemId = "diamond",
		Price = 1000,
		Currency = "Coins",
		Category = "Materials",
		Stock = -1,
		Discount = 0
	},
	{
		ItemId = "premium_pack",
		Price = 100,
		Currency = "Gems",
		Category = "Premium",
		Stock = -1,
		Discount = 0
	}
}

-- Precios de venta (% del precio de compra)
local SELL_RATE = 0.5

-- Crear nueva instancia
function ShopModule.new()
	local self = setmetatable({}, ShopModule)
	return self
end

-- Obtener catálogo completo
function ShopModule:GetCatalog(category)
	if category then
		local filtered = {}
		for _, item in ipairs(SHOP_CATALOG) do
			if item.Category == category then
				table.insert(filtered, item)
			end
		end
		return filtered
	end
	
	return SHOP_CATALOG
end

-- Obtener info de un item en la tienda
function ShopModule:GetShopItem(itemId)
	for _, item in ipairs(SHOP_CATALOG) do
		if item.ItemId == itemId then
			return item
		end
	end
	
	return nil
end

-- Calcular precio final con descuento
function ShopModule:GetFinalPrice(itemId, quantity)
	local shopItem = self:GetShopItem(itemId)
	if not shopItem then return nil end
	
	quantity = quantity or 1
	local basePrice = shopItem.Price * quantity
	local discount = shopItem.Discount or 0
	
	local finalPrice = math.floor(basePrice * (1 - discount))
	
	return finalPrice, shopItem.Currency
end

-- Verificar si el jugador puede comprar
function ShopModule:CanPurchase(player, itemId, quantity)
	local shopItem = self:GetShopItem(itemId)
	if not shopItem then
		return false, "Item no existe en la tienda"
	end
	
	quantity = quantity or 1
	
	-- Verificar stock
	if shopItem.Stock ~= -1 and shopItem.Stock < quantity then
		return false, "Stock insuficiente"
	end
	
	-- Verificar moneda
	local finalPrice, currency = self:GetFinalPrice(itemId, quantity)
	local playerCurrency = player:GetAttribute(currency) or 0
	
	if playerCurrency < finalPrice then
		return false, "Moneda insuficiente"
	end
	
	return true
end

-- Realizar compra
function ShopModule:Purchase(player, itemId, quantity, inventoryModule)
	quantity = quantity or 1
	
	-- Verificar si puede comprar
	local canPurchase, reason = self:CanPurchase(player, itemId, quantity)
	if not canPurchase then
		return false, reason
	end
	
	local shopItem = self:GetShopItem(itemId)
	local finalPrice, currency = self:GetFinalPrice(itemId, quantity)
	
	-- Deducir moneda
	local currentCurrency = player:GetAttribute(currency) or 0
	player:SetAttribute(currency, currentCurrency - finalPrice)
	
	-- Añadir item al inventario (si se proporciona)
	if inventoryModule then
		local success, message = inventoryModule:AddItem(itemId, quantity)
		if not success then
			-- Reembolsar si falla
			player:SetAttribute(currency, currentCurrency)
			return false, "Error añadiendo item: " .. message
		end
	end
	
	-- Reducir stock si no es infinito
	if shopItem.Stock ~= -1 then
		shopItem.Stock = shopItem.Stock - quantity
	end
	
	return true, "Compra exitosa", {
		ItemId = itemId,
		Quantity = quantity,
		Price = finalPrice,
		Currency = currency
	}
end

-- Calcular precio de venta
function ShopModule:GetSellPrice(itemId, quantity)
	local shopItem = self:GetShopItem(itemId)
	if not shopItem then return 0 end
	
	quantity = quantity or 1
	return math.floor(shopItem.Price * SELL_RATE * quantity), shopItem.Currency
end

-- Vender item
function ShopModule:Sell(player, itemId, quantity, inventoryModule)
	quantity = quantity or 1
	
	-- Verificar si tiene el item
	if inventoryModule then
		local hasItem, total = inventoryModule:HasItem(itemId, quantity)
		if not hasItem then
			return false, "No tienes suficientes items"
		end
		
		-- Remover item
		local success, message = inventoryModule:RemoveItem(itemId, quantity)
		if not success then
			return false, "Error removiendo item"
		end
	end
	
	-- Dar monedas
	local sellPrice, currency = self:GetSellPrice(itemId, quantity)
	local currentCurrency = player:GetAttribute(currency) or 0
	player:SetAttribute(currency, currentCurrency + sellPrice)
	
	return true, "Venta exitosa", {
		ItemId = itemId,
		Quantity = quantity,
		Price = sellPrice,
		Currency = currency
	}
end

-- Obtener categorías disponibles
function ShopModule:GetCategories()
	local categories = {}
	local seen = {}
	
	for _, item in ipairs(SHOP_CATALOG) do
		if not seen[item.Category] then
			table.insert(categories, item.Category)
			seen[item.Category] = true
		end
	end
	
	return categories
end

-- Aplicar descuento a un item
function ShopModule:ApplyDiscount(itemId, discountPercent)
	local shopItem = self:GetShopItem(itemId)
	if not shopItem then return false end
	
	shopItem.Discount = math.clamp(discountPercent, 0, 1)
	return true
end

-- Resetear descuentos
function ShopModule:ResetDiscounts()
	for _, item in ipairs(SHOP_CATALOG) do
		item.Discount = 0
	end
end

return ShopModule
