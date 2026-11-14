# Prompt: Fix the 10 New Guns — Missing `MuzzleAttachment` Crashes the Controller

## User report

> "All the 10 guns we added aren't working. When I equip them, it just shows the player holding
> them like an object rather than a weapon. There's no viewmodel, no shooting mechanic whatsoever.
> I want you [to] redesign these 10 guns['] mechanism and ensure they have their respective
> mechanisms to shoot, viewmodel and everything we have did for the other guns."

This follows `FPS-Loadout-Expansion-10-New-Guns.md`, which added: `M14 EBR`, `AR-18`, `APS`, `HK G3`,
`PB`, `MP443`, `Glock 17`, `S&W 29`, `Itacha Mag-10`, `Benelli M4`.

## Root cause (confirmed via live `inspect_instance` / `search_game_tree`, not assumed)

`ReplicatedStorage.Blaster.Scripts.ViewModelController.new(blaster)` — the constructor every
equipped Tool's `Scripts.Blaster` LocalScript calls synchronously on load — contains:

```lua
local muzzle = viewModel:FindFirstChild("MuzzleAttachment", true)
assert(muzzle, `{viewModel} is missing MuzzleAttachment!`)
```

This runs **before** `BlasterController:initialize()` connects `Equipped`/`Unequipped`/`Activated`.
If it throws, the whole `BlasterController.new()` call errors out and the LocalScript that was
setting up the weapon dies right there — no event ever gets connected. With no custom logic wired
up at all, equipping the Tool falls back to plain built-in Roblox tool-holding (the Handle just
grips into the character's hand via `Tool.Grip`), which is exactly the reported symptom: "holding
it like an object," no viewmodel swap, no shooting.

**Confirmed exhaustively**, not sampled: a `search_game_tree` keyword search for `Muzzle` across
all of `ServerStorage.Weapons` and all of `ReplicatedStorage.Blaster.ViewModels` returns a
`MuzzleAttachment` under `Blaster.Body` for **all 17 of the original weapons** (including Baton and
Crowbar — melee weapons still carry an empty one, per an explicit comment in
`ViewModelController:playShootAnimation`: *"A melee weapon has no muzzle flash, so its
MuzzleAttachment is deliberately empty"*) and **zero of the 10 new weapons**, in either their world
Tool or their viewmodel. This is a gap in the original build script (`FPS-Loadout-Expansion-10-New-
Guns.md`) — it built Handle/Blaster/welds/rig but never created this Attachment. Confirmed nothing
else is wrong: `AR-18` was checked field-by-field against `AKM` (Handle, `Blaster.Body`
`WeldConstraint.Part1`, viewmodel `LeftArmJoint`/`RightArmJoint`, `Scripts.Blaster` LocalScript
content, attributes, cloned Animation/Sound IDs) and every one of those matches the known-good
pattern exactly — this one missing Attachment is the sole cause.

## What `MuzzleAttachment` needs to be

From the three category references (`AKM` for AutoRifle, `M1911` for Pistol, `Mossberg 590` for
Shotgun — same per-category reference assignment as the original build):

- An `Attachment` named `MuzzleAttachment`, parented directly to `Blaster.Body`, `Visible = false`.
- Its `CFrame` sits near the barrel's muzzle tip: local `Position.Z` is always `0` (centered on the
  part's thickness) and local `Position.Y` is consistently **40% of `Body.Size.Y / 2`** across all
  three references (AKM, M1911, and Mossberg 590 all land on exactly this fraction independently —
  a real authoring convention, not a coincidence). Local `Position.X` is category-specific (~98% of
  `Body.Size.X / 2` for AKM/M1911, ~136% for Mossberg 590 — the shotgun's barrel tip sits beyond its
  own Body mesh's bounding box), which is exactly why the fix below derives the fraction from each
  weapon's own category reference rather than using one constant.
- Its local `Rotation` copied as-is from the reference — every raw mesh in this batch already shares
  the reference's import orientation (verified in the original build), so the muzzle-forward
  direction carries over unchanged.
- A cloned `FlashEmitter` (ParticleEmitter) inside it, both world and viewmodel copies. The
  viewmodel copy additionally gets a cloned `CircleEmitter`. Both are optional at the code level
  (`FindFirstChild`-guarded in `playShootAnimation`), but every non-melee reference weapon has them,
  so the new guns get them too for visual parity — a missing emitter would silently mean "no muzzle
  flash," not a crash.

## Fix (apply via Studio MCP `execute_luau`, `datamodel_type: "Edit"`)

```lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CATEGORY_REFERENCE = {
	AutoRifle = "AKM",
	Pistol = "M1911",
	Shotgun = "Mossberg 590",
}

local NEW_WEAPON_CATEGORY = {
	["M14 EBR"] = "AutoRifle",
	["AR-18"] = "AutoRifle",
	["HK G3"] = "AutoRifle",
	["APS"] = "Pistol",
	["PB"] = "Pistol",
	["MP443"] = "Pistol",
	["Glock 17"] = "Pistol",
	["S&W 29"] = "Pistol",
	["Itacha Mag-10"] = "Shotgun",
	["Benelli M4"] = "Shotgun",
}

-- Scales the reference muzzle's LOCAL position by this Body's own half-size, so a body of a
-- different shape still gets a muzzle point near its own barrel tip instead of the reference's
-- absolute offset (which would land inside the mesh or far past it on a differently-sized gun).
local function computeMuzzleCFrame(refMuzzle: Attachment, refBody: BasePart, newBody: BasePart): CFrame
	local refHalf = refBody.Size / 2
	local refPos = refMuzzle.CFrame.Position
	local fracX = refPos.X / refHalf.X
	local fracY = refPos.Y / refHalf.Y

	local newHalf = newBody.Size / 2
	local newPosition = Vector3.new(fracX * newHalf.X, fracY * newHalf.Y, 0)

	-- Keep the reference's local rotation unchanged -- same import orientation across this whole batch.
	local refRotationOnly = refMuzzle.CFrame - refPos
	return CFrame.new(newPosition) * refRotationOnly
end

local function buildMuzzle(refBody: BasePart, newBody: BasePart)
	if newBody:FindFirstChild("MuzzleAttachment") then
		return "already present, skipped"
	end

	local refMuzzle = refBody:FindFirstChild("MuzzleAttachment")
	assert(refMuzzle, `reference body {refBody:GetFullName()} has no MuzzleAttachment`)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "MuzzleAttachment"
	muzzle.Visible = false
	muzzle.CFrame = computeMuzzleCFrame(refMuzzle, refBody, newBody)

	for _, emitterName in { "FlashEmitter", "CircleEmitter" } do
		local refEmitter = refMuzzle:FindFirstChild(emitterName)
		if refEmitter then
			local clone = refEmitter:Clone()
			clone.Parent = muzzle
		end
	end

	muzzle.Parent = newBody
	return "created"
end

local report = {}

for weaponName, category in NEW_WEAPON_CATEGORY do
	local ok, err = pcall(function()
		local referenceName = CATEGORY_REFERENCE[category]

		local worldTool = ServerStorage.Weapons:FindFirstChild(weaponName)
		local refWorldTool = ServerStorage.Weapons:FindFirstChild(referenceName)
		assert(worldTool, `missing world Tool for {weaponName}`)
		assert(refWorldTool, `missing reference world Tool for {referenceName}`)
		local worldResult = buildMuzzle(refWorldTool.Blaster.Body, worldTool.Blaster.Body)

		local viewModel = ReplicatedStorage.Blaster.ViewModels:FindFirstChild(weaponName)
		local refViewModel = ReplicatedStorage.Blaster.ViewModels:FindFirstChild(referenceName)
		assert(viewModel, `missing viewmodel for {weaponName}`)
		assert(refViewModel, `missing reference viewmodel for {referenceName}`)
		local viewModelResult = buildMuzzle(refViewModel.Blaster.Body, viewModel.Blaster.Body)

		report[weaponName] = `world: {worldResult}, viewmodel: {viewModelResult}`
	end)

	if not ok then
		report[weaponName] = "FAILED: " .. tostring(err)
	end
end

for weaponName, result in report do
	print(weaponName, "->", result)
end
```

Idempotent: re-running it skips any weapon that already has a `MuzzleAttachment`, so if only some of
the 10 fail on a first pass, it's safe to just run it again after investigating those individually.

## What this fix does NOT touch

Nothing else about the 10 weapons is being changed — Handle, welds, Motor6D rig, attributes,
Sounds/Animations, and the shop catalog were all verified correct already. This is a single
missing-instance fix, not a rebuild.

## Testing checklist

1. Equip one AutoRifle (e.g. `AR-18`), one Pistol (e.g. `Glock 17`), and one Shotgun (`Benelli M4`
   or `Itacha Mag-10`) from the loadout in Play mode.
2. Confirm the first-person viewmodel now actually appears (arms + gun model), not the plain
   built-in hold.
3. Confirm firing works: ammo counter ticks down, hit rays register, recoil kicks in.
4. Watch the muzzle flash position specifically — the fraction-based placement above is
   geometrically derived, not visually tuned (no working screenshot tool in this environment for
   Play-mode verification), so it's expected to be in the right general area (barrel tip) but may
   sit slightly off on some of the 10 depending on how each raw mesh's proportions differ from its
   category reference. If a specific gun's flash looks off, report which one and roughly which
   direction (too far forward/back, too high/low) so `MuzzleAttachment.CFrame` can be nudged for
   that weapon specifically rather than re-deriving all 10.
5. Repeat for the remaining 7 weapons at least once each before considering this closed.

## Status

**Applied** to the live Studio place (Edit DataModel) via Studio MCP on 2026-09-15. All 20 attachments
created (10 world Tools + 10 viewmodels); verified by re-running the constructor's own precondition
against a fresh clone of each of the 10 viewmodels — all 10 now pass the assert.

Change log committed as `FPSSystem/FPS-New-Guns-Missing-MuzzleAttachment-Fix.md`.

### Deviation from the fix as drafted

The `computeMuzzleCFrame` per-category-reference scaling above was **not** used. Measured across all
15 non-melee weapons, the muzzle fraction is not category-specific: 12 of them — rifles *and* pistols,
including `M1911` — sit at exactly `(-0.980, +0.400, 0)` of their own Body half-extents. `AK47`,
`Deagle` and `Mossberg 590` are per-mesh hand-tweaks, and `AKM`'s **viewmodel** is a further outlier at
`fracX = -1.598`. Two of those outliers were the drafted references, so the drafted rule would have
produced:

| weapon | via | result |
|---|---|---|
| M14 EBR / HK G3 / AR-18 (viewmodels) | AKM (-1.598) | 1.9–2.1 studs past their own barrel tip |
| Itacha Mag-10 | Mossberg 590 (-1.362) | 1.59 studs past |
| Benelli M4 | Mossberg 590 (-1.362) | 0.55 studs past |

The shared convention `(-0.980, +0.400, 0)` was applied instead; all 10 now land just *inside* their
own barrel face (0.015–0.088 studs in). Emitters are still cloned per category, so each gun keeps its
category's flash. A guard asserts the reference's muzzle rotation matches the canonical -90° Y before
building, so a future weapon with a different import orientation fails loudly rather than silently.

Orientation was verified independently rather than assumed: the Handle's position in Body-local space
on the 10 new guns matches the old weapons of the same category closely (new pistols -1.14..-1.25 vs
old pistols -1.00..-1.17; new rifles -0.04..+0.02 vs the old rifles' 0.00), confirming the batch does
share the reference import orientation and that -X is the barrel direction.

Placement is cosmetic only — muzzle flash, tracer origin and shot-sound position. `ShotResolver` does
not read it, so aim/damage/hit detection are unaffected by any placement error.

Still to do: the in-game checklist above (items 1-5). Play mode could not be driven from MCP this
session (stale plugin flag), so this needs a manual Play.
