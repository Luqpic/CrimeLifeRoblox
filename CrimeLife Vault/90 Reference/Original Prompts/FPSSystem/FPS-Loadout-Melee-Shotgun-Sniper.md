# Prompt: Add Melee, Shotgun, and Sniper Weapon Types + Name-Only Inventory Icons

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Overview

Unlike previous loadout additions, these three weapons are not just new content on the existing hitscan-rifle shape — each needs one small, targeted, **opt-in** addition to shared code:

| Weapon | New mechanic needed | Shared code touched |
|---|---|---|
| Crowbar (melee) | No ammo/reload at all | `BlasterController`, `GuiController`, `validateShot`, `ShotResolver` |
| Mossberg 590 (shotgun) | Push the hit player/enemy backward | `ShotResolver` |
| Snipex Alligator (sniper) | Much stronger, weapon-specific zoom | `BlasterController` |

Every one of these is implemented as a **new Tool attribute that defaults to off/unchanged for every existing weapon** — none of the 14 existing guns need to be touched, and each addition should be tested against an existing gun (e.g. Deagle or AK47) to confirm zero regression before moving on to the next.

Do Part 1 (shared code) completely before Part 3 (building the weapons) — Part 3 depends on all three attributes existing. Part 2 (inventory icons) is independent and can be done any time.

Source meshes (raw, unrigged — same unlabeled-`MeshPart`-bag situation as every previous batch, inspect visually before assembling):
- `Workspace.crowbar`
- `Workspace."Mossberg 590"`
- `Workspace."Snipex Alligator"`

(Unrelated, do not touch: `ServerStorage."Gun Pack"` also contains a "Snipex T-rex" — a different weapon not requested here.)

---

## Part 1 — Shared code additions

### 1a. Infinite ammo (`infiniteAmmo` attribute) — enables melee

**Why this is the right shape for melee:** the crowbar doesn't need a new fire mode. It's a `Semi`-fire hitscan weapon with a very short `range`, exactly like every other gun's Semi branch — the only thing that's actually different is it never runs out of ammo and never reloads. Reusing the existing `Semi` branch means the crowbar automatically gets the same swing-cooldown behavior (`rateOfFire`), the same `Shoot` remote round-trip, and — because it goes through the exact same `ShotResolver.applyDamage`/`ReplicateShot`/`impactEffect`/hitmarker pipeline as every gun — it automatically gets the same hit effect on an enemy that guns get, satisfying "reuse the same effect when it hits an enemy" for free with no new VFX code.

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
INFINITE_AMMO_ATTRIBUTE = "infiniteAmmo",
```

**`ReplicatedStorage.Blaster.Scripts.BlasterController`** — cache the flag in `equip()` alongside the existing ammo/reloading resync (around line 325), then gate every ammo-touching check on it:
```lua
-- in equip(), alongside the existing ammo/reloading resync:
self.infiniteAmmo = self.blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE) or false
```
```lua
function BlasterController:canShoot(): boolean
	return self:isHumanoidAlive() and self.equipped and (self.infiniteAmmo or self.ammo > 0) and not self.reloading
end

function BlasterController:canReload(): boolean
	if self.infiniteAmmo then
		return false
	end
	local magazineSize = self.blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)
	return self:isHumanoidAlive() and self.equipped and self.ammo < magazineSize and not self.reloading
end
```
In `shoot()`, only decrement/display ammo when it isn't infinite:
```lua
if not self.infiniteAmmo then
	self.ammo -= 1
	self.guiController:setAmmo(self.ammo)
end
```
In `startShooting()`, the very first early-return must not treat an infinite-ammo weapon as empty:
```lua
if not self.infiniteAmmo and self.ammo == 0 then
	self:reload()
	return
end
```

**`ReplicatedStorage.Blaster.Scripts.GuiController`** — the ammo counter (`updateAmmoText`/`setAmmo`) should show nothing for an infinite-ammo weapon rather than a stale or eventually-negative number (see the server-side note below). In `GuiController.new()`, read the same attribute and either hide the `Ammo` label frame entirely or short-circuit `updateAmmoText()` to blank when `blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE)` is true. Inspect the actual `BlasterGui.Blaster` frame tree first (it wasn't fully read for this prompt) before deciding whether to hide the frame or blank its text.

**`ServerScriptService.Blaster.Scripts.Blaster.validateShot`** — this is a **separate, server-side ammo check** the client-side changes above don't touch; without this fix the crowbar will stop working the moment its server-side `_ammo` attribute would hit 0. Currently (lines 48–52):
```lua
	-- Make sure the blaster has enough ammo
	local ammo = blaster:GetAttribute(Constants.AMMO_ATTRIBUTE)
	if ammo <= 0 then
		return false
	end
