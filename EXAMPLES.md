# Ejemplos de Uso - Roblox Game Systems

Guía práctica con ejemplos de implementación de cada sistema.

## 📦 Sistema de Inventario

### Ejemplo Completo de Servidor

```lua
-- En ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)

-- Crear inventario para un jugador
local playerInventories = {}

game.Players.PlayerAdded:Connect(function(player)
    -- Crear inventario con 20 slots
    local inventory = InventoryModule.new({ MaxSlots = 20 })
    
    -- Añadir items iniciales
    inventory:AddItem("health_potion", 3)
    inventory:AddItem("iron_sword", 1)
    
    playerInventories[player.UserId] = inventory
    
    -- Cuando el jugador recolecta algo
    local function onItemPickup(itemId, quantity)
        local success, message = inventory:AddItem(itemId, quantity)
        if success then
            print(player.Name .. " recolectó " .. quantity .. "x " .. itemId)
        else
            print("Inventario lleno!")
        end
    end
end)
```

### Cliente: Mostrar Inventario

```lua
-- En StarterPlayerScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

local function updateInventoryUI(inventoryData)
    for slot, data in pairs(inventoryData) do
        if data.ItemId then
            print("Slot " .. slot .. ": " .. data.ItemId .. " x" .. data.Quantity)
            -- Aquí actualizarías tu GUI
        end
    end
end

-- Solicitar inventario al servidor
local getInventoryFunction = ReplicatedStorage.RemoteEvents:WaitForChild("GetInventory")
local result = getInventoryFunction:InvokeServer()

if result.Success then
    updateInventoryUI(result.Inventory)
end
```

## ⚔️ Sistema de Combate

### Implementación de Ataque Melee

```lua
-- En ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatModule = require(ReplicatedStorage.Modules.CombatModule)
local EventsManager = require(script.Parent.EventsManager)

EventsManager:Initialize()

EventsManager:CreateEvent("MeleeAttack", function(player, targetName)
    local character = player.Character
    if not character then return end
    
    -- Encontrar target
    local target = workspace:FindFirstChild(targetName)
    if not target or not target:FindFirstChildOfClass("Humanoid") then return end
    
    -- Validar distancia (anti-exploit)
    local playerHRP = character:FindFirstChild("HumanoidRootPart")
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    
    if not playerHRP or not targetHRP then return end
    
    local distance = (playerHRP.Position - targetHRP.Position).Magnitude
    if distance > 10 then 
        print("Jugador muy lejos del target - posible exploit")
        return 
    end
    
    -- Realizar ataque
    local weapon = character:FindFirstChild("Weapon") -- Tu arma equipada
    local success, message, info = CombatModule:MeleeAttack(
        character,
        target,
        weapon,
        1  -- cooldown de 1 segundo
    )
    
    if success then
        -- Notificar al cliente
        EventsManager:FireClient("CombatFeedback", player, {
            Damage = info.Damage,
            IsCritical = info.DamageInfo.IsCritical,
            ComboCount = info.DamageInfo.ComboCount
        })
        
        print(string.format(
            "%s golpeó a %s por %d de daño (Combo x%d)",
            player.Name,
            targetName,
            info.Damage,
            info.DamageInfo.ComboCount
        ))
    end
end)
```

### Cliente: Input de Ataque

```lua
-- En StarterPlayerScripts
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer

local attackEvent = ReplicatedStorage.RemoteEvents:WaitForChild("MeleeAttack")
local canAttack = true
local attackCooldown = 0.5

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E and canAttack then
        canAttack = false
        
        -- Encontrar enemigo más cercano (ejemplo simple)
        local character = player.Character
        if not character then return end
        
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local closestEnemy = nil
        local closestDistance = 10
        
        for _, model in pairs(workspace:GetChildren()) do
            if model:FindFirstChild("Humanoid") and model ~= character then
                local enemyHRP = model:FindFirstChild("HumanoidRootPart")
                if enemyHRP then
                    local distance = (hrp.Position - enemyHRP.Position).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestEnemy = model
                    end
                end
            end
        end
        
        if closestEnemy then
            attackEvent:FireServer(closestEnemy.Name)
        end
        
        task.wait(attackCooldown)
        canAttack = true
    end
end)
```

## 🌟 Sistema de Skills

### Servidor: Setup de Skills

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillsModule = require(ReplicatedStorage.Modules.SkillsModule)
local EventsManager = require(script.Parent.EventsManager)

local playerSkills = {}

game.Players.PlayerAdded:Connect(function(player)
    -- Crear sistema de skills
    local skills = SkillsModule.new()
    skills:InitializePlayerSkills(player.UserId, nil)
    
    -- Equipar skills iniciales
    skills:ToggleSkillEquip(player.UserId, "fireball")
    skills:ToggleSkillEquip(player.UserId, "heal")
    
    playerSkills[player.UserId] = skills
    
    -- Configurar recursos
    player:SetAttribute("Mana", 100)
    player:SetAttribute("MaxMana", 100)
    player:SetAttribute("Stamina", 100)
    player:SetAttribute("MaxStamina", 100)
end)

