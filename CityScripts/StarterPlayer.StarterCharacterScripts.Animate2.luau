-- Animate2 (LocalScript) - R15 Version
-- Place in StarterPlayer > StarterCharacterScripts

local Figure = script.Parent

-- Delete the default Animate script, and stop what it already started: its tracks outlive it (2026-11-20: its idle
-- kept playing at Core under everything, and Movement's loops drop to Core under a held tool)
local defaultAnimate = Figure:WaitForChild("Animate", 5)
if defaultAnimate then
	defaultAnimate:Destroy()
	local animator = Figure:WaitForChild("Humanoid"):FindFirstChildOfClass("Animator")
	for _, track in animator and animator:GetPlayingAnimationTracks() or {} do
		track:Stop(0)
	end
end

local Humanoid = Figure:WaitForChild("Humanoid")
local HumanoidRootPart = Figure:WaitForChild("HumanoidRootPart")

local pose = "Standing"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationPriorities = require(ReplicatedStorage.Modules.AnimationPriorities)
local UserInputService
local ContentProvider = game:GetService("ContentProvider")
local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)
local MovementConstants = require(ReplicatedStorage.Movement.Constants)

local runEvent = ReplicatedStorage:WaitForChild("UpdateRunningState")

-- Baseline FOV this game authors around (matches Crouching's config.DefaultFieldOfView and
-- Blaster's DEFAULT_FOV) -- CameraAuthority owns the actual camera reference and tweening now.
local BASE_FOV = 70

-- ============================================
-- ANIMATION SPEED CONFIGURATION
-- ============================================
local IDLE_ANIM_SPEED = 1.0
local WALK_ANIM_SPEED = 1.0
local RUN_ANIM_SPEED = 1.3
local WALK_SPEED_SCALE = 14.5
local BACKWARDS_WALK_SPEED = 1.0
local JUMP_ANIM_SPEED = 1.0
local FALL_ANIM_SPEED = 1.0
local CLIMB_ANIM_SPEED_SCALE = 12.0
local SIT_ANIM_SPEED = 1.0

-- ============================================
-- RUNNING CONFIGURATION
-- ============================================
local isRunning = false
-- Shared with the server so its lockout clamp and this walk baseline can't drift apart.
local originalWalkSpeed = MovementConstants.WALK_SPEED_BASELINE
local runSpeedBoost = 18
local runAcceleration = 50
local targetWalkSpeed = originalWalkSpeed

-- ============================================
-- LANDING RECOVERY CONFIGURATION
-- ============================================
-- Landing from a sprint-jump stops the player dead, then hands momentum back over the ramp below,
-- so a sprint has to be rebuilt rather than carried straight through the landing animation.
--
-- Both numbers come from the shared movement constants. They used to be local: this said 8
-- (originalWalkSpeed * 0.4) held for 0.35s while the server's clamp said 12 held for 0.5s, two
-- descriptions of the same moment that nothing kept in step.
local LANDING_RECOVERY_SPEED = MovementConstants.LANDING_RECOVERY_WALK_SPEED
local LANDING_RECOVERY_LOCK_DURATION = MovementConstants.LANDING_RECOVERY_HOLD

local isRecoveringFromLanding = false
local landingRecoveryEndTime = 0

-- ============================================
-- FOV CONFIGURATION
-- ============================================
local FOV_TWEEN_TIME = 0.5
local RUN_FOV_BOOST = 15

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1
local animTable = {}

-- R15 animation IDs
local animNames = {
	idle = {
		{ id = "rbxassetid://507766666", weight = 9 },
		{ id = "rbxassetid://507766951", weight = 1 }
	},
	walk = {
		{ id = "rbxassetid://507777826", weight = 10 }
	},
	jump = {
		{ id = "rbxassetid://507765000", weight = 10 }
	},
	fall = {
		{ id = "rbxassetid://507767968", weight = 10 }
	},
	climb = {
		{ id = "rbxassetid://507765644", weight = 10 }
	},
	sit = {
		{ id = "rbxassetid://507768133", weight = 10 }
	},
	run = {
		{ id = "rbxassetid://507767714", weight = 10 }
	},
}

local idleWalkTransitionTime = 0.35

-- ============================================
-- CROUCH CHECK FUNCTION
-- ============================================
local function IsCrouching()
	if HumanoidRootPart then
		return HumanoidRootPart:GetAttribute("IsCrouching") == true
	end
	return false
end

-- ============================================
-- SPRINT GATING (STAMINA)
-- ============================================
-- Sprint keeps a single source of truth: the server owns stamina and publishes CanSprint, which
-- goes false when stamina runs out and back true only once stamina has regenerated past the
-- re-enable threshold. This is a gate on the existing sprint state, not a second sprint detector.
--
-- `sprintHeld` (the raw key state) is deliberately kept separate from `isRunning` (sprint actually
-- granted) so that holding the key through a lockout resumes sprinting the instant the server
-- allows it again, without the player having to release and press the key.
local sprintHeld = false

-- Absent attribute (the moment before the server initialises a freshly spawned character) counts as
-- allowed, so spawning never starts with sprint dead.
local function CanSprint()
	if HumanoidRootPart then
		return HumanoidRootPart:GetAttribute(MovementConstants.CAN_SPRINT_ATTRIBUTE) ~= false
	end
	return true
end

-- Applies the locally desired sprint state and reports it to the server only when it changes. While
-- sprint is locked out this leaves WalkSpeed at the walk baseline and reports nothing, so the key
-- reads as unavailable rather than as a sprint the server silently refuses.
local function updateSprintState()
	local desired = sprintHeld and CanSprint()
	if desired == isRunning then
		return
	end

	isRunning = desired
	if isRunning then
		-- Only change speed if not crouching
		if not IsCrouching() then
			targetWalkSpeed = originalWalkSpeed + runSpeedBoost
		end
	else
		targetWalkSpeed = originalWalkSpeed
	end

	runEvent:FireServer(isRunning)
end

HumanoidRootPart:GetAttributeChangedSignal(MovementConstants.CAN_SPRINT_ATTRIBUTE):Connect(updateSprintState)

function configureAnimationSet(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0
	animTable[name].connections = {}

	local config = script:FindFirstChild(name)
	if (config ~= nil) then
		table.insert(animTable[name].connections, config.ChildAdded:connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:connect(function(child) configureAnimationSet(name, fileList) end))
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				table.insert(animTable[name].connections, childPart.Changed:connect(function(property) configureAnimationSet(name, fileList) end))
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject == nil) then
					animTable[name][idx].weight = 1
				else
					animTable[name][idx].weight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
				idx = idx + 1
			end
		end
	end

	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
		end
	end
end

function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

local function setupRunAnimation()
	local runValue = script:FindFirstChild("run")
	if runValue and runValue:IsA("StringValue") and runValue.Value ~= "" then
		animNames.run = { { id = runValue.Value, weight = 10 } }
	end
end

setupRunAnimation()

for name, fileList in pairs(animNames) do
	configureAnimationSet(name, fileList)
end

local function preloadAnimations()
	local assetsToLoad = {}
	for animName, animSet in pairs(animTable) do
		for i = 1, animSet.count do
			table.insert(assetsToLoad, animSet[i].anim)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(assetsToLoad)
	end)
