--!strict
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local GuardPost = {}
GuardPost.__index = GuardPost

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

-- Clone-from-template rather than resetting a corpse: unragdolling a dead R15
-- rig and rebuilding its Motor6Ds is far more bug-prone than starting fresh.
-- `lift` (config.GuardSpawnLift, default 3 as before): studs above the marker for the template's pivot, which
-- is at its feet. NewsStation uses 0 so its guards stand on the floor its markers sit on.
local function defaultSpawn(targetCFrame: CFrame, lift: number?): Model?
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

-- config.GuardsAlwaysPosted (NewsStation, police and wanted Task 3, 2026-11-17): the guard stands at its post
-- from boot, through Idle and Cooldown, and a fresh one replaces it at Rearm; a guard alive at Seal stays.
-- Without the flag (the Bank) guards exist only while a session is Active, as before. A config whose Tags
-- have no HeistCoverPoint gives guards no cover to run to: they hold their posts and fire from there.
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
		damage = deps.damage or function() end,
		_guard = nil,
		_humanoid = nil,
		_spawnedThisSession = false,
		_deathReported = false,
		_coverTarget = nil,
		_lastFired = nil,
		_activated = false,
		_lastPathAt = nil,
		_diedConn = nil,
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
	if self._spawnedThisSession then return end
	self._spawnedThisSession = true
	self._deathReported = false
	self._lastFired = nil

	local guard = self.spawnGuard(self.marker.CFrame, self.config and self.config.GuardSpawnLift)
	self._guard = guard
	if not guard then return end

	local ok, err = pcall(self.onGuardSpawned)
	if not ok then warn("[GuardPost] onGuardSpawned failed: " .. tostring(err)) end

	self._humanoid = guard:FindFirstChildOfClass("Humanoid")
	if self._humanoid then
		self._diedConn = self._humanoid.Died:Connect(function()
			self:_handleDeath()
		end)
	end
end

function GuardPost:_handleDeath()
	if self._deathReported then return end
	self._deathReported = true
	self._diedAt = self.now()
	local ok, err = pcall(self.onGuardDied)
	if not ok then warn("[GuardPost] onGuardDied failed: " .. tostring(err)) end
end

function GuardPost:_moveToCover()
	if not self._guard or not self._humanoid then return end
	local root = self._guard.PrimaryPart
	if not root then return end
	if not self.config.Tags.HeistCoverPoint then return end -- no cover here: hold the post

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
	self:_despawn()
	self._spawnedThisSession = false
	self._diedAt = nil
	self._activated = false
	self:OnSessionStart()
end

function GuardPost:Update()
	if self.bank:GetState() ~= "Active" then
		self:_respawnIfDue()
		return
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
		return GuardPost.mayTarget(self.bank, player)
	end)
	if not target then return end

	local now = self.now()
	if not GuardPost.shouldFire(now, self._lastFired, self.config.GuardFireInterval) then return end
	self._lastFired = now

	local ok, err = pcall(self.damage, target, self.config.GuardDamage)
	if not ok then warn("[GuardPost] damage failed: " .. tostring(err)) end
end

-- Heist layers 2026-11-17: engage at once, as if a player had come within GuardActivationRange.
-- Targeting (mayTarget, sight range, line of sight) is unchanged. No-op when the guard is dead.
function GuardPost:Alert()
	if not self:IsAlive() then return end
	self._activated = true
end

function GuardPost:_despawn()
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

-- Stage 2: allow a fresh guard for the next session. Guards do not exist while
-- the bank is Idle or in Cooldown.
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
