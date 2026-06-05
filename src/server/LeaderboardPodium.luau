-- LeaderboardPodium
-- Creates the 3 physical platform Parts and manages the top-3 character rigs.
-- Rig models are tagged "LeaderboardPodiumRig" so the client can find them
-- and play the dance animation locally (NPC animations don't replicate from server).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
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
local currentUserIds: { [number]: number? } = { nil, nil, nil }
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
	currentUserIds[slot] = nil
end

local function spawnRig(slot: number, userId: number, playerName: string)
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

	model.Name = playerName

	-- Set all rig parts to the PodiumRig collision group so players
	-- can walk through the display characters without being blocked.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "PodiumRig"
		end
	end

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
	currentUserIds[slot] = userId -- mark slot as successfully filled
end

-- ── Public: build ─────────────────────────────────────────────────

-- Creates the 3 podium platform Parts in Workspace.
-- Must be called once before update().
function LeaderboardPodium.build()
	podiumFolder = makeFolder()

	-- Set up collision groups so podium rigs don't block players,
	-- but still stand on their own platforms.
	-- pcall guards against re-registration if the script runs more than once (Studio).
	pcall(function()
		PhysicsService:RegisterCollisionGroup("PodiumRig")
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("PodiumPlatform")
	end)
	PhysicsService:CollisionGroupSetCollidable("PodiumRig", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("PodiumRig", "PodiumRig", false)
	PhysicsService:CollisionGroupSetCollidable("PodiumRig", "PodiumPlatform", true)

	for slot = 1, 3 do
		local plat = Instance.new("Part")
		plat.Name = "PodiumPlatform_" .. slot
		plat.Anchored = true
		plat.CanCollide = true
		plat.CollisionGroup = "PodiumPlatform"
		plat.Material = PLATFORM_MATERIALS[slot]
		plat.Color = PLATFORM_COLORS[slot]
		plat.Size = Vector3.new(PLATFORM_SIZE.X, PLATFORM_HEIGHTS[slot], PLATFORM_SIZE.Z)
		plat.CFrame = platCFrame(slot)
		plat.Parent = podiumFolder

		-- Rank number label painted on the top face of the platform.
		-- SurfaceGui scales with perspective (like any 3D object) so the label
		-- stays the same physical size regardless of viewing distance.
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "RankLabel"
		surfaceGui.Face = Enum.NormalId.Front
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 50
		surfaceGui.LightInfluence = 0
		surfaceGui.AlwaysOnTop = false
		surfaceGui.Parent = plat

		local rankText = Instance.new("TextLabel")
		rankText.Size = UDim2.fromScale(1, 1)
		rankText.BackgroundTransparency = 1
		rankText.Text = "#" .. slot
		rankText.Font = Enum.Font.GothamBold
		rankText.TextScaled = true
		rankText.TextColor3 = PLATFORM_COLORS[slot]
		rankText.Parent = surfaceGui

		platformParts[slot] = plat
	end
end

-- ── Public: update ────────────────────────────────────────────────

-- top3: array of up to 3 entries { rank, userId, name, score }
-- Skips slots where the same player is already displayed (avoids unnecessary
-- avatar re-fetches on refreshes where the top-3 hasn't changed).
function LeaderboardPodium.update(top3: { { [string]: any } })
	for slot = 1, 3 do
		local entry = top3[slot]
		local newUserId = if entry then entry.userId else nil

		-- Skip if this slot already has a live rig for the same player
		if currentUserIds[slot] == newUserId and currentRigs[slot] ~= nil then
			continue
		end

		destroyRig(slot) -- clears currentUserIds[slot] too

		if entry and entry.userId then
			-- Spawn in a separate thread so one slow fetch doesn't block the others
			task.spawn(spawnRig, slot, entry.userId, entry.name)
		end
	end
end

return LeaderboardPodium
