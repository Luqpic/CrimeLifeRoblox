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
		for _, field in { "spraypaint", "skinsOwned", "equippedSkin", "cash", "level", "xp",
		                  "kills", "weaponsOwned", "weaponUpgrades", "loadout" } do
			expect.truthy(Schema.template[field] ~= nil)
		end
	end)

	t.test("scalar defaults are sane for a brand new player", function()
		expect.equal(Schema.template.spraypaint, 0)
		expect.equal(Schema.template.cash, 0)
		expect.equal(Schema.template.level, 1)
		expect.equal(Schema.template.xp, 0)
	end)

	t.test("every table default is empty, not shared", function()
		-- A shared table in a template is how one player's progress leaks into another's: every
		-- profile would reference the same table. ProfileStore deep-copies, but the template itself
		-- must still start empty or a new player inherits whatever was written last.
		for _, field in { "skinsOwned", "equippedSkin", "kills", "weaponsOwned", "weaponUpgrades", "loadout" } do
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
end
