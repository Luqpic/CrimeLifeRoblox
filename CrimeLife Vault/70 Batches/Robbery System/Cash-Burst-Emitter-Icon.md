# Change Log: Robbable Objects Burst the Real Cash Icon

**Date:** 2026-09-19
**Status:** Applied (confirmed by the project owner)

## Summary
Robbing a register, ATM or safe threw a burst of the old placeholder cash decal rather than the
design library's cash icon.

## Cause
There are **two independent cash bursts** in this place, and only one had been updated:

- The **screen-space** one (`SharedSystems.CashClaimVFX`) fires on a claim and flies coins into the
  cash HUD. It was moved onto the Figma coin earlier.
- The **world-space** one (`SharedSystems.RobbableObject:_playCashBurst`) fires at the object you
  just robbed, from a `ParticleEmitter` **pre-placed on each object's attach part**. Those emitters
  were never touched, so all of them still pointed at `rbxassetid://18885492705` -- the placeholder
  decal that predates the redesign.

This is the same stale-duplicate hazard that has bitten this project before: a visual updated in the
module while pre-placed copies in the world keep the old asset. Anything authored per-object rather
than built by code needs its own sweep.

## Changes
- All 19 remaining `CashBurstEmitter` textures swapped to `UITheme.Assets.Coin`
  (`rbxassetid://134682502484497`) -- Bank, SlowFoods, Gas2Go and NewsStation registers, ATMs and
  safes. One emitter was already correct from the earlier pass.
- Their `Color` set to white, so the slice keeps its own accent rather than being tinted; the old
  decal had relied on a tint.

## Notes
- The texture is read from `UITheme`, so this stays in step with a future re-upload of the slice set.
