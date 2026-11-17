local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Heist layers 2026-11-17 (Task 6): the Bank's deposit boxes. DepositBoxLoot.roll is pure: at most
-- one gold bar per run (chance goldChance), the rest two thirds cash and one third empty.
return function()
	local DepositBoxLoot = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.DepositBoxLoot)
	local Config = require(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("DepositBoxLoot")

	local function count(list, kind)
		local n = 0
		for _, v in ipairs(list) do
			if v == kind then n += 1 end
		end
		return n
	end

	suite:test("Config holds the deposit box numbers", function(expect)
		expect.equal(Config.DepositBoxCount, 8, "DepositBoxCount")
		expect.equal(Config.DepositBoxCash, 1500, "DepositBoxCash")
		expect.equal(Config.GoldBarChance, 0.5, "GoldBarChance")
		expect.equal(Config.GoldBarValue, 8000, "GoldBarValue")
		expect.falsy(Config.Debug.DepositBoxContents, "no forced contents by default")
	end)

	suite:test("a roll has count entries, each cash, empty or gold, at most one gold", function(expect)
		local rng = Random.new(1)
		for _ = 1, 200 do
			local roll = DepositBoxLoot.roll(rng, 8, 0.5)
			expect.equal(#roll, 8, "length")
			expect.truthy(count(roll, "gold") <= 1, "at most one gold")
			expect.equal(count(roll, "cash") + count(roll, "empty") + count(roll, "gold"), 8, "only known kinds")
		end
	end)

	suite:test("over 2000 seeded runs: gold in half the runs, two thirds of the rest cash", function(expect)
		local rng = Random.new(20261117)
		local runsWithGold, cash, nonGold = 0, 0, 0
		for _ = 1, 2000 do
			local roll = DepositBoxLoot.roll(rng, 8, 0.5)
			if count(roll, "gold") == 1 then runsWithGold += 1 end
			cash += count(roll, "cash")
			nonGold += count(roll, "cash") + count(roll, "empty")
		end
		expect.near(runsWithGold / 2000, 0.5, 0.05, "share of runs with gold")
		expect.near(cash / nonGold, 2 / 3, 0.05, "cash share of non-gold boxes")
	end)

	suite:test("goldChance 0 never rolls gold", function(expect)
		local rng = Random.new(7)
		for _ = 1, 200 do
			expect.equal(count(DepositBoxLoot.roll(rng, 8, 0), "gold"), 0, "no gold")
		end
	end)

	suite:test("goldChance 1 rolls exactly one gold", function(expect)
		local rng = Random.new(9)
		for _ = 1, 200 do
			expect.equal(count(DepositBoxLoot.roll(rng, 8, 1), "gold"), 1, "one gold")
		end
	end)

	return suite:run()
end
