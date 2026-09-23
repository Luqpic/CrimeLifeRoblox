-- The one place a shot is resolved on the server.
--
-- Everything that decides what a shot actually does lives here: deterministic spread-ray derivation
-- from an origin and a seed, the occlusion cast, target validation, headshot detection, damage
-- application, the Tagged/Eliminated events, the damage indicator, the physics impulse, and the
-- ReplicateShot broadcast.
--
-- Two callers share it:
--   * ServerScriptService.Blaster.Scripts.Blaster -- the Shoot RemoteEvent handler. It validates the
--     player, timing, ammo and state first (anti-cheat), then hands the shot over along with the
--     humanoids the client claims it hit.
--   * ServerScriptService.Enemy.Scripts.EnemyAI -- an AI enemy. It calls in directly, with no
--     RemoteEvent: there is no client to round-trip with and no latency to hide, so the server
--     resolves the shot synchronously from the enemy's real muzzle position.
--
-- The difference between the two is exactly one thing: whether the caller supplies client-claimed
-- hits (see `claimedTags`). Range, spread, damage, headshot multiplier, occlusion rules, ammo
-- accounting and replication are identical for both, which is the point -- rebalancing or fixing
-- any of it moves the player and the AI together.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local castRays = require(ReplicatedStorage.Blaster.Utility.castRays)
local findOwningHumanoid = require(ReplicatedStorage.Blaster.Utility.findOwningHumanoid)
local getRayDirections = require(ReplicatedStorage.Blaster.Utility.getRayDirections)
local validateTag = require(script.validateTag)
local RagdollController = require(ReplicatedStorage.Modules.RagdollController)

local remotes = ReplicatedStorage.Blaster.Remotes
local replicateShotRemote = remotes.ReplicateShot
local damageIndicatorRemote = remotes.DamageIndicator

local events = ServerScriptService.Blaster.Events
local taggedEvent = events.Tagged
local eliminatedEvent = events.Eliminated

local DAMAGE_INDICATOR_WINDOW = 3
local HEADSHOT_DAMAGE_MULTIPLIER = 2
local HEADSHOT_PART_NAME = "Head"
-- Spherecast radius for the line-of-sight check. Small but non-zero; a zero-radius spherecast is
-- not a meaningful query.
local LINE_OF_SIGHT_RADIUS = 0.1
-- How far past a blocking ally the line-of-sight query restarts. Wide enough to clear a torso in one
-- step so a tight crowd does not need many iterations.
local LINE_OF_SIGHT_ALLY_STEP = 2.5
-- Bounded so a pathological pile-up cannot spin: eight allies deep is already far more than a crowd
-- that can physically fit between a shooter and its target at melee range.
local LINE_OF_SIGHT_MAX_ALLY_SKIPS = 8
-- How long to wait for the ragdoll before giving up on a kill fling.
local FLING_RAGDOLL_WAIT = 0.5
-- Upward share of the fling, which turns a shove along the floor into an arc.
local FLING_UPWARD_RATIO = 0.35

