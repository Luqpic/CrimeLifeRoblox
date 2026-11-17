local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Heist layers 2026-11-17 (Task 6): the Bank's deposit boxes. Each box is a LockedDoor on the shared
-- lockpick screen; contents are rolled at session start and paid to the solver. Boxes stay shut
-- until Unlock (the vault door latch). The gold bar and carry state are recording fakes.
return function()
	local DepositBoxes = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.DepositBoxes)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("DepositBoxes")

	local PLAYER = "robber"

	-- A box: a hinge part (the PrimaryPart, so the pivot) plus a door panel and the prompt part.
	local function boxModel(i)
		local model = Instance.new("Model")
		model.Name = "DepositBox" .. i
		local hinge = Instance.new("Part")
		hinge.Name = "Hinge"
		hinge.Anchored = true
		hinge.Size = Vector3.new(0.2, 2, 0.2)
		hinge.CFrame = CFrame.new(i * 4, 5, 0)
		hinge.Parent = model
		local handle = Instance.new("Part")
		handle.Name = "ProximityPart Handle"
		handle.Anchored = true
		handle.Size = Vector3.new(0.3, 0.3, 0.3)
		handle.CFrame = CFrame.new(i * 4 + 1.5, 5, 0)
		handle.Parent = model
		model.PrimaryPart = hinge
		model.Parent = workspace
		return model
	end

	local function makeNet()
		local net = { opened = {}, updates = {}, solved = {}, toasts = {}, _stop = {}, _exit = {} }
		function net:OpenLockpickGui(player, payload) table.insert(self.opened, { player = player, payload = payload }) end
		function net:LockpickUpdate(player, payload) table.insert(self.updates, { player = player, payload = payload }) end
		function net:LockpickSolved(player) table.insert(self.solved, player) end
		function net:Toast(player, text) table.insert(self.toasts, { player = player, text = text }) end
		function net:OnLockpickStopRequested(cb) table.insert(self._stop, cb) end
		function net:OnLockpickExitRequested(cb) table.insert(self._exit, cb) end
		-- One click reaches every listener, like the real shared remote.
		function net:click(player) for _, cb in ipairs(self._stop) do cb(player) end end
		return net
	end

	local function makeGoldBar(carryState, opts)
		opts = opts or {}
		local bar = { given = {}, drops = {} }
		function bar:GiveTo(player)
			table.insert(self.given, player)
			if opts.pickupRefused then return true end -- GiveTo's known trap: onPickup ran, PickUp refused
			carryState.carried[player] = self
			return true
		end
		function bar:DropAt(cframe) table.insert(self.drops, cframe) end
		return bar
	end

	local function makeCarryState()
		local cs = { carried = {} }
		function cs:IsCarrying(p) return self.carried[p] ~= nil end
		function cs:GetCarried(p) return self.carried[p] end
		return cs
	end

	local function makeRig(contents, opts)
		opts = opts or {}
		local bank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local net = makeNet()
		local carryState = makeCarryState()
		local goldBar = makeGoldBar(carryState, opts)
		local models = {}
		for i = 1, #contents do models[i] = boxModel(i) end
		local rolledWith
		local boxes = DepositBoxes.new(models, {
			bank = bank,
			net = net,
			config = Config,
			carryState = carryState,
			goldBar = goldBar,
			now = function() return 1000 end,
			generateZoneAngle = function() return 0 end, -- a stop at elapsed 0 always hits
			roll = function(count) rolledWith = count return table.clone(contents) end,
		})
		bank:RegisterComponent(boxes)
		bank:TryStart(PLAYER)
		bank:AddParticipant(PLAYER)
		return {
			bank = bank, net = net, carryState = carryState, goldBar = goldBar, models = models,
			boxes = boxes, rolledWith = function() return rolledWith end,
		}
	end

	local function solve(rig, i)
		rig.boxes.doors[i]:_onTriggered(PLAYER)
		for _ = 1, 4 do rig.net:click(PLAYER) end
	end

	local function lastToast(rig)
		local t = rig.net.toasts[#rig.net.toasts]
		return t and t.text
	end

	suite:test("contents are rolled at session start, one entry per box", function(expect)
		local rig = makeRig({ "cash", "empty", "gold" })
		expect.equal(rig.rolledWith(), 3, "rolled for 3 boxes")
		expect.equal(rig.boxes.contents[3], "gold", "contents kept")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("boxes refuse before Unlock and open the Bank lockpick after it", function(expect)
		local rig = makeRig({ "cash" })
		local door = rig.boxes.doors[1]
		-- The engine fires no Triggered for a disabled prompt: that is the refusal before the latch.
		expect.falsy(door.prompt.Enabled, "prompt off before the vault door opens")
		rig.boxes:Unlock()
		expect.truthy(door.prompt.Enabled, "prompt on after Unlock")
		expect.equal(door.prompt.ObjectText, "Deposit Box", "object text")
		door:_onTriggered(PLAYER)
		expect.equal(rig.net.opened[1].payload.location, "Bank", "payload location is the Bank")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("cash goes into the bag over the cap with a +1,500 toast", function(expect)
		local rig = makeRig({ "cash" })
		rig.boxes:Unlock()
		solve(rig, 1)
		expect.truthy(rig.boxes.doors[1].isOpen, "box opened")
		expect.equal(rig.bank:GetDuffel(PLAYER), 1500, "bag +1500")
		expect.equal(lastToast(rig), "+1,500", "toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("an empty box pays nothing and says so", function(expect)
		local rig = makeRig({ "empty" })
		rig.boxes:Unlock()
		solve(rig, 1)
		expect.equal(rig.bank:GetDuffel(PLAYER), 0, "bag unchanged")
		expect.equal(lastToast(rig), "Empty.", "toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("gold with free hands: the bar is given to the solver", function(expect)
		local rig = makeRig({ "gold" })
		rig.boxes:Unlock()
		solve(rig, 1)
		expect.equal(rig.goldBar.given[1], PLAYER, "GiveTo the solver")
		expect.equal(rig.carryState:GetCarried(PLAYER), rig.goldBar, "carrying the bar")
		expect.equal(#rig.goldBar.drops, 0, "not dropped")
		expect.equal(lastToast(rig), "Gold bar! Carry it 200 studs clear of the bank.", "toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("gold when GiveTo ran but the pickup did not happen: the bar is dropped at the box", function(expect)
		local rig = makeRig({ "gold" }, { pickupRefused = true })
		rig.boxes:Unlock()
		solve(rig, 1)
		expect.equal(#rig.goldBar.given, 1, "GiveTo tried")
		expect.equal(#rig.goldBar.drops, 1, "dropped for a re-pickup")
		local handle = rig.models[1]["ProximityPart Handle"]
		expect.truthy((rig.goldBar.drops[1].Position - handle.Position).Magnitude < 4, "dropped at the box")
		expect.equal(lastToast(rig), "Gold bar! Your hands are full: it's on the floor.", "toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("gold while already carrying: not given, dropped at the box", function(expect)
		local rig = makeRig({ "gold" })
		rig.carryState.carried[PLAYER] = { other = true }
		rig.boxes:Unlock()
		solve(rig, 1)
		expect.equal(#rig.goldBar.given, 0, "GiveTo not called")
		expect.equal(#rig.goldBar.drops, 1, "dropped for a re-pickup")
		expect.equal(lastToast(rig), "Gold bar! Your hands are full: it's on the floor.", "toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("one click with attempts on two boxes is judged once", function(expect)
		local rig = makeRig({ "cash", "cash" })
		rig.boxes:Unlock()
		rig.boxes.doors[1]:_onTriggered(PLAYER)
		rig.boxes.doors[2]:_onTriggered(PLAYER)
		rig.net:click(PLAYER)
		expect.equal(#rig.net.updates, 1, "one judgement")
		expect.equal(rig.boxes.doors[1]._attempts[PLAYER], nil, "first box attempt dropped")
		expect.equal(rig.boxes.doors[2]._attempts[PLAYER].progress, 0.25, "second box progressed")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("Seal shuts the boxes; the next session closes a solved box and locks it until Unlock", function(expect)
		local rig = makeRig({ "empty" })
		local door = rig.boxes.doors[1]
		rig.boxes:Unlock()
		solve(rig, 1)
		expect.truthy(door.isOpen, "open after solve")
		rig.bank:_seal("timer_expired")
		expect.falsy(door.isOpen, "closed at seal")
		expect.falsy(door.prompt.Enabled, "prompt off at seal")
		rig.bank:_rearm()
		rig.bank:TryStart(PLAYER)
		expect.falsy(door.isOpen, "closed next session")
		expect.falsy(door.prompt.Enabled, "locked until the latch")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("a seal while a lockpick attempt is in flight on a gold box drops it: later clicks judge and give nothing", function(expect)
		local rig = makeRig({ "gold" })
		local door = rig.boxes.doors[1]
		rig.boxes:Unlock()
		door:_onTriggered(PLAYER)
		rig.net:click(PLAYER)
		rig.net:click(PLAYER)
		expect.equal(door._attempts[PLAYER].progress, 0.5, "half-picked when the timer runs out")
		rig.bank:_seal("timer_expired")
		local updates = #rig.net.updates
		for _ = 1, 4 do rig.net:click(PLAYER) end
		expect.equal(#rig.net.updates, updates, "no click judged after the seal")
		expect.equal(#rig.net.solved, 0, "nothing solved")
		expect.equal(#rig.goldBar.given, 0, "no gold given")
		expect.falsy(door.isOpen, "box shut")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("two players race one gold box: one solve, exactly one GiveTo", function(expect)
		local RIVAL = "rival"
		local rig = makeRig({ "gold" })
		rig.bank:AddParticipant(RIVAL)
		local door = rig.boxes.doors[1]
		rig.boxes:Unlock()
		door:_onTriggered(PLAYER)
		door:_onTriggered(RIVAL)
		rig.net:click(RIVAL)
		for _ = 1, 4 do rig.net:click(PLAYER) end
		expect.truthy(door.isOpen, "opened by the first to finish")
		rig.net:click(RIVAL) -- the loser's next click only closes their lockpick
		for _ = 1, 3 do rig.net:click(RIVAL) end
		expect.equal(#rig.goldBar.given, 1, "one GiveTo")
		expect.equal(rig.goldBar.given[1], PLAYER, "to the solver")
		expect.equal(door._attempts[RIVAL], nil, "rival's attempt dropped")
		local goldToasts = 0
		for _, t in ipairs(rig.net.toasts) do
			if t.text:find("Gold bar") then goldToasts += 1 end
		end
		expect.equal(goldToasts, 1, "one gold toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("a non-participant's trigger starts no lockpick and the box keeps its contents", function(expect)
		local rig = makeRig({ "cash" })
		rig.boxes:Unlock()
		rig.boxes.doors[1]:_onTriggered("bystander")
		expect.equal(#rig.net.opened, 0, "no lockpick opened")
		expect.equal(rig.boxes.contents[1], "cash", "contents kept")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("no payout from a solve once the session is no longer Active", function(expect)
		local rig = makeRig({ "gold" })
		rig.boxes:Unlock()
		rig.bank:_seal("timer_expired")
		rig.boxes:_onSolved(1, PLAYER)
		expect.equal(#rig.goldBar.given, 0, "no gold given")
		expect.equal(#rig.goldBar.drops, 0, "no gold dropped")
		expect.equal(#rig.net.toasts, 0, "no toast")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	suite:test("Unlock opens nothing outside an Active session", function(expect)
		local rig = makeRig({ "cash" })
		rig.bank:_seal("timer_expired")
		rig.boxes:Unlock()
		expect.falsy(rig.boxes.doors[1].prompt.Enabled, "stays off")
		for _, m in ipairs(rig.models) do m:Destroy() end
	end)

	return suite:run()
end
