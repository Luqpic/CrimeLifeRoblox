# Change Log: Shared UI Effects, Camera FOV/Blur and Button Sounds

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Summary
Ported the FPS System's UI feel into Robbery System — hover/press animation, click and hover sounds, and the camera FOV-pull plus background blur when a panel opens. The modules were ported verbatim with the same names and the same folder layout as the FPS place, because the two projects are intended to be merged later and a divergent second implementation would have to be reconciled by hand at that point.

## Changes
- New shared modules under `ReplicatedStorage`, matching the FPS layout exactly: `UI.Sounds`, `UI.Effects`, `Modules.PropertyAuthority`, `Modules.CameraAuthority`, `Modules.MenuFovBlur`.
- New `StarterPlayer.StarterPlayerScripts.UiButtonEffects` — binds hover/press styles and sounds to every button, and drives focus mode.
- Focus mode: opening a puzzle panel now hides the rest of the HUD so the puzzle is the only thing on screen.
- Duffel `+` button given a darker-tint hover.
- Removed the duplicated "Got it" button — the panel artwork already contains one.

## Notes
- `MenuFovBlur` is reference counted. Two panels open at once and one closing must not cancel the other's blur, so it hands back a one-shot release rather than exposing a global off switch.
- The duplicate "Got it" was not a layout mistake. Five panels in `StarterGui` still held pre-refresh artwork that had the button baked in, while the live panel added its own. Beyond fixing the stored copies, the client now re-asserts the correct artwork at runtime and warns if it had to, so a stale saved place surfaces the problem instead of shipping it.
- Hover state could strand itself: focus mode disables the HUD mid-hover, and a disabled ScreenGui never fires MouseLeave, so the button stayed lit when it came back. Effects now reset to rest whenever a button is hidden.
