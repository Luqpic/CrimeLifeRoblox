-- Tests for ReplicatedStorage.Renown.Constants.
-- The faction lookup carries the anti-farming rule, so it is tested harder than a data table usually
-- would be: anything that is not a recognised NPC faction must be worth zero.
return function(t)
	local Constants = require(game.ReplicatedStorage.Renown.Constants)
	local expect = t.expect

	t.test("the balance attribute is named Renown", function()
		expect.equal(Constants.ATTRIBUTE, "Renown")
	end)

	t.test("both NPC factions are worth something, and Police more than Criminal", function()
		expect.truthy(Constants.renownForFaction("Criminal") > 0)
		expect.truthy(Constants.renownForFaction("Police") > Constants.renownForFaction("Criminal"))
	end)

	t.test("a level-up is worth more than a single kill", function()
		expect.truthy(Constants.LEVEL_RENOWN > Constants.renownForFaction("Police"))
	end)

	t.test("PvP earns nothing -- nil faction is worth zero", function()
		-- A player's own character carries no Faction attribute, which is what excludes PvP. If this
		-- ever returns non-zero, two players can trade kills and print currency at will.
		expect.equal(Constants.renownForFaction(nil), 0)
	end)

	t.test("an unrecognised faction is worth zero", function()
		expect.equal(Constants.renownForFaction("Civilian"), 0)
		expect.equal(Constants.renownForFaction(""), 0)
	end)

	t.test("a non-string faction is worth zero and does not throw", function()
		expect.equal(Constants.renownForFaction(42), 0)
		expect.equal(Constants.renownForFaction({}), 0)
		expect.equal(Constants.renownForFaction(true), 0)
	end)

	t.test("ownedAttributeFor is stable and legal", function()
		expect.equal(Constants.ownedAttributeFor("Cobalt"), "SkinOwned_Cobalt")
	end)

	t.test("ownedAttributeFor sanitises characters Roblox rejects in an attribute name", function()
		-- Phase 1 measured that 16 of the 29 weapon names contain such characters. A palette key added
		-- later could too, and SetAttribute throws on them rather than failing quietly.
		local probe = Instance.new("Part")
		for _, key in { "Neon Blue", "Half-Life", "S&W", "a/b" } do
			local name = Constants.ownedAttributeFor(key)
			expect.truthy(pcall(function() probe:SetAttribute(name, true) end))
		end
	end)
end