```
Change to:
```lua
	-- Make sure the blaster has enough ammo (skipped for infinite-ammo weapons, e.g. melee)
	if not blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE) then
		local ammo = blaster:GetAttribute(Constants.AMMO_ATTRIBUTE)
		if ammo <= 0 then
			return false
		end
	end
```

**`ServerScriptService.Blaster.Scripts.ShotResolver`** — for hygiene, skip the `_ammo` decrement (currently unconditional at lines 174–176) for infinite-ammo weapons too, so the attribute doesn't drift to a large negative number over a long session:
```lua
local infiniteAmmo = weapon:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE)
if not infiniteAmmo then
	local ammo = weapon:GetAttribute(Constants.AMMO_ATTRIBUTE)
	weapon:SetAttribute(Constants.AMMO_ATTRIBUTE, ammo - 1)
end
```

**Verify:** equip an existing gun (unaffected, attribute unset) and confirm ammo/reload behave exactly as before. This part is otherwise verified once the crowbar exists in Part 3.

### 1b. Knockback (`knockbackForce` attribute) — enables the shotgun

`ShotResolver` already applies a physics impulse on hit, but it **deliberately excludes character parts** (see the comment at the impulse block, lines 271–297) — a prior bug where the exact same impulse formula (`rayDirections[index] * force`, where `rayDirections` are pre-scaled by `range`) flung a ragdolled corpse at 584 studs/s. Do not reuse that formula or that code path for player/enemy knockback — build a separate, deliberately small, non-range-scaled addition.

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
KNOCKBACK_FORCE_ATTRIBUTE = "knockbackForce",
```

**`ServerScriptService.Blaster.Scripts.ShotResolver`** — read the attribute once near the other weapon-attribute reads (around line 172):
```lua
local knockbackForce = weapon:GetAttribute(Constants.KNOCKBACK_FORCE_ATTRIBUTE) or 0
```
Inside `applyDamage(taggedHumanoid, rayResult)` (lines 196–221), after `taggedHumanoid:TakeDamage(appliedDamage)`, add:
```lua
if knockbackForce > 0 then
	local rootPart = taggedHumanoid.RootPart
	if rootPart then
		local offset = rayResult.position - origin.Position
		local direction = offset.Magnitude > 1e-3 and offset.Unit or origin.LookVector
		rootPart.AssemblyLinearVelocity += direction * knockbackForce + Vector3.new(0, knockbackForce * 0.25, 0)
	end
end
```
Note this uses the **unit direction from shooter to the actual hit point** (not the range-pre-scaled `rayDirections[index]` the prop-impulse block uses), so `knockbackForce` is a clean, directly-tunable studs/s-ish push independent of the weapon's `range` — avoiding the exact bug class the existing comment warns about. The small upward bias (`* 0.25`) gives a "knocked off their feet" feel rather than a flat shove.

**Known interaction, not a bug to fix:** if this hit kills the target, `RagdollController`'s ragdoll transition zeroes velocity/angular velocity almost immediately after (documented in its own code as deliberate, to kill death-lunge momentum). That means knockback is only visually obvious on a **non-lethal** hit — a killing shotgun blast won't visibly fling the corpse. Leave this as-is; don't modify `RagdollController` to preserve momentum unless asked.

**Verify:** equip an existing gun (attribute unset → `knockbackForce = 0` → the `if` never runs, zero behavior change) and confirm nothing changed. Full verification happens with the shotgun in Part 3 — shoot a target player at close range and confirm they're pushed backward without being flung absurdly far.

### 1c. Per-weapon zoom (enables the sniper's scope)

Currently `applyZoom()`/`removeZoom()` in `BlasterController` use three **hardcoded, shared-by-every-weapon** module constants (lines 28–30: `ZOOMED_FOV = 50`, `CAMERA_OFFSET_ZOOMED = Vector3.new(0, 0, -2)`, `ZOOMED_SENSITIVITY_SCALE = 0.5`). Turn these into per-weapon attributes that fall back to the current constants as defaults, so every existing gun's ADS behaves identically unless a new attribute is explicitly set.

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
ZOOM_FOV_ATTRIBUTE = "zoomFov",
ZOOM_CAMERA_OFFSET_ATTRIBUTE = "zoomCameraOffset",
ZOOM_SENSITIVITY_ATTRIBUTE = "zoomSensitivity",
```

**`ReplicatedStorage.Blaster.Scripts.BlasterController`** — keep the existing module-level constants as fallback defaults, and change `applyZoom()` (lines 220–229) to:
```lua
function BlasterController:applyZoom()
	local fov = self.blaster:GetAttribute(Constants.ZOOM_FOV_ATTRIBUTE) or ZOOMED_FOV
	local cameraOffset = self.blaster:GetAttribute(Constants.ZOOM_CAMERA_OFFSET_ATTRIBUTE) or CAMERA_OFFSET_ZOOMED
	local sensitivity = self.blaster:GetAttribute(Constants.ZOOM_SENSITIVITY_ATTRIBUTE) or ZOOMED_SENSITIVITY_SCALE

	CameraAuthority.CameraOffset:Set("ADS", cameraOffset)
	CameraAuthority.FieldOfView:Set("ADS", fov)
	CameraAuthority.MouseDeltaSensitivity:Set("ADS", sensitivity)

	self.isZoomedIn = true
	self:startAimAssist()
