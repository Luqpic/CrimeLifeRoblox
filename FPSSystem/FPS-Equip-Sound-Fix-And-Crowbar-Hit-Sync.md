# Change Log: Equip Sound Fix and Crowbar Hit Sync

**Date:** 2026-09-11
**Status:** Applied

## Summary
Fixed several weapons (mainly rifles and the shotgun) not playing an equip sound at all — the old system depended on an animation-authored marker that some weapons' animations simply lacked. Made equip (and melee swing) sounds play explicitly instead, so this class of bug can't silently recur for future weapons. Assigned new sound assets to the rifle family, shotgun, and crowbar. Fixed the crowbar's damage/hit registering instantly on click instead of when the swing animation visually connects.

## Changes
- `ReplicatedStorage.Blaster.Scripts.ViewModelController` — equip sound (and, for melee weapons, swing sound) now plays explicitly rather than depending on an animation marker.
- 12 rifle/shotgun/crowbar weapons — new equip sound assets assigned.
- `ReplicatedStorage.Blaster.Constants`, `ReplicatedStorage.Blaster.Scripts.BlasterController` — added a per-weapon swing-delay attribute so melee damage resolves at the moment of visual contact instead of instantly on click; guns are unaffected, since the delay is zero for them.

## Notes
- The swing-delay mechanism added here only covered the player's own weapon handling. Enemies using melee weapons didn't get the same fix until a later change.
