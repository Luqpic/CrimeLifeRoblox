--!strict
local TweenService = game:GetService("TweenService")

local RobbableObject = {}
RobbableObject.__index = RobbableObject

-- Rob-success feedback (spec addendum, 2026-09-14): a world-space cash burst
-- plus a decaying bounce/settle, shared identically by both cash registers
-- and ATMs -- reinforces the kaching sound and highlight-off cue with a
-- tactile payoff at the object's own location, rather than only a GUI/sound
-- cue with no reaction from the object itself.
local BURST_PARTICLE_COUNT = 18
local BOUNCE_HOP_HEIGHT = 1.5
local BOUNCE_DURATION = 0.9

-- Generalizes the "flat-value, one-time-per-session robbable object with a
-- cloned prompt and a toggled pre-placed Highlight" pattern, first built for
-- SlowFoods' cash registers and now reused for the Bank's ATM machines (spec
-- addendum, 2026-09-14) -- identical lifecycle, different location/value/
-- prompt template/sound, so this is the single implementation both wrap
-- rather than maintaining two structurally identical copies.

-- Picks whichever BasePart sits closest to the model's own pivot as the
-- prompt's attach point: these models have no PrimaryPart and no
-- distinctly-named "main" part (many generic "Part" children each), so there
-- is no better signal than proximity to the model's own center.
local function findAttachPart(model: Model): BasePart
	local pivotPos = model:GetPivot().Position
	local best, bestDist = nil, math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local dist = (d.Position - pivotPos).Magnitude
			if dist < bestDist then
				best, bestDist = d, dist
			end
		end
	end
	assert(best, "RobbableObject requires at least one BasePart descendant")
	return best
end

