--!strict
-- CameraAuthority: shared, client-only PropertyAuthority instances for every camera/Humanoid
-- property that more than one system needs to drive. Both the Movement system and the Blaster
-- system must call through these instead of writing the underlying property directly, so that
-- unequipping/un-crouching/etc. always falls back to whatever the next-highest-priority system
-- wants instead of stomping it.
--
-- Priority orders are deliberately explicit here (not inferred from connection order):
--   FieldOfView:           Menu > Dialogue > ADS > Sprint > Crouch
--   CameraOffset:          Shoulder > ADS > Crouch
--   MinZoomDistance:       Shoulder > Blaster > BobbingCamera
--   MaxZoomDistance:       Shoulder > Blaster > BobbingCamera
--   MouseBehavior:         Blaster > ShiftLock
--   MouseDeltaSensitivity: ADS
--
-- "Shoulder" (Blaster.Scripts.ShoulderCamera, 2026-11-20) is the third-person shoulder view: it outranks ADS (aiming
-- over the shoulder pulls the shoulder offset in instead of pushing the camera forward) and folds Crouch's drop into
-- its own offset. Its CameraOffset is applied at once, not tweened: it moves every frame with the wall clamp.
--
-- Crouch deliberately does NOT touch Min/MaxZoomDistance: narrowing the zoom-distance range
-- makes Roblox's own camera controller hard-clamp the player's LIVE zoom distance into the new
-- bounds instantly (a visible snap when the player was zoomed out past the new max), and
-- Roblox has no way to restore that distance when the range widens back on un-crouch -- the
-- clamp is a one-way street, not a cache-and-restore. Crouch conveys its feel through
-- FieldOfView and CameraOffset only, both of which we fully control and already tween.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local PropertyAuthority = require(script.Parent.PropertyAuthority)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function currentHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local CameraAuthority = {}

local fovTween: Tween? = nil
-- "Menu" outranks "ADS" deliberately: an open full-screen menu is its own camera context and should
-- win outright over an in-progress zoom, rather than being silently overridden by it. "Dialogue"
-- (NPC conversations) sits just under it and is deliberately a SEPARATE source rather than reusing
-- "Menu": values here are keyed by source name, so two systems sharing one would overwrite each
-- other's value and, worse, either one's Clear would drop the other's contribution entirely.
CameraAuthority.FieldOfView = PropertyAuthority.new(camera.FieldOfView, { "Menu", "Dialogue", "ADS", "Sprint", "Crouch" }, function(value: number)
	if fovTween then
		fovTween:Cancel()
	end
	fovTween = TweenService:Create(camera, TWEEN_INFO, { FieldOfView = value })
	fovTween:Play()
end)

local cameraOffsetTween: Tween? = nil
CameraAuthority.CameraOffset = PropertyAuthority.new(Vector3.new(0, 0, 0), { "Shoulder", "ADS", "Crouch" }, function(value: Vector3, source: string?)
	local humanoid = currentHumanoid()
	if not humanoid then
		return
	end
	if cameraOffsetTween then
		cameraOffsetTween:Cancel()
	end
	if source == "Shoulder" then
		humanoid.CameraOffset = value
		return
	end
	cameraOffsetTween = TweenService:Create(humanoid, TWEEN_INFO, { CameraOffset = value })
	cameraOffsetTween:Play()
end)

CameraAuthority.MinZoomDistance = PropertyAuthority.new(0.5, { "Shoulder", "Blaster", "BobbingCamera" }, function(value: number)
	player.CameraMinZoomDistance = value
end)

CameraAuthority.MaxZoomDistance = PropertyAuthority.new(30, { "Shoulder", "Blaster", "BobbingCamera" }, function(value: number)
	player.CameraMaxZoomDistance = value
end)

-- Set only while this module is itself writing UserInputService.MouseBehavior, so the
-- property-changed listener at the bottom of this file can tell our own writes apart from an
-- external writer's.
local applyingMouseBehavior = false

local function writeMouseBehavior(value: Enum.MouseBehavior)
	applyingMouseBehavior = true
	UserInputService.MouseBehavior = value
	applyingMouseBehavior = false
end

CameraAuthority.MouseBehavior = PropertyAuthority.new(Enum.MouseBehavior.Default, { "Blaster", "ShiftLock" }, writeMouseBehavior)

CameraAuthority.MouseDeltaSensitivity = PropertyAuthority.new(1, { "ADS" }, function(value: number)
	UserInputService.MouseDeltaSensitivity = value
end)

-- Sources that belong to exactly ONE character and must never outlive it. The normal
-- death -> respawn path has each consumer clear its own on the Dead state, but a respawn that
-- bypasses that state (e.g. player:LoadCharacter()) skips the cleanup entirely and strands the
-- registration on these session-lifetime singletons: the old character's FOV/offset/zoom stay
-- applied, and the NEXT character's identical Set() silently no-ops (PropertyAuthority
-- deliberately suppresses re-applying an unchanged value), so crouch/sprint/ADS appear to stop
-- working for the rest of the session. Handled here rather than in each consumer so no consumer
-- needs its own copy of this lifecycle fix.
-- "Blaster" and "BobbingCamera" are deliberately NOT cleared -- they have their own lifecycle
-- (tool equip/unequip, and BobbingCamera's permanent top-level registration) that this would fight.
local CHARACTER_SCOPED_SOURCES = { "Crouch", "Sprint", "ADS", "ShiftLock", "Shoulder" }
local CHARACTER_SCOPED_AUTHORITIES = {
	CameraAuthority.FieldOfView,
	CameraAuthority.CameraOffset,
	CameraAuthority.MinZoomDistance,
	CameraAuthority.MaxZoomDistance,
	CameraAuthority.MouseBehavior,
	CameraAuthority.MouseDeltaSensitivity,
}

player.CharacterAdded:Connect(function()
	for _, authority in CHARACTER_SCOPED_AUTHORITIES do
		for _, source in CHARACTER_SCOPED_SOURCES do
			-- Only clear sources this authority actually arbitrates (MouseBehavior, for example,
			-- has no "Crouch"), so the intent stays readable and can't drift from priorityOrder.
			if table.find(authority._priorityOrder, source) then
				authority:Clear(source)
			end
		end
	end
end)

-- The default PlayerModule CameraModule (and this place's PlayerGui.Freecam.FreecamScript) also
-- assign UserInputService.MouseBehavior directly, outside this authority's knowledge, and nothing
-- reasserts against them any more -- the per-frame reasserts that used to were removed as
-- redundant against each other. So re-apply our own resolved value whenever an external writer
-- changes it while a source is still registered here. When no source is registered we leave the
-- property alone, so clearing the last source really does hand control back instead of pinning a
-- stale value (and so this can never fight itself into a loop).
UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
	if applyingMouseBehavior then
		return
	end

	local authority = CameraAuthority.MouseBehavior
	if authority._currentSource == nil then
		return
	end

	local resolved = authority._lastAppliedValue
	if UserInputService.MouseBehavior ~= resolved then
		writeMouseBehavior(resolved)
	end
end)

return CameraAuthority
