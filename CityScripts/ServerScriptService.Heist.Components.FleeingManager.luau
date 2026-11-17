--!strict
-- Heist layers 2026-11-17 (SlowFoods): the Manager. An NPCSpawnManager controller (`.model`,
-- OnSessionStart, Seal, Destroy). On the alarm he unanchors and paths to the escape point; a
-- participant within config.ManagerKeyRange who holds "Take Key" (config.ManagerKeyHold, timed
-- here, distance re-measured here) gets the key through onKeyTaken and he stops and cowers. If he
-- reaches the point he is hidden (unparented) until NPCSpawnManager:Rearm clones a fresh one.
--
-- deps = {bank, config, escapePoint: BasePart, onKeyTaken(player), measure(player)->number?,
--         pathTo(model, Vector3, keepGoing?), clock?}
local PathfindingService = game:GetService("PathfindingService")

local FleeingManager = {}
FleeingManager.__index = FleeingManager

local SCARED_ANIMATION_ID = "rbxassetid://88601399527319" -- NPCReactionAnimator's Scared
local ARRIVE_TOLERANCE = 4 -- studs, horizontal
local HOLD_TOLERANCE = 0.15 -- seconds of network jitter allowed under the hold
local MOVE_STEP_TIMEOUT = 2 -- seconds per waypoint before re-pathing
local GIVE_UP_AFTER = 60 -- seconds; longer than the 120 s session's useful part

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function defaultMeasure(root: BasePart)
	return function(player): number?
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not (playerRoot and playerRoot:IsA("BasePart")) then return nil end
		return (playerRoot.Position - root.Position).Magnitude
	end
end