-- Evento para activar skill
EventsManager:CreateEvent("UseSkill", function(player, skillId, targetData)
    local skills = playerSkills[player.UserId]
    if not skills then return end
    
    local success, message, info = skills:ActivateSkill(player, skillId, targetData)
    
    if success then
        print(player.Name .. " usó " .. skillId)
        
        -- Notificar éxito
        EventsManager:FireClient("SkillSuccess", player, {
            SkillId = skillId,
            Cooldown = info.SkillInfo.Cooldown
        })
        
        -- Efectos visuales a todos
        EventsManager:FireAllClients("SkillEffect", {
            Player = player.Name,
            SkillId = skillId,
            Position = player.Character.HumanoidRootPart.Position
        })
    else
        EventsManager:FireClient("SkillFailed", player, {
            SkillId = skillId,
            Reason = message
        })
    end
end)
```

### Cliente: UI de Skills

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

local useSkillEvent = ReplicatedStorage.RemoteEvents:WaitForChild("UseSkill")

-- Hotkeys para skills
local skillHotkeys = {
    [Enum.KeyCode.Q] = "fireball",
    [Enum.KeyCode.E] = "heal",
    [Enum.KeyCode.R] = "dash",
    [Enum.KeyCode.F] = "shield"
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local skillId = skillHotkeys[input.KeyCode]
    if skillId then
        -- Obtener dirección del mouse
        local mouse = player:GetMouse()
        local character = player.Character
        if not character then return end
        
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local direction = (mouse.Hit.Position - hrp.Position).Unit
        
        useSkillEvent:FireServer(skillId, {
            Direction = direction,
            Position = mouse.Hit.Position
        })
    end
end)

-- Escuchar resultado
ReplicatedStorage.RemoteEvents.SkillSuccess.OnClientEvent:Connect(function(data)
    print("Skill " .. data.SkillId .. " activada! Cooldown: " .. data.Cooldown .. "s")
    -- Actualizar UI de cooldown
end)

ReplicatedStorage.RemoteEvents.SkillFailed.OnClientEvent:Connect(function(data)
    warn("Skill falló: " .. data.Reason)
    -- Mostrar mensaje de error
end)
```

## 📋 Sistema de Quests

### Implementación Completa

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestModule = require(ReplicatedStorage.Modules.QuestModule)
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)
local DataManager = require(script.Parent.DataManager)

local playerQuests = {}
local playerInventories = {}

game.Players.PlayerAdded:Connect(function(player)
    -- Inicializar quest system
    local quests = QuestModule.new()
    local data = DataManager:GetData(player)
    
    quests:InitializePlayerQuests(player.UserId, data.Quests)
    playerQuests[player.UserId] = quests
    
    -- Cuando mata un enemigo
    local function onEnemyKilled(enemyName)
        quests:OnPlayerKill(player.UserId, enemyName)
        
        -- Verificar quests completadas
        local activeQuests = quests:GetActiveQuests(player.UserId)
        for _, quest in ipairs(activeQuests) do
            if quest.AllObjectivesCompleted then
                -- Dar recompensas
                local success = quests:CompleteQuest(player.UserId, quest.QuestId, function(rewards)
                    if rewards.Coins then
                        DataManager:IncrementValue(player, "Coins", rewards.Coins)
                    end
                    
                    if rewards.Experience then
                        DataManager:IncrementValue(player, "Experience", rewards.Experience)
                    end
                    
                    if rewards.Items then
                        local inventory = playerInventories[player.UserId]
                        for _, item in ipairs(rewards.Items) do
                            inventory:AddItem(item.ItemId, item.Quantity)
                        end
                    end
                end)
                
                if success then
                    print(player.Name .. " completó quest: " .. quest.Name)
                end
            end
        end
    end
end)
```

## 💾 Sistema de Data Persistence

### Guardado Automático

```lua
local DataManager = require(script.Parent.DataManager)
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)

DataManager:Initialize()

local playerInventories = {}

game.Players.PlayerAdded:Connect(function(player)
    -- Cargar datos
    local data = DataManager:LoadData(player)
    
    -- Crear inventario desde datos guardados
    local inventory = InventoryModule.new({ MaxSlots = 20 })
    if data.Inventory then
        inventory:LoadFromData(data.Inventory)
    end
    playerInventories[player.UserId] = inventory
    
    print("Datos cargados para " .. player.Name)
    print("Coins: " .. data.Coins)
    print("Level: " .. data.Level)
end)

-- Guardar inventario cuando cambia
local function saveInventory(player)
    local inventory = playerInventories[player.UserId]
    if inventory then
        DataManager:UpdateValue(player, "Inventory", inventory:ExportData())
    end
end

-- Cuando añade item
local function onItemAdded(player, itemId, quantity)
    local inventory = playerInventories[player.UserId]
    inventory:AddItem(itemId, quantity)
    saveInventory(player)
end
```

## 🛒 Sistema de Shop

### Tienda Completa

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopModule = require(ReplicatedStorage.Modules.ShopModule)
local EventsManager = require(script.Parent.EventsManager)

local shop = ShopModule.new()
local playerInventories = {}

-- Obtener catálogo
EventsManager:CreateFunction("GetShopCatalog", function(player, category)
    return {
        Success = true,
        Catalog = shop:GetCatalog(category)
    }
end)

-- Comprar item
EventsManager:CreateFunction("PurchaseItem", function(player, itemId, quantity)
    local inventory = playerInventories[player.UserId]
    
    local success, message, info = shop:Purchase(player, itemId, quantity, inventory)
    
    if success then
        print(player.Name .. " compró " .. quantity .. "x " .. itemId .. " por " .. info.Price .. " " .. info.Currency)
    end
    
    return {
        Success = success,
        Message = message,
        Info = info
    }
end)

-- Vender item
EventsManager:CreateFunction("SellItem", function(player, itemId, quantity)
    local inventory = playerInventories[player.UserId]
    
    local success, message, info = shop:Sell(player, itemId, quantity, inventory)
    
    return {
        Success = success,
        Message = message,
        Info = info
    }
end)
```

---

**Nota**: Todos estos ejemplos son funcionales y pueden ser integrados directamente en tu juego de Roblox. Adapta según tus necesidades específicas.