end

preloadAnimations()
setupRunAnimation()

local jumpAnimTime = 0
local jumpAnimDuration = 0.3
local fallTransitionTime = 0.3

function stopAllAnimations()
	local oldAnim = currentAnim
	currentAnim = ""
	currentAnimInstance = nil
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:disconnect()
	end
	if (currentAnimTrack ~= nil) then
		-- Stop but never Destroy: the track is owned by the locomotionTracks cache and will be
		-- reused. Destroying it would force a fresh LoadAnimation on the next swap, which is what
		-- used to strand tracks on the Animator until it stopped blending anything at all.
		currentAnimTrack:Stop()
		currentAnimTrack = nil
	end
	return oldAnim
end

function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		if currentAnimTrack then
			currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		end
	end
end

function keyFrameReachedFunc(frameName)
	if (frameName == "End") then
		local repeatAnim = currentAnim
		local animSpeed = currentAnimSpeed
		playAnimation(repeatAnim, 0.0, Humanoid)
		setAnimationSpeed(animSpeed)
	end
end

-- One AnimationTrack per Animation instance, created on first use and reused for the life of the
-- character.
--
-- Every swap used to call animator:LoadAnimation and create a brand new track. Tracks that never
-- finish are never released by the Animator -- and an animation whose asset fails to load has
-- length 0, never plays, and so never finishes. Rapid jump/land cycling swapped animations several
-- times a second, and the dead tracks piled up until the Animator hit its ~64-track ceiling. Past
-- that point NOTHING the character played could gain any weight: walk, run and the landing
-- flourish all reported IsPlaying with weight 0, and the character slid along in a static pose.
-- Measured: 64 stranded tracks for a single animation, and a fresh probe track pinned at weight 0.
local locomotionTracks: { [Animation]: AnimationTrack } = {}

