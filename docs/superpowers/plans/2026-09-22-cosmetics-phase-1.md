# Weapon Cosmetics Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship tint-based weapon skins in the FPS System place — visible in first and third person, browsable and equippable from the weapon detail panel, gated by the existing `Vip` game pass — with no save layer and no change to any damage path.

**Architecture:** A skin is a **palette**: a named map of `partName → Color3` over the 11-name part vocabulary shared by all 29 weapons. One `SkinApplier` module serves both sides — the server applies it to the world Tool where `WeaponShopService` already rebuilds weapons, the client applies it to the viewmodel after `WeaponViewmodelMotion` has solved the joints. The equipped skin travels as a `SkinId` attribute on the Tool, so no new networking is added.

**Tech Stack:** Roblox Luau. Existing in-place unit framework at `ServerStorage.UnitTest` (`RunUnitTest(filter, timeout)`, assertions `expect.equal / truthy / falsy / near / throws / deepEqual`). Existing `ReplicatedStorage.Monetization` for ownership. Existing Figma file `iRetcvpbMMD190DJA9Mwrm`, page `02 · Redesign`.

**Spec:** `docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md`

## Global Constraints

- **A skin never changes geometry.** It sets `Color` on existing parts. It never adds, removes, renames or re-parents a part. Renaming a Tool makes `WeaponViewmodelMotion` assert, which aborts `BlasterController.new` and kills first person for that weapon.
- **Viewmodel skinning runs strictly AFTER `WeaponViewmodelMotion.new`.** Never before, never inside it.
- **`ReplicatedStorage.Cosmetics` is never required by** `ServerScriptService.Blaster.Scripts.ShotResolver` **or** `ServerScriptService.Weapons.Scripts.WeaponUpgradeService`. Appearance data has no business in the damage path.
- **No DataStore, no Renown, no texture skins, no new purchase plumbing.** All Phase 2 or later.
- **Restore-on-spawn must stay silent.** `WeaponShopService`'s restore path already distinguishes a grant from a purchase so a respawn handing back four weapons plays no purchase sound. Skin restore inherits that.
- **Run unit tests in Play mode, not Edit mode.** Studio's Edit-mode module cache serves a stale module after an edit; Play gets a fresh require.
- **Part name vocabulary (measured, all 29 weapons):** `Body` (29/29), `TrimA` (27), `TrimB` (27), `TrimC` (26), `TrimD` (17), `Magazine` (14), `TrimE` (11), `TrimF` (4), `ChargingHandle` (1), `TrimG` (1), `Blade` (1).
- **Design tokens:** panel `#171A22`, raised `#1E222C`, accent `#CBF23C`, danger `#FF4B4B`, Acid 2px stroke convention.
- **Measured shop geometry (read live, do not re-derive):** `WeaponaryShop` 920x580, `ShopArea` 700x484,
  `DetailPanel` **700x438** with NO `UIListLayout` — every child is absolutely positioned. Occupied:
  `DetailViewport` (0,44 290x290), `PriceIcon`/`PriceLabel` (0,338 -> y366), `DetailName`/`CategoryChip`/
  `Description`/`StatsContainer` (x320, y40 -> y360), `ActionButton` (320,378 200x54), `EquipButton`
  (530,378 170x54). Content bottom is y=432 of 438. **The only free region is x 0-290, y 372-432 —
  290x60.** The skins row lives there and nowhere else; nothing existing moves.
- **Every Tool has a `Blaster` child Model holding the visible parts** (29/29 measured). The Tool's own
  `Handle` sits outside it and is never tinted. So skinning targets `tool.Blaster`, not `tool`.

## Deviations from the spec, and why

Both come from measuring the panel rather than imagining it. Neither changes what the phase delivers.

1. **Chips carry no name label, and are 52x52 rather than 84x84.** The spec asks for "a row of palette
   chips" and does not specify a size, but the measured free region is 290x60. Eight named 84px chips
   need about 730px. Swatch-only chips at 52px in a horizontally scrolling row fit, and a grid of
   colour swatches is self-describing. Names stay in `Palettes.list` for later surfaces.
2. **No baked "SKINS" heading.** The spec notes a heading would be a 4x banner export. There is no
   vertical room for one in 60px without shrinking the viewport, and a swatch row directly beneath a
   weapon preview needs no label. Dropped rather than deferred; say so if you disagree.

---

## File Structure

Roblox instances, not files. Created:

| Path | Responsibility |
|---|---|
| `ReplicatedStorage.Cosmetics` (Folder) | Namespace root |
| `ReplicatedStorage.Cosmetics.Palettes` (ModuleScript) | The catalogue: palette definitions + lookup. Data only. |
| `ReplicatedStorage.Cosmetics.SkinApplier` (ModuleScript) | `apply` / `remove`, original-colour bookkeeping. Pure enough to unit test. |
| `ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest` (RemoteEvent) | Client asks, server decides |
| `ServerScriptService.Cosmetics.Scripts.CosmeticsService` (Script) | Ownership, validation, `SkinId` stamping, respawn restore |
| `StarterPlayer.StarterPlayerScripts.SkinRowController` (LocalScript) | The skins row in the detail panel |
| `ServerStorage.UnitTest.Cases.Palettes_Test` (ModuleScript) | Task 1 tests |
| `ServerStorage.UnitTest.Cases.SkinApplier_Test` (ModuleScript) | Task 2 tests |
| `ServerStorage.UnitTest.Cases.CosmeticsOwnership_Test` (ModuleScript) | Task 5 tests |

Modified:

