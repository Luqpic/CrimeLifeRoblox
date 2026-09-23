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
		-- Not a reference-equality check against Schema.template.spraypaint: Reconcile deep-copies the
		-- template into a NEW table per profile, and migrate hands back a NEW {} again on the v1->v2
		-- step every fresh profile passes through -- two distinct empty tables are never `==` in Luau.
		expect.equal(typeof(profile.Data.spraypaint), "table")
		expect.equal(next(profile.Data.spraypaint), nil)
		expect.equal(profile.Data.spraypaintShared, Schema.template.spraypaintShared)
		expect.equal(profile.Data.cash, Schema.template.cash)
		expect.equal(profile.Data.level, Schema.template.level)
		profile:EndSession()
	end)

	t.test("a profile round-trips what was written to it", function()
		local key = "test-roundtrip-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.spraypaint.AK47 = 137
		first.Data.spraypaintShared = 12
		first.Data.skinsOwned.Cobalt = true
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.spraypaint.AK47, 137)
		expect.equal(second.Data.spraypaintShared, 12)
		expect.equal(second.Data.skinsOwned.Cobalt, true)
		second:EndSession()
	end)

	t.test("Reconcile fills a field added to the template since the profile was written", function()
		-- Adding a field must not require a version bump; this is what makes that true.
		local key = "test-reconcile-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.level = 5
		first.Data.cash = nil -- simulate a profile written before `cash` existed
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.cash, Schema.template.cash)
		expect.equal(second.Data.level, 5)
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
		-- keep everything it already had -- including its old scalar Spraypaint balance, which the
		-- v1->v2 step below carries into the shared bucket rather than dropping.
		local key = "migrate-v0-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.version = nil
		first.Data.spraypaint = 77
		first.Data.cash = 123
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.version, Schema.VERSION)
		expect.equal(second.Data.spraypaintShared, 77)
		expect.equal(next(second.Data.spraypaint), nil)
		expect.equal(second.Data.cash, 123)
		second:EndSession()
	end)

	t.test("migration is idempotent", function()
		-- Idempotent means a SECOND call after a REAL migration is a no-op -- not merely that migrate
		-- returns false when handed already-clean data, which a completely inert migrate would too.
		local data = { spraypaint = 5, NextLevelXP = 999 }
		Gateway.migrate(data)
		-- Mutation check: a migrate that re-ran the v1->v2 step on an already-v2 profile would double
		-- the shared bucket on every subsequent load. Asserting the exact value, not merely that
		-- `changed` came back falsy, is what catches that -- an idempotent-in-name-only migrate that
		-- quietly doubled spraypaintShared every call would still pass a bare falsy check.
		expect.falsy(Gateway.migrate(data))
		expect.equal(data.spraypaintShared, 5)
		expect.equal(next(data.spraypaint), nil)
	end)

	t.test("a v1 profile (version already stamped) migrates its scalar into the shared bucket", function()
		-- The literal case the design names: version explicitly 1 -- every profile that has loaded
		-- under the live v1 code, which is every real profile today -- not merely the theoretical
		-- no-version v0 case above.
		local data = { version = 1, spraypaint = 42 }
		expect.truthy(Gateway.migrate(data))
		expect.equal(data.version, 2)
		expect.equal(data.spraypaintShared, 42)
		expect.equal(typeof(data.spraypaint), "table")
		expect.equal(next(data.spraypaint), nil)
	end)

	t.test("a v1 profile that never earned Spraypaint migrates to an empty map and a zero shared bucket", function()
		-- No `spraypaint` field at all must not migrate to a shared balance out of nothing.
		local data = { version = 1 }
		Gateway.migrate(data)
		expect.equal(data.spraypaintShared, 0)
		expect.equal(next(data.spraypaint), nil)
	end)

	t.test("a v1 migration adds to an existing spraypaintShared rather than overwriting it", function()
		-- Reconcile runs before migrate and fills spraypaintShared from the template (0) on every real
		-- v1 profile, since the field is new in v2. Adding, rather than assuming zero, is what stops a
		-- migration step that somehow ran twice from silently dropping a balance instead of merely
		-- double-counting it.
		local data = { version = 1, spraypaint = 10, spraypaintShared = 5 }
		Gateway.migrate(data)
		expect.equal(data.spraypaintShared, 15)
	end)

	t.test("a derived field found in stored data is stripped", function()
		-- Older profiles, or a mirror bug, could have written one. Leaving it would let a stale value
		-- outlive and then contradict the thing it was derived from.
		local data = { version = Schema.VERSION, level = 3, NextLevelXP = 999 }
		expect.truthy(Gateway.migrate(data))
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

	t.test("a v0 profile with a leaked derived field gets both fixed in one pass", function()
		-- Neither branch's own case calls migrate with BOTH conditions true at once, so neither would
		-- catch a bug where handling one (for example via an early return) skips the other.
		local data = { spraypaint = 9, NextLevelXP = 500 }
		Gateway.migrate(data)
		expect.equal(data.version, Schema.VERSION)
		expect.equal(data.NextLevelXP, nil)
		expect.equal(data.spraypaintShared, 9)
		expect.equal(next(data.spraypaint), nil)
	end)

	t.test("migrate refuses to silently accept a version with no migration step", function()
		-- If VERSION is bumped without adding a step for the version a stored profile was written at,
		-- migrate must fail loudly rather than let mismatched-meaning data through unflagged.
		--
		-- The type check and the message check are both load-bearing. A bare expect.throws passes when
		-- Gateway.migrate is NIL, because calling nil throws -- so it cannot tell "migrate asserts
		-- correctly" from "migrate does not exist". That is not hypothetical: during Task 7's
		-- verification pass a stale module cache served a migrate-less gateway, four cases in this file
		-- failed with "attempt to call a nil value", and this one reported a clean pass throughout.
		expect.equal(typeof(Gateway.migrate), "function")
		local data = { version = -1 }
		local err = tostring(expect.throws(function() Gateway.migrate(data) end))
		expect.truthy(string.find(err, "no migration step for stored version", 1, true) ~= nil)
		expect.truthy(string.find(err, "-1", 1, true) ~= nil)
	end)

	t.test("a key already loaded in this server returns nil rather than throwing out of loadForKey", function()
		-- ProfileStore raises "Profile ... is already loaded in this session" instead of returning nil
		-- when the key is held by a live session in this same server -- what a rejoin hits inside the
		-- window between EndSession and the session actually ending. Unguarded, that throw escaped
		-- loadForKey and onPlayerAdded together, skipping the profile == nil kick.
		--
		-- The return value alone would not prove the fix: this asserts the OUTCOME the kick path
		-- depends on. loadForKey returns nil, the live session is left ACTIVE (the failed attempt
		-- neither ended nor stole it), and a write made after the failed attempt still saves.
		local key = "test-already-loaded-" .. os.clock()
		local first = Gateway.loadForKey(key)
		expect.truthy(first ~= nil)

		local second = Gateway.loadForKey(key)
		expect.equal(second, nil)
		expect.truthy(first:IsActive())

		first.Data.spraypaint = 5150
		first:EndSession()

		local reread = Gateway.loadForKey(key)
		expect.equal(reread.Data.spraypaint, 5150)
		reread:EndSession()
	end)

	t.test("a migrate failure ends the session and returns nil, rather than binding an unmigrated profile", function()
		-- Simulates a stored version with no migration step (migrate's own assert fires). loadForKey must
		-- not hand back a profile that failed to migrate, and must not leak the session lock doing so -- a
		-- leaked lock would push the player's very next load onto the contended-retry path instead of
		-- loading promptly.
		local key = "migrate-throws-" .. os.clock()
		local seed = Gateway.loadForKey(key)
		seed.Data.version = -1 -- no migration step exists for this version
		seed:EndSession()

		local failed = Gateway.loadForKey(key)
		expect.equal(failed, nil)

		-- The reload's `nil` proves nothing on its own, and this case used to assert only that. Delete
		-- `profile:EndSession()` from loadForKey and the reload still returns nil: the leaked session
		-- makes StartSessionAsync throw "already loaded", our own pcall swallows it, the attempts are
		-- exhausted and nil comes back for the WRONG reason. The old comment conceded it by asking a
		-- human to compare this case's duration against another -- a timing a person reads is not an
		-- assertion. The DURATION is the only thing that separates the two, so it is asserted here.
		--
		-- Freed lock: StartSessionAsync succeeds on attempt 1 and migrate throws again, so nil comes
		-- back in milliseconds. Leaked lock: three throwing attempts with RETRY_DELAY between them,
		-- ~4s. The 1s threshold sits four times below the failure and far above the success.
		local started = os.clock()
		local reread = Gateway.loadForKey(key)
		local elapsed = os.clock() - started
		expect.equal(reread, nil)
		if elapsed >= 1 then
			error(string.format(
				"reload took %.2fs, so it went down the contended-retry path: the failed attempt did not end the session",
				elapsed
			), 0)
		end
	end)
end
