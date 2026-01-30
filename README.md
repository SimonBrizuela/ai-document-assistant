# Roblox Game Systems - Portfolio

Colección de sistemas que hice para Roblox. Incluye inventario, combate, skills, guardado de datos, quests y más. Todo modular y listo para usar.

## 🎮 Características

### Sistemas Implementados

- **DataManager** - Sistema de persistencia con DataStores, autosave y manejo de errores robusto
- **InventoryModule** - Inventario modular con slots, stacking, categorías y operaciones de items
- **CombatModule** - Sistema de combate con daño, críticos, combos, knockback y cooldowns
- **SkillsModule** - Habilidades activables con costos de recursos, cooldowns y progresión
- **QuestModule** - Sistema de misiones con múltiples objetivos, tracking y recompensas
- **ShopModule** - Tienda con compra/venta, múltiples monedas y sistema de descuentos
- **EventsManager** - Gestión de RemoteEvents con rate limiting y validación server-side
- **ParticlesManager** ⭐ - VFX avanzado con object pooling, presets y auto-cleanup
- **NetworkModule** ⭐ - Comunicación red con rate limiting, retry logic y type validation
- **SpawnManager** ⭐ - Sistema de oleadas con dificultad dinámica, boss spawns y balanceo
- **AchievementManager** ⭐ - Logros con badges de Roblox, tracking persistente y recompensas automáticas

## 📁 Estructura del Proyecto

```
src/
├── ServerScriptService/
│   ├── DataManager.lua              # Persistencia de datos con DataStore
│   ├── EventsManager.lua            # Gestión de RemoteEvents
│   ├── LeaderboardManager.lua       # Sistema de rankings
│   ├── ServerInit.lua               # Inicialización del servidor
│   ├── SpawnManager.lua             # ⭐ Sistema de oleadas y spawns
│   └── AchievementManager.lua       # ⭐ Sistema de logros y badges
│
├── ReplicatedStorage/
│   └── Modules/
│       ├── InventoryModule.lua      # Sistema de inventario
│       ├── CombatModule.lua         # Sistema de combate
│       ├── SkillsModule.lua         # Sistema de habilidades
│       ├── QuestModule.lua          # Sistema de misiones
│       ├── ShopModule.lua           # Sistema de tienda
│       ├── UtilityModule.lua        # Funciones helper
│       ├── ParticlesManager.lua     # ⭐ Sistema de efectos visuales
│       └── NetworkModule.lua        # ⭐ Comunicación cliente-servidor
│
└── StarterPlayer/
    └── StarterPlayerScripts/
        ├── ClientInventoryHandler.lua  # Cliente inventario
        └── ClientCombatHandler.lua     # Cliente combate
```

## 🚀 Uso Rápido

### DataManager

```lua
local DataManager = require(ServerScriptService.DataManager)

-- Inicializar sistema
DataManager:Initialize()

-- Obtener datos de un jugador
local data = DataManager:GetData(player)

-- Actualizar valor
DataManager:UpdateValue(player, "Coins", 100)

-- Incrementar valor
DataManager:IncrementValue(player, "Experience", 50)
```

### InventoryModule

```lua
local InventoryModule = require(ReplicatedStorage.Modules.InventoryModule)

-- Crear inventario
local inventory = InventoryModule.new({ MaxSlots = 20 })

-- Añadir items
inventory:AddItem("health_potion", 5)
inventory:AddItem("iron_sword", 1)

-- Verificar si tiene item
local hasItem, count = inventory:HasItem("health_potion", 3)

-- Mover items entre slots
inventory:MoveItem(1, 5)

-- Exportar datos
local data = inventory:ExportData()
```

### CombatModule

```lua
local CombatModule = require(ReplicatedStorage.Modules.CombatModule)

-- Ataque melee
local success, message, info = CombatModule:MeleeAttack(
    attacker,
    target,
    weapon,
    1  -- cooldown
)

-- Calcular daño
local damage, damageInfo = CombatModule:CalculateDamage(
    attacker,
    target,
    baseDamage
)

-- Aplicar daño
CombatModule:ApplyDamage(target, damage, attacker, {
    Knockback = true,
    KnockbackForce = 50
})
```

### SkillsModule

```lua
local SkillsModule = require(ReplicatedStorage.Modules.SkillsModule)

-- Crear instancia
local skills = SkillsModule.new()

-- Inicializar skills del jugador
skills:InitializePlayerSkills(player.UserId, savedData)

-- Activar skill
local success, message, info = skills:ActivateSkill(
    player,
    "fireball",
    targetData
)

-- Verificar cooldown
local onCooldown, remaining = skills:IsOnCooldown(player.UserId, "fireball")
```

