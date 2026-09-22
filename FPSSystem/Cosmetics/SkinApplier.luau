-- Applies and removes a palette on a weapon model. Used by BOTH sides: the server dresses the world
-- Tool, the client dresses the viewmodel, and one implementation keeps them identical.
--
-- Geometry is never touched. No part is added, removed, renamed or re-parented -- only Color is
-- written. This is not stylistic: WeaponViewmodelMotion asserts on a weapon name it does not know and
-- that exception aborts BlasterController.new, so a skin that renamed a Tool would silently kill first
-- person for that weapon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)

-- Where a part's stock colour is remembered, so removal restores rather than guesses.
--
-- An ATTRIBUTE on the part, not a Lua table keyed by instance: the server and the client each run
-- their own copy of this module, a Tool outlives any one of their sessions, and a table would be
-- rebuilt empty after a respawn while the part kept its skinned colour -- which is how a skin becomes
-- permanent by accident.
local ORIGINAL_ATTRIBUTE = "SkinOriginalColor"

-- Rec. 709 luma. Any reasonable weighting works; this one is the standard.
local function luminance(colour: Color3): number
	return 0.2126 * colour.R + 0.7152 * colour.G + 0.0722 * colour.B
end

local SkinApplier = {}

-- The weapon's own parts, wherever the caller handed us a Tool, a viewmodel or a bare display model.
local function weaponRoot(model: Instance): Instance
	return model:FindFirstChild("Blaster") or model
end

-- The parts a skin may touch: visible ones, inside the weapon's Blaster sub-model.
--
-- Scoped to Blaster because a viewmodel's LeftArm, RightArm and Root sit outside it -- that scoping is
-- what makes tinting the player's arms structurally impossible rather than merely unlikely.
--
-- Visible only because the viewmodel build script leaves the original named parts behind as invisible
-- donor skeleton: on Spas 12 the visible geometry is Mesh1..Mesh4 while Body and TrimA..TrimD sit at
-- Transparency 1. Colouring those would be colouring nothing.
local function skinnableParts(model: Instance): { BasePart }
	local parts = {}
	for _, descendant in weaponRoot(model):GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function sampleRamp(ramp: { Color3 }, position: number): Color3
	if #ramp == 1 then
		return ramp[1]
	end
	local scaled = math.clamp(position, 0, 1) * (#ramp - 1)
	local lower = math.clamp(math.floor(scaled), 0, #ramp - 2)
	return ramp[lower + 1]:Lerp(ramp[lower + 2], scaled - lower)
end

function SkinApplier.apply(model: Instance, palette: Palettes.Palette): number
	local parts = skinnableParts(model)
	if #parts == 0 then
		return 0
	end

	-- Rank by each part's ORIGINAL luminance, not its current one, so re-skinning ranks by how the
	-- weapon looks in stock rather than by whatever the previous skin left behind.
	local levels: { [BasePart]: number } = {}
	local darkest, lightest = math.huge, -math.huge
	for _, part in parts do
		local recorded = part:GetAttribute(ORIGINAL_ATTRIBUTE)
		local base = if typeof(recorded) == "Color3" then recorded else part.Color
		local level = luminance(base)
		levels[part] = level
		darkest = math.min(darkest, level)
		lightest = math.max(lightest, level)
	end

	local spread = lightest - darkest
	for _, part in parts do
		-- Recorded once only. A second skin must not overwrite the record with the first skin's
		-- colour, or removal restores to a skin rather than to stock.
		if part:GetAttribute(ORIGINAL_ATTRIBUTE) == nil then
			part:SetAttribute(ORIGINAL_ATTRIBUTE, part.Color)
		end
		-- A weapon whose visible parts all share one luminance has no contrast to preserve, so it
		-- takes the ramp's midpoint rather than dividing by zero.
		local position = if spread > 1e-4 then (levels[part] - darkest) / spread else 0.5
		part.Color = sampleRamp(palette.ramp, position)
	end
	return #parts
end

function SkinApplier.remove(model: Instance): number
	local restored = 0
	-- Deliberately NOT filtered by visibility: a part hidden after it was skinned must still be able
	-- to give its colour back.
	for _, descendant in weaponRoot(model):GetDescendants() do
		if descendant:IsA("BasePart") then
			local original = descendant:GetAttribute(ORIGINAL_ATTRIBUTE)
			if typeof(original) == "Color3" then
				descendant.Color = original
				descendant:SetAttribute(ORIGINAL_ATTRIBUTE, nil)
				restored += 1
			end
		end
	end
	return restored
end

-- The one entry point callers should use. nil, the default key, or an unknown key all mean "stock".
function SkinApplier.applyKey(model: Instance, key: string?): number
	if key == nil or key == Palettes.DEFAULT_KEY then
		return SkinApplier.remove(model)
	end
	local palette = Palettes.byKey(key)
	if not palette then
		return 0
	end
	SkinApplier.remove(model)
	return SkinApplier.apply(model, palette)
end

return SkinApplier
