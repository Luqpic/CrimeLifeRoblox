-- AI enemy state machine: Patrol -> Chase -> Attack -> Search -> Patrol, plus Dead.
--
-- The enemy does not implement shooting. It calls the same server-side resolver the player's Shoot
-- RemoteEvent calls (ServerScriptService.Blaster.Scripts.ShotResolver), passing its real muzzle
-- position and aim, so range, spread, damage, headshots, occlusion and replication are the player's
-- code paths verbatim. Its engagement range is derived from the equipped weapon's own `range`
-- attribute for the same reason -- there is no NPC-only range number to drift out of sync.
--
-- Scheduling: every enemy "thinks" on Constants.THINK_INTERVAL, not per frame, and enemies are given
-- random phase offsets so their ticks spread across the interval instead of landing on one frame.
-- Between thinks the engine moves them via Humanoid:MoveTo, which costs us nothing per frame.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local AnimationPriorities = require(ReplicatedStorage.Modules.AnimationPriorities)
local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local CharacterAnimationController = require(ReplicatedStorage.Blaster.Scripts.CharacterAnimationController)
local AimConfig = require(ReplicatedStorage.Enemy.AimConfig)
local Constants = require(ReplicatedStorage.Enemy.Constants)
local RagdollController = require(ReplicatedStorage.Modules.RagdollController)
local ShotResolver = require(ServerScriptService.Blaster.Scripts.ShotResolver)
local getRayDirections = require(ReplicatedStorage.Blaster.Utility.getRayDirections)
local locomotionAnimations = require(ReplicatedStorage.Movement.Scripts.locomotionAnimations)
local templateConfig = require(ReplicatedStorage.Enemy.templateConfig)

local taggedEvent = ServerScriptService.Blaster.Events.Tagged

local STATE = {
	Patrol = "Patrol",
	Chase = "Chase",
	Attack = "Attack",
	Search = "Search",
	Dead = "Dead",
}

local EnemyAI = {}
EnemyAI.__index = EnemyAI
EnemyAI.State = STATE

-- Every live enemy, plus a humanoid -> enemy lookup so the single shared Tagged connection below can
-- find who was shot in O(1) instead of scanning.
local activeEnemies: { [any]: boolean } = {}
local enemiesByHumanoid: { [Humanoid]: any } = {}
local schedulerConnection: RBXScriptConnection? = nil
EnemyAI._activeEnemies = activeEnemies -- read by getLive; exposed for EnemyTargetFilter_Test only

-- ============================================================================
-- HELPERS
-- ============================================================================

local function getAimPosition(humanoid: Humanoid): Vector3?
	local rootPart = humanoid.RootPart
	return rootPart and rootPart.Position or nil
end

-- ============================================================================
-- CONSTRUCTION
-- ============================================================================

