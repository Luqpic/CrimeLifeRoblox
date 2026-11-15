-- Tests for Blaster.validateFireInterval: the server's rate-of-fire rule on the CLAIMED timestamps.
-- rateOfFire is rounds per minute (BlasterController waits 60 / rateOfFire between Shoot events in
-- every fire mode), and a shot is refused when it comes less than 0.9 of that interval after the last
-- accepted shot from the same tool.
return function(t)
	local validateFireInterval = require(game:GetService("ServerScriptService").Blaster.Scripts.Blaster.validateFireInterval)
	local expect = t.expect
	local RATE = 600 -- AK47: one round every 0.1 s
	local interval = 60 / RATE

	t.test("the first shot passes", function()
		expect.truthy(validateFireInterval(nil, 100, RATE))
	end)
	t.test("a shot one interval after the last passes", function()
		expect.truthy(validateFireInterval(100, 100 + interval, RATE))
	end)
	t.test("a shot half an interval after the last is refused", function()
		expect.falsy(validateFireInterval(100, 100 + 0.5 * interval, RATE))
	end)
	t.test("a second shot with the same timestamp is refused", function()
		expect.falsy(validateFireInterval(100, 100, RATE))
	end)
	t.test("a NaN timestamp is refused", function()
		expect.falsy(validateFireInterval(nil, 0 / 0, RATE))
		expect.falsy(validateFireInterval(100, 0 / 0, RATE))
	end)
end
