# Change Log: Baton's Shop Preview, Grid Bleeding Past the Panel, and Overlapping Buttons

**Date:** 2026-09-16
**Status:** Applied

## Summary
Three unrelated faults in the shop. The Baton's spinning 3D preview was lying on its side and framed
far too close, while all twenty-seven other weapons were fine. The weapon grid could be seen past the
panel's rounded corners when scrolled. And hovering the buy/upgrade button made it grow into the
equip button beside it.

## Changes
- `ServerStorage.Weapons.Baton` — its body was rebuilt as a proper mesh part, the same way every
  other weapon in the game is built. The swing trail, the muzzle point and the weld all moved across
  unchanged.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` — the shop panel now clips its contents to its own
  shape.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton` — moved twenty
  pixels right.

## Notes
- The Baton was the only weapon showing the preview fault because it was the only weapon not built
  like the others: a plain part with a mesh hung off it, rather than a mesh part. The shop works out
  which way up to show a weapon, and how far back to put the camera, by measuring the weapon's real
  size. For a plain part that measurement returns the part's own dimensions, which had no relation to
  what was actually being drawn — so the shop picked the wrong axis and framed far too close. Nothing
  was wrong with the shop's own logic, and it was left alone.
- Only the world model was converted. The first-person view of the Baton is positioned by a joint
  rather than by measurement, so it was never affected and was not touched.
- The rounded corners were only ever cosmetic — they draw the corner but do not stop anything
  rendering past it. The grid already clipped its own contents, which is why this only showed at the
  panel's outer edge and only when scrolled.
- The button overlap was a side effect of the hover reaction added in the previous pass. At its
  normal size the button ended ten pixels short of its neighbour; grown on hover it needed eighteen.
  The hover effect is working as designed — the gap was simply never sized for it.
