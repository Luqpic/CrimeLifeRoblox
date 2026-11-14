---
type: system
tags: [system, weapons, animation, viewmodel]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/*.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-*.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Viewmodel-Swing.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Baton-Viewmodel-Real-Mesh-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-AK47-Display-Fix-11-New-Guns-Integration.md"]
---

# Viewmodels and Weapon Animation

**Skills:** `roblox-characters-animation`, `roblox-game-systems` (load these for work here)

## What it does
The first-person arms-and-gun model for every weapon: equip, idle breathing, move / sprint bob, aim, recoil, reload and melee swings. Motion is procedural Motor6D animation in Luau, not published animation assets.

## Where it lives
- `ReplicatedStorage.Blaster.ViewModels.<Weapon>`: rig `Root -> Body -> {Magazine, RightArm, ChargingHandle}`, `LeftArm` under `Magazine` (magazine-fed) or `Body` (melee, shotguns); `AnimationController` + `Animator`, no Humanoid. Optional `Pump` (`PumpJoint`) and `Round` (`RoundJoint`, RPG) joints.
- `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` owns the cloned joints; `ViewModelController` drives it; `BlasterController` supplies aim and reload-cancel events.
- Tests: `ServerStorage.WeaponViewmodelMotionTests`, `ServerStorage.WeaponClassMotionTests` (not run automatically).
- Exported clips: `ServerStorage.ViewmodelKeyframeSequences` (49 sequences, not published); editing rigs `Workspace.ViewmodelAnimationRigs` (disposable).
- Repo: `CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/` (authoring copies, specs, `ExportKeyframeSequences.luau`, `baseline/` = the two original asset-driven controllers, `README.md`).

## How it works
- `profiles` maps each weapon to a mechanical kind (`rock`, `rifle`, `bullpup`, `top`, `pistol`, `revolver`, `shell`, `pump`, `melee`, `launcher`) plus two numbers; `showcase` entries (AK47, Glock 17, Mossberg 590) carry authored carry pose, `omega` and `kick`.
- Keyframe tracks (equip, reload, melee swings) interpolate linearly (`ease(t) = t`). Aim / sprint / move blends are frame-rate-independent exponentials and recoil is a critically damped spring; both deliberately not linear.
- Idle sway, bob, sprint lean and ADS offset are a pivot offset applied with `model:PivotTo`, not joint motion.
- Hand seating: `frameInBody` cancels each hand's off-plane drift per rig at `Motion.new` (worst gap 1.03 -> 0.25 studs).
- Melee viewmodel swing: wind-up / strike / settle composed into the pivot in `ViewModelController` (`MELEE_SWING_DURATION` 0.4 s, `MELEE_SWING_REACH` 0.7, `MELEE_SWING_WINDUP` 0.28; overhead `Shoot`, right-to-left `Shoot2`, left-to-right `Shoot3`). Contact lands on `swingDelay`.
- Pump weapons: `p.Pump` takes the left hand's 0.55-stud rack when the rig has a `Pump` joint. RPG `launcher` kind: the hand's track is the rocket's track during reload (0.00 stud gap).
- Melee reload is dead: `Motion:reload` returns early for `kind == "melee"`.
- 28 viewmodels shared only 11 `AnimationId`s across three generic kits (as of 2026-09-20), which is why motion is procedural.

## Extend it
- New weapon: add a `profiles` entry (missing one asserts and stops first person). Keep the donor skeleton whole and hidden; hang the new mesh off `Body`.
- Asset path: publish the `KeyframeSequence`s (needs a person: MCP cannot upload animations), paste ids into each viewmodel's `Animations`, restore the `baseline/` controllers. Author against the mechanical classes, not the 28 weapons.
- Mossberg 590 / Spas 12: split a fore-end mesh onto a `Pump` joint and it racks with no code change.

## Watch out
- Never replace a viewmodel's core part: the arms hang off it (both hands detached once). Add a mesh instead.
- Studio Edit-mode `require` serves a stale cached module; clone-require when measuring a module you just edited.
- The Animation Editor only loads from an `AnimSaves` ObjectValue under a rig in Workspace; re-running the exporter rebuilds the master folder only.
- Grip placement along the weapon still comes from generic idle clips; there are no grip attachments, only `MuzzleAttachment`.
- The repo copy of `WeaponViewmodelMotion.luau` has no RPG / launcher or 2026-09-24 gun profiles; Studio is newer.
- Sounds with inaccessible assets throw authorization errors in Studio.

## History
- 2026-09-25: RPG `launcher` reload, rocket on `RoundJoint`. [[FPS-RPG-Reload-Hand-Carries-Rocket]]
- 2026-09-24: `PumpJoint` racks fore-ends; pistol magazines move. [[FPS-New-Guns-Magazines-And-Pump-Forends]]
- 2026-09-24: profiles for eight new guns. [[FPS-Eight-New-Pistols-And-Shotguns]]
- 2026-09-21: Knife profile (Crowbar verbatim); viewmodel blade rolled 180°. [[FPS-Knife-Bleed-Melee]] / [[FPS-Melee-Shop-View-And-Bleed-Effect]]
- 2026-09-20: hands seated on the weapon plane. [[FPS-Viewmodel-Hands-Off-Weapon]]
- 2026-09-20: 49 linear KeyframeSequences exported (unpublished). [[FPS-Viewmodel-KeyframeSequence-Export]]
- 2026-09-20: keyframe easing smoothstep -> linear. [[FPS-Viewmodel-Animation-Linear-Easing]]
- 2026-09-20: procedural melee swing. [[FPS-Melee-Viewmodel-Swing]]
- 2026-09-16: Baton viewmodel gets its real mesh. [[FPS-Baton-Viewmodel-Real-Mesh-Fix]]
- 2026-09-16: donor-skeleton swap for eleven viewmodels. [[FPS-AK47-Display-Fix-11-New-Guns-Integration]]
- 2026-09-11: random shoot-animation variants. [[FPS-Melee-Combo-And-Shotgun-Reload-Refactor]]
- Undated: three-weapon preview and the 26-firearm extension recorded in `FPSSystem/ViewmodelAnimations/README.md`.

See [[Batch Log]].
