---
type: rule
tags: [rule, building, blender, assets, viewmodels]
updated: 2026-11-14
sources: ["CLAUDE.md (Systems: Weapons / blaster)", "CrimeLifeRoblox/FPSSystem/Blaster/BuildNewPistolsShotguns.luau", "70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "OBT Vault/10 Rules/Building Rules.md (generic parts)"]
---

# Building Rules

## Rule

- **Edit-time builds are re-runnable scripts.** ViewModels and new guns are built by a build script that can run again (for example `CrimeLifeRoblox/FPSSystem/Blaster/BuildNewPistolsShotguns.luau`). It **copies raw meshes rather than consuming them**, so the sources stay usable.
- **Donor-skeleton swap: add a mesh to the core part, never replace it.** The core part is the rig hub: the arm Motor6Ds, the tool weld, `MuzzleAttachment` and the trail hang off it. Swap the mesh, keep the part ([[FPS-Knife-Bleed-Melee]]).
- **Every gun carries a `MuzzleAttachment`** in both its world model and its viewmodel; melee carries an empty one. Without it the weapon setup stops before wiring equip, fire and reload ([[FPS-New-Guns-Missing-MuzzleAttachment-Fix]]).
- **Anchor only a rig's root part.** Anchoring a Motor6D-driven part freezes it ([[FPS-Viewmodel-KeyframeSequence-Export]]).
- **Keep the source models** a build script reads. When sources are deleted the build script must skip those weapons and say so, as it now does for the eight pistols and shotguns ([[FPS-RPG-Gamepass-Launcher]]).
- **Blender work** (meshes for weapons and props): load `roblox-blender-modelling` ([[Roblox Skills]], [[Blender Pipeline]]). Never fuse touching parts with a boolean union; keep each part a closed solid; check with backface culling (carried from OBT).
- **Never pose a template rig in Edit** to test an animation: pose a throwaway clone (carried from OBT).

## Why

- `CLAUDE.md`: "ViewModels are built by a re-runnable build script that copies raw meshes rather than consuming them, using a donor-skeleton swap (add a mesh to the core part, never replace it)."
- [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]]: ten new guns lacked the marker and were held as ordinary objects.

## How to apply

- Recipes: [[How-To MOC]]. Animation: [[Animation Pipeline]]. Weapons: [[Weapons and Blaster]], [[Viewmodels and Weapon Animation]].
- Verify a build by reading the result (joint names, part sizes, attachment presence on every weapon), not by the script's exit ([[Verify in Edit and by Screenshot]]).
