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

	t.test("a point on the city baseplate off the road is refused (Workspace.Ground is not road)", function()
		-- (-800, 0, 900): Workspace.Ground.Baseplate's top, west of NewsStation, measured 2026-11-17
		local ok, why = PoliceDispatcher.isValidSpawn(Vector3.new(-800, 0, 900) + up, nil)
		expect.equal(ok, false)
		expect.equal(why, "ground")
	end)

	t.test("sight: glass and a thin pole do not hide an officer; a wall does", function()
		local folder = Instance.new("Folder")
		folder.Name = "TmpPoliceSight"
		folder.Parent = Workspace
		local results = {}
		local okRun, err = pcall(function()
			local eye, spot = Vector3.new(0, 5000, 0), Vector3.new(0, 5000, 30)
			local function block(size: Vector3, transparency: number)
				folder:ClearAllChildren()
				local part = Instance.new("Part")
				part.Anchored, part.Size, part.Transparency = true, size, transparency
				part.Position = Vector3.new(0, 5000, 15)
				part.Parent = folder
			end
			folder:ClearAllChildren()
			results.open = PoliceDispatcher._inSight(eye, spot)
			block(Vector3.new(20, 20, 1), 0)
			results.wall = PoliceDispatcher._inSight(eye, spot)
			block(Vector3.new(20, 20, 1), 0.5)
			results.glass = PoliceDispatcher._inSight(eye, spot)
			block(Vector3.new(1, 20, 1), 0)
			results.pole = PoliceDispatcher._inSight(eye, spot)
		end)
		folder:Destroy()
		if not okRun then error(err, 0) end
		expect.equal(results.open, true)
		expect.equal(results.wall, false)
		expect.equal(results.glass, true)
		expect.equal(results.pole, true)
	end)

	t.test("a point in the air above the road is refused", function()
		local ok, why = PoliceDispatcher.isValidSpawn(road + Vector3.new(0, 60, 0), nil)
		expect.equal(ok, false)
		expect.equal(why, "ground")
	end)
end
