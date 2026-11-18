local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Heist layers 2026-11-17: a carried heavy-loot object banks when its carrier gets clear of the
-- building and escapeDistance studs (horizontal) from the anchor. Players are tables with a real
-- character model so Getaway's default position read works; carry state, currency and net are
-- recording stubs.
return function()
	local CarryGetaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.CarryGetaway)
	local suite = TestRunner.new("CarryGetaway")

	local VALUE = 3000

	-- Open items pass 2026-11-18: every anchor and character a case builds is destroyed by the case itself
	-- (cleanup() on its last line), not left for TestRunner's per-case sweep.
	local made = {}
	local function cleanup()
		for _, instance in ipairs(made) do instance:Destroy() end
		table.clear(made)
	end

	local function makePlayer(userId, x)
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Anchored = true
		root.Position = Vector3.new(x, 50, 0)
		root.Parent = character
		character.PrimaryPart = root
		character.Parent = workspace
		table.insert(made, character)
		return { UserId = userId, Character = character }
	end

	local function makeRig(opts)
		opts = opts or {}
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.Position = Vector3.new(0, 0, 0)
		anchor.Parent = workspace
		table.insert(made, anchor)
		local rig = { carried = {}, consumed = {}, credited = {}, toasts = {}, successes = {}, players = {}, inside = {} }
		local carryState = {
			GetCarried = function(_, p) return rig.carried[p] end,
			Consume = function(_, p)
				local obj = rig.carried[p]
				if not obj then return false, nil end
				rig.carried[p] = nil
				table.insert(rig.consumed, p)
				return true, obj
			end,
		}
		rig.getaway = CarryGetaway.new({
			escapeDistance = 200,
			anchor = anchor,
			isInsideBuilding = function(p) return rig.inside[p] == true end,
			matches = function(obj) return obj.kind == "gold" end,
			value = VALUE,
			carryState = carryState,
			currency = { Add = function(_, userId, amount) table.insert(rig.credited, { userId, amount }) end },
			net = {
				Toast = function(_, p, msg) table.insert(rig.toasts, { p, msg }) end,
				NotifyRobberySuccess = function(_, p) table.insert(rig.successes, p) end,
			},
			getPlayers = function() return rig.players end,
			addActiveRobbery = opts.addActiveRobbery,
		})
		return rig
	end

	suite:test("a matching carry at 199 studs is not paid", function(expect)
		local rig = makeRig()
		local p = makePlayer(1, 199)
		rig.players = { p }
		rig.carried[p] = { kind = "gold" }
		rig.getaway:Step()
		expect.equal(#rig.credited, 0, "no pay")
		expect.truthy(rig.getaway:IsNear(p), "still near")
		cleanup()
	end)

	suite:test("a matching carry outside at 200 studs is paid once and consumed", function(expect)
		local rig = makeRig()
		local p = makePlayer(42, 200)
		rig.players = { p }
		rig.carried[p] = { kind = "gold" }
		rig.getaway:Step()
		rig.getaway:Step()
		expect.equal(#rig.credited, 1, "paid once")
		expect.equal(rig.credited[1][1], 42, "to the carrier")
		expect.equal(rig.credited[1][2], VALUE, "the configured value")
		expect.equal(#rig.consumed, 1, "carry consumed")
		expect.equal(rig.toasts[1][2], "Banked 3000 Cash.", "toast")
		expect.equal(#rig.successes, 1, "robbery success VFX")
		expect.falsy(rig.getaway:IsNear(p), "no carry: not near")
		cleanup()
	end)

	suite:test("a carrier inside the building at 300 studs is not paid", function(expect)
		local rig = makeRig()
		local p = makePlayer(1, 300)
		rig.players = { p }
		rig.carried[p] = { kind = "gold" }
		rig.inside[p] = true
		rig.getaway:Step()
		expect.equal(#rig.credited, 0, "no pay inside")
		expect.truthy(rig.getaway:IsNear(p), "inside counts as near")
		cleanup()
	end)

	suite:test("a non-matching carry is not paid", function(expect)
		local rig = makeRig()
		local p = makePlayer(1, 500)
		rig.players = { p }
		rig.carried[p] = { kind = "camera" }
		rig.getaway:Step()
		expect.equal(#rig.credited, 0, "no pay")
		expect.equal(#rig.consumed, 0, "not consumed")
		cleanup()
	end)

	suite:test("no carry is never near", function(expect)
		local rig = makeRig()
		local p = makePlayer(1, 10)
		rig.players = { p }
		expect.falsy(rig.getaway:IsNear(p), "no carry: not near")
		cleanup()
	end)

	suite:test("addActiveRobbery registers carrying-and-near, and Destroy disconnects it", function(expect)
		local registered, disconnected = nil, 0
		local rig = makeRig({
			addActiveRobbery = function(fn)
				registered = fn
				return { Disconnect = function() disconnected += 1 end }
			end,
		})
		local p = makePlayer(1, 50)
		rig.players = { p }
		expect.truthy(registered ~= nil, "registered")
		expect.falsy(registered(p), "not carrying: not active")
		rig.carried[p] = { kind = "gold" }
		expect.truthy(registered(p), "carrying and near: active")
		rig.getaway:Destroy()
		expect.equal(disconnected, 1, "disconnected on Destroy")
		cleanup()
	end)

	return suite:run()
end
