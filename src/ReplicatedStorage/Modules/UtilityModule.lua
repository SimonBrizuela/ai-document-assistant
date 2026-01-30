--[[
	UtilityModule - Funciones auxiliares generales
	
	Colección de funciones útiles que se usan en varios sistemas.
	
	Autor: 4GP
]]

local UtilityModule = {}

-- Formatear números grandes (1000 -> 1K, 1000000 -> 1M)
function UtilityModule.FormatNumber(number)
	if number >= 1000000000 then
		return string.format("%.1fB", number / 1000000000)
	elseif number >= 1000000 then
		return string.format("%.1fM", number / 1000000)
	elseif number >= 1000 then
		return string.format("%.1fK", number / 1000)
	else
		return tostring(number)
	end
end

-- Formatear tiempo (segundos -> MM:SS)
function UtilityModule.FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

-- Interpolar entre dos valores
function UtilityModule.Lerp(a, b, t)
	return a + (b - a) * t
end

-- Clamp valor entre min y max
function UtilityModule.Clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

-- Obtener distancia entre dos posiciones
function UtilityModule.GetDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

-- Verificar si un jugador está vivo
function UtilityModule.IsPlayerAlive(player)
	local character = player.Character
	if not character then return false end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	return true
end

-- Obtener jugadores en un radio
function UtilityModule.GetPlayersInRadius(position, radius, excludePlayer)
	local players = {}
	
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player ~= excludePlayer then
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local distance = (hrp.Position - position).Magnitude
					if distance <= radius then
						table.insert(players, player)
					end
				end
			end
		end
	end
	
	return players
end

-- Shuffle tabla (Fisher-Yates)
function UtilityModule.ShuffleTable(tbl)
	local shuffled = {}
	for i, v in ipairs(tbl) do
		shuffled[i] = v
	end
	
	for i = #shuffled, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	
	return shuffled
end

-- Obtener elemento aleatorio de una tabla
function UtilityModule.GetRandomElement(tbl)
	if #tbl == 0 then return nil end
	return tbl[math.random(#tbl)]
end

-- Deep copy de tabla
function UtilityModule.DeepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = UtilityModule.DeepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Verificar si tabla contiene valor
function UtilityModule.TableContains(tbl, value)
	for _, v in pairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

-- Remover valor de tabla
function UtilityModule.TableRemove(tbl, value)
	for i, v in ipairs(tbl) do
		if v == value then
			table.remove(tbl, i)
			return true
		end
	end
	return false
end

-- Calcular porcentaje
function UtilityModule.GetPercentage(current, max)
	if max == 0 then return 0 end
	return (current / max) * 100
end

-- Chance (probabilidad)
function UtilityModule.Chance(percent)
	return math.random() < percent
end

-- Crear raycast params básicos
function UtilityModule.CreateRaycastParams(ignore)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = ignore or {}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	return params
end

-- Obtener dirección normalizada entre dos puntos
function UtilityModule.GetDirection(from, to)
	return (to - from).Unit
end

-- Calcular tiempo restante de cooldown
function UtilityModule.GetCooldownRemaining(endTime)
	local remaining = endTime - os.clock()
	return math.max(0, remaining)
end

-- Redondear número a decimales
function UtilityModule.Round(number, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(number * mult + 0.5) / mult
end

-- Crear instancia con propiedades
function UtilityModule.CreateInstance(className, properties)
	local instance = Instance.new(className)
	
	for property, value in pairs(properties) do
		if property ~= "Parent" then
			instance[property] = value
		end
	end
	
	if properties.Parent then
		instance.Parent = properties.Parent
	end
	
	return instance
end

-- Esperar con timeout
function UtilityModule.WaitForChildTimeout(parent, childName, timeout)
	local startTime = os.clock()
	
	while not parent:FindFirstChild(childName) do
		if os.clock() - startTime >= timeout then
			return nil
		end
		task.wait()
	end
	
	return parent:FindFirstChild(childName)
end

-- Generar ID único
function UtilityModule.GenerateId()
	return tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
end

-- Calcular XP necesaria para nivel
function UtilityModule.GetXPForLevel(level)
	return math.floor(100 * (level ^ 1.5))
end

-- Calcular nivel desde XP total
function UtilityModule.GetLevelFromXP(totalXP)
	local level = 1
	local xpNeeded = 0
	
	while xpNeeded <= totalXP do
		level = level + 1
		xpNeeded = xpNeeded + UtilityModule.GetXPForLevel(level)
	end
	
	return level - 1
end

-- Cooldown visual (retorna progreso 0-1)
function UtilityModule.GetCooldownProgress(startTime, duration)
	local elapsed = os.clock() - startTime
	local progress = math.clamp(elapsed / duration, 0, 1)
	return progress
end

-- Convertir RGB a Color3
function UtilityModule.RGBToColor3(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Obtener color por rareza
function UtilityModule.GetRarityColor(rarity)
	local colors = {
		Common = Color3.fromRGB(255, 255, 255),
		Uncommon = Color3.fromRGB(85, 255, 85),
		Rare = Color3.fromRGB(85, 170, 255),
		Epic = Color3.fromRGB(170, 85, 255),
		Legendary = Color3.fromRGB(255, 170, 0)
	}
	
	return colors[rarity] or colors.Common
end

return UtilityModule
