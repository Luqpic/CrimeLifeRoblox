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

		t.test("getLive lists live enemies only", function()
			for _, enemy in EnemyAI.getLive() do
				expect.truthy(not enemy.destroyed and enemy.state ~= EnemyAI.State.Dead)
				expect.truthy(enemy.character)
			end
		end)
	end)
	EnemyAI._players, ShotResolver.hasLineOfSight = savedPlayers, savedSight
	folder:Destroy()
	if not ok then error(err, 0) end
end
