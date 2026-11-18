--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LockedDoor = {}
LockedDoor.__index = LockedDoor

-- LockedDoor lockpicking minigame (spec addendum, 2026-09-2X): one persistent,
-- non-consumable door per location (SlowFoods, Gas2Go), independent state
-- each -- built directly (not on RobbableObject/Safe): there is no Robbed/
-- grant concept here at all, just a one-time-per-session isOpen gate behind
-- a server-authoritative timing puzzle.
--
-- Rotary needle (spec addendum, 2026-09-2X): FULLY REPLACES the earlier
-- sequential-pin/line system (PIN_COUNT, PIN_SIZE_FRACTIONS, full-restart-
-- on-miss, the 2s "LockPick Fail" lockout). A needle rotates continuously
-- around a ring at a constant angular speed. The player clicks to catch it
-- inside a randomly-positioned, progressively-narrowing "success zone" arc.
--
-- Needle-reset-on-miss (spec correction, 2026-09-2X): supersedes the
-- original "the needle keeps spinning uninterrupted, no pause, no reset"
-- rule -- that turned out to only ever be true for HITS. A miss now
-- explicitly resets attempt.startTime to the moment of the miss (angle
-- snaps to 0, rotation resumes normally from there) -- a deliberate
-- anti-spam-click measure: without this, mashing clicks at arbitrary
-- needle positions would still have a reasonable chance of eventually
-- landing inside a stationary zone from repetition alone. A hit still
-- never touches startTime, so the needle truly never pauses/resets across
-- a run of successes.

local PROMPT_ACTION_TEXT = "Pick Lock"
local PROMPT_OBJECT_TEXT = "Locked Door"
local PROMPT_HOLD_DURATION = 1

-- Exact per-location open CFrames (spec addendum, 2026-09-2X): replaces the
-- earlier guessed hinge-offset rotation entirely -- the project owner has
-- since supplied the EXACT closed/open Position+Orientation for both real
-- doors. openCFrame is now a REQUIRED caller-supplied dep (see .new() below)
-- rather than anything computed in here; each location's own server script
-- builds its own exact literal CFrame.new(position) * CFrame.Angles(...)
-- and passes it in, so there is no shared/computed value either location
-- could accidentally cross-wire with the other's.
local OPEN_TWEEN_DURATION = 2

-- Same technique as VaultDoor's own tweenModel helper (a CFrameValue drives
-- the actual move via its own PropertyChangedSignal, Completed cleans up) --
-- but via PivotTo/GetPivot rather than VaultDoor's legacy SetPrimaryPartCFrame/
-- GetPrimaryPartCFrame, matching every OTHER component built this session
-- (RobbableObject, Safe, SupplyObject all use PivotTo/GetPivot).
local function tweenModel(model: Model, cframe: CFrame, duration: number): Tween
	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Value = model:GetPivot()
	local conn
	conn = cframeValue:GetPropertyChangedSignal("Value"):Connect(function()
		model:PivotTo(cframeValue.Value)
	end)
	local tween = TweenService:Create(
		cframeValue,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = cframe })
	tween.Completed:Connect(function()
		conn:Disconnect()
		cframeValue:Destroy()
	end)
	tween:Play()
	return tween
end

-- Identical closest-to-pivot algorithm to RobbableObject/Safe/SupplyObject --
-- these models have no PrimaryPart and no distinctly-named main part.
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
	assert(best, "LockedDoor requires at least one BasePart descendant")
	return best
end

