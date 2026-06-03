-- LeaderboardPodium
-- Creates the 3 physical platform Parts and manages the top-3 character rigs.
-- Rig models are tagged "LeaderboardPodiumRig" so the client can find them
-- and play the dance animation locally (NPC animations don't replicate from server).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.LeaderboardConfig)

local LeaderboardPodium = {}

-- ── Constants ─────────────────────────────────────────────────────

-- Podium slot layout (relative to Config.podiumOriginCFrame):
--   Slot 1: center, tallest (1st place)
--   Slot 2: left,   medium  (2nd place)
--   Slot 3: right,  shortest(3rd place)
local SLOT_OFFSETS = {
	[1] = Vector3.new(0, 0, 0), -- center  (offset applied after platform height)
	[2] = Vector3.new(-5, 0, 0), -- left
	[3] = Vector3.new(5, 0, 0), -- right
}

local PLATFORM_HEIGHTS = { [1] = 3.5, [2] = 2.5, [3] = 1.5 } -- studs tall
local PLATFORM_SIZE = Vector3.new(4, 1, 4) -- W × thickness × D

local PLATFORM_COLORS = {
	[1] = Color3.fromRGB(212, 175, 55), -- gold
	[2] = Color3.fromRGB(160, 160, 160), -- silver
	[3] = Color3.fromRGB(176, 96, 36), -- bronze
}

local PLATFORM_MATERIALS = {
	[1] = Enum.Material.SmoothPlastic,
	[2] = Enum.Material.SmoothPlastic,
	[3] = Enum.Material.SmoothPlastic,
}

-- How far above the platform surface the character root is placed
local RIG_HOVER_OFFSET = 0.1

-- ── State ─────────────────────────────────────────────────────────

local platformParts: { [number]: BasePart } = {}
local currentRigs: { [number]: Model? } = { nil, nil, nil }
local podiumFolder: Folder

-- ── Helpers ───────────────────────────────────────────────────────

local function makeFolder(): Folder
	-- Clean up any leftover folder from a previous run (Studio testing)
	local existing = workspace:FindFirstChild("LeaderboardPodium")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "LeaderboardPodium"
	folder.Parent = workspace
	return folder
end

-- ── Internal ─────────────────────────────────────────────────────

-- Returns the CFrame for the top surface center of a platform slot
local function slotTopCFrame(slot: number): CFrame
	local origin = Config.podiumOriginCFrame
	local offset = SLOT_OFFSETS[slot]
	local height = PLATFORM_HEIGHTS[slot]
	local topY = height + RIG_HOVER_OFFSET
	-- Offset from origin: lateral offset + height of platform top
	local worldPos = origin:PointToWorldSpace(offset + Vector3.new(0, topY, 0))
	return CFrame.new(worldPos) * (origin - origin.Position) -- preserve rotation
end

-- Returns the CFrame for the platform center
local function platCFrame(slot: number): CFrame
	local origin = Config.podiumOriginCFrame
	local offset = SLOT_OFFSETS[slot]
	local height = PLATFORM_HEIGHTS[slot]
	local platCenter = origin:PointToWorldSpace(offset + Vector3.new(0, height / 2, 0))
	return CFrame.new(platCenter) * (origin - origin.Position)
end

local function destroyRig(slot: number)
	local rig = currentRigs[slot]
	if rig then
		rig:Destroy()
		currentRigs[slot] = nil
	end
end

local function spawnRig(slot: number, userId: number)
	-- Fetch avatar description (may fail for invalid/deleted accounts)
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	end)
	if not ok or not desc then
		warn("[LeaderboardPodium] Failed to get description for userId", userId, desc)
		return
	end

	-- Build character model from description
	local rigOk, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not rigOk or not model then
		warn("[LeaderboardPodium] Failed to create model for userId", userId, model)
		return
	end

	model.Name = "PodiumRig_" .. slot

	-- Position: place HumanoidRootPart at the top surface of the platform
	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		local topCF = slotTopCFrame(slot)
		model:PivotTo(topCF)
	end

	-- Make the humanoid not move (it's a static display rig)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end

	model.Parent = podiumFolder

	-- Tag AFTER parenting so the client signal fires when the model is already visible
	CollectionService:AddTag(model, "LeaderboardPodiumRig")

	currentRigs[slot] = model
end

-- ── Public: build ─────────────────────────────────────────────────

-- Creates the 3 podium platform Parts in Workspace.
-- Must be called once before update().
function LeaderboardPodium.build()
	podiumFolder = makeFolder()

	for slot = 1, 3 do
		local plat = Instance.new("Part")
		plat.Name = "PodiumPlatform_" .. slot
		plat.Anchored = true
		plat.CanCollide = true
		plat.Material = PLATFORM_MATERIALS[slot]
		plat.Color = PLATFORM_COLORS[slot]
		plat.Size = Vector3.new(PLATFORM_SIZE.X, PLATFORM_HEIGHTS[slot], PLATFORM_SIZE.Z)
		plat.CFrame = platCFrame(slot)
		plat.Parent = podiumFolder

		-- Rank number label on the face of the platform
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "RankLabel"
		billboard.Size = UDim2.fromOffset(80, 60)
		billboard.StudsOffset = Vector3.new(0, PLATFORM_HEIGHTS[slot] / 2 + 0.5, 0)
		billboard.AlwaysOnTop = false
		billboard.LightInfluence = 0
		billboard.Parent = plat

		local rankText = Instance.new("TextLabel")
		rankText.Size = UDim2.fromScale(1, 1)
		rankText.BackgroundTransparency = 1
		rankText.Text = "#" .. slot
		rankText.Font = Enum.Font.GothamBold
		rankText.TextScaled = true
		rankText.TextColor3 = PLATFORM_COLORS[slot]
		rankText.Parent = billboard

		platformParts[slot] = plat
	end
end

-- ── Public: update ────────────────────────────────────────────────

-- top3: array of up to 3 entries { rank, userId, name, score }
-- Destroys old rigs and spawns fresh ones for the new top-3.
function LeaderboardPodium.update(top3: { { [string]: any } })
	for slot = 1, 3 do
		destroyRig(slot)
		local entry = top3[slot]
		if entry and entry.userId then
			-- Spawn in a separate thread so one slow fetch doesn't block the others
			task.spawn(spawnRig, slot, entry.userId)
		end
	end
end

return LeaderboardPodium
