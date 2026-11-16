-- EnemyAI's target filter, canSee and the live registry (police and wanted, Task 2, 2026-11-17).
--
-- _findVisibleTarget runs on a fake enemy (a table with EnemyAI's methods) over stand-in players served
-- through the EnemyAI._players seam. ShotResolver.hasLineOfSight is stubbed to "clear" so only the filter
-- and the distance decide; both are restored even if a case throws. Stand-ins are real Models (the AI reads
-- Humanoid.RootPart), parked high above the map and destroyed at the end.
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")
	local EnemyAI = require(ServerScriptService.Enemy.Scripts.EnemyAI)
	local ShotResolver = require(ServerScriptService.Blaster.Scripts.ShotResolver)
	local expect = t.expect

	local savedPlayers, savedSight = EnemyAI._players, ShotResolver.hasLineOfSight
	local folder = Instance.new("Folder")
	folder.Name = "TmpEnemyTargetFilter"
	folder.Parent = Workspace

	local ok, err = pcall(function()
		local function standIn(name: string, x: number)
			local model = Instance.new("Model")
			model.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Position = Vector3.new(x, 5000, 0)
			root.Parent = model
			Instance.new("Humanoid").Parent = model
			model.Parent = folder
			return { Name = name, Character = model }
		end
		local near, far = standIn("Near", 10), standIn("Far", 20)
		EnemyAI._players = function() return { far, near } end
		ShotResolver.hasLineOfSight = function() return true end

		local function fakeEnemy(filter)
			local enemy = setmetatable({ character = Instance.new("Model"), config = { detectionRadius = 100, targetFilter = filter } }, EnemyAI)
			enemy._eyePosition = function() return Vector3.new(0, 5000, 0) end
			return enemy
		end

		t.test("no filter (every gang): the nearest visible player, as before", function()
			expect.equal(fakeEnemy(nil):_findVisibleTarget(), near)
		end)

		t.test("a filter that refuses a stand-in makes _findVisibleTarget skip it", function()
			expect.equal(fakeEnemy(function(p) return p ~= near end):_findVisibleTarget(), far)
			expect.equal(fakeEnemy(function() return false end):_findVisibleTarget(), nil)
		end)

		t.test("a target the filter refuses mid-fight is dropped (no humanoid to chase or shoot)", function()
			local wanted = true
			local enemy = fakeEnemy(function() return wanted end)
			enemy.target = near
			expect.truthy(enemy:_targetHumanoid())
			wanted = false
			expect.equal(enemy:_targetHumanoid(), nil)
		end)

		t.test("canSee is a strict boolean from the line-of-sight check", function()
			local enemy = fakeEnemy(nil)
			expect.equal(enemy:canSee(near.Character), true)
			ShotResolver.hasLineOfSight = function() return false end
			expect.equal(enemy:canSee(near.Character), false)
			expect.equal(enemy:canSee(Instance.new("Model")), false)
		end)

		t.test("getLive lists live enemies only (a fake live, a fake dead and a fake destroyed enemy)", function()
			-- Put in and taken out within one resume, so the scheduler never sees them (and nextThinkTime is huge).
			local active = EnemyAI._activeEnemies
			local alive = { state = EnemyAI.State.Patrol, destroyed = false, nextThinkTime = math.huge }
			local dead = { state = EnemyAI.State.Dead, destroyed = false, nextThinkTime = math.huge }
			local gone = { state = EnemyAI.State.Patrol, destroyed = true, nextThinkTime = math.huge }
			active[alive], active[dead], active[gone] = true, true, true
			local live = EnemyAI.getLive()
			active[alive], active[dead], active[gone] = nil, nil, nil
			expect.truthy(table.find(live, alive))
			expect.equal(table.find(live, dead), nil)
			expect.equal(table.find(live, gone), nil)
		end)

		t.test("onDamagedBy: no retaliation against a player the filter refuses", function()
			local real = game:GetService("Players"):GetPlayers()[1]
			expect.truthy(real and real.Character)
			local refusing = fakeEnemy(function() return false end)
			refusing.state = EnemyAI.State.Patrol
			refusing:onDamagedBy(real)
			expect.equal(refusing.target, nil)
			expect.equal(refusing.state, EnemyAI.State.Patrol)
			local accepting = fakeEnemy(nil)
			accepting.state = EnemyAI.State.Patrol
			accepting:onDamagedBy(real)
			expect.equal(accepting.target, real)
		end)

		t.test("prefers its own squad's player when visible, else the nearest it accepts", function()
			ShotResolver.hasLineOfSight = function() return true end -- the canSee case left it "blocked"
			local enemy = fakeEnemy(nil)
			expect.equal(enemy:_findVisibleTarget(), near) -- without a preference: the nearest
			enemy.config.preferTarget = function() return far end
			expect.equal(enemy:_findVisibleTarget(), far)
			-- preferred but out of sight: the nearest visible one
			ShotResolver.hasLineOfSight = function(_, _, humanoid) return humanoid.Parent ~= far.Character end
			expect.equal(enemy:_findVisibleTarget(), near)
			ShotResolver.hasLineOfSight = function() return true end
			-- preferred but refused by the filter: never taken
			enemy.config.targetFilter = function(p) return p ~= far end
			expect.equal(enemy:_findVisibleTarget(), near)
		end)

		t.test("investigate heads a patrolling or searching enemy for the point; a chasing one ignores it", function()
			local enemy = fakeEnemy(nil)
			enemy.state = EnemyAI.State.Patrol
			local point = Vector3.new(10, 0, 20)
			enemy:investigate(point)
			expect.equal(enemy.state, EnemyAI.State.Search)
			expect.equal(enemy.lastKnownPosition, point)
			expect.truthy(enemy.searchUntil > os.clock())
			local chasing = fakeEnemy(nil)
			chasing.state = EnemyAI.State.Chase
			chasing:investigate(point)
			expect.equal(chasing.state, EnemyAI.State.Chase)
			expect.equal(chasing.lastKnownPosition, nil)
		end)
	end)
	EnemyAI._players, ShotResolver.hasLineOfSight = savedPlayers, savedSight
	folder:Destroy()
	if not ok then error(err, 0) end
end
