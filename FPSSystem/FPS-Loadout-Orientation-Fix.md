# Change Log: Backwards Weapon Orientation Fix

**Date:** 2026-09-11
**Status:** Applied

## Summary
Fixed three weapons (AKM, Scar L, Kriss Vector) rendering backwards in third-person view — muzzle pointing toward the character instead of away — caused by their weapon-body model being rotated 180° relative to the other, correctly-oriented weapons.

## Changes
- `StarterPack.AKM.Blaster`, `StarterPack."Scar L".Blaster`, `StarterPack."Kriss Vector".Blaster` — rotated 180° as a single rigid unit, preserving their internally-welded parts.

## Notes
- The Tool's grip was already correct and shared with every other weapon, so it was left untouched. First-person viewmodels were checked and confirmed unaffected — the bug was specific to the third-person world model.
