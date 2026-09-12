# Change Log: Weapon Renames, Burst-Fire Mode, Six New Weapons

**Date:** 2026-09-11
**Status:** Applied

## Summary
Renamed the two original placeholder-named starter weapons to their proper identities (stats/scripts/sounds untouched). Added a true burst-fire mode (fixed round count per trigger pull) alongside the existing semi-automatic and automatic modes, entirely client-side since the server already validates every shot independently. Added six more weapons to the loadout using the same content-integration process as the previous weapon batch.

## Changes
- Two starter weapons — renamed (Tool, viewmodel folder, and the attribute linking them); one fallback constant used for a default enemy weapon updated to match. A generic shared sub-model name and combat-system namespace were deliberately left untouched, since every weapon shares them.
- Weapon controller — added a burst-fire mode: fires a fixed number of rounds at the weapon's normal rate per trigger pull, then locks out, regardless of whether the trigger is held or released mid-burst.
- Six new weapons added (a bullpup rifle, a modern auto carbine, a high-rate machine pistol, a low-recoil SMG, a burst-fire rifle, and a large-magazine PDW), each built from an unlabeled raw source mesh, with full stat blocks and matching first-person viewmodels; all use the existing shared weapon systems, no new per-weapon scripts.

## Notes
- All six new weapons shipped with placeholder icon art pending real assets.
- Every new weapon's orientation was explicitly checked against the known-correct convention before being considered finished, given a prior batch had shipped weapons facing backwards.
