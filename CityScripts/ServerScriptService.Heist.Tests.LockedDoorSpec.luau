local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local LockedDoor = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.LockedDoor)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("LockedDoor")

	local function activeBank(now)
		local inst = BankInstance.new({ config = Config, now = now or function() return 1000 end })
		inst:TryStart("starter")
		return inst
	end

	-- Matches the real LockedDoor models' actual shape: a flat, no-PrimaryPart
	-- assembly of several generic Parts (the real ones have 42; a handful here
	-- is enough to exercise findAttachPart/rigid-whole-model-move behavior).
	local ORIGIN = CFrame.new(10, 5, 0)
	local function tempModel()
		local model = Instance.new("Model")
		model.Name = "LockedDoor"
		for i = 1, 4 do
			local part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.Parent = model
		end
		-- Matches the real LockedDoor models' own manually-placed part (spec
		-- correction, 2026-09-2X): the ProximityPrompt is required to parent
		-- here specifically, not wherever findAttachPart's heuristic lands.
		local promptPart = Instance.new("Part")
		promptPart.Name = "ProximityPart Handle"
		promptPart.Anchored = true
		promptPart.Parent = model
		model.Parent = workspace
		model:PivotTo(ORIGIN)
		return model
	end

	-- Captures every call the door makes outward, and stores whatever callback
	-- OnLockpickStopRequested/OnLockpickExitRequested register so tests can
	-- drive input exactly the way the real remote wiring would (proving the
	-- wiring itself works, not just the underlying methods).
	local function makeNet()
		local net = {
			opened = {},
			updates = {},
			solved = {},
			_stopCallback = nil,
			_exitCallback = nil,
		}
		function net:OpenLockpickGui(player, payload)
			table.insert(self.opened, { player = player, payload = payload })
		end
		function net:OnLockpickStopRequested(callback)
			self._stopCallback = callback
		end
		function net:OnLockpickExitRequested(callback)
			self._exitCallback = callback
		end
		function net:LockpickUpdate(player, payload)
			table.insert(self.updates, { player = player, payload = payload })
		end
		function net:LockpickSolved(player)
			table.insert(self.solved, player)
		end
		return net
	end

	-- Needle angle formula: angle = (elapsed * NEEDLE_ANGULAR_SPEED) % (2*pi).
	-- With a clock that never advances between a trigger and a stop (no
	-- clientClickTime given), elapsed is always 0, so angle is always 0 --
	-- a guaranteed hit against any zone centered at 0 (any nonzero zoneWidth
	-- covers angle 0). Lets a test solve the whole puzzle deterministically
	-- with zero real waiting and no dependency on the exact angular speed.
	local function alwaysZeroAngle()
		return 0
	end

	-- A zone centered at pi (the opposite side of the ring from angle 0) --
	-- guaranteed outside tolerance regardless of zoneWidth (the widest
	-- configured zone is well under 2*pi).
	local function alwaysPiAngle()
		return math.pi
	end

	-- Distinctive, obviously-not-the-closed-position default so tests can
	-- tell "the injected openCFrame" apart from "wherever the model happens
	-- to sit" at a glance -- openCFrame is a required dep (exact per-location
	-- literals, no computed hinge math).
	local DEFAULT_OPEN_CFRAME = CFrame.new(500, 500, 500) * CFrame.Angles(0, math.rad(45), 0)

	local function newDoor(overrides)
		overrides = overrides or {}
		local model = overrides.model or tempModel()
		local net = overrides.net or makeNet()
		local door = LockedDoor.new(model, {
			bank = overrides.bank,
			net = net,
			location = overrides.location or "TestLocation",
			now = overrides.now or function() return 1000 end,
			generateZoneAngle = overrides.generateZoneAngle,
			openCFrame = overrides.openCFrame or DEFAULT_OPEN_CFRAME,
			onSolved = overrides.onSolved,
			objectText = overrides.objectText,
		})
		return door, model, net
	end

	-- Drives a stop THROUGH the same path the real remote wiring uses (proves
	-- OnLockpickStopRequested was actually registered), not door:_onStopRequested
	-- directly. clientClickTime is optional -- omitted, this matches every
	-- pre-existing call site exactly (server-receipt-time behavior).
	local function requestStop(net, player, clientClickTime)
		net._stopCallback(player, clientClickTime)
	end

	-- Same discipline for the exit remote -- proves OnLockpickExitRequested
	-- was actually registered, not door:_onExitRequested directly.
	local function requestExit(net, player)
		net._exitCallback(player)
	end

	suite:test("construction requires a Model, bank, net, openCFrame, and location", function(expect)
		local net = makeNet()
		expect.throws(function() LockedDoor.new(nil, { bank = {}, net = net }) end, "missing model")
		expect.throws(function() LockedDoor.new(tempModel(), { net = net }) end, "missing bank")
		expect.throws(function() LockedDoor.new(tempModel(), { bank = {} }) end, "missing net")
		expect.throws(function() LockedDoor.new(tempModel(), { bank = {}, net = net, location = "X" }) end, "missing openCFrame")
		expect.throws(function() LockedDoor.new(tempModel(), { bank = {}, net = net, openCFrame = DEFAULT_OPEN_CFRAME }) end, "missing location")
	end)

	suite:test("construction wires the stop/exit-request callbacks and configures the permanent prompt, disabled by default", function(expect)
		local door, model, net = newDoor({ bank = activeBank() })
		expect.truthy(net._stopCallback ~= nil, "OnLockpickStopRequested was called during construction")
		expect.truthy(net._exitCallback ~= nil, "OnLockpickExitRequested was called during construction")
		expect.equal(door.prompt.ActionText, "Pick Lock", "action text")
		expect.equal(door.prompt.ObjectText, "Locked Door", "object text")
		expect.equal(door.prompt.HoldDuration, 1, "1 second hold")
		expect.equal(door.prompt.Parent.Name, "ProximityPart Handle", "parented specifically to ProximityPart Handle, not door.part")
		expect.falsy(door.prompt.Enabled, "disabled until OnSessionStart")
		expect.falsy(door.isOpen, "starts closed")
		expect.equal(model:GetPivot().Position, ORIGIN.Position, "starts at its authored position")
		model:Destroy()
	end)

	suite:test("OnSessionStart enables the prompt and positions at closedCFrame; Seal disables it", function(expect)
		local door, model = newDoor({ bank = activeBank() })
		door:OnSessionStart()
		expect.truthy(door.prompt.Enabled, "enabled once Active")
		expect.equal(model:GetPivot().Position, door.closedCFrame.Position, "at the closed position")

		door:Seal()
		expect.falsy(door.prompt.Enabled, "disabled again once sealed")
		model:Destroy()
	end)

	suite:test("triggering while the bank is not Active is a no-op", function(expect)
		local idleBank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local door, model, net = newDoor({ bank = idleBank })
		door:_onTriggered("p1")
		expect.equal(#net.opened, 0, "no GUI opened")
		model:Destroy()
	end)

	suite:test("triggering while already open is a no-op", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		for _ = 1, 4 do requestStop(net, "p1") end
		expect.truthy(door.isOpen, "solved -- sanity check on the repro itself")

		local openedBefore = #net.opened
		door:_onTriggered("p2")
		expect.equal(#net.opened, openedBefore, "no new GUI opened for a second player once already open")
		model:Destroy()
	end)

	suite:test("a correct click increases progress by exactly 0.25, advances widthLevel, and re-randomizes+shrinks the zone for the next round", function(expect)
		local calls = 0
		local angles = { 0, 1.5 } -- call 1: initial zone (=0, guarantees the upcoming hit at angle 0); call 2: the post-hit re-randomize target
		local function gen()
			calls += 1
			return angles[calls] or 1.5
		end
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = gen })
		door:OnSessionStart()
		door:_onTriggered("p1")
		expect.equal(net.opened[1].payload.zoneAngle, 0, "opens with the first generated zone angle")
		local widthAtOpen = net.opened[1].payload.zoneWidth
		expect.equal(door._attempts["p1"].widthLevel, 1, "starts at widthLevel 1")

		requestStop(net, "p1") -- angle=0 (elapsed 0), zoneAngle=0 -- guaranteed hit
		expect.equal(#net.updates, 1, "one update pushed")
		expect.equal(net.updates[1].payload.progress, 0.25, "progress advanced by exactly PROGRESS_STEP")
		expect.equal(net.updates[1].payload.outcome, "hit", "outcome tagged as hit")
		expect.equal(net.updates[1].payload.zoneAngle, 1.5, "re-randomized to the NEXT generated angle")
		expect.truthy(net.updates[1].payload.zoneWidth < widthAtOpen, "zone width shrunk for the next round")
		expect.equal(door._attempts["p1"].widthLevel, 2, "widthLevel advanced")
		expect.falsy(door.isOpen, "door still closed")
		model:Destroy()
	end)

	suite:test("a miss decreases progress by exactly 0.25, clamps at 0, and leaves zoneAngle/zoneWidth completely untouched", function(expect)
		local calls = 0
		local angles = { 0, 2.0 }
		local function gen()
			calls += 1
			return angles[calls] or 2.0
		end
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = gen })
		door:OnSessionStart()
		door:_onTriggered("p1") -- zoneAngle=0 (call 1)

		requestStop(net, "p1") -- angle=0 matches zoneAngle=0 -- HIT, progress -> 0.25, new zoneAngle=2.0 (call 2)
		expect.equal(net.updates[1].payload.progress, 0.25, "sanity check: the hit landed")
		local zoneAngleAfterHit = net.updates[1].payload.zoneAngle
		local zoneWidthAfterHit = net.updates[1].payload.zoneWidth

		requestStop(net, "p1") -- angle=0, zoneAngle=2.0 now -- a genuine miss
		expect.equal(net.updates[2].payload.progress, 0, "progress decreased back to 0")
		expect.equal(net.updates[2].payload.outcome, "miss", "outcome tagged as miss")
		expect.equal(net.updates[2].payload.zoneAngle, zoneAngleAfterHit, "zone position untouched by the miss")
		expect.equal(net.updates[2].payload.zoneWidth, zoneWidthAfterHit, "zone width untouched by the miss")

		requestStop(net, "p1") -- another miss while already at 0
		expect.equal(net.updates[3].payload.progress, 0, "clamped at 0 -- a string of misses can't push it negative")
		model:Destroy()
	end)

	suite:test("a miss resets the needle to angle 0 (startTime resets to the moment of the miss) -- spec correction superseding 'needle never resets'", function(expect)
		local t = 1000
		local now = function() return t end
		-- zoneAngle far from wherever the needle will actually be, guaranteeing
		-- every click below is a genuine miss.
		local door, model, net = newDoor({ bank = activeBank(now), now = now, generateZoneAngle = alwaysPiAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		local openStartTime = net.opened[1].payload.startTime

		-- Advance real elapsed time so the needle is well away from angle 0
		-- before the miss -- if startTime were NOT reset, the very next click
		-- at this same `t` would evaluate the SAME nonzero angle again.
		t += 1.234
		requestStop(net, "p1")
		expect.equal(net.updates[1].payload.outcome, "miss", "sanity check: this was a genuine miss")
		expect.equal(door._attempts["p1"].startTime, t, "startTime reset to the exact moment of the miss")
		expect.truthy(door._attempts["p1"].startTime ~= openStartTime, "differs from the original open-time startTime")
		expect.equal(net.updates[1].payload.startTime, t, "the reset startTime is replicated to the client")

		-- Immediately after the reset (no further time elapsed), the needle's
		-- angle is exactly 0 -- proven indirectly: a click at THIS instant
		-- against a zone now centered at 0 must hit.
		door:_onExitRequested("p1")
		local door2, model2, net2 = newDoor({ bank = activeBank(now), now = now, generateZoneAngle = alwaysZeroAngle })
		door2:OnSessionStart()
		door2:_onTriggered("p2")
		t += 5 -- move the needle well away from 0 again
		requestStop(net2, "p2") -- miss (angle != 0 after 5s elapsed) -- resets startTime to `t`
		expect.equal(net2.updates[1].payload.outcome, "miss", "sanity check: second door's first click also misses")
		requestStop(net2, "p2") -- immediately after, same `t` -- needle is back at angle 0, zone is at 0 -- must hit
		expect.equal(net2.updates[2].payload.outcome, "hit", "needle was genuinely back at angle 0 right after the reset")
		model:Destroy()
		model2:Destroy()
	end)

	suite:test("reaching 100% progress (4 consecutive hits, zero misses) opens the door to the exact openCFrame, disables the prompt, and fires LockpickSolved", function(expect)
		local customOpen = CFrame.new(77, 8, -20) * CFrame.Angles(0, math.rad(15), 0)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle, openCFrame = customOpen })
		door:OnSessionStart()
		door:_onTriggered("p1")

		for i = 1, 3 do
			requestStop(net, "p1")
			expect.falsy(door.isOpen, "still closed after hit " .. i)
		end
		requestStop(net, "p1") -- 4th hit -- progress reaches 1.0

		expect.truthy(door.isOpen, "door now open")
		expect.falsy(door.prompt.Enabled, "prompt disabled -- no further interaction needed")
		expect.equal(#net.solved, 1, "LockpickSolved fired once")
		expect.equal(net.solved[1], "p1", "for the solving player")
		-- The actual door TWEEN runs on real TweenService/engine time, fully
		-- decoupled from the injectable fake clock -- assert a tween STARTED
		-- with the right target reachable, not that it has finished.
		expect.truthy(door._activeTween ~= nil, "a tween was created")
		expect.equal(door._activeTween.PlaybackState, Enum.PlaybackState.Playing, "actively playing")
		door:Destroy()
		model:Destroy()
	end)

	suite:test("a hit-miss-hit-miss-hit sequence still reaches widthLevel 4 even though progress oscillates and never exceeds one PROGRESS_STEP (widthLevel ratchets independent of net progress)", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		expect.equal(door._attempts["p1"].widthLevel, 1, "starts at widthLevel 1")

		requestStop(net, "p1") -- HIT (angle 0 == zoneAngle 0)
		expect.equal(net.updates[1].payload.progress, 0.25, "hit 1: progress 0.25")
		expect.equal(door._attempts["p1"].widthLevel, 2, "widthLevel advanced to 2 after hit 1")

		-- Force a miss by moving the CURRENT zone far away, directly on the
		-- attempt's own state -- simplest way to inject exactly one miss amid
		-- a run of otherwise-guaranteed hits without a bespoke per-step
		-- generator. Confirmed a miss leaves this untouched anyway, so
		-- setting it here (simulating "wherever it currently is") and
		-- checking it afterward is a faithful test of that same guarantee.
		door._attempts["p1"].zoneAngle = math.pi
		requestStop(net, "p1") -- MISS
		expect.equal(net.updates[2].payload.progress, 0, "miss 1: progress back to 0")
		expect.equal(door._attempts["p1"].widthLevel, 2, "widthLevel UNCHANGED by the miss -- still 2")
		expect.equal(door._attempts["p1"].zoneAngle, math.pi, "zone position untouched by the miss")

		door._attempts["p1"].zoneAngle = 0 -- restore for the next guaranteed hit
		requestStop(net, "p1") -- HIT
		expect.equal(net.updates[3].payload.progress, 0.25, "hit 2: progress back up to 0.25 (net, not cumulative from the miss)")
		expect.equal(door._attempts["p1"].widthLevel, 3, "widthLevel advanced to 3 after hit 2 -- independent of progress oscillating")

		door._attempts["p1"].zoneAngle = math.pi
		requestStop(net, "p1") -- MISS
		expect.equal(net.updates[4].payload.progress, 0, "miss 2: progress back to 0")
		expect.equal(door._attempts["p1"].widthLevel, 3, "widthLevel still unchanged by the second miss")

		door._attempts["p1"].zoneAngle = 0
		requestStop(net, "p1") -- HIT (3rd total hit)
		expect.equal(net.updates[5].payload.progress, 0.25, "hit 3: progress 0.25 -- never exceeded one PROGRESS_STEP across this whole sequence")
		expect.equal(door._attempts["p1"].widthLevel, 4, "widthLevel reached 4 after 3 total hits, despite 2 misses and progress never climbing past 0.25")
		model:Destroy()
	end)

	suite:test("a stale/unknown player's stop request is a harmless no-op", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		-- p1 never triggered the prompt -- no attempt exists for them.
		local ok = pcall(function() requestStop(net, "p1") end)
		expect.truthy(ok, "no error")
		expect.equal(#net.updates, 0, "no update pushed")
		expect.equal(#net.solved, 0, "not solved")
		model:Destroy()
	end)

	suite:test("a stop request arriving after the door was already solved by someone else closes that player's GUI gracefully", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		door:_onTriggered("p2") -- both mid-attempt

		for _ = 1, 4 do requestStop(net, "p1") end -- p1 solves it first
		expect.truthy(door.isOpen, "solved by p1")

		local solvedBefore = #net.solved
		requestStop(net, "p2") -- p2, still mid-puzzle, tries again
		expect.equal(#net.solved, solvedBefore + 1, "p2 also gets a LockpickSolved close signal")
		expect.equal(net.solved[#net.solved], "p2", "specifically for p2")
		door:Destroy()
		model:Destroy()
	end)

	suite:test("OnSessionStart resets regardless of prior state: never touched", function(expect)
		local door, model = newDoor({ bank = activeBank() })
		door:OnSessionStart()
		expect.falsy(door.isOpen, "closed")
		expect.truthy(door.prompt.Enabled, "armed")
		expect.equal(model:GetPivot().Position, door.closedCFrame.Position, "at closed position")
		model:Destroy()
	end)

	suite:test("OnSessionStart resets regardless of prior state: mid-attempt with partial progress", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		requestStop(net, "p1") -- 1 of 4 hits landed, mid-attempt, progress 0.25

		door:OnSessionStart() -- next session
		expect.falsy(door.isOpen, "closed")
		expect.truthy(door.prompt.Enabled, "armed")
		-- The stale mid-attempt (including its partial progress) must not
		-- survive -- a stop for p1 now is a no-op.
		local updatesBefore = #net.updates
		requestStop(net, "p1")
		expect.equal(#net.updates, updatesBefore, "no update -- the old attempt was cleared")
		model:Destroy()
	end)

	suite:test("OnSessionStart resets regardless of prior state: fully solved", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		for _ = 1, 4 do requestStop(net, "p1") end
		expect.truthy(door.isOpen, "solved beforehand")

		door:OnSessionStart()
		expect.falsy(door.isOpen, "forced closed again")
		expect.truthy(door.prompt.Enabled, "re-armed")
		expect.equal(model:GetPivot().Position, door.closedCFrame.Position, "snapped back to closed")
		expect.falsy(door._activeTween, "the open tween was cancelled, not left running")
		model:Destroy()
	end)

	suite:test("Seal snaps closed instantly (no tween) and disables the prompt, regardless of prior state", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		for _ = 1, 4 do requestStop(net, "p1") end
		expect.truthy(door.isOpen, "solved beforehand")

		door:Seal()
		expect.falsy(door.isOpen, "forced closed")
		expect.falsy(door.prompt.Enabled, "disabled for the cooldown")
		expect.equal(model:GetPivot().Position, door.closedCFrame.Position, "snapped to closed, no tween")
		expect.falsy(door._activeTween, "tween reference cleared")
		model:Destroy()
	end)

	suite:test("a fresh session after Seal can be solved normally again", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		for _ = 1, 4 do requestStop(net, "p1") end
		door:Seal()

		door:OnSessionStart()
		door:_onTriggered("p2")
		for _ = 1, 4 do requestStop(net, "p2") end
		expect.truthy(door.isOpen, "opens again normally in the next session")
		door:Destroy()
		model:Destroy()
	end)

	suite:test("Destroy disconnects the prompt and cancels any in-flight tween without error", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		for _ = 1, 4 do requestStop(net, "p1") end
		local ok = pcall(function() door:Destroy() end)
		expect.truthy(ok, "no error")
		model:Destroy()
	end)

	suite:test("exiting mid-attempt clears server-side state -- a stop request afterward is a harmless no-op, and the door/prompt are untouched", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysZeroAngle })
		door:OnSessionStart()
		door:_onTriggered("p1")
		requestStop(net, "p1") -- 1 of 4 hits landed, mid-attempt

		requestExit(net, "p1")
		local updatesBefore = #net.updates
		requestStop(net, "p1") -- stale -- the attempt was cleared by the exit
		expect.equal(#net.updates, updatesBefore, "no update -- exiting cleared the in-flight attempt")
		expect.falsy(door.isOpen, "door still closed")
		expect.truthy(door.prompt.Enabled, "prompt untouched -- exiting a puzzle never disables/re-enables it")

		-- Re-triggering after an exit starts a genuinely fresh attempt (0%
		-- progress, same "no partial-progress persistence" guarantee as any
		-- other re-trigger).
		door:_onTriggered("p1")
		expect.equal(net.opened[#net.opened].payload.progress, 0, "fresh attempt starts at 0% progress")
		model:Destroy()
	end)

	suite:test("exiting with no in-flight attempt is a harmless no-op", function(expect)
		local door, model, net = newDoor({ bank = activeBank() })
		local ok = pcall(function() requestExit(net, "p1") end)
		expect.truthy(ok, "no error")
		model:Destroy()
	end)

	-- Confirms the door's open target is now an exact, caller-supplied
	-- literal, not anything computed inside this module -- combined with
	-- each location's own server script literally hardcoding its OWN
	-- distinct value (verified by direct side-by-side read, not by a
	-- shared/computed reference), this is what rules out the
	-- OpenCloseBarrier-style cross-location mixup at the unit level.
	suite:test("openCFrame is stored exactly as injected -- never recomputed from closedCFrame", function(expect)
		local customOpen = CFrame.new(42, 7, -13) * CFrame.Angles(0, math.rad(37), 0)
		local door, model = newDoor({ bank = activeBank(), openCFrame = customOpen })
		expect.equal(door.openCFrame, customOpen, "stored exactly as given, not recomputed")
		model:Destroy()
	end)

	-- Location threading: every outbound payload must carry the door's OWN
	-- location, verbatim -- this is what lets the client tell "my puzzle
	-- just ended" apart from "a DIFFERENT location's session ended while
	-- I'm still mid-puzzle here" (the real bug behind "an unrelated toast
	-- closes my lockpick GUI" -- it was never the toast, it was HeistState's
	-- own missing location filter).
	suite:test("every outbound payload (open, hit, miss) carries this door's own location", function(expect)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = alwaysPiAngle, location = "Gas2Go" })
		door:OnSessionStart()
		door:_onTriggered("p1")
		expect.equal(net.opened[1].payload.location, "Gas2Go", "OpenLockpickGui carries the door's location")

		requestStop(net, "p1") -- guaranteed miss (angle 0 vs zoneAngle pi)
		expect.equal(net.updates[1].payload.location, "Gas2Go", "the miss LockpickUpdate carries it too")
		model:Destroy()
	end)

	-- Lag-compensation abuse guard: a claim beyond MAX_LATENCY_COMPENSATION
	-- (1s) must NOT be honored literally -- it gets clamped to exactly
	-- serverNow - 1. NEEDLE_ANGULAR_SPEED is a fixed module constant (120
	-- deg/s, a 3s period) -- crafted so the CLAMPED evaluation moment
	-- (elapsed=-1, angle=240deg) and the LITERAL unclamped moment
	-- (elapsed=-2.5, angle=60deg) land at genuinely different angles, not a
	-- coincidental period-aligned match (naive round numbers like -10 or -7
	-- happen to land on the exact same angle as -1 here, since they differ
	-- by whole multiples of the 3s period -- -2.5 does not).
	suite:test("an implausible clientClickTime claim (2.5s in the past, beyond the 1s clamp) is clamped, not honored literally", function(expect)
		local zoneAngle = math.rad(240)
		local door, model, net = newDoor({ bank = activeBank(), generateZoneAngle = function() return zoneAngle end })
		door:OnSessionStart()
		door:_onTriggered("p1")
		door._attempts["p1"].zoneWidth = math.rad(30) -- tolerance +/-15deg

		requestStop(net, "p1", 997.5) -- claims serverNow(1000) - 2.5
		expect.equal(net.updates[1].payload.outcome, "hit",
			"clamped correctly to elapsed=-1 (angle 240deg, inside the zone) -- an unclamped -2.5s claim would have landed at 60deg and missed instead")
		model:Destroy()
	end)

	-- Lag-compensation feature actually working: a plausible, small claim
	-- (0.2s ago -- well within a real round trip) can flip a would-be miss
	-- into a genuine hit, proportional to how far the needle has moved
	-- since the click.
	suite:test("a plausible small clientClickTime claim (0.2s ago) can turn a server-receipt-time miss into a hit", function(expect)
		local zoneAngle = math.rad(336)
		local zoneWidth = math.rad(20) -- tolerance +/-10deg

		-- Baseline: no clientClickTime -- evaluated at serverNow (elapsed=0,
		-- angle=0deg), a genuine miss against a zone centered at 336deg.
		local door1, model1, net1 = newDoor({ bank = activeBank(), generateZoneAngle = function() return zoneAngle end })
		door1:OnSessionStart()
		door1:_onTriggered("p1")
		door1._attempts["p1"].zoneWidth = zoneWidth
		requestStop(net1, "p1")
		expect.equal(net1.updates[1].payload.outcome, "miss", "no compensation: genuinely misses at serverNow (angle 0deg vs zone centered at 336deg)")
		model1:Destroy()

		-- Same exact scenario, but this stop claims a plausible 0.2s-ago
		-- click (elapsed=-0.2, angle=336deg -- dead center of the same zone).
		local door2, model2, net2 = newDoor({ bank = activeBank(), generateZoneAngle = function() return zoneAngle end })
		door2:OnSessionStart()
		door2:_onTriggered("p1")
		door2._attempts["p1"].zoneWidth = zoneWidth
		requestStop(net2, "p1", 999.8) -- claims serverNow(1000) - 0.2 -- within the sane window, honored
		expect.equal(net2.updates[1].payload.outcome, "hit", "with plausible compensation: the SAME scenario now hits")
		model2:Destroy()
	end)

	-- Heist layers 2026-11-17 (Task 2): onSolved, objectText, Open, one live attempt per player.
	suite:test("onSolved runs exactly once with the solver after the 4th hit, after LockpickSolved; objectText sets the prompt", function(expect)
		local calls = {}
		local net = makeNet()
		local door, model = newDoor({ bank = activeBank(), net = net, generateZoneAngle = alwaysZeroAngle, objectText = "Deposit Box",
			onSolved = function(player) table.insert(calls, { player = player, solvedSent = #net.solved }) end })
		expect.equal(door.prompt.ObjectText, "Deposit Box", "objectText overrides the prompt")
		door:OnSessionStart()
		door:_onTriggered("p1")
		for _ = 1, 3 do requestStop(net, "p1") end
		expect.equal(#calls, 0, "not before the solve")
		requestStop(net, "p1")
		expect.equal(#calls, 1, "once at the solve")
		expect.equal(calls[1].player, "p1", "with the solver")
		expect.equal(calls[1].solvedSent, 1, "after LockpickSolved")
		requestStop(net, "p1")
		expect.equal(#calls, 1, "not again")
		door:Destroy()
		model:Destroy()
	end)

	suite:test("Open(p) in Active opens at once and returns true without onSolved; false when open or Idle", function(expect)
		local solvedCalls = 0
		local door, model, net = newDoor({ bank = activeBank(), onSolved = function() solvedCalls += 1 end })
		expect.equal(door.prompt.ObjectText, "Locked Door", "default object text")
		door:OnSessionStart()
		expect.equal(door:Open("p1"), true, "opens")
		expect.truthy(door.isOpen, "open")
		expect.falsy(door.prompt.Enabled, "prompt off")
		expect.truthy(door._activeTween ~= nil, "the open tween runs")
		expect.equal(solvedCalls, 0, "onSolved not called")
		expect.equal(#net.solved, 0, "no LockpickSolved")
		expect.equal(door:Open("p1"), false, "already open")
		door:Destroy()
		model:Destroy()

		local idleBank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local door2, model2 = newDoor({ bank = idleBank })
		expect.equal(door2:Open("p1"), false, "Idle")
		expect.falsy(door2.isOpen, "still closed")
		model2:Destroy()
	end)

	suite:test("one live attempt per player: triggering B drops A, and one stop is judged by B only", function(expect)
		-- One net shared by both doors, like the real shared remote: every door's listener hears every stop.
		local net = makeNet()
		local stops, exits = {}, {}
		function net:OnLockpickStopRequested(callback) table.insert(stops, callback) end
		function net:OnLockpickExitRequested(callback) table.insert(exits, callback) end
		local bank = activeBank()
		local doorA, modelA = newDoor({ bank = bank, net = net, generateZoneAngle = alwaysZeroAngle })
		local doorB, modelB = newDoor({ bank = bank, net = net, generateZoneAngle = alwaysZeroAngle })
		doorA:OnSessionStart()
		doorB:OnSessionStart()
		doorA:_onTriggered("p1")
		doorB:_onTriggered("p1")
		expect.falsy(doorA._attempts["p1"], "A has no attempt left")
		for _, callback in ipairs(stops) do callback("p1") end
		expect.equal(#net.updates, 1, "one door judged the click")
		expect.equal(doorB._attempts["p1"].progress, 0.25, "B advanced")
		expect.falsy(doorA._attempts["p1"], "A still has none")
		for _, callback in ipairs(exits) do callback("p1") end
		expect.falsy(doorB._attempts["p1"], "exit clears B")
		doorA:_onTriggered("p1")
		expect.truthy(doorA._attempts["p1"] ~= nil, "A can be picked again after the exit")
		modelA:Destroy()
		modelB:Destroy()
	end)

	return suite:run()
end
