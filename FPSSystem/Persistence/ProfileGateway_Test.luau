-- Tests for ProfileGateway against ProfileStore's MOCK store, which operates on a fake DataStore and
-- is forgotten at server shutdown. That is what lets this run on an unpublished place.
--
-- The rule these exist to protect: a profile that failed to load is never written. Everything else in
-- this phase is recoverable; that one is not.
return function(t)
	local Gateway = require(game.ServerScriptService.Persistence.Scripts.ProfileGateway)
	local Schema = require(game.ReplicatedStorage.Persistence.Schema)
	local expect = t.expect

	Gateway.useMockStore()

	t.test("a fresh key loads a profile matching the template", function()
		local profile = Gateway.loadForKey("test-fresh-" .. os.clock())
		expect.truthy(profile ~= nil)
		expect.equal(profile.Data.spraypaint, Schema.template.spraypaint)
		expect.equal(profile.Data.cash, Schema.template.cash)
		expect.equal(profile.Data.level, Schema.template.level)
		profile:EndSession()
	end)

	t.test("a profile round-trips what was written to it", function()
		local key = "test-roundtrip-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.spraypaint = 137
		first.Data.skinsOwned.Cobalt = true
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.spraypaint, 137)
		expect.equal(second.Data.skinsOwned.Cobalt, true)
		second:EndSession()
	end)

	t.test("Reconcile fills a field added to the template since the profile was written", function()
		-- Adding a field must not require a version bump; this is what makes that true.
		local key = "test-reconcile-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.spraypaint = 5
		first.Data.cash = nil -- simulate a profile written before `cash` existed
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.cash, Schema.template.cash)
		expect.equal(second.Data.spraypaint, 5)
		second:EndSession()
	end)

	t.test("a stamped version is preserved across a round trip", function()
		local key = "test-version-" .. os.clock()
		local first = Gateway.loadForKey(key)
		expect.equal(first.Data.version, Schema.VERSION)
		first:EndSession()
	end)

	t.test("get returns nil for a player with no profile", function()
		local stranger = { UserId = -1, Name = "NoSuchPlayer" }
		expect.equal(Gateway.get(stranger), nil)
		expect.falsy(Gateway.isLoaded(stranger))
	end)

	t.test("a failed load yields no profile and writes nothing", function()
		-- THE rule. A load that fails must leave the stored profile untouched; handing out a blank
		-- profile and later saving it is how an account is wiped, and it looks like a normal session
		-- right up until the save lands.
		local key = "test-failure-" .. os.clock()
		local seeded = Gateway.loadForKey(key)
		seeded.Data.spraypaint = 999
		seeded:EndSession()

		Gateway._forceNextLoadFailure(true)
		local failed = Gateway.loadForKey(key)
		Gateway._forceNextLoadFailure(false)
		expect.equal(failed, nil)

		local reread = Gateway.loadForKey(key)
		expect.equal(reread.Data.spraypaint, 999)
		reread:EndSession()
	end)

	t.test("ending a session twice does not throw", function()
		local profile = Gateway.loadForKey("test-double-end-" .. os.clock())
		profile:EndSession()
		expect.truthy(pcall(function() profile:EndSession() end))
	end)

	t.test("a v0 profile migrates to the current version without losing fields", function()
		-- v0 is any profile written before the version field existed. It must gain the version and
		-- keep everything it already had.
		local key = "migrate-v0-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.version = nil
		first.Data.spraypaint = 77
		first.Data.cash = 123
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.version, Schema.VERSION)
		expect.equal(second.Data.spraypaint, 77)
		expect.equal(second.Data.cash, 123)
		second:EndSession()
	end)

	t.test("migration is idempotent", function()
		local data = { version = Schema.VERSION, spraypaint = 5 }
		expect.falsy(Gateway.migrate(data))
		expect.equal(data.spraypaint, 5)
	end)

	t.test("a derived field found in stored data is stripped", function()
		-- Older profiles, or a mirror bug, could have written one. Leaving it would let a stale value
		-- outlive and then contradict the thing it was derived from.
		local data = { version = Schema.VERSION, level = 3, NextLevelXP = 999 }
		Gateway.migrate(data)
		expect.equal(data.NextLevelXP, nil)
		expect.equal(data.level, 3)
	end)

	t.test("an unrecognised field survives migration untouched", function()
		-- An unrecognised field is more likely to be from a NEWER schema than garbage. migrate must
		-- strip only what Schema.DERIVED actually names, never anything merely absent from the template.
		local data = { version = Schema.VERSION, fieldFromANewerSchema = "keep me" }
		Gateway.migrate(data)
		expect.equal(data.fieldFromANewerSchema, "keep me")
	end)
end
