# Change Log: Proximity Prompt Sized Down, Ring Starts Empty

**Date:** 2026-09-19
**Status:** Applied (confirmed live in both places)

## The ring sat half filled at rest

The first build swept the ring with the usual radial trick: two half-width frames with
`ClipsDescendants`, each holding a rotated copy of a half-ring, revealed by changing `Rotation`.

**That does not work in Roblox. `ClipsDescendants` does not clip a ROTATED descendant.** So each
half rendered wherever its rotation happened to put it, regardless of its clip. At rest the first
half is parked at 180 degrees -- arc thrown over to the left -- and it drew there anyway, which is
the filled left semicircle in the report.

The geometry was never wrong: clips measured as exact halves and the images sat centred at the right
rotations. Only the clipping failed, which is why it looked like a maths error and was not one.

- `UI.PromptUI` -- the ring is now 48 discrete segments laid around the circle, each a small
  tangential bar, lit in order. No clipping is involved at all: a rotated Frame is just a rotated
  Frame. Segments are drawn 1.35x long so neighbours overlap and the fill reads continuous.
- Progress floors rather than rounds, so progress 0 lights zero segments. Rounding would light the
  first one immediately and the ring would look pre-filled again, just by a smaller amount.
- The half-ring slice is no longer used and is gone from `PromptUI.Assets`.

Verified: 0 / 4 / 12 / 24 / 36 / 48 segments at progress 0 / .1 / .25 / .5 / .75 / 1, with segments
marching clockwise from 12 o'clock (Seg1 at 0 degrees, Seg13 at 90, Seg25 at 180, Seg37 at 270).

## It was far too big

`BOX` 116 -> **76**, with plate, ring width and radius all derived from it so the Figma proportions
hold. Plate is now 52px.

## The hold drives the ring

Measured against a 2 second hold: the ring sat at 0/48, began filling the moment the key went down,
and reached 47/48 after 1.9s before the prompt triggered. Prompts with `HoldDuration = 0` fire
instantly and correctly leave the ring as an empty outline.

## Notes
- Both copies of `PromptUI` are byte-identical (6592 bytes, matching checksums).
- Still not eyeballed: `screen_capture` returns a blank frame for a running game, so size and
  appearance were verified numerically. 76px is a judgement call and easy to change -- every other
  measurement follows `BOX`.
