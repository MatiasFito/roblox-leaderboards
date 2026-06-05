-- LeaderboardGui
-- Builds and updates the SurfaceGui board entirely in code.
-- Called by LeaderboardService; never required by the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.LeaderboardConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)

local LeaderboardGui = {}

-- ── Internal helpers ─────────────────────────────────────────────

local function makeInstance(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	return inst
end

local function makeLabel(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Config.theme.textColor,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	return makeInstance("TextLabel", defaults) :: TextLabel
end

-- ── Public: build ────────────────────────────────────────────────

-- Creates the board Part in Workspace and populates it with a SurfaceGui.
-- Returns a "handle" table that update() uses to refresh text without
-- rebuilding the whole GUI.
function LeaderboardGui.build(): { [string]: any }
	local theme = Config.theme

	-- ── Board Part ───────────────────────────────────────────────
	local boardPart = makeInstance("Part", {
		Name = "LeaderboardBoard",
		CFrame = Config.boardCFrame,
		Size = Config.boardSize,
		Anchored = true,
		CanCollide = false,
		Material = Enum.Material.SmoothPlastic,
		Color = theme.backgroundColor,
		Parent = workspace,
	})

	-- ── SurfaceGui ───────────────────────────────────────────────
	-- Canvas is 800 wide × 1400 tall (arbitrary units; scaled by Roblox)
	local CANVAS_W, CANVAS_H = 800, 1400
	local gui = makeInstance("SurfaceGui", {
		Name = "LeaderboardSurfaceGui",
		Face = Enum.NormalId.Front,
		CanvasSize = Vector2.new(CANVAS_W, CANVAS_H),
		LightInfluence = 0,
		AlwaysOnTop = false,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		Parent = boardPart,
	}) :: SurfaceGui

	-- Root frame (fills entire canvas)
	local root = makeInstance("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.backgroundColor,
		BorderSizePixel = 0,
		Parent = gui,
	}) :: Frame

	-- ── Header ───────────────────────────────────────────────────
	local headerH = 130
	local header = makeInstance("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerH),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = theme.headerColor,
		BorderSizePixel = 0,
		Parent = root,
	}) :: Frame

	makeLabel({
		Name = "Title",
		Size = UDim2.fromScale(0.8, 1),
		Position = UDim2.fromScale(0.1, 0),
		Text = "🏆 " .. Config.statName,
		Font = Enum.Font.GothamBold,
		TextColor3 = theme.goldColor,
		Parent = header,
	})

	-- ── Podium Info (top-3 summary row) ──────────────────────────
	local podiumH = 240
	local podiumFrame = makeInstance("Frame", {
		Name = "PodiumInfo",
		Size = UDim2.new(1, 0, 0, podiumH),
		Position = UDim2.fromOffset(0, headerH),
		BackgroundColor3 = theme.headerColor,
		BorderSizePixel = 0,
		Parent = root,
	}) :: Frame

	-- Thin divider at bottom of podium info
	makeInstance("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = theme.dividerColor,
		BorderSizePixel = 0,
		Parent = podiumFrame,
	})

	local podiumSlotColors = {
		theme.goldColor,
		theme.silverColor,
		theme.bronzeColor,
	}
	local podiumMedals = { "🥇", "🥈", "🥉" }
	local podiumSlotWidth = 1 / 3

	-- We store refs to the name/score labels so update() can set them
	local podiumNameLabels = {}
	local podiumScoreLabels = {}

	for i = 1, 3 do
		local slotFrame = makeInstance("Frame", {
			Name = "PodiumSlot" .. i,
			Size = UDim2.new(podiumSlotWidth, -4, 1, -8),
			Position = UDim2.new((i - 1) * podiumSlotWidth, 2, 0, 4),
			BackgroundColor3 = theme.backgroundColor,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = podiumFrame,
		}) :: Frame
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = slotFrame })

		-- Medal / rank badge
		makeLabel({
			Name = "Medal",
			Size = UDim2.fromScale(1, 0.38),
			Position = UDim2.fromScale(0, 0),
			Text = podiumMedals[i],
			TextColor3 = podiumSlotColors[i],
			Parent = slotFrame,
		})

		-- Player name
		local nameLabel = makeLabel({
			Name = "Name",
			Size = UDim2.new(1, -8, 0.32, 0),
			Position = UDim2.new(0, 4, 0.38, 0),
			Text = "---",
			Font = Enum.Font.GothamBold,
			TextColor3 = podiumSlotColors[i],
			Parent = slotFrame,
		}) :: TextLabel
		podiumNameLabels[i] = nameLabel

		-- Score
		local scoreLabel = makeLabel({
			Name = "Score",
			Size = UDim2.new(1, -8, 0.28, 0),
			Position = UDim2.new(0, 4, 0.70, 0),
			Text = "---",
			Font = Enum.Font.Gotham,
			TextColor3 = theme.dimTextColor,
			Parent = slotFrame,
		}) :: TextLabel
		podiumScoreLabels[i] = scoreLabel
	end

	-- ── Scrolling List ───────────────────────────────────────────
	local listTopY = headerH + podiumH
	local listFrame = makeInstance("ScrollingFrame", {
		Name = "ListFrame",
		Size = UDim2.new(1, -16, 0, CANVAS_H - listTopY - 8),
		Position = UDim2.fromOffset(8, listTopY + 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.primaryColor,
		CanvasSize = UDim2.new(0, 0, 0, 0), -- set after rows
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = root,
	}) :: ScrollingFrame

	makeInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = listFrame,
	})

	-- Pre-build all row frames (hidden until update fills them)
	local ROW_H = 66
	local RANK_W = 0.12 -- 12 % of row
	local SCORE_W = 0.26 -- 26 % of row
	local NAME_W = 1 - RANK_W - SCORE_W

	local rowRankLabels = {}
	local rowNameLabels = {}
	local rowScoreLabels = {}
	local rowFrames = {}

	for i = 1, Config.maxEntries do
		local isTop3 = i <= 3
		local rowBg = if i % 2 == 0 then theme.rowAltColor else theme.backgroundColor
		local rankCol = if isTop3 then podiumSlotColors[i] else theme.dimTextColor
		local nameCol = if isTop3 then podiumSlotColors[i] else theme.textColor

		local row = makeInstance("Frame", {
			Name = "Row" .. i,
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundColor3 = rowBg,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Visible = false,
			Parent = listFrame,
		}) :: Frame
		makeInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = row })
		rowFrames[i] = row

		-- Rank column
		local rankLabel = makeLabel({
			Name = "Rank",
			Size = UDim2.fromScale(RANK_W, 1),
			Position = UDim2.fromScale(0, 0),
			Text = "#" .. i,
			TextColor3 = rankCol,
			Font = Enum.Font.GothamBold,
			Parent = row,
		}) :: TextLabel
		rowRankLabels[i] = rankLabel

		-- Name column
		local nameLabel = makeLabel({
			Name = "Name",
			Size = UDim2.new(NAME_W, -8, 1, 0),
			Position = UDim2.new(RANK_W, 4, 0, 0),
			Text = "---",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = nameCol,
			Parent = row,
		}) :: TextLabel
		rowNameLabels[i] = nameLabel

		-- Score column (right-aligned)
		local scoreLabel = makeLabel({
			Name = "Score",
			Size = UDim2.new(SCORE_W, -8, 1, 0),
			Position = UDim2.new(1 - SCORE_W, 4, 0, 0),
			Text = "---",
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = theme.dimTextColor,
			Parent = row,
		}) :: TextLabel
		rowScoreLabels[i] = scoreLabel
	end

	-- ── Countdown footer ─────────────────────────────────────────
	local FOOTER_H = 60
	local footer = makeInstance("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, FOOTER_H),
		Position = UDim2.new(0, 0, 1, -FOOTER_H),
		BackgroundColor3 = theme.headerColor,
		BorderSizePixel = 0,
		Parent = root,
	}) :: Frame

	local countdownLabel = makeLabel({
		Name = "Countdown",
		Size = UDim2.fromScale(1, 1),
		Text = "Updates in ...",
		Font = Enum.Font.Gotham,
		TextColor3 = theme.dimTextColor,
		Parent = footer,
	}) :: TextLabel

	return {
		boardPart = boardPart,
		podiumNameLabels = podiumNameLabels,
		podiumScoreLabels = podiumScoreLabels,
		rowFrames = rowFrames,
		rowRankLabels = rowRankLabels,
		rowNameLabels = rowNameLabels,
		rowScoreLabels = rowScoreLabels,
		countdownLabel = countdownLabel,
	}