### EventsManager

```lua
local EventsManager = require(ServerScriptService.EventsManager)

-- Inicializar
EventsManager:Initialize()

-- Crear RemoteEvent
EventsManager:CreateEvent("PlayerAttack", function(player, target)
    -- Lógica del evento
end)

-- Crear RemoteFunction
EventsManager:CreateFunction("GetPlayerData", function(player)
    return { Success = true, Data = data }
end)

-- Enviar a cliente
EventsManager:FireClient("UpdateUI", player, uiData)

-- Enviar a todos
EventsManager:FireAllClients("GameEvent", eventData)
```

## 🛡️ Seguridad

- **Rate Limiting** - Para que no spameen eventos
- **Validación de distancia** - Anti-exploit en combate (no puedes pegar desde 1000 studs)
- **Manejo de errores** - PCalls en todo lo importante
- **Reintentos automáticos** - Si falla el DataStore, reintenta
- **Validación** - El servidor valida todo, no confío en el cliente

## 📊 Sistema de Data Persistence

El `DataManager` incluye:

- ✅ Autosave cada 3 minutos
- ✅ Guardado al salir del juego
- ✅ Guardado antes del cierre del servidor
- ✅ Sistema de reintentos con backoff
- ✅ Merge automático con template de datos
- ✅ Cache en memoria para acceso rápido

## 🎯 Sistema de Combat

Características del sistema de combate:

- Daño base + stats del jugador
- Sistema de defensa con reducción porcentual
- Críticos (15% chance, 1.5x multiplicador)
- Sistema de combos con bonificación
- Cooldowns por entidad
- Knockback configurable
- Stun temporal
- DOT (Damage Over Time)

## ⚡ Sistema de Skills

Skills implementados:

- **Fireball** - Proyectil de daño
- **Heal** - Curación
- **Dash** - Movimiento rápido
- **Shield** - Escudo temporal
- **Area Attack** - Daño en área

Cada skill incluye:
- Cooldown individual
- Costo de recursos (Mana/Stamina)
- Sistema de niveles (1-10)
- Bonuses por nivel
- Experiencia y progresión

## 📝 Sistema de Quests

- Tipos de objetivos: Kill, Collect, Distance, UseSkill
- Sistema de recompensas (Coins, XP, Items)
- Tracking automático de progreso
- Quests con requisitos de nivel
- Auto-accept para quests de tutorial

## 💰 Sistema de Shop

- Compra y venta de items
- Múltiples tipos de moneda
- Sistema de descuentos
- Stock configurable (finito o infinito)
- Categorías de items
- Precio de venta al 50% del precio de compra

## 🔧 Configuración

Cada módulo tiene una sección `CONFIG` al inicio para ajustar parámetros:

```lua
local CONFIG = {
    DataStoreName = "PlayerData_v1",
    AutoSaveInterval = 180,
    MaxRetries = 3
}
```

## 📈 Optimización

- Cacheo de datos en memoria para acceso rápido
- Limpieza automática de cooldowns viejos
- Task.spawn para no bloquear el thread principal
- Rate limiting para evitar spam
- Validaciones rápidas antes de procesar

## 🤝 Sobre el Proyecto

Portfolio personal que muestra lo que sé hacer:
- Sistemas modulares en Lua/Roblox
- Código escalable y organizado
- Seguridad y prevención de exploits
- Guardado de datos con DataStore
- RemoteEvents y comunicación cliente-servidor
- Optimización y código limpio

## 📚 Más Info

Si quieres ver más ejemplos:
- **[EXAMPLES.md](EXAMPLES.md)** - Ejemplos de cómo usar cada módulo

## 🌟 Lo Más Destacado

### ParticlesManager - VFX Optimizado
Sistema de efectos visuales que usa object pooling para no lagear. Incluye presets y limpieza automática.

### SpawnManager - Oleadas Dinámicas
Spawneo de enemigos que se adapta automáticamente a la cantidad de jugadores y oleada actual. Incluye sistema de boss cada 10 oleadas.

### AchievementManager - Logros
Sistema completo de logros con integración de badges de Roblox. Se guarda automáticamente en DataStore y da recompensas.

### NetworkModule - Comunicación Segura
Wrapper sobre RemoteEvents con rate limiting automático y validación de tipos. Previene exploits y spam.

## 📄 Licencia

Código de portfolio - Libre para uso educativo

---

**Hecho por 4GP** | 1 año y medio programando en Roblox
