--[[
	LeaderboardManager - Sistema de leaderboard
	
	Gestiona las stats que aparecen en el leaderboard de Roblox.
	
	Autor: 4GP
]]

local Players = game:GetService("Players")

local LeaderboardManager = {}

-- Configuración de stats
local STATS_CONFIG = {
	{
		Name = "Level",
		Type = "IntValue",
		DefaultValue = 1,
		Icon = "🌟"
	},
	{
		Name = "Coins",
		Type = "IntValue",
		DefaultValue = 0,
		Icon = "💰"
	},
	{
		Name = "Wins",
		Type = "IntValue",
		DefaultValue = 0,
		Icon = "🏆"
	},
	{
		Name = "KOs",
		Type = "IntValue",
		DefaultValue = 0,
		Icon = "⚔️"
	}
}

-- Crear leaderstats para un jugador
function LeaderboardManager:CreateLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	for _, config in ipairs(STATS_CONFIG) do
		local stat = Instance.new(config.Type)
		stat.Name = config.Name
		stat.Value = config.DefaultValue
		stat.Parent = leaderstats
	end
	
	leaderstats.Parent = player
	
	print(("[LeaderboardManager] Leaderstats creadas para %s"):format(player.Name))
end

-- Actualizar stat desde datos guardados
function LeaderboardManager:UpdateFromData(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	
	-- Actualizar level
	local levelStat = leaderstats:FindFirstChild("Level")
	if levelStat and data.Level then
		levelStat.Value = data.Level
	end
	
	-- Actualizar coins
	local coinsStat = leaderstats:FindFirstChild("Coins")
	if coinsStat and data.Coins then
		coinsStat.Value = data.Coins
	end
	
	-- Actualizar wins (ejemplo)
	local winsStat = leaderstats:FindFirstChild("Wins")
	if winsStat and data.Wins then
		winsStat.Value = data.Wins
	end
	
	-- Actualizar KOs (ejemplo)
	local kosStat = leaderstats:FindFirstChild("KOs")
	if kosStat and data.KOs then
		kosStat.Value = data.KOs
	end
end

-- Incrementar stat
function LeaderboardManager:IncrementStat(player, statName, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end
	
	local stat = leaderstats:FindFirstChild(statName)
	if not stat then return false end
	
	stat.Value = stat.Value + amount
	return true
end

-- Obtener stat
function LeaderboardManager:GetStat(player, statName)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return nil end
	
	local stat = leaderstats:FindFirstChild(statName)
	if not stat then return nil end
	
	return stat.Value
end

-- Establecer stat
function LeaderboardManager:SetStat(player, statName, value)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return false end
	
	local stat = leaderstats:FindFirstChild(statName)
	if not stat then return false end
	
	stat.Value = value
	return true
end

-- Inicializar sistema
function LeaderboardManager:Initialize()
	Players.PlayerAdded:Connect(function(player)
		self:CreateLeaderstats(player)
	end)
	
	print("[LeaderboardManager] Sistema inicializado")
end

return LeaderboardManager
