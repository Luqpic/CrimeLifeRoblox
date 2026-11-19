--[[
	Blaster.Scripts.ShoulderCamera (2026-11-20): the over-the-shoulder third person while a gun is held, ported from
	OBT's GunEngine.Camera (developer: "Add a third person POV for the FPS system (can toggle). You can reuse the OBT's
	weaponary system"). Roblox's Classic camera keeps orbiting, colliding and handling touch drag; this module only sets
	and restores:
	  - the built-in camera's mouse lock (with no offset of its own: the built-in camera turns with the mouse only while
	    mouse-locked); the cursor itself stays CameraAuthority's "Blaster" LockCenter
	  - the zoom (pinned at SHOULDER_ZOOM) and Humanoid.CameraOffset (the shoulder, wall-clamped, plus the crouch drop)
	    through CameraAuthority's "Shoulder" source, the highest on those channels
	  - the facing: AutoRotate off and the root turned to the camera heading, except while a move (roll, ledge climb:
	    character attribute MoveAction) owns it; CustomShiftLock stands aside while character attribute ShoulderCam is set
	  - the local Waist / Neck pitch, reported to the server (Remotes.AimPitch) so other players see it (AimPitchView)
	FOV and mouse sensitivity while aiming stay BlasterController's "ADS" claims; recoil stays CameraRecoiler's.
	Never engages, and exits, while a UI.Panels panel is open, an NPC dialogue holds the camera, the character is dead,
	seated, ragdolled (PlatformStand) or not the camera subject. ViewModelController enters it every frame it should be on.
	The view the player picked with V is kept here for the session (respawns included): third person by default
	(developer, 2026-11-20). OBT's scope first person, walking bob and fire shake are not ported: CrimeLife has no scoped
	gun, "Bobbing Camera" already bobs, and CameraRecoiler already kicks.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)
local Panels = require(ReplicatedStorage.UI.Panels)
local shoulderMath = require(script.Parent.Parent.Utility.shoulderMath)

local ShoulderCamera = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local aimRemote = ReplicatedStorage.Blaster.Remotes:WaitForChild("AimPitch")

local BIND_NAME = "BlasterShoulderCamera"
-- Before Roblox's camera (Camera priority): the offset, zoom and facing it reads are this frame's.
local BIND_PRIORITY = Enum.RenderPriority.Camera.Value - 1
local MAX_PITCH = math.rad(Constants.SHOULDER_MAX_PITCH_DEGREES)
local FACE_LERP = 0.35
local SWAP_TIME = 0.15
local BLEND_TIME = 0.35
local SEND_STEP = math.rad(2)

local preferThird = true -- the session's choice (V)
local wantAiming = false -- the last aim BlasterController asked for: kept across an exit / enter (a panel, V, a seat)
local side, sideValue = 1, 1 -- +1 right shoulder, -1 left; kept for the session
local state = nil -- nil while inactive

local cameras -- the PlayerModule's CameraModule singleton, once found
local lockedControllers = {}

-- Test seam: the CameraModule table, or nil.
function ShoulderCamera._cameras()
	if not cameras then
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		module = module and module:FindFirstChild("CameraModule")
		local ok, result = pcall(function()
			return module and require(module)
		end)
		cameras = ok and type(result) == "table" and result or nil
	end
	return cameras
end

-- BaseCamera turns the camera with the mouse only while panning, in first person or mouse-locked: the shoulder view
-- holds the built-in mouse lock on with its offset zeroed (CameraOffset carries the shoulder), re-asserted every frame.
local function lockBuiltIn()
	local c = ShoulderCamera._cameras()
	local controller = c and c.activeCameraController
	if not controller then
		return
	end
	lockedControllers[controller] = true
	if not controller:GetIsMouseLocked() then
		controller:SetIsMouseLocked(true)
	end
	if controller:GetMouseLockOffset() ~= Vector3.zero then
		controller:SetMouseLockOffset(Vector3.zero)
	end
end

-- Hands every controller it locked back the player's own shift-lock state and offset.
local function releaseBuiltIn()
	local c = ShoulderCamera._cameras()
	local shiftLock = c and c.activeMouseLockController
	local locked = shiftLock and shiftLock:GetIsMouseLocked() or false
	for controller in pairs(lockedControllers) do
		controller:SetIsMouseLocked(locked)
		if shiftLock then
			controller:SetMouseLockOffset(shiftLock:GetMouseLockOffset())
		end
	end
	table.clear(lockedControllers)
	local active = c and c.activeCameraController
	if active then
		active:UpdateMouseBehavior()
	end
end

