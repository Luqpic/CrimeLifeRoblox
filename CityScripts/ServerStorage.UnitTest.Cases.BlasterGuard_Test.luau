-- Tests for Blaster.validateShootArguments: the claimed-hits table may name each ray only once, in the
-- spelling the real client uses (tostring(index), BlasterController). tonumber folds "01", "1.0", "1e0"
-- and others onto ray 1, so without this one ray could be claimed many times against one humanoid.
return function(t)
	local validateShootArguments = require(game:GetService("ServerScriptService").Blaster.Scripts.Blaster.validateShootArguments)
	local expect = t.expect
	local tool = Instance.new("Tool")
	local humanoid = Instance.new("Humanoid")
	local function accepted(tagged)
		return validateShootArguments(workspace:GetServerTimeNow(), tool, CFrame.new(), tagged)
	end

	t.test("the real client's keys, tostring(index), pass", function()
		local tagged = {}
		for index = 1, 8 do
			tagged[tostring(index)] = humanoid
		end
		expect.truthy(accepted(tagged))
	end)
	t.test("a shot that claims no hit passes", function()
		expect.truthy(accepted({}))
	end)
	t.test("two spellings of the same ray are refused", function()
		expect.falsy(accepted({ ["1"] = humanoid, ["01"] = humanoid }))
	end)
	t.test("a non-canonical spelling of a ray is refused", function()
		for _, key in { "1e0", "1.0", " 1", "+1", "0x1" } do
			expect.falsy(accepted({ [key] = humanoid }))
		end
	end)
end
