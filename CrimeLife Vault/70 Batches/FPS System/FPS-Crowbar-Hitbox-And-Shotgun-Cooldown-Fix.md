# Change Log: Crowbar Hit Reliability, Shotgun Fire-Rate Increase

**Date:** 2026-09-11
**Status:** Applied

## Summary
Fixed a report that the crowbar "needs a certain angle" to land a hit — it was using the same single precision-ray detection guns use, appropriate for aiming but unforgiving for a melee swing. Widened melee hit detection into a multi-ray cone, with damage capped so a swing can't deal more than its configured amount no matter how many rays connect. Also sped up the shotgun's follow-up shot timing.

## Changes
- Melee weapons — swing detection widened from a single ray to a forgiving multi-ray cone; damage no longer stacks per connecting ray (a solid hit still deals the crowbar's full configured damage, a glancing hit deals proportionally less, never more than intended). Guns and the shotgun are unaffected, since this only applies to weapons flagged as melee.
- Melee on-hit sound/VFX — capped to at most once per target per swing, preventing several stacked pops/sounds when multiple rays connect on the same swing; the cosmetic tracer effect still draws per ray.
- Shotgun — pump-cycle delay shortened and fire-rate stat raised, cutting the total delay between shots by roughly 40%.

## Notes
- Only weapons flagged melee or shotgun are affected by these two changes respectively; every other weapon's timing and damage behavior is unchanged.
