
-- -=/GETTING CHARACTER/=-
local plr = game.Players.LocalPlayer
local Character = plr.Character or plr.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- -=/SERVICES & CAMERA/=-
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local CameraAuthority = require(game:GetService("ReplicatedStorage").Modules.CameraAuthority)
local MovementConstants = require(game:GetService("ReplicatedStorage").Movement.Constants)
local crouchRemote = game:GetService("ReplicatedStorage"):WaitForChild("PlayerMovement"):WaitForChild("Crouch")

----------------- { CONFIGURATION } ---------------------

local config = {
	CrouchButtons = Enum.KeyCode.C,                                                    -- Key for crouching
	CrouchingCooldown = 0.1,                                                           -- Minimum time required between crouching and uncrouching
	Speed = 8,                                                                         -- Speed while crouching
	DefaultFieldOfView = 70,                                                           -- Default Camera FOV
	CrouchFieldOfView = 60,                                                            -- Crouching Camera FOV (can make it the same or zoom in/out)
	-- DEAD: the two CameraFOV*Time fields below are no longer read by anything -- FOV transition timing is owned by CameraAuthority's fixed 0.3s tween. Changing them does nothing.
	CameraFOVCrouchTime = 0.5,                                                         -- Time to tween the camera to the crouching FOV
	CameraFOVResetTime = 1,                                                            -- Time to tween the camera back to the default FOV
	CameraOffset = -1,                                                                 -- How much the camera tweens down when crouching
	-- DEAD: the two CameraDistance fields below are no longer read by anything -- crouch no
	-- longer touches zoom distance at all (narrowing it made Roblox hard-snap the camera when
	-- the player was zoomed out past the new max, with no way to restore it on un-crouch).
	-- Crouch's camera feel now comes from CrouchFieldOfView/CameraOffset only.
	MinCameraDistance = 0.5,                                                           -- Minimum camera distance you want while Crouching 
	MaxCameraDistance = 10,                                                            -- Maximum camera distance you want while Crouching
	CrouchEnabled = true,                                                              -- Whether crouching is enabled by default
	DustEnabled = true,                                                                -- Enables dust particles when crouching (if disabled you can delete the VFX folder in ReplicatedStorage)
	DynamicDustColor = true,                                                           -- Whether dust color should change based on material
	DustSpawnRate = 0.15,                                                              -- How often you want dust particles spawning
	MaxFreefallDuration = 0.35,                                                        -- Max Freefall duration before getting up
	StopOnLanding = true,                                                              -- Does crouch stop when the player lands
	CrouchInAir = false,                                                               -- Whether crouching is enabled when in the air
	RunningEnabled = true,                                                             -- Enabled since you have running system
	CrouchWalkAnimSpeed = 0.5                                                          -- Speed multiplier for crouch walk animation (1.0 = normal speed)
}

---------------------------------------------------------

-- A speed never above a heavy-loot carry cap (heist layers 2026-11-17; the stand-up too since 2026-11-18,
-- so a carrier who stands up is capped on the same frame, not one frame later).
local function carryCapped(speed: number): number
	local cap = Character:GetAttribute(MovementConstants.CARRY_SPEED_CAP_ATTRIBUTE)
	return if type(cap) == "number" then math.min(speed, cap) else speed
end

local function crouchSpeed()
	return carryCapped(config.Speed)
end

-- -=/ANIMATIONS/=-
local Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)
local CrouchIdleAnim = Animator:LoadAnimation(script:WaitForChild("Crouching"))
local CrouchWalkAnim = Animator:LoadAnimation(script:WaitForChild("CrouchWalk"))

-- -=/VARIABLES/=-
local CrouchSound = script:FindFirstChild("Crouch")
local GetUpSound = script:FindFirstChild("GetUp")
local originalSpeed = Humanoid.WalkSpeed
local dustDebounce = true
local notMoving = true
local crouchDebounce = true
local isOnGround = true
local freefallTimer = 0
local currentCrouchAnim = nil
local isCrouching = false

-- -=/INITIAL ATTRIBUTE SETUP/=-
if RootPart:GetAttribute("IsCrouching") == nil then
	RootPart:SetAttribute("IsCrouching", false)
end

if RootPart:GetAttribute("CrouchEnabled") == nil then
	if config.CrouchEnabled == true then
		RootPart:SetAttribute("CrouchEnabled", true)
	else
		RootPart:SetAttribute("CrouchEnabled", false)
	end
end

