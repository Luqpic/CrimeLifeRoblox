--!strict
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local AnimationPriorities = require(ReplicatedStorage.Modules.AnimationPriorities)
local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local CharacterAnimationController = require(ReplicatedStorage.Blaster.Scripts.CharacterAnimationController)
local Combat = require(ReplicatedStorage.Enemy.Combat)
local NpcFire = require(ServerScriptService.Enemy.Scripts.NpcFire) :: any
local RagdollController = require(ReplicatedStorage.Modules.RagdollController)
local locomotionAnimations = require(ReplicatedStorage.Movement.Scripts.locomotionAnimations)
local templateConfig = require(ReplicatedStorage.Enemy.templateConfig)

local GuardPost = {}
GuardPost.__index = GuardPost

-- The weapon clips of each EnemyTemplates guard (its shoot animation), by guard model.
local animationOf = setmetatable({}, { __mode = "k" })

-- Close enough to cover to stop pathing. Recomputing a path for a guard that
-- is already standing in cover is pure waste.
local ARRIVE_TOLERANCE = 6
-- Minimum seconds between ComputeAsync calls while still travelling.
local PATH_RECOMPUTE_INTERVAL = 1.0

-- Pure decisions, unit-testable. Movement quality can only be judged in Play.

function GuardPost.assignCover(guardPosition: Vector3, coverPoints, claimed): (number?, Vector3?)
	local bestIndex, bestPosition, bestDistance = nil, nil, math.huge
	for index, position in ipairs(coverPoints) do
		if not claimed[index] then
			local distance = (position - guardPosition).Magnitude
			if distance < bestDistance then
				bestIndex, bestPosition, bestDistance = index, position, distance
			end
		end
	end
	return bestIndex, bestPosition
end

-- Police and wanted Task 3 fix round 1: a guard shoots only a participant of its location's robbery or a
-- wanted player (WantedStars >= 1); bystanders are left alone, at the Bank and NewsStation alike.
function GuardPost.mayTarget(bank, player): boolean
	return bank:IsParticipant(player) or (player:GetAttribute("WantedStars") or 0) >= 1
end

-- `mayTarget` (optional): candidates it refuses are skipped.
function GuardPost.selectTarget(guardPosition: Vector3, candidates, sightRange: number, mayTarget: ((any) -> boolean)?)
	local best, bestDistance = nil, math.huge
	for _, candidate in ipairs(candidates) do
		if candidate.visible and (mayTarget == nil or mayTarget(candidate.player)) then
			local distance = (candidate.position - guardPosition).Magnitude
			if distance <= sightRange and distance < bestDistance then
				best, bestDistance = candidate.player, distance
			end
		end
	end
	return best
end

-- The designer's requirement is that guards hold their posts until players
-- breach the guard room, then run for cover. `Active` spans the whole 600s
-- heist, so gating on session state alone would send guards to cover before
-- players had even cleared the laser rooms. Proximity to the post is the
-- stand-in for "the door has been opened".
function GuardPost.shouldActivate(postPosition: Vector3, playerPositions, range: number): boolean
	for _, position in ipairs(playerPositions) do
		if (position - postPosition).Magnitude <= range then
			return true
		end
	end
	return false
end

function GuardPost.shouldFire(now: number, lastFired: number?, interval: number): boolean
	if lastFired == nil then return true end
	return (now - lastFired) >= interval
end

