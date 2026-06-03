-- LeaderboardClient
-- Handles animation playback for podium character rigs.
--
-- Why on the client?
--   Server-side animation playback on non-player NPC models does NOT replicate
--   to other clients. By detecting rig additions via CollectionService on every
--   client independently, each player sees the dance animation correctly.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.LeaderboardConfig)

local LeaderboardClient = {}

local TAG = "LeaderboardPodiumRig"

-- ── Animation helpers ─────────────────────────────────────────────

local function playDanceOnRig(model: Model)
	-- Wait for the Humanoid to be ready (it may not be immediately on arrival)
	local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		warn("[LeaderboardClient] No Humanoid found in rig", model.Name)
		return
	end

	-- Wait for the animator (needed for LoadAnimation on R15 rigs)
	local animator = humanoid:WaitForChild("Animator", 10) :: Animator?
	if not animator then
		warn("[LeaderboardClient] No Animator found in rig", model.Name)
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = Config.danceAnimationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok or not track then
		warn("[LeaderboardClient] Failed to load animation on rig", model.Name, track)
		return
	end

	track.Looped = true
	track:Play()
end

-- ── Public: init ──────────────────────────────────────────────────

-- Call once from init.client.luau.
function LeaderboardClient.init()
	-- Handle rigs that are already in the workspace when the client loads
	-- (e.g. player joins after the server has already refreshed the podium)
	for _, model in CollectionService:GetTagged(TAG) do
		task.spawn(playDanceOnRig, model)
	end

	-- Handle rigs added in the future (new refresh cycle, podium slots updated)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model: Instance)
		task.spawn(playDanceOnRig, model :: Model)
	end)
end

return LeaderboardClient
