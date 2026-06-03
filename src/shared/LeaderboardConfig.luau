-- LeaderboardConfig
-- ═══════════════════════════════════════════════════════════════
-- The ONLY file you need to edit when setting up a new leaderboard.
-- All other modules read from this config automatically.
-- ═══════════════════════════════════════════════════════════════

local LeaderboardConfig = {}

-- ── Stat ────────────────────────────────────────────────────────
-- Must match the name of a child inside the player's "leaderstats" folder.
-- This is also used as the board title and the OrderedDataStore key prefix.
LeaderboardConfig.statName = "Diamonds"

-- ── DataStore ────────────────────────────────────────────────────
-- Unique key for this leaderboard's OrderedDataStore.
-- Change this if you want a fresh leaderboard (e.g. for a new season).
LeaderboardConfig.dataStoreKey = "Leaderboard_Diamonds_v1"

-- ── Timing ───────────────────────────────────────────────────────
-- How often (in seconds) the board fetches fresh data from the DataStore.
LeaderboardConfig.refreshInterval = 60

-- How many players to show in the scrolling list (max 100, limited by OrderedDataStore).
LeaderboardConfig.maxEntries = 25

-- ── Board Placement ───────────────────────────────────────────────
-- CFrame and size of the board Part that will be created in Workspace.
-- Adjust these to position the board in your game world.
-- Size convention: Vector3.new(width, height, thickness)
--   The SurfaceGui renders on the Front face (-Z), so keep Z (thickness) small
--   and put the display width in X and display height in Y.
LeaderboardConfig.boardCFrame = CFrame.new(0, 10, -20)
LeaderboardConfig.boardSize = Vector3.new(20, 14, 0.5)

-- ── Podium Placement ─────────────────────────────────────────────
-- CFrame of the CENTER of the podium area (where the 1st-place platform sits).
-- 2nd and 3rd platforms are automatically offset left and right from this point.
LeaderboardConfig.podiumOriginCFrame = CFrame.new(0, 0, -35)

-- ── Animation ────────────────────────────────────────────────────
-- Animation played by the top-3 podium character rigs.
-- Default: Roblox "Robot Dance" (free, works on R15)
-- Replace with any AnimationId you have permissions to use.
LeaderboardConfig.danceAnimationId = "rbxassetid://507770239"

-- ── Theme ────────────────────────────────────────────────────────
-- Colors used throughout the board GUI.
LeaderboardConfig.theme = {
	backgroundColor = Color3.fromRGB(15, 15, 25), -- dark navy background
	headerColor = Color3.fromRGB(25, 25, 45), -- slightly lighter header band
	primaryColor = Color3.fromRGB(60, 120, 220), -- accent / highlight
	textColor = Color3.fromRGB(220, 220, 230), -- default row text
	dimTextColor = Color3.fromRGB(130, 130, 150), -- rank number, secondary info
	rowAltColor = Color3.fromRGB(20, 20, 35), -- alternating row tint
	goldColor = Color3.fromRGB(255, 215, 0), -- 1st place
	silverColor = Color3.fromRGB(192, 192, 192), -- 2nd place
	bronzeColor = Color3.fromRGB(205, 127, 50), -- 3rd place
	dividerColor = Color3.fromRGB(50, 50, 80), -- thin separator lines
}

return LeaderboardConfig