-- Heist police and Bank guards (2026-11-20): config.GuardTemplates names ServerStorage.EnemyTemplates rigs by post
-- number, wrapping (the Bank's { "Security", "Police" }: GuardPost1 Security, GuardPost2 Police, ...). Nil without a
-- list (NewsStation keeps GuardTemplate).
function GuardPost.templateFor(markerName: string, templates: { string }?): string?
	if not templates or #templates == 0 then
		return nil
	end
	local n = tonumber(string.match(markerName, "%d+$")) or 1
	return templates[(n - 1) % #templates + 1]
end

-- Clone-from-template rather than resetting a corpse: unragdolling a dead R15
-- rig and rebuilding its Motor6Ds is far more bug-prone than starting fresh.
-- `lift` (config.GuardSpawnLift, default 3 as before): studs above the marker for the template's pivot.
-- GuardTemplate's pivot is at its feet (NewsStation uses 0 so its guards stand on the floor its markers sit
-- on); an EnemyTemplates rig's is its root, 3.2 over its feet (the Bank's lift).
-- A guard from ServerStorage.EnemyTemplates[name] (heist police and Bank guards, 2026-11-20), built the way police
-- are (EnemyRig: look, weapon held, health, nameplate, ragdoll on death) and kept a witness and a guard. Its root is
-- anchored at the post (it never walks: cover is skipped for an anchored guard), with the idle and the weapon's hold
-- clips playing; on death the root lets go and the body ragdolls.
local function templateSpawn(name: string, targetCFrame: CFrame, lift: number?): Model?
	local templates = ServerStorage:FindFirstChild("EnemyTemplates")
	local template = templates and templates:FindFirstChild(name)
	if not template then
		warn("[GuardPost] ServerStorage.EnemyTemplates." .. name .. " is missing")
		return nil
	end
	local EnemyRig = require(ServerScriptService.Enemy.Scripts.EnemyRig) :: any
	local guard, weapon = EnemyRig.build(template, name)
	if not guard or not weapon then
		return nil
	end
	guard.Name = "Guard"
	CollectionService:AddTag(guard, "Witness")
	guard:SetAttribute("WitnessRole", "Guard")
	EnemyRig.place(guard, weapon, targetCFrame + Vector3.new(0, lift or 3, 0), workspace)
	local humanoid = guard:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = guard.PrimaryPart :: BasePart
	root.Anchored = true
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local idle = locomotionAnimations.get("idle")
	if idle then
		local track = (animator :: Animator):LoadAnimation(idle)
		track.Priority = AnimationPriorities.Locomotion
		track.Looped = true
		track:Play()
	end
	pcall(function()
		local controller = CharacterAnimationController.new(weapon)
		controller:enable()
		animationOf[guard] = controller
	end)
	humanoid.Died:Once(function()
		root.Anchored = false
		RagdollController.ragdoll(guard)
	end)
	return guard
end

-- `templateName` (config.GuardTemplates) builds that EnemyTemplates rig; without one, ServerStorage.GuardTemplate.
local function defaultSpawn(targetCFrame: CFrame, lift: number?, templateName: string?): Model?
	if templateName then
		return templateSpawn(templateName, targetCFrame, lift)
	end
	local template = ServerStorage:FindFirstChild("GuardTemplate")
	if not template then
		warn("[GuardPost] ServerStorage.GuardTemplate is missing")
		return nil
	end
	local guard = template:Clone()
	guard.Name = "Guard"
	guard:PivotTo(targetCFrame + Vector3.new(0, lift or 3, 0))
	guard.Parent = workspace
	return guard
end

-- Heist police and Bank guards (2026-11-20): a player's hit on a guard (Blaster's Tagged: every shot, swing and
-- bleed tick) provokes it (Provoke). One listener for every post, found by the guard's humanoid.
local postByHumanoid = setmetatable({}, { __mode = "k" })
local listening = false
local function listenForHits()
	if listening then return end
	local blaster = ServerScriptService:FindFirstChild("Blaster")
	local events = blaster and blaster:FindFirstChild("Events")
	local tagged = events and events:FindFirstChild("Tagged")
	if not tagged then return end
	listening = true
	local event = (tagged :: BindableEvent).Event
	event:Connect(function(attacker, humanoid)
		local post = postByHumanoid[humanoid]
		if post and typeof(attacker) == "Instance" and attacker:IsA("Player") then
			post:Provoke(attacker)
		end
	end)
end

