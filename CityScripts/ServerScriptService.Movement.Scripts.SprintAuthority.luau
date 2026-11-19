-- Server-side authority for sprint + stamina.
--
-- Trust model, mirroring the Blaster system: the client reports sprint INTENT over
-- UpdateRunningState, and the server decides whether that intent is granted. Because stamina gates
-- a movement ability, a client cannot be allowed to self-report "I still have stamina".
--
-- This module is the single writer of the shared IsSprinting attribute -- RunningState hands it the
-- validated client intent and nothing else touches that attribute, so stamina gating goes through
-- the same one source of truth that Lean.isCharacterSprinting() already reads rather than adding
-- another independent notion of "is sprinting".
--
-- Replication is by attribute, not by RemoteEvent: the stamina maths runs every Heartbeat (so the
-- 10-second drain is exact regardless of frame rate) but the value is only published at
-- SERVER_PUBLISH_INTERVAL, plus immediately whenever the lockout state flips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Movement.Constants)
local staminaStep = require(ReplicatedStorage.Movement.Scripts.staminaStep)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

type PlayerState = {
	-- What the client last asked for, after validation. Intent is kept separate from the granted
	-- IsSprinting state so that a player who holds the key through a lockout resumes sprinting the
	-- moment stamina recovers, without having to release and press again.
	intent: boolean,
	stamina: staminaStep.StaminaState,
	secondsSincePublish: number,
	-- os.clock() timestamp until which this player is in post-landing recovery; 0 = not recovering.
	landingRecoveryUntil: number,
	-- True while the server is holding WalkSpeed below the walk baseline (landing recovery or a
	-- weapon stun). Both share one release, so whichever ends last restores the baseline.
	belowBaselineClamped: boolean,
}

local SprintAuthority = {}

local states: { [Player]: PlayerState } = {}
local started = false

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = {
			intent = false,
			stamina = staminaStep.newState(),
			secondsSincePublish = 0,
			landingRecoveryUntil = 0,
			belowBaselineClamped = false,
		}
		states[player] = state
	end
	return state
end

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return if rootPart and rootPart:IsA("BasePart") then rootPart else nil
end

local function publish(rootPart: BasePart, state: PlayerState)
	state.secondsSincePublish = 0
	rootPart:SetAttribute(Constants.STAMINA_ATTRIBUTE, state.stamina.stamina)
end

-- Horizontal speed only: a fall or a jump adds vertical velocity that has nothing to do with
-- whether the player is sprinting along the ground.
local function getHorizontalSpeed(rootPart: BasePart): number
	local velocity = rootPart.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

-- Records the client's (already validated) sprint intent. Whether it is granted is decided here,
-- not by the client.
function SprintAuthority.setIntent(player: Player, isRunning: boolean)
	local state = getState(player)
	state.intent = isRunning

	local rootPart = getRootPart(player)
	if not rootPart then
		return
	end

	-- A sprint request from a locked-out player is simply not granted. The client checks this too
	-- (so the key feels dead rather than laggy), but the decision is the server's.
	rootPart:SetAttribute(Constants.SPRINTING_ATTRIBUTE, isRunning and not state.stamina.lockedOut)
end

function SprintAuthority.cleanup(player: Player)
	states[player] = nil
end

-- Exposed for tests/debugging: the server's current view of a player's stamina.
function SprintAuthority.getStamina(player: Player): number?
	local state = states[player]
	return state and state.stamina.stamina
end

-- Spends `amount` stamina at once (the roll, 2026-11-20: RollAuthority), only if the player has that much. It counts
-- as a drain: the regen delay starts again, and emptying the bar locks sprint out as a sprint to empty does.
-- Returns whether it was spent.
function SprintAuthority.spend(player: Player, amount: number): boolean
	local state = getState(player)
	if state.stamina.lockedOut or state.stamina.stamina < amount then
		return false
	end
	state.stamina.stamina -= amount
	state.stamina.secondsSinceDrain = 0
	if state.stamina.stamina <= 0 then
		state.stamina.lockedOut = true
	end
	local rootPart = getRootPart(player)
	if rootPart then
		rootPart:SetAttribute(Constants.CAN_SPRINT_ATTRIBUTE, not state.stamina.lockedOut)
		publish(rootPart, state)
	end
	return true
