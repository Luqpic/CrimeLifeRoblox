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

	-- Final review 2026-11-17: a wanted player with no valid spawn point (an interior off the navmesh, a roof)
	-- costs one search per round, not one per owed officer; an alarm ring's miss falls through to the player
	-- ring once. The searches and the spawns go through PoliceDispatcher's seams, both restored.
	t.test("no valid spawn: one search per round (two with an alarm ring), whatever is owed", function()
		local savedFind, savedSpawn = PoliceDispatcher._findSpawn, PoliceDispatcher._spawnOfficer
		local calls, spawned = 0, 0
		PoliceDispatcher._spawnOfficer = function() spawned += 1 end
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(0, 5000, 0)
		root.Parent = model
		Instance.new("Humanoid").Parent = model
		model.Parent = Workspace
		local player = { Name = "StandIn", Character = model, GetAttribute = function(_, name)
			return if name == "WantedStars" then 5 else nil
		end }
		local ok, plain, alarm, found = pcall(function()
			PoliceDispatcher._findSpawn = function() calls += 1 return nil end
			PoliceDispatcher._spawnRound(player, 10, nil, 4, 6)
			local a = calls
			calls = 0
			PoliceDispatcher._spawnRound(player, 10, Vector3.new(0, 5000, 100), 4, 6)
			local b = calls
			calls = 0
			PoliceDispatcher._findSpawn = function() calls += 1 return Vector3.new(0, 5000, 50) end
			PoliceDispatcher._spawnRound(player, 3, nil, 4, 6)
			return a, b, calls
		end)
		model:Destroy()
		PoliceDispatcher._findSpawn, PoliceDispatcher._spawnOfficer = savedFind, savedSpawn
		expect.truthy(ok)
		expect.equal(plain, 1)
		expect.equal(alarm, 2)
		expect.equal(found, 3)
		expect.equal(spawned, 3)
	end)

	-- Slow fill fix (2026-11-17): only path checks are budgeted, SPAWN_PATH_BUDGET per player per round.
	t.test("a round spends at most SPAWN_PATH_BUDGET path checks; cheap misses spend none", function()
		local saved = { PoliceDispatcher._cheapReason, PoliceDispatcher._reaches, PoliceDispatcher._spawnOfficer }
		local paths, spawned = 0, 0
		PoliceDispatcher._spawnOfficer = function() spawned += 1 end
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(0, 5000, 0)
		root.Parent = model
		Instance.new("Humanoid").Parent = model
		model.Parent = Workspace
		local player = { Name = "StandIn", Character = model, GetAttribute = function(_, name)
			return if name == "WantedStars" then 5 else nil
		end }
		local results = {}
		local ok = pcall(function()
			-- every sample passes the cheap checks; no path leads anywhere
			PoliceDispatcher._cheapReason = function() return nil end
			PoliceDispatcher._reaches = function() paths += 1 return false end
			PoliceDispatcher._spawnRound(player, 10, road, 4, 6)
			results.noPath = { paths, spawned }
			paths, spawned = 0, 0
			-- every path leads: one path check per officer
			PoliceDispatcher._reaches = function() paths += 1 return true end
			PoliceDispatcher._spawnRound(player, 10, road, 4, 6)
			results.allPath = { paths, spawned }
			paths, spawned = 0, 0
			-- every sample is in sight: no path check at all
			PoliceDispatcher._cheapReason = function() return "sight" end
			PoliceDispatcher._spawnRound(player, 10, road, 4, 6)
			results.inSight = { paths, spawned }
		end)
		model:Destroy()
		PoliceDispatcher._cheapReason, PoliceDispatcher._reaches, PoliceDispatcher._spawnOfficer = table.unpack(saved)
		expect.truthy(ok)
		expect.equal(results.noPath[1], Constants.SPAWN_PATH_BUDGET)
		expect.equal(results.noPath[2], 0)
		expect.equal(results.allPath[1], 10)
		expect.equal(results.allPath[2], 10)
		expect.equal(results.inSight[1], 0)
		expect.equal(results.inSight[2], 0)
	end)
end
