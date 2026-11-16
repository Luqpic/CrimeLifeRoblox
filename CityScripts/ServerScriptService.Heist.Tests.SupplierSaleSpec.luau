local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Pins the Illegal Supplier sale (phase 3 Task 5, audit row 4): the server pays a carry only
-- when the seller is standing at the supplier, because the conversation that sends
-- SubmitSupplierChoice is opened client-side. Players are plain tables; the carry state and
-- currency are recording stubs, so nothing touches Workspace.
return function()
	local SupplierSale = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.SupplierSale)
	local suite = TestRunner.new("SupplierSale")

	local SUPPLIER = Vector3.new(0, 0, 0)

	local function makeDeps(carrying, rootPosition)
		local state = { carrying = carrying, consumed = 0, credited = {} }
		local deps = {
			supplierPosition = SUPPLIER,
			carryState = {
				IsCarrying = function() return state.carrying end,
				Consume = function()
					if not state.carrying then return false, nil end
					state.carrying = false
					state.consumed += 1
					return true, { cashOutAmount = 10000 }
				end,
			},
			currency = {
				Add = function(_, userId, amount) table.insert(state.credited, { userId, amount }) end,
			},
		}
		if rootPosition ~= nil then
			deps.getRoot = function() return { Position = rootPosition } end
		end
		return deps, state
	end

	suite:test("a carry sold within reach of the supplier is paid once", function(expect)
		local deps, state = makeDeps(true, Vector3.new(8, 0, 0))
		local paid, outcome = SupplierSale.try({ UserId = 7 }, deps)
		expect.equal(outcome, "sold", "outcome")
		expect.equal(paid, 10000, "the supply's own server-side amount")
		expect.equal(#state.credited, 1, "credited once")
		expect.equal(state.credited[1][1], 7, "to the seller")
		expect.falsy(state.carrying, "carry consumed")
	end)

	suite:test("a carry 1,000 studs from the supplier is refused and kept", function(expect)
		local deps, state = makeDeps(true, Vector3.new(1000, 0, 0))
		local paid, outcome = SupplierSale.try({ UserId = 7 }, deps)
		expect.equal(outcome, "too_far", "outcome")
		expect.equal(paid, 0, "nothing paid")
		expect.equal(#state.credited, 0, "nothing credited")
		expect.equal(state.consumed, 0, "Consume never called")
		expect.truthy(state.carrying, "carry kept on refusal")
	end)

	suite:test("a seller with no character is refused and keeps the carry", function(expect)
		local deps, state = makeDeps(true, nil) -- default getRoot reads player.Character
		local paid, outcome = SupplierSale.try({ UserId = 7, Character = nil }, deps)
		expect.equal(outcome, "too_far", "outcome")
		expect.equal(paid, 0, "nothing paid")
		expect.truthy(state.carrying, "carry kept on refusal")
	end)

	suite:test("the reach limit is 15 studs: 15 sells, 15.5 does not", function(expect)
		local depsIn = makeDeps(true, Vector3.new(15, 0, 0))
		local _, inside = SupplierSale.try({ UserId = 1 }, depsIn)
		local depsOut = makeDeps(true, Vector3.new(15.5, 0, 0))
		local _, outside = SupplierSale.try({ UserId = 1 }, depsOut)
		expect.equal(inside, "sold", "at the limit")
		expect.equal(outside, "too_far", "past the limit")
	end)

	suite:test("nothing carried answers no_supplies whatever the distance", function(expect)
		local deps, state = makeDeps(false, Vector3.new(1, 0, 0))
		local paid, outcome = SupplierSale.try({ UserId = 7 }, deps)
		expect.equal(outcome, "no_supplies", "outcome")
		expect.equal(paid, 0, "nothing paid")
		expect.equal(#state.credited, 0, "nothing credited")
	end)

	return suite:run()
end
