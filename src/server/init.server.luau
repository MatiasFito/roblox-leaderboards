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
		diamonds.Value = 70
	end)
end)

local LeaderboardService = require(script.LeaderboardService)
LeaderboardService.init()
LeaderboardService.seedLeaderboard()

-- Example to add score to a player (replace with actual UserId and desired score):
-- To add score to Farty run the following in a command bar or script:
-- require(game.ServerScriptService.Server.LeaderboardService).setScoreByUserId(4565655254, 50000)