end

-- ── Public: update ────────────────────────────────────────────────

-- entries: array of { rank: number, userId: number, name: string, score: number }
-- Called by LeaderboardService after each DataStore fetch.
function LeaderboardGui.update(handle: { [string]: any }, entries: { { [string]: any } })
	local theme = Config.theme
	local podiumColors = { theme.goldColor, theme.silverColor, theme.bronzeColor }

	-- Update top-3 podium summary
	for i = 1, 3 do
		local entry = entries[i]
		if entry then
			handle.podiumNameLabels[i].Text = entry.name
			handle.podiumScoreLabels[i].Text = NumberFormatter.format(entry.score)
		else
			handle.podiumNameLabels[i].Text = "---"
			handle.podiumScoreLabels[i].Text = "---"
		end
	end

	-- Update list rows
	for i = 1, Config.maxEntries do
		local entry = entries[i]
		local row = handle.rowFrames[i]
		if entry then
			row.Visible = true
			handle.rowRankLabels[i].Text = "#" .. entry.rank
			handle.rowNameLabels[i].Text = entry.name
			handle.rowScoreLabels[i].Text = NumberFormatter.format(entry.score)
			-- Re-color top-3 rows with medal colors
			if i <= 3 then
				handle.rowRankLabels[i].TextColor3 = podiumColors[i]
				handle.rowNameLabels[i].TextColor3 = podiumColors[i]
			end
		else
			row.Visible = false
		end
	end
end

-- ── Public: setCountdown ─────────────────────────────────────────

-- seconds: integer seconds remaining until the next refresh.
-- Called every second by LeaderboardService between refreshes.
function LeaderboardGui.setCountdown(handle: { [string]: any }, seconds: number)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	handle.countdownLabel.Text = string.format("Updates in %d:%02d", m, s)
end

return LeaderboardGui
