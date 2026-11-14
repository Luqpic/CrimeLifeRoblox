---
type: howto
tags: [howto, animation, viewmodel]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-Animation-Linear-Easing.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-Hands-Off-Weapon.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Reload-Hand-Carries-Rocket.md"]
---

# Add a Viewmodel Animation

Change or add a first-person motion (equip, carry, recoil, reload, swing). The viewmodels run on **procedural Motor6D motion** in code, not on published animation assets. Full method: [[Animation Pipeline]]. System: [[Viewmodels and Weapon Animation]].

Skills: `roblox-characters-animation`.

## Steps
1. **Edit the motion module**, `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` (authoring copy `FPSSystem/ViewmodelAnimations/WeaponViewmodelMotion.luau`). It owns the cloned viewmodel joints; `ViewModelController` drives it and `BlasterController` supplies aim and reload-cancel events.
   - Per weapon: its `profiles` row (mechanical class plus two tuning numbers).
   - A hand-authored look: a `showcase` entry (AK47, Glock 17, Mossberg 590 are the approved ones; others inherit their family's).
   - Reload tracks and melee swing poses live in the same module. Keep gameplay timings: reload length comes from the Tool's `reloadTime`, melee contact from `swingDelay`.
   - Easing goes through the one `ease(t)` hook (linear since 2026-09-20). Aim, sprint and move blends and the recoil spring are deliberately not keyframes; leave them.
   - Pivot-level sway (idle breathing, walk bob, sprint lean, ADS offset) is returned by `Motion:step` and applied by `ViewModelController` with `PivotTo`; it is not joint motion.
2. **A new moving piece** (pump, carried round) needs a joint first: the build script adds a `Body -> Pump` or `Body -> Round` Motor6D ([[Add a Gun]]).
3. **Mirror** the module into `FPSSystem/ViewmodelAnimations/`. A local file change alone does not update Studio.
4. **Regenerate the KeyframeSequences** if the rest pose or a track changed: run `FPSSystem/ViewmodelAnimations/ExportKeyframeSequences.luau`. It rebuilds `ServerStorage.ViewmodelKeyframeSequences`; then refresh the copies in each staged rig's `AnimSaves` under `workspace.ViewmodelAnimationRigs`.

## Files to touch
`WeaponViewmodelMotion` (Studio and mirror); rarely `ViewModelController` / `BlasterController`.

## Check
- Run the specs in Play: `WeaponViewmodelMotion.spec.luau` (`ServerStorage.WeaponViewmodelMotionTests`, 7,102 assertions), `WeaponClassMotion.spec.luau` (`ServerStorage.WeaponClassMotionTests`), `ScopeAlignment.spec.luau`, `MeleeStability.spec.luau`. See [[Unit Test Runner]].
- Sample the joint at even slices before and after (the easing change measured Body `C0.Z` at eight slices of `equipTime`).
- Hand-to-weapon distance on all rigs (target: none over 0.30 studs).
- **Clone-require the module in Edit tooling**: Studio's Edit-mode cache serves the stale copy, and the measurement looks unchanged.
- A person still has to look at it in first person; numbers are not an artistic review.

## Rollback
`FPSSystem/ViewmodelAnimations/baseline/` holds the original `BlasterController` and `ViewModelController`; restoring both returns to asset-driven playback.

## Done before
[[FPS-Melee-Viewmodel-Swing]], [[FPS-Viewmodel-Animation-Linear-Easing]], [[FPS-Viewmodel-KeyframeSequence-Export]], [[FPS-Viewmodel-Hands-Off-Weapon]], [[FPS-New-Guns-Magazines-And-Pump-Forends]], [[FPS-RPG-Reload-Hand-Carries-Rocket]].
