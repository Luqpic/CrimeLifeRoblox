# Change Log: Prompt Progress Becomes a Liquid Fill, With Entrance and Exit

**Date:** 2026-09-19
**Status:** Applied (confirmed live in both places)

## The ring is gone

Holding now fills the plate itself from the bottom, like liquid rising, instead of drawing a ring
around it.

This is also the third and simplest attempt at the progress indicator, and the cheapest by a wide
margin:

| attempt | how | outcome |
|---|---|---|
| clipped half-discs | two rotated half-rings behind `ClipsDescendants` | broken -- Roblox does not clip a ROTATED descendant, so it sat half-lit at rest |
| 48 segments | one rotated bar per 7.5 degrees, lit in order | worked, but 48 instances per prompt to draw a circle |
| liquid fill | one unrotated frame inside one clip | **8 instances for the whole prompt** |

Nothing in the fill is rotated, so ordinary clipping applies and a `UICorner` on the clip makes the
liquid take the plate's rounded shape rather than sitting in it as a square block. The fill is
inset 2px so it stops short of the plate's own border.

- `UI.PromptUI` -- ring, segments and both ring slices removed; `Assets` is down to the plate.
- The liquid is the accent colour held back to 0.55 transparency, so the full-strength accent letter
  still reads over it. Composited over the plate that lands near RGB(101,120,41).

## Entrance and exit

The prompt now animates in and out instead of appearing and vanishing.

- `Root` is a **CanvasGroup**. Fading a prompt otherwise means driving `BackgroundTransparency`,
  `ImageTransparency` and `TextTransparency` across every element; `GroupTransparency` does all of it
  with one property, so the whole fade is a single tween.
- Entrance: transparency 1 -> 0 with a 0.82 -> 1 scale pop, Back easing, 0.16s.
- Exit: 0 -> 1 with a slight shrink, 0.10s, **then** destroy -- a prompt leaving range animates away
  rather than popping out.
- `PromptUiController` drops the handle from its live table before starting the fade, so a re-show
  mid-fade builds a fresh one instead of adopting a handle already on its way out.

## Measured
- 8 instances per prompt (the ring alone was 48 segments).
- Fill rises linearly: 0 / 9.8 / 19.7 / 29.5 / 39.4 px at progress 0 / .25 / .5 / .75 / 1.
- Against a real 2 second hold: 0% -> 13 -> 30 -> 47 -> 63 -> 79 -> 96 -> 100% over about 1.8s, then
  the exit fade takes over.
- `show()` leaves GroupTransparency 0 / scale 1; `hide()` was caught mid-fade at 0.45 and destroyed
  on completion.

## Notes
- Progress is assigned straight rather than tweened. The controller already feeds it a fresh value
  every frame from the hold's elapsed time, so a tween would only fight it -- and a redundant-value
  guard skips the write entirely when nothing changed.
- Both copies of `PromptUI` are byte-identical (6788 bytes, matching checksums).
- Still not eyeballed: `screen_capture` returns a blank frame for a running game, so colour balance
  and the 52px plate are judgement calls made from measurements.
