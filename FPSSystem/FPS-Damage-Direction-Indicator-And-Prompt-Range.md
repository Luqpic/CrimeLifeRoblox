# Change Log: Damage Directional Indicator, Weapon Prompt Range Fix

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added a directional on-screen indicator that points toward whatever just damaged the player (AI enemy or another player), and fixed a range mismatch where a weapon pickup's interaction prompt activated at a shorter distance than its stat billboard became visible, leaving a dead zone where stats were visible but the weapon couldn't yet be taken.

## Changes
- `ServerScriptService.Blaster.Scripts.DamageDirectionService` (new) + `ReplicatedStorage.Blaster.Remotes.DamageDirection` (new RemoteEvent) — relays the attacker's position to the victim's client on every hit, reusing the existing hit-resolution event rather than adding a second "you got hurt" signal.
- `StarterPlayer.StarterPlayerScripts.DamageDirectionIndicator` (new) — renders a fading directional arrow using bearing math relative to camera facing; supports multiple simultaneous hits from different directions.
- All 16 weapon pickups — `ProximityPrompt.MaxActivationDistance` raised from `10` to `20` to match the stat billboard's visibility range. Cash drop pickups were intentionally left at their own separate range.

## Notes
- None.
