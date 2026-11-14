# Change Log: Notification, HUD Stacking, Lockpick and Title Fixes

**Date:** 2026-09-18
**Status:** Applied (confirmed live)

## Summary
Seven reported UI defects, two of which had non-obvious causes. The notification card's text overlapped its own accent edge because a nine-sliced image draws its border regions at native pixel size — the slice is a 2x export, so a 60px border rendered at 60 Roblox pixels instead of 30 and pushed the baked edge under the text. Separately, the lockpick's "wrong click plays no error sound" turned out not to be an audio fault at all.

## Changes
- `NotificationGui` — slice scale corrected, and `NotificationClient` now measures its own body text instead of choosing between two hardcoded heights.
- `HeistClient` — HUD slots derived from the element above rather than hardcoded, fixing the timer/duffel/toast overlaps.
- Lockpick success-zone arcs rebuilt at the server's exact widths and selected by nearest match.
- New furniture-free breach panel for the word-scramble completion screen.
- Safe keypad digit boxes normalised so all four read identically.
- All six ribbon titles centred within their plates.

## Notes
- The lockpick sound was always firing. The real fault was that the drawn arc did not match the hit test: the selector's thresholds sat below every real zone width, so the widest arc was always drawn, and it was narrower than the true level-one zone. Clicking outside the visible arc still scored a hit, so the success cue played instead of the error one. The drawn arc now equals the hit test.
- The breach screen needed its own artwork because the puzzle's boxes and buttons are baked into the panel; hiding the puzzle container only removed the live text.
