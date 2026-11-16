-- PoliceDispatcher.isValidSpawn: the box and ground checks (police and wanted, Task 2, 2026-11-17).
-- Without a player only these run; the line-of-sight and pathfinding checks need a real character and are
-- checked in Play. Points measured in the city on 2026-11-17: the road west of SlowFoods tops at y 1.0
-- (Map.City.Roads.Road at x -20, z 1723.8); a spawn point stands SPAWN_HEIGHT above its ground.
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local PoliceDispatcher = require(ServerScriptService.Wanted.PoliceDispatcher)
	local Constants = require(ReplicatedStorage.Wanted.Constants)
	local expect = t.expect

	local up = Vector3.new(0, Constants.SPAWN_HEIGHT, 0)
	local road = Vector3.new(-20, 1, 1723.8) + up

	t.test("a point on the road is accepted", function()
		expect.equal(PoliceDispatcher.isValidSpawn(road, nil), true)
	end)

	t.test("a point inside a plot's box is refused", function()
		local plot = Workspace.Plots.Plot1
		local ok, why = PoliceDispatcher.isValidSpawn(plot.Position + up, nil)
		expect.equal(ok, false)
		expect.equal(why, "plot")
	end)

	t.test("a point inside a robbery building's box is refused (a location root and Map.Robbery)", function()
		local ok, why = PoliceDispatcher.isValidSpawn(Vector3.new(78.6, 1, 1753.5) + up, nil) -- inside SlowFoods
		expect.equal(ok, false)
		expect.equal(why, "robbery")
		local casino = Workspace.Map.Robbery.CasinoMain:GetBoundingBox()
		ok, why = PoliceDispatcher.isValidSpawn(casino.Position, nil)
		expect.equal(ok, false)
		expect.equal(why, "robbery")
	end)

	t.test("a point in the air above the road is refused", function()
		local ok, why = PoliceDispatcher.isValidSpawn(road + Vector3.new(0, 60, 0), nil)
		expect.equal(ok, false)
		expect.equal(why, "ground")
	end)
end
