-- Tests for Blaster.Utility.thirdPersonAim: in third person the shot leaves the head (the server measures
-- the origin from the root part, and a long gun's muzzle sits past its 5 studs) toward the point the
-- crosshair's ray hits. The crosshair ray starts level with the head, so anything between the camera
-- and the character is not what the player aims at. With nothing under the crosshair within range it aims
-- along the camera's look at a far point (direction only). The cast is injected: cast(from, direction) -> hit?
return function(t)
	local thirdPersonAim = require(game:GetService("ReplicatedStorage").Blaster.Utility.thirdPersonAim)
	local expect = t.expect
	local head = Vector3.new(0, 5, 0)
	-- ViewModelController's third-person camera: head + (2.5, 1.5, 5), looking along -Z.
	local camera = CFrame.new(head + Vector3.new(2.5, 1.5, 5))
	local function near(a: Vector3, b: Vector3)
		expect.near((a - b).Magnitude, 0, 1e-4)
	end
	local function noHit()
		return nil
	end
	local function degreesOff(origin: CFrame, look: Vector3): number
		return math.deg(origin.LookVector:Angle(look))
	end

	t.test("the shot leaves the head toward the point the crosshair ray hits", function()
		local hit = Vector3.new(2.5, 6.5, -50)
		local origin = thirdPersonAim(camera, head, 1000, function()
			return hit
		end)
		near(origin.Position, head)
		near(origin.LookVector, (hit - head).Unit)
	end)
	t.test("the crosshair ray starts level with the head, not at the camera", function()
		local from, direction
		thirdPersonAim(camera, head, 1000, function(f, d)
			from, direction = f, d
			return nil
		end)
		near(from, Vector3.new(2.5, 6.5, 0))
		near(direction, Vector3.new(0, 0, -1000))
	end)
	t.test("with nothing hit it aims at a point 1000 studs along the crosshair", function()
		local origin = thirdPersonAim(camera, head, 1000, noHit)
		near(origin.LookVector, (Vector3.new(2.5, 6.5, -1000) - head).Unit)
	end)
	t.test("a hit level with the head falls back to the camera's direction", function()
		local origin = thirdPersonAim(camera, head, 1000, function(f)
			return f
		end)
		near(origin.Position, head)
		near(origin.LookVector, Vector3.new(0, 0, -1))
	end)
	t.test("a camera ahead of the head casts from the camera itself", function()
		local ahead = CFrame.new(head + Vector3.new(0, 0, -3))
		local from
		local hit = Vector3.new(0, 5, -40)
		local origin = thirdPersonAim(ahead, head, 1000, function(f)
			from = f
			return hit
		end)
		near(from, ahead.Position)
		near(origin.Position, head)
		near(origin.LookVector, (hit - head).Unit)
	end)
	t.test("no range (0 or nil) casts nothing and aims along the camera's look", function()
		for _, range in { 0, nil } do
			local called = false
			local origin = thirdPersonAim(camera, head, range, function()
				called = true
				return nil
			end)
			expect.falsy(called)
			expect.truthy(degreesOff(origin, camera.LookVector) < 1)
		end
	end)
	t.test("a straight-up look gives a valid origin looking up", function()
		local up = CFrame.fromMatrix(head + Vector3.new(2.5, 1.5, 5), Vector3.xAxis, Vector3.zAxis)
		expect.near(up.LookVector.Y, 1, 1e-6)
		local origin = thirdPersonAim(up, head, 1000, noHit)
		local look = origin.LookVector
		expect.truthy(look.X == look.X and look.Y == look.Y and look.Z == look.Z)
		expect.truthy(degreesOff(origin, Vector3.yAxis) < 1)
	end)
	t.test("a melee miss (6 studs, nothing hit) swings within 1 degree of the camera's look", function()
		local origin = thirdPersonAim(camera, head, 6, noHit)
		expect.truthy(degreesOff(origin, camera.LookVector) < 1)
	end)
end
