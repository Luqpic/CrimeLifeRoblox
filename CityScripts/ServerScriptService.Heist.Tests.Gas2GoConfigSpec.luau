local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.Gas2GoShared.Config)
	local suite = TestRunner.new("Gas2GoConfig")

	suite:test("carries the spec's tunables", function(expect)
		expect.equal(Config.SessionDuration, 300, "SessionDuration (5 minutes)")
		expect.equal(Config.CooldownDuration, 600, "CooldownDuration (10 minutes)")
		expect.equal(Config.DuffelCap, 4000, "DuffelCap (matches SlowFoods' base)")
		expect.equal(Config.AccrualPerSecond, 0, "no time-based accrual at Gas2Go")
		expect.equal(Config.RegisterRobAmount, 2000, "RegisterRobAmount")
		expect.equal(Config.ATMRobAmount, 3000, "ATMRobAmount")
		expect.equal(Config.HeartbeatRate, 10, "HeartbeatRate")
		expect.falsy(Config.Debug.FastLifecycle, "FastLifecycle default off")
	end)

	-- Heist layers 2026-11-17 (Task 4): the ATM rip-out.
	suite:test("carries the ATM rip-out values", function(expect)
		expect.equal(Config.ATMRipAmount, 9000, "ATMRipAmount (3x the rob)")
		expect.equal(Config.ATMRipHold, 10, "ATMRipHold")
	end)

	-- Deliberately independent from HeistShared.Config AND RestaurantShared.
	-- Config: changing one location's balance must never move another's
	-- numbers.
	suite:test("is a separate module instance from the Bank's and SlowFoods' Config", function(expect)
		local BankConfig = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
		local RestaurantConfig = TestRunner.freshRequire(game.ReplicatedStorage.RestaurantShared.Config)
		expect.truthy(Config ~= BankConfig, "distinct from the Bank's Config")
		expect.truthy(Config ~= RestaurantConfig, "distinct from SlowFoods' Config")
		expect.truthy(Config.SessionDuration ~= BankConfig.SessionDuration,
			"different session duration than the Bank (300 vs " .. tostring(BankConfig.SessionDuration) .. ")")
		expect.truthy(Config.SessionDuration ~= RestaurantConfig.SessionDuration,
			"different session duration than SlowFoods (300 vs " .. tostring(RestaurantConfig.SessionDuration) .. ")")
		-- Same numeric rob amounts as the Bank/SlowFoods are confirmed correct
		-- (not a coincidence to "fix") -- but they must still be Gas2Go's OWN
		-- entries, never read through another location's Config table.
		expect.equal(Config.RegisterRobAmount, RestaurantConfig.RegisterRobAmount,
			"happens to match SlowFoods' register amount, but is its own separate value")
		expect.equal(Config.ATMRobAmount, BankConfig.ATMRobAmount,
			"happens to match the Bank's ATM amount, but is its own separate value")
	end)

	suite:test("effective() shortens the lifecycle only in debug", function(expect)
		expect.equal(Config.effective("SessionDuration"), 300, "normal session")
		Config.Debug.FastLifecycle = true
		expect.equal(Config.effective("SessionDuration"), 10, "fast session")
		expect.equal(Config.effective("CooldownDuration"), 20, "fast cooldown")
		Config.Debug.FastLifecycle = false
	end)

	suite:test("is frozen against accidental writes to tunables", function(expect)
		expect.throws(function() Config.DuffelCap = 1 end, "DuffelCap immutable")
	end)

	return suite:run()
end
