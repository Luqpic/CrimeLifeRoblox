# Change Log: Six Enemy Types with Dedicated Debug Spawners

**Date:** 2026-09-11
**Status:** Applied

## Summary
Replaced the generic `StandardEnemy`/`HeavyEnemy` pair with six distinct enemy types split across two factions (law enforcement and criminal), each with its own weapon and a dedicated spawn point so each type could be tested in isolation. Also fixed a melee engagement-range bug and a damage-flattening bug that would have made the new types indistinguishable from each other in practice.

## Changes
- `ServerScriptService.Enemy.Scripts.EnemySpawner` — spawn points can now be tagged with an `EnemyType` attribute that pins them to one named template; untagged points keep the old "any template" behavior. Raised `MAX_CONCURRENT_ENEMIES` from 4 to 10.
- `ServerStorage.EnemyTemplates` — added six templates (`Security`, `Police`, `Armed Police`, `Thug`, `Criminal`, `Armed Criminal`), each a clone of the existing rig with its own weapon and tuned health/speed/detection stats. Each got an explicit `DamageOverride` (the shared config otherwise force-lowers every enemy's damage to a debug value of 3, which would have made every weapon feel identical) and, for the two melee types, an `EngageRangeFraction` override (the shared default effectively never lets a short-range melee weapon register as "in range").
- New `Baton` weapon (Security's weapon) — built by cloning the Crowbar's entire mechanism and swapping only the mesh and sounds, so it behaves identically to the Crowbar under the hood.
- Real swing animations applied to the Crowbar (both player and enemy copies), replacing an earlier placeholder animation.
- Six existing world spawn points tagged with their assigned `EnemyType`.

## Notes
- Retiring `StandardEnemy`/`HeavyEnemy` was a deliberate side effect of tagging all six spawn points — they stop spawning unless a fresh untagged point is added.