function getLocomotionTrack(anim, humanoid)
	local cached = locomotionTracks[anim]
	if cached then
		return cached
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = animator:LoadAnimation(anim)
	track.Priority = AnimationPriorities.Locomotion
	locomotionTracks[anim] = track
	return track
end

function playAnimation(animName, transitionTime, humanoid)
	-- 2026-11-20: StarterCharacterScripts.Movement plays the locomotion clips while it runs (character attribute
	-- MovementAnimations); this script keeps sitting, and its WalkSpeed, sprint, landing recovery and sprint FOV
	if animName ~= "sit" and Figure:GetAttribute("MovementAnimations") then
		stopAllAnimations()
		return
	end
	local roll = math.random(1, animTable[animName].totalWeight)
	local idx = 1
	while (roll > animTable[animName][idx].weight) do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
	local anim = animTable[animName][idx].anim

	if (anim ~= currentAnimInstance) then
		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop(transitionTime)
		end

		currentAnimSpeed = 1.0

		currentAnimTrack = getLocomotionTrack(anim, humanoid)
		currentAnimTrack:Play(transitionTime)
		-- Reused tracks remember the speed they were last adjusted to, so normalise it here to keep
		-- currentAnimSpeed honest -- setAnimationSpeed only writes when the value differs.
		currentAnimTrack:AdjustSpeed(currentAnimSpeed)
		currentAnim = animName
		currentAnimInstance = anim

		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
	end
end

-- ============================================
-- LOCOMOTION RESOLUTION
-- ============================================
-- The locomotion animation has ONE source of truth: the humanoid's actual state and actual speed,
-- re-derived on every tick and on every Humanoid event.
--
-- It used to be assigned by whichever Humanoid event fired last. During rapid jump/land cycling
-- FreeFalling and Running interleave (sometimes several times in a single frame), which could leave
-- `pose` on "FreeFall" while the character was demonstrably grounded and moving at full speed --
-- move() then kept replaying the fall animation instead of walk/run, and nothing corrected it until
-- the next Running event happened to fire. That is the "animation freezes into a stiff pose while
-- still translating" bug.
--
-- Deriving run-vs-walk from REAL speed also means anything that changes the character's speed
-- without going through the sprint key -- the stamina system forcing sprint off, landing recovery,
-- crouch, any future system -- is reflected automatically instead of having to notify this script.

-- Actual speed at which the character starts/stops being presented as sprinting (animation + FOV).
-- These sit above the walk pace and below full sprint, so the run cycle engages as the character
-- accelerates and drops back the moment real speed does.
--
-- Two thresholds rather than one, because speed crosses this band constantly -- landing recovery
-- alone drops it to a third of sprint pace and back. A single threshold made run/walk flip on
-- alternate ticks, and every flip restarts a crossfade from zero weight, which reads as a stutter.
local RUN_PRESENTATION_ENTER_SPEED = originalWalkSpeed + 4
local RUN_PRESENTATION_EXIT_SPEED = originalWalkSpeed + 1
-- Below this the character is presented as standing still.
local IDLE_SPEED_THRESHOLD = 0.5