-- Sends a corpse flying, for weapons that declare knockbackOnKill.
--
-- Two things make this different from the ordinary knockback above, and both were measured rather
-- than assumed:
--
-- 1. It has to WAIT for the ragdoll. RagdollController zeroes every part's velocity as it hands the
--    body to physics, and that happens a frame AFTER the humanoid dies -- so an impulse applied
--    inline, in the same call that dealt the fatal damage, is wiped before it moves anything.
--    Measured inline: 152.6 studs/s on the frame of the shot, 3.3 on the next, 1.76 studs travelled.
-- 2. It pushes EVERY part, not just the root. A ragdolled rig is fourteen separate assemblies held
--    by BallSocketConstraints; pushing the root alone leaves the other thirteen to drag it to a
--    halt. Measured: a 155 studs/s push on the root alone moved the body 1.95 studs.
--
-- With both, the response is steep -- 30 studs/s travels ~13 studs, 38 travels ~19, 45 travels ~24,
-- 100 travels ~108 -- so knockbackForce is a sensitive dial for these weapons, not a linear one.
local function flingRagdoll(taggedHumanoid: Humanoid, direction: Vector3, speed: number)
	local character = taggedHumanoid.Parent
	if not character or not character:IsA("Model") then
		return
	end

	task.spawn(function()
		local deadline = os.clock() + FLING_RAGDOLL_WAIT
		while os.clock() < deadline and not RagdollController.isRagdolled(character) do
			RunService.Heartbeat:Wait()
		end
		-- One more frame, so the ragdoll's own zeroing pass is definitely behind us.
		RunService.Heartbeat:Wait()
		if not character.Parent then
			return
		end

		local velocity = direction * speed + Vector3.new(0, speed * FLING_UPWARD_RATIO, 0)
		for _, descendant in character:GetDescendants() do
			-- A carried weapon is welded to the hand and follows the arm on its own; pushing it
			-- separately only fights that weld.
			if descendant:IsA("BasePart") and not descendant:FindFirstAncestorOfClass("Tool") then
				descendant.AssemblyLinearVelocity = velocity
			end
		end
	end)
end

local ShotResolver = {}

-- A shot to resolve.
--   shooter      the Player firing, or an enemy character Model. Decides team rules (an enemy has
--                no team and is hostile to every player) and whose character the rays ignore.
--   weapon       the Tool carrying the weapon config attributes (damage/spread/range/rayRadius/
--                raysPerShot/_ammo) and the Handle/Sounds/MuzzleAttachment used for replication.
--                An enemy carries a real clone of the player's Tool, so the config is the same one.
--   origin       muzzle/aim origin. Position is where rays start, LookVector is the aim direction.
--   seed         seed for the spread pattern. The player path passes the client's timestamp so the
--                server reproduces the client's spread exactly; the AI passes server time.
--   claimedTags  humanoids the client reported hitting, keyed by ray index as a string. Present
--                only on the player path. When nil, hits are resolved from the server's own cast.
export type ShotRequest = {
	shooter: Player | Model,
	weapon: Tool,
	origin: CFrame,
	seed: number,
	claimedTags: { [string]: Humanoid }?,
}

export type ShotHit = {
	humanoid: Humanoid,
	damage: number,
	isHeadshot: boolean,
}

export type ShotResult = {
	rayResults: { castRays.RayResult },
	hits: { ShotHit },
}

-- Whether an instance belongs to a character (anything with a Humanoid), alive or dead, including
-- anything a character is carrying. Used to keep the prop impulse away from bodies; see the note at
-- the impulse loop.
--
-- The whole ancestry is walked rather than stopping at the first Model ancestor. A weapon's visible
-- parts sit inside the Tool's own inner Model, so a first-Model-only test found no Humanoid there
-- and declared them props: a single shot into a corpse's gun then flung the body by the rigid grip
-- holding it, measured at 523 studs/s peak and the corpse thrown 627 studs. Only the Tool's Handle,
-- which happens to be a direct child of the Tool, was ever protected.
local function isCharacterPart(instance: Instance?): boolean
	local current: Instance? = instance
	while current do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Accumulates damage a player deals to a given humanoid within a rolling window, so rapid multi-hits
-- (e.g. automatic weapons) combine into a single indicator instead of spamming the client.
local activeIndicators = {}

local function showDamageIndicator(attacker: Player, humanoid: Humanoid, damage: number, isHeadshot: boolean)
	local character = humanoid.Parent
	if not character then
		return
	end

	activeIndicators[attacker] = activeIndicators[attacker] or {}
	local playerIndicators = activeIndicators[attacker]
	local indicatorData = playerIndicators[humanoid]

	if indicatorData then
		indicatorData.totalDamage += damage
		damageIndicatorRemote:FireClient(attacker, humanoid, indicatorData.totalDamage, isHeadshot)

		if indicatorData.removeTask then
			task.cancel(indicatorData.removeTask)
		end
		indicatorData.removeTask = task.delay(DAMAGE_INDICATOR_WINDOW, function()
			playerIndicators[humanoid] = nil
		end)
	else
		damageIndicatorRemote:FireClient(attacker, humanoid, damage, isHeadshot)

		playerIndicators[humanoid] = {
			totalDamage = damage,
			removeTask = task.delay(DAMAGE_INDICATOR_WINDOW, function()
				playerIndicators[humanoid] = nil
			end),
		}
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	activeIndicators[player] = nil
end)

