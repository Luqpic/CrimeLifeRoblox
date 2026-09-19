# Change Log: Liquid Takes the Plate's Shape, Plus Hover and Hold Lift

**Date:** 2026-09-19
**Status:** Applied (confirmed live in both places)

## The liquid had square corners

The fill sat inside a rounded plate with sharp bottom corners. The clip carried a `UICorner`, which
did nothing:

**`UICorner` does NOT affect `ClipsDescendants`. Roblox always clips to the rectangular bounds.**

Rounding the clip was therefore cosmetic on the clip itself and invisible to what it clipped.

The fix is to stop trying to clip *into* a rounded shape and let the liquid **be** one. It is now
the same rounded square as the plate, drawn WHITE (`ImageColor3` multiplies, so only a white source
can be tinted to the accent) with the 4px inset baked in as transparent margin. The clip is a plain
rectangle grown up from the bottom, which reveals exactly the bottom slice of that shape -- rounded
bottom corners, flat top, like liquid in a rounded glass.

Redesigned on Figma page **05 · ProximityPrompt**, which now carries idle / 35% / 70% / full / hover
reference tiles alongside the two export slices.

- `UI.PromptUI` -- `Liquid` is an ImageLabel on the new fill slice, full plate size and pinned to the
  bottom, so growing the clip shows more of the shape rather than stretching it. Verified: the
  liquid's bottom edge stays exactly on the plate's bottom edge (+0.0px) at every fill level.

## Hover and hold now lift the prompt

- The plate is an `ImageButton` and the billboard sets `Active = true`. BillboardGui gates input for
  its whole subtree and defaults to off, so without that the cursor never reaches the plate.
- `MouseEnter` / `MouseLeave` and the hold events share one `setLifted` state: the key rises
  by 9% of the plate and the whole prompt swells to 1.07, Back-eased.
- The press lifts **before** any fill, so a `HoldDuration = 0` prompt still reacts to the key going
  down. Where the mouse is locked to centre (aiming), the hold path drives the same state.

## Measured
- Lift: key y 0 -> -5 -> 0, scale 1.00 -> 1.07 -> 1.00.
- Live 2s hold, released early: press lifted at once (keyY -5, scale 1.08 on the Back overshoot)
  with fill still at 0%, fill then rose 13 -> 27 -> 40 -> 53 -> 67%, and release reset both.
- Both copies of `PromptUI` are byte-identical (7487 bytes, matching checksums).

## Notes
- Still not eyeballed: `screen_capture` returns a blank frame for a running game. Shape alignment,
  lift and fill were verified numerically; the liquid's 0.55 transparency remains a taste call.