local function humanoidOf(player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Readable gunfights (combat balance, 2026-11-20): a guard's shot is a real shot through the Blaster's ShotResolver
-- from its weapon's muzzle (tracer, flash, sound and impact for everyone, its shoot animation, Tagged, NPC range
-- falloff and level armor), aimed at the target's root inside the shared NPC cone (NpcFire: the template's aim, the
-- focus ramp, the widest cone at a rolling target). Its weapon deals config.GuardDamage (set at spawn) and never runs
-- dry: guards do not reload.
local function shootDefault(post, target)
	local guard = post._guard
	local weapon = guard and guard:FindFirstChildOfClass("Tool")
	local humanoid = humanoidOf(target)
	local root = humanoid and humanoid.RootPart
	if not weapon or not root then return end
	local ShotResolver = require(ServerScriptService.Blaster.Scripts.ShotResolver) :: any
	local from = NpcFire.muzzlePosition(weapon, guard)
	local seed = workspace:GetServerTimeNow()
	local focus = post:_focusSeconds()
	local errorDegrees = NpcFire.errorDegrees(post._aim, (root.Position - from).Magnitude, root, focus, focus)
	local origin = NpcFire.aimOrigin(from, root.Position, errorDegrees, seed)
	weapon:SetAttribute(BlasterConstants.AMMO_ATTRIBUTE, weapon:GetAttribute(BlasterConstants.MAGAZINE_SIZE_ATTRIBUTE) or 1)
	local animation = animationOf[guard]
	if animation then
		pcall(function() animation:playShootAnimation() end)
	end
	local function resolve()
		if guard.Parent then
			ShotResolver.resolveShot({ shooter = guard, weapon = weapon, origin = origin, seed = seed })
		end
	end
	local swingDelay = weapon:GetAttribute(BlasterConstants.SWING_DELAY_ATTRIBUTE)
	if typeof(swingDelay) == "number" and swingDelay > 0 then
		task.delay(swingDelay, resolve)
	else
		resolve()
	end
end

-- The red aim line from the guard's weapon to the target for its wind-up (NpcFire); returns its remover.
local function showTellDefault(post, target): () -> ()
	local guard = post._guard
	return NpcFire.showTell(guard and guard:FindFirstChildOfClass("Tool"), humanoidOf(target))
end

-- config.GuardsAlwaysPosted (NewsStation, police and wanted Task 3, 2026-11-17; the Bank since 2026-11-20): the
-- guard stands at its post from boot, through Idle and Cooldown, and a fresh one replaces it at Rearm; a guard alive
-- at Seal stays. Without the flag guards exist only while a session is Active. A config whose Tags have no
-- HeistCoverPoint gives guards no cover to run to: they hold their posts and fire from there.
function GuardPost.new(marker: BasePart, deps)
	assert(marker and marker:IsA("BasePart"), "GuardPost requires a marker BasePart")
	local self = setmetatable({
		marker = marker,
		config = deps.config,
		bank = deps.bank,
		now = deps.now or function() return workspace:GetServerTimeNow() end,
		spawnGuard = deps.spawnGuard or defaultSpawn,
		onGuardDied = deps.onGuardDied or function() end,
		-- Called once, only after spawnGuard actually returns a guard. HeistServer
		-- wires this to bank:NotifyGuardSpawned() so the guard-clear counter tracks
		-- guards that really exist, not Config.GuardCount.
		onGuardSpawned = deps.onGuardSpawned or function() end,
		-- Combat balance (2026-11-20): shoot(post, target) fires one shot or swing (the visible ShotResolver shot by
		-- default); tokens: the players' shooter tokens (NpcFire's); showTell(post, target) puts up the aim line.
		shoot = deps.shoot or shootDefault,
		tokens = deps.tokens or NpcFire.tokens,
		showTell = deps.showTell or showTellDefault,
		_guard = nil,
		_humanoid = nil,
		_spawnedThisSession = false,
		_deathReported = false,
		_coverTarget = nil,
		_lastFired = nil,
		_activated = false,
		_lastPathAt = nil,
		_diedConn = nil,
		-- [Player] = until when a player who hurt this guard is its target (Provoke).
		_provoked = setmetatable({}, { __mode = "k" }),
		-- Combat balance (2026-11-20): the target being fired at, when its sight began (focus) and was last had (a
		-- fresh wind-up after Combat.REACQUIRE_AFTER), the wind-up's end and whether this engagement had one, the
		-- shots left in the burst, the pause after it, a flinch's delay, and the guard's weapon (melee, automatic)
		-- and aim template.
		_target = nil,
		_lastTarget = nil,
		_sightSince = nil,
		_lastSightAt = nil,
		_windupUntil = nil,
		_windupDone = false,
		_hideTell = nil,
		_burstLeft = nil,
		_pauseUntil = -math.huge,
		_shotAfter = -math.huge,
		_melee = false,
		_automatic = false,
		_aim = nil,
	}, GuardPost)
	if self:_alwaysPosted() then
		self:OnSessionStart()
	end
	return self