-- `character` must already be parented to Workspace, tagged Constants.ENEMY_TAG, and holding
-- `weapon` (the Tool that came with its rig template). The spawner does all of that.
--
-- `config` carries this enemy TYPE's tunables, read off its rig template's attributes. Omit it and
-- the shared defaults are used, which is what a template with no attributes resolves to anyway.
function EnemyAI.new(
	character: Model,
	weapon: Tool,
	spawnPosition: Vector3,
	onDied: ((any) -> ())?,
	config: templateConfig.EnemyConfig?
)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{character:GetFullName()} has no Humanoid`)
	assert(humanoid.RootPart, `{character:GetFullName()} has no RootPart`)

	local self = setmetatable({
		character = character,
		humanoid = humanoid,
		rootPart = humanoid.RootPart,
		weapon = weapon,
		spawnPosition = spawnPosition,
		onDied = onDied,
		-- Reading the character itself works because the spawner clones the template, so the clone
		-- carries the same attributes the designer set on the template.
		config = config or templateConfig.read(character),

		state = STATE.Patrol,
		target = nil :: Player?,
		-- When the current target was acquired, for AimConfig's reaction-lag term.
		targetAcquiredTime = 0,
		lastKnownPosition = nil :: Vector3?,

		-- Path state. A path is reused until it goes stale or its destination moves far enough.
		waypoints = nil :: { PathWaypoint }?,
		waypointIndex = 1,
		pathDestination = nil :: Vector3?,
		pathComputedAt = 0,

		patrolDwellUntil = 0,
		searchUntil = 0,
		-- One-shot guard for the Search-state look-around. Reset on every fresh entry into Search,
		-- see _setState.
		hasLookedAround = false,
		fireGeneration = 0,
		-- Used to average travel speed across think ticks for locomotion animation selection.
		lastSpeedPosition = nil :: Vector3?,
		lastSpeedSampleTime = nil :: number?,
		-- Real time of the last shot that actually left the barrel, so the weapon's own rate of fire
		-- gates the AI the same way it gates a player between clicks.
		lastShotTime = 0,
		-- Accumulated recoil, in radians, folded into the aim origin of every shot. See _decayRecoil.
		recoilOffset = Vector2.new(0, 0),
		lastRecoilTime = nil :: number?,
		thinking = false,
		destroyed = false,
		nextThinkTime = 0,
		-- True on the previous think while StunnedUntil (see ShotResolver) was in the future.
		-- Lets the stun handling in `think` tell "just became stunned" / "still stunned" /
		-- "just recovered" apart with one flag instead of three separate checks.
		wasStunned = false,

		connections = {},
	}, EnemyAI)

	character:SetAttribute("AIState", self.state)
	self:_setupAnimations()

	table.insert(self.connections, humanoid.Died:Connect(function()
		self:_enterDead()
	end))

	activeEnemies[self] = true
	enemiesByHumanoid[humanoid] = self

	-- Stagger the first think randomly inside the interval so a batch of enemies spawned on the same
	-- frame does not think on the same frame forever after.
	self.nextThinkTime = os.clock() + math.random() * Constants.THINK_INTERVAL

	EnemyAI._ensureScheduler()
	return self
end

function EnemyAI:_setupAnimations()
	-- Shoot/reload come from the Tool's own Animations folder through the shared controller -- the
	-- same third-person animations a player's character plays, on the shared priority scheme.
	local ok, controller = pcall(function()
		local animationController = CharacterAnimationController.new(self.weapon)
		animationController:enable()
		return animationController
	end)
	self.animationController = if ok then controller else nil
	if not ok then
		warn(`EnemyAI: could not load weapon animations for {self.character:GetFullName()}: {controller}`)
	end

	-- Locomotion. Driven here because the runtime-built rig's own `Animate` LocalScript is stripped
	-- by the spawner, but the animations come from the player's movement animations -- the same
	-- Animation instances Animate2 plays -- so an enemy and a player walking look identical and
	-- there is no second id list to drift.
	local animator = self.humanoid:FindFirstChildOfClass("Animator")
		or Instance.new("Animator", self.humanoid)

	self.locomotionTracks = {}
	for _, setName in { "idle", "walk", "run" } do
		local animation = locomotionAnimations.get(setName)
		if animation then
			local track = animator:LoadAnimation(animation)
			track.Priority = AnimationPriorities.Locomotion
			track.Looped = true
			self.locomotionTracks[setName] = track
		end
	end
	self.currentLocomotionSet = nil :: string?
end

-- ============================================================================
-- MOVEMENT
-- ============================================================================

function EnemyAI:_clearPath()
	self.waypoints = nil
	self.pathDestination = nil
	self.waypointIndex = 1
end

-- Computes a path only when the current one is stale or its destination has moved far enough. This
-- is the expensive call in the whole system, so it is deliberately rate limited rather than run per
-- think, let alone per frame.
function EnemyAI:_needsNewPath(destination: Vector3, now: number): boolean
	if not self.waypoints or not self.pathDestination then
		return true
	end
	if now - self.pathComputedAt < Constants.PATH_REPLAN_INTERVAL then
		return false
	end
	return (destination - self.pathDestination).Magnitude > Constants.PATH_REPLAN_DISTANCE
end

function EnemyAI:_computePath(destination: Vector3, now: number): boolean
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	local ok = pcall(function()
		path:ComputeAsync(self.rootPart.Position, destination)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		self:_clearPath()
		return false
	end

	self.waypoints = path:GetWaypoints()
	self.waypointIndex = 1
	self.pathDestination = destination
	self.pathComputedAt = now
	return true
end

function EnemyAI:_followPath(destination: Vector3, speed: number, now: number)
	self.humanoid.WalkSpeed = speed

	if self:_needsNewPath(destination, now) then
		self:_computePath(destination, now)
	end

	local waypoints = self.waypoints
	if not waypoints then
		-- No route available: walk straight at the destination so the enemy still behaves rather than
		-- standing still. Pathfinding will be retried on the next replan.
		self.humanoid:MoveTo(destination)
		return
	end

	-- Advance past any waypoints we have already reached.
	while self.waypointIndex <= #waypoints do
		local waypoint = waypoints[self.waypointIndex]
		local offset = waypoint.Position - self.rootPart.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > 4 then
			break
		end
		self.waypointIndex += 1
	end

	local waypoint = waypoints[self.waypointIndex]
	if not waypoint then
		self:_clearPath()
		self.humanoid:MoveTo(destination)
		return
	end

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		self.humanoid.Jump = true
	end
	self.humanoid:MoveTo(waypoint.Position)
end

function EnemyAI:_stopMoving()
	self.humanoid:MoveTo(self.rootPart.Position)
	self:_clearPath()
end

-- Turn to face a position, yaw only, so an attacking enemy looks at its target while standing still
-- (Humanoid.AutoRotate only turns us while we are walking somewhere).
function EnemyAI:_faceTowards(position: Vector3)
	local from = self.rootPart.Position
	local flatTarget = Vector3.new(position.X, from.Y, position.Z)
	if (flatTarget - from).Magnitude < 0.1 then
		return
	end
	self.rootPart.CFrame = CFrame.lookAt(from, flatTarget)
end

-- Picks idle / walk / run from what the character is actually doing, and crossfades only when the
-- choice changes.
function EnemyAI:_updateLocomotionAnimation()
	local tracks = self.locomotionTracks
	if not tracks then
		return
	end

	-- Keyed off how far the character actually travelled since the last think, averaged over that
	-- interval.
	--
	-- Two signals were tried and rejected. Humanoid.MoveDirection reads zero for a server-driven
	-- humanoid navigating with MoveTo even while it is walking, so it made every enemy look
	-- permanently idle. Instantaneous AssemblyLinearVelocity (what Animate2 uses, correctly, for a
	-- continuously-controlled player) also reads zero most of the time here, because MoveTo
	-- navigation is stop-and-go: the character reaches a path waypoint, halts, and waits for the next
	-- think to be sent onward. Averaging over the interval sees through those gaps.
	local now = os.clock()
	local position = self.rootPart.Position
	local speed = 0
	if self.lastSpeedSampleTime and now > self.lastSpeedSampleTime then
		local travelled = position - (self.lastSpeedPosition or position)
		speed = Vector3.new(travelled.X, 0, travelled.Z).Magnitude / (now - self.lastSpeedSampleTime)
	end
	self.lastSpeedPosition = position
	self.lastSpeedSampleTime = now

	local desiredSet
	if speed <= Constants.IDLE_SPEED_THRESHOLD then
		desiredSet = "idle"
	elseif speed > self.config.walkSpeed + Constants.RUN_SPEED_MARGIN then
		desiredSet = "run"
	else
		desiredSet = "walk"
	end

	if desiredSet == self.currentLocomotionSet then
		return
	end

	local previous = self.currentLocomotionSet and tracks[self.currentLocomotionSet]
	if previous and previous.IsPlaying then
		previous:Stop(0.2)
	end

	self.currentLocomotionSet = desiredSet
	local track = tracks[desiredSet]
	if track and not track.IsPlaying then
		track:Play(0.2)
	end
end

-- ============================================================================
-- PERCEPTION
-- ============================================================================

function EnemyAI:_eyePosition(): Vector3
	local head = self.character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return self.rootPart.Position
end

function EnemyAI:_muzzlePosition(): Vector3
	local muzzle = self.weapon:FindFirstChild("MuzzleAttachment", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	local handle = self.weapon:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle.Position
	end
	return self:_eyePosition()
end

-- The engagement distance, derived from the equipped weapon's own range rather than an NPC-only
-- number. See Constants.ENGAGE_RANGE_FRACTION for why a fraction of it is used.
function EnemyAI:_engageRange(): number
	local range = self.weapon:GetAttribute(BlasterConstants.RANGE_ATTRIBUTE) or 0
	return range * self.config.engageRangeFraction
end

-- Police and wanted (2026-11-17): an enemy whose config carries `targetFilter` (police: wanted players
-- only) never takes, keeps or retaliates against a player the filter refuses. Gangs pass no filter, so for
-- them this is always true and nothing changes.
function EnemyAI:_accepts(player): boolean
	local filter = self.config.targetFilter
	return filter == nil or filter(player) == true
end

-- The player list _findVisibleTarget scans; a seam so EnemyTargetFilter_Test can serve stand-ins.
function EnemyAI._players(): { Player }
	return Players:GetPlayers()
end

-- Nearest living player inside DETECTION_RADIUS with a clear line of sight, using the resolver's own
-- occlusion query so "can I see you" and "can I shoot you" cannot disagree. An enemy whose config has
-- `preferTarget` (police: its squad's player) takes that player whenever it is visible.
function EnemyAI:_findVisibleTarget(): (Player?, Humanoid?)
	local eyePosition = self:_eyePosition()
	local bestPlayer, bestHumanoid, bestDistance = nil, nil, math.huge
	local preferred = self.config.preferTarget and self.config.preferTarget()

	for _, player in EnemyAI._players() do
		if not self:_accepts(player) then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		local aimPosition = getAimPosition(humanoid)
		if not aimPosition then
			continue
		end

		local distance = (aimPosition - eyePosition).Magnitude
		if distance > self.config.detectionRadius or (distance >= bestDistance and player ~= preferred) then
			continue
		end
		if not ShotResolver.hasLineOfSight(self.character, eyePosition, humanoid) then
			continue
		end
		if player == preferred then
			return player, humanoid
		end

		bestPlayer, bestHumanoid, bestDistance = player, humanoid, distance
	end

	return bestPlayer, bestHumanoid
end

-- Public line-of-sight check from this enemy's eyes, the same one detection uses (the wanted service's
-- "seen"). Always a boolean.
function EnemyAI:canSee(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and ShotResolver.hasLineOfSight(self.character, self:_eyePosition(), humanoid) == true
end

-- Single place the target changes, so the acquisition timestamp behind AimConfig's reaction-lag term
-- cannot be forgotten at one of the call sites. Re-acquiring the same target after losing it also
-- re-stamps, which is the point: the enemy has to re-settle its aim.
function EnemyAI:_setTarget(player: Player?)
	if player ~= self.target then
		self.targetAcquiredTime = os.clock()
	end
	self.target = player
end

function EnemyAI:_targetHumanoid(): Humanoid?
	local player = self.target
	if player and not self:_accepts(player) then
		return nil -- e.g. a wanted player's heat reached 0 mid-fight: no longer chased or shot
	end
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- True only if we still have a target AND its humanoid exists but has died (Health <= 0) -- as
-- opposed to simply being unreachable (player disconnected, character not loaded). This is what
-- lets Chase/Attack tell "the target died" (give up immediately, ignore the corpse entirely)
-- apart from "lost track of a still-living target" (searching its last known position is
-- correct and unchanged).
function EnemyAI:_isTargetDead(): boolean
	local player = self.target
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health <= 0
end

-- ============================================================================
-- FIRING
-- ============================================================================

function EnemyAI:_stopFiring()
	-- Invalidating the generation is what stops the automatic loop; a stale loop can never fire again.
	self.fireGeneration += 1
end

-- Automatic weapons hold the trigger down; semi-automatic weapons fire once per trigger pull. This
-- is read off the weapon, exactly as BlasterController reads it for a player.
function EnemyAI:_isAutomatic(): boolean
	return self.weapon:GetAttribute(BlasterConstants.FIRE_MODE_ATTRIBUTE) == BlasterConstants.FIRE_MODE.AUTO
end

-- Minimum interval between shots, from the weapon's own rateOfFire. Same constant and same role it
-- plays for a player: BlasterController blocks a semi-auto weapon for 60/rateOfFire after a click.
function EnemyAI:_shotCooldown(): number
	local rateOfFire = self.weapon:GetAttribute(BlasterConstants.RATE_OF_FIRE_ATTRIBUTE) or 600
	return 60 / math.max(rateOfFire, 1)
end

-- One trigger pull, for a semi-automatic weapon.
--
-- A player's cadence on a semi-auto is set by how fast they can click, with the weapon's rateOfFire
-- only imposing a ceiling. The AI's equivalent of a click is one Attack think tick, and the same
-- rateOfFire ceiling is enforced on top -- so a slow-firing weapon is still limited by its own
-- config, and a fast one is limited by the trigger pull rather than firing like an automatic.
--
-- lastShotTime only advances when a shot actually left the barrel, so a pull wasted on a blocked
-- line of sight or an empty magazine does not eat into the next one.
function EnemyAI:_tryFire(now: number)
	if now - self.lastShotTime < self:_shotCooldown() then
		return
	end
	if self:_fireOnce() then
		self.lastShotTime = now
	end
end

function EnemyAI:_reload()
	local weapon = self.weapon
	if weapon:GetAttribute(BlasterConstants.RELOADING_ATTRIBUTE) then
		return
	end

	-- Same attributes and the same reloadTime the player's reload uses, read off the same Tool.
	local reloadTime = weapon:GetAttribute(BlasterConstants.RELOAD_TIME_ATTRIBUTE) or 1
	local magazineSize = weapon:GetAttribute(BlasterConstants.MAGAZINE_SIZE_ATTRIBUTE) or 1

	weapon:SetAttribute(BlasterConstants.RELOADING_ATTRIBUTE, true)
	if self.animationController then
		pcall(function()
			self.animationController:playReloadAnimation(reloadTime)
		end)
	end

	task.delay(reloadTime, function()
		if self.destroyed then
			return
		end
		weapon:SetAttribute(BlasterConstants.AMMO_ATTRIBUTE, magazineSize)
		weapon:SetAttribute(BlasterConstants.RELOADING_ATTRIBUTE, false)
	end)
end

-- Rotates a perfect aim direction by a random amount inside an error cone.
--
-- Reuses getRayDirections -- the same seeded angular-deviation helper the weapon system already uses
-- to derive its spread pattern -- rather than introducing a second randomisation mechanism. The seed
-- is offset from the shot's own seed so the aim cone and the weapon's spread cone draw different
-- numbers; sharing a seed would make both deviate identically and simply stack.
function EnemyAI:_applyAimError(trueOrigin: CFrame, targetHumanoid: Humanoid, seed: number): CFrame
	local targetRoot = targetHumanoid.RootPart
	if not targetRoot then
		return trueOrigin
	end

	local distance = (targetRoot.Position - trueOrigin.Position).Magnitude
	local velocity = targetRoot.AssemblyLinearVelocity
	local targetSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local secondsSinceAcquired = os.clock() - (self.targetAcquiredTime or 0)

	local errorDegrees = AimConfig.getErrorDegrees(distance, targetSpeed, secondsSinceAcquired, self.config.aim)
	if errorDegrees <= 0 then
		return trueOrigin
	end

	local deviated = getRayDirections(trueOrigin, 1, math.rad(errorDegrees), seed + AimConfig.SEED_DECORRELATION_OFFSET)[1]
	if not deviated then
		return trueOrigin
	end

	return CFrame.lookAt(trueOrigin.Position, trueOrigin.Position + deviated)
end

-- Decays the accumulated recoil toward zero based on real elapsed time since it was last touched.
-- Called lazily right before each shot rather than on a separate timer -- a long gap since the last
-- shot (e.g. the enemy stopped firing entirely) naturally decays it back to ~0 in one lump, which is
-- correct and needs no separate "stopped firing" handling.
function EnemyAI:_decayRecoil(now: number)
	local elapsed = now - (self.lastRecoilTime or now)
	self.lastRecoilTime = now

	local magnitude = self.recoilOffset.Magnitude
	if magnitude <= 1e-4 then
		self.recoilOffset = Vector2.new(0, 0)
		return
	end
	local decay = math.min(Constants.RECOIL_DECAY_RATE * elapsed, magnitude)
	self.recoilOffset -= self.recoilOffset.Unit * decay
end

-- Adds one shot's worth of kick, same random-in-range math as BlasterController:recoil() for the
-- player, so an enemy's recoil feel matches the player's for the same weapon.
function EnemyAI:_accumulateRecoil()
	-- A per-template override applies only here, inside the AI -- a player holding the same Tool
	-- still reads the weapon's own attributes and feels unchanged recoil.
	local recoilMin = self.config.recoilMinOverride or self.weapon:GetAttribute(BlasterConstants.RECOIL_MIN_ATTRIBUTE)
	local recoilMax = self.config.recoilMaxOverride or self.weapon:GetAttribute(BlasterConstants.RECOIL_MAX_ATTRIBUTE)
	if not recoilMin or not recoilMax then
		return
	end

	local xDif = recoilMax.X - recoilMin.X
	local yDif = recoilMax.Y - recoilMin.Y
	local kick = Vector2.new(
		math.rad(-(recoilMin.X + math.random() * xDif)),
		math.rad(recoilMin.Y + math.random() * yDif)
	)

	self.recoilOffset += kick
	local maxRadians = math.rad(Constants.RECOIL_MAX_OFFSET_DEGREES)
	if self.recoilOffset.Magnitude > maxRadians then
		self.recoilOffset = self.recoilOffset.Unit * maxRadians
	end
end

function EnemyAI:_fireOnce(): boolean
	local weapon = self.weapon
	if weapon:GetAttribute(BlasterConstants.RELOADING_ATTRIBUTE) then
		return false
	end

	local ammo = weapon:GetAttribute(BlasterConstants.AMMO_ATTRIBUTE) or 0
	if ammo <= 0 then
		self:_reload()
		return false
	end

	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		return false
	end
	local aimPosition = getAimPosition(targetHumanoid)
	if not aimPosition then
		return false
	end

	local muzzlePosition = self:_muzzlePosition()
	if not ShotResolver.hasLineOfSight(self.character, muzzlePosition, targetHumanoid) then
		return false
	end

	-- Aim at the torso. Enemies do not deliberately go for the head; a headshot only happens if the
	-- aim error or the weapon's own spread happens to put a ray there, as it would for a player.
	--
	-- The aim is then deliberately spoiled before the shot is resolved, by an amount that grows with
	-- range and with how fast the target is moving (see AimConfig). The resolver is handed an
	-- already-adjusted direction and stays completely unaware of who is shooting.
	local seed = Workspace:GetServerTimeNow()
	local origin = self:_applyAimError(CFrame.lookAt(muzzlePosition, aimPosition), targetHumanoid, seed)

	-- Recoil is folded in BEFORE this shot's own kick is accumulated below, so a shot is thrown off
	-- by every PREVIOUS shot's recoil and never by its own -- matching how a real weapon's kick
	-- spoils the follow-up shot rather than the one that caused it. Unlike the aim cone above, this
	-- term persists between shots, which is what makes a held trigger walk off target.
	self:_decayRecoil(os.clock())
	origin = origin * CFrame.Angles(self.recoilOffset.Y, self.recoilOffset.X, 0)

	if self.animationController then
		pcall(function()
			self.animationController:playShootAnimation()
		end)
	end

	-- Melee weapons declare a swingDelay so the hit lands when the swing visually reaches the
	-- target -- the same problem BlasterController's own player-facing fix already solved. Without
	-- this, a melee enemy's damage resolves the instant the swing starts, before the animation has
	-- moved the weapon anywhere near the target. Guns leave this unset/0, so their behaviour
	-- (instant hit) is completely unchanged.
	--
	-- Recoil still accumulates synchronously below, exactly as before: origin already has the
	-- PREVIOUS shots' recoil baked in further up, so this shot's own kick has only ever affected
	-- the next shot, deferred hit or not.
	local swingDelay = weapon:GetAttribute(BlasterConstants.SWING_DELAY_ATTRIBUTE) or 0
	local character = self.character
	local function resolveHit()
		if self.destroyed or not character.Parent then
			return -- the enemy died or was cleaned up during the delay
		end
		ShotResolver.resolveShot({
			shooter = character,
			weapon = weapon,
			origin = origin,
			seed = seed,
			-- No claimedTags: there is no client here to claim hits, so the server's own cast
			-- resolves them. This is the single difference between this call and the player's.
		})
	end

	if swingDelay > 0 then
		task.delay(swingDelay, resolveHit)
	else
		resolveHit()
	end

	self:_accumulateRecoil()

	return true
end

-- Holds the trigger down, for an automatic weapon only: fires continuously at the weapon's real rate
-- of fire for as long as we stay in Attack, mirroring BlasterController's Auto branch. Runs on its
-- own thread because an automatic weapon's cadence is faster than the think interval.
--
-- Semi-automatic weapons deliberately do NOT use this -- they go through _tryFire, one shot per
-- think tick. Running this loop for a semi-auto is what made the pistol behave like an automatic.
function EnemyAI:_startAutoFire()
	self.fireGeneration += 1
	local generation = self.fireGeneration

	task.spawn(function()
		while
			not self.destroyed
			and self.fireGeneration == generation
			and self.state == STATE.Attack
		do
			if self:_fireOnce() then
				self.lastShotTime = os.clock()
			end
			task.wait(self:_shotCooldown())
		end
	end)
end

-- ============================================================================
-- STATE TRANSITIONS
-- ============================================================================

function EnemyAI:_setState(newState: string)
	if self.state == newState or self.state == STATE.Dead then
		return
	end

	if self.state == STATE.Attack then
		self:_stopFiring()
	end

	self.state = newState
	-- Published as an attribute so the state machine is inspectable in Studio while the game runs,
	-- the same way this game exposes IsSprinting/IsCrouching/Stamina.
	self.character:SetAttribute("AIState", newState)
	self:_clearPath()

	if newState == STATE.Attack then
		-- Only an automatic weapon gets a continuous firing loop. A semi-auto is pulled once per
		-- think tick from _thinkAttack instead.
		if self:_isAutomatic() then
			self:_startAutoFire()
		end
	elseif newState == STATE.Search then
		self.searchUntil = os.clock() + Constants.SEARCH_DURATION
		self.hasLookedAround = false
	elseif newState == STATE.Patrol then
		self:_setTarget(nil)
		self.lastKnownPosition = nil
		self.patrolDwellUntil = 0
	end
end

function EnemyAI:_enterDead()
	if self.state == STATE.Dead then
		return
	end

	self.state = STATE.Dead
	self.character:SetAttribute("AIState", STATE.Dead)
	self:_stopFiring()
	self:_clearPath()

	for _, track in self.locomotionTracks or {} do
		if track.IsPlaying then
			track:Stop(0.1)
		end
	end
	self.currentLocomotionSet = nil
	if self.animationController then
		pcall(function()
			self.animationController:disable()
		end)
	end

	if Constants.DEATH_ANIMATION_ID ~= "" then
		pcall(function()
			local animator = self.humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				return
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = Constants.DEATH_ANIMATION_ID
			local track = animator:LoadAnimation(animation)
			track.Priority = AnimationPriorities.CombatAction
			track:Play()
		end)
	end

	-- Hand the corpse to physics, through the same module player deaths use. This also owns the
	-- corpse's lifetime: cleanup is the end of the death presentation, so it lives here rather than
	-- in the spawner, which is only responsible for counting and for scheduling the replacement.
	RagdollController.ragdoll(self.character, {
		holdDuration = Constants.CORPSE_LINGER_DURATION,
		onFinished = function()
			self:destroy()
		end,
	})

	-- Tell the spawner, so it decrements its live count and schedules the respawn. Fired immediately,
	-- and deliberately not gated on the ragdoll finishing -- respawn timing must not depend on how
	-- long a corpse happens to lie around. The spawner never polls for death independently of this.
	if self.onDied then
		task.spawn(self.onDied, self)
	end
end

-- ============================================================================
-- THINK
-- ============================================================================

function EnemyAI:_thinkPatrol(now: number)
	local player, humanoid = self:_findVisibleTarget()
	if player and humanoid then
		self:_setTarget(player)
		self.lastKnownPosition = getAimPosition(humanoid)
		self:_setState(STATE.Chase)
		return
	end

	if now < self.patrolDwellUntil then
		self:_stopMoving()
		return
	end

	-- Wander to a random reachable point near the spawn point. If the destination turns out to be
	-- unreachable the path simply fails and a different point is tried on the next replan.
	if not self.pathDestination then
		local angle = math.random() * math.pi * 2
		local distance = math.random() * Constants.PATROL_RADIUS
		local destination = self.spawnPosition
			+ Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		self:_computePath(destination, now)
		if not self.pathDestination then
			return
		end
	end

	local destination = self.pathDestination :: Vector3
	self:_followPath(destination, self.config.walkSpeed, now)

	local offset = destination - self.rootPart.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 6 then
		self:_clearPath()
		self.patrolDwellUntil = now + Constants.PATROL_DWELL_DURATION
	end
end

function EnemyAI:_thinkChase(now: number)
	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		-- Dead means ignore it entirely and return to Patrol -- searching a corpse's last known
		-- position is exactly the "runs at the dead body" behavior being fixed here. Anything else
		-- (player disconnected, character not yet loaded) keeps the existing Search behavior.
		self:_setState(if self:_isTargetDead() then STATE.Patrol else STATE.Search)
		return
	end

	local aimPosition = getAimPosition(targetHumanoid)
	if not aimPosition then
		self:_setState(STATE.Search)
		return
	end

	local eyePosition = self:_eyePosition()
	local distance = (aimPosition - eyePosition).Magnitude

	-- DETECTION_RADIUS bounds pursuit as well as acquisition, and deliberately regardless of line of
	-- sight: an enemy should not track a target from further away than it could have spotted it in
	-- the first place. Without this, a target that stays visible on open ground is chased across the
	-- entire map and the Search state is unreachable.
	if distance > self.config.detectionRadius then
		self:_setState(STATE.Search)
		return
	end

	if ShotResolver.hasLineOfSight(self.character, eyePosition, targetHumanoid) then
		self.lastKnownPosition = aimPosition
		if distance <= self:_engageRange() then
			self:_setState(STATE.Attack)
			return
		end
	end

	self:_followPath(self.lastKnownPosition or aimPosition, self.config.chaseSpeed, now)
end

function EnemyAI:_thinkAttack(now: number)
	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		self:_setState(if self:_isTargetDead() then STATE.Patrol else STATE.Search)
		return
	end

	local aimPosition = getAimPosition(targetHumanoid)
	if not aimPosition then
		self:_setState(STATE.Search)
		return
	end

	local eyePosition = self:_eyePosition()
	if not ShotResolver.hasLineOfSight(self.character, eyePosition, targetHumanoid) then
		-- Cover broke the shot: go back to closing the distance, and remember where they were.
		self:_setState(STATE.Chase)
		return
	end

	self.lastKnownPosition = aimPosition
	local distance = (aimPosition - eyePosition).Magnitude
	local engageRange = self:_engageRange()

	if distance > engageRange then
		self:_setState(STATE.Chase)
		return
	end

	-- Hold a firing line instead of walking into the player.
	self:_faceTowards(aimPosition)

	-- One trigger pull per think for a semi-automatic weapon; automatic weapons are driven by their
	-- own loop (see _startAutoFire).
	if not self:_isAutomatic() then
		self:_tryFire(now)
	end
	if distance > engageRange * self.config.preferredRangeFraction then
		self:_followPath(aimPosition, self.config.chaseSpeed, now)
	else
		self:_stopMoving()
	end
end

function EnemyAI:_thinkSearch(now: number)
	-- Re-acquire if they come back into view.
	local player, humanoid = self:_findVisibleTarget()
	if player and humanoid then
		self:_setTarget(player)
		self.lastKnownPosition = getAimPosition(humanoid)
		self:_setState(STATE.Chase)
		return
	end

	if now >= self.searchUntil then
		self:_setState(STATE.Patrol)
		return
	end

	local lastKnown = self.lastKnownPosition
	if not lastKnown then
		self:_setState(STATE.Patrol)
		return
	end

	local offset = lastKnown - self.rootPart.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 6 then
		-- Arrived at the last known position: look around ONCE rather than immediately giving up.
		-- Gated by hasLookedAround so this fires exactly one time per Search-state entry -- left
		-- unconditional, it re-added another 50 degrees every THINK_INTERVAL for the whole
		-- SEARCH_DURATION (~20 ticks), which read as the enemy continuously spinning in place next
		-- to wherever it lost its target (most visibly: standing over a player's corpse).
		self:_stopMoving()
		if not self.hasLookedAround then
			self.hasLookedAround = true
			self.rootPart.CFrame = self.rootPart.CFrame * CFrame.Angles(0, math.rad(50), 0)
		end
	else
		self:_followPath(lastKnown, self.config.chaseSpeed, now)
	end
end

function EnemyAI:think(now: number)
	if self.destroyed or self.state == STATE.Dead then
		return
	end
	if not self.character.Parent or not self.rootPart.Parent then
		return
	end
	if self.humanoid.Health <= 0 then
		self:_enterDead()
		return
	end

	-- Shared signal written by ShotResolver on a hit from a weapon declaring stunDuration -- the
	-- same attribute SprintAuthority reads to freeze a stunned PLAYER. An enemy has no sprint
	-- system to hook into, so it is enforced directly here instead.
	local stunnedUntil = self.rootPart:GetAttribute("StunnedUntil") or 0
	local isStunned = now < stunnedUntil
	if isStunned then
		if not self.wasStunned then
			-- Just got stunned: kill any in-progress automatic-fire loop and cancel movement
			-- immediately rather than waiting for the current path/attack to finish naturally.
			self:_stopFiring()
			self:_stopMoving()
			self.wasStunned = true
		end
		self.humanoid.WalkSpeed = 0
		return
	elseif self.wasStunned then
		self.wasStunned = false
		-- The stun killed an automatic weapon's fire loop (see _stopFiring above); if we are
		-- still in Attack once the stun lifts, that loop does not restart on its own.
		if self.state == STATE.Attack and self:_isAutomatic() then
			self:_startAutoFire()
		end
	end

	if self.state == STATE.Patrol then
		self:_thinkPatrol(now)
	elseif self.state == STATE.Chase then
		self:_thinkChase(now)
	elseif self.state == STATE.Attack then
		self:_thinkAttack(now)
	elseif self.state == STATE.Search then
		self:_thinkSearch(now)
	end

	self:_updateLocomotionAnimation()
end

-- Head for `position` the way Search heads for a last known position (police going where they believe the
-- player is). Only from Patrol or Search: while chasing or attacking, the AI's own pursuit wins, and Search
-- itself switches to Chase the moment a target is seen.
function EnemyAI:investigate(position: Vector3)
	if self.state ~= STATE.Patrol and self.state ~= STATE.Search then
		return
	end
	self.lastKnownPosition = position
	self:_setState(STATE.Search)
	self.searchUntil = os.clock() + Constants.SEARCH_DURATION
end

-- Called when something damages this enemy. Being shot from outside the detection radius is itself a
-- detection event, otherwise an enemy would ignore a sniper indefinitely.
function EnemyAI:onDamagedBy(attacker: Player | Model)
	if not Constants.RETALIATION_DETECTION or self.state == STATE.Dead then
		return
	end
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return
	end

	local character = attacker.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not self:_accepts(attacker) then
		return
	end

	self:_setTarget(attacker)
	self.lastKnownPosition = getAimPosition(humanoid)
	if self.state == STATE.Patrol or self.state == STATE.Search then
		self:_setState(STATE.Chase)
	end
end

function EnemyAI:destroy()
	self.destroyed = true
	self:_stopFiring()
	activeEnemies[self] = nil
	enemiesByHumanoid[self.humanoid] = nil

	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)

	if self.animationController then
		pcall(function()
			self.animationController:destroy()
		end)
		self.animationController = nil
	end

	if self.character.Parent then
		self.character:Destroy()
	end
end

-- ============================================================================
-- SCHEDULER
-- ============================================================================

-- One Heartbeat connection for every enemy. Each enemy is only thought about when its own interval
-- is due, and each think runs on its own thread because path computation yields -- one enemy waiting
-- on ComputeAsync must not stall the others.
function EnemyAI._ensureScheduler()
	if schedulerConnection then
		return
	end

	schedulerConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for enemy in activeEnemies do
			if enemy.destroyed then
				activeEnemies[enemy] = nil
				continue
			end
			if now < enemy.nextThinkTime or enemy.thinking then
				continue
			end

			enemy.nextThinkTime = now + Constants.THINK_INTERVAL
			enemy.thinking = true
			task.spawn(function()
				local ok, err = pcall(function()
					enemy:think(now)
				end)
				enemy.thinking = false
				if not ok then
					warn(`EnemyAI think error: {err}`)
				end
			end)
		end
	end)
end

-- A single shared Tagged listener routes "you were shot" to the right enemy. Note the attacker may
-- be a Player or an enemy character Model -- the resolver generalized that parameter.
taggedEvent.Event:Connect(function(attacker: Player | Model, humanoid: Humanoid)
	local enemy = enemiesByHumanoid[humanoid]
	if enemy then
		enemy:onDamagedBy(attacker)
	end
end)

-- Every live enemy instance (not destroyed, not dead); police are the ones with config.faction "Police".
function EnemyAI.getLive(): { any }
	local live = {}
	for enemy in activeEnemies do
		if not enemy.destroyed and enemy.state ~= STATE.Dead then
			table.insert(live, enemy)
		end
	end
	return live
end

function EnemyAI.getActiveCount(): number
	local count = 0
	for _ in activeEnemies do
		count += 1
	end
	return count
end

return EnemyAI
