-- LeaderboardService
-- Orchestrates DataStore saving, score auto-tracking, periodic refresh,
-- and coordinates the Gui + Podium modules.
--
-- Public API (call from other server scripts when needed):
--   LeaderboardService.init()                     → starts everything
--   LeaderboardService.setScore(player, value)    → manual score override / escape hatch

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.LeaderboardConfig)
local Gui = require(script.Parent.LeaderboardGui)
local Podium = require(script.Parent.LeaderboardPodium)

local LeaderboardService = {}

-- ── State ─────────────────────────────────────────────────────────

local dataStore: OrderedDataStore
local guiHandle: { [string]: any }

-- Read strategy once so the type checker sees a plain string, not a table key.
local SCORE_STRATEGY: string = (Config :: any).scoreStrategy or "always"

-- Debounce tracking per player
local lastSaved: { [Player]: number } = {} -- tick() of last successful save
local pendingTask: { [Player]: thread? } = {} -- scheduled task.delay thread
local lastValue: { [Player]: number } = {} -- most recent known score

-- Username cache to avoid repeated GetNameFromUserIdAsync calls
local usernameCache: { [number]: string } = {}

-- Countdown ticker thread (cancelled and restarted on each refresh)
local countdownThread: thread? = nil

-- All-time peak per player (only used when scoreStrategy == "max").
-- Loaded from DataStore on join so comparisons are against the true lifetime record.
local sessionPeak: { [Player]: number } = {}

-- ── DataStore helpers ─────────────────────────────────────────────

local SAVE_COOLDOWN = 6 -- seconds

local function _doSave(player: Player, value: number)
	-- "max" strategy: only write if the new value beats the stored all-time peak
	if SCORE_STRATEGY == "max" then
		if value <= (sessionPeak[player] or 0) then
			return -- not a new record, skip the write
		end
		sessionPeak[player] = value -- update in-memory peak before writing
	end

	local userId = player.UserId
	local ok, err = pcall(function()
		dataStore:SetAsync(tostring(userId), math.floor(value))
	end)
	if ok then
		lastSaved[player] = tick()
		pendingTask[player] = nil
	else
		warn("[LeaderboardService] Failed to save score for", player.Name, "–", err)
	end
end

local function _scheduleSave(player: Player, value: number)
	lastValue[player] = value

	local elapsed = tick() - (lastSaved[player] or 0)

	if elapsed >= SAVE_COOLDOWN then
		-- Enough time has passed → save immediately
		_doSave(player, value)
	else
		-- Cancel any previously scheduled save for this player
		local pending = pendingTask[player]
		if pending then
			task.cancel(pending)
			pendingTask[player] = nil
		end

		-- Schedule a save for when the cooldown expires
		local remaining = SAVE_COOLDOWN - elapsed
		pendingTask[player] = task.delay(remaining, function()
			if player and player.Parent then -- still in game
				_doSave(player, lastValue[player])
			end
		end)
	end
end

-- ── Username resolution ───────────────────────────────────────────

local function _getUsername(userId: number): string
	-- Negative userIds are fake/seed entries; resolve from config seedData
	-- instead of calling the Roblox API (which would fail for negative IDs).
	if userId < 0 then
		local seedData = (Config :: any).seedData
		if seedData then
			local entry = seedData[-userId]
			if entry then
				return entry.name
			end
		end
		return "Player " .. userId
	end

	if usernameCache[userId] then
		return usernameCache[userId]
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	local resolved = if ok and name then name else ("Player " .. userId)
	usernameCache[userId] = resolved
	return resolved
end

-- ── Leaderboard refresh ───────────────────────────────────────────

local function _fetchTopEntries(): { { [string]: any } }
	local entries = {}

	local ok, pages = pcall(function()
		return dataStore:GetSortedAsync(false, Config.maxEntries)
	end)
	if not ok then
		warn("[LeaderboardService] GetSortedAsync failed –", pages)
		return entries
	end

	local rank = 0
	local page = pages:GetCurrentPage()
	for _, item in page do
		rank += 1
		local userId = tonumber(item.key)
		local score = item.value

		if userId then
			table.insert(entries, {
				rank = rank,
				userId = userId,
				name = _getUsername(userId),
				score = score,
			})
		end
	end

	return entries
end

local function _refresh()
	-- Cancel the previous countdown ticker before starting a new refresh
	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end

	local entries = _fetchTopEntries()

	-- Update board GUI
	Gui.update(guiHandle, entries)

	-- Update podium rigs (top 3 only)
	local top3 = { entries[1], entries[2], entries[3] }
	Podium.update(top3)

	-- Start a per-second countdown ticker for this interval
	local interval = Config.refreshInterval
	countdownThread = task.spawn(function()
		for remaining = interval, 0, -1 do
			Gui.setCountdown(guiHandle, remaining)
			if remaining > 0 then
				task.wait(1)
			end
		end
	end)

	-- Schedule next refresh
	task.delay(interval, _refresh)
