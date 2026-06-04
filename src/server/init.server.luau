game.Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Diamonds
	local diamonds = Instance.new("IntValue")
	diamonds.Name = "Diamonds"
	diamonds.Value = 100
	diamonds.Parent = leaderstats

	task.delay(3, function()
		diamonds.Value = 50
	end)
end)

local LeaderboardService = require(script.LeaderboardService)
LeaderboardService.init()