| Path | Change |
|---|---|
| `ServerScriptService.Weapons.Scripts.WeaponShopService` | Call `CosmeticsService.applyToTool` where it grants/restores a weapon |
| `ReplicatedStorage.Blaster.Scripts.ViewModelController` | Apply the equipped palette after the viewmodel is built |
| `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel` | Add `SkinRow` frame + `SkinChip` template |

---

## Task 1: The palette catalogue

**Files:**
- Create: `ReplicatedStorage.Cosmetics.Palettes` (ModuleScript)
- Test: `ServerStorage.UnitTest.Cases.Palettes_Test` (ModuleScript)

**Interfaces:**
- Consumes: nothing
- Produces:
  - `Palettes.list: { Palette }` — ordered, render order
  - `Palettes.byKey(key: string): Palette?`
  - `Palettes.isVipOnly(key: string): boolean`
  - `type Palette = { key: string, name: string, source: "Free" | "Vip", tints: { [string]: Color3 } }`

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.Palettes_Test`:

```lua
-- Tests for ReplicatedStorage.Cosmetics.Palettes.
-- The catalogue is data, so these assert its shape and invariants rather than behaviour.
return function(t)
	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)
	local expect = t.expect

	t.test("exposes an ordered list with at least six palettes", function()
		expect.truthy(#Palettes.list >= 6)
	end)

	t.test("every palette tints Body, the only part every weapon has", function()
		for _, palette in Palettes.list do
			expect.truthy(palette.tints.Body ~= nil)
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

	t.test("tints only name parts that exist somewhere in the armoury", function()
		local known = {
			Body = true, TrimA = true, TrimB = true, TrimC = true, TrimD = true,
			TrimE = true, TrimF = true, TrimG = true, Magazine = true,
			ChargingHandle = true, Blade = true,
		}
		for _, palette in Palettes.list do
			for partName in palette.tints do
				expect.truthy(known[partName])
			end
		end
	end)

	t.test("carries no numbers -- a palette can never encode a stat", function()
		for _, palette in Palettes.list do
			for _, value in palette do
				expect.falsy(type(value) == "number")
			end
		end
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
end
```

- [ ] **Step 2: Run it and confirm it fails**

In a Play session, Server datamodel:

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("Palettes")
```

Expected: every case fails — `Palettes is not a valid member of ReplicatedStorage`.

- [ ] **Step 3: Write the catalogue**

Create `ReplicatedStorage.Cosmetics.Palettes`:

```lua
-- The skin catalogue. A palette is a named map of partName -> Color3, applied to ANY weapon.
--
-- Universal rather than per-weapon because the armoury shares its part names: measured across all 29
-- weapons there are only 11 distinct visible part names, and Body appears in every one. So a single
-- table dresses the whole armoury, and adding a skin later is an entry here and nothing else.
--
-- Data only. No numbers live in this file, and nothing in the damage path requires it.
export type Palette = {
	key: string,
	name: string,
	source: "Free" | "Vip",
	tints: { [string]: Color3 },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Palettes = {}

-- Ordered: the skins row renders these in sequence, so this order is the order on screen.
Palettes.list = {
	{
		key = "Stock", name = "STOCK", source = "Free",
		-- The "no skin" entry. Its colours are the rig's own defaults, so selecting it reads as
		-- removal without the UI needing a separate "none" concept.
		tints = { Body = rgb(163, 162, 165), TrimA = rgb(99, 95, 98), TrimB = rgb(99, 95, 98) },
	},
	{
		key = "Carbon", name = "CARBON", source = "Free",
		tints = { Body = rgb(28, 30, 36), TrimA = rgb(58, 62, 72), TrimB = rgb(58, 62, 72),
			TrimC = rgb(44, 47, 55), Magazine = rgb(36, 39, 46) },
	},
	{
		key = "Sandstorm", name = "SANDSTORM", source = "Free",
		tints = { Body = rgb(198, 176, 128), TrimA = rgb(120, 104, 74), TrimB = rgb(120, 104, 74),
			TrimC = rgb(150, 132, 94), Magazine = rgb(96, 84, 60) },
	},
	{
		key = "Crimson", name = "CRIMSON", source = "Free",
		tints = { Body = rgb(122, 26, 32), TrimA = rgb(38, 20, 22), TrimB = rgb(38, 20, 22),
			TrimC = rgb(74, 22, 26), Magazine = rgb(30, 16, 18) },
	},
	{
		key = "Acid", name = "ACID", source = "Free",
		tints = { Body = rgb(203, 242, 60), TrimA = rgb(38, 44, 20), TrimB = rgb(38, 44, 20),
			TrimC = rgb(140, 168, 40), Magazine = rgb(30, 34, 18) },
	},
	{
		key = "Gold", name = "GOLD", source = "Vip",
		tints = { Body = rgb(212, 175, 55), TrimA = rgb(120, 96, 28), TrimB = rgb(120, 96, 28),
			TrimC = rgb(168, 138, 42), TrimD = rgb(96, 78, 24), Magazine = rgb(72, 58, 18),
			ChargingHandle = rgb(120, 96, 28), Blade = rgb(232, 200, 96) },
	},
	{
		key = "Obsidian", name = "OBSIDIAN", source = "Vip",
		tints = { Body = rgb(16, 16, 20), TrimA = rgb(78, 30, 96), TrimB = rgb(78, 30, 96),
			TrimC = rgb(40, 18, 50), TrimD = rgb(24, 24, 30), Magazine = rgb(20, 20, 26),
			ChargingHandle = rgb(78, 30, 96), Blade = rgb(150, 90, 180) },
	},
	{
		key = "Arctic", name = "ARCTIC", source = "Vip",
		tints = { Body = rgb(226, 232, 240), TrimA = rgb(120, 150, 180), TrimB = rgb(120, 150, 180),
			TrimC = rgb(170, 190, 210), TrimD = rgb(100, 124, 150), Magazine = rgb(140, 160, 184),
			ChargingHandle = rgb(120, 150, 180), Blade = rgb(240, 248, 255) },
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
```

- [ ] **Step 4: Run the tests and confirm they pass**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("Palettes")
```

Expected: 8 passed, 0 failed.

- [ ] **Step 5: Confirm the damage path is still clean**

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local leaks = {}
for _, path in { ServerScriptService.Blaster.Scripts.ShotResolver, ServerScriptService.Weapons.Scripts.WeaponUpgradeService } do
	local src = path.Source
	if src:find("Cosmetics") or src:find("Palettes") then table.insert(leaks, path.Name) end
end
return #leaks == 0 and "clean" or ("LEAK: " .. table.concat(leaks, ", "))
```

Expected: `clean`.

- [ ] **Step 6: Commit**

```bash
cd /Users/luqpic/Documents/Roblox/CrimeLifeRoblox
git add FPSSystem/
git commit -m "Add the cosmetics palette catalogue"
```

---

## Task 2: SkinApplier

The riskiest module in the plan: it mutates live weapon instances and must be exactly reversible.

**Files:**
- Create: `ReplicatedStorage.Cosmetics.SkinApplier` (ModuleScript)
- Test: `ServerStorage.UnitTest.Cases.SkinApplier_Test` (ModuleScript)

**Interfaces:**
- Consumes: `Palettes.byKey`, `Palettes.DEFAULT_KEY` from Task 1
- Produces:
  - `SkinApplier.apply(model: Instance, palette: Palettes.Palette): number` — returns how many parts it recoloured
  - `SkinApplier.remove(model: Instance): number` — returns how many parts it restored
  - `SkinApplier.applyKey(model: Instance, key: string?): number` — `remove` when key is nil or the default

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.SkinApplier_Test`:

```lua
-- Tests for ReplicatedStorage.Cosmetics.SkinApplier.
-- The contract that matters is REVERSIBILITY: a weapon must come back to stock exactly, because the
-- same Tool instances are reused across respawns and a drifting colour would accumulate.
return function(t)
	local SkinApplier = require(game.ReplicatedStorage.Cosmetics.SkinApplier)
	local expect = t.expect

	-- A stand-in weapon with the part names the real rigs use.
	local function makeWeapon()
		local model = Instance.new("Model")
		for name, colour in {
			Body = Color3.fromRGB(10, 20, 30),
			TrimA = Color3.fromRGB(40, 50, 60),
			Unrelated = Color3.fromRGB(70, 80, 90),
		} do
			local part = Instance.new("Part")
			part.Name = name
			part.Color = colour
			part.Parent = model
		end
		return model
	end

	local palette = {
		key = "TestPalette", name = "TEST", source = "Free",
		tints = { Body = Color3.fromRGB(1, 2, 3), TrimA = Color3.fromRGB(4, 5, 6) },
	}

	t.test("recolours exactly the parts the palette names", function()
		local model = makeWeapon()
		local count = SkinApplier.apply(model, palette)
		expect.equal(count, 2)
		expect.equal(model.Body.Color, Color3.fromRGB(1, 2, 3))
		expect.equal(model.TrimA.Color, Color3.fromRGB(4, 5, 6))
	end)

	t.test("leaves parts the palette does not name alone", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		expect.equal(model.Unrelated.Color, Color3.fromRGB(70, 80, 90))
	end)

	t.test("restores every original colour on remove", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		local restored = SkinApplier.remove(model)
		expect.equal(restored, 2)
		expect.equal(model.Body.Color, Color3.fromRGB(10, 20, 30))
		expect.equal(model.TrimA.Color, Color3.fromRGB(40, 50, 60))
	end)

	t.test("re-skinning does not bake the previous skin in as the original", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		SkinApplier.apply(model, {
			key = "Second", name = "SECOND", source = "Free",
			tints = { Body = Color3.fromRGB(9, 9, 9) },
		})
		SkinApplier.remove(model)
		expect.equal(model.Body.Color, Color3.fromRGB(10, 20, 30))
	end)

	t.test("remove on an unskinned model is a no-op", function()
		local model = makeWeapon()
		expect.equal(SkinApplier.remove(model), 0)
		expect.equal(model.Body.Color, Color3.fromRGB(10, 20, 30))
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
		expect.truthy(model:FindFirstChild("Body") ~= nil)
		expect.truthy(model:FindFirstChild("TrimA") ~= nil)
	end)

	t.test("applyKey with nil removes any applied skin", function()
		local model = makeWeapon()
		SkinApplier.apply(model, palette)
		SkinApplier.applyKey(model, nil)
		expect.equal(model.Body.Color, Color3.fromRGB(10, 20, 30))
	end)

	t.test("applyKey with an unknown key leaves the model untouched", function()
		local model = makeWeapon()
		SkinApplier.applyKey(model, "NoSuchPalette")
		expect.equal(model.Body.Color, Color3.fromRGB(10, 20, 30))
	end)
end
```

- [ ] **Step 2: Run it and confirm it fails**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("SkinApplier")
```

Expected: every case fails — `SkinApplier is not a valid member of ReplicatedStorage.Cosmetics`.

- [ ] **Step 3: Write the applier**

Create `ReplicatedStorage.Cosmetics.SkinApplier`:

```lua
-- Applies and removes a palette on a weapon model. Used by BOTH sides: the server dresses the world
-- Tool, the client dresses the viewmodel, and one implementation keeps them identical.
--
-- Geometry is never touched. No part is added, removed, renamed or re-parented -- only Color is
-- written. This is not stylistic: WeaponViewmodelMotion asserts on a weapon name it does not know
-- and that exception aborts BlasterController.new, so a skin that renamed a Tool would silently kill
-- first person for that weapon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)

-- Where a part's stock colour is remembered, so removal restores rather than guesses.
--
-- An ATTRIBUTE on the part, not a Lua table keyed by instance: the server and the client each run
-- their own copy of this module, a Tool outlives any one of their sessions, and a table would be
-- rebuilt empty after a respawn while the part kept its skinned colour -- which is how a skin
-- becomes permanent by accident.
local ORIGINAL_ATTRIBUTE = "SkinOriginalColor"

local SkinApplier = {}

local function eachPart(model: Instance)
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

function SkinApplier.apply(model: Instance, palette: Palettes.Palette): number
	local changed = 0
	for _, part in eachPart(model) do
		local tint = palette.tints[part.Name]
		if tint then
			-- Recorded once only. A second skin must not overwrite the record with the first
			-- skin's colour, or removal restores to a skin rather than to stock.
			if part:GetAttribute(ORIGINAL_ATTRIBUTE) == nil then
				part:SetAttribute(ORIGINAL_ATTRIBUTE, part.Color)
			end
			part.Color = tint
			changed += 1
		end
	end
	return changed
end

function SkinApplier.remove(model: Instance): number
	local restored = 0
	for _, part in eachPart(model) do
		local original = part:GetAttribute(ORIGINAL_ATTRIBUTE)
		if typeof(original) == "Color3" then
			part.Color = original
			part:SetAttribute(ORIGINAL_ATTRIBUTE, nil)
			restored += 1
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
```

- [ ] **Step 4: Run the tests and confirm they pass**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("SkinApplier")
```

Expected: 9 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add FPSSystem/
git commit -m "Add SkinApplier with exact, reversible tinting"
```

---

## Task 3: Server applies the skin to the world Tool

**Files:**
- Create: `ServerScriptService.Cosmetics.Scripts.CosmeticsService` (Script)
- Modify: `ServerScriptService.Weapons.Scripts.WeaponShopService` — the grant/restore path

**Interfaces:**
- Consumes: `SkinApplier.applyKey` (Task 2), `Palettes` (Task 1)
- Produces:
  - `SkinId` attribute stamped on each granted Tool
  - Player attribute `EquippedSkin_<WeaponName>` holding the chosen key

- [ ] **Step 1: Write the failing live check**

In a Play session, Server datamodel. This is the measurement the task must make pass:

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
player:SetAttribute("EquippedSkin_Crowbar", "Carbon")
local tool = player.Backpack:FindFirstChild("Crowbar") or player.Character:FindFirstChild("Crowbar")
return string.format("SkinId=%s  Body colour=%s",
	tostring(tool:GetAttribute("SkinId")),
	tostring(tool.Blaster.Body.Color))
```

Expected before the change: `SkinId=nil`, and Body is the stock grey.

- [ ] **Step 2: Write CosmeticsService**

Create `ServerScriptService.Cosmetics.Scripts.CosmeticsService`:

```lua
-- Server side of cosmetics: decides what a player may wear, stamps it on the Tool, and dresses the
-- world model everyone else sees.
--
-- The viewmodel is NOT dressed here. It is built client-side and is dressed there, after the motion
-- module has solved its joints.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)

local CosmeticsService = {}

-- Which game pass unlocks the Vip tier. The pass already advertises "Exclusive weapon skins".
local VIP_KEY = "Vip"

-- Per weapon, so a player can dress each gun differently. Republished as a player attribute the way
-- LoadoutSlot already is, which is what makes it survive a respawn without a DataStore.
function CosmeticsService.attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

function CosmeticsService.ownsPalette(player: Player, key: string): boolean
	if not Palettes.byKey(key) then
		return false
	end
	if not Palettes.isVipOnly(key) then
		return true
	end
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor(VIP_KEY)) == true
end

function CosmeticsService.equippedKeyFor(player: Player, weaponName: string): string
	local key = player:GetAttribute(CosmeticsService.attributeFor(weaponName))
	if typeof(key) ~= "string" or not CosmeticsService.ownsPalette(player, key) then
		return Palettes.DEFAULT_KEY
	end
	return key
end

-- Called by WeaponShopService wherever it hands a weapon to a player, including the respawn restore.
-- Silent by design: it writes appearance and nothing else, so it cannot make a restore sound like a
-- purchase.
function CosmeticsService.applyToTool(player: Player, tool: Tool)
	local key = CosmeticsService.equippedKeyFor(player, tool.Name)
	tool:SetAttribute("SkinId", key)
	local blaster = tool:FindFirstChild("Blaster")
	if blaster then
		SkinApplier.applyKey(blaster, key)
	end
end

-- Re-dresses every weapon a player is currently carrying. Used when the equipped skin changes.
function CosmeticsService.refresh(player: Player, weaponName: string?)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and (weaponName == nil or tool.Name == weaponName) then
					CosmeticsService.applyToTool(player, tool)
				end
			end
		end
	end
end

return CosmeticsService
```

- [ ] **Step 3: Hook it into the grant path**

Find where `WeaponShopService` parents a granted Tool into the Backpack (the `grantWeapon` function). Add, immediately after the Tool is parented:

```lua
	CosmeticsService.applyToTool(player, tool)
```

and at the top of the file, beside the other requires:

```lua
local CosmeticsService = require(game:GetService("ServerScriptService").Cosmetics.Scripts.CosmeticsService)
```

- [ ] **Step 4: Run the live check again**

Re-run the Step 1 script.

Expected after: `SkinId=Carbon` and Body colour reads `0.109804, 0.117647, 0.141176` — RGB(28, 30, 36), the Carbon Body tint.

- [ ] **Step 5: Confirm the rig is undisturbed**

```lua
local Players = game:GetService("Players")
local tool = Players:GetPlayers()[1].Backpack:FindFirstChild("Crowbar")
local n = 0
for _, d in tool:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
return string.format("parts=%d  names=%s", n, (function()
	local names = {}
	for _, d in tool.Blaster:GetChildren() do table.insert(names, d.Name) end
	table.sort(names)
	return table.concat(names, ",")
end)())
```

Expected: the same part count and the same names as before skinning — `Body,TrimA,TrimB,TrimC,TrimD,TrimE`.

- [ ] **Step 6: Commit**

```bash
git add FPSSystem/
git commit -m "Dress the world Tool from the equipped skin on grant and respawn"
```

---

## Task 4: Client applies the skin to the viewmodel

**Files:**
- Modify: `ReplicatedStorage.Blaster.Scripts.ViewModelController` — after the viewmodel is built

**Interfaces:**
- Consumes: `SkinApplier.applyKey` (Task 2), the `SkinId` attribute (Task 3)
- Produces: a skinned viewmodel in first person

- [ ] **Step 1: Write the failing live check**

Play session, Client datamodel, with the Crowbar equipped and `EquippedSkin_Crowbar` set to `Carbon`:

```lua
local viewModel
for _, child in workspace:GetChildren() do
	if child:IsA("Model") and child:FindFirstChild("AnimationController") then viewModel = child break end
end
return string.format("viewmodel=%s  Body colour=%s",
	viewModel and viewModel.Name or "none",
	viewModel and tostring(viewModel.Blaster.Body.Color) or "-")
```

Expected before: the viewmodel exists but Body is stock grey — the world Tool is skinned and the viewmodel is not.

- [ ] **Step 2: Apply the skin after the viewmodel is built**

In `ViewModelController.new`, find the line that returns `self` at the end of the constructor. Immediately BEFORE that return, add:

```lua
	-- Dressed last, after the model is built and WeaponViewmodelMotion has solved the joints.
	-- Ordering is load-bearing: that module asserts on a weapon it has no profile for and the
	-- exception aborts BlasterController.new, so anything that runs before it can take first person
	-- down with it. Colour is the only thing written, so the solved joints are unaffected.
	local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
	SkinApplier.applyKey(viewModel, blaster:GetAttribute("SkinId"))
```

- [ ] **Step 3: Re-equip and run the check again**

Unequip and re-equip the weapon so a fresh viewmodel is built, then re-run the Step 1 script.

Expected: `Body colour=0.109804, 0.117647, 0.141176`.

- [ ] **Step 4: Confirm first person still works and the rig is unchanged**

```lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local viewModel
for _, child in workspace:GetChildren() do
	if child:IsA("Model") and child:FindFirstChild("AnimationController") then viewModel = child break end
end
local joints = {}
for _, d in viewModel:GetDescendants() do
	if d:IsA("Motor6D") then table.insert(joints, d.Name) end
end
table.sort(joints)
return string.format("camera=%s  joints=%s", player.CameraMode.Name, table.concat(joints, ","))
```

Expected: `camera=LockFirstPerson` and `joints=BodyJoint,LeftArmJoint,RightArmJoint`. If the camera is `Classic`, the skin ran too early — move the call after the motion construction.

- [ ] **Step 5: Commit**

```bash
git add FPSSystem/
git commit -m "Dress the viewmodel from the SkinId attribute after the joints are solved"
```

---

## Task 5: Ownership and the equip remote

**Files:**
- Create: `ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest` (RemoteEvent)
- Modify: `ServerScriptService.Cosmetics.Scripts.CosmeticsService` — handle the remote
- Test: `ServerStorage.UnitTest.Cases.CosmeticsOwnership_Test` (ModuleScript)

**Interfaces:**
- Consumes: `CosmeticsService.ownsPalette`, `CosmeticsService.refresh` (Task 3)
- Produces: `EquipSkinRequest:FireServer(weaponName: string, paletteKey: string)`

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.CosmeticsOwnership_Test`:

```lua
-- Tests for the ownership rule in CosmeticsService. These run against a stand-in player object
-- rather than a real Player, because a unit test cannot mint one.
return function(t)
	local ReplicatedStorage = game.ReplicatedStorage
	local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
	local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)
	local CosmeticsService = require(game.ServerScriptService.Cosmetics.Scripts.CosmeticsService)
	local expect = t.expect

	-- Minimal stand-in: ownsPalette only ever calls GetAttribute.
	local function fakePlayer(ownsVip: boolean)
		local attributes = {}
		if ownsVip then
			attributes[MonetizationConstants.ownedAttributeFor("Vip")] = true
		end
		return { GetAttribute = function(_, name) return attributes[name] end }
	end

	local freeKey, vipKey
	for _, palette in Palettes.list do
		if palette.source == "Vip" and not vipKey then vipKey = palette.key end
		if palette.source == "Free" and not freeKey then freeKey = palette.key end
	end

	t.test("a free palette is owned by everyone", function()
		expect.truthy(CosmeticsService.ownsPalette(fakePlayer(false), freeKey))
	end)

	t.test("a Vip palette is refused without the pass", function()
		expect.falsy(CosmeticsService.ownsPalette(fakePlayer(false), vipKey))
	end)

	t.test("a Vip palette is allowed with the pass", function()
		expect.truthy(CosmeticsService.ownsPalette(fakePlayer(true), vipKey))
	end)

	t.test("an unknown key is never owned, pass or no pass", function()
		expect.falsy(CosmeticsService.ownsPalette(fakePlayer(true), "NoSuchPalette"))
	end)

	t.test("attributeFor is stable and sanitises a weapon name with a space", function()
		expect.equal(CosmeticsService.attributeFor("Mossberg 590"), "EquippedSkin_Mossberg_590")
	end)

	t.test("every weapon in the armoury maps to a legal, unique attribute name", function()
		-- Not decorative. Roblox rejects an attribute name containing a space, hyphen or '&', and 16
		-- of the 29 weapon names contain one ("AUG A-3", "S&W 29", "Mossberg 590"...). Without the
		-- sanitising gsub the equip remote throws for over half the armoury. And two weapons must
		-- never collapse to the same key, or they would silently share one skin.
		local probe = Instance.new("Part")
		local seen = {}
		for _, tool in game.ServerStorage.Weapons:GetChildren() do
			if tool:IsA("Tool") then
				local key = CosmeticsService.attributeFor(tool.Name)
				expect.falsy(seen[key])
				seen[key] = tool.Name
				expect.truthy(pcall(function() probe:SetAttribute(key, "x") end))
			end
		end
	end)
end
```

- [ ] **Step 2: Run it and confirm the last three fail**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("CosmeticsOwnership")
```

Expected: fails until Task 3's service exists; if Task 3 is done, all five pass already except any naming mismatch, which this catches.

- [ ] **Step 3: Create the remote and handle it**

Create the RemoteEvent:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local folder = ReplicatedStorage.Cosmetics:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage.Cosmetics
end
local remote = Instance.new("RemoteEvent")
remote.Name = "EquipSkinRequest"
remote.Parent = folder
return remote:GetFullName()
```

Append to `CosmeticsService`, before `return CosmeticsService`:

```lua
-- The client asks; the server decides. Ownership is re-checked here rather than trusted from the
-- caller, so a forged request naming a Vip palette from a player without the pass is refused.
ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest.OnServerEvent:Connect(
	function(player: Player, weaponName: unknown, paletteKey: unknown)
		if typeof(weaponName) ~= "string" or typeof(paletteKey) ~= "string" then
			return
		end
		if not CosmeticsService.ownsPalette(player, paletteKey) then
			return
		end
		player:SetAttribute(CosmeticsService.attributeFor(weaponName), paletteKey)
		CosmeticsService.refresh(player, weaponName)
	end
)
```

- [ ] **Step 4: Run the tests and confirm they pass**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("CosmeticsOwnership")
```

Expected: 6 passed, 0 failed. Measured today: 29 tools, 0 key collisions, 0 rejected keys.

- [ ] **Step 5: Prove the server refuses a forged request, live**

Client datamodel, with no Vip pass:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest:FireServer("Crowbar", "Gold")
task.wait(1)
return "EquippedSkin_Crowbar = " .. tostring(player:GetAttribute("EquippedSkin_Crowbar"))
```

Expected: unchanged — **not** `Gold`. Then grant the pass attribute server-side and repeat; it becomes `Gold`.

- [ ] **Step 6: Commit**

```bash
git add FPSSystem/
git commit -m "Add the server-authoritative skin equip remote"
```

---

## Task 6: Figma design for the skin chip

The 290x60 free region is the hard constraint. Eight 84x84 named chips need ~730px, so the chip is a
**swatch only** — no name label. A row of colour swatches is a standard skin picker and the panel has
no room for text. The palette name is not lost: it is what the chip's tooltip-free accent outline and
the Figma spec call the equipped state, and names remain in `Palettes.list` for later surfaces.

**Files:**
- Figma file `iRetcvpbMMD190DJA9Mwrm`, page `02 · Redesign`

**Interfaces:**
- Consumes: the design tokens and the measured geometry in Global Constraints
- Produces: a `SkinChip` 52x52 in four states, and the `SkinRow` 290x60 container, for Task 7

- [ ] **Step 1: Load the Figma skill**

REQUIRED: invoke `figma:figma-use` before any `use_figma` call. Skipping it causes hard-to-debug failures.

- [ ] **Step 2: Read the existing detail panel frame**

Use `get_metadata` on the file and locate the `WeaponaryShop` detail panel frame, so the new row is
drawn against the real panel rather than on blank canvas.

- [ ] **Step 3: Draw the row and the four chip states**

`SkinRow`: 290x60, fill `#171A22`, 8px radius, 4px inner padding.

`SkinChip`: 52x52, 8px corner radius, the palette's `Body` tint as the whole fill. Four states, drawn
side by side so they can be compared:

- **Rest** — swatch at full opacity, no stroke.
- **Hover** — 2px `#CBF23C` stroke at 40% transparency.
- **Equipped** — 2px `#CBF23C` stroke at full opacity.
- **Locked** — swatch at 35% opacity with a 20x20 lock glyph centred, glyph `#8A8F9A`.

Eight chips at 52px with 6px gaps span 458px, which is wider than 290. That is intended: the row
scrolls horizontally and shows four and a half chips at rest, which is the visual cue that more exist.

- [ ] **Step 4: Screenshot and check at true size**

Use `get_screenshot` on the frame. Confirm the lock glyph is still legible at 52px, and that a dark
palette (Obsidian, `#101014`) is still distinguishable from the `#171A22` row behind it. If it is not,
add a 1px `#2A2E38` stroke to the rest state for all chips.

- [ ] **Step 5: Export the lock glyph**

`download_assets` the lock glyph at 4x, then upload it through the existing image pipeline and record
the returned asset id. It is the only new image this phase needs.

- [ ] **Step 6: Commit**

```bash
git add FPSSystem/
git commit -m "Add change log: skin chip states designed in Figma"
```

---

## Task 7: The skins row in the detail panel

**Files:**
- Modify: `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel` — add `SkinRow`
- Create: `StarterPlayer.StarterPlayerScripts.SkinRowController` (ModuleScript)
- Modify: `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — call the row

**Interfaces:**
- Consumes: `Palettes.list` (Task 1), `SkinApplier.applyKey` (Task 2), `EquipSkinRequest` (Task 5)
- Produces: `SkinRowController.build(row, chipTemplate, weaponName, previewModel) -> (() -> ())`
  returning a repaint function

- [ ] **Step 1: Build the row and chip template**

Run once in the Edit datamodel. Exact numbers, taken from the measured geometry:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local detail = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel

local existing = detail:FindFirstChild("SkinRow")
if existing then existing:Destroy() end

-- A ScrollingFrame, not a Frame: eight 52px chips span 458px in a 290px slot, so the row must scroll.
local row = Instance.new("ScrollingFrame")
row.Name = "SkinRow"
row.Position = UDim2.fromOffset(0, 372)
row.Size = UDim2.fromOffset(290, 60)
row.BackgroundColor3 = Color3.fromHex("171A22")
row.BackgroundTransparency = 0
row.BorderSizePixel = 0
row.ScrollingDirection = Enum.ScrollingDirection.X
row.AutomaticCanvasSize = Enum.AutomaticSize.X
row.CanvasSize = UDim2.new()
row.ScrollBarThickness = 3
row.ScrollBarImageColor3 = Color3.fromHex("CBF23C")
row.ScrollBarImageTransparency = 0.6
row.Parent = detail

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = row

local padding = Instance.new("UIPadding")
for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
	padding[side] = UDim.new(0, 4)
end
padding.Parent = row

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = row

local chip = Instance.new("ImageButton")
chip.Name = "SkinChip"
chip.Size = UDim2.fromOffset(52, 52)
chip.BackgroundColor3 = Color3.fromRGB(163, 162, 165)
chip.BorderSizePixel = 0
chip.AutoButtonColor = false
chip.Image = ""
chip.Visible = false
chip.Parent = row

local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0, 8)
chipCorner.Parent = chip

-- Transparency 1 at rest; the controller tweens it to 0 for the equipped chip and 0.6 on hover.
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromHex("CBF23C")
stroke.Transparency = 1
stroke.Parent = chip

local lock = Instance.new("ImageLabel")
lock.Name = "Lock"
lock.Size = UDim2.fromOffset(20, 20)
lock.AnchorPoint = Vector2.new(0.5, 0.5)
lock.Position = UDim2.fromScale(0.5, 0.5)
lock.BackgroundTransparency = 1
lock.ImageColor3 = Color3.fromHex("8A8F9A")
lock.Visible = false
lock.Parent = chip

return row:GetFullName() .. "  chipTemplate=" .. chip:GetFullName()
```

Set `lock.Image` to the asset id recorded in Task 6 Step 5.

- [ ] **Step 2: Write the controller**

Create `StarterPlayer.StarterPlayerScripts.SkinRowController` as a **ModuleScript**:

```lua
-- The skins row under the weapon detail panel. One chip per palette; clicking one asks the server to
-- equip it and recolours the spinning preview immediately so the choice reads before the round trip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)

local player = Players.LocalPlayer
local equipRemote = ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest
local promptGamepass = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase

local STROKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACCENT_HOVER_TRANSPARENCY = 0.6

local SkinRowController = {}

-- Must match CosmeticsService.attributeFor on the server. Duplicated rather than shared because the
-- server module lives in ServerScriptService, which the client cannot require.
local function attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

local function ownsVip(): boolean
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor("Vip")) == true
end

-- Builds the chips for one weapon. Returns a repaint function so the caller can refresh the equipped
-- outline on attribute change without rebuilding the row.
function SkinRowController.build(
	row: ScrollingFrame,
	chipTemplate: ImageButton,
	weaponName: string,
	previewModel: Instance?
): () -> ()
	for _, child in row:GetChildren() do
		if child:IsA("ImageButton") and child ~= chipTemplate then
			child:Destroy()
		end
	end

	local chips: { [string]: ImageButton } = {}
	local equippedKey: string? = nil

	local function repaint()
		local current = player:GetAttribute(attributeFor(weaponName))
		if typeof(current) ~= "string" then
			current = Palettes.DEFAULT_KEY
		end
		equippedKey = current
		for key, chip in chips do
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = key == current and 0 or 1 }):Play()
			end
		end
	end

	for index, palette in Palettes.list do
		local locked = palette.source == "Vip" and not ownsVip()
		local chip = chipTemplate:Clone()
		chip.Name = palette.key
		chip.Visible = true
		chip.LayoutOrder = index
		chip.BackgroundColor3 = palette.tints.Body
		chip.BackgroundTransparency = locked and 0.65 or 0
		chip.Lock.Visible = locked
		chip.Parent = row
		chips[palette.key] = chip

		local stroke = chip:FindFirstChildOfClass("UIStroke")

		chip.MouseEnter:Connect(function()
			if stroke and palette.key ~= equippedKey then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = ACCENT_HOVER_TRANSPARENCY }):Play()
			end
		end)
		chip.MouseLeave:Connect(function()
			if stroke and palette.key ~= equippedKey then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = 1 }):Play()
			end
		end)

		chip.MouseButton1Click:Connect(function()
			if locked then
				-- MonetizationService already disables the prompt for an unconfigured pass id, so
				-- this is safe to fire before the place is published.
				promptGamepass:FireServer("Vip")
				return
			end
			equipRemote:FireServer(weaponName, palette.key)
			if previewModel then
				SkinApplier.applyKey(previewModel, palette.key)
			end
		end)
	end

	repaint()
	return repaint
end

return SkinRowController
```

- [ ] **Step 3: Call it from the shop controller**

In `WeaponaryShopController`, in the function that populates the detail panel, after the preview model
has been built and framed in `DetailViewport`, add:

```lua
	local repaintSkins = SkinRowController.build(
		detailPanel.SkinRow, detailPanel.SkinRow.SkinChip, weapon.Name, previewModel
	)
	local skinAttributeConnection = player:GetAttributeChangedSignal(
		"EquippedSkin_" .. (string.gsub(weapon.Name, "[^%w_]", "_"))
	):Connect(repaintSkins)
```

Disconnect `skinAttributeConnection` wherever the controller already tears down the detail panel's
other connections. Leaving it connected leaks one connection per weapon viewed.

Add at the top, beside the other requires:

```lua
local SkinRowController = require(script.Parent.SkinRowController)
```

- [ ] **Step 4: Verify the row live**

Open the shop and select a weapon, then in the Client datamodel:

```lua
local Players = game:GetService("Players")
local row
for _, d in Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d.Name == "SkinRow" and d:IsA("ScrollingFrame") then row = d break end
end
local shown, locked = 0, 0
for _, chip in row:GetChildren() do
	if chip:IsA("ImageButton") and chip.Visible then
		shown += 1
		if chip.Lock.Visible then locked += 1 end
	end
end
return string.format("chips=%d locked=%d  AbsSize=%s  CanvasX=%.0f",
	shown, locked, tostring(row.AbsoluteSize), row.AbsoluteCanvasSize.X)
```

Expected without the Vip pass: `chips=8 locked=3`, `AbsSize=290, 60`, and `CanvasX` about 458 —
proving the canvas really is wider than the window, so the row scrolls rather than clipping silently.

- [ ] **Step 5: Confirm the row displaced nothing**

```lua
local Players = game:GetService("Players")
local detail
for _, d in Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d.Name == "DetailPanel" then detail = d break end
end
local rows = {}
for _, name in { "DetailViewport", "PriceLabel", "ActionButton", "EquipButton", "StatsContainer" } do
	local c = detail:FindFirstChild(name)
	table.insert(rows, name .. "=" .. tostring(c.AbsolutePosition))
end
return table.concat(rows, "  ")
```

Expected: identical to the same reading taken before Step 1. `AbsolutePosition`, not `Position` — the
panel has no layout, but a stray `UIListLayout` added by mistake would show up here and nowhere else.

- [ ] **Step 6: Confirm clicking a locked chip does not equip**

Click a Vip chip without the pass, then:

```lua
local Players = game:GetService("Players")
return tostring(Players.LocalPlayer:GetAttribute("EquippedSkin_Crowbar"))
```

Expected: unchanged. The purchase prompt may appear or be silently disabled depending on whether the
pass id is configured; either is correct before publish.

- [ ] **Step 7: Commit**

```bash
git add FPSSystem/
git commit -m "Add the skins row to the weapon detail panel"
```

---

## Task 8: Full verification pass

No new code. This task produces the numbers the change log must cite.

- [ ] **Step 1: Third person**

Equip a skinned weapon, then read the colour back off the **live** Tool in the character, not the template.

- [ ] **Step 2: First person**

Confirm `player.CameraMode == Enum.CameraMode.LockFirstPerson` and the viewmodel's `Body.Color` equals the palette tint.

- [ ] **Step 3: Rig undisturbed**

Re-measure the hand-to-weapon gap on the skinned viewmodel. Expected: unchanged from the post-fix figures, worst 0.25 and mean 0.041 studs.

- [ ] **Step 4: Removal is exact**

Apply a palette, then equip `Stock`, and confirm every part's `Color` matches its pre-skin value and no `SkinOriginalColor` attribute remains.

- [ ] **Step 5: Survives respawn**

Equip a skin, kill the player, wait for respawn, and read the colour off the new Tool.

- [ ] **Step 6: Damage unaffected**

Fire the same weapon skinned and unskinned at a pinned enemy; damage figures must be identical.

- [ ] **Step 7: Server-authoritative**

Fire `EquipSkinRequest` with a Vip key and no pass; the attribute must not change.

- [ ] **Step 8: Ownership is not in a hot path**

Confirm `CosmeticsService` calls no `MarketplaceService` method per frame — ownership is read from the replicated attribute that `MonetizationService` already publishes once per player.

- [ ] **Step 9: The damage path is still clean**

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local leaks = {}
for _, s in { ServerScriptService.Blaster.Scripts.ShotResolver, ServerScriptService.Weapons.Scripts.WeaponUpgradeService } do
	if s.Source:find("Cosmetics") or s.Source:find("Palettes") or s.Source:find("SkinApplier") then
		table.insert(leaks, s.Name)
	end
end
return #leaks == 0 and "clean" or ("LEAK: " .. table.concat(leaks, ", "))
```

Expected: `clean`.

- [ ] **Step 10: Write the change log and commit**

Write `FPSSystem/FPS-Weapon-Skins-Phase-1.md` in the project's Summary / Cause / Changes / Verification / Notes shape, citing every number above and stating plainly which checks were confirmed live and which still need a person.

```bash
git add FPSSystem/
git commit -m "Add change log: weapon skins, Phase 1"
```
