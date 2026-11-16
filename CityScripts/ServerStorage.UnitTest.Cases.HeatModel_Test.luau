-- Pure heat arithmetic for the wanted level (police and wanted, Task 1, 2026-11-17).
return function(t)
	local HeatModel = require(game:GetService("ReplicatedStorage").Wanted.HeatModel)
	local expect = t.expect

	t.test("raise clamps at 5 and at 0", function()
		expect.equal(HeatModel.raise(4.5, 1), 5)
		expect.equal(HeatModel.raise(5, 0.25), 5)
		expect.equal(HeatModel.raise(0.5, -2), 0)
		expect.equal(HeatModel.raise(1, 0.25), 1.25)
	end)

	t.test("stars is the whole part of heat", function()
		expect.equal(HeatModel.stars(2.75), 2)
		expect.equal(HeatModel.stars(0.5), 0)
		expect.equal(HeatModel.stars(5), 5)
	end)

	t.test("atLeast raises to the level and never lowers", function()
		expect.equal(HeatModel.atLeast(0.5, 1), 1)
		expect.equal(HeatModel.atLeast(3.2, 1), 3.2)
	end)

	t.test("drainStep drops to the integer below, or by 1 when integral, not below 0", function()
		expect.equal(HeatModel.drainStep(2.75), 2)
		expect.equal(HeatModel.drainStep(2), 1)
		expect.equal(HeatModel.drainStep(0.25), 0)
		expect.equal(HeatModel.drainStep(0), 0)
	end)
end
