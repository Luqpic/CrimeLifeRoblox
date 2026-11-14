# Prompt: Expand FPS Loadout with 6 New Weapons

Paste this whole document to Claude Code (with Roblox Studio MCP access) as the task prompt. It is self-contained — it does not assume you have prior conversation context about this codebase.

## Goal

Integrate 6 new weapons into the existing Blaster combat system, following the exact same architecture as the two weapons already in `StarterPack` (`Blaster` and `AutoBlaster`). By the end, each new weapon must be a fully working `Tool` in `StarterPack` that a player can equip, aim, fire (with correct semi/auto behavior), reload, and see hit-validated damage from, indistinguishable in behavior from the existing two weapons — only its model, viewmodel, and stats differ.

**Do not** design a new system. This is pure content integration into the system that already exists. Read the referenced scripts before writing anything, to confirm current behavior hasn't drifted from this brief.

## Weapons in scope (this pass)

| New weapon | Template to clone | Source mesh (raw, unrigged) |
|---|---|---|
| M1911 | `Blaster` (pistol) | `Workspace."Guns to add".M1911` (5 MeshParts) |
| Mateba 2006M | `Blaster` (pistol) | `Workspace."Guns to add"."Mateba 2006m"` |
| AKM | `AutoBlaster` (auto rifle) | `Workspace."Guns to add".AKM` (7 MeshParts) |
| HCAR | `AutoBlaster` (auto rifle) | `Workspace."Guns to add".HCAR` |
| Kriss Vector | `AutoBlaster` (auto SMG) | `Workspace."Guns to add"."Kriss Vector"` |
| Scar L | `AutoBlaster` (auto rifle) | `Workspace."Guns to add"."Scar L"` |

