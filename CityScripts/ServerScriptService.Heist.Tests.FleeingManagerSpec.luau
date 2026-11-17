local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Heist layers 2026-11-17 (Task 3): the SlowFoods Manager who flees on the alarm and drops
-- the storage-room key to whoever catches him.
return function()
	local FleeingManager = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.FleeingManager)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.RestaurantShared.Config)
	local suite = TestRunner.new("FleeingManager")

	local function makeRig()
		local model = Instance.new("Model")
		model.Name = "Manager"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(0, 500, 0)
		root.Parent = model
		model.PrimaryPart = root
		Instance.new("Humanoid").Parent = model
		model.Parent = workspace
		local escape = Instance.new("Part")
		escape.Anchored = true
		escape.Position = Vector3.new(100, 500, 0)
		escape.Parent = workspace
		return model, escape
	end

	-- distances[player] is what measure() returns; t is the injected clock.
	local function setup(overrides)
		overrides = overrides or {}
		local model, escape = makeRig()
		local bank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local distances, taken, paths = {}, {}, {}
		local clock = { t = 0 }
		local manager = FleeingManager.new(model, {
			bank = bank,
			config = Config,
			escapePoint = escape,
			measure = function(player) return distances[player] end,
			onKeyTaken = function(player) table.insert(taken, player) end,
			pathTo = overrides.pathTo or function(m, target) table.insert(paths, { model = m, target = target }) end,
			clock = function() return clock.t end,
		})
		bank:RegisterComponent(manager)
		local function cleanup()
			manager:Destroy()
			model:Destroy()
			escape:Destroy()
		end
		return manager, bank, distances, taken, paths, clock, escape, cleanup
	end

	suite:test("Config carries the spec's manager values", function(expect)
		expect.equal(Config.ManagerKeyRange, 10, "ManagerKeyRange")
		expect.equal(Config.ManagerSafeAmount, 3000, "ManagerSafeAmount")
		expect.equal(Config.ManagerKeyHold, 1, "ManagerKeyHold")
	end)

	suite:test("idle before the alarm: no prompt, TryTakeKey refused", function(expect)
		local manager, bank, distances, _, paths, _, _, cleanup = setup()
		expect.equal(manager.state, "idle", "idle")
		expect.equal(manager._prompt, nil, "no prompt")
		distances.p1 = 5
		local ok, reason = manager:TryTakeKey("p1")
		expect.falsy(ok, "refused")
		expect.equal(reason, "not_fleeing", "not_fleeing")
		expect.equal(#paths, 0, "never pathed")
		cleanup()
	end)

	suite:test("OnSessionStart: fleeing, root unanchored, pathTo called with the escape point", function(expect)
		local manager, bank, _, _, paths, _, escape, cleanup = setup()
		bank:TryStart("p1")
		expect.equal(manager.state, "fleeing", "fleeing")
		expect.falsy(manager.root.Anchored, "root unanchored")
		expect.equal(#paths, 1, "pathTo called once")
		expect.equal(paths[1].model, manager.model, "with his model")
		expect.equal(paths[1].target, escape.Position, "to the escape point")
		cleanup()
	end)

	suite:test("OnSessionStart arms a Take Key prompt from Config", function(expect)
		local manager, bank, _, _, _, _, _, cleanup = setup()
		bank:TryStart("p1")
		local prompt = manager._prompt
		expect.truthy(prompt ~= nil and prompt.Parent == manager.root, "prompt on the root")
		if prompt then
			expect.equal(prompt.ActionText, "Take Key", "ActionText")
			expect.equal(prompt.HoldDuration, Config.ManagerKeyHold, "hold")
			expect.equal(prompt.MaxActivationDistance, Config.ManagerKeyRange, "range")
			expect.falsy(prompt.RequiresLineOfSight, "no line of sight needed")
		end
		cleanup()
	end)

	suite:test("a participant at 9 studs takes the key once; a second player is refused", function(expect)
		local manager, bank, distances, taken, _, _, _, cleanup = setup()
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:AddParticipant("p2")
		distances.p1, distances.p2 = 9, 2
		local ok, reason = manager:TryTakeKey("p1")
		expect.truthy(ok, "p1 takes it")
		expect.equal(reason, nil, "no reason")
		expect.equal(manager.state, "caught", "caught")
		expect.equal(#taken, 1, "onKeyTaken once")
		expect.equal(taken[1], "p1", "for p1")
		expect.equal(manager._prompt, nil, "prompt gone")
		expect.truthy(manager.root.Anchored, "he stops")
		local ok2, reason2 = manager:TryTakeKey("p2")
		expect.falsy(ok2, "p2 refused")
		expect.equal(reason2, "not_fleeing", "not_fleeing")
		expect.equal(#taken, 1, "still once")
		cleanup()
	end)

	suite:test("at 11 studs: too_far; no distance: too_far", function(expect)
		local manager, bank, distances, taken, _, _, _, cleanup = setup()
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		distances.p1 = 11
		local ok, reason = manager:TryTakeKey("p1")
		expect.falsy(ok, "refused")
		expect.equal(reason, "too_far", "too_far")
		distances.p1 = nil
		local ok2, reason2 = manager:TryTakeKey("p1")
		expect.falsy(ok2, "refused without a character")
		expect.equal(reason2, "too_far", "too_far")
		expect.equal(manager.state, "fleeing", "still fleeing")
		expect.equal(#taken, 0, "no key")
		cleanup()
	end)

	suite:test("a non-participant is refused", function(expect)
		local manager, bank, distances, taken, _, _, _, cleanup = setup()
		bank:TryStart("p1")
		distances.p3 = 3
		local ok, reason = manager:TryTakeKey("p3")
		expect.falsy(ok, "refused")
		expect.equal(reason, "not_participant", "not_participant")
		expect.equal(#taken, 0, "no key")
		cleanup()
	end)

	suite:test("reaching the escape point: escaped, hidden, no key possible", function(expect)
		local manager, bank, distances, taken, _, _, _, cleanup = setup({
			pathTo = function(model, target) model:PivotTo(CFrame.new(target)) end,
		})
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		expect.equal(manager.state, "escaped", "escaped")
		expect.equal(manager.model.Parent, nil, "hidden until Rearm")
		expect.equal(manager._prompt, nil, "prompt gone")
		distances.p1 = 1
		local ok, reason = manager:TryTakeKey("p1")
		expect.falsy(ok, "refused")
		expect.equal(reason, "not_fleeing", "not_fleeing")
		expect.equal(#taken, 0, "no key")
		cleanup()
	end)

	suite:test("pathTo returning short of the point leaves him fleeing and catchable", function(expect)
		local manager, bank, distances, _, _, _, _, cleanup = setup()
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		expect.equal(manager.state, "fleeing", "still fleeing")
		distances.p1 = 4
		expect.truthy((manager:TryTakeKey("p1")), "key taken")
		cleanup()
	end)

	suite:test("Seal while fleeing: stops, prompt gone, no key possible", function(expect)
		local manager, bank, distances, taken, _, _, _, cleanup = setup()
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		manager:Seal()
		expect.equal(manager.state, "idle", "idle")
		expect.equal(manager._prompt, nil, "prompt gone")
		expect.truthy(manager.root.Anchored, "stopped")
		distances.p1 = 2
		local ok, reason = manager:TryTakeKey("p1")
		expect.falsy(ok, "refused")
		expect.equal(reason, "not_fleeing", "not_fleeing")
		expect.equal(#taken, 0, "no key")
		cleanup()
	end)

	suite:test("the prompt is honoured only after a server-timed hold", function(expect)
		local manager, bank, distances, taken, _, clock, _, cleanup = setup()
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		distances.p1 = 3
		manager:_onPromptTriggered("p1")
		expect.equal(#taken, 0, "no hold began: ignored")
		manager:_onHoldBegan("p1")
		clock.t += 0.3
		manager:_onPromptTriggered("p1")
		expect.equal(#taken, 0, "0.3 s hold: ignored")
		manager:_onHoldBegan("p1")
		clock.t += Config.ManagerKeyHold
		manager:_onPromptTriggered("p1")
		expect.equal(#taken, 1, "a full hold takes the key")
		cleanup()
	end)

	return suite:run()
end