-- Latched between ticks so the band above behaves as hysteresis rather than a single edge.
local presentingSprint = false

-- Crossfade used when swapping between the ground animations, or landing into one from the air.
-- idleWalkTransitionTime (0.35s) is tuned for easing out of a standstill; it is longer than the
-- time a player spends grounded while spamming jump, so re-using it there meant the walk/run track
-- never climbed off zero weight and the character slid along in a static pose.
local LOCOMOTION_SWAP_TRANSITION = 0.1

local function groundTransition(target: string): number
	if currentAnim == target then
		return 0.1
	end
	if currentAnim == "fall" or currentAnim == "jump" or currentAnim == "walk" or currentAnim == "run" then
		return LOCOMOTION_SWAP_TRANSITION
	end
	-- Easing out of idle (or from nothing at all) keeps the original, softer blend.
	return idleWalkTransitionTime
end

local function getHorizontalSpeed(): number
	local velocity = HumanoidRootPart.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function isMovingBackwards(): boolean
	local velocity = HumanoidRootPart.AssemblyLinearVelocity
	if velocity.Magnitude <= 0.1 then
		return false
	end
	return velocity.Unit:Dot(HumanoidRootPart.CFrame.LookVector) < -0.1
end

-- Backwards by the player's INPUT, not by velocity. Pressed against a wall, collision resolution
-- gives the root a small backward velocity (measured 0.1 to 10.5 studs/s) while the player holds
-- forward, so the velocity test clamped WalkSpeed to 20 every few ticks and the ramp climbed back
-- one tick (20 + 50 * 0.1167 = 25.83) before the next clamp: the 20 / 25.83 swing.
local function isInputBackwards(): boolean
	return Humanoid.MoveDirection:Dot(HumanoidRootPart.CFrame.LookVector) < -0.1
end

-- WalkSpeed targets. A separate concern from animation, but likewise recomputed rather than latched
-- on an input event.
local function resolveMovementTargets()
	if isInputBackwards() then
		targetWalkSpeed = originalWalkSpeed
		-- Clamp rather than assign: this now runs every tick, and a plain assignment would lift the
		-- character straight back out of the landing-recovery cap while walking backwards.
		Humanoid.WalkSpeed = math.min(Humanoid.WalkSpeed, originalWalkSpeed)
	elseif IsCrouching() then
		-- While crouching, ignore sprint input
		targetWalkSpeed = originalWalkSpeed
	elseif isRunning then
		targetWalkSpeed = originalWalkSpeed + runSpeedBoost
	else
		targetWalkSpeed = originalWalkSpeed
	end

	-- Heavy-loot carry (heist layers 2026-11-17): no sprint boost, and the target never above the
	-- cap. Clamped at once rather than ramped down, so a carrier picking up mid-sprint is slow now.
	local carryCap = Figure:GetAttribute(MovementConstants.CARRY_SPEED_CAP_ATTRIBUTE)
	if type(carryCap) == "number" then
		targetWalkSpeed = math.min(originalWalkSpeed, carryCap)
		Humanoid.WalkSpeed = math.min(Humanoid.WalkSpeed, carryCap)
	end
end

