-- Tests for ReplicatedStorage.Cosmetics.Palettes.
-- The catalogue is data, so these assert its shape and the invariants the applier relies on.
return function(t)
	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)
	local expect = t.expect

	local function luminance(c)
		return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
	end

	t.test("exposes an ordered list with at least six palettes", function()
		expect.truthy(#Palettes.list >= 6)
	end)

	t.test("every palette has a ramp of at least two stops", function()
		for _, palette in Palettes.list do
			expect.truthy(#palette.ramp >= 2)
		end
	end)

	t.test("every ramp stop is a Color3", function()
		for _, palette in Palettes.list do
			for _, stop in palette.ramp do
				expect.equal(typeof(stop), "Color3")
			end
		end
	end)

	t.test("every palette has a swatch colour for its chip", function()
		for _, palette in Palettes.list do
			expect.equal(typeof(palette.swatch), "Color3")
		end
	end)

	t.test("every ramp runs dark to light", function()
		-- The applier maps a part's normalised luminance straight onto the ramp, so a ramp that ran
		-- light to dark would invert that weapon's shading.
		for _, palette in Palettes.list do
			for index = 2, #palette.ramp do
				expect.truthy(luminance(palette.ramp[index]) >= luminance(palette.ramp[index - 1]))
			end
		end
	end)

	t.test("every palette key is unique", function()
		local seen = {}
		for _, palette in Palettes.list do
			expect.falsy(seen[palette.key])
			seen[palette.key] = true
		end
	end)

	t.test("byKey returns the matching palette and nil for an unknown key", function()
		local first = Palettes.list[1]
		expect.equal(Palettes.byKey(first.key), first)
		expect.equal(Palettes.byKey("NoSuchPalette"), nil)
	end)

	t.test("DEFAULT_KEY names a palette that actually exists", function()
		expect.truthy(Palettes.byKey(Palettes.DEFAULT_KEY) ~= nil)
	end)

	t.test("isVipOnly agrees with the source field", function()
		for _, palette in Palettes.list do
			expect.equal(Palettes.isVipOnly(palette.key), palette.source == "Vip")
		end
	end)

	t.test("at least one free palette and at least one Vip palette exist", function()
		local free, vip = 0, 0
		for _, palette in Palettes.list do
			if palette.source == "Vip" then vip += 1 else free += 1 end
		end
		expect.truthy(free > 0)
		expect.truthy(vip > 0)
	end)

	-- Encodes a discipline the catalogue's own comments only ever stated in prose (see RoseGold and
	-- the Skins-card-expansion block): every swatch was checked against every other before it shipped,
	-- and the closest pair on file is Stock<->Sandstorm at 52.8. This must fail the moment someone
	-- adds a colour that violates that floor, rather than relying on a human re-running the check by
	-- eye next time the catalogue grows.
	t.test("no two swatches sit closer than 52.8 apart in RGB space", function()
		local minDistance = math.huge
		for i = 1, #Palettes.list do
			for j = i + 1, #Palettes.list do
				local a, b = Palettes.list[i].swatch, Palettes.list[j].swatch
				local dr = (a.R - b.R) * 255
				local dg = (a.G - b.G) * 255
				local db = (a.B - b.B) * 255
				local distance = math.sqrt(dr * dr + dg * dg + db * db)
				minDistance = math.min(minDistance, distance)
			end
		end
		expect.truthy(minDistance >= 52.8)
	end)
end
