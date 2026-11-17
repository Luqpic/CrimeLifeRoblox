--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HeistConfig = require(ReplicatedStorage.HeistShared.Config)

-- Despawn implosion (spec addendum, 2026-09-2X): natural despawn only (NOT
-- re-pickup) plays a collapse-inward pulse before vanishing -- reads
-- distinctly from the drop/detach pop-out elsewhere in this project (a
-- uniform release-and-shrink) by pivoting around the model's own true
-- centroid (see the PivotOffset fix in .new()) and accelerating INTO the
-- collapse (Quad/In) rather than a springy Elastic bounce. Same NumberValue-
-- driven Model:ScaleTo() technique as DuffelBagAttachment's own tweenScale
-- helper (Model.Scale isn't directly tweenable on this engine version).
local IMPLOSION_END_SCALE = 0.05
local IMPLOSION_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local SupplyObject = {}
SupplyObject.__index = SupplyObject

-- Supplies Robbery (spec addendum, 2026-09-19): SlowFoods/Gas2Go-only side
-- mechanic. Deliberately NOT built on top of RobbableObject -- that module's
-- lifecycle is "toggle Robbed/highlight/prompt in place, once, forever";
-- this one genuinely moves and reappears (carried off, dropped elsewhere,
-- silently despawned, reset to its original spot next session), which
-- RobbableObject has no hook for (same reasoning Safe's own header comment
-- already gives for forking instead of extending).
--
-- Identical findAttachPart algorithm to RobbableObject/Safe -- these models
-- have no PrimaryPart and no distinctly-named "main" part.
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
	assert(best, "SupplyObject requires at least one BasePart descendant")
	return best
end

-- deps = {bank, promptTemplate, repickupPromptTemplate, onPickup, onRefused?,
-- isBlocked?, despawnTime?}. repickupPromptTemplate is used ONLY by DropAt's
-- re-arm (spec: the re-pickup prompt on a dropped/settled object is instant,
-- HoldDuration = 0 -- the ORIGINAL in-place "Steal Supplies" prompt keeps
-- its own hold duration unchanged, so these are deliberately two distinct
-- templates, not one reused for both).
-- onPickup(player, self) fires once a hold succeeds and the model has
-- ALREADY been hidden -- the caller (SlowFoodsServer/Gas2GoServer) is
-- responsible for actually starting the Carry State (equipping a Tool via
-- SharedSystems.CarryState). isBlocked(player) is the same additive gate
-- shape RobbableObject/Safe now both have -- lets an already-carrying
-- player be refused a second pickup. despawnTime overrides
-- HeistConfig.SupplyDespawnTime (test-only hook, so specs can exercise a
-- real timer expiry without waiting 20 real seconds).
-- Heist layers 2026-11-17 (heavy loot): bankOnly (the Illegal Supplier refuses it) and speedCap
-- (CarryState slows the carrier to it) are stored as plain fields. startHidden: OnSessionStart
-- leaves the object hidden with no prompt, and only GiveTo hands it over.
-- enforceHold (Task 4): the engine's hold is client-side only, so a prompt with a HoldDuration is
-- honoured only after a hold the server timed itself (PromptButtonHoldBegan, then Triggered at
-- least HoldDuration - HOLD_TOLERANCE later, as FleeingManager does). clock defaults to os.clock.
local HOLD_TOLERANCE = 0.15

function SupplyObject.new(model: Model, deps)
	assert(model and model:IsA("Model"), "SupplyObject requires a Model")
	local part = findAttachPart(model)
	-- Physics-drop fix (found live, 2026-09-20): a Model with no PrimaryPart
	-- computes GetPivot()/PivotTo() from an internal snapshot that does NOT
	-- track live physics -- confirmed live that once the (now unanchored,
	-- physics-active) parts fall/settle away from wherever PivotTo last put
	-- them, a subsequent PivotTo (e.g. OnSessionStart's reset) computes its
	-- delta from that STALE snapshot, landing the model tens of studs off
	-- from the real target. Assigning a PrimaryPart makes GetPivot() always
	-- equal PrimaryPart.CFrame * PivotOffset -- a genuinely live value -- so
	-- every PivotTo call after this is always correct regardless of how far
	-- physics has since carried the object.
	-- Centroid attempt (2026-09-2X), reverted: tried also setting
	-- Model.PivotOffset (relative to PrimaryPart) to the model's true
	-- GetBoundingBox() center, so the despawn implosion below would collapse
	-- toward the model's real visual centroid rather than toward wherever
	-- this one specific attach part happens to sit. Confirmed live:
	-- Model.PivotOffset is not a valid member on this engine build (same
	-- category of gap as Model.Scale not being directly tweenable, already
	-- discovered earlier this session) -- so the pivot stays exactly
	-- PrimaryPart.CFrame, same as the live-physics fix above already relied
	-- on. findAttachPart's own "closest existing part to the model's default
	-- pivot" selection already keeps this a reasonable centroid
	-- approximation in practice, just not a mathematically exact one.
	model.PrimaryPart = part
	-- Scale baseline (spec correction, 2026-09-2X): a previous round forced
	-- ScaleTo(1) here unconditionally, assuming 1 was always the correct
	-- baseline -- WRONG. SupplyFoodBox's true/original geometry was oversized
	-- and has been deliberately corrected by hand in Studio (confirmed live:
	-- both real SupplyFoodBox instances read Scale == 0.437; both real
	-- Barrels instances read a clean 1.0 -- genuinely different per object,
	-- not a universal constant). That hardcoded ScaleTo(1) actively fought
	-- this manual correction every time the server booted. Captured here
	-- instead, once, BEFORE this component ever calls ScaleTo itself -- so
	-- whatever is currently authored in Studio at server-boot time becomes
	-- this specific object's own permanent baseline for the rest of the
	-- server's life, exactly mirroring how originalCFrame below already
	-- captures GetPivot() the same way. Provably safe, not merely
	-- convenient: nothing in this codebase can touch the object before this
	-- line runs at server boot, so there is no window for a future bug to
	-- corrupt what gets captured as truth.
	local originalScale = model:GetScale()
	local highlight = model:FindFirstChildOfClass("Highlight")
	assert(highlight, "SupplyObject requires a pre-placed Highlight on " .. model:GetFullName())
	highlight.Enabled = false

	assert(deps.bank, "SupplyObject requires bank")
	assert(deps.promptTemplate, "SupplyObject requires promptTemplate")
	assert(deps.repickupPromptTemplate, "SupplyObject requires repickupPromptTemplate")
	assert(type(deps.onPickup) == "function", "SupplyObject requires onPickup")
	-- Per-location cash-out generalization (spec addendum, 2026-09-2X): a
	-- previous version read a single GLOBAL HeistConfig.SupplyCashOutAmount
	-- everywhere -- safe only because SlowFoods/Gas2Go happened to share the
	-- same value. NewsStation's ExpensiveCamera needs its own, different
	-- amount, so this is now REQUIRED per-object, same discipline as
	-- bank/promptTemplate/onPickup, not a silently-defaulted convenience.
	assert(type(deps.cashOutAmount) == "number" and deps.cashOutAmount > 0,
		"SupplyObject requires a positive cashOutAmount")

	-- Cached per-part, not assumed uniform: hiding/showing must restore each
	-- part's OWN original Transparency/CanCollide exactly, not a flat 0/true
	-- (a Union or one particular Part could legitimately differ).
	local cachedParts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			cachedParts[d] = { transparency = d.Transparency, canCollide = d.CanCollide }
		end
	end

	-- Rigid weld (spec addendum, 2026-09-20): confirmed live these models are
	-- loose, individually-Anchored sibling Part/UnionOperation instances with
	-- zero existing joints between them (checked via GetJoints() and a
	-- Weld/WeldConstraint/Motor6D descendant scan) -- going Anchored=false on
	-- every part independently for the physics-drop below would scatter them
	-- as separate falling bodies instead of one coherent object. Welded once
	-- here, at construction, to the same attach part prompts are parented to
	-- -- a rigid assembly falls/settles as one unit, no Union needed.
	for otherPart in pairs(cachedParts) do
		if otherPart ~= part then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = otherPart
			weld.Parent = part
		end
	end

	-- Despawn countdown (spec addendum, 2026-09-20): permanently present on
	-- the object but hidden except while dropped/unclaimed -- an ordinary
	-- world-space GUI, visible to every nearby player by default, same as
	-- every other world-space display in this project (no per-player
	-- filtering). Created once here, toggled via .Enabled, never cloned/
	-- destroyed -- same pattern as the pre-placed Highlight.
	local countdownGui = Instance.new("BillboardGui")
	countdownGui.Name = "SupplyCountdownGui"
	countdownGui.Size = UDim2.new(4, 0, 1.5, 0)
	countdownGui.StudsOffset = Vector3.new(0, 2, 0)
	countdownGui.AlwaysOnTop = true
	countdownGui.Enabled = false
	countdownGui.Parent = part
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(1, 0, 1, 0)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.TextScaled = true
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.TextColor3 = Color3.new(1, 1, 1)
	countdownLabel.TextStrokeTransparency = 0.4
	countdownLabel.Text = ""
	countdownLabel.Parent = countdownGui

	local self = setmetatable({
		model = model,
		part = part,
		highlight = highlight,
		bank = deps.bank,
		promptTemplate = deps.promptTemplate,
		repickupPromptTemplate = deps.repickupPromptTemplate,
		onPickup = deps.onPickup,
		onRefused = deps.onRefused or function() end,
		isBlocked = deps.isBlocked or function() return false end,
		-- Mutual exclusivity with an active duffel bag (spec addendum,
		-- 2026-09-2X): a player already holding loot from THIS SAME location's
		-- own robbery cannot also pick up supplies -- checked against that
		-- location's own bank:GetDuffel(player) > 0, the identical value each
		-- location's own pushDuffel already computes every heartbeat to drive
		-- the DuffelBag GUI/accessory. Scope limit: this does NOT catch a
		-- player carrying a BANK duffel walking over to grab Gas2Go/SlowFoods
		-- supplies -- there is no existing cross-location duffel signal in
		-- this codebase, and building one is a bigger addition than asked for
		-- here. Defaults to a no-op so this stays additive.
		hasDuffel = deps.hasDuffel or function() return false end,
		despawnTime = deps.despawnTime or HeistConfig.SupplyDespawnTime,
		-- This specific object's own redemption amount at the Illegal Supplier
		-- (see CarryState:Consume's own second return value, and SuppliesServer's
		-- redemption handler, which reads THIS instead of a flat global constant).
		cashOutAmount = deps.cashOutAmount,
		bankOnly = deps.bankOnly,
		speedCap = deps.speedCap,
		startHidden = deps.startHidden == true,
		enforceHold = deps.enforceHold == true,
		clock = deps.clock or os.clock,
		_holdBegan = {},
		_holdDuration = 0,
		countdownGui = countdownGui,
		countdownLabel = countdownLabel,
		-- Captured once, at construction, at the model's real placed position --
		-- the one truth OnSessionStart always resets back to, regardless of
		-- anything that happened to it mid-session (carried off, dropped
		-- elsewhere, despawned).
		originalCFrame = model:GetPivot(),
		-- This object's own authored baseline scale (see the comment above,
		-- where it's captured) -- every ScaleTo(...) reset in this module
		-- targets THIS, never a hardcoded 1.
		originalScale = originalScale,
		cachedParts = cachedParts,
		_prompt = nil,
		_conn = nil,
		_visible = true,
		-- startHidden only: true from OnSessionStart until GiveTo succeeds (or Close / Seal).
		_givable = false,
		-- Invalidates any in-flight despawn timer whose closure captured an
		-- older generation -- incremented on every state transition (pickup,
		-- drop, reset, seal) so a stale task.delay callback from a superseded
		-- drop can never hide a since-repositioned object.
		_despawnGen = 0,
		_implosionTween = nil,
		_implosionScaleValue = nil,
		_implosionConn = nil,
	}, SupplyObject)
	-- Heist layers 2026-11-17 (Task 6): a startHidden object is hidden from boot too, not only
	-- from its first OnSessionStart (the parts' authored look is already cached above).
	if self.startHidden then self:_setVisible(false) end
	return self
end

function SupplyObject:_teardownPrompt()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._prompt then
		self._prompt:Destroy()
		self._prompt = nil
	end
end

-- Hides/reveals the WHOLE model by toggling every cached part's own
-- Transparency/CanCollide -- there is no single-property "invisible" switch
-- for a multi-part, no-PrimaryPart model like RobbableObject/Safe's own
-- PivotTo-based bounce works around the same absence.
function SupplyObject:_setVisible(visible: boolean)
	self._visible = visible
	for part, cache in pairs(self.cachedParts) do
		part.Transparency = visible and cache.transparency or 1
		part.CanCollide = visible and cache.canCollide or false
	end
end

-- Physics-drop (spec addendum, 2026-09-20): active while dropped/unclaimed
-- -- unanchored, collidable, pushable, and deliberately left that way for
-- as long as it sits there (unlike the NPC-ragdoll-then-anchor performance
-- pattern elsewhere in this codebase; a handful of simultaneously-dropped
-- supply objects staying physics-active is an accepted trade-off, not an
-- oversight, since this one still needs to be pushable and re-promptable).
-- Deliberately does not touch CanCollide when deactivating -- _setVisible
-- already owns CanCollide for the idle/hidden states, called alongside
-- this everywhere, and must not be fought over which one wins.
function SupplyObject:_setPhysicsActive(active: boolean)
	for part in pairs(self.cachedParts) do
		part.Anchored = not active
	end
	if active then
		for part in pairs(self.cachedParts) do
			part.CanCollide = true
		end
	end
end

function SupplyObject:_playImplosion(onDone: () -> ())
	local model = self.model
	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = 1
	local conn
	conn = scaleValue:GetPropertyChangedSignal("Value"):Connect(function()
		pcall(function() model:ScaleTo(scaleValue.Value) end)
	end)
	self._implosionScaleValue = scaleValue
	self._implosionConn = conn

	local tween = TweenService:Create(scaleValue, IMPLOSION_INFO, { Value = IMPLOSION_END_SCALE })
	tween.Completed:Connect(function()
		conn:Disconnect()
		scaleValue:Destroy()
		self._implosionTween = nil
		self._implosionScaleValue = nil
		self._implosionConn = nil
		-- Reset to THIS object's own authored baseline, not a hardcoded 1 --
		-- the object must be back at its real resting scale before its NEXT
		-- reveal (a future DropAt or OnSessionStart), same "exact restore, no
		-- drift" discipline as RobbableObject's own bounce tween resetting to
		-- restCFrame on Completed. Already invisible by the time onDone() below
		-- hides it, so this jump is unnoticed.
		pcall(function() model:ScaleTo(self.originalScale) end)
		onDone()
	end)
	self._implosionTween = tween
	tween:Play()
end

-- Defensive cleanup for Seal/OnSessionStart, same discipline as Safe/
-- RobbableObject's own Seal manually reapplying final state after a
-- cancelled tween -- Tween:Cancel() does NOT synchronously fire Completed
-- (established this session), so this can't be left to the tween's own
-- callback the way the normal-completion path is.
function SupplyObject:_cancelImplosion()
	if not self._implosionTween then return end
	pcall(function() self._implosionTween:Cancel() end)
	self._implosionTween = nil
	if self._implosionConn then
		self._implosionConn:Disconnect()
		self._implosionConn = nil
	end
	if self._implosionScaleValue then
		self._implosionScaleValue:Destroy()
		self._implosionScaleValue = nil
	end
	pcall(function() self.model:ScaleTo(self.originalScale) end)
end

function SupplyObject:_arm(template: ProximityPrompt)
	self:_teardownPrompt()
	local prompt = template:Clone()
	prompt.Parent = self.part
	self._prompt = prompt
	self._holdDuration = prompt.HoldDuration
	table.clear(self._holdBegan)
	self._conn = prompt.Triggered:Connect(function(player)
		self:_onPromptTriggered(player)
	end)
	if self.enforceHold then
		-- Destroyed with the prompt, so no connection to keep.
		prompt.PromptButtonHoldBegan:Connect(function(player) self:_onHoldBegan(player) end)
	end
	self.highlight.Enabled = true
end

function SupplyObject:_onHoldBegan(player)
	self._holdBegan[player] = self.clock()
end

function SupplyObject:_onPromptTriggered(player)
	if self.enforceHold and self._holdDuration > 0 then
		local began = self._holdBegan[player]
		self._holdBegan[player] = nil
		if not began or self.clock() - began < self._holdDuration - HOLD_TOLERANCE then return end
	end
	self:_onTriggered(player)
end

function SupplyObject:_onTriggered(player)
	-- Race guard: a network delay could let a Triggered fire right after
	-- another player's hold (or a despawn) already hid this exact object.
	if not self._visible then return end
	-- Task 4: nor after Close (or any teardown) took the prompt away.
	if not self._prompt then return end
	self:_take(player)
end

-- The pickup itself, shared by a prompt trigger and GiveTo. Returns whether onPickup ran.
function SupplyObject:_take(player): boolean
	if self.isBlocked(player) then
		local ok, err = pcall(self.onRefused, player, "carrying_supplies")
		if not ok then warn("[SupplyObject] onRefused failed: " .. tostring(err)) end
		return false
	end
	if self.hasDuffel(player) then
		local ok, err = pcall(self.onRefused, player, "has_duffel")
		if not ok then warn("[SupplyObject] onRefused failed: " .. tostring(err)) end
		return false
	end
	self._despawnGen += 1
	self:_teardownPrompt()
	self.highlight.Enabled = false
	self:_setVisible(false)
	-- Re-picked-up mid-drop: countdown/physics must vanish/re-anchor
	-- immediately, not wait for DropAt's own tick loop to next notice the
	-- bumped generation (up to a full second later).
	self:_setPhysicsActive(false)
	self.countdownGui.Enabled = false

	-- Pre-placed static instance, same pattern as RegisterRobSound/ATMRobSound
	-- elsewhere in this codebase -- plays on EVERY successful pickup, both
	-- the original in-place steal and a dropped-object re-pickup, since both
	-- routes funnel through this one success path.
	local pickupSound = self.part:FindFirstChild("SupplyPickupSound")
	if pickupSound then
		local sok, serr = pcall(function() pickupSound:Play() end)
		if not sok then warn("[SupplyObject] SupplyPickupSound failed: " .. tostring(serr)) end
	end

	local ok, err = pcall(self.onPickup, player, self)
	if not ok then warn("[SupplyObject] onPickup failed: " .. tostring(err)) end
	return true
end

-- Heist layers 2026-11-17: hand a startHidden object straight to a player (a layer's own
-- trigger, not a prompt). Same path as a prompt trigger, isBlocked/hasDuffel included. Refused
-- unless the object is hidden and still available this session; once given it is not again
-- until the next OnSessionStart (a dropped one is re-picked through its own prompt).
function SupplyObject:GiveTo(player): boolean
	if self._visible or not self._givable then return false end
	if not self:_take(player) then return false end
	self._givable = false
	return true
end

-- Heist layers 2026-11-17: disarm the steal prompt and highlight (and GiveTo) until the next
-- OnSessionStart. Leaves the model where and as it is.
function SupplyObject:Close()
	self._givable = false
	self:_teardownPrompt()
	self.highlight.Enabled = false
end

-- Voluntary Drop (GUI button) or death-while-carrying: reappears at an
-- arbitrary world CFrame, fully promptable again, with a despawn timer that
-- hides it again if nobody re-triggers it in time (spec: a fixed window,
-- then it silently disappears for the rest of the session).
-- Ticks once per second, doubling as both the countdown display's data
-- source AND the real despawn timer (spec: never two separately-run
-- clocks that could drift -- one shared counter drives both). Physics-
-- active for the whole window: the object falls under gravity from
-- wherever `cframe` places it and settles naturally, staying pushable/
-- collidable until either re-picked-up or the countdown reaches 0.
function SupplyObject:DropAt(cframe: CFrame)
	self._despawnGen += 1
	local myGen = self._despawnGen
	self.model:PivotTo(cframe)
	self:_setVisible(true)
	self:_setPhysicsActive(true)
	self:_arm(self.repickupPromptTemplate)

	-- Pre-placed static instance, parented to the same attach part the
	-- model itself moves/falls with -- plays audibly from wherever the drop
	-- actually lands, covering both the voluntary Drop button and death-
	-- while-carrying (both already funnel through this one call site).
	local dropSound = self.part:FindFirstChild("SupplyDropSound")
	if dropSound then
		local sok, serr = pcall(function() dropSound:Play() end)
		if not sok then warn("[SupplyObject] SupplyDropSound failed: " .. tostring(serr)) end
	end

	local remaining = self.despawnTime
	self.countdownLabel.Text = string.format("%ds", math.ceil(remaining))
	self.countdownGui.Enabled = true

	task.spawn(function()
		while remaining > 0 do
			-- Stepped by min(1, remaining), not a flat 1s wait -- lets a
			-- test-injected fractional despawnTime (e.g. 0.05) actually expire
			-- in real time rather than being forced to wait a full second
			-- regardless; a real 20s production timer still ticks exactly
			-- once per second throughout.
			local step = math.min(1, remaining)
			task.wait(step)
			-- Re-picked-up, or superseded by a newer drop/reset -- whichever
			-- branch got there first already handled visibility/physics/
			-- prompt/countdown; this stale loop just stops silently.
			if self._despawnGen ~= myGen then return end
			remaining -= step
			self.countdownLabel.Text = string.format("%ds", math.ceil(remaining))
		end
		if self._despawnGen ~= myGen then return end
		-- Natural despawn (NOT re-pickup): collapse-inward implosion first,
		-- THEN the real hide/re-anchor -- the object stays visibly present
		-- (falling/settled) and physics-active for the duration of the
		-- implosion tween, only actually vanishing once it completes.
		-- Highlight fix (2026-09-2X): must stay Enabled for the object's ENTIRE
		-- lifetime through the implosion -- it used to be disabled right here,
		-- before the tween even started, so it visibly vanished a third of a
		-- second before the object itself did. Now it turns off in the exact
		-- same step as everything else that means "this object is gone", never
		-- separately/early.
		self:_teardownPrompt()
		self.countdownGui.Enabled = false
		self:_playImplosion(function()
			if self._despawnGen ~= myGen then return end
			self.highlight.Enabled = false
			self:_setVisible(false)
			self:_setPhysicsActive(false)
		end)
	end)
end

-- RobberyActive becomes true: always back to the ORIGINAL world position,
-- fully visible and promptable, regardless of prior-session outcome
-- (carried off, dropped elsewhere, despawned, or never touched).
function SupplyObject:OnSessionStart()
	self._despawnGen += 1
	-- Defensive, same reasoning as Safe/RobbableObject's own Seal re-applying
	-- final state after a cancelled tween: a session could start/reset while
	-- something was still mid-drop or mid-implosion.
	self:_cancelImplosion()
	self.model:PivotTo(self.originalCFrame)
	self:_setPhysicsActive(false)
	self.countdownGui.Enabled = false
	if self.startHidden then
		self:_teardownPrompt()
		self.highlight.Enabled = false
		self:_setVisible(false)
		self._givable = true
		return
	end
	self:_setVisible(true)
	self:_arm(self.promptTemplate)
end

function SupplyObject:Seal()
	self._despawnGen += 1
	self._givable = false
	self:_teardownPrompt()
	self.highlight.Enabled = false
	self:_cancelImplosion()
	self:_setVisible(false)
	self:_setPhysicsActive(false)
	self.countdownGui.Enabled = false
end

function SupplyObject:Destroy()
	self:_teardownPrompt()
end

return SupplyObject
