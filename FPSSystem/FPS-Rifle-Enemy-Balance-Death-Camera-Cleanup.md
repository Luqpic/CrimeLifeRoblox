# Change Log: Rifle Enemy Rebalance, Death Camera Fix, Old Template Cleanup

**Date:** 2026-09-11
**Status:** Applied

## Summary
Rebalanced the two rifle-carrying enemy types (Armed Police, Armed Criminal), which were near-unmissable at range and against movement — they now have a real chance to miss — and cut their per-hit damage by 60%. Removed two generic enemy templates that had been superseded by the current 6 enemy types. Fixed the camera staying stuck in first-person view after dying while a weapon was equipped or zoomed in.

## Changes
- `ReplicatedStorage.Enemy.AimConfig`, `.templateConfig` — added a per-enemy-type accuracy ceiling override (previously the same fixed ceiling applied to every enemy type regardless of its other accuracy settings).
- `ServerStorage.EnemyTemplates."Armed Police"`, `."Armed Criminal"` — accuracy and damage attributes retuned.
- `ServerStorage.EnemyTemplates.StandardEnemy`, `.HeavyEnemy` — removed.
- `ReplicatedStorage.Blaster.Scripts.BlasterController` — camera now resets on death the same way it already did on weapon unequip, fixing the stuck first-person view.

## Notes
- None.