**Out of scope / do not touch:** FN P-90 (no source mesh exists in Studio yet — skip entirely, do not stub it into StarterPack), Enemy AI weapon assignment (`ServerScriptService.Enemy.*`), any GUI art beyond the placeholder icon described below, ammo pickups/economy (none exists today — don't invent one).

## Architecture you must follow (read the real files to confirm before editing)

This game's weapon system is fully data-driven — a "new gun" is 95% content, 0% new code:

- Every weapon is a `Tool` whose **stats live as Instance Attributes**, not code: `damage`, `fireMode` (`"Semi"`|`"Auto"`), `magazineSize`, `range`, `rateOfFire` (RPM), `reloadTime` (seconds), `raysPerShot`, `rayRadius`, `spread`, `recoilMin`/`recoilMax` (`Vector2`), `unanchoredImpulseForce`, `viewModel` (string, must match a folder name under `ReplicatedStorage.Blaster.ViewModels`). The exact attribute name strings are defined in `ReplicatedStorage.Blaster.Constants` — use that module's constants, don't hardcode the strings, when writing any script; when setting attributes directly via Studio/MCP calls you still need the literal name, just read it from `Constants` first to confirm it hasn't changed.
- **One shared client controller (`ReplicatedStorage.Blaster.Scripts.BlasterController`) and one shared server handler (`ServerScriptService.Blaster.Scripts.Blaster` + `ShotResolver`) drive every weapon.** You are NOT writing per-weapon scripts. Each `Tool`'s own `Scripts` folder contains a single thin `LocalScript` (see `StarterPack.Blaster.Scripts.Blaster`) that just bootstraps `BlasterController` for that tool — copy this verbatim.
- **Remotes are shared, not per-weapon**: `ReplicatedStorage.Blaster.Remotes.{Shoot, Reload}` and `ReplicatedStorage.Blaster.Remotes.ReplicateShot` already handle every weapon. You do not create new remotes.
- **GUI icon comes straight from `Tool.TextureId`** (`ReplicatedStorage.Blaster.Scripts.GuiController.lua:26` — `blasterGui.Blaster.IconLabel.Image = blaster.TextureId`). There is no separate per-weapon icon asset to wire up.
- **Viewmodel structure is a Model under `ReplicatedStorage.Blaster.ViewModels.<viewModel attribute value>`**, containing (minimum, matching `ReplicatedStorage.Blaster.ViewModels.Blaster` / `.AutoBlaster`):
  - `Root` (Part) with a `BodyJoint` (Motor6D)
  - `LeftArm`, `RightArm` (Parts) with their own Motor6D joints (`LeftArmJoint`, `RightArmJoint`) — present on the `AutoBlaster` viewmodel; confirm whether the `Blaster` (pistol) viewmodel needs the same before assuming
  - `Animations` folder containing `Idle`, `Shoot`, `Reload`, `Equip` (`Animation` instances)
  - `AnimationController` containing an `Animator`
  - `AnimSaves` (`ObjectValue`)
  - A gun body Model (mirroring `Blaster.Blaster` / `AutoBlaster.Blaster`: `Body` MeshPart as root with `TrimA`/`TrimB`/etc. and `Magazine` MeshParts welded to it via `WeldConstraint`, plus a `MuzzleAttachment` on `Body` with its particle emitters, plus `ChargingHandle` for the auto-weapon template)
  - **The safest approach: clone the matching template's entire ViewModel folder, then swap only the gun-mesh geometry (MeshId/Size/CFrame of Body/Trim*/Magazine) for the new gun's parts, keeping every joint name, attachment, animation, and the AnimationController untouched.** This is what lets the existing Idle/Shoot/Reload/Equip animations, `CameraRecoiler`, and `BlasterController` work on the new weapon with zero code changes.
- The **world model** (third-person, seen by other players / dropped view) mirrors the same pattern one level up: `StarterPack.<Tool>.<Tool>` Model with `Body` (PrimaryPart) + `Trim*` + `Magazine`, welded together, positioned by the Tool's `Grip` CFrame. Clone `StarterPack.Blaster.Blaster` or `StarterPack.AutoBlaster.Blaster` the same way as the viewmodel.
- Each `Tool` also needs its own `Handle` (Part, `RequiresHandle = true`), `Sounds` folder (`Shoot` subfolder + `Equip`, `MagIn`, `MagOut` Sounds — clone from the matching template, reuse the same sound assets unless told otherwise), and `Animations` folder (`Idle`, `Shoot`, `Reload` — for the third-person `CharacterAnimationController`, separate from the viewmodel's own Animations folder).

## Known risk: the raw source meshes are unlabeled

Every model under `Workspace."Guns to add"` is just a flat bag of `MeshPart`s all literally named `"MeshPart"` — no `Body`/`Trim`/`Magazine` labels, no `PrimaryPart`, no welds, no rig. Before assembling each gun:

1. Select the model in Studio (or use `screen_capture`/`inspect_instance` on each child) to visually identify which mesh is the main body, which is the magazine, which are furniture (sights, rails, stock, charging handle, etc.).
2. Rename each part to match the template's naming scheme (`Body`, `TrimA`, `TrimB`, ..., `Magazine`, `ChargingHandle` if applicable) so the structure is self-documenting and matches convention.
3. Set `PrimaryPart` to the main body part, weld everything else to it with `WeldConstraint`, matching how `StarterPack.Blaster.Blaster` and `StarterPack.AutoBlaster.Blaster` are built.
4. Positioning/scale of the gun relative to the viewmodel arms (`Constants.VIEW_MODEL_OFFSET`, `Grip` CFrame on the world Tool) will need hand-tuning per gun since these are different real-world sizes — use Play mode + `screen_capture` to visually check the first-person view looks reasonable (grip roughly at the hands, muzzle pointing forward) before considering a weapon done.

If a gun's mesh count/shape doesn't cleanly map onto the template's part count (e.g. AKM/HCAR/Kriss Vector/Scar L have 7 raw MeshParts vs. the AutoBlaster template's fewer named parts), it's fine to keep extra parts as additional `TrimD`/`TrimE`/etc., matching how `ReplicatedStorage.Blaster.ViewModels.AutoBlaster.Blaster` already has `TrimA`–`TrimE`.

## Stats

Design values below (damage/RPM/mag/reload/range/spread/recoil/impulse), balanced against the existing `Blaster` (pistol baseline: 35 dmg, 600 RPM semi, 10 mag) and `AutoBlaster` (auto baseline: 10 dmg, 600 RPM auto, 30 mag) so each new gun has a distinct identity while staying in a comparable sustained-DPS band (~170–250 dps for the autos, semi-auto pistols left click-speed-limited). Treat these as a reasonable starting balance, not gospel — adjust freely if playtesting says otherwise, but set *something* for every attribute; don't leave any blank.

Set every value as an **Attribute** on the Tool (same attribute names as `Blaster`/`AutoBlaster` use — verify against `Constants` before typing them).

### M1911 (template: Blaster / Semi)
- `damage` = 38
- `fireMode` = `"Semi"`
- `magazineSize` = 7
- `range` = 900
- `rateOfFire` = 400
- `reloadTime` = 1.3
- `raysPerShot` = 1
- `rayRadius` = 0.4
- `spread` = 2.2
- `recoilMin` = `Vector2.new(0, 18)`
- `recoilMax` = `Vector2.new(6, 24)`
- `unanchoredImpulseForce` = 6
- `viewModel` = `"M1911"`

### Mateba 2006M (template: Blaster / Semi — revolver, hits hard, slow, low capacity)
- `damage` = 60
- `fireMode` = `"Semi"`
- `magazineSize` = 6
- `range` = 900
- `rateOfFire` = 220
- `reloadTime` = 2.2
- `raysPerShot` = 1
- `rayRadius` = 0.4
- `spread` = 3
- `recoilMin` = `Vector2.new(2, 26)`
- `recoilMax` = `Vector2.new(10, 34)`
- `unanchoredImpulseForce` = 9
- `viewModel` = `"Mateba 2006M"`

### AKM (template: AutoBlaster / Auto — hard-hitting, punchy recoil)
- `damage` = 18
- `fireMode` = `"Auto"`
- `magazineSize` = 30
- `range` = 1400
- `rateOfFire` = 600
- `reloadTime` = 2.3
- `raysPerShot` = 1
- `rayRadius` = 0.4
- `spread` = 3
- `recoilMin` = `Vector2.new(-4, 10)`
- `recoilMax` = `Vector2.new(4, 16)`
- `unanchoredImpulseForce` = 3
- `viewModel` = `"AKM"`

### HCAR (template: AutoBlaster / Auto — DMR-ish, big mag, long range, heavier per-shot kick)
- `damage` = 24
- `fireMode` = `"Auto"`
- `magazineSize` = 50
- `range` = 1800
- `rateOfFire` = 480
- `reloadTime` = 3.2
- `raysPerShot` = 1
- `rayRadius` = 0.4
- `spread` = 2.5
- `recoilMin` = `Vector2.new(-3, 12)`
- `recoilMax` = `Vector2.new(5, 18)`
- `unanchoredImpulseForce` = 4
- `viewModel` = `"HCAR"`

### Kriss Vector (template: AutoBlaster / Auto — very fast cyclic rate, very low recoil, short range)
- `damage` = 13
- `fireMode` = `"Auto"`
- `magazineSize` = 25
- `range` = 900
- `rateOfFire` = 900
- `reloadTime` = 1.6
- `raysPerShot` = 1
- `rayRadius` = 0.4
- `spread` = 3.5
- `recoilMin` = `Vector2.new(-2, 4)`
- `recoilMax` = `Vector2.new(2, 8)`
- `unanchoredImpulseForce` = 2
- `viewModel` = `"Kriss Vector"`

### Scar L (template: AutoBlaster / Auto — controllable, accurate, mid-high range)
- `damage` = 16
- `fireMode` = `"Auto"`
- `magazineSize` = 30
- `range` = 1500
- `rateOfFire` = 650
- `reloadTime` = 2.1
- `raysPerShot` = 1
- `rayRadius` = 0.4
- `spread` = 2
- `recoilMin` = `Vector2.new(-3, 9)`
- `recoilMax` = `Vector2.new(3, 14)`
- `unanchoredImpulseForce` = 3
- `viewModel` = `"Scar L"`

### FN P-90 — prepared, not implemented this pass
No source mesh exists in Studio. Do not create a Tool for it. For when the mesh is added later (template: AutoBlaster / Auto — PDW, huge top-mounted mag, very high rate of fire): `damage` 12, `fireMode` "Auto", `magazineSize` 50, `range` 1000, `rateOfFire` 850, `reloadTime` 2.4, `raysPerShot` 1, `rayRadius` 0.4, `spread` 2.8, `recoilMin` `Vector2.new(-2, 5)`, `recoilMax` `Vector2.new(2, 9)`, `unanchoredImpulseForce` 2, `viewModel` `"FN P90"`.

## Placeholder icon

`Tool.TextureId` is the only image that needs a value (see architecture note above — `GuiController` reads it directly). Set it to a known-valid placeholder rather than leaving it blank:
- Pistols (M1911, Mateba 2006M) → reuse `Blaster`'s icon: `rbxassetid://17744927818`
- Auto weapons (AKM, HCAR, Kriss Vector, Scar L) → reuse `AutoBlaster`'s icon: `rbxassetid://17744925782`

This is a deliberate placeholder — flag it back to the user as a TODO to replace with real per-weapon icons later; don't spend time generating unique icon art now.

## Step-by-step per weapon

1. Duplicate the matching template `Tool` (`StarterPack.Blaster` or `StarterPack.AutoBlaster`) — this carries over the `Scripts` LocalScript, `Sounds`, `Animations`, `Handle`, and world Model structure for free.
2. Rename it to the weapon name (see table). Update `Tool.TextureId` (placeholder above) and clear/reset the world Model's mesh children.
3. Assemble the world Model (`<Tool>.<Tool>`) from the weapon's raw source meshes per the "Known risk" section above; weld to a `PrimaryPart`; position via `Grip`/`WorldPivot` so it sits naturally in a held hand, referencing the template's `Grip` CFrame as a starting point.
4. Build `ReplicatedStorage.Blaster.ViewModels.<viewModel value>` by cloning the matching template's ViewModel folder and swapping gun geometry only, per the architecture section above.
5. Set every stat Attribute from the table above (and `_ammo` = `magazineSize`, `_reloading` = `false`, matching how the existing tools initialize).
6. Parent the finished Tool into `StarterPack`.
7. Delete the consumed raw model from `Workspace."Guns to add"` once its parts have been moved/copied into the Tool + ViewModel (don't leave a stray duplicate copy sitting in Workspace).
8. Playtest: equip, fire (confirm semi vs. auto behavior matches `fireMode`), confirm hitmarker/damage/ammo HUD work, reload, switch weapons, and check the first-person viewmodel doesn't clip badly through the camera or float away from the hands. Use `screen_capture` to visually confirm the first-person pose before calling a weapon done.

## Verification checklist before reporting done

- [ ] All 6 Tools present in `StarterPack`, each with a `Handle`, world Model, `Scripts`, `Sounds`, `Animations`.
- [ ] All 6 have every attribute from `ReplicatedStorage.Blaster.Constants`' attribute list set to a real value (no attribute left unset/inherited-default).
- [ ] All 6 have a working `ReplicatedStorage.Blaster.ViewModels.<name>` folder with intact joint names/animations copied from the correct template.
- [ ] Fired shots register hits/damage/hitmarker through the existing `Shoot`/`ReplicateShot` remotes — no new remotes, no new server scripts were created.
- [ ] Reload works and respects `magazineSize`/`reloadTime`.
- [ ] `Workspace."Guns to add"` no longer contains the 6 consumed source models (or, if you chose to leave them for reference, say so explicitly rather than silently leaving duplicates).
- [ ] FN P-90 was left untouched (no Tool created).
- [ ] Nothing in `ServerScriptService.Enemy.*` was modified.
