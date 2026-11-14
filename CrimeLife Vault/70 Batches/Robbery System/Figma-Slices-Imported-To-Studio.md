# Change Log: Figma Slices Imported Into Studio

**Date:** 2026-09-18
**Status:** Applied (confirmed live)

## Summary
Replaced the runtime-drawn Robbery System UI with pre-rendered artwork exported from Figma, so the shipped game uses the real design rather than an approximation of it. 23 slices were exported, uploaded and wired up. The deciding constraint was typography: the design system uses Archivo Black and Barlow Semi Condensed, and neither exists in Roblox's font catalogue — `Font.fromName` fails silently and falls back to the engine default. Baking the type into the artwork is the only way to ship the real faces.

## Changes
- New `ReplicatedStorage.SharedSystems.UITheme` — pins every asset id, its 1x display size, and the body offset for panels whose ribbon overhangs the frame.
- `StarterPlayer.StarterPlayerScripts.HeistClient` — the HUD (timer, duffel, toast, safe keypad, drop button) now draws exported chrome with only live values layered on top.
- `ReplicatedStorage.SharedSystems.CashClaimVFX` — cash widget rebuilt on the adopted slice.
- `StarterPlayer.StarterPlayerScripts.WordScrambleClient` — letter tiles built natively rather than baked.
- The six `StarterGui` dialogs and the four world StatusBillboards re-skinned in place, keeping every node name so existing script references still resolve.

## Notes
- The word-scramble letter tiles were deliberately NOT baked. `MasterComputer`'s word list runs 5 to 9 letters, so a fixed tile row in the image breaks on anything longer than five.
- Static text is baked; dynamic values stay native. A countdown, a filling bar and typed digits cannot be pixels.
- Roblox caps uploaded textures at 1024px, so export scales were chosen per slice to stay under it rather than letting Roblox silently downscale.
