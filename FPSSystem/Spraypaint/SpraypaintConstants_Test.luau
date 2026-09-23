-- Tests for ReplicatedStorage.Spraypaint.Constants.
-- The faction lookup carries the anti-farming rule, so it is tested harder than a data table usually
-- would be: anything that is not a recognised NPC faction must be worth zero.
return function(t)
	local Constants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local expect = t.expect

	t.test("the shared-bucket attribute is named SpraypaintShared", function()
		expect.equal(Constants.SHARED_ATTRIBUTE, "SpraypaintShared")
	end)

	t.test("balanceAttributeFor is stable and legal", function()
		expect.equal(Constants.balanceAttributeFor("AK47"), "Spraypaint_AK47")
	end)

	t.test("balanceAttributeFor sanitises characters Roblox rejects in an attribute name", function()
		-- Same trap ownedAttributeFor's own test guards against: 16 of the 29 weapon names contain
		-- characters SetAttribute rejects outright.
		local probe = Instance.new("Part")
		for _, name in { "Neon Blue", "Half-Life", "S&W", "a/b" } do
			local attributeName = Constants.balanceAttributeFor(name)
			expect.truthy(pcall(function() probe:SetAttribute(attributeName, 0) end))
		end
	end)

	t.test("balanceAttributeFor is distinct per weapon and distinct from ownedAttributeFor's namespace", function()
		-- Two different weapons must never collide on one balance attribute, and a weapon named the
		-- same as a palette key must not collide with SkinOwned_ either -- both would silently merge
		-- two players' -- or two currencies' -- state onto one attribute.
		expect.truthy(Constants.balanceAttributeFor("AK47") ~= Constants.balanceAttributeFor("M4A1"))
		expect.truthy(Constants.balanceAttributeFor("Cobalt") ~= Constants.ownedAttributeFor("Cobalt"))
	end)

	t.test("both NPC factions are worth something, and Police more than Criminal", function()
		expect.truthy(Constants.spraypaintForFaction("Criminal") > 0)
		expect.truthy(Constants.spraypaintForFaction("Police") > Constants.spraypaintForFaction("Criminal"))
	end)

	t.test("a level-up is worth more than a single kill", function()
		expect.truthy(Constants.LEVEL_SPRAYPAINT > Constants.spraypaintForFaction("Police"))
	end)

	t.test("PvP earns nothing -- nil faction is worth zero", function()
		-- A player's own character carries no Faction attribute, which is what excludes PvP. If this
		-- ever returns non-zero, two players can trade kills and print currency at will.
		expect.equal(Constants.spraypaintForFaction(nil), 0)
	end)

	t.test("an unrecognised faction is worth zero", function()
		expect.equal(Constants.spraypaintForFaction("Civilian"), 0)
		expect.equal(Constants.spraypaintForFaction(""), 0)
	end)

	t.test("a non-string faction is worth zero and does not throw", function()
		expect.equal(Constants.spraypaintForFaction(42), 0)
		expect.equal(Constants.spraypaintForFaction({}), 0)
		expect.equal(Constants.spraypaintForFaction(true), 0)
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
