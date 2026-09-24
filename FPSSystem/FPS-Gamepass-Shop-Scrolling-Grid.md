# Change Log: Gamepass Shop Grid Scrolls Instead of Overflowing

**Date:** 2026-09-25
**Status:** Applied. Verified live in play by screenshot and by reading back the grid's measurements. The
place is not saved to disk by this change.

## Summary
The Gamepasses panel drew its seventh card below the bottom of the panel. The grid now scrolls, the
same way the Weaponary's weapon grid does.

## Cause
- `GuiTemplates.GamepassShop.Grid` was a plain Frame, sized for exactly two rows of three cards
  (438 px tall, 428 px of cards).
- The RPG pass, added in the RPG change, is the seventh entry in `Monetization.Constants.Gamepasses`.
  It started a third row.
- A Frame neither clips nor scrolls, so that row was drawn past the panel's bottom edge.

## Changes
- `GuiTemplates.GamepassShop.Grid`: replaced by a ScrollingFrame with the same name, box and children,
  so `GamepassShopController` needed no change.
  - The scroll settings are copied from `WeaponaryShop`'s `WeaponGrid`: vertical only, auto-sized canvas
    height, a 6 px bar, and the same bar images and colours.
  - `WeaponGrid`'s UIPadding is added, so the 2 px "owned" outline is not clipped at the grid's edges.
- `UIGridLayout.CellPadding` X: 12 → 10. The right column otherwise touched the scrollbar exactly: its
  edge was at 706 px and the bar starts at 706 px. It now has 4 px of clearance, still 3 columns.

## Verification (play mode)
- Canvas measured 662 px against a 438 px window. It scrolled to the bottom (224 px).
- The RPG card showed in full at the bottom, "OWNED" outline intact. Nothing drew past the panel: the
  grid's bottom is 595 px against the panel's 615 px.
- The rightmost card edge is at 702 px, inside the 706 px window.

## Notes
- This scales with the pass list: any further passes just add rows to scroll.