end

function GuardPost:_alwaysPosted(): boolean
	return self.config ~= nil and self.config.GuardsAlwaysPosted == true
end

function GuardPost:IsAlive(): boolean
	if not self._spawnedThisSession then return false end
	if self._deathReported then return false end
	return self._guard ~= nil and self._guard.Parent ~= nil
end

function GuardPost:OnSessionStart()
	if self._spawnedThisSession then
		-- Heist police and Bank guards (2026-11-20): an always-posted guard meets each robbery whole.
		-- BankInstance:TryStart zeroed the guard count, so a standing guard is counted again and a dead one is
		-- replaced now: the Bank's guard-room gate opens when this session's guards fall.
		if self:_alwaysPosted() and self.bank:GetState() == "Active" then
			if self:IsAlive() then
				local ok, err = pcall(self.onGuardSpawned)
				if not ok then warn("[GuardPost] onGuardSpawned failed: " .. tostring(err)) end
			else
				self:_respawn()
			end
		end
		return
	end
	self._spawnedThisSession = true
	self._deathReported = false
	self._lastFired = nil

	local templateName = self.config and GuardPost.templateFor(self.marker.Name, self.config.GuardTemplates)
	local guard = self.spawnGuard(self.marker.CFrame, self.config and self.config.GuardSpawnLift, templateName)
	self._guard = guard
	if not guard then return end

	local ok, err = pcall(self.onGuardSpawned)
	if not ok then warn("[GuardPost] onGuardSpawned failed: " .. tostring(err)) end

	-- Combat balance (2026-11-20): what the guard holds decides how it fights (a melee weapon swings within reach, a
	-- gun fires like every NPC shooter); its hits deal config.GuardDamage; it aims with its template's cone.
	local weapon = guard:FindFirstChildOfClass("Tool")
	self._melee = weapon ~= nil and weapon:GetAttribute(BlasterConstants.MELEE_HIT_EFFECT_ATTRIBUTE) ~= nil
	self._automatic = weapon ~= nil
		and weapon:GetAttribute(BlasterConstants.FIRE_MODE_ATTRIBUTE) == BlasterConstants.FIRE_MODE.AUTO
	self._aim = templateConfig.read(guard).aim
	self._windupDone, self._lastTarget, self._pauseUntil = false, nil, -math.huge
	if weapon and self.config and typeof(self.config.GuardDamage) == "number" then
		weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, self.config.GuardDamage)
	end

	self._humanoid = guard:FindFirstChildOfClass("Humanoid")
	if self._humanoid then
		self._diedConn = self._humanoid.Died:Connect(function()
			self:_handleDeath()
		end)
		postByHumanoid[self._humanoid] = self
		listenForHits()
	end
end

function GuardPost:_handleDeath()
	if self._deathReported then return end
	self._deathReported = true
	self:_track(nil)
	self._diedAt = self.now()
	local ok, err = pcall(self.onGuardDied)
	if not ok then warn("[GuardPost] onGuardDied failed: " .. tostring(err)) end
end

