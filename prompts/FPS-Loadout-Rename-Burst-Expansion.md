# Prompt: Rename Starter Weapons, Add Burst-Fire, Expand Loadout with 6 More Weapons

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained. Do the three parts in order — Part 3 (M16A1) depends on Part 2 (burst-fire) existing.

---

## Part 1 — Rename `Blaster` → `Deagle`, `AutoBlaster` → `AK47`

These are pure identity renames of the two starter weapons. Their stats, scripts, sounds, and animations are untouched.

### What to rename
For **each** of the two weapons:
1. `StarterPack.Blaster` (Tool) → rename to `StarterPack.Deagle`
2. `ReplicatedStorage.Blaster.ViewModels.Blaster` (Model) → rename to `ReplicatedStorage.Blaster.ViewModels.Deagle`
3. On the Tool, set the `viewModel` attribute from `"Blaster"` to `"Deagle"` (must match the ViewModels folder child name exactly, or the weapon will fail to find its first-person model)

Repeat identically for `AutoBlaster` → `AK47` (Tool: `StarterPack.AutoBlaster` → `StarterPack.AK47`; ViewModel: `ReplicatedStorage.Blaster.ViewModels.AutoBlaster` → `ReplicatedStorage.Blaster.ViewModels.AK47`; `viewModel` attribute → `"AK47"`).

