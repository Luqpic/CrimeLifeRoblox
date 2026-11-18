-- Tests for Blaster.Utility.thirdPersonAim: in third person the shot leaves the head (the server measures
-- the origin from the root part, and a long gun's muzzle sits past its 5 studs) toward the point the
-- crosshair's ray hits. The crosshair ray starts level with the head, so anything between the camera
-- and the character is not what the player aims at. The cast is injected: cast(from, direction) -> hit?
return function(t)
	local thirdPersonAim = require(game:GetService("ReplicatedStorage").Blaster.Utility.thirdPersonAim)
	local expect = t.expect
	local head = Vector3.new(0, 5, 0)
	-- ViewModelController's third-person camera: head + (2.5, 1.5, 5), looking along -Z.
	local camera = CFrame.new(head + Vector3.new(2.5, 1.5, 5))
	local function near(a: Vector3, b: Vector3)
		expect.near((a - b).Magnitude, 0, 1e-4)
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
	t.test("with nothing hit it aims at the crosshair point at full range", function()
		local origin = thirdPersonAim(camera, head, 1000, function()
			return nil
		end)
		near(origin.LookVector, (Vector3.new(2.5, 6.5, -1000) - head).Unit)
	end)
	t.test("a hit level with the head falls back to the camera's direction", function()
		local origin = thirdPersonAim(camera, head, 1000, function(f)
			return f
		end)
		near(origin.Position, head)
		near(origin.LookVector, Vector3.new(0, 0, -1))
	end)
end
