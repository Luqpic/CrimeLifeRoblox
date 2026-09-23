-- Tests for ReplicatedStorage.Persistence.Schema.
-- The template is the contract every service hydrates from, so these assert its shape and, more
-- importantly, that nothing DERIVED has crept into it.
return function(t)
	local Schema = require(game.ReplicatedStorage.Persistence.Schema)
	local expect = t.expect

	t.test("VERSION is a positive integer", function()
		expect.equal(typeof(Schema.VERSION), "number")
		expect.truthy(Schema.VERSION >= 1)
		expect.equal(Schema.VERSION % 1, 0)
	end)

	t.test("the template carries every field the spec names", function()
		for _, field in { "spraypaint", "spraypaintShared", "skinsOwned", "equippedSkin", "cash", "level", "xp",
		                  "kills", "weaponsOwned", "weaponUpgrades", "loadout" } do
			expect.truthy(Schema.template[field] ~= nil)
		end
	end)

	t.test("scalar defaults are sane for a brand new player", function()
		expect.equal(Schema.template.spraypaintShared, 0)
		-- Cash is the one non-zero starting balance: CashService.STARTING_CASH reads this value
		-- directly (fix round 1), so a new player actually receives it rather than an empty wallet.
		-- Pinned to the literal 500, not read back from the template and compared to itself, so this
		-- still fails if someone changes the starting balance to something a new player should not get.
		expect.equal(Schema.template.cash, 500)
		expect.equal(Schema.template.level, 1)
		expect.equal(Schema.template.xp, 0)
	end)

	t.test("every table default is empty, not shared", function()
		-- A shared table in a template is how one player's progress leaks into another's: every
		-- profile would reference the same table. ProfileStore deep-copies, but the template itself
		-- must still start empty or a new player inherits whatever was written last.
		for _, field in { "spraypaint", "skinsOwned", "equippedSkin", "kills", "weaponsOwned", "weaponUpgrades", "loadout" } do
			expect.equal(typeof(Schema.template[field]), "table")
			expect.equal(next(Schema.template[field]), nil)
		end
	end)

	t.test("no derived field appears in the template", function()
		-- A persisted derivative outlives the thing it was derived from and then disagrees with it.
		for _, derived in Schema.DERIVED do
			expect.equal(Schema.template[derived], nil)
		end
	end)

	t.test("DERIVED names the five values the spec excludes", function()
		local named = {}
		for _, d in Schema.DERIVED do named[d] = true end
		for _, d in { "NextLevelXP", "SkinId", "damage", "catalogue", "lastLevel" } do
			expect.truthy(named[d])
		end
	end)

	t.test("the template holds no functions or instances", function()
		-- DataStores serialise neither, and a template that cannot round-trip fails at save time
		-- rather than here, which is far too late.
		for key, value in Schema.template do
			expect.falsy(typeof(value) == "function" or typeof(value) == "Instance")
		end
	end)

	t.test("version is never part of the template", function()
		-- Reconcile fills anything present in the template, unconditionally, for every profile including
		-- a v0 one. If `version` ever became a template field, Reconcile would stamp every v0 profile
		-- current BEFORE ProfileGateway.migrate ever saw it, and version-based migration would die
		-- silently with no test here to catch it.
		expect.equal(Schema.template.version, nil)
	end)
end
