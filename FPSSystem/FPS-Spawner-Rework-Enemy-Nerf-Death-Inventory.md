# Change Log: Spawner Directory Rework, Enemy Damage/Accuracy/Recoil Nerf, Inventory Lock on Death

**Date:** 2026-09-11
**Status:** Applied

## Summary
Three unrelated changes bundled together: enemy spawn points were renamed and switched from an Attribute to a StringValue for easier discoverability in Studio; all six enemy types had their damage cut further (to 20% of their weapon's stock damage) and the four ranged types got reduced accuracy plus a new recoil mechanic that didn't previously exist for AI; and the custom inventory/hotbar was locked while the player is dead, closing a gap where a player could still switch weapons after dying.

## Changes
- 6 enemy spawn points in `Workspace` — renamed to match their enemy type (e.g. `PoliceSpawner`), each given an `EnemyType` StringValue child replacing the old Attribute.
- `ServerScriptService.Enemy.Scripts.EnemySpawner` — reads the spawn point's enemy type from the new StringValue instead of the old Attribute.
- `ServerStorage.EnemyTemplates.*` (all 6 templates) — `DamageOverride` attributes lowered to 20% of each template's actual weapon damage.
- `ServerStorage.EnemyTemplates.Police` / `Criminal` — given accuracy-error overrides for the first time (previously only the "Armed" variants had any).
- `ServerStorage.EnemyTemplates."Armed Police"` / `"Armed Criminal"` — accuracy-error overrides raised further (wider miss cone than the previous pass).
- `ReplicatedStorage.Enemy.Constants` — added recoil-decay tuning constants for the new enemy recoil mechanic.
- `ServerScriptService.Enemy.Scripts.EnemyAI` — added a recoil accumulate/decay mechanic for ranged enemies, reusing each weapon's existing recoil attributes so it stays consistent with player recoil for the same gun; automatic weapons visibly climb during a sustained burst, semi-auto weapons barely show it.
- `StarterPlayer.StarterPlayerScripts.InventoryDeathLock` — new script disabling the native/custom inventory entirely while the player's character is dead, regardless of whether a weapon was equipped at the moment of death, re-enabling it on respawn.

## Notes
- The recoil mechanic for enemies is new — players already had camera-based recoil, but AI had nothing equivalent until this pass since AI recomputes its aim fresh each shot rather than drifting a camera.
