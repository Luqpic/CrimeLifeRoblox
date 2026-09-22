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
	source: "Free" | "Vip",
	swatch: Color3,
	ramp: { Color3 },
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

-- The key the game treats as "unskinned". Kept here so nothing else hardcodes the string.
Palettes.DEFAULT_KEY = "Stock"

return Palettes
