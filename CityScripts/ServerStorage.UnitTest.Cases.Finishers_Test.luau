-- Wounded finishers and stealth takedowns (combat, 2026-11-20): ServerScriptService.Enemy.Scripts.Finishers.
return function(t)
	local Finishers = require(game:GetService("ServerScriptService").Enemy.Scripts.Finishers)
	local expect = t.expect

	t.test("isBehind: within range and outside the enemy's front half-cone only", function()
		local enemy = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1)) -- looking toward -z
		expect.equal(Finishers.isBehind(enemy, Vector3.new(0, 0, 3), 5), true)
		expect.equal(Finishers.isBehind(enemy, Vector3.new(1, 0, 3), 5), true)
		expect.equal(Finishers.isBehind(enemy, Vector3.new(0, 0, -3), 5), false)
		expect.equal(Finishers.isBehind(enemy, Vector3.new(3, 0, 0), 5), false)
		expect.equal(Finishers.isBehind(enemy, Vector3.new(0, 0, 6), 5), false)
	end)

	t.test("request: refuses a model that is not a tagged enemy", function()
		local player = game:GetService("Players"):GetPlayers()[1]
		expect.truthy(player)
		local model = Instance.new("Model")
		Instance.new("Humanoid").Parent = model
		expect.equal(Finishers.request(player, model, "Finish"), false)
		expect.equal(Finishers.request(player, "nope", "Takedown"), false)
		model:Destroy()
	end)
end
