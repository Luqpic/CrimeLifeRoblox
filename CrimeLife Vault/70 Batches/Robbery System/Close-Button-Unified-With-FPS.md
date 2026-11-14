# Change Log: Close Buttons Unified With FPS System

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Summary
This place's four X buttons were already uniform -- 36x36 `ImageButton`s on the Figma slice, all bound through `UI.Effects`. The FPS place was the one that had drifted, so most of the work happened there. What changed here is that the close button's definition moved out of this file and into the shared module, so neither place can drift again.

## Changes
- `ReplicatedStorage.UI.Effects` -- gained `CLOSE_IMAGE`, `CLOSE_SIZE` and `bindClose()`, and its header now states that the file is kept byte-identical across both places.
- `UiButtonEffects` -- the four X buttons (supplier, duffel upgrade, lockpick, word scramble) now call `bindClose` instead of naming the `"bounce"` style themselves.

## Notes
- `HackCodeGui.DialogFrame.CloseButton` is named like an X but is the 320x48 "GOT IT" confirm button. It stays on `rotate`, which is the correct motion for a wide button.
- A `replace_all` edit reported success without changing two of the four call sites. Caught by a follow-up audit; worth knowing that tool can silently under-apply.
- Verified live: hover grew the X 36 to 39.6 with a hover sound, and it returned to rest on leave.
