# Change Log: Melee, Shotgun, and Sniper Weapon Types

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added three weapons that each needed a small, opt-in addition to the shared weapon system, rather than being pure content like previous batches: a melee weapon (Crowbar) with no ammo, a shotgun (Mossberg 590) that knocks targets back, and a sniper (Snipex Alligator) with its own tighter scope zoom. Also switched weapon selection UI (backpack and ammo HUD) from icons to plain names, since real per-weapon icon art doesn't exist.

## Changes
- `ReplicatedStorage.Blaster.Constants` / `BlasterController` / server-side shot validation — added an `infiniteAmmo` attribute so a weapon can skip ammo tracking and reloading entirely; defaults to off for every existing weapon.
- `ShotResolver` — added a `knockbackForce` attribute that pushes a hit target back, using a direction/magnitude scheme deliberately separate from the existing (and already-known-buggy-at-large-values) prop-impulse code, so it can't repeat that bug.
- `BlasterController` — ADS zoom (FOV, camera offset, sensitivity) is now overridable per-weapon via attributes, falling back to the previous shared hardcoded values for every weapon that doesn't set them.
- `StarterPack` / viewmodels — three new weapons built on top of the above: Crowbar (melee, infinite ammo), Mossberg 590 (shotgun, knockback + pellet spread), Snipex Alligator (sniper, tight zoom, very high damage/range).
- Backpack and ammo HUD — weapon `TextureId` cleared across all weapons so the default Roblox backpack shows names instead of icons; ammo HUD's icon slot replaced with the weapon's name for the same reason.

## Notes
- The Crowbar shipped with a placeholder swing animation (borrowed from an existing pistol's fire animation) since no real swing asset existed at the time — flagged for later replacement.
- A killing knockback hit doesn't visibly fling the corpse, because the ragdoll system zeroes velocity on death by design — left as-is, not treated as a bug.
