# Opening the Skins card slides the shop aside instead of shrinking it

**Status:** Confirmed live through the real input path (HUD weaponry button → AK47 card → BACK), at a
1286-point viewport that matches the user's own (~1283, derived from their screenshot). Every frame of
both animations was recorded, and the open state was screenshotted. The narrow-viewport fallback was
exercised separately at 978 points. Both changed scripts are client-side, where the server test
suite cannot reach, so the live recording is the verification for them. Live source and repo mirror
checksummed identical for both files.

## Summary

Clicking a weapon card used to shrink the whole shop so the Skins card could fit beside it. Now the
shop keeps its size and slides left, the Skins card slides in from the right beside it, and BACK
reverses both. The shop only scales down on a viewport too narrow to hold the pair at full size.

## Cause

User-reported: "when I click the weapon card, it then suddenly becomes small."

The previous fix kept the shop centred on its own and made the responsive scale reserve the card's
overhang on **both** sides (`RESERVED_WIDTH = 2 * (card + gap + slide)` = 600 extra units). That
budget was correct for a centred shop, but it made the shop shrink much further than the card needed.
At the user's viewport the fit worked out to roughly 0.78, a visible jump down in size on every
weapon click.

## Changes

- `SkinsCardController`
  - `RESERVED_WIDTH` is now one card footprint (`card + gap` = 260), not a doubled overhang. The pair
    is centred as a unit, and a centred pair of width `shop + gap + card` is exactly what the
    symmetric fit formula measures.
  - Exports `SHOP_SHIFT` (half the card footprint, 130 units) and its open/close tweens, so the shop's
    slide shares the card's timing and easing.
  - The card's slide is now an animated offset (`slideValue`) added on top of the card's tracked
    position, not a tween of `card.Position`.
  - Tracking continues through the close animation and is released only when the fade finishes. The
    fade's completion is guarded, so re-opening the card mid-fade cannot switch it off.
- `WeaponaryShopController`
  - `slideShop(makeRoom)` tweens the shop's `Position` left by `SHOP_SHIFT` when the card opens, and
    back to `SHOP_REST_POSITION` on BACK and on closing the shop. The rest position is captured from
    the template.
  - `openShop` resets the shop to its rest position.
  - `refreshShopScale` takes a `TweenInfo`: eased when the card opens or closes, instant on a viewport
    resize.

## Verification

At 1286x719 (the user's case):

| | Shop width | Shop left edge | Card right edge | Gap | Pair centre vs viewport centre |
|---|---|---|---|---|---|
| Before click | 920 | 183 | n/a | n/a | shop centred at 643 |
| During open | 920 every frame | 183 → 41 (Back overshoot) → 53 | max 1259 of 1286 | 17 – 26 | |
| Settled open | 920 | 53 | 1233 | 20 | 643 = 643 |
| During BACK | 920 every frame | 68 → 183 | | 24 → 42 while visible | |
| Settled BACK | 920 | 183 | card off | | 643 = 643 |

The shop never changed size and the card never left the screen. At 978 points, where the pair cannot
fit at full size, the pair still ends centred (midpoint 488.7 against 489), with the shop scaled to
0.779.

## Notes

**Why the slide had to become an offset, not a tween.** The card is glued to the shop: it re-seats
itself whenever the shop's `AbsolutePosition` or `AbsoluteSize` changes, which is how it follows a
viewport resize. With the shop now moving at the same moment the card slides in, a tween on
`card.Position` would be overwritten by that glue on the first frame of the shop's slide, and the card
would simply appear at its destination. Animating a separate `NumberValue` and adding it inside
`reseat` makes the two motions add: the card rides with the shop and slides in relative to it on
every frame. The close animation had the same problem in reverse. The old code stopped tracking the
moment close began, so on BACK the shop would have slid across a card that had stopped moving.

**A defect the recording caught, not the arithmetic.** On the first pass, a BACK at 978 points
showed one frame with the shop's left edge at **x = −17.6**, briefly off-screen. The scale was
easing Quad-Out (fast start) while the slide back eased Quad-In (slow start), so the shop grew around
its still-shifted centre before it moved. The fix passes the matching easing in: Quad-In for the
scale on close, and Quad-Out over the open tween's duration on open. It is Quad rather than the
card's Back easing, because Back overshoots and would briefly push the scale past `SHOP_MAX_SCALE`.
This only arises where the fallback shrink applies. At the user's viewport the scale stays at 1.0
throughout.

**Budget arithmetic.** Pair at full scale: 920 + 20 + 240 = 1180. At the user's 1283-point viewport
with the formula's 0.94 margin, fitX = 1206 / 1180 = 1.022, clamped to 1.0, so no shrink. The pair
first needs to shrink below about a 1255-point viewport.

**Not reserved: the slide's overshoot.** The card starts `SLIDE_OFFSET` (40) to the right of its
resting spot, but it is fully transparent there, and its slide-out ends fully transparent too. So
that travel does not need a place in the fit budget. The measured maximum right edge during the open
was 1259 of 1286.