-- GuardPost:_moveToCover's pattern (CreatePath, next waypoints, direct MoveTo fallback), run
-- in its own thread until he arrives, keepGoing() turns false or GIVE_UP_AFTER passes.
-- AgentRadius 1: the restaurant's only walkable exit is a double door with 4-stud leaves.
local function defaultPathTo(model: Model, target: Vector3, keepGoing: (() -> boolean)?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) then return end
	local going = keepGoing or function() return true end
	local deadline = os.clock() + GIVE_UP_AFTER
	local function stepTo(position: Vector3)
		humanoid:MoveTo(position)
		local started = os.clock()
		while going() and model.Parent and os.clock() - started < MOVE_STEP_TIMEOUT
			and horizontal(root.Position, position) > 2 do
			task.wait(0.1)
		end
	end
	while going() and model.Parent and os.clock() < deadline
		and horizontal(root.Position, target) > ARRIVE_TOLERANCE do
		local path = PathfindingService:CreatePath({ AgentRadius = 1, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function() path:ComputeAsync(root.Position, target) end)
		if ok and path.Status == Enum.PathStatus.Success then
			for i, waypoint in ipairs(path:GetWaypoints()) do
				if i > 1 then
					if not going() or not model.Parent then break end
					if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
					stepTo(waypoint.Position)
				end
			end
		else
			stepTo(target)
		end
	end
end

local function loadTrack(humanoid: Humanoid, animationId: string?, looped: boolean): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not (animator and animationId) then return nil end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok then return nil end
	track.Looped = looped
	track.Priority = Enum.AnimationPriority.Action
	return track
end

function FleeingManager.new(model: Model, deps)
	assert(deps and deps.bank, "FleeingManager requires bank")
	assert(deps.config, "FleeingManager requires config")
	assert(deps.escapePoint and deps.escapePoint:IsA("BasePart"), "FleeingManager requires an escapePoint BasePart")
	assert(type(deps.onKeyTaken) == "function", "FleeingManager requires onKeyTaken")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "FleeingManager requires a Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "FleeingManager requires a HumanoidRootPart")

	-- The template's own (Legacy, so never running) Animate script holds the walk animation.
	local animate = model:FindFirstChild("Animate")
	local walkValue = animate and animate:FindFirstChild("walk")
	local walkAnim = walkValue and walkValue:FindFirstChildOfClass("Animation")

	local self = setmetatable({
		model = model,
		humanoid = humanoid,
		root = root :: BasePart,
		bank = deps.bank,
		config = deps.config,
		escapePoint = deps.escapePoint :: BasePart,
		onKeyTaken = deps.onKeyTaken,
		measure = deps.measure or defaultMeasure(root :: BasePart),
		pathTo = deps.pathTo or defaultPathTo,
		clock = deps.clock or os.clock,
		state = "idle",
		_runId = 0,
		_prompt = nil :: ProximityPrompt?,
		_holdBegan = {},
		_walkTrack = loadTrack(humanoid, walkAnim and walkAnim.AnimationId, true),
		_scaredTrack = loadTrack(humanoid, SCARED_ANIMATION_ID, true),
	}, FleeingManager)
	-- Behind the counter he must not drift or be shoved before the alarm.
	self.root.Anchored = true
	return self
end

function FleeingManager:_removePrompt()
	if self._prompt then
		self._prompt:Destroy()
		self._prompt = nil
	end
	table.clear(self._holdBegan)
end

-- Stop where he stands: a new run id ends the path thread, the anchor ends any MoveTo.
function FleeingManager:_stop()
	self._runId += 1
	self:_removePrompt()
	if self.model.Parent then self.humanoid:MoveTo(self.root.Position) end
	self.root.Anchored = true
	if self._walkTrack then self._walkTrack:Stop() end
end

function FleeingManager:OnSessionStart()
	if self.state ~= "idle" then return end
	self.state = "fleeing"
	self._runId += 1
	local runId = self._runId

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakeKeyPrompt"
	prompt.ActionText = "Take Key"
	prompt.ObjectText = "Manager"
	prompt.HoldDuration = self.config.ManagerKeyHold
	prompt.MaxActivationDistance = self.config.ManagerKeyRange
	prompt.RequiresLineOfSight = false
	prompt.PromptButtonHoldBegan:Connect(function(player) self:_onHoldBegan(player) end)
	prompt.Triggered:Connect(function(player) self:_onPromptTriggered(player) end)
	prompt.Parent = self.root
	self._prompt = prompt

	self.root.Anchored = false
	-- Measured in Play: without these two lines he lay toppled ~3 s after unanchoring; with them
	-- he runs at once. The server owns his physics.
	pcall(function() self.root:SetNetworkOwner(nil) end)
	self.humanoid:ChangeState(Enum.HumanoidStateType.Running)
	if self._walkTrack then self._walkTrack:Play() end
	local target = self.escapePoint.Position
	task.spawn(function()
		self.pathTo(self.model, target, function() return self._runId == runId end)
		if self._runId ~= runId or self.state ~= "fleeing" then return end
		if horizontal(self.root.Position, target) <= ARRIVE_TOLERANCE then
			self:_escape()
		end
	end)
end

function FleeingManager:_escape()
	self.state = "escaped"
	self:_stop()
	self.model.Parent = nil
end

function FleeingManager:_onHoldBegan(player)
	self._holdBegan[player] = self.clock()
end

-- The engine's hold is client-side only: honour a trigger only after a hold the server saw.
function FleeingManager:_onPromptTriggered(player)
	local began = self._holdBegan[player]
	self._holdBegan[player] = nil
	if not began or self.clock() - began < self.config.ManagerKeyHold - HOLD_TOLERANCE then return end
	self:TryTakeKey(player)
end

function FleeingManager:TryTakeKey(player): (boolean, string?)
	if self.state ~= "fleeing" then return false, "not_fleeing" end
	if not self.bank:IsParticipant(player) then return false, "not_participant" end
	local distance = self.measure(player)
	if type(distance) ~= "number" or distance > self.config.ManagerKeyRange then return false, "too_far" end

	self.state = "caught"
	self:_stop()
	if self._scaredTrack then self._scaredTrack:Play() end
	local ok, err = pcall(self.onKeyTaken, player)
	if not ok then warn("[FleeingManager] onKeyTaken failed: " .. tostring(err)) end
	return true
end

-- Session end: he stops where he is (or stays hidden) until Rearm respawns a fresh Manager.
function FleeingManager:Seal()
	if self.state == "fleeing" or self.state == "caught" then
		self.state = "idle"
	end
	self:_stop()
	if self._scaredTrack then self._scaredTrack:Stop() end
end

function FleeingManager:Destroy()
	self._runId += 1
	self:_removePrompt()
	if self._walkTrack then self._walkTrack:Stop() end
	if self._scaredTrack then self._scaredTrack:Stop() end
end

return FleeingManager
