# Change Log: Death Screen, Tweened Leveling Bar, Level-Up Shine VFX

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added a death screen: the background blurs, a random taunting phrase fades in, then a black-screen transition covers the moment of respawn before fading back out. Also polished the leveling system — the XP bar now animates smoothly instead of snapping, and leveling up triggers a one-shot particle "shine" burst on the character, visible to everyone.

## Changes
- `ReplicatedStorage.GuiTemplates.DeathScreen`, `.LevelUpShine` (new templates).
- `StarterPlayer.StarterPlayerScripts.DeathScreen` (new) — plays the death sequence for the local player's own death only.
- `StarterPlayer.StarterPlayerScripts.LevelingHud` — XP bar fill now animates via tween instead of snapping instantly.
- `StarterPlayer.StarterPlayerScripts.LevelUpVFX` (new) — attaches one dormant particle emitter per character at spawn time, fired with a single burst on level-up rather than creating/destroying an effect per event.

## Notes
- This was the first version of the death screen. It had a stuck-overlay bug that needed two follow-up fixes (see later changelog entries dated the same day and the next).
