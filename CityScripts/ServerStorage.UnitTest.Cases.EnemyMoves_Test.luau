-- Enemies climb, vault and roll (2026-11-20): ServerScriptService.Enemy.Scripts.EnemyMoves.
return function(t)
	local EnemyMoves = require(game:GetService("ServerScriptService").Enemy.Scripts.EnemyMoves)
	local expect = t.expect

	-- A fake world: ground at y 0, a wall from x 2 to x 3 of `height`, and optionally a ceiling at `ceiling`.
	local function world(height: number, ceiling: number?)
		return function(origin: Vector3, direction: Vector3): RaycastResult?
			local finish = origin + direction
			local function hit(position: Vector3)
				return ({ Position = position } :: any) :: RaycastResult
			end
			if direction.Y == 0 then -- level rays: the wall's face
				if origin.X < 2 and finish.X >= 2 and origin.Y <= height then
					return hit(Vector3.new(2, origin.Y, origin.Z))
				end
				return nil
			end
			if direction.Y > 0 then -- up: the ceiling
				if ceiling and origin.Y < ceiling and finish.Y >= ceiling then
					return hit(Vector3.new(origin.X, ceiling, origin.Z))
				end
				return nil
			end
			-- down: the wall's top (or the inside of the wall), else the ground
			if origin.X >= 2 and origin.X <= 3 then
				if origin.Y <= height then
					return hit(origin)
				end
				if finish.Y <= height then
					return hit(Vector3.new(origin.X, height, origin.Z))
				end
				return nil
			end
			if finish.Y <= 0 then
				return hit(Vector3.new(origin.X, 0, origin.Z))
			end
			return nil
		end
	end
	local feet, forward = Vector3.zero, Vector3.xAxis

	t.test("ledgeKind: vault 1.5 to 3.8, climb 3.8 to 8, nothing else", function()
		expect.equal(EnemyMoves.ledgeKind(1.4), nil)
		expect.equal(EnemyMoves.ledgeKind(2), "vault")
		expect.equal(EnemyMoves.ledgeKind(3.8), "climb")
		expect.equal(EnemyMoves.ledgeKind(8), "climb")
		expect.equal(EnemyMoves.ledgeKind(8.1), nil)
	end)

	t.test("measureLedge: climbs a 5-stud wall and lands on top", function()
		local kind, landing = EnemyMoves.measureLedge(feet, forward, world(5))
		expect.equal(kind, "climb")
		expect.near(landing.X, 3.7, 1e-6) -- the face at x 2, the top probed 0.7 past it, landing 1 further
		expect.near(landing.Y, 5 + EnemyMoves.ROOT_HEIGHT, 1e-6)
	end)

	t.test("measureLedge: vaults a 2.5-stud wall; nothing for a 10-stud wall, a low curb, open ground or no headroom", function()
		expect.equal((EnemyMoves.measureLedge(feet, forward, world(2.5))), "vault")
		expect.equal((EnemyMoves.measureLedge(feet, forward, world(10))), nil)
		expect.equal((EnemyMoves.measureLedge(feet, forward, world(0.5))), nil)
		expect.equal((EnemyMoves.measureLedge(feet, -forward, world(5))), nil)
		expect.equal((EnemyMoves.measureLedge(feet, forward, world(5, 7))), nil)
	end)
end