-- Pure puzzle math, deliberately free of any Instance/state -- easy to unit
-- test and to reason about independently of the networking/lifecycle glue
-- around it.
local NEEDLE_ANGULAR_SPEED = math.rad(120) -- rad/sec -- a ~3s full rotation. PLACEHOLDER: needs visual tuning once someone can see it move (screen capture unavailable this session) -- getting the MECHANISM right (constant, server-authoritative, click-validated) is this addition's success criterion, not this exact value.
local PROGRESS_STEP = 0.25 -- +/- per click outcome; 4 net hits with zero misses solves it (4 * 0.25 = 1.0), confirmed explicitly by the project owner
-- Indexed by widthLevel (1-based). PLACEHOLDER progression (widest first
-- hit, narrowest by the 4th) -- exact values not specified, flagged clearly
-- for a visual tuning pass. Clamped to the last entry beyond this table's
-- length: a player CAN accumulate more than 4 successive hits in one
-- attempt if they also miss along the way (misses don't undo widthLevel),
-- so this must never index out of bounds.
local ZONE_WIDTHS = { math.rad(60), math.rad(45), math.rad(32), math.rad(22) }
-- Lag compensation (carried forward unchanged from the prior pin system,
-- same justification): the SERVER evaluates the needle's angle at the
-- moment it RECEIVES the stop-request over the network, not the moment the
-- player actually clicked -- a real, structural gap. The client sends its
-- OWN locally-read workspace:GetServerTimeNow() alongside its stop request;
-- the server does NOT trust this as an angle or a success claim -- it only
-- uses it as WHEN to evaluate its own, still fully server-computed formula,
-- clamped to this small, sane recent window so a modified client can't
-- claim an arbitrarily-favorable moment in the past. The 1 s window is
-- proportionate for the base doors, which gate only map access (spec: "no
-- additional reward... just access"). Doors that pay (the Bank's deposit
-- boxes since 2026-11-17) pass a narrower deps.maxLatencyCompensation
-- (final review M2, 2026-11-18): the client already knows startTime, zone
-- and speed, so the window only decides how far back a click may claim.
local MAX_LATENCY_COMPENSATION = 1
-- Final review C1 (2026-11-18): the lockpick screen stays open while the
-- player walks, so a click is judged only from a living character within the
-- prompt's MaxActivationDistance plus this many studs of the prompt part.
local REACH_ALLOWANCE = 6

-- Heist layers 2026-11-17: one live lockpick attempt per player across ALL doors. Every door
-- listens on the same shared stop/exit remotes (which carry no door id), so with several
-- doors in one place a click would otherwise be judged by every door holding an attempt.
-- player -> the door that owns that player's live attempt. Weak keys: a departed Player drops out.
local activeDoorByPlayer = setmetatable({}, { __mode = "k" })

local function zoneWidthForLevel(level: number): number
	return ZONE_WIDTHS[level] or ZONE_WIDTHS[#ZONE_WIDTHS]
end

local function needleAngle(elapsed: number): number
	return (elapsed * NEEDLE_ANGULAR_SPEED) % (2 * math.pi)
end

-- Shortest signed angular difference a-b, wrapped to (-pi, pi] -- required
-- for a correct containment check when a zone straddles the 0/2*pi boundary
-- (e.g. centerAngle near 0 or near 2*pi) -- a naive abs(a-b) comparison
-- would incorrectly fail exactly at the wrap point.
local function angleDiff(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	if d > math.pi then d -= 2 * math.pi end
	return d
end

local function withinZone(angle: number, zoneAngle: number, zoneWidth: number): boolean
	return math.abs(angleDiff(angle, zoneAngle)) <= zoneWidth / 2
end

-- Overridable so tests can drive deterministic zone placement (same
-- "optional dep, real-random default" shape as every other pluggable
-- behavior in this codebase -- deferUnlock, isBlocked, hasDuffel, measure,
-- the old generatePin this replaces).
local function defaultGenerateZoneAngle(): number
	return math.random() * 2 * math.pi
end

-- Distance from a living character's root to the prompt part; nil when dead or without a character.
local function defaultMeasure(part: BasePart)
	return function(player): number?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then return nil end
		return (root.Position - part.Position).Magnitude
	end
end

-- deps = {bank, net, location, openCFrame, now?, generateZoneAngle?, onSolved?, objectText?, canAttempt?,
-- measure?, maxLatencyCompensation?}.
-- canAttempt(player) -> boolean (heist layers Task 6): a trigger from a player it refuses starts nothing,
-- and (final review C1) a click from one it now refuses ends the attempt. measure(player) -> number?
-- (C1): distance to the prompt part, nil = dead or no character (specs inject it for string players).
-- maxLatencyCompensation (M2): the click-time window for a door that pays (default 1 s).
-- onSolved(player) (heist layers 2026-11-17) runs once at a lockpick solve, after LockpickSolved;
-- objectText overrides the prompt's "Locked Door". net is
-- required: this component owns its own full remote round-trip (open the
-- GUI, accept a stop request, push updates, announce a solve) rather than
-- routing through a caller-supplied hook, since -- unlike RobbableObject's
-- onRefused/playRobSound -- there is only ever one way any of this behaves,
-- regardless of location.
function LockedDoor.new(model: Model, deps)
	assert(model and model:IsA("Model"), "LockedDoor requires a Model")
	assert(deps.bank, "LockedDoor requires bank")
	assert(deps.net, "LockedDoor requires net")
	assert(deps.openCFrame, "LockedDoor requires openCFrame")
	assert(deps.location, "LockedDoor requires location")

	local part = findAttachPart(model)
	-- Unconditional, matching the lesson already learned twice this session
	-- (SupplyObject's live-physics GetPivot() bug): always give a bind-once
	-- world component a real PrimaryPart so GetPivot()/PivotTo() behave
	-- predictably, even though this component never goes physics-active.
	model.PrimaryPart = part

	-- Spec correction, 2026-09-2X: the ProximityPrompt is parented
	-- specifically to this named part, not to whatever findAttachPart's
	-- closest-to-pivot heuristic happens to pick -- the project owner has
	-- manually placed a part named exactly "ProximityPart Handle" inside
	-- BOTH real LockedDoor models (confirmed live) for this express
	-- purpose. PrimaryPart/pivot/closedCFrame above are UNCHANGED by this
	-- -- purely about where the prompt itself lives.
	local promptPart = model:FindFirstChild("ProximityPart Handle")
	assert(promptPart and promptPart:IsA("BasePart"), "LockedDoor requires a BasePart named 'ProximityPart Handle'")

	-- Captured once, at construction, from whatever is live in Studio right
	-- now -- same "respect the authored state as truth" principle already
	-- re-confirmed this session for SupplyObject's own scale-baseline fix.
	-- Never hardcoded.
	local closedCFrame = model:GetPivot()
	local openCFrame = deps.openCFrame

	-- Real, permanent instance -- unlike every cloned-per-session prompt
	-- elsewhere in this codebase, this one is never destroyed/recreated (spec:
	-- "persistent, non-consumable fixture"), just toggled .Enabled in sync
	-- with RobberyActive.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockedDoorPrompt"
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = deps.objectText or PROMPT_OBJECT_TEXT
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.Enabled = false
	prompt.Parent = promptPart

	local self = setmetatable({
		model = model,
		part = part,
		prompt = prompt,
		bank = deps.bank,
		net = deps.net,
		location = deps.location,
		now = deps.now or function() return workspace:GetServerTimeNow() end,
		generateZoneAngle = deps.generateZoneAngle or defaultGenerateZoneAngle,
		onSolved = deps.onSolved,
		canAttempt = deps.canAttempt,
		measure = deps.measure or defaultMeasure(promptPart),
		maxLatencyCompensation = deps.maxLatencyCompensation or MAX_LATENCY_COMPENSATION,
		closedCFrame = closedCFrame,
		openCFrame = openCFrame,
		isOpen = false,
		_activeTween = nil,
		_attempts = {}, -- player -> {progress, widthLevel, zoneAngle, zoneWidth, startTime}
		_conn = nil,
		_leaveConn = nil :: RBXScriptConnection?,
	}, LockedDoor)

	self._conn = prompt.Triggered:Connect(function(player)
		self:_onTriggered(player)
	end)
	-- Wired here, once, at construction -- self-contained, matching every
	-- other component's own event wiring in this codebase. Each location
	-- constructs its own LockedDoor from its own server script and each
	-- calls Net.setup() independently already -- this adds one more
	-- OnServerEvent listener to the SAME shared remote per location, which
	-- is safe: _onStopRequested no-ops for any player who isn't in THIS
	-- door's own _attempts table, so a SlowFoods player's stop request
	-- harmlessly reaches Gas2Go's LockedDoor too and is ignored there.
	self.net:OnLockpickStopRequested(function(player, clientClickTime)
		self:_onStopRequested(player, clientClickTime)
	end)
	-- Exit/bail-out: a clean, no-penalty abandon -- clears server-side
	-- attempt state only. The prompt's own Enabled state is never touched
	-- by opening/exiting a puzzle (only OnSessionStart/Seal/a full solve
	-- ever change it), so there is nothing to re-enable here.
	self.net:OnLockpickExitRequested(function(player)
		self:_onExitRequested(player)
	end)
	-- Final review M4 (2026-11-18): a leaver's attempt goes with them.
	self._leaveConn = Players.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)

	return self
end

-- A player's attempt on this door ends now (leave, or a caller's own cleanup).
function LockedDoor:Forget(player)
	self:_dropAttempt(player)
end

-- Final review C1 (2026-11-18): may this player's click still be judged here?
function LockedDoor:_canStillPick(player): boolean
	if self.canAttempt and not self.canAttempt(player) then return false end
	local distance = self.measure(player)
	return type(distance) == "number" and distance <= self.prompt.MaxActivationDistance + REACH_ALLOWANCE
end

-- Drops this door's attempt for `player` and, if this door owned the player's live attempt,
-- the cross-door ownership entry too.
function LockedDoor:_dropAttempt(player)
	self._attempts[player] = nil
	if activeDoorByPlayer[player] == self then
		activeDoorByPlayer[player] = nil
	end
end

-- Every attempt on this door ends at once (session start, seal).
function LockedDoor:_dropAllAttempts()
	self._attempts = {}
	for player, door in pairs(activeDoorByPlayer) do
		if door == self then
			activeDoorByPlayer[player] = nil
		end
	end
end

function LockedDoor:_onExitRequested(player)
	if activeDoorByPlayer[player] ~= self then return end
	self:_dropAttempt(player)
end

function LockedDoor:_cancelTween()
	if self._activeTween then
		pcall(function() self._activeTween:Cancel() end)
		self._activeTween = nil
	end
end

-- Holding the prompt starts (or restarts) a FRESH attempt for this player,
-- at 0% progress -- there is no partial-progress persistence across
-- separate prompt holds, by design: an abandoned/incomplete attempt is
-- simply overwritten by the next trigger, never resumed.
function LockedDoor:_onTriggered(player)
	-- Defense-in-depth, same discipline as every other prompt in this
	-- codebase: the prompt SHOULD already be disabled in both cases, but
	-- never trust prompt-existence/enabled-state alone.
	if self.isOpen then return end
	if self.bank:GetState() ~= "Active" then return end
	if self.canAttempt and not self.canAttempt(player) then return end

	-- Already mid-puzzle: ignore. The GUI is modal but the world is not, so the
	-- player can walk back into the prompt's radius and re-trigger it with the
	-- lockpick still on screen -- which would silently reset their progress to 0
	-- and re-randomise the zone under them. This does NOT change the documented
	-- "a new hold starts a fresh attempt, never resumes" rule above: backing out
	-- with the X clears _attempts via _onExitRequested, so the next hold still
	-- starts clean.
	if self._attempts[player] then return end

	-- One live attempt per player: a trigger here silently drops the player's attempt on any
	-- other door (the client only ever shows the latest lockpick GUI anyway).
	local previous = activeDoorByPlayer[player]
	if previous and previous ~= self then
		previous._attempts[player] = nil
	end
	activeDoorByPlayer[player] = self

	local zoneAngle = self.generateZoneAngle()
	local zoneWidth = zoneWidthForLevel(1)
	local attempt = {
		progress = 0,
		widthLevel = 1,
		zoneAngle = zoneAngle,
		zoneWidth = zoneWidth,
		startTime = self.now(),
	}
	self._attempts[player] = attempt
	-- Final review C1 (2026-11-18): the client closes its lockpick at death without telling the server, so
	-- the server drops the attempt itself. The connection goes with the humanoid.
	local character = type(player) ~= "string" and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			if self._attempts[player] == attempt then self:_dropAttempt(player) end
		end)
	end
	self.net:OpenLockpickGui(player, {
		location = self.location,
		progress = 0,
		zoneAngle = zoneAngle,
		zoneWidth = zoneWidth,
		angularSpeed = NEEDLE_ANGULAR_SPEED,
		startTime = self._attempts[player].startTime,
	})
end

-- Server-authoritative click check (spec: "the server validates the
-- needle's live computed angle against the live success-zone bounds at
-- that exact moment -- the client never determines success/fail on its
-- own"). clientClickTime is OPTIONAL and never trusted as an angle/success
-- claim -- see MAX_LATENCY_COMPENSATION's own comment for the full
-- reasoning.
function LockedDoor:_onStopRequested(player, clientClickTime: number?)
	if activeDoorByPlayer[player] ~= self then return end -- only the door owning the live attempt judges a click
	local attempt = self._attempts[player]
	if not attempt then return end -- stale/no-op: no in-flight attempt for this player at THIS door

	-- Final review C1 (2026-11-18): walked away, died, or no longer allowed (left the roster, picked up a
	-- carry): the attempt ends and the lockpick screen closes, judged nothing.
	if not self:_canStillPick(player) then
		self:_dropAttempt(player)
		self.net:LockpickSolved(player) -- closes the client's lockpick screen
		return
	end

	if self.isOpen then
		-- Someone else solved it while this player was still mid-puzzle.
		self:_dropAttempt(player)
		self.net:LockpickSolved(player)
		return
	end

	local serverNow = self.now()
	local evalTime = serverNow
	if type(clientClickTime) == "number" then
		evalTime = math.clamp(clientClickTime, serverNow - self.maxLatencyCompensation, serverNow)
	end
	local angle = needleAngle(evalTime - attempt.startTime)

	if withinZone(angle, attempt.zoneAngle, attempt.zoneWidth) then
		attempt.progress = math.min(1, attempt.progress + PROGRESS_STEP)
		if attempt.progress >= 1 then
			self:_dropAttempt(player)
			self:_open()
			self.net:LockpickSolved(player)
			if self.onSolved then
				local ok, err = pcall(self.onSolved, player)
				if not ok then warn("[LockedDoor] onSolved failed: " .. tostring(err)) end
			end
			return
		end
		-- Hit: re-randomize position AND shrink width for the next round --
		-- confirmed explicitly, this only ever happens on a hit. widthLevel
		-- ratchets monotonically -- it only ever increases here, is NEVER
		-- decremented on a miss below, and is looked up fresh every time
		-- (never cached), so a hit-miss-hit-miss-hit sequence still reaches
		-- widthLevel 3 by the third hit even though progress oscillates and
		-- never climbs past one PROGRESS_STEP.
		attempt.widthLevel += 1
		attempt.zoneAngle = self.generateZoneAngle()
		attempt.zoneWidth = zoneWidthForLevel(attempt.widthLevel)
		self.net:LockpickUpdate(player, {
			location = self.location,
			outcome = "hit",
			progress = attempt.progress,
			zoneAngle = attempt.zoneAngle,
			zoneWidth = attempt.zoneWidth,
			angularSpeed = NEEDLE_ANGULAR_SPEED,
			startTime = attempt.startTime,
		})
	else
		-- Miss: progress down (clamped at 0), zone COMPLETELY UNTOUCHED (same
		-- angle, same width, same widthLevel) -- confirmed explicitly: "the
		-- zone stays exactly where it was" on a miss.
		--
		-- Needle reset (spec correction, 2026-09-2X): startTime resets to
		-- serverNow (not evalTime -- the reset itself is anchored to "the
		-- server is processing this miss right now", independent of the
		-- click-latency-compensation nuance used only for the hit/miss
		-- determination above), making elapsed 0 and angle 0 at this exact
		-- instant -- rotation then resumes normally, unmodified, until the
		-- next hit/miss. No client-side needle-reset code is needed at all:
		-- the render loop already recomputes angle from startTime every
		-- frame, so simply replicating this new startTime is sufficient.
		attempt.progress = math.max(0, attempt.progress - PROGRESS_STEP)
		attempt.startTime = serverNow
		self.net:LockpickUpdate(player, {
			location = self.location,
			outcome = "miss",
			progress = attempt.progress,
			zoneAngle = attempt.zoneAngle,
			zoneWidth = attempt.zoneWidth,
			angularSpeed = NEEDLE_ANGULAR_SPEED,
			startTime = attempt.startTime,
		})
	end
end

-- The open itself, shared by a lockpick solve and Open().
function LockedDoor:_open()
	self.isOpen = true
	self.prompt.Enabled = false
	self:_cancelTween()
	-- Positional, pre-placed on the door's own attach part (spec
	-- addendum, 2026-09-2X) -- simulates the physical sound of the
	-- door opening, audible to nearby players, synced to the exact
	-- moment the tween itself starts (not the GUI-close moment).
	local doorOpenSound = self.part:FindFirstChild("LockpickDoorOpenSound")
	if doorOpenSound then
		local sok, serr = pcall(function() doorOpenSound:Play() end)
		if not sok then warn("[LockedDoor] LockpickDoorOpenSound failed: " .. tostring(serr)) end
	end
	self._activeTween = tweenModel(self.model, self.openCFrame, OPEN_TWEEN_DURATION)
end

-- Heist layers 2026-11-17: open at once (e.g. a key), same tween/sound/prompt-off as a solve,
-- without onSolved. `player` is for the caller's symmetry/logging only: the caller gates who
-- may open. Anyone still mid-puzzle here gets the "already solved" close on their next click.
function LockedDoor:Open(_player): boolean
	if self.isOpen or self.bank:GetState() ~= "Active" then return false end
	self:_open()
	return true
end

-- RobberyActive becomes true: always back to closed/armed regardless of
-- prior-session outcome (never touched, mid-attempt, or already solved).
function LockedDoor:OnSessionStart()
	self.isOpen = false
	self:_dropAllAttempts()
	self:_cancelTween()
	self.model:PivotTo(self.closedCFrame)
	self.prompt.Enabled = true
end

-- Session end: snap closed instantly, no tween -- matching VaultDoor/
-- CounterBarrier/every other instant-reset component in this codebase. No
-- player should still be mid-puzzle by the time this runs (BankInstance:_seal
-- already ejects every remaining participant in the same call).
function LockedDoor:Seal()
	self.isOpen = false
	self:_dropAllAttempts()
	self:_cancelTween()
	self.model:PivotTo(self.closedCFrame)
	self.prompt.Enabled = false
end

function LockedDoor:Destroy()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._leaveConn then
		self._leaveConn:Disconnect()
		self._leaveConn = nil
	end
	self:_dropAllAttempts() -- final review M4: no live-door entry outlives the door
	self:_cancelTween()
end

return LockedDoor
