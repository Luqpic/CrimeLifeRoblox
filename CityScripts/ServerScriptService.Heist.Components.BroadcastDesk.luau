--!strict
-- Heist layers 2026-11-17 (NewsStation): the broadcast desk. Locked until Arm() (the first
-- MasterComputer breach of the session). Any participant within config.BroadcastRange holds
-- "Go Live" once; then Update() counts air time while at least one living participant is within
-- range (pauses when nobody is, never resets). At config.BroadcastSeconds the participants in range
-- at that moment go to onComplete. One broadcast per session; Seal ends it without a payout.
--
-- deps = {bank, config, now?, measure?(player)->number?, onLive(player), onComplete({Player}),
--   isBlocked?(player)->boolean, onRefused?(player, reason)}
-- The model needs a Highlight and a Studio-authored BillboardGui with a TextLabel.
-- Final review I1 (2026-11-18): carriers can't rob. isBlocked (the carry check) refuses Go Live with reason
-- "carrying_supplies", and a carrier in range at completion is not paid (still counts as holding the desk).
-- Leftovers (2026-11-18): a refused press through the prompt goes to onRefused, so the presser is told why.
local BroadcastDesk = {}
BroadcastDesk.__index = BroadcastDesk

local HOLD_DURATION = 1
local HOLD_TOLERANCE = 0.15 -- seconds of network jitter allowed under the hold

-- Same closest-to-pivot attach part as MasterComputer/RobbableObject.
local function findAttachPart(model: Model): BasePart
	local pivotPos = model:GetPivot().Position
	local best, bestDist = nil, math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local dist = (d.Position - pivotPos).Magnitude
			if dist < bestDist then best, bestDist = d, dist end
		end
	end
	assert(best, "BroadcastDesk requires at least one BasePart descendant")
	return best
end

-- Distance from a living character to the desk; nil when dead or without a character.
local function defaultMeasure(part: BasePart)
	return function(player): number?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then return nil end
		return (root.Position - part.Position).Magnitude
	end
end

function BroadcastDesk.new(model: Model, deps)
	assert(model and model:IsA("Model"), "BroadcastDesk requires a Model")
	assert(deps and deps.bank, "BroadcastDesk requires bank")
	assert(deps.config, "BroadcastDesk requires config")
	assert(type(deps.onLive) == "function", "BroadcastDesk requires onLive")
	assert(type(deps.onComplete) == "function", "BroadcastDesk requires onComplete")
	local highlight = model:FindFirstChildWhichIsA("Highlight", true)
	assert(highlight, "BroadcastDesk requires a Highlight")
	local billboard = model:FindFirstChildWhichIsA("BillboardGui", true)
	local label = billboard and billboard:FindFirstChildWhichIsA("TextLabel", true)
	assert(label, "BroadcastDesk requires a BillboardGui with a TextLabel")

	local part = findAttachPart(model)
	model.PrimaryPart = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GoLivePrompt"
	prompt.ActionText = "Go Live"
	prompt.ObjectText = "Broadcast Desk"
	prompt.HoldDuration = HOLD_DURATION
	prompt.MaxActivationDistance = deps.config.BroadcastRange
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part

	local self = setmetatable({
		model = model,
		part = part,
		prompt = prompt,
		highlight = highlight,
		label = label :: TextLabel,
		bank = deps.bank,
		config = deps.config,
		now = deps.now or os.clock,
		measure = deps.measure or defaultMeasure(part),
		onLive = deps.onLive,
		onComplete = deps.onComplete,
		isBlocked = deps.isBlocked or function() return false end,
		onRefused = deps.onRefused or function() end,
		state = "locked",
		airSeconds = 0,
		_lastUpdate = 0,
		_holdBegan = {}, -- player -> now() when their hold began (keyed by the player value)
		_conns = {},
	}, BroadcastDesk)
	table.insert(self._conns, prompt.PromptButtonHoldBegan:Connect(function(player) self:_onHoldBegan(player) end))
	table.insert(self._conns, prompt.Triggered:Connect(function(player) self:_onPromptTriggered(player) end))
	highlight.Enabled = false
	self:_render()
	return self
end

