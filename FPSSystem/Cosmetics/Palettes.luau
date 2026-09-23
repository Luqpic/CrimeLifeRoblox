-- The skin catalogue. A palette is a ramp of colour stops, dark to light, plus a swatch for its chip.
--
-- Not a part-name map, which is what this started as. Measured: 11 of the 29 viewmodels carry parts
-- named Mesh1..Mesh8 and MagazineMesh, and on those weapons the conventionally named parts (Body,
-- TrimA..TrimD) are invisible donor skeleton left behind by the viewmodel build script. Keying on
-- names would have tinted only invisible geometry there, making the skin absent in first person for
-- more than a third of the armoury.
--
-- Keying on each part's own luminance instead means one palette dresses every weapon, present or
-- future, and each weapon keeps its existing dark-to-light contrast rather than going flat.
export type Palette = {
	key: string,
	name: string,
	source: "Free" | "Vip" | "Spraypaint",
	swatch: Color3,
	ramp: { Color3 },
	-- Present only on Spraypaint entries. A Free or Vip palette carrying a price would imply it is
	-- buyable with Spraypaint, which must never be true of the pass tier.
	price: number?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Palettes = {}

-- Ordered: the skins row renders these in sequence, so this order is the order on screen.
Palettes.list = {
	{
		key = "Stock", name = "STOCK", source = "Free",
		-- The "no skin" entry. applyKey short-circuits it to a removal, so its ramp is never applied;
		-- it carries one anyway so every palette has the same shape and no branch handles a nil.
		swatch = rgb(163, 162, 165),
		ramp = { rgb(99, 95, 98), rgb(131, 129, 132), rgb(163, 162, 165) },
	},
	{
		key = "Carbon", name = "CARBON", source = "Free",
		swatch = rgb(40, 43, 51),
		ramp = { rgb(18, 19, 23), rgb(40, 43, 51), rgb(78, 84, 98) },
	},
	{
		key = "Sandstorm", name = "SANDSTORM", source = "Free",
		swatch = rgb(198, 176, 128),
		ramp = { rgb(84, 72, 50), rgb(150, 132, 94), rgb(214, 196, 152) },
	},
	{
		key = "Crimson", name = "CRIMSON", source = "Free",
		swatch = rgb(122, 26, 32),
		ramp = { rgb(34, 14, 16), rgb(96, 24, 28), rgb(176, 52, 58) },
	},
	{
		key = "Acid", name = "ACID", source = "Free",
		swatch = rgb(203, 242, 60),
		ramp = { rgb(30, 34, 18), rgb(120, 146, 36), rgb(216, 248, 96) },
	},
	{
		key = "Gold", name = "GOLD", source = "Vip",
		swatch = rgb(212, 175, 55),
		ramp = { rgb(74, 58, 18), rgb(168, 138, 42), rgb(238, 212, 120) },
	},
	{
		key = "Obsidian", name = "OBSIDIAN", source = "Vip",
		swatch = rgb(78, 30, 96),
		ramp = { rgb(12, 12, 16), rgb(58, 24, 72), rgb(150, 90, 180) },
	},
	{
		key = "Arctic", name = "ARCTIC", source = "Vip",
		swatch = rgb(226, 232, 240),
		ramp = { rgb(96, 120, 146), rgb(170, 190, 210), rgb(240, 248, 255) },
	},
	{
		key = "Cobalt", name = "COBALT", source = "Spraypaint", price = 500,
		swatch = rgb(30, 58, 138),
		ramp = { rgb(12, 22, 54), rgb(30, 58, 138), rgb(96, 140, 224) },
	},
	{
		key = "Verdigris", name = "VERDIGRIS", source = "Spraypaint", price = 700,
		swatch = rgb(47, 122, 107),
		ramp = { rgb(16, 46, 40), rgb(47, 122, 107), rgb(120, 200, 180) },
	},
	{
		key = "Ember", name = "EMBER", source = "Spraypaint", price = 900,
		swatch = rgb(194, 65, 12),
		ramp = { rgb(60, 18, 6), rgb(194, 65, 12), rgb(250, 160, 80) },
	},
	{
		-- Not the ivory this slot originally held. Measured: that swatch sat 37.4 from Arctic in RGB
		-- space, the closest pair in the whole catalogue against a prior floor of 52.8, and both were
		-- pale and near-identical in brightness -- a difference that may not survive a 52px chip or
		-- colour-vision deficiency. This one sits 68.0 from its nearest neighbour.
		key = "RoseGold", name = "ROSE GOLD", source = "Spraypaint", price = 1200,
		swatch = rgb(183, 110, 121),
		ramp = { rgb(74, 38, 44), rgb(183, 110, 121), rgb(232, 176, 182) },
	},
	-- Eight more, added for the Skins card expansion (12 -> 20). Each swatch was checked against all
	-- 19 others before it shipped, the same discipline RoseGold above documents -- the catalogue's
	-- closest pair stays Stock<->Sandstorm at 52.8, unchanged by this addition. Ramps follow the same
	-- shape as every entry above: dark/mid/light stops at roughly 0.3x/1.0x/1.6x the swatch, clamped
	-- to 255, with the mid stop equal to the swatch itself.
	{
		key = "Slate", name = "SLATE", source = "Spraypaint", price = 1500,
		swatch = rgb(96, 112, 132),
		ramp = { rgb(29, 34, 40), rgb(96, 112, 132), rgb(154, 179, 211) },
	},
	{
		key = "Rust", name = "RUST", source = "Spraypaint", price = 1800,
		swatch = rgb(140, 96, 40),
		ramp = { rgb(42, 29, 12), rgb(140, 96, 40), rgb(224, 154, 64) },
	},
	{
		key = "Forest", name = "FOREST", source = "Spraypaint", price = 2200,
		swatch = rgb(44, 140, 40),
		ramp = { rgb(13, 42, 12), rgb(44, 140, 40), rgb(70, 224, 64) },
	},
	{
		key = "Coral", name = "CORAL", source = "Spraypaint", price = 2600,
		swatch = rgb(240, 118, 96),
		ramp = { rgb(72, 35, 29), rgb(240, 118, 96), rgb(255, 189, 154) },
	},
	{
		key = "Aqua", name = "AQUA", source = "Spraypaint", price = 3100,
		swatch = rgb(34, 190, 210),
		ramp = { rgb(10, 57, 63), rgb(34, 190, 210), rgb(54, 255, 255) },
	},
	{
		key = "Lilac", name = "LILAC", source = "Spraypaint", price = 3700,
		swatch = rgb(158, 132, 240),
		ramp = { rgb(47, 40, 72), rgb(158, 132, 240), rgb(253, 211, 255) },
	},
	{
		key = "Fuchsia", name = "FUCHSIA", source = "Spraypaint", price = 4400,
		swatch = rgb(198, 40, 140),
		ramp = { rgb(59, 12, 42), rgb(198, 40, 140), rgb(255, 64, 224) },
	},
	{
		key = "Nebula", name = "NEBULA", source = "Vip",
		swatch = rgb(126, 52, 210),
		ramp = { rgb(38, 16, 63), rgb(126, 52, 210), rgb(202, 83, 255) },
	},
} :: { Palette }

local byKeyIndex: { [string]: Palette } = {}
for _, palette in Palettes.list do
	byKeyIndex[palette.key] = palette
end

function Palettes.byKey(key: string): Palette?
	return byKeyIndex[key]
end

function Palettes.isVipOnly(key: string): boolean
	local palette = byKeyIndex[key]
	return palette ~= nil and palette.source == "Vip"
end

function Palettes.priceOf(key: string): number?
	local palette = byKeyIndex[key]
	if not palette then
		return nil
	end
	return palette.price
end

-- The key the game treats as "unskinned". Kept here so nothing else hardcodes the string.
Palettes.DEFAULT_KEY = "Stock"

return Palettes