end

local function onCharacterAdded(player: Player, character: Model)
	local state = getState(player)
	state.intent = false
	state.stamina = staminaStep.newState()
	state.secondsSincePublish = 0
	state.landingRecoveryUntil = 0
	state.belowBaselineClamped = false

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	rootPart:SetAttribute(Constants.STAMINA_ATTRIBUTE, state.stamina.stamina)
	rootPart:SetAttribute(Constants.CAN_SPRINT_ATTRIBUTE, true)
	rootPart:SetAttribute(Constants.SPRINTING_ATTRIBUTE, false)

	-- Landing recovery: reuses the engine's own Landed state rather than hand-rolling a fall-speed
	-- threshold. Scoped to this character's own lifetime; a fresh humanoid on respawn gets its own
	-- connection, so nothing needs manual disconnection here.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed then
				state.landingRecoveryUntil = os.clock() + Constants.LANDING_RECOVERY_DURATION
			end
		end)
	end
end

local function tick(deltaTime: number)
	for player, state in states do
		local rootPart = getRootPart(player)
		if rootPart then
			local wasLockedOut = state.stamina.lockedOut
			local isMovingFast = getHorizontalSpeed(rootPart) >= Constants.MIN_DRAIN_SPEED
			-- Shared signal written by ShotResolver on a hit from a weapon declaring stunDuration.
			local stunnedUntil = rootPart:GetAttribute("StunnedUntil") or 0
			local isStunned = os.clock() < stunnedUntil
			local isLandingRecovering = os.clock() < state.landingRecoveryUntil
			-- Heavy-loot carry (heist layers 2026-11-17), set by CarryState on the character.
			local carryCap = rootPart.Parent and rootPart.Parent:GetAttribute(Constants.CARRY_SPEED_CAP_ATTRIBUTE)
			local isCarryCapped = type(carryCap) == "number"

			staminaStep.step(state.stamina, state.intent, isMovingFast, deltaTime)

			local lockedOut = state.stamina.lockedOut
			if lockedOut ~= wasLockedOut then
				rootPart:SetAttribute(Constants.CAN_SPRINT_ATTRIBUTE, not lockedOut)
				-- Publish the crossing value immediately rather than waiting for the next interval,
				-- so the client's bar and its lockout feedback flip in the same frame.
				publish(rootPart, state)
			end

			-- The granted sprint state is re-asserted every tick, so a player who is still holding
			-- the key resumes automatically when the lockout lifts, and is dropped out of sprint
			-- the moment it applies.
			local granted = state.intent and not lockedOut and not isLandingRecovering and not isStunned
				and not isCarryCapped
			if rootPart:GetAttribute(Constants.SPRINTING_ATTRIBUTE) ~= granted then
				rootPart:SetAttribute(Constants.SPRINTING_ATTRIBUTE, granted)
			end

			-- Server-side speed correction. Animate2 drives WalkSpeed on the client, and a client's
			-- own writes to WalkSpeed are local -- they never reach the server -- so this clamp is
			-- stable rather than a tug-of-war: while a player is locked out, the server's Humanoid
			-- reads at most the walk baseline, and it replicates that correction down to the client.
			if lockedOut then
				local humanoid = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.WalkSpeed > Constants.WALK_SPEED_BASELINE then
					humanoid.WalkSpeed = Constants.WALK_SPEED_BASELINE
				end
			end

			-- Same idea, for the brief window right after landing -- clamped BELOW the normal walk
			-- baseline (not just capped at it), so this slows ordinary walking too, not only sprint.
			-- Applied after the lockout clamp, so when both are active the lower speed wins.
			local humanoid = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
			if isLandingRecovering and humanoid then
				-- The cap RAMPS rather than sitting flat. A flat cap at a dead stop would pin the
				-- player for the whole window and then hand back the full baseline in one step,
				-- which reads as a teleport. Animate2 accelerates out of the landing at the same
				-- rate on the client, so both authorities describe one curve and the server's
				-- correction never contradicts what the player is already feeling.
				local elapsed = os.clock()
					- (state.landingRecoveryUntil - Constants.LANDING_RECOVERY_DURATION)
				local ramping = math.max(0, elapsed - Constants.LANDING_RECOVERY_HOLD)
				local cap = math.min(
					Constants.WALK_SPEED_BASELINE,
					Constants.LANDING_RECOVERY_WALK_SPEED
						+ Constants.LANDING_RECOVERY_ACCELERATION * ramping
				)
				-- Driven to the cap in BOTH directions, not merely clamped down to it. Clamping only
				-- downward leaves the server's own WalkSpeed pinned at the floor for the whole window,
				-- because a client's writes never reach the server -- so the release at the end of the
				-- window arrives as a step from the floor straight to the baseline, and that step
				-- replicates down and wipes the momentum the client has already rebuilt. Measured
				-- before this line: the client was at 25.6 and got stamped back to 20. Following the
				-- ramp upward means the server is already at the baseline when the window closes, so
				-- the release below has nothing to do.
				if math.abs(humanoid.WalkSpeed - cap) > 0.01 then
					humanoid.WalkSpeed = cap
				end
				state.belowBaselineClamped = true
			end

			-- Carry cap: clamped down only (never raised), after the landing ramp so the ramp cannot
			-- lift a carrier past it. Shares the below-baseline release, so clearing the attribute
			-- hands the baseline back.
			if isCarryCapped and humanoid then
				if humanoid.WalkSpeed > carryCap then
					humanoid.WalkSpeed = carryCap
				end
				state.belowBaselineClamped = true
			end

			-- Applied last, so when a stun and a landing recovery overlap the more restrictive of
			-- the two wins and neither ends the other early.
			if isStunned and humanoid then
				if humanoid.WalkSpeed > 0 then
					humanoid.WalkSpeed = 0
				end
				state.belowBaselineClamped = true
			end

			if not isLandingRecovering and not isStunned and not isCarryCapped and state.belowBaselineClamped then
				-- Release. Unlike the lockout clamp above -- which pins WalkSpeed to the very value
				-- Animate2 already walks at, so letting go is a no-op -- this one holds it BELOW the
				-- baseline, and a client's WalkSpeed writes are local and never reach the server. So
				-- if the server does not raise it back itself, its Humanoid stays pinned at the
				-- recovery speed for the rest of the character's life (measured: stuck at 12 for the
				-- full 17s of a test run instead of 0.5s).
				if humanoid and humanoid.WalkSpeed < Constants.WALK_SPEED_BASELINE then
					humanoid.WalkSpeed = Constants.WALK_SPEED_BASELINE
				end
				state.belowBaselineClamped = false
			end

			-- Admin walk speed (2026-11-20): written last, so no clamp above outlasts it while the character
			-- carries AdminWalkSpeed (the admin panel sets it; it goes with the character on death).
			local adminSpeed = rootPart.Parent and rootPart.Parent:GetAttribute("AdminWalkSpeed")
			if type(adminSpeed) == "number" and humanoid and humanoid.WalkSpeed ~= adminSpeed then
				humanoid.WalkSpeed = adminSpeed
			end

			state.secondsSincePublish += deltaTime
			if state.secondsSincePublish >= Constants.SERVER_PUBLISH_INTERVAL then
				publish(rootPart, state)
			end
		end
	end
end

function SprintAuthority.start()
	if started then
		return
	end
	started = true

	safePlayerAdded(function(player: Player)
		getState(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		SprintAuthority.cleanup(player)
	end)

	RunService.Heartbeat:Connect(tick)
end

return SprintAuthority
