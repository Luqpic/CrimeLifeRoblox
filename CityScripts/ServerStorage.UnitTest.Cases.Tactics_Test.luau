-- Smarter enemies (combat depth, 2026-11-20): ServerScriptService.Enemy.Scripts.Tactics.
return function(t)
	local Tactics = require(game:GetService("ServerScriptService").Enemy.Scripts.Tactics)
	local expect = t.expect

	t.test("shouldBackOff: below 30 % of max health and alive only", function()
		expect.equal(Tactics.shouldBackOff(29, 100), true)
		expect.equal(Tactics.shouldBackOff(30, 100), false)
		expect.equal(Tactics.shouldBackOff(0, 100), false)
		expect.equal(Tactics.shouldBackOff(5, 0), false)
	end)

	t.test("backOffPoint: BACK_OFF_STEP studs straight away from the target, flat", function()
		local point = Tactics.backOffPoint(Vector3.new(10, 3, 0), Vector3.new(0, 8, 0))
		expect.near(point.X, 10 + Tactics.BACK_OFF_STEP, 1e-6)
		expect.near(point.Y, 3, 1e-6)
		expect.near(point.Z, 0, 1e-6)
	end)

	t.test("flankPoint: the given angle round the target from the ally, at the given distance", function()
		local target = Vector3.new(0, 3, 0)
		local point = Tactics.flankPoint(target, Vector3.new(20, 3, 0), 15, 90)
		local offset = point - target
		expect.near(offset.Magnitude, 15, 1e-4)
		expect.near(math.deg(math.acos(offset.Unit:Dot(Vector3.xAxis))), 90, 1e-3)
		local other = Tactics.flankPoint(target, Vector3.new(20, 3, 0), 15, -90) - target
		expect.near((other + offset).Magnitude, 0, 1e-4) -- the two sides are opposite
	end)

	t.test("findCover: behind a wall, reachable, on ground; nil in the open", function()
		-- A wall on the plane x = 4 (y up to 10); ground everywhere at y = 0.
		local function blocked(a: Vector3, b: Vector3): boolean
			local crossesWall = (a.X - 4) * (b.X - 4) < 0
			if crossesWall then
				local f = (4 - a.X) / (b.X - a.X)
				if a.Y + (b.Y - a.Y) * f <= 10 then
					return true
				end
			end
			return math.min(a.Y, b.Y) <= 0 -- reaches the ground
		end
		local from = Vector3.new(0, 3, 0)
		local target = Vector3.new(-30, 3, 0)
		-- The target is on the near side of the wall: nothing round the enemy hides from it except across the wall,
		-- and the enemy cannot walk through the wall.
		expect.equal(Tactics.findCover(from, target, blocked), nil)
		-- The target behind the wall's far side: the enemy's own side is hidden; the first point is the inner ring's.
		local spot = Tactics.findCover(from, Vector3.new(30, 3, 0), blocked)
		expect.truthy(spot)
		expect.truthy(spot.X < 4)
		expect.near((spot - from).Magnitude, Tactics.COVER_RADII[1], 1e-4)
		-- No ground: no cover.
		local function noGround(a: Vector3, b: Vector3): boolean
			return blocked(a, b) and math.min(a.Y, b.Y) > 0
		end
		expect.equal(Tactics.findCover(from, Vector3.new(30, 3, 0), noGround), nil)
	end)

	t.test("inAlertRange: within ALERT_RADIUS", function()
		expect.equal(Tactics.inAlertRange(Vector3.zero, Vector3.new(Tactics.ALERT_RADIUS, 0, 0)), true)
		expect.equal(Tactics.inAlertRange(Vector3.zero, Vector3.new(Tactics.ALERT_RADIUS + 1, 0, 0)), false)
	end)
end
