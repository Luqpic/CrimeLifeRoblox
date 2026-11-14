# Change Log: Prompt Becomes a Circle With a Liquid Fill and Halo

**Date:** 2026-09-19
**Status:** Applied (confirmed by the project owner)

## Summary
The custom prompt went through several shapes before landing. It is now a **circle**: one frame whose `UICorner` makes it round, whose `UIStroke` draws the border, and whose fill level is a hard stop in its own `UIGradient`. A faint accent halo sits just outside it. Holding fills it bottom-to-top like liquid.

## The outline chase — four Roblox limitations, in order

A thin outline hugged the fill and survived four fixes. Each fix was aimed at a different plausible cause; each was wrong for an instructive reason. Recording them because every one is a trap worth knowing:

1. **`ClipsDescendants` does not clip a ROTATED descendant.** The first progress ring was two rotated half-discs behind half-width clips. They rendered wherever their rotation put them, ignoring the clips, so the ring sat half-lit at rest. Replaced with 48 rotated segment frames — correct, but 48 instances to draw a circle.
2. **`UICorner` does not affect `ClipsDescendants`.** Clipping is always rectangular. A rounded clip around the liquid did nothing, so the fill had square corners inside a rounded plate.
3. **Stacking two coincident soft-edged shapes always bleeds the lower through the upper.** The plate and the liquid were the same rounded shape on top of each other. Along their shared silhouette the liquid alpha falls below 1, so the plate showed through as a ~1px rim. `BorderSizePixel`, `strokeAlign`, removing the inset and making the fill opaque each only changed WHICH colour bled through.
4. **`UICorner` does not mask a `CanvasGroup`.** After removing the images, the group was supposed to own the rounded silhouette. It accepted the property but never clipped the children, so the prompt rendered square with a rounded stroke drawn over it.

The settled design avoids all four: **one frame, one shape, one gradient.** Nothing is rotated, nothing is clipped, nothing is stacked, nothing is masked.

## What it does now
- Circle via `UICorner` at 0.5 scale on the frame that actually draws.
- Fill is a two-keypoint hard stop in a `UIGradient` (rotation 90, so offset 0 is the top). Verified: p=0.25 puts the boundary at 0.750 from the top, p=0.5 at 0.500, p=0.75 at 0.250.
- Faint accent halo as a stroke on an empty slightly-larger circle, 0.82 transparency at rest.
- Entrance: transparency 1 to 0 with a 0.82 to 1 scale pop, Back easing. Exit fades then destroys, so a prompt leaving range animates away.
- Hover and hold both swell the prompt to 1.07 and brighten the halo to 0.55. **The letter does not move** — nudging a centred letter inside a circle reads as a wobble.
- Triggering DRAINS the meter. It used to be pinned at 1, which left instant prompts and refused actions sitting brim-full.

## Notes
- Both copies of `PromptUI` are byte-identical (9729 bytes, matching checksums).
- The `CanvasGroup` is sized `BOX` rather than `PLATE` so the halo fits: a CanvasGroup renders children into a texture its own size and cuts off anything past it.
- The prompt draws entirely from colours now. The Figma plate and fill slices it used to need are unused; Figma page **05 · ProximityPrompt** still documents the look.
- None of this was ever confirmed visually by me: `screen_capture` returns a blank frame for a running game, so every check above is structural or numeric. The user confirmed the final result by eye.
