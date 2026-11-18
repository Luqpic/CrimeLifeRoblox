-- RunUnitTest's filter: a plain string still runs every case module whose name contains it (unanchored,
-- no patterns); a filter that starts with "=" runs only the module named exactly the rest.
return function(t)
	local RunUnitTest = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
	local expect = t.expect

	t.test("a plain filter still matches any part of the name, nil matches all", function()
		expect.truthy(RunUnitTest.matches("SpraypaintTier_Test", "Tier"))
		expect.truthy(RunUnitTest.matches("SpraypaintTier_Test", nil))
		expect.truthy(RunUnitTest.matches("Palettes_Test", "s_T"))
		expect.falsy(RunUnitTest.matches("SpraypaintTier_Test", "Palettes"))
	end)

	t.test("a filter starting with = matches the whole name only", function()
		expect.truthy(RunUnitTest.matches("Palettes_Test", "=Palettes_Test"))
		expect.falsy(RunUnitTest.matches("SpraypaintPalettes_Test", "=Palettes_Test"))
		expect.falsy(RunUnitTest.matches("Palettes_Test", "=Palettes"))
	end)
end