local function resolveLocomotion()
	local state = Humanoid:GetState()

	-- These states have dedicated handlers (onClimbing, onSeated, onDied, ...) that own the pose.
	if
		state == Enum.HumanoidStateType.Dead
		or state == Enum.HumanoidStateType.Seated
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Swimming
		or state == Enum.HumanoidStateType.PlatformStanding
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.GettingUp
	then
		return
	end

	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		pose = if state == Enum.HumanoidStateType.Jumping then "Jumping" else "FreeFall"
		CameraAuthority.FieldOfView:Clear("Sprint")
		-- The jump animation owns the first jumpAnimDuration seconds of the arc.
		if jumpAnimTime <= 0 then
			playAnimation("fall", fallTransitionTime, Humanoid)
			setAnimationSpeed(FALL_ANIM_SPEED)
		end
		return
	end

	-- Grounded: Running, RunningNoPhysics, Landed or None.
	local speed = getHorizontalSpeed()

	if speed <= IDLE_SPEED_THRESHOLD then
		pose = "Standing"
		presentingSprint = false
		CameraAuthority.FieldOfView:Clear("Sprint")
		playAnimation("idle", if currentAnim == "idle" then 0.1 else idleWalkTransitionTime, Humanoid)
		setAnimationSpeed(IDLE_ANIM_SPEED)
		return
	end

	pose = "Running"

	if isMovingBackwards() then
		CameraAuthority.FieldOfView:Clear("Sprint")
		playAnimation("walk", groundTransition("walk"), Humanoid)
		setAnimationSpeed(-(speed / WALK_SPEED_SCALE) * WALK_ANIM_SPEED * BACKWARDS_WALK_SPEED)
		return
	end

	-- Run vs walk comes from the speed the character is ACTUALLY moving at, never from the sprint
	-- key, so any forced slow-down shows the walk cycle without that system knowing this exists.
	if presentingSprint then
		presentingSprint = speed > RUN_PRESENTATION_EXIT_SPEED
	else
		presentingSprint = speed >= RUN_PRESENTATION_ENTER_SPEED
	end

	local sprintingNow = presentingSprint and not IsCrouching() and animNames.run[1].id ~= ""

	if sprintingNow then
		CameraAuthority.FieldOfView:Set("Sprint", BASE_FOV + RUN_FOV_BOOST)
		playAnimation("run", groundTransition("run"), Humanoid)
		setAnimationSpeed(RUN_ANIM_SPEED)
	else
		CameraAuthority.FieldOfView:Clear("Sprint")
		playAnimation("walk", groundTransition("walk"), Humanoid)
		setAnimationSpeed((speed / WALK_SPEED_SCALE) * WALK_ANIM_SPEED)
	end
end

function onRunning(speed)
	-- Humanoid.Running is only a hint that something changed; the decision is re-derived, so an
	-- event that arrives out of order (or a stale one) cannot strand the animation state.
	resolveMovementTargets()
	resolveLocomotion()
end

function onDied()
	pose = "Dead"
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	setAnimationSpeed(JUMP_ANIM_SPEED)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
	playAnimation("climb", 0.1, Humanoid)
	setAnimationSpeed(speed / CLIMB_ANIM_SPEED_SCALE)
	pose = "Climbing"
end

function onGettingUp()
	pose = "GettingUp"
end

-- Humanoid.FreeFalling can arrive while the character is already back on the ground during rapid
-- jump/land cycling, so this must NOT assert "we are airborne" -- it just asks for a re-derivation,
-- which reads the humanoid's real state.
function onFreeFall()
	resolveLocomotion()
end

function onFallingDown()
	pose = "FallingDown"
end

-- EVERY landing stops the player dead and then hands momentum back over the ramp in move(). This
-- used to be conditional on having been sprinting; it is not any more, so stepping off a low ledge
-- costs the same as a sprint-jump.
function onLanded()
	isRecoveringFromLanding = true
	landingRecoveryEndTime = time() + LANDING_RECOVERY_LOCK_DURATION
	Humanoid.WalkSpeed = math.min(Humanoid.WalkSpeed, LANDING_RECOVERY_SPEED)
	-- Re-derive immediately so the ground animation engages on touchdown instead of waiting for the
	-- next Humanoid.Running event, which may be up to a whole tick away (or not come at all).
	resolveLocomotion()
end

function onSeated()
	pose = "Seated"
end

function onPlatformStanding()
	pose = "PlatformStanding"
end

function onSwimming(speed)
	if speed > 0 then
		pose = "Running"
	else
		pose = "Standing"
	end
end

local lastTick = 0

