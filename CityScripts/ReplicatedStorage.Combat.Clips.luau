--!strict
-- Character clips for combat and robbery (2026-11-20). All are group 4998611's Player_* clips from the Blender pipeline
-- (ids in Blender/_enemies/ids.json); they play on any R15 character or NPC. The Crime* clips are made
-- (Blender/_enemies/Player/Player_Crime*.rbxmx) and wait for an upload: until an id is filled in below, each use takes
-- the next name in its list that has one, or plays nothing.
local Clips = {}

Clips.ids = {
	Choked = "rbxassetid://84852849800147", -- hands at the throat, legs kicking (the takedown's victim)
	RepairKneel = "rbxassetid://121944371724979", -- down onto one knee, working at something in front
	RepairLoop = "rbxassetid://90730140087815", -- kneeling, working it in a loop
	DeviceBrowse = "rbxassetid://115684067438169", -- a device held in front, scrolled
	-- Waiting for the upload (fill in the asset ids): CrimeRegister, CrimeType, CrimePickUp, CrimeChoke, CrimeStagger
} :: { [string]: string }

Clips.uses = {
	Register = { "CrimeRegister", "DeviceBrowse" }, -- registers, ATMs, stealing supplies (held)
	Type = { "CrimeType", "DeviceBrowse" }, -- the computer hack, the safe keypad
	PickUp = { "CrimePickUp", "RepairKneel" }, -- picking something up
	KneelDown = { "RepairKneel" }, -- safes, C4, lockpicks, deposit boxes: down first
	KneelLoop = { "RepairLoop" }, -- then this while it lasts
	Choker = { "CrimeChoke" }, -- the takedown, the player's side
	Choked = { "Choked" }, -- the takedown, the enemy's side
	Stagger = { "CrimeStagger" }, -- an enemy's headshot stagger
}

-- The asset id for a use, or nil when none of its clips is uploaded yet.
function Clips.id(use: string): string?
	for _, name in Clips.uses[use] or {} do
		local id = Clips.ids[name]
		if id then
			return id
		end
	end
	return nil
end

-- A track for `use` on `animator` at Action4 (loaded through `cache`, one per use), or nil.
function Clips.track(animator: Animator, use: string, cache: { [string]: AnimationTrack }): AnimationTrack?
	local cached = cache[use]
	if cached then
		return cached
	end
	local id = Clips.id(use)
	if not id then
		return nil
	end
	local ok, track = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action4
	cache[use] = track
	return track
end

return Clips