-- ============================================================================
-- BLEED
-- ============================================================================
-- A weapon declaring bleedDuration keeps damaging what it cut after the swing has landed. The ticks
-- go through the same TakeDamage + Tagged/Eliminated path a direct hit uses, so a kill by bleeding
-- still pays cash, grants XP and counts toward a quest -- all three listen to Eliminated, and none
-- of them has to learn that bleeding exists.
-- Counted in TICKS, not against a deadline. Comparing os.clock() to an expiry loses the last tick:
-- task.wait overshoots slightly, so after five one-second waits the clock is already past a
-- five-second deadline and the fifth tick is rejected. Measured that way, a 5s bleed at 4/s dealt
-- 16 rather than 20. A count says what was intended -- five seconds of bleeding is five ticks.
local BLEED_TICK_INTERVAL = 1
local BLEED_EMITTER_NAME = "BleedingEffect"
local bloodTemplate = ReplicatedStorage.VFX:WaitForChild("BloodParticle")
local bleedTicksLeft: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Switches the wound off and clears it up. Separated because three paths end a bleed: it running
-- out, the target dying, and the target being gone entirely.
local function clearBleedEffect(taggedHumanoid: Humanoid)
	local character = taggedHumanoid.Parent
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant.Name == BLEED_EMITTER_NAME and descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			-- Outlives its own last particles rather than cutting them mid-flight.
			Debris:AddItem(descendant, descendant.Lifetime.Max)
		end
	end
end

local function applyBleed(shooter: Player | Model, taggedHumanoid: Humanoid, duration: number, damagePerSecond: number, weapon: Tool)
	local alreadyBleeding = bleedTicksLeft[taggedHumanoid] ~= nil
	local expiry = os.clock() + duration
	bleedTicksLeft[taggedHumanoid] = math.max(1, math.round(duration / BLEED_TICK_INTERVAL))

	-- Mirrors StunnedUntil: a plain replicated signal, so anything that wants to SHOW bleeding can
	-- read it without this resolver knowing such a thing exists.
	local rootPart = taggedHumanoid.RootPart
	if rootPart then
		rootPart:SetAttribute("BleedingUntil", expiry)
	end

	-- The wound itself. Parented to the torso rather than the root part so it sits at chest height
	-- and follows the body through a ragdoll; parented on the SERVER so every client sees it
	-- bleeding, not just the one that landed the hit.
	local character = taggedHumanoid.Parent
	local bleedHost = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or rootPart)
	if bleedHost and bleedHost:IsA("BasePart") and not bleedHost:FindFirstChild(BLEED_EMITTER_NAME) then
		local emitter = bloodTemplate:Clone()
		emitter.Name = BLEED_EMITTER_NAME
		emitter.Enabled = true
		emitter.Parent = bleedHost
	end

	-- A second cut refreshes the clock rather than starting a second loop. A melee swing resolves
	-- several rays against the same target, so without this one swing would start six loops and
	-- tick six times a second -- a stacking damage bug wearing a longer bleed's clothes.
	if alreadyBleeding then
		return
	end

	task.spawn(function()
		while true do
			task.wait(BLEED_TICK_INTERVAL)
			local ticksLeft = bleedTicksLeft[taggedHumanoid]
			if not ticksLeft or ticksLeft <= 0 then
				break
			end
			bleedTicksLeft[taggedHumanoid] = ticksLeft - 1
			if not taggedHumanoid.Parent or taggedHumanoid.Health <= 0 then
				break
			end

			taggedHumanoid:TakeDamage(damagePerSecond)
			taggedEvent:Fire(shooter, taggedHumanoid, damagePerSecond)
			-- Each tick shows the same floating number a direct hit does, so the player can see the
			-- bleed working rather than watching a health bar drop for no visible reason. Never a
			-- headshot: a bleed does not land anywhere in particular.
			if shooter:IsA("Player") then
				showDamageIndicator(shooter :: Player, taggedHumanoid, math.floor(damagePerSecond), false)
			end
			if taggedHumanoid.Health <= 0 then
				-- Weapon name threaded through so a kill-by-bleed still credits SpraypaintService's
				-- per-weapon balance -- the direct-hit site below fires the same fourth argument.
				eliminatedEvent:Fire(shooter, taggedHumanoid, damagePerSecond, weapon.Name)
				break
			end
		end

		bleedTicksLeft[taggedHumanoid] = nil
		clearBleedEffect(taggedHumanoid)
		local root = taggedHumanoid.RootPart
		if root then
			root:SetAttribute("BleedingUntil", nil)
		end
	end)
