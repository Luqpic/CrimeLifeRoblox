-- Tests for the Spraypaint tier added to ReplicatedStorage.Cosmetics.Palettes.
-- Phase 1's Palettes_Test still guards the shared invariants (ramps ascend, swatches exist, keys are
-- unique); this case covers only what the new tier adds.
return function(t)
	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)
	local expect = t.expect

	local function spraypaintPalettes()
		local found = {}
		for _, palette in Palettes.list do
			if palette.source == "Spraypaint" then
				table.insert(found, palette)
			end
		end
		return found
	end

	t.test("there are fifteen Spraypaint palettes", function()
		-- Was four; the Skins-card-revamp expansion (12 -> 20 palettes) added seven more, and putting Vip
		-- on hold moved its four palettes (Arctic, Obsidian, Gold, Nebula) onto Spraypaint prices.
		expect.equal(#spraypaintPalettes(), 15)
	end)

	t.test("every Spraypaint palette has a positive integer price", function()
		for _, palette in spraypaintPalettes() do
			expect.equal(typeof(palette.price), "number")
			expect.truthy(palette.price > 0)
			expect.equal(palette.price % 1, 0)
		end
	end)

	t.test("no Free or Vip palette carries a price", function()
		-- A priced Vip palette would imply it is buyable with Spraypaint, which must never be true.
		for _, palette in Palettes.list do
			if palette.source ~= "Spraypaint" then
				expect.equal(palette.price, nil)
			end
		end
	end)

	t.test("priceOf returns the price for every Spraypaint key and nil otherwise", function()
		-- Round-trips all four rather than trusting the first to stand in for the rest.
		for _, palette in spraypaintPalettes() do
			expect.equal(Palettes.priceOf(palette.key), palette.price)
		end
		expect.equal(Palettes.priceOf("Stock"), nil)
		expect.equal(Palettes.priceOf("Carbon"), nil)
		expect.equal(Palettes.priceOf("NoSuchPalette"), nil)
	end)

	t.test("isVipOnly stays false for Spraypaint palettes", function()
		-- Spraypaint must not route through the Vip gate, or buying it would demand the pass as well.
		for _, palette in spraypaintPalettes() do
			expect.falsy(Palettes.isVipOnly(palette.key))
		end
	end)

	t.test("the catalogue now holds twenty palettes", function()
		-- Was twelve; see the note on the Spraypaint-palette-count test above.
		expect.equal(#Palettes.list, 20)
	end)

	t.test("every palette key maps to a unique, legal attribute name", function()
		-- Not decorative. ownedAttributeFor sanitises with gsub, so two distinct keys can collapse onto
		-- one attribute -- "S&W" and "S W" both become SkinOwned_S_W -- and two palettes would then
		-- share one ownership flag: buy either and you silently own both. Every current key is
		-- alphanumeric so nothing collides today, which is exactly why this needs locking before
		-- someone adds a key with a space in it. Phase 1 proved the same invariant for the 29 weapon
		-- names.
		local SpraypaintConstants = require(game.ReplicatedStorage.Spraypaint.Constants)
		local probe = Instance.new("Part")
		local seen = {}
		for _, palette in Palettes.list do
			local name = SpraypaintConstants.ownedAttributeFor(palette.key)
			expect.falsy(seen[name])
			seen[name] = palette.key
			expect.truthy(pcall(function() probe:SetAttribute(name, true) end))
		end
	end)

	t.test("every Spraypaint ramp still runs dark to light", function()
		local function luminance(c)
			return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
		end
		for _, palette in spraypaintPalettes() do
			expect.truthy(#palette.ramp >= 2)
			for index = 2, #palette.ramp do
				expect.truthy(luminance(palette.ramp[index]) >= luminance(palette.ramp[index - 1]))
			end
		end
	end)
end