### What NOT to rename (important — do not touch these)
- **The inner gun-body Model inside every Tool and every ViewModel is always named `"Blaster"` regardless of the weapon's own name** — this is a generic convention across the whole loadout (e.g. `StarterPack.AKM.Blaster`, `StarterPack.HCAR.Blaster` already both exist and are correctly named this way). Do not rename `StarterPack.Deagle.Blaster` or `ReplicatedStorage.Blaster.ViewModels.Deagle.Blaster` — leave those as `"Blaster"`.
- The `ReplicatedStorage.Blaster` folder itself (the whole combat system's namespace: `Scripts`, `Remotes`, `Constants`, `ViewModels`, `Effects`, `Utility`) is unrelated to the pistol weapon's name — never rename this.
- `CameraAuthority`/`ViewModelController` use the literal string `"Blaster"` as a `PropertyAuthority` **source key** (e.g. `CameraAuthority.MouseBehavior:Set("Blaster", ...)` in `ReplicatedStorage.Modules.CameraAuthority` and `ReplicatedStorage.Blaster.Scripts.ViewModelController`) to mean "the weapon system in general," not any specific Tool. Leave every one of these untouched.

### The one real hardcoded dependency — must update
`ReplicatedStorage.Enemy.Constants.ENEMY_WEAPON_NAME = "Blaster"` is a fallback: `ServerScriptService.Enemy.Scripts.EnemySpawner`'s `prepareWeapon()` does `game.StarterPack:FindFirstChild(Constants.ENEMY_WEAPON_NAME)` when a spawned enemy template has no Tool of its own already equipped. Once `StarterPack.Blaster` no longer exists, this lookup will fail and warn (`EnemySpawner: ... has no Tool and no "Blaster" in StarterPack`). Update this constant to `"Deagle"` (or whichever starter weapon you want enemies to fall back to — `Deagle` is the direct rename target, so use that unless you have a reason to prefer `AK47`).

### Verify
- Re-run a grep for the literal string `"Blaster"` across all scripts after the rename. The only hits remaining should be the `CameraAuthority`/`ViewModelController` source-key usages listed above — nothing else.
- Play-test: equip Deagle and AK47, confirm both fire/reload/show HUD correctly (this exercises the renamed `viewModel` attribute lookup).
- Confirm `ReplicatedStorage.Enemy.Constants.ENEMY_WEAPON_NAME` reads `"Deagle"`. (You may not be able to easily force-trigger the fallback path live if every `EnemyTemplates` entry already carries its own Tool — confirming the constant value is sufficient if so.)

---

## Part 2 — Add a real `Burst` fire mode (shared code change)

Currently `ReplicatedStorage.Blaster.Constants.FIRE_MODE` only has `SEMI` and `AUTO`, and `ReplicatedStorage.Blaster.Scripts.BlasterController:startShooting()` only branches on those two. Burst is new client-side behavior — fire exactly 3 rounds per trigger pull, then lock out until the next press — needed for the M16A1 in Part 3. The server does not need to change: it treats every `Shoot:FireServer` call as an independent, self-validated event regardless of the client's fire mode, so this is entirely a `BlasterController` change.

### `ReplicatedStorage.Blaster.Constants`
Add to the `FIRE_MODE` table and add one new top-level constant:
```lua
FIRE_MODE = {
	SEMI = "Semi",
	AUTO = "Auto",
	BURST = "Burst",
},
...
BURST_ROUND_COUNT = 3,
```

### `ReplicatedStorage.Blaster.Scripts.BlasterController`
In `startShooting()` (currently lines 153–194), add a third branch alongside the existing `SEMI`/`AUTO` ones — do not modify those two at all:

```lua
elseif fireMode == Constants.FIRE_MODE.BURST then
	task.spawn(function()
		self.shooting = true
		for _ = 1, Constants.BURST_ROUND_COUNT do
			if not self:canShoot() then
				break
			end
			self:shoot()
			task.wait(60 / rateOfFire)
		end
		self.shooting = false

		if self.ammo == 0 then
			self:reload()
		end
	end)
end
```

This mirrors the existing `AUTO` branch's `task.spawn` shape but with a bounded loop instead of `while self.activated do`, so releasing the mouse mid-burst doesn't matter — it always completes its 3 rounds (or stops early only if ammo runs out or the humanoid dies mid-burst, via the existing `canShoot()` check). The existing `if self.shooting then return end` guard at the top of `startShooting()` already prevents re-triggering mid-burst with no further changes needed. `rateOfFire` becomes the intra-burst cyclic rate (the weapon's own `rateOfFire` attribute), matching how real burst weapons fire at their normal cyclic rate for exactly 3 rounds rather than a separately-tuned "burst speed."

### Verify
- Equip M16A1 (once built in Part 3) and confirm exactly 3 rounds fire per click, ammo drops by 3, and clicking again mid-burst does nothing until the burst finishes.
- Re-test one `Semi` weapon (e.g. Deagle) and one `Auto` weapon (e.g. AK47) afterward to confirm this change didn't regress them — it shouldn't, since their branches are untouched, but confirm anyway.

---

## Part 3 — Add 6 more weapons

Same content-only integration pattern used for the previous batch (AKM/HCAR/Kriss Vector/Scar L/M1911/Mateba 2006M) — read `StarterPack.AK47` and `StarterPack.Deagle` (post-rename) to confirm current structure before starting, since this document doesn't assume you have that prior context loaded.

### Weapons in scope

| New weapon | Template | Source mesh (raw, unrigged) | fireMode |
|---|---|---|---|
| AUG A-3 | AK47 (was AutoBlaster) | `Workspace."AUG A-3"` (7 MeshParts) | Auto |
| AMB-17 | AK47 | `Workspace."AMB-17"` (6 MeshParts) | Auto |
| MP9 | AK47 | `Workspace.MP9` (5 MeshParts) | Auto |
| Sig MPX | AK47 | `Workspace."Sig MPX"` (5 MeshParts) | Auto |
| M16A1 | AK47 | `Workspace.M16A1` (8 MeshParts) | **Burst** (Part 2) |
| FN P-90 | AK47 | `Workspace."Guns to add"."FN P-90"` (6 MeshParts) | Auto |

Note the first 5 source meshes are sitting loose directly under `Workspace` (not inside `Workspace."Guns to add"` like the previous batch and like FN P-90 this time) — use the exact paths above, no need to relocate them first unless you want to for tidiness.

**Out of scope / do not touch:** `ServerStorage."Gun Pack"` (contains Zastava M17, Glock 17, HK417 — pre-existing meshes unrelated to this task, not mentioned by the user), Enemy AI weapon assignment beyond the Part 1 fallback-name update, any GUI art beyond the placeholder icon convention below.

### Architecture recap (self-contained — same system as before)

- Every weapon is a `Tool` whose stats live as **Instance Attributes** (`damage`, `fireMode`, `magazineSize`, `range`, `rateOfFire`, `reloadTime`, `raysPerShot`, `rayRadius`, `spread`, `recoilMin`/`recoilMax` as `Vector2`, `unanchoredImpulseForce`, `viewModel`) — attribute name strings are defined in `ReplicatedStorage.Blaster.Constants`, read them from there rather than retyping the literals.
- One shared client controller (`BlasterController`) and one shared server handler (`Blaster` + `ShotResolver`) drive every weapon — you are not writing per-weapon scripts, just cloning the template's thin bootstrap `LocalScript`.
- Remotes (`Shoot`, `Reload`, `ReplicateShot`) are shared — do not create new ones.
- GUI icon = `Tool.TextureId` directly (`GuiController.lua` reads `blaster.TextureId`). Use `rbxassetid://17744925782` (AK47's icon) as the placeholder for all 6 — every one of them uses the AK47 template.
- Viewmodel = clone `ReplicatedStorage.Blaster.ViewModels.AK47` wholesale into a new folder named after the weapon's `viewModel` attribute value, then swap only the gun-mesh geometry (`Body`/`Trim*`/`Magazine`/`ChargingHandle` inside the inner `Blaster` sub-model), keeping every joint name (`Root`, `LeftArm`/`RightArm` + their Motor6Ds, the `Body`→`Root` `BodyJoint` Motor6D), `Animations` (`Idle`/`Shoot`/`Reload`/`Equip`), `AnimationController`, and `AnimSaves` untouched, so the existing animations/CameraRecoiler/BlasterController work with zero code changes.
- World model = clone `StarterPack.AK47.Blaster` the same way, weld the new gun's parts to a `Body` primary part exactly like the template, positioned via the Tool's `Grip` CFrame (which is shared/identical across every weapon — do not modify `Grip` on any of these).
- Each `Tool` also needs its own `Handle`, `Sounds` folder (clone AK47's), and `Animations` folder (clone AK47's) — reuse the same sound/animation assets unless told otherwise.

### Known risk (same as last time, plus a lesson learned)

The raw source meshes are unlabeled — every model is a flat bag of `MeshPart`s all literally named `"MeshPart"`, no `Body`/`Trim`/`Magazine` labels, no `PrimaryPart`, no welds. Before assembling each gun: visually identify which mesh is the body vs. magazine vs. furniture (use `screen_capture`/`inspect_instance`), rename parts to match the template's scheme, set `PrimaryPart`, weld with `WeldConstraint`.

**Orientation lesson from the previous batch:** three of the last six guns (AKM, Scar L, Kriss Vector) were assembled with `Body` rotated 180° off on the local Y axis, making the gun point backwards in third person. After assembling each of these 6 weapons, explicitly compare the new gun's `StarterPack.<Gun>.Blaster.Body.Rotation` against `StarterPack.AK47.Blaster.Body.Rotation` (should read `(90, 0, 180)`) before considering it done — if it doesn't match that convention, the muzzle is very likely pointing the wrong way. Confirm with a third-person `screen_capture` regardless of what the numbers say.

### Stats

Real-world-informed, balanced against the existing loadout's ~165–195 sustained-DPS band for auto weapons (`damage × rateOfFire / 60`). Set every attribute listed — don't leave any blank. `_ammo` = `magazineSize`, `_reloading` = `false` on creation, matching every other weapon.

#### AUG A-3 (Steyr AUG A3 — bullpup 5.56, prized for accuracy and low recoil)
- `damage` = 15, `fireMode` = `"Auto"`, `magazineSize` = 30, `range` = 1500, `rateOfFire` = 700, `reloadTime` = 2.0, `raysPerShot` = 1, `rayRadius` = 0.4, `spread` = 1.8 (most accurate weapon in the loadout — its signature trait), `recoilMin` = `Vector2.new(-2, 7)`, `recoilMax` = `Vector2.new(2, 11)` (lowest recoil among the rifles), `unanchoredImpulseForce` = 3, `viewModel` = `"AUG A-3"`

#### AMB-17 (no confirmed real-world match — treated as a generic modern auto carbine; adjust if you had a specific gun in mind)
- `damage` = 14, `fireMode` = `"Auto"`, `magazineSize` = 30, `range` = 1300, `rateOfFire` = 750, `reloadTime` = 2.0, `raysPerShot` = 1, `rayRadius` = 0.4, `spread` = 2.3, `recoilMin` = `Vector2.new(-3, 8)`, `recoilMax` = `Vector2.new(3, 12)`, `unanchoredImpulseForce` = 3, `viewModel` = `"AMB-17"`

#### MP9 (B&T MP9 — machine pistol, real-world signature trait is an extremely high ~1200 RPM cyclic rate)
- `damage` = 9, `fireMode` = `"Auto"`, `magazineSize` = 30, `range` = 850, `rateOfFire` = 1200 (highest in the loadout), `reloadTime` = 1.4, `raysPerShot` = 1, `rayRadius` = 0.4, `spread` = 4 (bloom kept high on purpose so the very high RPM doesn't turn it into a long-range laser), `recoilMin` = `Vector2.new(-2, 3)`, `recoilMax` = `Vector2.new(2, 6)`, `unanchoredImpulseForce` = 2, `viewModel` = `"MP9"`

#### Sig MPX (SIG MPX — AR-pattern gas-piston 9mm PDW, celebrated for near-zero muzzle climb)
- `damage` = 11, `fireMode` = `"Auto"`, `magazineSize` = 30, `range` = 950, `rateOfFire` = 900, `reloadTime` = 1.6, `raysPerShot` = 1, `rayRadius` = 0.4, `spread` = 2.5, `recoilMin` = `Vector2.new(-1, 3)`, `recoilMax` = `Vector2.new(1, 6)` (lowest recoil of any weapon in the game — its defining trait), `unanchoredImpulseForce` = 2, `viewModel` = `"Sig MPX"`

#### M16A1 (Burst Gun) (real M16A1 was historically Semi/Auto, not burst — burst is a deliberate design choice here per your request; requires Part 2)
- `damage` = 17, `fireMode` = `"Burst"`, `magazineSize` = 30, `range` = 1600, `rateOfFire` = 900 (intra-burst cyclic rate), `reloadTime` = 2.0, `raysPerShot` = 1, `rayRadius` = 0.4, `spread` = 1.5 (most accurate weapon in the loadout, rewarding disciplined burst fire), `recoilMin` = `Vector2.new(-2, 8)`, `recoilMax` = `Vector2.new(2, 13)`, `unanchoredImpulseForce` = 3, `viewModel` = `"M16A1"`

#### FN P-90 (PDW, huge top-mounted 50-round mag, very high rate of fire)
- `damage` = 12, `fireMode` = `"Auto"`, `magazineSize` = 50, `range` = 1000, `rateOfFire` = 850, `reloadTime` = 2.4, `raysPerShot` = 1, `rayRadius` = 0.4, `spread` = 2.8, `recoilMin` = `Vector2.new(-2, 5)`, `recoilMax` = `Vector2.new(2, 9)`, `unanchoredImpulseForce` = 2, `viewModel` = `"FN P90"`

### Step-by-step per weapon

1. Duplicate `StarterPack.AK47` — carries over `Scripts`, `Sounds`, `Animations`, `Handle`, world Model structure.
2. Rename to the weapon name. Set `Tool.TextureId` to `rbxassetid://17744925782` (placeholder, flag as TODO for real art). Clear the world Model's mesh children.
3. Assemble the world Model from the weapon's raw source mesh per the "Known risk" section; weld to `PrimaryPart`; position via `Grip`.
4. Build `ReplicatedStorage.Blaster.ViewModels.<viewModel value>` by cloning `ReplicatedStorage.Blaster.ViewModels.AK47` and swapping gun geometry only.
5. Set every stat Attribute from the table above.
6. Parent the finished Tool into `StarterPack`.
7. Delete the consumed raw model from `Workspace` (or `Workspace."Guns to add"` for P-90) once its parts are moved into the Tool + ViewModel.
8. Playtest: equip, fire (confirm fire mode matches the table — Burst for M16A1, Auto for the rest), confirm hitmarker/damage/ammo HUD, reload, and check the world-model orientation per the lesson-learned note above via third-person `screen_capture`.

### Verification checklist

- [ ] Part 1: `StarterPack.Deagle` and `StarterPack.AK47` exist, `StarterPack.Blaster`/`StarterPack.AutoBlaster` do not. Both fire/reload/HUD correctly. `ReplicatedStorage.Enemy.Constants.ENEMY_WEAPON_NAME` = `"Deagle"`. A grep for `"Blaster"` shows only the `CameraAuthority`/`ViewModelController` source-key hits.
- [ ] Part 2: Burst fires exactly 3 rounds per click and locks until the burst completes. Semi and Auto weapons re-tested and unaffected.
- [ ] Part 3: All 6 new Tools present in `StarterPack` with every attribute set, a working ViewModel folder, and correct world-model orientation (`Body.Rotation` = `(90, 0, 180)`) confirmed via screenshot.
- [ ] No new remotes, no new server scripts.
- [ ] `Workspace."AUG A-3"`, `Workspace."AMB-17"`, `Workspace.MP9`, `Workspace."Sig MPX"`, `Workspace.M16A1`, and `Workspace."Guns to add"."FN P-90"` are gone (consumed) — or explicitly noted if left for reference.
- [ ] `ServerStorage."Gun Pack"` untouched.
