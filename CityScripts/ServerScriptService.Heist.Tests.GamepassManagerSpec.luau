local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- GamepassManager is a thin adapter since 2026-11-18: the duffel pass ids live in
-- Monetization.Constants.Gamepasses (shop = false) and ownership is published by the city's
-- PassOwnership as the GamepassOwned_<key> attribute. The cache, purchase-confirm and failed-check
-- cases moved to ServerStorage.UnitTest.Cases.PassOwnership_Test with that code.
return function()
	local GamepassManager = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.GamepassManager)
	local MonetizationConstants = require(game.ReplicatedStorage.Monetization.Constants)
	local suite = TestRunner.new("GamepassManager")

	-- A stand-in player holding the published ownership attributes; `reads` records every pass key
	-- read, so a test can prove a lookup was SKIPPED, not just what it returned.
	local function fakePlayer(ownedKeys)
		local attributes, reads = {}, {}
		for _, key in ownedKeys or {} do
			attributes[MonetizationConstants.ownedAttributeFor(key)] = true
		end
		local player = {
			reads = reads,
			GetAttribute = function(_, name)
				table.insert(reads, name)
				return attributes[name]
			end,
			own = function(_, key) attributes[MonetizationConstants.ownedAttributeFor(key)] = true end,
		}
		return player
	end

	suite:test("PlayerOwnsGamepass reads the pass's published ownership attribute", function(expect)
		local player = fakePlayer({ "DuffelCapacityX2" })
		expect.truthy(GamepassManager:PlayerOwnsGamepass(player, "DuffelCapacityX2"), "owned")
		expect.falsy(GamepassManager:PlayerOwnsGamepass(player, "DuffelCapacityX4"), "not owned")
	end)

	suite:test("GetDuffelCapMultiplier: neither owned -> 1x", function(expect)
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer()), 1, "base rate")
	end)

	suite:test("GetDuffelCapMultiplier: x2 only -> 2x", function(expect)
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer({ "DuffelCapacityX2" })), 2, "x2")
	end)

	suite:test("GetDuffelCapMultiplier: x4 only -> 4x", function(expect)
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer({ "DuffelCapacityX4" })), 4, "x4")
	end)

	suite:test("GetDuffelCapMultiplier: owning BOTH resolves to x4, never x6 or additive", function(expect)
		local player = fakePlayer({ "DuffelCapacityX2", "DuffelCapacityX4" })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 4, "highest tier wins, no stacking")
	end)

	suite:test("GetDuffelCapMultiplier: x4 owned skips the x2 lookup entirely", function(expect)
		local player = fakePlayer({ "DuffelCapacityX4" })
		GamepassManager:GetDuffelCapMultiplier(player)
		expect.equal(#player.reads, 1, "only the x4 read ran")
		expect.equal(player.reads[1], MonetizationConstants.ownedAttributeFor("DuffelCapacityX4"), "and it was x4")
	end)

	suite:test("GetDuffelCapMultiplier: upgrade path (x2 first, x4 bought later) resolves to x4", function(expect)
		local player = fakePlayer({ "DuffelCapacityX2" })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 2, "x2 before the upgrade")
		player:own("DuffelCapacityX4") -- PassOwnership publishes the confirmed purchase
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 4, "x4 after the upgrade, x2 untouched")
	end)

	suite:test("the adapter keeps no cache: a pass published mid-session is read at once", function(expect)
		local player = fakePlayer()
		expect.equal(GamepassManager:GetAccrualRateMultiplier(player), 1, "before")
		player:own("DuffelSpeedBoost")
		expect.equal(GamepassManager:GetAccrualRateMultiplier(player),
			GamepassManager.GamepassConfig.DuffelSpeedBoost.Multiplier, "after, no stale answer")
	end)

	suite:test("GetAccrualRateMultiplier: not owned -> 1x, owned -> the configured boost", function(expect)
		expect.equal(GamepassManager:GetAccrualRateMultiplier(fakePlayer()), 1, "not owned")
		expect.equal(GamepassManager:GetAccrualRateMultiplier(fakePlayer({ "DuffelSpeedBoost" })),
			GamepassManager.GamepassConfig.DuffelSpeedBoost.Multiplier, "owned")
	end)

	suite:test("Duffel Speed+ stacks independently of whichever capacity tier is owned", function(expect)
		local player = fakePlayer({ "DuffelCapacityX4", "DuffelSpeedBoost" })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 4, "capacity unaffected")
		expect.equal(GamepassManager:GetAccrualRateMultiplier(player),
			GamepassManager.GamepassConfig.DuffelSpeedBoost.Multiplier, "speed boost independent")
	end)

	suite:test("every adapter key is a hidden pass in Monetization.Constants (one place for the ids)", function(expect)
		local hidden = {}
		for _, pass in MonetizationConstants.Gamepasses do
			if pass.shop == false then hidden[pass.key] = true end
		end
		for key in GamepassManager.GamepassConfig do
			expect.truthy(hidden[key], key .. " is a hidden pass entry")
		end
	end)

	return suite:run()
end
