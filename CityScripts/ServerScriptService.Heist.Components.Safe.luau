--!strict
local TweenService = game:GetService("TweenService")

local Safe = {}
Safe.__index = Safe

-- Same rob-success feedback recipe as ReplicatedStorage.SharedSystems.
-- RobbableObject (spec addendum, 2026-09-14/2026-09-16) -- duplicated, not
-- shared, because Safe's trigger lifecycle genuinely diverges from
-- RobbableObject's: holding the prompt gates a code-entry GUI instead of an
-- immediate grant, and RobbableObject has no hook to intercept/defer its own
-- hardcoded hold -> grant path (confirmed: _tryRob's success branch is not
-- overridable). Forking the shared module -- or bolting an onHold escape
-- hatch onto a module with 4 existing production callers and its own 24-test
-- spec -- carries more regression risk than re-stating this small, stable,
-- already-proven ~40 lines here.
local BURST_PARTICLE_COUNT = 18
local BOUNCE_HOP_HEIGHT = 1.5
local BOUNCE_DURATION = 0.9

-- City (phase 3 Task 5): when each opted-in player last spent a safe attempt, shared by every
-- opted-in Safe so a second safe of the same location does not reset the floor. Weak keys:
-- a departed Player drops out on its own.
local lastAttemptAt = setmetatable({}, { __mode = "k" })

-- Same server-side re-measure as Terminal.lua's own defaultMeasure --
-- SubmitSafeCode is a bare client-fireable RemoteEvent with no engine-level
-- proximity gate of its own (unlike a ProximityPrompt), so this is the ONLY
-- thing standing between "walked up and held the prompt" and "fired the
-- remote from anywhere on the map" (regression found via adversarial review,
-- 2026-09-16: nothing previously tied a submission back to an actual
-- trigger, letting a modified client brute-force the shared 4-digit code
-- with zero proximity and zero physical interaction).
local function defaultMeasure(part: BasePart, player): number
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return math.huge end
	return (root.Position - part.Position).Magnitude
end

-- Identical algorithm to RobbableObject.findAttachPart -- these models have
-- no PrimaryPart and many generic, identically-named "Part" children, so
-- proximity to the model's own pivot is the only reliable signal.
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
	assert(best, "Safe requires at least one BasePart descendant")
	return best
end

