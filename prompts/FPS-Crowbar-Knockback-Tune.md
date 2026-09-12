# Change Log: Crowbar Knockback Tune

**Date:** 2026-09-11
**Status:** Applied

## Summary
The crowbar's knockback wasn't actually missing a feature — it already used the same generic knockback system every weapon (including the shotgun) uses. The configured value was just too low relative to how it gets divided across the melee swing's multiple hit-rays, so it read as no knockback at all.

## Changes
- `ServerStorage.Weapons.Crowbar` — `knockbackForce` attribute raised from `15` to `90`.

## Notes
- No code was changed, only a balance value. This reused the existing mechanism rather than adding a parallel one.
