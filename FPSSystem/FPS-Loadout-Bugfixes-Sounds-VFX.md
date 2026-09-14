# Change Log: Sniper Fire-Rate Fix, Orientation Audit, Shotgun/Crowbar Sound and VFX

**Date:** 2026-09-11
**Status:** Applied

## Summary
Investigated a report that the sniper "stops responding" after firing — the cause was an unusually long cooldown with no feedback during it, not a bug; the cooldown was shortened, still deliberately the slowest weapon in the loadout. Re-checked two SMGs reported as facing backwards again and found both already correctly oriented — no change made. Wired up the shotgun's full sound set (equip, shot, pump, magazine in/out). Replaced the crowbar's inherited gun-style muzzle flash and gunshot sound with a proper equip/hit sound and a lightweight melee impact effect.

## Changes
- Sniper weapon — fire-rate stat raised so its cooldown drops from ~1.7s to ~1.2s between shots.
- Two SMG weapons — re-verified against the correct orientation reference; confirmed already correct, nothing changed.
- Shotgun — equip, shot, pump-cycle, and magazine in/out sounds assigned (some slots share one asset as a placeholder).
- Crowbar — added its own equip and on-hit sounds; removed inherited muzzle-flash particles from both the world model and viewmodel; added a small on-hit impact effect via the shared hit-effect system.
- Shared animation/effects code — made defensive about a weapon not having muzzle-flash emitters, ahead of removing the crowbar's.

## Notes
- No "shot denied" feedback during the sniper's cooldown yet — flagged as a possible follow-up, not addressed here.
- The shotgun's pump/magazine sounds and the crowbar's impact sound reuse a single provided asset across multiple cues as placeholders.
