-- LeaderboardConfig
-- ═══════════════════════════════════════════════════════════════
-- The ONLY file you need to edit when setting up a new leaderboard.
-- All other modules read from this config automatically.
-- ═══════════════════════════════════════════════════════════════

local LeaderboardConfig = {}

-- ── Score Strategy ────────────────────────────────────────────────
-- Controls when this leaderboard's DataStore record is overwritten.
--
--   "always"  → always save the current stat value, even if it went down.
--               Use for leaderboards that reflect the CURRENT state of a stat
--               (e.g. "who has the most gold right now").
--
--   "max"     → only save when the new value EXCEEDS the stored record.
--               The leaderboard score never goes down.
--               Use for "best ever" leaderboards (e.g. "highest gold held at once",
--               "most trees chopped all time").
LeaderboardConfig.scoreStrategy = "max" -- "always" | "max"

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

-- ── Seed Data ───────────────────────────────────────────────────
-- Optional fake entries to pre-populate the leaderboard on new games,
-- so the board never looks empty before real players have played.
--
-- Entries are written to the DataStore with special negative-ID keys that
-- never clash with real player UserIds. Real players displace them naturally
-- once their scores rank higher.
--
-- Scores should be realistic but beatable. Order doesn't matter — the
-- DataStore sorts by score automatically.
--
-- To use: uncomment and fill in the table, then call
--   LeaderboardService.seedLeaderboard() from your init.server.luau.
-- To clear seed data: delete the entries and change dataStoreKey to start fresh.
LeaderboardConfig.seedData = nil
-- LeaderboardConfig.seedData = {
-- 	{ name = "DiamondKing", score = 50000 },
-- 	{ name = "GemHunter", score = 38000 },
-- 	{ name = "SparkleQueen", score = 27500 },
-- 	{ name = "RockStar", score = 19000 },
-- 	{ name = "CrystalFox", score = 12000 },
-- }

return LeaderboardConfig