end

-- Is `targetHumanoid` visible from `fromPosition`, i.e. would a shot reach it?
--
-- Built on the same castRays occlusion query the resolver uses, and shared with the AI's detection
-- and attack gating so "can I see you" and "can I shoot you" cannot disagree. A wall counts as
-- blocking; an ally standing in front does not (see the loop below).
function ShotResolver.hasLineOfSight(shooter: Player | Model, fromPosition: Vector3, targetHumanoid: Humanoid): boolean
	local targetPart = targetHumanoid.RootPart
	if not targetPart then
		return false
	end

	local origin = fromPosition
	for _ = 1, LINE_OF_SIGHT_MAX_ALLY_SKIPS do
		local offset = targetPart.Position - origin
		local distance = offset.Magnitude
		if distance < 1e-3 then
			return true
		end

		local rayResult = castRays(shooter, origin, { offset }, LINE_OF_SIGHT_RADIUS, false)[1]
		if not rayResult then
			return false
		end
		if rayResult.taggedHumanoid == targetHumanoid then
			return true
		end

		-- An ally in the way is not cover. castRays only excludes the shooter's OWN character, so a
		-- second enemy's body -- or the weapon it is carrying -- stopped this cast, and because an
		-- enemy cannot damage another enemy the hit came back with no taggedHumanoid, which read as
		-- "blocked". That is what froze a crowd: every enemy whose view was blocked by the one in
		-- front dropped out of Attack, and Chase could not restore it because they were already on
		-- top of the target with nowhere to path to. Measured with six thugs ringed at 3.2 studs,
		-- two of the six were blocked by another enemy's blaster geometry.
		--
		-- A wall has no humanoid anywhere above it, so real cover still blocks.
		if not findOwningHumanoid(rayResult.instance) then
			return false
		end

		-- Step past the ally and look again. If that step reaches the target, nothing but allies was
		-- ever in the way.
		local travelled = (rayResult.position - origin).Magnitude + LINE_OF_SIGHT_ALLY_STEP
		if travelled >= distance then
			return true
		end
		origin = origin + offset.Unit * travelled
	end

	return false
end

