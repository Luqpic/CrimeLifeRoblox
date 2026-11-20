--!strict
-- Enemy hit reactions (combat, developer picker 2026-11-20): every player hit on an NPC flashes it red and pushes it a
-- little away from the shooter; a headshot staggers it (the StunnedUntil stun EnemyAI already obeys: no moving, no
-- firing); a shotgun blast within KNOCKDOWN_RANGE knocks it down (the Humanoid's own FallingDown state, which gets
-- back up by itself) and stuns it while it is down. Once per shot per enemy (ShotResolver), with cooldowns so a fast
-- gun cannot stun-lock. No animation clips: the engine's own states and a Highlight.
local Clips = require(game:GetService("ReplicatedStorage").Combat.Clips)

local HitReaction = {}

HitReaction.FLASH_SECONDS = 0.12
HitReaction.PUSH_SPEED = 6 -- studs a second added to the root, away from the shooter
HitReaction.STAGGER_SECONDS = 0.5
HitReaction.STAGGER_COOLDOWN = 1.5
HitReaction.KNOCKDOWN_RANGE = 8
HitReaction.KNOCKDOWN_SECONDS = 1.6
HitReaction.KNOCKDOWN_PUSH_SPEED = 22
HitReaction.KNOCKDOWN_COOLDOWN = 3

-- Pure: what a hit does. category is the weapon's Category attribute; distance in studs.
function HitReaction.kind(isHeadshot: boolean, category: unknown, distance: number): string
	if category == "Shotgun" and distance <= HitReaction.KNOCKDOWN_RANGE then
		return "knockdown"
	elseif isHeadshot then
		return "stagger"
	end
	return "flinch"
end

local lastStagger: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any
local staggerTracks: { [Humanoid]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local lastKnockdown: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any

local function flash(character: Model)
	local highlight = character:FindFirstChild("HitFlash") :: Highlight?
	if not highlight then
		local made = Instance.new("Highlight")
		made.Name = "HitFlash"
		made.FillColor = Color3.fromRGB(255, 60, 60)
		made.FillTransparency = 0.45
		made.OutlineTransparency = 1
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Parent = character
		highlight = made
	end
	local h = highlight :: Highlight
	h.Enabled = true
	local token = (h:GetAttribute("FlashToken") or 0) + 1
	h:SetAttribute("FlashToken", token)
	task.delay(HitReaction.FLASH_SECONDS, function()
		if h.Parent and h:GetAttribute("FlashToken") == token then
			h.Enabled = false
		end
	end)
end

local function push(root: BasePart, from: Vector3, speed: number)
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.01 or root.Anchored then
		return
	end
	pcall(function()
		root:ApplyImpulse(away.Unit * speed * root.AssemblyMass)
	end)
end

-- One reaction of an NPC `humanoid` to a player's shot from `from` with `weapon`.
function HitReaction.react(humanoid: Humanoid, from: Vector3, weapon: Instance?, isHeadshot: boolean)
	local character = humanoid.Parent
	local root = humanoid.RootPart
	if not (character and character:IsA("Model") and root) or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local kind = HitReaction.kind(isHeadshot, weapon and weapon:GetAttribute("Category"), (root.Position - from).Magnitude)
	flash(character)
	if kind == "knockdown" and now - (lastKnockdown[humanoid] or -math.huge) >= HitReaction.KNOCKDOWN_COOLDOWN then
		lastKnockdown[humanoid] = now
		root:SetAttribute("StunnedUntil", math.max(root:GetAttribute("StunnedUntil") or 0, now + HitReaction.KNOCKDOWN_SECONDS))
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		push(root, from, HitReaction.KNOCKDOWN_PUSH_SPEED)
		return
	end
	if kind ~= "flinch" and now - (lastStagger[humanoid] or -math.huge) >= HitReaction.STAGGER_COOLDOWN then
		lastStagger[humanoid] = now
		root:SetAttribute("StunnedUntil", math.max(root:GetAttribute("StunnedUntil") or 0, now + HitReaction.STAGGER_SECONDS))
		-- The stagger clip (Combat.Clips "Stagger", 2026-11-20: a stun with nothing to see read as a freeze).
		local animator = humanoid:FindFirstChildOfClass("Animator")
		local cache = staggerTracks[humanoid] or {}
		staggerTracks[humanoid] = cache
		local track = animator and Clips.track(animator, "Stagger", cache)
		if track then
			track.Looped = false
			track:Play(0.05)
		end
	end
	push(root, from, HitReaction.PUSH_SPEED)
end

return HitReaction
