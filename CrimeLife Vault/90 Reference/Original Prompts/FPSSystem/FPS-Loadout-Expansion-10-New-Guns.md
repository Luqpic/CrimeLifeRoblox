# Prompt: Loadout Expansion — 10 New Weapons

## Context

The user prepared 10 new gun models, sitting as raw, completely unprocessed meshes in
`Workspace."New Guns to implement"`:

- **Ungrouped** (the ones the user asked me to determine auto/burst/real-world accuracy for):
  `M14 EBR`, `AR-18`, `APS`, `HK G3`
- **`Pistols`** group: `PB`, `MP443`, `Glock 17`, `S&W 29`
- **`Shotguns`** group: `Itacha Mag-10`, `Benelli M4`

Each raw model is just a handful of generically-named `MeshPart`s (literally all named
`"MeshPart"`) — no `Handle`, no `Tool`, no attachments, no rig, no gameplay attributes at all.
This is the true starting point; a separate, unrelated 11-weapon roster
(`AKM`, `AMB-17`, `AUG A-3`, `Kriss Vector`, `M16A1`, `M1911`, `MP9`, `Mateba 2006M`,
`Mossberg 590`, `Scar L`, `Sig MPX`) is already fully built and live in
`ServerStorage.Weapons` from an earlier, separate round of work — those are used below purely as
**reference templates** for geometry, animations, and sounds, per the user's own instruction
("may use the other weapons as reference... reuse the same mechanism from other weapons").

**Important lesson baked into this prompt:** the Baton weapon (see
`FPS-Baton-Rig-Weld-Fixes-Applied.md`) broke in exactly this class of way — a `WeldConstraint`
left pointing at the wrong instance, and a viewmodel rig missing its arm joints entirely. Every
weld and joint built below is constructed so it can ONLY point at this weapon's own parts, never a
reference weapon's parts left over from a clone.

## What already works generically — no changes needed

- The shop (`WeaponaryShopController`) and catalog builder (`WeaponShopService`) build their entries
  generically off any `Tool` in `ServerStorage.Weapons` that has a `Category` attribute. `AutoRifle`,
  `Pistol`, and `Shotgun` — the only categories these 10 need — already exist as shop tabs. **Nothing
  in the shop/catalog/UI code needs to change for this task.**
