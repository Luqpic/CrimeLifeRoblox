# Change Log: Remove the Sniper (Snipex Alligator)

**Date:** 2026-09-11
**Status:** Applied

## Summary
Fully removed the sniper weapon added in the previous loadout pass, including reverting the per-weapon ADS zoom system that existed solely to support it, since no other weapon used it.

## Changes
- `StarterPack."Snipex Alligator"` and `ReplicatedStorage.Blaster.ViewModels."Snipex Alligator"` deleted, along with everything under them (sounds, animations, world model, viewmodel).
- `ReplicatedStorage.Blaster.Constants` / `BlasterController` — the per-weapon zoom attributes (`zoomFov`, `zoomCameraOffset`, `zoomSensitivity`) and the logic reading them were removed; ADS zoom reverted to the original shared hardcoded values for every weapon.

## Notes
- An unrelated pre-existing asset with a similar name (`Snipex T-rex`) was explicitly confirmed unrelated and left untouched.