end

-- ── Player tracking ───────────────────────────────────────────────

local function _trackPlayer(player: Player)
	-- Wait for leaderstats and the specific stat value
	local leaderstats = player:WaitForChild("leaderstats", 30)
	if not leaderstats then
		warn("[LeaderboardService] No leaderstats found for", player.Name)
		return
	end

	local statValue = leaderstats:WaitForChild(Config.statName, 30)
	if not statValue then
		warn("[LeaderboardService] No stat '" .. Config.statName .. "' found for", player.Name)
		return
	end

	-- Initialise last-saved time so first change is compared to "never saved"
	lastSaved[player] = 0

	-- For "max" strategy, load the player's existing DataStore record so future
	-- values are compared against their true all-time peak, not just this session.
	if SCORE_STRATEGY == "max" then
		local peakOk, stored = pcall(function()
			return dataStore:GetAsync(tostring(player.UserId))
		end)
		sessionPeak[player] = if peakOk and stored then stored else 0
	end

	-- Save when the value changes
	print("Tracking player", player.Name, "with initial score", statValue.Value)
	statValue.Changed:Connect(function(newValue: number)
		_scheduleSave(player, newValue)
	end)
end

local function _onPlayerRemoving(player: Player)
	-- Cancel any pending scheduled save
	local pending = pendingTask[player]
	if pending then
		task.cancel(pending)
		pendingTask[player] = nil
	end

	-- Always save the final score before the player leaves
	local value = lastValue[player]
	if value then
		_doSave(player, value)
	end

	-- Clean up tables
	lastSaved[player] = nil
	lastValue[player] = nil
	pendingTask[player] = nil
	sessionPeak[player] = nil
end

-- ── Public API ────────────────────────────────────────────────────

-- Populates the DataStore with fake entries from LeaderboardConfig.seedData.
-- Call this once from init.server.luau when launching a new game so the board
-- is never empty. Safe to call on every server start — it always overwrites
-- the fake entries with the configured scores, so you can update them by
-- changing the config and redeploying.
--
-- Fake entries use negative integer DataStore keys (-1, -2, …) which never
-- clash with real player UserIds. Real players displace fakes naturally
-- as their scores rank higher.
function LeaderboardService.seedLeaderboard()
	local seedData = (Config :: any).seedData
	if not seedData then
		warn("[LeaderboardService] seedLeaderboard() called but LeaderboardConfig.seedData is nil.")
		return
	end

	for i, entry in seedData do
		local fakeKey = tostring(-i)
		local ok, err = pcall(function()
			dataStore:SetAsync(fakeKey, math.floor(entry.score))
		end)
		if ok then
			print("[LeaderboardService] Seeded fake entry #" .. i .. " '" .. entry.name .. "' → " .. entry.score)
		else
			warn("[LeaderboardService] Failed to seed '" .. entry.name .. "' –", err)
		end
	end
end

-- Manual score override. Saves immediately and resets the debounce timer.
-- Use this when you need to set a score from outside the leaderstats system.
function LeaderboardService.setScore(player: Player, value: number)
	lastValue[player] = value

	-- Cancel any pending scheduled save
	local pending = pendingTask[player]
	if pending then
		task.cancel(pending)
		pendingTask[player] = nil
	end

	_doSave(player, value)
end

-- Writes a score directly to the DataStore for any userId, whether or not
-- that player is currently in the server. Useful for seeding friend/family
-- scores before launch:
--   LeaderboardService.setScoreByUserId(1234567890, 50000)
-- Respects the "max" strategy — won't overwrite a higher existing record.
function LeaderboardService.setScoreByUserId(userId: number, value: number)
	local key = tostring(userId)

	if SCORE_STRATEGY == "max" then
		local ok, stored = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok and stored and stored >= math.floor(value) then
			return -- existing record is already higher, don't overwrite
		end
	end

	local ok, err = pcall(function()
		dataStore:SetAsync(key, math.floor(value))
	end)
	if ok then
		print("[LeaderboardService] setScoreByUserId:", userId, "→", value)
	else
		warn("[LeaderboardService] setScoreByUserId failed for", userId, "–", err)
	end
end

-- Entry point. Call once from init.server.luau.
function LeaderboardService.init()
	dataStore = DataStoreService:GetOrderedDataStore(Config.dataStoreKey)

	-- Build the physical board and podium platforms
	guiHandle = Gui.build()
	Podium.build()

	-- Connect player events
	Players.PlayerAdded:Connect(function(player)
		task.spawn(_trackPlayer, player)
	end)

	-- Handle players who joined before this script ran (shouldn't normally happen
	-- in production, but useful when testing in Studio with already-joined players)
	for _, player in Players:GetPlayers() do
		task.spawn(_trackPlayer, player)
	end

	Players.PlayerRemoving:Connect(_onPlayerRemoving)

	-- Initial board fetch (slight delay to let DataStore settle on server start)
	task.delay(3, _refresh)
end

return LeaderboardService