-- deps = {bank, promptTemplate, amount, getCode, onOpenGui, onRefused,
-- playRobSound}. getCode() returns the CURRENT session's shared code (owned
-- by SafeCode, not this object -- confirmed live: both physical safes
-- validate against the SAME code, but are independently robbable). onOpenGui
-- (player, self) fires instead of an immediate grant when the prompt is
-- held -- the caller is responsible for actually showing the client GUI.
function Safe.new(model: Model, deps)
	assert(model and model:IsA("Model"), "Safe requires a Model")
	local part = findAttachPart(model)

	local highlight = model:FindFirstChildOfClass("Highlight")
	assert(highlight, "Safe requires a pre-placed Highlight on " .. model:GetFullName())
	-- Pre-existing gap fixed 2026-09-17: unlike RobbableObject.new (which
	-- does this same line), Safe never explicitly disabled the highlight at
	-- construction -- a fresh Highlight instance defaults to Enabled=true
	-- (confirmed live), so before the very first session ever started, a
	-- Safe's highlight was silently ON when it should have been off. Only
	-- ever surfaced now because deferUnlock introduces a real, externally-
	-- observable "locked" window where this default actually matters.
	highlight.Enabled = false

	local burstEmitter = part:FindFirstChildOfClass("ParticleEmitter")
	assert(burstEmitter, "Safe requires a pre-placed ParticleEmitter on " .. model:GetFullName() .. "'s attach part")

	assert(deps.bank, "Safe requires bank")
	assert(deps.promptTemplate, "Safe requires promptTemplate")
	assert(type(deps.amount) == "number" and deps.amount > 0, "Safe requires a positive amount")
	assert(type(deps.getCode) == "function", "Safe requires getCode")
	assert(type(deps.onOpenGui) == "function", "Safe requires onOpenGui")

	return setmetatable({
		model = model,
		part = part,
		highlight = highlight,
		bank = deps.bank,
		promptTemplate = deps.promptTemplate,
		amount = deps.amount,
		getCode = deps.getCode,
		onOpenGui = deps.onOpenGui,
		onRefused = deps.onRefused or function() end,
		playRobSound = deps.playRobSound or function() end,
		measure = deps.measure or defaultMeasure,
		-- Opt-in (spec addendum, 2026-09-19), same additive shape/reason as
		-- RobbableObject's own isBlocked -- currently only the Supplies
		-- Robbery Carry State. Checked in _onTriggered, before the GUI ever
		-- opens; TrySubmitCode needs no copy of its own -- a blocked player's
		-- _onTriggered never sets _pending, so TrySubmitCode already rejects
		-- them with "not_pending".
		isBlocked = deps.isBlocked or function() return false end,
		-- Set for real once OnSessionStart clones the prompt (mirrors
		-- Terminal's own self.maxDistance = prompt.MaxActivationDistance) --
		-- 0 until then, but _onTriggered can never fire before a prompt
		-- exists anyway, so this placeholder is never actually load-bearing.
		maxDistance = 0,
		-- Per-player "this player's prompt hold actually opened a GUI for
		-- THIS safe, and hasn't been consumed by a submission yet" gate
		-- (spec-consistent, not an extra restriction: the user's own spec
		-- says a wrong guess closes the GUI and "the player can immediately
		-- re-trigger the prompt to try again" -- i.e. one hold = one
		-- attempt, by design). Cleared on every TrySubmitCode call
		-- (right or wrong) and on Seal.
		_pending = {},
		-- Opt-in (spec addendum, 2026-09-17): same shape as RobbableObject's own
		-- deferUnlock -- when true, OnSessionStart resets Robbed/_pending but
		-- does NOT clone the prompt/enable the highlight; the caller must call
		-- :Unlock() itself once its own later condition is met (the Bank's
		-- Safe is now gated on VaultDoor.isOpen, not session start). Defaults
		-- to false, matching RobbableObject's own default.
		deferUnlock = deps.deferUnlock == true,
		-- City (phase 3 Task 5), opt-in: a prompt's HoldDuration is enforced only on the client,
		-- so a script could re-trigger and guess twice a second. With enforceHold, one player's
		-- attempts are at least the prompt's own HoldDuration apart (read at Unlock, like
		-- maxDistance); an attempt inside that floor is refused as "too_soon" and keeps its try.
		enforceHold = deps.enforceHold == true,
		minAttemptInterval = 0,
		clock = deps.clock or os.clock,
		_unlocked = false,
		_prompt = nil,
		_conn = nil,
		_bounceTween = nil,
		_bounceRestoreCFrame = nil,
	}, Safe)
end

function Safe:_teardownPrompt()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._prompt then
		self._prompt:Destroy()
		self._prompt = nil
	end
end

-- Holding the prompt to completion opens the code-entry GUI -- it does NOT
-- grant anything by itself (the one deliberate divergence from every other
-- robbable object in this system). Re-validates Robbed/session state here,
-- same discipline as RobbableObject's own _tryRob gate, even though
-- TrySubmitCode below re-checks everything again at actual submission time
-- (a real gap can open between "prompt held" and "code submitted" -- the
-- session could end, or someone else could crack this exact safe, while the
-- GUI is still open).
function Safe:_onTriggered(player)
	if self.model:GetAttribute("Robbed") then return end
	if self.bank:GetState() ~= "Active" then return end
	local distance = self.measure(self.part, player)
	if type(distance) ~= "number" or distance > self.maxDistance then return end
	if self.isBlocked(player) then
		local rok, rerr = pcall(self.onRefused, player, "carrying_supplies")
		if not rok then warn("[Safe] onRefused failed: " .. tostring(rerr)) end
		return
	end
	self._pending[player] = true
	self.onOpenGui(player, self)
end

