-- Weapon gacha (2026-11-20): ReplicatedStorage.Gacha.Draw and Config.
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Draw = require(ReplicatedStorage.Gacha.Draw)
	local Config = require(ReplicatedStorage.Gacha.Config)
	local expect = t.expect
	local STANDARD, PREMIUM = Config.ODDS.Standard, Config.ODDS.Premium

	t.test("odds add up to 1 for both crates, and the page text shows them", function()
		for _, crate in { "Standard", "Premium" } do
			local sum = 0
			for _, chance in Config.ODDS[crate] do
				sum += chance
			end
			expect.near(sum, 1, 1e-9)
		end
		expect.equal(Config.oddsText("Standard"), "Common 60%, Rare 28%, Epic 10%, Legendary 2%")
		expect.equal(Config.oddsText("Premium"), "Rare 72%, Epic 22%, Legendary 6%")
	end)

	t.test("a uniform number picks by cumulative odds; the Premium crate never gives a Common", function()
		expect.equal(Draw.rarity(0.0, STANDARD, 0, 0, 30, 100), "Common")
		expect.equal(Draw.rarity(0.59, STANDARD, 0, 0, 30, 100), "Common")
		expect.equal(Draw.rarity(0.61, STANDARD, 0, 0, 30, 100), "Rare")
		expect.equal(Draw.rarity(0.89, STANDARD, 0, 0, 30, 100), "Epic")
		expect.equal(Draw.rarity(0.99, STANDARD, 0, 0, 30, 100), "Legendary")
		expect.equal(Draw.rarity(0.999999, STANDARD, 0, 0, 30, 100), "Legendary")
		expect.equal(Draw.rarity(0.0, PREMIUM, 0, 0, 30, 100), "Rare")
		expect.equal(Draw.rarity(0.95, PREMIUM, 0, 0, 30, 100), "Legendary")
	end)

	t.test("pity: the 30th roll without an Epic is at least Epic, the 100th without a Legendary is Legendary", function()
		expect.equal(Draw.rarity(0.0, STANDARD, 28, 28, 30, 100), "Common")
		expect.equal(Draw.rarity(0.0, STANDARD, 29, 29, 30, 100), "Epic")
		expect.equal(Draw.rarity(0.0, STANDARD, 5, 99, 30, 100), "Legendary")
		local a, b = Draw.advance("Epic", 12, 40)
		expect.equal(a, 0)
		expect.equal(b, 41)
		a, b = Draw.advance("Legendary", 12, 40)
		expect.equal(a + b, 0)
		a, b = Draw.advance("Common", 12, 40)
		expect.equal(a, 13)
		expect.equal(b, 41)
	end)

	t.test("ten rolls hold at least one Rare; 100 all-Common draws still reach Epics and a Legendary", function()
		local rarities = Draw.roll(10, STANDARD, 0, 0, function() return 0 end, 30, 100)
		expect.equal(#rarities, 10)
		expect.equal(rarities[10], "Rare")
		local got = {}
		local e, l = 0, 0
		rarities, e, l = Draw.roll(100, STANDARD, 0, 0, function() return 0 end, 30, 100)
		for _, rarity in rarities do
			got[rarity] = (got[rarity] or 0) + 1
		end
		expect.equal(rarities[30], "Epic")
		expect.equal(rarities[100], "Legendary")
		expect.equal(got.Legendary, 1)
		expect.equal(e + l, 0)
	end)

	t.test("a weapon's rarity: its attribute, else its old price; none for a gamepass weapon", function()
		local tool = Instance.new("Tool")
		tool:SetAttribute("Price", 600)
		expect.equal(Config.rarityOf(tool), "Rare")
		tool:SetAttribute("Rarity", "Legendary")
		expect.equal(Config.rarityOf(tool), "Legendary")
		tool:SetAttribute("Gamepass", "RPG")
		expect.equal(Config.rarityOf(tool), nil)
		expect.equal(Config.rarityForPrice(450), "Common")
		expect.equal(Config.rarityForPrice(951), "Legendary")
	end)
end