function ShotResolver.resolveShot(request: ShotRequest): ShotResult
	local shooter = request.shooter
	local weapon = request.weapon
	local origin = request.origin
	local claimedTags = request.claimedTags
	local shooterIsPlayer = shooter:IsA("Player")

	local spread = weapon:GetAttribute(Constants.SPREAD_ATTRIBUTE)
	local raysPerShot = weapon:GetAttribute(Constants.RAYS_PER_SHOT_ATTRIBUTE)
	local range = weapon:GetAttribute(Constants.RANGE_ATTRIBUTE)
	local rayRadius = weapon:GetAttribute(Constants.RAY_RADIUS_ATTRIBUTE)
	local damage = weapon:GetAttribute(Constants.DAMAGE_ATTRIBUTE)
	local isMeleeHit = weapon:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE)
	-- A melee weapon fans several rays across its swing arc so a hit does not require pixel-perfect
	-- aim. A swing must still land as ONE hit rather than one per ray that happens to connect:
	-- dividing here means a solidly centred swing (most or all rays connect) deals the weapon's full
	-- configured damage, a glancing swing deals proportionally less instead of nothing, and widening
	-- the ray count can never multiply damage past the configured value. Same idea as
	-- knockbackPerRay below. Guns and the shotgun leave the attribute unset, so damagePerRay ==
	-- damage for them and pellet damage still stacks, which is the shotgun's whole identity.
	local damagePerRay = if isMeleeHit then damage / math.max(raysPerShot, 1) else damage
	local knockbackForce = weapon:GetAttribute(Constants.KNOCKBACK_FORCE_ATTRIBUTE) or 0
	-- applyDamage runs once per ray, so a multi-pellet weapon would otherwise stack the push once
	-- per pellet (a full 8-pellet shotgun blast measured 337 studs/s instead of 55). Dividing by the
	-- pellet count makes knockbackForce the total for a shot that connects with everything, and a
	-- partial hit pushes proportionally less -- the same range falloff the pellet spread already
	-- gives the damage.
	local knockbackPerRay = knockbackForce / math.max(raysPerShot, 1)
	local knockbackOnKill = weapon:GetAttribute(Constants.KNOCKBACK_ON_KILL_ATTRIBUTE) == true
	local infiniteAmmo = weapon:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE)

	-- Subtract ammo. Skipped for infinite-ammo weapons so the attribute doesn't drift steadily
	-- negative over a session.
	if not infiniteAmmo then
		local ammo = weapon:GetAttribute(Constants.AMMO_ATTRIBUTE)
		weapon:SetAttribute(Constants.AMMO_ATTRIBUTE, ammo - 1)
	end

	-- The seed drives the blaster's random spread. On the player path it is the timestamp the client
	-- sent, which lets us recalculate the client's spread accurately on the server relative to the
	-- look direction, rather than simply accepting a direction or directions from the client.
	local spreadAngle = math.rad(spread)
	local rayDirections = getRayDirections(origin, raysPerShot, spreadAngle, request.seed)
	for index, direction in rayDirections do
		rayDirections[index] = direction * range
	end

	-- With client-claimed hits the cast is an occlusion check against static geometry and the claims
	-- are validated against it. Without them (an AI enemy -- nothing claimed anything) the cast IS
	-- the hit resolution: castRays already reports the humanoid each ray struck, and a nearer wall
	-- wins on its own.
	local resolveFromCast = claimedTags == nil
	local rayResults = castRays(shooter, origin.Position, rayDirections, rayRadius, not resolveFromCast)

	local hits: { ShotHit } = {}

	local function applyDamage(taggedHumanoid: Humanoid, rayResult: castRays.RayResult)
		if taggedHumanoid.Health <= 0 then
			return
		end

		-- Headshot detection: the server raycast's hit part tells us exactly what was struck.
		local hitPart = rayResult.instance
		local isHeadshot = hitPart ~= nil and hitPart.Name == HEADSHOT_PART_NAME
		local appliedDamage = isHeadshot and (damagePerRay * HEADSHOT_DAMAGE_MULTIPLIER) or damagePerRay

		-- Apply damage and fire any relevant events. The attacker passed to Tagged/Eliminated is a
		-- Player or an enemy character Model -- listeners must not assume Player.
		taggedHumanoid:TakeDamage(appliedDamage)
		taggedEvent:Fire(shooter, taggedHumanoid, appliedDamage)

		-- Knockback for weapons that declare it (shotgun, melee). Deliberately NOT the impulse
		-- formula used for unanchored props below: that one multiplies by the range-pre-scaled
		-- rayDirections and once flung a corpse at 584 studs/s. This uses the unit direction from
		-- the shooter to the actual hit point, so knockbackForce is a direct studs/s push that does
		-- not grow with the weapon's range. The small upward component makes it read as being
		-- knocked off balance rather than shoved along the floor.
		--
		-- A knockbackOnKill weapon spends the WHOLE force on the shot that kills and nothing on a shot
		-- the target survives. The two cases were never equivalent even before this: a living target's
		-- humanoid fights the push, so a non-lethal shotgun hit only ever produced a twitch, while the
		-- same impulse on a corpse -- whose velocity RagdollController has just zeroed, and whose
		-- humanoid has stopped resisting -- is the fling. This makes that split explicit rather than
		-- incidental, and pays the full force once instead of a per-pellet share, because only the one
		-- pellet that lands the kill gets here (the rest return at the Health <= 0 guard above).
		local killedByThisRay = taggedHumanoid.Health <= 0
		local appliedKnockback = if knockbackOnKill
			then (if killedByThisRay then knockbackForce else 0)
			else knockbackPerRay
		if appliedKnockback > 0 then
			local rootPart = taggedHumanoid.RootPart
			if rootPart then
				local offset = rayResult.position - origin.Position
				local direction = if offset.Magnitude > 1e-3 then offset.Unit else origin.LookVector
				if knockbackOnKill then
					flingRagdoll(taggedHumanoid, direction, appliedKnockback)
				else
					rootPart.AssemblyLinearVelocity += direction * appliedKnockback
						+ Vector3.new(0, appliedKnockback * 0.25, 0)
				end
			end
		end

		-- Stun: stamped as a plain attribute on the target's RootPart rather than calling into
		-- SprintAuthority or EnemyAI directly -- those are separate systems owning player and enemy
		-- movement respectively, and neither should depend on this resolver or on each other. Each
		-- enforces the lockout independently by reading this same shared signal on its own next
		-- tick, the way IsSprinting/CanSprint already work. os.clock() matches the clock both of
		-- those systems already tick against.
		local stunDuration = weapon:GetAttribute(Constants.STUN_DURATION_ATTRIBUTE)
		if typeof(stunDuration) == "number" and stunDuration > 0 then
			local stunRootPart = taggedHumanoid.RootPart
			if stunRootPart then
				stunRootPart:SetAttribute("StunnedUntil", os.clock() + stunDuration)
			end

			-- The attribute above is the movement lockout; on its own it left the target standing
			-- rooted with its idle animation still playing, which read as a freeze rather than as
			-- having been hit. Dropping the body for the same window and standing it back up is the
			-- same lockout, made visible. The two share one duration deliberately, so the target is
			-- never back on its feet while still unable to move, or moving again while still limp.
			local stunCharacter = taggedHumanoid.Parent
			if stunCharacter and stunCharacter:IsA("Model") then
				RagdollController.stagger(stunCharacter, stunDuration)
			end
		end

		-- Bleed, for a weapon that declares one. Skipped on a target the swing already killed --
		-- there is nothing left to bleed, and starting a loop against a corpse would keep firing
		-- Tagged at whatever is left of it.
		local bleedDuration = weapon:GetAttribute(Constants.BLEED_DURATION_ATTRIBUTE)
		local bleedDamage = weapon:GetAttribute(Constants.BLEED_DAMAGE_ATTRIBUTE)
		if
			typeof(bleedDuration) == "number" and bleedDuration > 0
			and typeof(bleedDamage) == "number" and bleedDamage > 0
			and taggedHumanoid.Health > 0
		then
			applyBleed(shooter, taggedHumanoid, bleedDuration, bleedDamage, weapon)
		end

		-- The hit indicator is a piece of player HUD; an enemy has no client to show it to.
		if shooterIsPlayer then
			showDamageIndicator(shooter :: Player, taggedHumanoid, math.floor(appliedDamage), isHeadshot)
		end

		table.insert(hits, { humanoid = taggedHumanoid, damage = appliedDamage, isHeadshot = isHeadshot })

		if taggedHumanoid.Health <= 0 then
			-- Fourth argument: the weapon that made the kill, so SpraypaintService (and any future
			-- listener) can credit the specific weapon rather than a global balance. The four existing
			-- listeners that don't want it (CashService, LevelingService, QuestService, KillStatsService)
			-- simply ignore a trailing argument their handlers don't declare a parameter for.
			eliminatedEvent:Fire(shooter, taggedHumanoid, appliedDamage, weapon.Name)
		end
	end

	if resolveFromCast then
		for _, rayResult in rayResults do
			local taggedHumanoid = rayResult.taggedHumanoid
			if taggedHumanoid then
				applyDamage(taggedHumanoid, rayResult)
			end
		end
	else
		for indexString, taggedHumanoid in claimedTags do
			-- claimedTags contains a client-reported list of the humanoids hit by each of the rays that
			-- was fired. Strings are used for the indices since non-contiguous arrays do not get passed
			-- over the network correctly. (This may be non-contiguous in the case of firing a shotgun,
			-- where not all of the rays hit a target.) For each humanoid that the client reports it
			-- tagged, we validate against the ray that was recast on the server.
			local index = tonumber(indexString)
			if not index then
				continue
			end
			local rayResult = rayResults[index]
			if not rayResult then
				continue
			end
			local rayDirection = rayDirections[index]
			if not rayDirection then
				continue
			end

			-- Validate that the shooter is able to tag this humanoid based on the server raycast
			if not validateTag(shooter, taggedHumanoid, origin.Position, rayDirection, rayResult) then
				continue
			end

			rayResult.taggedHumanoid = taggedHumanoid

			-- Align the rayResult position to the tagged humanoid. This is necessary so that when we
			-- replicate this shot to the other clients they don't see lasers going through characters
			-- they should be hitting.
			local model = taggedHumanoid:FindFirstAncestorOfClass("Model")
			if model then
				local modelPosition = model:GetPivot().Position
				local distance = (modelPosition - origin.Position).Magnitude
				rayResult.position = origin.Position + rayDirection.Unit * distance
			end

			applyDamage(taggedHumanoid, rayResult)
		end
	end

	-- Apply physics impulse
	-- This is the most straightforward way to do this, although there will be some latency since the
	-- impulse is being applied on the server
	local force = weapon:GetAttribute(Constants.UNANCHORED_IMPULSE_FORCE_ATTRIBUTE)
	if force ~= 0 then
		for index, rayResult in rayResults do
			-- We don't want to apply impulses to characters.
			--
			-- Testing whether we tagged a humanoid is NOT sufficient for that: canDamageHumanoid
			-- returns false for a humanoid already at zero health, so taggedHumanoid is nil for any
			-- shot that lands on a corpse -- and the corpse was then treated as a loose prop. Since
			-- rayDirections are pre-scaled to the weapon's range, the impulse is range * force
			-- (1000 * 5 = 5000), which flung ragdolled bodies across the map: measured 584 studs/s
			-- on a corpse limb against 31 studs/s for a body that simply fell.
			--
			-- Asking whether the part belongs to a character covers the living, the dying and the dead.
			if rayResult.taggedHumanoid or isCharacterPart(rayResult.instance) then
				continue
			end

			if rayResult.instance and rayResult.instance:IsA("BasePart") and not rayResult.instance.Anchored then
				local direction = rayDirections[index]
				local impulse = direction * force
				rayResult.instance:ApplyImpulseAtPosition(impulse, rayResult.position)
			end
		end
	end

	-- Replicate the shot so every other client sees the muzzle flash, laser and impacts. A shooting
	-- player already drew it locally from its own prediction and is skipped; an enemy has no client
	-- of its own, so every player receives it.
	for _, otherPlayer in Players:GetPlayers() do
		if shooter == otherPlayer then
			continue
		end

		replicateShotRemote:FireClient(otherPlayer, weapon, origin.Position, rayResults)
	end

	return { rayResults = rayResults, hits = hits }
end

return ShotResolver
