-- Tests for ReplicatedStorage.Cosmetics.SkinApplier.
-- Two contracts matter. REVERSIBILITY, because the same Tool instances are reused across respawns and
-- a drifting colour would accumulate. And COVERAGE, because the reason this module is luminance-keyed
-- rather than name-keyed is that the named parts are invisible skeleton on 11 of the 29 weapons.
return function(t)
	local SkinApplier = require(game.ReplicatedStorage.Cosmetics.SkinApplier)
	local expect = t.expect

	-- A stand-in shaped like a real viewmodel: arms outside the Blaster sub-model, an invisible
	-- skeleton part inside it, and visible mesh parts with names no palette could know.
	local function makeWeapon()
		local model = Instance.new("Model")

		local arm = Instance.new("Part")
		arm.Name = "RightArm"
		arm.Color = Color3.fromRGB(200, 150, 120)
		arm.Parent = model

		local blaster = Instance.new("Model")
		blaster.Name = "Blaster"
		blaster.Parent = model

		local skeleton = Instance.new("Part")
		skeleton.Name = "Body"
		skeleton.Transparency = 1
		skeleton.Color = Color3.fromRGB(10, 10, 10)
		skeleton.Parent = blaster

		for name, colour in {
			Mesh1 = Color3.fromRGB(20, 20, 20),
			Mesh2 = Color3.fromRGB(120, 120, 120),
			Mesh3 = Color3.fromRGB(220, 220, 220),
		} do
			local part = Instance.new("Part")
			part.Name = name
			part.Color = colour
			part.Parent = blaster
		end

		return model
	end

	local palette = {
		key = "TestPalette", name = "TEST", source = "Free",
		swatch = Color3.fromRGB(0, 0, 0),
		ramp = { Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 255) },
	}

	local function luminance(c)
		return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
	end

	t.test("colours the visible parts inside the Blaster sub-model", function()
		expect.equal(SkinApplier.apply(makeWeapon(), palette), 3)
	end)

	t.test("never touches the arms, which live outside the Blaster sub-model", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.equal(model.RightArm.Color, Color3.fromRGB(200, 150, 120))
	end)

	t.test("skips invisible skeleton parts", function()
		-- The whole reason this module is not name-keyed. Tinting Body here would be tinting nothing.
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.equal(model.Blaster.Body.Color, Color3.fromRGB(10, 10, 10))
	end)

	t.test("preserves contrast: darkest stays darkest, lightest stays lightest", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.truthy(luminance(model.Blaster.Mesh1.Color) < luminance(model.Blaster.Mesh2.Color))
		expect.truthy(luminance(model.Blaster.Mesh2.Color) < luminance(model.Blaster.Mesh3.Color))
	end)

	t.test("spans the ramp: darkest reaches the first stop, lightest the last", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.near(luminance(model.Blaster.Mesh1.Color), 0, 0.01)
		expect.near(luminance(model.Blaster.Mesh3.Color), 1, 0.01)
	end)

	t.test("restores every original colour on remove", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.equal(SkinApplier.remove(model), 3)
		expect.equal(model.Blaster.Mesh1.Color, Color3.fromRGB(20, 20, 20))
		expect.equal(model.Blaster.Mesh2.Color, Color3.fromRGB(120, 120, 120))
		expect.equal(model.Blaster.Mesh3.Color, Color3.fromRGB(220, 220, 220))
	end)

	t.test("re-skinning does not bake the previous skin in as the original", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		SkinApplier.apply(model, {
			key = "Second", name = "SECOND", source = "Free",
			swatch = Color3.fromRGB(9, 9, 9),
			ramp = { Color3.fromRGB(9, 9, 9), Color3.fromRGB(90, 90, 90) },
		})
		SkinApplier.remove(model)
		expect.equal(model.Blaster.Mesh2.Color, Color3.fromRGB(120, 120, 120))
	end)

	t.test("a weapon whose parts share one luminance does not divide by zero", function()
		local model = Instance.new("Model")
		local blaster = Instance.new("Model")
		blaster.Name = "Blaster"
		blaster.Parent = model
		for index = 1, 3 do
			local part = Instance.new("Part")
			part.Name = "Mesh" .. index
			part.Color = Color3.fromRGB(100, 100, 100)
			part.Parent = blaster
		end
		expect.equal(SkinApplier.apply(model, palette), 3)
		-- A zero-spread division produces NaN in Lua without throwing, and a NaN-derived Color3 is
		-- still typeof "Color3" -- that check alone cannot fail against the bug it targets. The ramp
		-- midpoint can: NaN's luminance is not near 0.5, so this assertion actually discriminates.
		expect.near(luminance(blaster.Mesh1.Color), 0.5, 0.01)
	end)

	t.test("remove on an unskinned model is a no-op", function()
		local model = makeWeapon()
		expect.equal(SkinApplier.remove(model), 0)
		expect.equal(model.Blaster.Mesh2.Color, Color3.fromRGB(120, 120, 120))
	end)

	t.test("adds and removes no instances -- geometry is never touched", function()
		local model = makeWeapon()
		local before = #model:GetDescendants()
		SkinApplier.apply(model, palette)
		expect.equal(#model:GetDescendants(), before)
		SkinApplier.remove(model)
		expect.equal(#model:GetDescendants(), before)
	end)

	t.test("renames nothing", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.truthy(model.Blaster:FindFirstChild("Mesh1") ~= nil)
		expect.truthy(model:FindFirstChild("RightArm") ~= nil)
	end)

	t.test("applyKey with nil removes any applied skin", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		SkinApplier.applyKey(model, nil)
		expect.equal(model.Blaster.Mesh2.Color, Color3.fromRGB(120, 120, 120))
	end)

	t.test("applyKey with an unknown key on an unskinned model stays at stock", function()
		local model = makeWeapon()
		expect.equal(SkinApplier.applyKey(model, "NoSuchPalette"), 0)
		expect.equal(model.Blaster.Mesh2.Color, Color3.fromRGB(120, 120, 120))
	end)

	t.test("applyKey with an unknown key falls back to stock even when a skin was already applied", function()
		-- The case the old "leaves the model untouched" test could not catch: it only ever ran against
		-- an unskinned model, so it passed whether or not an unknown key actually removed anything.
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		local restored = SkinApplier.applyKey(model, "NoSuchPalette")
		expect.equal(restored, 3)
		expect.equal(model.Blaster.Mesh1.Color, Color3.fromRGB(20, 20, 20))
		expect.equal(model.Blaster.Mesh2.Color, Color3.fromRGB(120, 120, 120))
		expect.equal(model.Blaster.Mesh3.Color, Color3.fromRGB(220, 220, 220))
	end)
end