-- Before a robbery is active, the object has no ProximityPrompt at all --
-- not hidden, genuinely absent -- so .new() never creates one; OnSessionStart
-- is the only place a prompt is cloned in. One-time-per-session, per object:
-- the "Robbed" attribute on the MODEL is the authoritative gate, independent
-- of whether the prompt instance itself still exists, so a double-trigger
-- race right before destruction still can't rob the same object twice.
--
-- deps = {bank, promptTemplate, amount, onRefused, playRobSound}.
-- promptTemplate carries its own ActionText/ObjectText/HoldDuration (e.g.
-- "Rob register" vs "Rob ATM machine") -- never overridden here, same as
-- every other cloned-prompt component in this system. playRobSound(part) is
-- a caller-supplied hook (e.g. play a pre-placed Sound on the attach part)
-- since the two locations currently source their cue differently; this
-- module has no opinion on where the sound comes from.
function RobbableObject.new(model: Model, deps)
	local part = findAttachPart(model)
	-- Permanently pre-placed on the model itself, unlike the prompt, which is
	-- cloned in/destroyed per session -- this is toggled via .Enabled, never
	-- cloned or destroyed.
	local highlight = model:FindFirstChildOfClass("Highlight")
	assert(highlight, "RobbableObject requires a pre-placed Highlight on " .. model:GetFullName())
	highlight.Enabled = false

	-- Same static-instance pattern as the Highlight/sound above -- a single
	-- disabled/zero-rate emitter, :Emit()'d at rob time, never cloned or
	-- destroyed (spec addendum, 2026-09-14).
	local burstEmitter = part:FindFirstChildOfClass("ParticleEmitter")
	assert(burstEmitter, "RobbableObject requires a pre-placed ParticleEmitter on " .. model:GetFullName() .. "'s attach part")

	assert(deps.bank, "RobbableObject requires bank")
	assert(deps.promptTemplate, "RobbableObject requires promptTemplate")
	assert(type(deps.amount) == "number" and deps.amount > 0, "RobbableObject requires a positive amount")

	return setmetatable({
		model = model,
		part = part,
		highlight = highlight,
		burstEmitter = burstEmitter,
		bank = deps.bank,
		promptTemplate = deps.promptTemplate,
		amount = deps.amount,
		onRefused = deps.onRefused or function() end,
		playRobSound = deps.playRobSound or function() end,
		-- Opt-in (spec addendum, 2026-09-19): lets a caller refuse a hold for a
		-- reason entirely outside this object's own state -- currently only the
		-- Supplies Robbery Carry State ("drop your supplies before robbing
		-- anything else"). Same additive-dependency shape as deferUnlock below:
		-- defaults to a no-op, so every existing caller is unaffected.
		isBlocked = deps.isBlocked or function() return false end,
		-- Heist layers 2026-11-17: the onRefused reason when isBlocked refuses (default
		-- "carrying_supplies"), and onRobbed(player) after a successful rob. Both optional.
		blockedReason = deps.blockedReason or "carrying_supplies",
		onRobbed = deps.onRobbed,
		-- Heist layers 2026-11-17 (Task 3): "bonus" pays through bank:AddBonus (over the bag cap,
		-- the SlowFoods storage safe); anything else keeps bank:TryAddDuffel.
		payWith = deps.payWith,
		-- Opt-in (spec addendum, 2026-09-17): when true, OnSessionStart resets
		-- Robbed but does NOT clone the prompt/enable the highlight -- the
		-- caller becomes responsible for calling :Unlock() itself once whatever
		-- later condition it cares about is met (e.g. the Bank's ATM/Register,
		-- now gated on VaultDoor.isOpen rather than session start). Defaults to
		-- false so every EXISTING caller (SlowFoods/Gas2Go registers+ATM) keeps
		-- its current "available the instant the session starts" behavior
		-- unchanged.
		deferUnlock = deps.deferUnlock == true,
		_unlocked = false,
		_prompt = nil,
		_conn = nil,
		_bounceTween = nil,
		_bounceRestoreCFrame = nil,
	}, RobbableObject)
end

function RobbableObject:_teardownPrompt()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._prompt then
		self._prompt:Destroy()
		self._prompt = nil
	end
end

function RobbableObject:_tryRob(player)
	-- Authoritative gate: never trust prompt-existence alone -- a network
	-- delay could let a Triggered fire right before the prompt is destroyed
	-- after a first, winning trigger.
	if self.model:GetAttribute("Robbed") then return end

	if self.isBlocked(player) then
		local rok, rerr = pcall(self.onRefused, player, self.blockedReason)
		if not rok then warn("[RobbableObject] onRefused failed: " .. tostring(rerr)) end
		return
	end

	local ok, reason
	if self.payWith == "bonus" then
		ok, reason = self.bank:AddBonus(player, self.amount)
	else
		ok, reason = self.bank:TryAddDuffel(player, self.amount)
	end
	if not ok then
		-- Rejected (e.g. cap exceeded): the object is NOT marked robbed and
		-- its prompt stays live, so the player can retry later (e.g. after
		-- banking some loot to free up room).
		local rok, rerr = pcall(self.onRefused, player, reason)
		if not rok then warn("[RobbableObject] onRefused failed: " .. tostring(rerr)) end
		return
	end

	self.model:SetAttribute("Robbed", true)
	self:_teardownPrompt()
	-- No longer interactable -- must not stay visually flagged as available.
	self.highlight.Enabled = false

	local soundOk, soundErr = pcall(self.playRobSound, self.part)
	if not soundOk then warn("[RobbableObject] playRobSound failed: " .. tostring(soundErr)) end

	local feedbackOk, feedbackErr = pcall(function() self:PlayRobFeedback(self.part) end)
	if not feedbackOk then warn("[RobbableObject] PlayRobFeedback failed: " .. tostring(feedbackErr)) end

	if self.onRobbed then
		local robbedOk, robbedErr = pcall(self.onRobbed, player)
		if not robbedOk then warn("[RobbableObject] onRobbed failed: " .. tostring(robbedErr)) end
	end
end

-- One-shot confetti-style burst from the pre-placed emitter: Rate = 0, so
-- nothing emits on its own -- :Emit() fires exactly BURST_PARTICLE_COUNT
-- particles once, each fading out over its own Lifetime with no further
-- bookkeeping needed (the emitter instance itself is permanent, never
-- cloned/destroyed).
function RobbableObject:_playCashBurst(objectPart: BasePart)
	local emitter = objectPart:FindFirstChildOfClass("ParticleEmitter")
	if not emitter then return end
	emitter:Emit(BURST_PARTICLE_COUNT)
end

-- Ball-drop-style bounce/settle (spec addendum, 2026-09-14): a single tween
-- with Roblox's built-in Bounce easing style already produces the decaying
-- multi-bounce curve, rather than manually chaining several smaller tweens.
-- Moves the WHOLE model (findAttachPart's own part is one of many generic,
-- unnamed parts in these models) via PivotTo/GetPivot, not SetPrimaryPartCFrame
-- -- these models have no PrimaryPart, same reason findAttachPart exists.
-- The object is Anchored (a static world fixture, confirmed live for every
-- real register/ATM) -- tweening Position/CFrame directly is correct here;
-- unanchoring to use physics instead would risk it toppling or drifting if
-- bumped mid-bounce.
function RobbableObject:_playBounce()
	local model = self.model
	-- Read fresh each time rather than cached at construction: the object
	-- never moves except during this very animation (one-time-per-session,
	-- Anchored, static), so "wherever it is right now" and "its original
	-- resting position" are always the same thing at the moment a rob fires.
	local restCFrame = model:GetPivot()
	self._bounceRestoreCFrame = restCFrame
	local raisedCFrame = restCFrame + Vector3.new(0, BOUNCE_HOP_HEIGHT, 0)

	model:PivotTo(raisedCFrame)
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = raisedCFrame
	local conn
	conn = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		model:PivotTo(cframeValue.Value)
	end)

	local tween = TweenService:Create(
		cframeValue,
		TweenInfo.new(BOUNCE_DURATION, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Value = restCFrame })
	tween.Completed:Connect(function()
		conn:Disconnect()
		cframeValue:Destroy()
		-- Exact restore, no cumulative drift, regardless of any floating-point
		-- noise the tween itself settled on.
		model:PivotTo(restCFrame)
		self._bounceTween = nil
	end)
	self._bounceTween = tween
	tween:Play()
