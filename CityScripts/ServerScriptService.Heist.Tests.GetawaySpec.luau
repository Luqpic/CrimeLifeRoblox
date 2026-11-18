local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local Getaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Getaway)
	local suite = TestRunner.new("Getaway")

	-- The anchor sits 136 studs ABOVE the origin, mirroring the Bank's real
	-- StatusBillboardAnchor (Y=136.4 over a lobby at Y=18.5). Every distance
	-- assertion below is therefore also a regression test that Y is ignored.
	local ANCHOR = Vector3.new(0, 136, 0)

	local function makeRig(overrides)
		overrides = overrides or {}
		local state = {
			duffels = { p1 = 1000 },
			inside = { p1 = false },
			positions = { p1 = Vector3.new(0, 0, 0) },
			escaped = {},
		}
		local cfg = {
			escapeDistance = 200,
			getAnchorPosition = function() return ANCHOR end,
			isInsideBuilding = function(player) return state.inside[player] == true end,
			getDuffel = function(player) return state.duffels[player] or 0 end,
			getPosition = function(player) return state.positions[player] end,
			getPlayers = function() return { "p1" } end,
			onEscaped = function(player)
				table.insert(state.escaped, player)
				-- Mirrors the real consumer: bank:Claim zeroes the bag.
				state.duffels[player] = 0
			end,
		}
		for k, v in pairs(overrides) do cfg[k] = v end
		return Getaway.new(cfg), state
	end

	-- THE Bank test. Its VaultZone is 314 studs horizontally from its own
	-- anchor, so without the inside-the-building gate the Bank would pay out
	-- the instant cash entered the bag, with no getaway at all.
	suite:test("does not fire while still inside the building, however far away", function(expect)
		local getaway, state = makeRig()
		state.inside.p1 = true
		state.positions.p1 = Vector3.new(314, 56, 0)

		getaway:Step()

		expect.equal(#state.escaped, 0, "no payout from inside the vault")
	end)

	suite:test("does not fire without a bag", function(expect)
		local getaway, state = makeRig()
		state.duffels.p1 = 0
		state.positions.p1 = Vector3.new(500, 0, 0)

		getaway:Step()

		expect.equal(#state.escaped, 0, "nothing to bank")
	end)

	suite:test("fires once the player is outside and past the distance", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(200, 0, 0)

		getaway:Step()

		expect.equal(#state.escaped, 1, "banked")
		expect.equal(state.escaped[1], "p1", "the right player")
	end)

	-- 3D distance from this position would be sqrt(199^2 + 136^2) = 241, which
	-- is past the 200 threshold. Horizontal distance is 199, which is not.
	suite:test("measures horizontally: the anchor's height never counts toward the run", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(199, 0, 0)

		getaway:Step()

		expect.equal(#state.escaped, 0, "199 horizontal studs is short of 200")
	end)

	suite:test("fires exactly once per bag, not once per tick", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()
		getaway:Step()
		getaway:Step()

		expect.equal(#state.escaped, 1, "one payout")
	end)

	suite:test("re-arms for a second bag after the first is banked", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()          -- banks bag one, duffel -> 0
		state.duffels.p1 = 500  -- robbed again
		getaway:Step()

		expect.equal(#state.escaped, 2, "both bags banked")
	end)

	-- Guards the case where onEscaped does NOT zero the bag -- bank:Claim
	-- returns 0 when the session is no longer Active. Without the latch this
	-- would re-fire every heartbeat for the rest of the session.
	suite:test("does not re-fire every tick when onEscaped leaves the bag alone", function(expect)
		local fired = 0
		-- Deliberately does NOT clear the duffel, unlike the default rig.
		local getaway, state = makeRig({ onEscaped = function() fired += 1 end })
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()
		getaway:Step()

		expect.equal(fired, 1, "latched after the first fire")
	end)

	suite:test("DistanceRemaining is nil inside, and counts down outside", function(expect)
		local getaway, state = makeRig()

		state.inside.p1 = true
		expect.equal(getaway:DistanceRemaining("p1"), nil, "nil while inside")

		state.inside.p1 = false
		state.positions.p1 = Vector3.new(50, 0, 0)
		expect.equal(getaway:DistanceRemaining("p1"), 150, "150 studs left")

		state.positions.p1 = Vector3.new(500, 0, 0)
		expect.equal(getaway:DistanceRemaining("p1"), 0, "clamped at zero, never negative")
	end)

	suite:test("DistanceRemaining is nil without a bag", function(expect)
		local getaway, state = makeRig()
		state.duffels.p1 = 0

		expect.equal(getaway:DistanceRemaining("p1"), nil, "nothing to escape with")
	end)

	suite:test("a missing character is not an escape and does not error", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = nil

		getaway:Step()

		expect.equal(#state.escaped, 0, "no position, no payout")
		expect.equal(getaway:DistanceRemaining("p1"), nil, "no position, no number")
	end)

	suite:test("Forget clears the latch", function(expect)
		local fired = 0
		local getaway, state = makeRig({ onEscaped = function() fired += 1 end })
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()
		getaway:Forget("p1")
		getaway:Step()

		expect.equal(fired, 2, "latch cleared, fires again")
	end)

	suite:test("accepts an anchor Part instead of a position function", function(expect)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(0, 136, 0)
		part.Parent = workspace

		local escaped = {}
		local getaway = Getaway.new({
			escapeDistance = 200,
			anchor = part,
			isInsideBuilding = function() return false end,
			getDuffel = function() return 1000 end,
			getPosition = function() return Vector3.new(250, 0, 0) end,
			getPlayers = function() return { "p1" } end,
			onEscaped = function(player) table.insert(escaped, player) end,
		})
		getaway:Step()

		expect.equal(#escaped, 1, "anchor Part resolved to its Position")
		part:Destroy()
	end)

	suite:test("rejects a construction missing its required dependencies", function(expect)
		local ok = pcall(function()
			return Getaway.new({ escapeDistance = 200 })
		end)
		expect.falsy(ok, "constructing without callbacks errors")
	end)

	-- Open items pass 2026-11-18: one getaway function for server and client (HeistShared.GetawayMath).
	suite:test("the server's distance is GetawayMath.remaining, the function the client widget calls", function(expect)
		local GetawayMath = require(game.ReplicatedStorage.HeistShared.GetawayMath)
		local getaway, state = makeRig()
		local samples = {
			Vector3.new(0, 0, 0), Vector3.new(100, -50, 0), Vector3.new(0, 300, 150), Vector3.new(141.42, 0, 141.42),
			Vector3.new(-199.9, 7, 0), Vector3.new(120.5, 0, -160.25), Vector3.new(500, 0, 500),
		}
		for _, position in ipairs(samples) do
			state.positions.p1 = position
			expect.equal(getaway:DistanceRemaining("p1"), GetawayMath.remaining(position, ANCHOR, 200), tostring(position))
		end
		expect.equal(GetawayMath.remaining(Vector3.new(100, 999, 0), ANCHOR, 200), 100, "horizontal: 100 studs out, 100 to go")
		expect.equal(GetawayMath.remaining(Vector3.new(0, 0, 250), ANCHOR, 200), 0, "never below 0")
		local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("HeistClient")
		expect.truthy(client and string.find(client.Source, "GetawayMath.remaining(", 1, true) ~= nil,
			"HeistClient's widget calls GetawayMath.remaining")
	end)

	suite:test("rejects a non-positive escapeDistance", function(expect)
		local ok = pcall(function()
			return Getaway.new({
				escapeDistance = 0,
				getAnchorPosition = function() return ANCHOR end,
				isInsideBuilding = function() return false end,
				getDuffel = function() return 0 end,
				getPlayers = function() return {} end,
				onEscaped = function() end,
			})
		end)
		expect.falsy(ok, "zero distance is a configuration error, not a free payout")
	end)

	return suite:run()
end
