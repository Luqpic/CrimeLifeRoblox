-- validateTag (hit registration fix, 2026-11-20): a claimed hit passes when the ray runs within 10 studs of the
-- target's pivot, measured sideways from the ray, and the pivot is at most 3 studs behind the ray's start. Up close
-- the old angle rule refused real hits while the player moved. Uses the real Play player as the shooter.
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ENEMY_TAG = require(ReplicatedStorage.Enemy.Constants).ENEMY_TAG
	local validateTag = require(ServerScriptService.Blaster.Scripts.ShotResolver.validateTag)
	local expect = t.expect

	local function target(position: Vector3)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Anchored = true
		root.Position = position
		root.Parent = model
		model.PrimaryPart = root
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		CollectionService:AddTag(model, ENEMY_TAG)
		model.Parent = workspace
		return model, humanoid
	end
	local function check(player, humanoid, origin: Vector3, direction: Vector3): boolean
		return validateTag(player, humanoid, origin, direction, { position = origin + direction.Unit * 1000 } :: any)
	end

	t.test("a claimed hit passes within 10 studs of the ray, also up close; not further off it or behind the shooter", function()
		local player = game:GetService("Players"):GetPlayers()[1]
		expect.truthy(player)
		local origin = Vector3.new(0, 6000, 0)
		local forward = Vector3.new(0, 0, -1)
		local near, nearHumanoid = target(origin + Vector3.new(4.69, 0, -1.43)) -- 4.9 studs, 73 degrees off the ray
		local far9, far9Humanoid = target(origin + Vector3.new(9, 0, -100))
		local far11, far11Humanoid = target(origin + Vector3.new(11, 0, -100))
		local behind, behindHumanoid = target(origin + Vector3.new(0, 0, 5))
		expect.equal(check(player, nearHumanoid, origin, forward), true)
		expect.equal(check(player, far9Humanoid, origin, forward), true)
		expect.equal(check(player, far11Humanoid, origin, forward), false)
		expect.equal(check(player, behindHumanoid, origin, forward), false)
		for _, model in { near, far9, far11, behind } do
			model:Destroy()
		end
	end)
end