end

-- Both effects fire together, immediately on successful rob (spec addendum,
-- 2026-09-14) -- the single shared success-feedback entry point for both
-- Cash Registers and ATMs. objectPart is the emission point for the burst;
-- the bounce always moves the whole model regardless of which part is passed.
function RobbableObject:PlayRobFeedback(objectPart: BasePart)
	self:_playCashBurst(objectPart)
	self:_playBounce()
end

-- Clones the prompt in and enables the highlight -- split out of
-- OnSessionStart (spec addendum, 2026-09-17) so a deferUnlock caller can
-- fire this at its own later trigger instead. Idempotent: a second call
-- (e.g. an unrelated re-fire of whatever external condition drives it)
-- must not clone a second prompt on top of a still-live one.
function RobbableObject:Unlock()
	if self._unlocked then return end
	self._unlocked = true

	self:_teardownPrompt()
	local prompt = self.promptTemplate:Clone()
	prompt.Parent = self.part
	self._prompt = prompt
	self._conn = prompt.Triggered:Connect(function(player)
		self:_tryRob(player)
	end)
	-- Same trigger point as the prompt clone: the highlight tracks the
	-- prompt's own availability lifecycle exactly.
	self.highlight.Enabled = true
end

-- Heist layers 2026-11-17: shut for the rest of this session (prompt and highlight off,
-- Robbed = true). _unlocked stays true so a later Unlock() (the Bank's deferUnlock path) is a
-- no-op: Close wins until the next OnSessionStart.
function RobbableObject:Close()
	self.model:SetAttribute("Robbed", true)
	self:_teardownPrompt()
	self.highlight.Enabled = false
	self._unlocked = true
end

-- RobberyActive becomes true: every object starts fresh (session-end must
-- have cleared "Robbed" and destroyed any leftover prompt already, but this
-- is enforced again here defensively rather than assumed). Unlocks
-- immediately unless deferUnlock is set, in which case the caller decides
-- when (see Unlock's own comment).
function RobbableObject:OnSessionStart()
	self.model:SetAttribute("Robbed", false)
	self:_teardownPrompt()
	self._unlocked = false
	if not self.deferUnlock then
		self:Unlock()
	end
end

-- Session end, regardless of outcome: back to "no prompt at all", ready for
-- fresh clones next trigger. No highlight should linger into the cooldown
-- period, robbed or not.
function RobbableObject:Seal()
	self.model:SetAttribute("Robbed", false)
	self:_teardownPrompt()
	self.highlight.Enabled = false
	self._unlocked = false
	-- Interrupt-on-session-end, same pattern as VaultDoor's own Seal: a
	-- bounce still mid-flight at the exact moment the session ends must not
	-- freeze the object off its resting position into the next cooldown.
	if self._bounceTween then
		pcall(function() self._bounceTween:Cancel() end)
		self._bounceTween = nil
		if self._bounceRestoreCFrame then
			self.model:PivotTo(self._bounceRestoreCFrame)
		end
	end
end

function RobbableObject:Destroy()
	self:_teardownPrompt()
end

return RobbableObject