- `Constants.FIRE_MODE.BURST` is fully implemented in `BlasterController` (3-round bursts at the
  weapon's own `rateOfFire`) — confirmed live, not a dead label.

## Fire-mode / category determinations (real-world-based, per the user's ask)

| Weapon | Category | Fire mode | Reasoning |
|---|---|---|---|
| AR-18 | AutoRifle | Auto | Real AR-18 was issued select-fire military/police; no burst variant ever existed. |
| HK G3 | AutoRifle | Auto | Real G3 is safe/semi/auto only (roller-delayed blowback); no burst trigger group exists for it. |
| APS (Stechkin) | **Pistol** | **Auto** | Real APS is a genuine select-fire machine pistol (~700-750rpm full-auto). It's a pistol, not a rifle — almost certainly why it was left ungrouped rather than dropped in `Pistols`, since it doesn't behave like the semi-only pistols there. |
| M14 EBR | AutoRifle | **Semi** | Deliberate deviation from "auto or burst": the real M14 EBR/Mk14 is specifically the modern semi-auto-only DMR variant — that's the entire point of the EBR chassis. User approved this call; flagged here again as the one non-obvious choice. |

## Full stat table

Values reasoned from each weapon's real ballistics, scaled against the existing roster's already-
established conventions (e.g. `AKM`=18dmg/7.62×39 Auto, `M1911`=38dmg/.45ACP Semi,
`Mossberg 590`=15dmg-per-pellet/12ga Semi, 8 `raysPerShot`).

| Weapon | Category | fireMode | damage | rateOfFire | magazineSize | range | reloadTime | spread | recoilMin | recoilMax | unanchoredImpulseForce | Price | Other |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| M14 EBR | AutoRifle | Semi | 34 | 350 | 20 | 1000 | 2.4 | 1.2 | (-5, 13) | (5, 20) | 4 | 900 | |
| AR-18 | AutoRifle | Auto | 16 | 750 | 30 | 1000 | 2.0 | 2.0 | (-3, 8) | (3, 13) | 3 | 425 | |
| APS | Pistol | Auto | 12 | 700 | 20 | 800 | 1.5 | 4.0 | (-3, 6) | (3, 10) | 3 | 575 | |
| HK G3 | AutoRifle | Auto | 22 | 550 | 20 | 1000 | 2.2 | 2.5 | (-5, 11) | (5, 18) | 4 | 550 | |
| PB | Pistol | Semi | 32 | 350 | 8 | 750 | 1.4 | 2.0 | (0, 9) | (3, 14) | 4 | 500 | |
| MP443 | Pistol | Semi | 30 | 400 | 17 | 850 | 1.2 | 2.0 | (0, 11) | (2, 16) | 5 | 450 | |
| Glock 17 | Pistol | Semi | 28 | 450 | 17 | 850 | 1.1 | 1.8 | (0, 8) | (2, 13) | 5 | 400 | |
| S&W 29 | Pistol | Semi | 55 | 200 | 6 | 900 | 2.3 | 3.0 | (2, 24) | (9, 32) | 8 | 850 | |
| Itacha Mag-10 | Shotgun | Semi | 18 | 70 | 4 | 550 | 0.6 | 10.0 | (-8, 30) | (14, 42) | 8 | 900 | `isShotgun=true`, `raysPerShot=10`, `rayRadius=0.5`, `knockbackForce=70` |
| Benelli M4 | Shotgun | Semi | 15 | 180 | 7 | 550 | 0.5 | 8.0 | (-4, 18) | (7, 26) | 6 | 850 | `isShotgun=true`, `raysPerShot=8`, `rayRadius=0.5`, `knockbackForce=50` |

All non-shotgun entries: `raysPerShot = 1`, `rayRadius = 0.4` (matches every existing rifle/pistol).

## Reference weapon per category (for geometry, animations, sounds)

- **AutoRifle** reference: `AKM` — confirmed complete: `Handle` + `Blaster` (`Body`/`Magazine`/
  `TrimA-E`, each with its own `WeldConstraint` → this Tool's own `Handle`), `Sounds`
  (Equip/Charger/MagIn/MagOut/Shoot), `Animations` (Idle/Shoot/Reload), `Scripts.Blaster`, a tuned
  `Grip`, and a viewmodel with `Root`/`LeftArm`/`RightArm` + joints.
- **Pistol** reference: `M1911` — same completeness, tuned for a handgun hold.
- **Shotgun** reference: `Mossberg 590` — same completeness, tuned for a two-handed long-gun hold.

fireMode/Category are set independently per the stat table above — the reference is used ONLY for
physical geometry, animations, and sounds, never for gameplay attributes.

## Build script

Run this in **Edit mode** (`datamodel_type: "Edit"`) via Studio MCP `execute_luau`, or paste into a
Command Bar / one-shot Script. It is idempotent per weapon (skips a weapon if
`ServerStorage.Weapons` already has that name) so it's safe to re-run after fixing one weapon by
hand.

```lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local STAGING = Workspace:WaitForChild("New Guns to implement")
local WEAPONS = ServerStorage.Weapons
local VIEWMODELS = ReplicatedStorage.Blaster.ViewModels

-- ============================================================================
-- CONFIG -- one entry per new weapon.
-- ============================================================================
local WEAPONS_TO_BUILD = {
	{
		name = "M14 EBR", rawPath = { "M14 EBR" }, referenceWeapon = "AKM",
		attributes = {
			Category = "AutoRifle", fireMode = "Semi", Price = 900, damage = 34, rateOfFire = 350,
			magazineSize = 20, range = 1000, reloadTime = 2.4, spread = 1.2,
			recoilMin = Vector2.new(-5, 13), recoilMax = Vector2.new(5, 20),
			unanchoredImpulseForce = 4, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "AR-18", rawPath = { "AR-18" }, referenceWeapon = "AKM",
		attributes = {
			Category = "AutoRifle", fireMode = "Auto", Price = 425, damage = 16, rateOfFire = 750,
			magazineSize = 30, range = 1000, reloadTime = 2.0, spread = 2.0,
			recoilMin = Vector2.new(-3, 8), recoilMax = Vector2.new(3, 13),
			unanchoredImpulseForce = 3, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "APS", rawPath = { "APS" }, referenceWeapon = "M1911",
		attributes = {
			Category = "Pistol", fireMode = "Auto", Price = 575, damage = 12, rateOfFire = 700,
			magazineSize = 20, range = 800, reloadTime = 1.5, spread = 4.0,
			recoilMin = Vector2.new(-3, 6), recoilMax = Vector2.new(3, 10),
			unanchoredImpulseForce = 3, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "HK G3", rawPath = { "HK G3" }, referenceWeapon = "AKM",
		attributes = {
			Category = "AutoRifle", fireMode = "Auto", Price = 550, damage = 22, rateOfFire = 550,
			magazineSize = 20, range = 1000, reloadTime = 2.2, spread = 2.5,
			recoilMin = Vector2.new(-5, 11), recoilMax = Vector2.new(5, 18),
			unanchoredImpulseForce = 4, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "PB", rawPath = { "Pistols", "PB" }, referenceWeapon = "M1911",
		attributes = {
			Category = "Pistol", fireMode = "Semi", Price = 500, damage = 32, rateOfFire = 350,
			magazineSize = 8, range = 750, reloadTime = 1.4, spread = 2.0,
			recoilMin = Vector2.new(0, 9), recoilMax = Vector2.new(3, 14),
			unanchoredImpulseForce = 4, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "MP443", rawPath = { "Pistols", "MP443" }, referenceWeapon = "M1911",
		attributes = {
			Category = "Pistol", fireMode = "Semi", Price = 450, damage = 30, rateOfFire = 400,
			magazineSize = 17, range = 850, reloadTime = 1.2, spread = 2.0,
			recoilMin = Vector2.new(0, 11), recoilMax = Vector2.new(2, 16),
			unanchoredImpulseForce = 5, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "Glock 17", rawPath = { "Pistols", "Glock 17" }, referenceWeapon = "M1911",
		attributes = {
			Category = "Pistol", fireMode = "Semi", Price = 400, damage = 28, rateOfFire = 450,
			magazineSize = 17, range = 850, reloadTime = 1.1, spread = 1.8,
			recoilMin = Vector2.new(0, 8), recoilMax = Vector2.new(2, 13),
			unanchoredImpulseForce = 5, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "S&W 29", rawPath = { "Pistols", "S&W 29" }, referenceWeapon = "M1911",
		attributes = {
			Category = "Pistol", fireMode = "Semi", Price = 850, damage = 55, rateOfFire = 200,
			magazineSize = 6, range = 900, reloadTime = 2.3, spread = 3.0,
			recoilMin = Vector2.new(2, 24), recoilMax = Vector2.new(9, 32),
			unanchoredImpulseForce = 8, raysPerShot = 1, rayRadius = 0.4,
		},
	},
	{
		name = "Itacha Mag-10", rawPath = { "Shotguns", "Itacha Mag-10" }, referenceWeapon = "Mossberg 590",
		attributes = {
			Category = "Shotgun", fireMode = "Semi", Price = 900, damage = 18, rateOfFire = 70,
			magazineSize = 4, range = 550, reloadTime = 0.6, spread = 10.0,
			recoilMin = Vector2.new(-8, 30), recoilMax = Vector2.new(14, 42),
			unanchoredImpulseForce = 8, raysPerShot = 10, rayRadius = 0.5,
			isShotgun = true, knockbackForce = 70,
		},
	},
	{
		name = "Benelli M4", rawPath = { "Shotguns", "Benelli M4" }, referenceWeapon = "Mossberg 590",
		attributes = {
			Category = "Shotgun", fireMode = "Semi", Price = 850, damage = 15, rateOfFire = 180,
			magazineSize = 7, range = 550, reloadTime = 0.5, spread = 8.0,
			recoilMin = Vector2.new(-4, 18), recoilMax = Vector2.new(7, 26),
			unanchoredImpulseForce = 6, raysPerShot = 8, rayRadius = 0.5,
			isShotgun = true, knockbackForce = 50,
		},
	},
}

-- ============================================================================
-- GEOMETRY HELPER
--
-- Every raw model in "New Guns to implement" shares an identical WorldPivot.Rotation (verified
-- live), meaning they were all normalized the same way on import -- so a fractional position within
-- one model's bounding box carries meaningfully onto another's. This is used to "transplant" a
-- known-good anchor point (a reference weapon's Handle, or its viewmodel Body's attach point) from
-- the reference weapon's own geometry onto a new, differently-shaped mesh: same fractional position
-- along each local axis, same local rotation.
--
-- This is inherently a best-effort placement, not a verified one -- there is no working screenshot
-- tool in this environment to visually confirm hand/grip alignment. Every weapon built by this
-- script MUST be checked in-game per the testing section below, exactly like the Baton.
-- ============================================================================
local function transplantAnchor(refBoundsCFrame, refBoundsSize, refAnchorCFrame, newBoundsCFrame, newBoundsSize)
	local localCFrame = refBoundsCFrame:ToObjectSpace(refAnchorCFrame)
	local fraction = Vector3.new(
		refBoundsSize.X > 0.001 and localCFrame.Position.X / refBoundsSize.X or 0,
		refBoundsSize.Y > 0.001 and localCFrame.Position.Y / refBoundsSize.Y or 0,
		refBoundsSize.Z > 0.001 and localCFrame.Position.Z / refBoundsSize.Z or 0
	)
	local newLocalPosition = Vector3.new(
		fraction.X * newBoundsSize.X,
		fraction.Y * newBoundsSize.Y,
		fraction.Z * newBoundsSize.Z
	)
	local rotationOnly = localCFrame - localCFrame.Position
	return newBoundsCFrame * CFrame.new(newLocalPosition) * rotationOnly
end

local function findRawModel(rawPath)
	local current = STAGING
	for _, segment in rawPath do
		current = current:FindFirstChild(segment)
		assert(current, "Missing raw model at staging path: " .. table.concat(rawPath, "."))
	end
	return current
end

local function largestPart(model)
	local best, bestVolume = nil, -1
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if volume > bestVolume then
				best, bestVolume = part, volume
			end
		end
	end
	return best
end

-- ============================================================================
-- BUILD ONE WEAPON
-- ============================================================================
local function buildWeapon(config)
	if WEAPONS:FindFirstChild(config.name) then
		print("[skip] " .. config.name .. " already exists in ServerStorage.Weapons")
		return
	end

	local raw = findRawModel(config.rawPath)
	local reference = WEAPONS:FindFirstChild(config.referenceWeapon)
	local refViewmodel = VIEWMODELS:FindFirstChild(config.referenceWeapon)
	assert(reference and refViewmodel, "Reference weapon not found: " .. config.referenceWeapon)

	-- Identify the main body (largest part by volume) vs. trim; every raw model's parts are
	-- currently all generically named "MeshPart".
	local bodyPart = largestPart(raw)
	bodyPart.Name = "Body"
	local trimLetters = "ABCDEFGHIJ"
	local trimIndex = 0
	for _, part in raw:GetChildren() do
		if part:IsA("BasePart") and part ~= bodyPart then
			trimIndex += 1
			part.Name = "Trim" .. trimLetters:sub(trimIndex, trimIndex)
		end
	end

	-- ---- World model: Handle + Blaster, welded exactly like AKM (verified pattern: every visible
	-- part gets its OWN WeldConstraint, Part1 = THIS weapon's own Handle -- never a foreign one).
	local rawBounds, rawSize = raw:GetBoundingBox()
	local refBlaster = reference.Blaster
	local refBounds, refSize = refBlaster:GetBoundingBox()

	local handleCFrame = transplantAnchor(refBounds, refSize, reference.Handle.CFrame, rawBounds, rawSize)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = handleCFrame

	for _, part in raw:GetChildren() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = handle
			weld.Parent = part
		end
	end

	local blasterModel = Instance.new("Model")
	blasterModel.Name = "Blaster"
	for _, part in raw:GetChildren() do
		part.Parent = blasterModel
	end
	blasterModel.PrimaryPart = bodyPart

	local tool = Instance.new("Tool")
	tool.Name = config.name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.TextureId = "" -- placeholder per instruction; falls back to the name-label already used
	                     -- for icon-less weapons (same fix applied to the Baton)
	tool.Grip = reference.Grip -- reused verbatim; the physical hold pose is carried by Handle's
	                            -- own transplanted placement above, not by re-deriving Grip

	for attrName, value in config.attributes do
		tool:SetAttribute(attrName, value)
	end
	tool:SetAttribute("viewModel", config.name)
	tool:SetAttribute("_ammo", config.attributes.magazineSize)
	tool:SetAttribute("_reloading", false)

	handle.Parent = tool
	blasterModel.Parent = tool
	reference.Sounds:Clone().Parent = tool
	reference.Animations:Clone().Parent = tool
	reference.Scripts:Clone().Parent = tool

	tool.Parent = WEAPONS

	-- ---- Viewmodel: clone the reference weapon's viewmodel wholesale (Root/LeftArm/RightArm/
	-- joints/AnimationController/AnimSaves), then swap in this weapon's own mesh, placed via the
	-- same transplant technique, and rig BodyJoint/arm joints so they point ONLY at this weapon's
	-- own parts -- never left pointing at the reference's parts (the exact Baton bug).
	local viewmodel = refViewmodel:Clone()
	viewmodel.Name = config.name
	local refVmBlaster = viewmodel.Blaster
	local refVmBody = refVmBlaster.Body
	local refVmBounds, refVmSize = refVmBlaster:GetBoundingBox()
	local refVmLeftJoint = viewmodel.LeftArm.LeftArmJoint
	local refVmRightJoint = viewmodel.RightArm.RightArmJoint
	viewmodel.Blaster:Destroy()

	local vmBlasterModel = tool.Blaster:Clone() -- reuses the just-built world Blaster; mesh + welds
	                                             -- carry over intact, referencing the CLONE's own parts
	vmBlasterModel.Name = "Blaster"
	local vmBody = vmBlasterModel:FindFirstChild("Body")
	local vmBounds, vmSize = vmBlasterModel:GetBoundingBox()

	local targetBodyCFrame = transplantAnchor(refVmBounds, refVmSize, refVmBody.CFrame, vmBounds, vmSize)
	-- vmBlasterModel's PrimaryPart is vmBody (carried over from the world-model build, where it was
	-- set on the original before cloning), so PivotTo(targetBodyCFrame) moves Body to exactly that
	-- CFrame and drags every other welded part along with it, preserving their relative geometry.
	vmBlasterModel:PivotTo(targetBodyCFrame)

	vmBlasterModel.Parent = viewmodel

	local bodyJoint = Instance.new("Motor6D")
	bodyJoint.Name = "BodyJoint"
	bodyJoint.Part0 = viewmodel.Root
	bodyJoint.Part1 = vmBody
	bodyJoint.C1 = CFrame.new()
	bodyJoint.C0 = viewmodel.Root.CFrame:ToObjectSpace(vmBody.CFrame)
	bodyJoint.Parent = vmBody

	-- Hand grip points on the new Body mesh, transplanted from where the reference weapon's arm
	-- joints anchor onto ITS OWN Body (same technique, scoped to Body's bounding box instead of the
	-- whole weapon's).
	local refBodyBounds, refBodySize = refVmBody:GetBoundingBox()
	local vmBodyBounds, vmBodySize = vmBody:GetBoundingBox()

	local function rigArm(jointName, armName, refJoint)
		local arm = viewmodel[armName]
		local anchorCFrame = transplantAnchor(refBodyBounds, refBodySize, refVmBody.CFrame * refJoint.C0, vmBodyBounds, vmBodySize)
		local joint = Instance.new("Motor6D")
		joint.Name = jointName
		joint.Part0 = vmBody
		joint.Part1 = arm
		joint.C0 = vmBody.CFrame:ToObjectSpace(anchorCFrame)
		joint.C1 = refJoint.C1
		joint.Parent = arm
	end
	rigArm("LeftArmJoint", "LeftArm", refVmLeftJoint)
	rigArm("RightArmJoint", "RightArm", refVmRightJoint)

	viewmodel.Parent = VIEWMODELS

	print("[built] " .. config.name)
end

for _, config in WEAPONS_TO_BUILD do
	local ok, err = pcall(buildWeapon, config)
	if not ok then
		warn("[FAILED] " .. config.name .. ": " .. tostring(err))
	end
end

print("Done. Check ServerStorage.Weapons and ReplicatedStorage.Blaster.ViewModels for the 10 new entries.")
```

## Testing checklist (apply in this order — this is not optional given the geometry above is best-effort)

1. Run the script once in Edit mode. Confirm the console prints 10 `[built]` lines with no
   `[FAILED]` lines. If a weapon fails, read the error — most likely cause is a raw-path typo or a
   missing reference weapon.
2. Open the Weaponary shop: confirm all 10 new weapons appear under the correct tab (AutoRifle:
   M14 EBR/AR-18/HK G3; Pistol: APS/PB/MP443/Glock 17/S&W 29; Shotgun: Itacha Mag-10/Benelli M4),
   each showing its real name with no icon (blank placeholder, not a wrong/borrowed icon).
3. Buy and equip **each** of the 10 in turn. For each one, check in first person:
   - Are the hands/arms visible and gripping the weapon (not floating disconnected, not clipped
     through it)?
   - Does the weapon mesh look reasonably centered/oriented in view (not sideways, not way off to
     one edge)?
4. Check third person (or have another player look at you): does the weapon appear actually held in
   the hand, not dangling/floating disconnected?
5. Fire each weapon once: confirm the muzzle flash/raycast origin looks like it's coming from the
   barrel, not from somewhere on the body/stock. If it looks off, the fix is usually a `MuzzleAttachment`
   repositioning on that weapon's `Body` part specifically — flag which weapon(s) need it rather than
   redoing the whole build.
6. For any weapon that looks wrong in steps 3-5: **do not re-run the whole script.** Since it's
   idempotent (skips existing weapons), either delete just that one weapon's `Tool` +
   `ViewModels.<name>` and re-run, or manually adjust just that weapon's `Handle.CFrame` (world
   model) or `BodyJoint.C0` (viewmodel) in Studio directly — both are single, isolated values per
   weapon, not something that requires touching the other 9.
7. Confirm reload/shoot sounds and animations play (borrowed from the category reference weapon per
   the approved design) — if a specific weapon plays no sound/animation at all, check that its
   `Animations`/`Sounds` folders actually cloned (step 1's `[FAILED]` check should have caught this,
   but worth a spot-check).

## Notes for whoever applies this

- The 10 raw staging models under `Workspace."New Guns to implement"` are consumed (reparented) by
  the build script, not deleted outright — the folder itself and the `Pistols`/`Shotguns`
  sub-models will end up empty after a successful run. Safe to delete the now-empty staging folder
  once all 10 are confirmed working; leave it in place until then in case a weapon needs a rebuild.
- Once applied and verified against the checklist above, per the standing workflow: do NOT commit
  this prompt document to the git repo. Write a short plain-prose changelog entry instead (see
  `FPSSystem/`'s existing changelog template/history) and commit that, one commit per logical
  change, then push.