function GuardPost:_moveToCover()
	if not self._guard or not self._humanoid then return end
	local root = self._guard.PrimaryPart
	if not root then return end
	if not self.config.Tags.HeistCoverPoint then return end -- no cover here: hold the post
	-- An anchored guard (both rigs, 2026-11-20: they stand at their posts at all times) holds its post: no cover
	-- claim and no path computed for a body that cannot move.
	if root.Anchored then return end

	if self._coverTarget == nil then
		-- ONE GetTagged call, held in `markers`, and every index derived from it.
		-- CollectionService:GetTagged returns instances in unspecified order, so
		-- calling it twice and indexing the second result with an index computed
		-- from the first can claim the WRONG cover point — two guards claiming one
		-- point while another is never claimed at all.
		local markers = CollectionService:GetTagged(self.config.Tags.HeistCoverPoint)
		local points, claimed = {}, {}
		for i, marker in ipairs(markers) do
			points[i] = marker.Position
			if marker:GetAttribute("ClaimedBy") ~= nil then
				claimed[i] = true
			end
		end
		local index, position = GuardPost.assignCover(root.Position, points, claimed)
		if not position then return end
		self._coverTarget = position
		markers[index]:SetAttribute("ClaimedBy", self.marker.Name)
	end

	-- Arrived: stop pathing entirely. Without this the guard recomputes a path
	-- every tick for the rest of the session while standing perfectly still —
	-- at 10 Hz across 4 guards for 600s that is ~24,000 ComputeAsync calls,
	-- one of the most expensive calls on the engine, for zero movement.
	if (root.Position - self._coverTarget).Magnitude <= ARRIVE_TOLERANCE then
		return
	end

	-- Throttle recomputes even while travelling; a path a second is ample.
	local nowSeconds = self.now()
	if self._lastPathAt and (nowSeconds - self._lastPathAt) < PATH_RECOMPUTE_INTERVAL then
		return
	end
	self._lastPathAt = nowSeconds

	-- Fall back to a direct MoveTo when pathfinding cannot reach the cover, so a
	-- guard with a blocked route still fights rather than standing inert.
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function() path:ComputeAsync(root.Position, self._coverTarget) end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local nextWaypoint = waypoints[math.min(2, #waypoints)]
		if nextWaypoint then self._humanoid:MoveTo(nextWaypoint.Position) end
	else
		self._humanoid:MoveTo(self._coverTarget)
	end
end

function GuardPost:_candidates()
	local root = self._guard and self._guard.PrimaryPart
	if not root then return {} end
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if playerRoot and humanoid and humanoid.Health > 0 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { self._guard, character }
			local direction = playerRoot.Position - root.Position
			local hit = workspace:Raycast(root.Position, direction, params)
			table.insert(candidates, {
				player = player,
				position = playerRoot.Position,
				visible = hit == nil,
			})
		end
	end
	return candidates
end

-- Fix round 1: a posted guard dead while no session is Active is back at its post GuardRespawnSeconds after
-- it died (otherwise a guard killed between robberies would stay dead until the next Rearm).
function GuardPost:_respawnIfDue()
	if not self:_alwaysPosted() or not self._deathReported or not self._diedAt then return end
	if self.now() - self._diedAt < (self.config.GuardRespawnSeconds or math.huge) then return end
	self:_respawn()
end

-- A fresh guard at the post now.
function GuardPost:_respawn()
	self:_despawn()
	self._spawnedThisSession = false
	self._diedAt = nil
	self._activated = false
	self:OnSessionStart()
end

-- Turn the guard (anchored: it never turns by itself) toward the target it fires at. A target straight above or
-- below is not faced (CFrame.lookAt would be NaN).
function GuardPost:_face(candidates, target)
	for _, candidate in ipairs(candidates) do
		if candidate.player == target then
			local pivot = self._guard:GetPivot()
			local flat = Vector3.new(candidate.position.X, pivot.Position.Y, candidate.position.Z)
			if (flat - pivot.Position).Magnitude > 0.1 then
				self._guard:PivotTo(CFrame.lookAt(pivot.Position, flat))
			end
			return
		end
	end
end

-- Combat balance (2026-11-20): the guard's hold on its target. A new target (or the same one back after more than
-- Combat.REACQUIRE_AFTER out of sight) needs a fresh wind-up; focus counts from when sight began; losing the target
-- gives its shooter token back and takes the aim line down.
function GuardPost:_track(target, now: number?)
	if target == self._target then
		if target then self._lastSightAt = now end
		return
	end
	if self._target then self.tokens:release(self._target, self) end
	self._burstLeft = nil
	self._windupUntil = nil
	self:_endTell()
	if target then
		if target ~= self._lastTarget or (now :: number) - (self._lastSightAt or -math.huge) > Combat.REACQUIRE_AFTER then
			self._windupDone = false
		end
		self._sightSince = now
		self._lastTarget, self._lastSightAt = target, now
	end
	self._target = target
end

function GuardPost:_endTell()
	if self._hideTell then
		self._hideTell()
		self._hideTell = nil
	end
end

function GuardPost:_focusSeconds(): number
	return if self._sightSince then self.now() - self._sightSince else 0
end

-- A gun guard fires like every NPC shooter: with one of its target's shooter tokens (NpcFire), after the wind-up
-- with the aim line (Combat.reactionTime) before its first shot at a fresh target, in bursts of Combat.burstShots
-- shots GuardFireInterval apart (_shotFired), then the token goes back for Combat.burstPause.
function GuardPost:_ready(target, now: number): boolean
	if now < self._pauseUntil or not self.tokens:acquire(target, self) then return false end
	if self._windupDone then return true end
	if not self._windupUntil then
		self._windupUntil = now + Combat.reactionTime(self._automatic)
		self._hideTell = self.showTell(self, target)
	end
	if now < self._windupUntil then return false end
	self._windupDone = true
	self._windupUntil = nil
	self:_endTell()
	self._lastFired = nil
	return true
end

function GuardPost:_shotFired(target, now: number)
	self._burstLeft = (self._burstLeft or Combat.burstShots()) - 1
	if self._burstLeft <= 0 then
		self._burstLeft = nil
		self.tokens:release(target, self)
		self._pauseUntil = now + Combat.burstPause()
	end
end

function GuardPost:_fire(target)
	local ok, err = pcall(self.shoot, self, target)
	if not ok then warn("[GuardPost] shot failed: " .. tostring(err)) end
end

-- A melee guard's reach: the target's root within its weapon's range of the muzzle.
function GuardPost:_inReach(target): boolean
	local weapon = self._guard and self._guard:FindFirstChildOfClass("Tool")
	local humanoid = humanoidOf(target)
	local root = humanoid and humanoid.RootPart
	if not weapon or not root then return false end
	local reach = weapon:GetAttribute(BlasterConstants.RANGE_ATTRIBUTE)
	return typeof(reach) == "number" and (root.Position - NpcFire.muzzlePosition(weapon, self._guard)).Magnitude <= reach
end

-- Still staggered by a stun (ShotResolver's StunnedUntil, os.clock), or within GuardFireInterval of getting up.
function GuardPost:_staggered(target): boolean
	local humanoid = humanoidOf(target)
	local root = humanoid and humanoid.RootPart
	local stunnedUntil = root and root:GetAttribute("StunnedUntil")
	return typeof(stunnedUntil) == "number" and os.clock() < stunnedUntil + self.config.GuardFireInterval
end

function GuardPost:Update()
	if self.bank:GetState() ~= "Active" then
		self:_respawnIfDue()
		-- Heist police and Bank guards (2026-11-20): outside a session a guard is passive unless a player hurt it.
		if not self:_anyProvoked() then
			self:_track(nil)
			return
		end
	end
	if not self:IsAlive() then return end

	local root = self._guard.PrimaryPart
	if not root then return end
	local candidates = self:_candidates()

	-- Hold the post until a player is actually near. See shouldActivate.
	if not self._activated then
		local positions = {}
		for _, candidate in ipairs(candidates) do
			table.insert(positions, candidate.position)
		end
		if not GuardPost.shouldActivate(self.marker.Position, positions, self.config.GuardActivationRange) then
			return
		end
		self._activated = true
	end

	self:_moveToCover()

	local target = GuardPost.selectTarget(root.Position, candidates, self.config.GuardSightRange, function(player)
		return GuardPost.mayTarget(self.bank, player) or self:_isProvokedBy(player)
	end)
	local now = self.now()
	self:_track(target, now)
	if not target then return end

	-- Turned toward its target first: a melee guard's reach is measured from its weapon's muzzle.
	self:_face(candidates, target)
	if self._melee then
		-- Combat balance (2026-11-20): a guard holding a melee weapon (Security's Baton) strikes only within its
		-- weapon's reach, and not at a target still staggered by its last strike. No token, no aim line.
		if not self:_inReach(target) or self:_staggered(target) then return end
		if not GuardPost.shouldFire(now, self._lastFired, self.config.GuardFireInterval) then return end
		self._lastFired = now
		self:_fire(target)
		return
	end

	if not self:_ready(target, now) then return end
	if now < self._shotAfter or not GuardPost.shouldFire(now, self._lastFired, self.config.GuardFireInterval) then return end
	self._lastFired = now
	self:_fire(target)
	self:_shotFired(target, now)
end

-- Heist layers 2026-11-17: engage at once, as if a player had come within GuardActivationRange.
-- Targeting (mayTarget, sight range, line of sight) is unchanged. No-op when the guard is dead.
function GuardPost:Alert()
	if not self:IsAlive() then return end
	self._activated = true
end

-- Heist police and Bank guards (2026-11-20): a player who hurt this guard is its target for GuardProvokeSeconds
-- after the hit (also outside a session, when it is otherwise passive), and it engages at once, as after Alert().
-- No-op when the guard is dead.
function GuardPost:Provoke(player)
	if not self:IsAlive() then return end
	local now = self.now()
	self._provoked[player] = now + (self.config.GuardProvokeSeconds or 0)
	self._activated = true
	-- Combat balance (2026-11-20): the hit makes it flinch like every NPC shooter (Combat.FLINCH_*).
	if self._sightSince then
		self._sightSince = math.min(now, self._sightSince + Combat.FLINCH_FOCUS_SETBACK)
	end
	self._shotAfter = now + Combat.FLINCH_SHOT_DELAY
end

function GuardPost:_isProvokedBy(player): boolean
	local untilTime = self._provoked[player]
	return untilTime ~= nil and self.now() < untilTime
end

-- Is a provocation still running? Spent ones are dropped.
function GuardPost:_anyProvoked(): boolean
	local now = self.now()
	for player, untilTime in self._provoked do
		if now < untilTime then return true end
		self._provoked[player] = nil
	end
	return false
end

function GuardPost:_despawn()
	table.clear(self._provoked)
	self:_track(nil)
	if self._diedConn then
		self._diedConn:Disconnect()
		self._diedConn = nil
	end
	if self._guard then
		self._guard:Destroy()
		self._guard = nil
	end
	self._humanoid = nil
end

-- Stage 1: guards leave the world when the session seals.
function GuardPost:Seal()
	if self:_alwaysPosted() and self:IsAlive() then return end
	self:_despawn()
end

-- Stage 2: allow a fresh guard for the next session (an always-posted one stands
-- again at once).
function GuardPost:Rearm()
	self:_despawn()
	self._spawnedThisSession = false
	self._deathReported = false
	self._coverTarget = nil
	self._lastFired = nil
	self._activated = false
	self._lastPathAt = nil
	local coverTag = self.config.Tags.HeistCoverPoint
	for _, marker in ipairs(if coverTag then CollectionService:GetTagged(coverTag) else {}) do
		if marker:GetAttribute("ClaimedBy") == self.marker.Name then
			marker:SetAttribute("ClaimedBy", nil)
		end
	end
	if self:_alwaysPosted() then
		self:OnSessionStart()
	end
end

function GuardPost:Destroy()
	self:_despawn()
end

return GuardPost