end
```
`removeZoom()` needs no changes — it only clears the `"ADS"` source, which works the same regardless of what value was set.

**Verify:** equip an existing gun and right-click — zoom should look and feel identical to before (attributes unset → falls back to the same hardcoded constants). Full verification happens with the sniper in Part 3 — right-click should zoom noticeably tighter than a normal gun's ADS.

---

## Part 2 — Inventory: names instead of icons

Two separate UI surfaces currently show a weapon's `Tool.TextureId` as a picture icon:
1. Roblox's native Backpack/hotbar (bottom of screen, tool selection slots).
2. The in-combat ammo HUD (`ReplicatedStorage.Blaster.Scripts.GuiController`, `blasterGui.Blaster.IconLabel.Image = blaster.TextureId`).

**Backpack (surface 1):** Roblox's default Backpack GUI automatically falls back to displaying the Tool's `Name` as text when `TextureId` is empty — no custom code needed. Clear `TextureId` to `""` on every weapon Tool in `StarterPack` (all 17: Deagle, AK47, M1911, Mateba 2006M, AKM, HCAR, Kriss Vector, Scar L, AUG A-3, AMB-17, MP9, Sig MPX, M16A1, FN P-90, plus the 3 built in Part 3). This directly satisfies "I just want the names of the weapons."

**Ammo HUD (surface 2):** clearing `TextureId` will also blank `IconLabel`'s image as a side effect, leaving an empty gap. Since the goal is explicitly "so it's easy to check which gun is which," extend the same fix here rather than leaving a blank space: in `GuiController.new()`, replace the `IconLabel.Image = blaster.TextureId` line with hiding `IconLabel` and showing the weapon's name instead (e.g. `blaster.Name`) in a `TextLabel` in the same spot. Inspect the actual `BlasterGui.Blaster` frame tree first (its full structure wasn't read for this prompt — it contains at least `IconLabel` and an `Ammo` sub-frame with `MagazineLabel`/`AmmoLabel`) before deciding whether to add a new `TextLabel` or repurpose an existing one; set its text once at construction, since the weapon's name never changes for the lifetime of that GUI instance.

**Verify:** open the backpack — every weapon shows its name, no icons. Equip each and confirm the ammo HUD also shows the weapon's name where the icon used to be (except the crowbar, whose ammo HUD is hidden entirely per Part 1a).

---

## Part 3 — Build the 3 weapons

Same assembly procedure as every previous batch (clone the closest template Tool, assemble the world model + viewmodel from the raw source mesh, weld/verify orientation against the template's `Body.Rotation` convention before calling it done, set attributes, playtest, delete the consumed source model). Templates: Deagle (one-handed pistol rig) for the crowbar, AK47 (two-handed long-gun rig) for the shotgun and sniper.

### Crowbar (melee)
Template: **Deagle**. `damage` = 45, `fireMode` = `"Semi"`, `infiniteAmmo` = `true`, `magazineSize` = 1, `range` = 6 (melee reach), `raysPerShot` = 1, `rayRadius` = 1 (generous hit-forgiveness, chunkier than any gun's), `spread` = 0, `rateOfFire` = 90 (a swing roughly every 0.67s), `reloadTime` = 0 (never triggered), `recoilMin` = `Vector2.new(-3, -3)`, `recoilMax` = `Vector2.new(3, 3)` (a small snappy camera kick to sell the impact — recoil still fires unconditionally on every `shoot()` call), `unanchoredImpulseForce` = 3, `knockbackForce` = 15 (a small satisfying "bonk" push, distinct from the shotgun's much larger push), `viewModel` = `"Crowbar"`.

Keep a `MuzzleAttachment` present on the crowbar's `Body` (other code may assume it exists) but with its `ParticleEmitter`s disabled/rate 0 — a muzzle flash makes no sense for melee. Don't worry about the laser-beam tracer effect: at a 6-stud range it travels its full length in ~0.03s at the existing `LASER_BEAM_VISUAL_SPEED`, effectively invisible without any special-casing needed.

**Animation gap, flagged:** there's no swing animation asset in the project. Reuse Deagle's `Shoot` animation as a placeholder for the crowbar's `Shoot` slot (it'll look like a firing flinch rather than a genuine swing — acceptable placeholder, same spirit as the earlier placeholder-icon convention) and note to the user that a real swing animation should be authored later. The `Reload` animation slot is never played (infinite ammo skips the reload flow) — leave it as an inert copy of Deagle's for schema completeness.

### Mossberg 590 (shotgun — close range, high damage, knockback)
Template: **AK47**. `damage` = 15 (per pellet), `fireMode` = `"Semi"`, `magazineSize` = 8, `range` = 550 (short — this is a close-range weapon by design), `raysPerShot` = 8 (pellets), `rayRadius` = 0.5, `spread` = 9 (wide cone — damage naturally falls off with range as pellets miss more, no extra falloff code needed), `rateOfFire` = 55 (~1.1s pump cycle), `reloadTime` = 3.2 (slow tube-fed reload), `recoilMin` = `Vector2.new(-6, 25)`, `recoilMax` = `Vector2.new(10, 35)` (heaviest recoil of any gun), `unanchoredImpulseForce` = 6, `knockbackForce` = 55 (its signature trait — a full point-blank hit connecting all 8 pellets deals 120 damage, exceeding 100 HP, so it can one-shot at point-blank range while also shoving the target back), `viewModel` = `"Mossberg 590"`.

### Snipex Alligator (sniper — long range, scoped)
Template: **AK47**. `damage` = 100 (anti-materiel-tier — a body shot alone nearly kills, a headshot at ×2 is 200, deliberately overkill for theme), `fireMode` = `"Semi"`, `magazineSize` = 5, `range` = 3500 (far beyond any other weapon), `raysPerShot` = 1, `rayRadius` = 0.1 (thin, precise), `spread` = 0.2 (near pixel-perfect), `rateOfFire` = 35 (~1.7s bolt-cycle between shots), `reloadTime` = 3.5, `recoilMin` = `Vector2.new(-10, 32)`, `recoilMax` = `Vector2.new(18, 48)` (largest kick in the game), `unanchoredImpulseForce` = 8, `zoomFov` = 12 (vs. the generic ADS's 50 — a dramatically tighter scope), `zoomSensitivity` = 0.15 (vs. generic 0.5, so high zoom stays controllable), `zoomCameraOffset` = `Vector3.new(0, 0, -1)`, `viewModel` = `"Snipex Alligator"`.

### Step-by-step per weapon (same as previous batches)
1. Duplicate the matching template Tool (Deagle or AK47).
2. Rename, clear `TextureId` to `""` per Part 2, clear the world Model's mesh children.
3. Assemble the world Model from the raw source mesh (identify parts visually, name them, set `PrimaryPart`, weld with `WeldConstraint`).
4. Build the matching `ReplicatedStorage.Blaster.ViewModels.<name>` folder by cloning the template's, swapping gun geometry only.
5. Set every attribute from the tables above.
6. Parent into `StarterPack`.
7. Delete the consumed raw source model from `Workspace`.
8. Playtest each: crowbar (swing connects at close range, no ammo HUD, infinite swings, hit effect plays on an enemy), shotgun (point-blank one-shot potential, target visibly pushed back, spread thins damage at range), sniper (right-click zooms noticeably tighter than a normal gun, long-range hits register, 5-round mag, slow reload). Verify world-model orientation via `Body.Rotation` against the AK47/Deagle convention before calling each done.

## Verification checklist

- [ ] Part 1a: crowbar has infinite ammo and no ammo HUD; an existing gun's ammo/reload is unaffected.
- [ ] Part 1b: shotgun knocks players/enemies back on hit without flinging corpses; an existing gun's hits are unaffected (no knockback).
- [ ] Part 1c: sniper's right-click zoom is visibly tighter than a normal gun's ADS; an existing gun's ADS is unchanged.
- [ ] Part 2: Backpack shows names, not icons, for every weapon. Ammo HUD shows the weapon's name where the icon was (crowbar excepted, its HUD is hidden).
- [ ] Part 3: all 3 new Tools in `StarterPack`, correct fire behavior each, correct world-model orientation.
- [ ] No changes to any of the 14 existing weapons' own attributes.
- [ ] `ServerStorage."Gun Pack"` untouched.
