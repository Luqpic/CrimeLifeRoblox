# Change Log: Billboard Scale-Up and Tiered Cash Drops

**Date:** 2026-09-11
**Status:** Applied

## Summary
Scaled up the weapon stat billboard by 25% for legibility, and replaced the flat +50 Cash-per-kill reward with a 30% chance for a killed enemy to drop a physical, pickupable cash object instead. The drop's value depends on the dying enemy's weapon class (melee, pistol, or auto-rifle).

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponStatBillboard` — billboard panel size increased ~1.25x.
- `ServerStorage.Cash` — relocated from Workspace into ServerStorage as a proper clone-source template; given a `PrimaryPart` and a `WeldConstraint` so it falls and settles as one piece instead of coming apart.
- `ServerScriptService.Weapons.Scripts.CashService` (new) — removed the old flat per-kill Cash grant; added tiered cash drops (30% chance per kill, value scaled by enemy weapon tier), a pickup prompt, a despawn timer, and a shared shrink/fade animation for both collection and despawn.

## Notes
- Drop chance and tier values were placeholders meant to be tuned by playtesting, not final balance.