-- -=/CROUCH KEY CHECK/=- 
local function crouchKey(input)
	local crouchKeys = (typeof(config.CrouchButtons) == "table") and config.CrouchButtons or {config.CrouchButtons}

	for _, key in ipairs(crouchKeys) do
		if input.KeyCode == key then
			return true
		end
	end
	return false
end

-- -=/HEADROOM CHECK/=-
local function IsObstructed()
	local head = Character:FindFirstChild("Head")
	if head then
		local rayStart = head.Position
		local rayDirection = head.CFrame.UpVector * 1.5
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {Character}
		local raycastResult = workspace:Raycast(rayStart, rayDirection, raycastParams)
		return raycastResult ~= nil
	end
	return false
end

-- With a tool out the crouch drives the legs only (2026-11-20, developer: crouching with a gun "the gun is pointing
-- downwards"; picker "The gun's own hold"). Its clips pose the whole body at Action2 / Action3, over the gun hold
-- (Blaster Idle, shoot, reload at Action), so they drop under it while a tool is held and the arms keep the hold.
-- Nothing else plays under them while crouched (Movement steps aside). Without a tool: their own priorities.
local TOOL_CROUCH_PRIORITY = Enum.AnimationPriority.Movement
local ownPriority: { [AnimationTrack]: Enum.AnimationPriority } = {}
local function setCrouchPriority(track: AnimationTrack)
	if ownPriority[track] == nil and track.Length > 0 and track.Priority ~= TOOL_CROUCH_PRIORITY then
		ownPriority[track] = track.Priority
	end
	local want = if Character:FindFirstChildOfClass("Tool") then TOOL_CROUCH_PRIORITY else ownPriority[track]
	if want and track.Priority ~= want then
		track.Priority = want
	end
end

-- -=/HANDLE CROUCH ANIMATIONS/=-
local function HandleCrouchAnimations()
	if isCrouching then
		setCrouchPriority(CrouchIdleAnim)
		setCrouchPriority(CrouchWalkAnim)
	end
	if notMoving and isCrouching then
		-- Stop walk animation and play idle animation
		if currentCrouchAnim == CrouchWalkAnim then
			CrouchWalkAnim:Stop()
		end
		if not CrouchIdleAnim.IsPlaying then
			CrouchIdleAnim:Play()
			currentCrouchAnim = CrouchIdleAnim
		end
	elseif not notMoving and isCrouching then
		-- Stop idle animation and play walk animation
		if currentCrouchAnim == CrouchIdleAnim then
			CrouchIdleAnim:Stop()
		end
		if not CrouchWalkAnim.IsPlaying then
			CrouchWalkAnim:Play()
			CrouchWalkAnim:AdjustSpeed(config.CrouchWalkAnimSpeed)
			currentCrouchAnim = CrouchWalkAnim
		end
	end
end

-- -=/CROUCH FUNCTION/=-
local function Crouch()
	if not crouchDebounce or not RootPart:GetAttribute("CrouchEnabled") then return end
	if not config.CrouchInAir and not isOnGround then return end
	if isCrouching then return end

	crouchDebounce = false
	isCrouching = true
	RootPart:SetAttribute("IsCrouching", true)
	crouchRemote:FireServer(true) -- crouch stealth (2026-11-20): the server's Stealth owns what a crouch hides

	-- Play appropriate crouch animation based on movement
	HandleCrouchAnimations()

	if CrouchSound then
		CrouchSound:Play()
	end

	-- Set crouch speed (this overrides the running system)
	Humanoid.WalkSpeed = crouchSpeed()

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- Set crouch FOV and camera dip
	CameraAuthority.FieldOfView:Set("Crouch", config.CrouchFieldOfView)
	CameraAuthority.CameraOffset:Set("Crouch", Vector3.new(0, config.CameraOffset, 0))

	task.delay(config.CrouchingCooldown, function()
		crouchDebounce = true
	end)
end

-- -=/STOP FUNCTION/=- 
local function Stop()
	if not IsObstructed() then
		if isCrouching then
			isCrouching = false
			RootPart:SetAttribute("IsCrouching", false)
			crouchRemote:FireServer(false)

			-- Stop both crouch animations
			CrouchIdleAnim:Stop()
			CrouchWalkAnim:Stop()
			currentCrouchAnim = nil

			if GetUpSound then
				GetUpSound:Play()
			end

			-- Reset to original speed (running system will handle it from here)
			Humanoid.WalkSpeed = carryCapped(originalSpeed)

			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

			-- Reset FOV and camera dip to default
			CameraAuthority.FieldOfView:Clear("Crouch")
			CameraAuthority.CameraOffset:Clear("Crouch")
		end
	end
end

-- -=/KEY INPUT HANDLER/=- 
UIS.InputBegan:Connect(function(input, isTyping)
	if isTyping then return end

	if crouchKey(input) then
		if not isCrouching then
			Crouch()
		else
			Stop()
		end
	end
end)

-- -=/STATE CHANGES HANDLER/=- 
local function onStateChanged(_, newState)
	if isCrouching then
		if (newState == Enum.HumanoidStateType.Landed and config.StopOnLanding ~= false)
			or newState == Enum.HumanoidStateType.Dead
			or newState == Enum.HumanoidStateType.Climbing
			or newState == Enum.HumanoidStateType.Swimming
			or newState == Enum.HumanoidStateType.Seated
			or newState == Enum.HumanoidStateType.Physics then
			Stop()
		end
	end
end

-- -=/HEARTBEAT LOOP/=-
RunService.Heartbeat:Connect(function()

	-- -=/NON-MOVEMENT CHECK/=- 
	notMoving = Humanoid.MoveDirection.Magnitude == 0

	-- Handle crouch animations based on movement
	HandleCrouchAnimations()

	-- Force crouch speed while crouching
	if isCrouching then
		Humanoid.WalkSpeed = crouchSpeed()
	end

	-- -=/CROUCHING ENABLED VALUE CHECK/=- 
	if isCrouching and not RootPart:GetAttribute("CrouchEnabled") then
		Stop()
	end

	-- -=/DUST PARTICLES/=- 
	isOnGround = Humanoid.FloorMaterial ~= Enum.Material.Air

	if config.DustEnabled and isOnGround and isCrouching and dustDebounce and not notMoving then
		dustDebounce = false

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {Character}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local rayResult = workspace:Raycast(
			RootPart.Position + Vector3.new(0, 1, 0), 
			Vector3.new(0, -4.5, 0), 
			rayParams
		)

		local dustTemplate = game.ReplicatedStorage:FindFirstChild("VFX") and game.ReplicatedStorage.VFX:FindFirstChild("Dust")
		if dustTemplate then
			local dust = game.ReplicatedStorage.VFX.Dust:Clone()
			dust.Position = RootPart.Position + Vector3.new(0, -2.5, 0)
			dust.Parent = workspace.FX
			dust.Name = "CrouchDust"

			if config.DynamicDustColor then
				if rayResult then
					local hitPart = rayResult.Instance
					if hitPart and hitPart:IsA("BasePart") then
						dust.Attachment.Dust.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, hitPart.Color),
							ColorSequenceKeypoint.new(1, hitPart.Color)
						}
					end
				end
			else
				dust.Attachment.Dust.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)) -- Default dust color if dynamic dust color is not enabled
			end

			dust.Attachment.Dust:Emit(1)
			game.Debris:AddItem(dust, 0.8)

			task.wait(config.DustSpawnRate)
			dustDebounce = true
		end
	end

	-- -=/FREEFALL CHECK/=- 
	if not isOnGround and isCrouching then
		freefallTimer = freefallTimer + RunService.Heartbeat:Wait()
		if freefallTimer >= config.MaxFreefallDuration then
			Stop()
		end
	else
		freefallTimer = 0
	end
end)

Humanoid.StateChanged:Connect(onStateChanged)

-- -=/CHARACTER ADDED HANDLER/=-
plr.CharacterAdded:Connect(function(newCharacter)
	Character = newCharacter
	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")
	Animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)

	-- Reload animations for new character
	CrouchIdleAnim = Animator:LoadAnimation(script:WaitForChild("Crouching"))
	CrouchWalkAnim = Animator:LoadAnimation(script:WaitForChild("CrouchWalk"))

	-- Reset variables
	currentCrouchAnim = nil
	dustDebounce = true
	notMoving = true
	crouchDebounce = true
	isOnGround = true
	freefallTimer = 0
	isCrouching = false
	originalSpeed = Humanoid.WalkSpeed

	-- Reset attributes for new character
	if RootPart:GetAttribute("IsCrouching") == nil then
		RootPart:SetAttribute("IsCrouching", false)
	end

	if RootPart:GetAttribute("CrouchEnabled") == nil then
		if config.CrouchEnabled == true then
			RootPart:SetAttribute("CrouchEnabled", true)
		else
			RootPart:SetAttribute("CrouchEnabled", false)
		end
	end

	-- Reconnect state changed event
	Humanoid.StateChanged:Connect(onStateChanged)
end)