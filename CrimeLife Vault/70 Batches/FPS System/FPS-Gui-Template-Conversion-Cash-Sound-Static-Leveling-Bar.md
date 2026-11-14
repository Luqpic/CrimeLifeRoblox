# Change Log: GUI Template Conversion, Cash Pickup Sound, Static Leveling Bar

**Date:** 2026-09-11
**Status:** Applied

## Summary
Converted four HUD elements that were built entirely in code (stamina bar, leveling bar, weapon stat panel, damage-direction arrow) into cloned, hand-editable templates, so their look can be tweaked directly in Studio going forward instead of requiring a script change. Bundled in two small fixes while touching the same area: cash pickups had no sound at all, and the leveling bar faded in and out instead of staying visible.

## Changes
- `ReplicatedStorage.GuiTemplates` (new folder) holding five pre-built UI templates.
- `StarterPlayer.StarterPlayerScripts.StaminaHud`, `.LevelingHud`, `.WeaponStatBillboard`, `.DamageDirectionIndicator` — all rebuilt to clone their visuals from templates instead of constructing them in code.
- Leveling bar is now always visible instead of fading in/out, and repositioned just above the hotbar.
- `ServerScriptService.Weapons.Scripts.CashService` — cash pickups now play a sound on collection.

## Notes
- None.
