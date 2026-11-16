local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local GamepassManager = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.GamepassManager)
	local suite = TestRunner.new("GamepassManager")

	-- Production's three Ids are all the placeholder 0 (genuinely distinct
	-- real ids are the project owner's job, see the TODO in GamepassManager).
	-- Tests need to tell the three gamepasses apart, so give this freshly
	-- required COPY of the module distinct fake ids -- this never touches
	-- the real Config placeholders.
	GamepassManager.GamepassConfig.DuffelCapacityX2.Id = 201
	GamepassManager.GamepassConfig.DuffelCapacityX4.Id = 202
	GamepassManager.GamepassConfig.DuffelSpeedBoost.Id = 203

	-- freshRequire happens ONCE for the whole file, not once per test, so
	-- GamepassManager's internal cache is a single upvalue SHARED across every
	-- suite:test() below. A repeated userId would silently hit an earlier
	-- test's cached result instead of this test's stub -- so every test gets
	-- its own never-repeated userId from this counter, guaranteeing a clean
	-- cache slate each time.
	local _nextUserId = 0
	local function fakePlayer()
		_nextUserId += 1
		return { UserId = _nextUserId, Name = "p" .. _nextUserId }
	end

	-- Swaps the real MarketplaceService call for a controllable stub. `calls`
	-- records every (userId, gamepassId) pair actually asked for, so tests can
	-- prove a lookup was SKIPPED, not just what it returned.
	local function stubOwnership(owned)
		local calls = {}
		GamepassManager._ownershipCheck = function(userId, gamepassId)
			table.insert(calls, { userId = userId, gamepassId = gamepassId })
			return owned[gamepassId] == true
		end
		return calls
	end

	suite:test("PlayerOwnsGamepass reflects the ownership check", function(expect)
		stubOwnership({ [42] = true })
		local player = fakePlayer()
		expect.truthy(GamepassManager:PlayerOwnsGamepass(player, 42), "owned")
		expect.falsy(GamepassManager:PlayerOwnsGamepass(player, 99), "not owned")
	end)

	suite:test("PlayerOwnsGamepass caches -- only calls the real check once per player+gamepass", function(expect)
		local calls = stubOwnership({ [42] = true })
		local player = fakePlayer()
		GamepassManager:PlayerOwnsGamepass(player, 42)
		GamepassManager:PlayerOwnsGamepass(player, 42)
		GamepassManager:PlayerOwnsGamepass(player, 42)
		expect.equal(#calls, 1, "real check hit exactly once despite three queries")
	end)

	suite:test("PlayerOwnsGamepass caches per player independently", function(expect)
		local calls = stubOwnership({ [42] = true })
		GamepassManager:PlayerOwnsGamepass(fakePlayer(), 42)
		GamepassManager:PlayerOwnsGamepass(fakePlayer(), 42)
		expect.equal(#calls, 2, "different players are not cross-cached")
	end)

	suite:test("a throwing ownership check is swallowed and treated as not-owned", function(expect)
		GamepassManager._ownershipCheck = function() error("network error") end
		local owns = GamepassManager:PlayerOwnsGamepass(fakePlayer(), 42)
		expect.falsy(owns, "failure defaults to not-owned, never throws")
	end)

	suite:test("GetDuffelCapMultiplier: neither owned -> 1x", function(expect)
		stubOwnership({})
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer()), 1, "base rate")
	end)

	suite:test("GetDuffelCapMultiplier: x2 only -> 2x", function(expect)
		local config = GamepassManager.GamepassConfig
		stubOwnership({ [config.DuffelCapacityX2.Id] = true })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer()), 2, "x2")
	end)

	suite:test("GetDuffelCapMultiplier: x4 only -> 4x", function(expect)
		local config = GamepassManager.GamepassConfig
		stubOwnership({ [config.DuffelCapacityX4.Id] = true })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer()), 4, "x4")
	end)

	suite:test("GetDuffelCapMultiplier: owning BOTH resolves to x4, never x6 or additive", function(expect)
		local config = GamepassManager.GamepassConfig
		stubOwnership({ [config.DuffelCapacityX2.Id] = true, [config.DuffelCapacityX4.Id] = true })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(fakePlayer()), 4, "highest tier wins, no stacking")
	end)

	suite:test("GetDuffelCapMultiplier: x4 owned skips the x2 lookup entirely", function(expect)
		-- Efficiency behaviour explicitly called out in the spec: once x4 is
		-- confirmed, x2's ownership is never even queried.
		local config = GamepassManager.GamepassConfig
		local calls = stubOwnership({ [config.DuffelCapacityX4.Id] = true })
		GamepassManager:GetDuffelCapMultiplier(fakePlayer())
		expect.equal(#calls, 1, "only the x4 check ran")
		expect.equal(calls[1].gamepassId, config.DuffelCapacityX4.Id, "and it was the x4 id")
	end)

	suite:test("GetDuffelCapMultiplier: upgrade path (x2 first, x4 purchased later) resolves to x4 with no invalidation needed", function(expect)
		-- SAME player throughout, proving the x2 cache entry from before the
		-- upgrade coexists with a freshly-cached x4=true afterward -- nothing
		-- needs to invalidate/clear the earlier x2 record for this to resolve
		-- correctly; GetDuffelCapMultiplier just always checks x4 first.
		local config = GamepassManager.GamepassConfig
		local player = fakePlayer()
		stubOwnership({ [config.DuffelCapacityX2.Id] = true })
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 2, "x2 before the upgrade")

		-- Simulates PromptGamePassPurchaseFinished actually firing for the x4
		-- purchase (see Init()/_setCached) -- the earlier x2 cache entry for
		-- this same player is left completely untouched.
		GamepassManager:_setCached(player.UserId, config.DuffelCapacityX4.Id, true)
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 4, "x4 after the upgrade, same player, x2's earlier cache entry untouched")
	end)

	suite:test("_setCached mirrors what PromptGamePassPurchaseFinished records on a completed purchase", function(expect)
		local player = fakePlayer()
		local calls = stubOwnership({}) -- would report not-owned if actually queried
		GamepassManager:_setCached(player.UserId, 77, true)
		expect.truthy(GamepassManager:PlayerOwnsGamepass(player, 77), "cached fact wins over a fresh query")
		expect.equal(#calls, 0, "never even asked _ownershipCheck -- the cached fact short-circuited it")
	end)

	suite:test("GetAccrualRateMultiplier: not owned -> 1x, owned -> the configured boost", function(expect)
		local config = GamepassManager.GamepassConfig
		stubOwnership({})
		expect.equal(GamepassManager:GetAccrualRateMultiplier(fakePlayer()), 1, "not owned")
		stubOwnership({ [config.DuffelSpeedBoost.Id] = true })
		expect.equal(GamepassManager:GetAccrualRateMultiplier(fakePlayer()), config.DuffelSpeedBoost.Multiplier, "owned")
	end)

	suite:test("Duffel Speed+ stacks independently of whichever capacity tier is owned", function(expect)
		local config = GamepassManager.GamepassConfig
		stubOwnership({ [config.DuffelCapacityX4.Id] = true, [config.DuffelSpeedBoost.Id] = true })
		local player = fakePlayer()
		expect.equal(GamepassManager:GetDuffelCapMultiplier(player), 4, "capacity unaffected")
		expect.equal(GamepassManager:GetAccrualRateMultiplier(player), config.DuffelSpeedBoost.Multiplier, "speed boost independent")
	end)

	-- City (phase 3 Task 5): PromptGamePassPurchaseFinished is reported by the client, so a
	-- "purchased" event is confirmed with the ownership check before anything is cached.
	suite:test("a purchase confirmed by the ownership check is cached", function(expect)
		local calls = stubOwnership({ [301] = true })
		local player = fakePlayer()
		GamepassManager:_onPurchaseFinished(player, 301, true)
		local callsAfterEvent = #calls
		local owns = GamepassManager:PlayerOwnsGamepass(player, 301)
		expect.equal(callsAfterEvent, 1, "the event asked the ownership check once")
		expect.truthy(owns, "owned")
		expect.equal(#calls, 1, "and the answer was cached")
	end)

	suite:test("a purchase the ownership check denies caches nothing", function(expect)
		local calls = stubOwnership({})
		local player = fakePlayer()
		GamepassManager:_onPurchaseFinished(player, 302, true)
		local owns = GamepassManager:PlayerOwnsGamepass(player, 302)
		expect.falsy(owns, "not owned")
		expect.equal(#calls, 2, "nothing cached by the event: the later query asked again")
	end)

	suite:test("a purchase whose ownership check errors caches nothing and does not throw", function(expect)
		GamepassManager._ownershipCheck = function() error("network error") end
		local player = fakePlayer()
		local ok = pcall(function() GamepassManager:_onPurchaseFinished(player, 303, true) end)
		local calls = stubOwnership({})
		local owns = GamepassManager:PlayerOwnsGamepass(player, 303)
		expect.truthy(ok, "no throw")
		expect.falsy(owns, "not owned")
		expect.equal(#calls, 1, "nothing cached by the event")
	end)

	suite:test("a closed prompt without a purchase asks nothing and caches nothing", function(expect)
		local calls = stubOwnership({ [304] = true })
		GamepassManager:_onPurchaseFinished(fakePlayer(), 304, false)
		expect.equal(#calls, 0, "no ownership check")
	end)

	return suite:run()
end