function BroadcastDesk:_render()
	if self.state == "live" then
		local left = math.max(0, math.ceil(self.config.BroadcastSeconds - self.airSeconds - 1e-6))
		self.label.Text = string.format("LIVE %d:%02d", left // 60, left % 60)
	elseif self.state == "armed" then
		self.label.Text = "GO LIVE"
	elseif self.state == "done" then
		self.label.Text = "AIRED"
	else
		self.label.Text = "OFF AIR"
	end
end

function BroadcastDesk:_setOpen(open: boolean)
	self.prompt.Enabled = open
	self.highlight.Enabled = open
end

function BroadcastDesk:_inRange(player): boolean
	local distance = self.measure(player)
	return type(distance) == "number" and distance <= self.config.BroadcastRange
end

-- The first breach of an Active session opens the desk; a live or finished desk is untouched.
function BroadcastDesk:Arm()
	if self.state ~= "locked" or self.bank:GetState() ~= "Active" then return end
	self.state = "armed"
	self:_setOpen(true)
	self:_render()
end

function BroadcastDesk:_onHoldBegan(player)
	self._holdBegan[player] = self.now()
end

-- The engine's hold is client-side only: honour a trigger only after a hold the server saw.
function BroadcastDesk:_onPromptTriggered(player)
	local began = self._holdBegan[player]
	self._holdBegan[player] = nil
	if not began or self.now() - began < HOLD_DURATION - HOLD_TOLERANCE then return end
	local ok, reason = self:TryGoLive(player)
	if not ok then
		local rok, rerr = pcall(self.onRefused, player, reason)
		if not rok then warn("[BroadcastDesk] onRefused failed: " .. tostring(rerr)) end
	end
end

function BroadcastDesk:TryGoLive(player): (boolean, string?)
	if self.state == "live" then return false, "already_live" end
	if self.state == "done" then return false, "done" end
	if self.state ~= "armed" then return false, "not_armed" end
	if not self.bank:IsParticipant(player) then return false, "not_participant" end
	if self.isBlocked(player) then return false, "carrying_supplies" end
	if not self:_inRange(player) then return false, "too_far" end

	self.state = "live"
	self._lastUpdate = self.now()
	self.prompt.Enabled = false -- nobody has to press again; the highlight stays on while live
	self:_render()
	local ok, err = pcall(self.onLive, player)
	if not ok then warn("[BroadcastDesk] onLive failed: " .. tostring(err)) end
	return true
end

function BroadcastDesk:_participantsInRange()
	local list = {}
	for _, player in ipairs(self.bank:GetParticipants()) do
		if self:_inRange(player) then table.insert(list, player) end
	end
	return list
end

-- Called from the location's heartbeat. Air time accrues for the interval since the last call
-- only when someone holds the studio at this call.
function BroadcastDesk:Update()
	if self.state ~= "live" then return end
	local t = self.now()
	local dt = math.max(0, t - self._lastUpdate)
	self._lastUpdate = t
	local holders = self:_participantsInRange()
	if #holders == 0 then return end
	self.airSeconds = math.min(self.config.BroadcastSeconds, self.airSeconds + dt)
	if self.airSeconds >= self.config.BroadcastSeconds then
		self.state = "done"
		self:_setOpen(false)
		self:_render()
		local payees = {}
		for _, player in ipairs(holders) do
			if not self.isBlocked(player) then table.insert(payees, player) end
		end
		local ok, err = pcall(self.onComplete, payees)
		if not ok then warn("[BroadcastDesk] onComplete failed: " .. tostring(err)) end
		return
	end
	self:_render()
end

function BroadcastDesk:OnSessionStart()
	self.state = "locked"
	self.airSeconds = 0
	table.clear(self._holdBegan)
	self:_setOpen(false)
	self:_render()
end

-- Session end: whatever was on air stops, unpaid. The next OnSessionStart re-locks it.
function BroadcastDesk:Seal()
	if self.state ~= "locked" then self.state = "done" end
	table.clear(self._holdBegan)
	self:_setOpen(false)
	self.label.Text = "OFF AIR"
end

function BroadcastDesk:Forget(player)
	self._holdBegan[player] = nil
end

function BroadcastDesk:Destroy()
	for _, conn in ipairs(self._conns) do conn:Disconnect() end
	table.clear(self._conns)
	if self.prompt then self.prompt:Destroy() end
end

return BroadcastDesk