function move(time)
	local deltaTime = time - lastTick
	lastTick = time

	if isRecoveringFromLanding and time >= landingRecoveryEndTime then
		isRecoveringFromLanding = false
	end

	-- Recomputed before the speed ramp below so the ramp acts on this tick's target, not last
	-- tick's.
	resolveMovementTargets()

	-- While recovering from a landing, hold speed at the recovery pace regardless of targetWalkSpeed
	-- (which onRunning keeps recalculating to full sprint if sprint+forward are still held) -- once the
	-- recovery window ends this falls back to targetWalkSpeed, and the existing acceleration below
	-- carries the player smoothly back up to it instead of snapping.
	local speedCap = if isRecoveringFromLanding then LANDING_RECOVERY_SPEED else targetWalkSpeed

	if Humanoid.WalkSpeed < speedCap then
		Humanoid.WalkSpeed = math.min(Humanoid.WalkSpeed + runAcceleration * deltaTime, speedCap)
	elseif Humanoid.WalkSpeed > speedCap then
		Humanoid.WalkSpeed = math.max(Humanoid.WalkSpeed - runAcceleration * deltaTime, speedCap)
	end

	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end

	-- Gated on the humanoid's ACTUAL state, not on `pose`. Testing `pose` here latched: a fall left
	-- pose on "FallingDown", this branch then returned before re-deriving, and since a character
	-- holding a constant speed fires no Humanoid.Running event, nothing ever cleared it -- the
	-- character kept moving with every animation stopped. `pose` is an output of this state machine,
	-- so it must never also be an input to it.
	local state = Humanoid:GetState()

	if state == Enum.HumanoidStateType.Seated then
		pose = "Seated"
		playAnimation("sit", 0.5, Humanoid)
		setAnimationSpeed(SIT_ANIM_SPEED)
		return
	elseif
		state == Enum.HumanoidStateType.Dead
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.GettingUp
		or state == Enum.HumanoidStateType.PlatformStanding
	then
		stopAllAnimations()
		return
	end

	-- The tick that makes a stale animation state impossible: even if no Humanoid event fires, or
	-- several fire out of order in one frame, the very next tick re-derives idle/walk/run/fall from
	-- the humanoid's real state and speed.
	resolveLocomotion()
end

-- ============================================
-- INPUT HANDLING
-- ============================================
local function isSprintKey(input)
	return input.KeyCode == Enum.KeyCode.LeftShift
		or input.KeyCode == Enum.KeyCode.RightShift
		or input.KeyCode == Enum.KeyCode.ButtonL2
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	if isSprintKey(input) then
		sprintHeld = true
		updateSprintState()
	end
end

local function onInputEnded(input, gameProcessed)
	if isSprintKey(input) then
		sprintHeld = false
		updateSprintState()
	end
end

local function setupInputConnection()
	local player = Players.LocalPlayer
	if player then
		UserInputService = game:GetService("UserInputService")
		if player.Character == Figure or player.CharacterAdded:Wait() == Figure then
			pcall(function()
				UserInputService.InputBegan:Connect(onInputBegan)
				UserInputService.InputEnded:Connect(onInputEnded)
			end)
		end
	end
end

task.spawn(function()
	task.wait(1)
	setupInputConnection()
end)

-- ============================================
-- HUMANOID EVENT CONNECTIONS
-- ============================================
Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.FreeFalling:connect(onFreeFall)
Humanoid.FallingDown:connect(onFallingDown)
Humanoid.Seated:connect(onSeated)
Humanoid.PlatformStanding:connect(onPlatformStanding)
Humanoid.Swimming:connect(onSwimming)
Humanoid.StateChanged:Connect(function(_, newState)
	if newState == Enum.HumanoidStateType.Landed then
		onLanded()
	end
end)

playAnimation("idle", idleWalkTransitionTime, Humanoid)
setAnimationSpeed(IDLE_ANIM_SPEED)
pose = "Standing"

while Figure.Parent ~= nil do
	-- task.wait() returns only ONE value (elapsed time), unlike legacy wait()'s two, so `move`
	-- gets the elapsed game time from the time() global instead -- the same global onLanded()
	-- above already uses for this exact concept.
	task.wait(0.1)
	move(time())
end