-- Server-authoritative code check (spec: "the client never knows the real
-- code, only sends its guess"). Called from HeistServer's SubmitSafeCode
-- remote handler once it has resolved which Safe instance a guess targets.
-- Never trusts that the earlier _onTriggered moment is still valid -- full
-- re-check here, exactly the discipline Terminal.validate/C4Charge.validate
-- already establish elsewhere in this codebase. A wrong guess does NOT mark
-- this safe robbed and does NOT tear down its prompt (spec: unlimited
-- retries, no cooldown, no lockout) -- only a correct one does.
function Safe:TrySubmitCode(player, guess: string): (boolean, string?)
	-- Consumed on every call, right or wrong: closes the "fire the remote
	-- directly, never approach the safe or hold the prompt" exploit (a
	-- modified client can no longer brute-force the shared code from
	-- anywhere on the map or across colluding alts sitting idle elsewhere)
	-- while matching the spec's own described flow exactly -- one prompt
	-- hold gates exactly one guess, then the player re-triggers for another.
	if not self._pending[player] then return false, "not_pending" end
	if self.enforceHold then
		local t = self.clock()
		local last = lastAttemptAt[player]
		if last and t - last < self.minAttemptInterval then return false, "too_soon" end
		lastAttemptAt[player] = t
	end
	self._pending[player] = nil

	if self.model:GetAttribute("Robbed") then return false, "already_robbed" end
	if self.bank:GetState() ~= "Active" then return false, "inactive" end

	local code = self.getCode()
	if not code or guess ~= code then return false, "wrong_code" end

	local ok, reason = self.bank:TryAddDuffel(player, self.amount)
	if not ok then
		-- Cap exceeded etc: NOT marked robbed, prompt stays live -- same
		-- "retry later" contract as every other robbable object's refusal
		-- path, even though the code itself was correct.
		local rok, rerr = pcall(self.onRefused, player, reason)
		if not rok then warn("[Safe] onRefused failed: " .. tostring(rerr)) end
		return false, reason
	end

	self.model:SetAttribute("Robbed", true)
	self:_teardownPrompt()
	self.highlight.Enabled = false

	local soundOk, soundErr = pcall(self.playRobSound, self.part)
	if not soundOk then warn("[Safe] playRobSound failed: " .. tostring(soundErr)) end

	local feedbackOk, feedbackErr = pcall(function() self:PlayRobFeedback(self.part) end)
	if not feedbackOk then warn("[Safe] PlayRobFeedback failed: " .. tostring(feedbackErr)) end

	return true
end

function Safe:_playCashBurst(objectPart: BasePart)
	local emitter = objectPart:FindFirstChildOfClass("ParticleEmitter")
	if not emitter then return end
	emitter:Emit(BURST_PARTICLE_COUNT)
end

function Safe:_playBounce()
	local model = self.model
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
		model:PivotTo(restCFrame)
		self._bounceTween = nil
	end)
	self._bounceTween = tween
	tween:Play()
end

function Safe:PlayRobFeedback(objectPart: BasePart)
	self:_playCashBurst(objectPart)
	self:_playBounce()
end

-- Clones the prompt in and enables the highlight -- split out of
-- OnSessionStart (spec addendum, 2026-09-17) so a deferUnlock caller can
-- fire this at its own later trigger instead. Idempotent, same reasoning as
-- RobbableObject's own Unlock.
function Safe:Unlock()
	if self._unlocked then return end
	self._unlocked = true

	self:_teardownPrompt()
	local prompt = self.promptTemplate:Clone()
	prompt.Parent = self.part
	self._prompt = prompt
	self.maxDistance = prompt.MaxActivationDistance
	if self.enforceHold then self.minAttemptInterval = prompt.HoldDuration end
	self._conn = prompt.Triggered:Connect(function(player)
		self:_onTriggered(player)
	end)
	self.highlight.Enabled = true
end

-- Same lifecycle shape as RobbableObject's OnSessionStart -- resets fresh
-- state, then unlocks immediately unless deferUnlock is set.
function Safe:OnSessionStart()
	self.model:SetAttribute("Robbed", false)
	self:_teardownPrompt()
	-- Defensively cleared HERE, not in Seal: a pending flag set legitimately
	-- (prompt held while Active) must survive into Cooldown so a submission
	-- arriving just after the session ends still reaches the "inactive"
	-- check below and gets an honest reason, instead of being silently wiped
	-- and misreported as "you never triggered the prompt". It only needs to
	-- be gone before the NEXT session, so it can't let a stale trigger from
	-- a past session skip the requirement against a brand-new code.
	self._pending = {}
	self._unlocked = false
	if not self.deferUnlock then
		self:Unlock()
	end
end

function Safe:Seal()
	self.model:SetAttribute("Robbed", false)
	self:_teardownPrompt()
	self.highlight.Enabled = false
	self._unlocked = false
	if self._bounceTween then
		pcall(function() self._bounceTween:Cancel() end)
		self._bounceTween = nil
		if self._bounceRestoreCFrame then
			self.model:PivotTo(self._bounceRestoreCFrame)
		end
	end
end

function Safe:Destroy()
	self:_teardownPrompt()
end

return Safe