-- A tiltable joint: a Motor6D rotates its C0; an AnimationConstraint (this game's avatar joints) rotates its
-- parent-side attachment, the equivalent of C0. Returns {rest, set, alive} or nil. `rest` is the pose the joint had
-- the first time anyone asked (animations do not move it).
local rests = setmetatable({}, { __mode = "k" })
function ShoulderCamera.joint(model: Model, partName: string, jointName: string)
	local part = model:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(jointName)
	if joint and joint:IsA("Motor6D") then
		rests[joint] = rests[joint] or joint.C0
		return {
			rest = rests[joint],
			set = function(cf)
				joint.C0 = cf
			end,
			alive = function()
				return joint.Parent ~= nil
			end,
		}
	elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		local a = joint.Attachment0
		rests[a] = rests[a] or a.CFrame
		return {
			rest = rests[a],
			set = function(cf)
				a.CFrame = cf
			end,
			alive = function()
				return a.Parent ~= nil
			end,
		}
	end
	return nil
end

-- Tilts an upper body by `pitch` (radians): the waist takes 0.6 of it and the neck 0.4. `hips` turns the waist back
-- by the hips' yaw against the root, so the chest and gun stay on the crosshair while the legs strafe (own body only).
function ShoulderCamera.tilt(waist, neck, pitch: number, hips: number?)
	if waist and waist.alive() then
		local rest = waist.rest
		waist.set(CFrame.new(rest.Position) * CFrame.Angles(0, -(hips or 0), 0) * rest.Rotation * CFrame.Angles(pitch * 0.6, 0, 0))
	end
	if neck and neck.alive() then
		neck.set(neck.rest * CFrame.Angles(pitch * 0.4, 0, 0))
	end
end

local function blocked(humanoid: Humanoid): boolean
	return Panels.current() ~= nil
		or CameraAuthority.FieldOfView:Get("Dialogue") ~= nil
		or humanoid.Health <= 0
		or humanoid.Sit
		or humanoid.PlatformStand
		or camera.CameraSubject ~= humanoid
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local ignore = {}

-- Distance free along `dir` from `origin` before a solid, visible part, minus the wall gap.
local function clearance(origin: Vector3, dir: Vector3, character: Model): number
	local length = dir.Magnitude
	if length < 1e-3 then
		return 0
	end
	table.clear(ignore)
	ignore[1] = character
	for _ = 1, 8 do
		rayParams.FilterDescendantsInstances = ignore
		local r = workspace:Raycast(origin, dir.Unit * (length + Constants.SHOULDER_WALL_GAP), rayParams)
		if not r then
			return length
		end
		if r.Instance.Transparency >= 0.9 or not r.Instance.CanCollide then
			table.insert(ignore, r.Instance)
		else
			return math.max(0, (r.Position - origin).Magnitude - Constants.SHOULDER_WALL_GAP)
		end
	end
	return length
end

local function setZoom(z: number)
	-- raise the max before the min (and the reverse when lowering) so the pair never crosses
	if z >= player.CameraMaxZoomDistance then
		CameraAuthority.MaxZoomDistance:Set("Shoulder", z)
		CameraAuthority.MinZoomDistance:Set("Shoulder", z)
	else
		CameraAuthority.MinZoomDistance:Set("Shoulder", z)
		CameraAuthority.MaxZoomDistance:Set("Shoulder", z)
	end
end

local function update(dt: number)
	local s = state
	if not s.humanoid.Parent or blocked(s.humanoid) then
		ShoulderCamera.exit()
		return
	end
	lockBuiltIn()
	-- the shoulder side (animated by a swap) and the wall clamp along the character's right
	local step = dt / SWAP_TIME * 2
	sideValue += math.clamp(side - sideValue, -step, step)
	local base = if s.aiming then Constants.SHOULDER_AIM_OFFSET else Constants.SHOULDER_OFFSET
	local wantX = base.X * sideValue
	local origin = s.root.Position + Vector3.new(0, base.Y, 0)
	local x = shoulderMath.clampSide(wantX, clearance(origin, s.root.CFrame.RightVector * wantX, s.character))
	local offset = Vector3.new(x, base.Y, 0) + (CameraAuthority.CameraOffset:Get("Crouch") or Vector3.zero)
	local e = shoulderMath.smooth((os.clock() - s.blendStart) / BLEND_TIME)
	setZoom(s.zoomFrom + (s.zoomTo - s.zoomFrom) * e)
	CameraAuthority.CameraOffset:Set("Shoulder", offset * e)
	-- face the camera heading, unless a move (roll, ledge climb) owns the facing
	s.humanoid.AutoRotate = false
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 1e-3 and s.character:GetAttribute("MoveAction") == nil then
		local rootCF = s.root.CFrame
		s.root.CFrame = rootCF:Lerp(CFrame.lookAt(rootCF.Position, rootCF.Position + flat), FACE_LERP)
	end
	-- the upper body follows the aim; the chest stays on the crosshair whatever the legs layer does with the hips
	s.pitch = shoulderMath.pitchOf(look.Y, MAX_PITCH)
	local hips = 0
	if s.lower and s.lower.Parent then
		local _, y = s.root.CFrame:ToObjectSpace(s.lower.CFrame):ToEulerAnglesYXZ()
		hips = y
	end
	ShoulderCamera.tilt(s.waist, s.neck, s.pitch, hips)
	local now = os.clock()
	if shoulderMath.due(s.sentAt, now, Constants.AIM_PITCH_SEND_INTERVAL) and math.abs(s.pitch - s.sentPitch) > SEND_STEP then
		s.sentAt, s.sentPitch = now, s.pitch
		aimRemote:FireServer(s.pitch)
	end
end

local function renderStep(dt: number)
	if not state then
		return
	end
	local ok, err = pcall(update, dt)
	if not ok then
		warn("ShoulderCamera: " .. tostring(err))
		ShoulderCamera.exit()
	end
end

-- Starts the shoulder view; false while it cannot run (see blocked). Calling it while active does nothing.
function ShoulderCamera.enter(): boolean
	if state then
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or blocked(humanoid) then
		return false
	end
	local fromZoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	state = {
		character = character,
		humanoid = humanoid,
		root = root,
		aiming = wantAiming,
		waist = ShoulderCamera.joint(character, "UpperTorso", "Waist"),
		neck = ShoulderCamera.joint(character, "Head", "Neck"),
		lower = character:FindFirstChild("LowerTorso"),
		pitch = 0,
		sentPitch = 0,
		sentAt = nil,
		zoomFrom = math.clamp(fromZoom, 0.5, 400),
		zoomTo = Constants.SHOULDER_ZOOM,
		blendStart = os.clock(),
	}
	humanoid.AutoRotate = false
	character:SetAttribute("ShoulderCam", true)
	lockBuiltIn()
	RunService:BindToRenderStep(BIND_NAME, BIND_PRIORITY, renderStep)
	return true
end

function ShoulderCamera.exit()
	local s = state
	if not s then
		return
	end
	state = nil
	RunService:UnbindFromRenderStep(BIND_NAME)
	local function try(fn)
		local ok, err = pcall(fn)
		if not ok then
			warn("ShoulderCamera restore: " .. tostring(err))
		end
	end
	try(releaseBuiltIn)
	try(function()
		CameraAuthority.CameraOffset:Clear("Shoulder")
		CameraAuthority.MinZoomDistance:Clear("Shoulder")
		CameraAuthority.MaxZoomDistance:Clear("Shoulder")
	end)
	try(function()
		-- AutoRotate back on (CustomShiftLock takes it back every frame while shift lock is on). Not in the middle of a
		-- move (roll, ledge climb): the move found it off and will not switch it on, so it is switched on once the
		-- move ends, unless the shoulder view has come back by then (review I4).
		local humanoid, character = s.humanoid, s.character
		if not humanoid.Parent then
			return
		end
		if character:GetAttribute("MoveAction") == nil then
			humanoid.AutoRotate = true
			return
		end
		local conn
		conn = character:GetAttributeChangedSignal("MoveAction"):Connect(function()
			if character:GetAttribute("MoveAction") == nil then
				conn:Disconnect()
				if not state and humanoid.Parent then
					humanoid.AutoRotate = true
				end
			end
		end)
	end)
	try(function()
		ShoulderCamera.tilt(s.waist, s.neck, 0, 0)
	end)
	try(function()
		s.character:SetAttribute("ShoulderCam", nil)
	end)
	if s.sentPitch ~= 0 then
		aimRemote:FireServer(0)
	end
end

-- Cursor re-arm (OBT, 2026-10-21): Roblox drops the mouse lock when the window loses focus and does not always take
-- it back; Default for a moment re-arms it (CameraAuthority puts the claimed LockCenter straight back).
local function rearm()
	if state then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end
UserInputService.WindowFocused:Connect(rearm)
UserInputService.TextBoxFocusReleased:Connect(rearm)
game:GetService("GuiService").MenuClosed:Connect(rearm)

function ShoulderCamera.active(): boolean
	return state ~= nil
end

function ShoulderCamera.setAiming(on: boolean)
	wantAiming = on
	if state then
		state.aiming = on
	end
end

function ShoulderCamera.swapShoulder()
	side = -side
end

function ShoulderCamera.side(): number
	return side
end

function ShoulderCamera.pitch(): number
	return state and state.pitch or 0
end

-- The view the player picked this session (V): true = third person. Mirrored on player attribute ViewMode.
function ShoulderCamera.prefersThird(): boolean
	return preferThird
end

function ShoulderCamera.setPrefersThird(on: boolean)
	preferThird = on
	player:SetAttribute("ViewMode", if on then "third" else "first")
end

return ShoulderCamera
