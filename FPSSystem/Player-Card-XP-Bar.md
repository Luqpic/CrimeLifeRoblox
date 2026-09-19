# Change Log: Player Card XP Bar Alignment and Colour

**Date:** 2026-09-19
**Status:** Applied

## Summary
The XP bar in the player card sat half outside its own track, and used the accent green rather than
reading as an XP bar.

## Cause
The fill's `AnchorPoint` is `(0, 0.5)` -- anchored at its vertical CENTRE -- while its `Position` Y
was `0`. That puts the fill's centre on the track's TOP edge, so half the bar hangs above the track.

## Changes
- `GuiTemplates.PlayerCard.StatsContainer.LevelRow.Track.Fill` -- position moved to
  `UDim2.fromScale(0, 0.5)` so the centre sits on the track's centre, and colour changed from the
  accent green to light blue `RGB(120, 200, 255)`.

## Notes
- The health bar in the same container was checked for the same mismatch and is correct: it anchors
  at `(0, 0)` with position `(0, 0)`, which is self-consistent. Left alone.
- Only the template changed; `PlayerCardController` still drives the width with
  `Size = UDim2.fromScale(fraction, 1)`.
