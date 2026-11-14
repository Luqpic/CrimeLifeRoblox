# Change Log: Menu Blur, and Buttons That React to the Cursor

**Date:** 2026-09-16
**Status:** Applied

## Summary
Opening the weaponry shop or the player card now narrows the view slightly and blurs the world behind
the panel, so the panel reads as the thing in focus rather than as a flat sheet laid over a busy
scene. Several buttons also gained a reaction to the cursor: the shop's trigger button dips when
clicked, the weapon cards and the equip button light up an outline on hover, and the buy/upgrade
button grows slightly on hover and presses in on click.

## Changes
- `ReplicatedStorage.Modules.MenuFovBlur` (new) — one shared piece that handles the narrowing and the
  blur for any menu that wants it. It counts how many menus are open rather than simply switching the
  effect on and off, so closing one panel while another is still open does not clear the effect early.
- `ReplicatedStorage.Modules.CameraAuthority` — gained a "Menu" entry, so an open menu's claim on the
  view is arbitrated against the other things that adjust it (aiming down sights, sprinting,
  crouching) instead of overwriting them.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` and `PlayerCardController` — both now
  raise and lower that effect as they open and close, including the player card's second open path.
- `StarterGui."Custom Inventory".weaponaryButton` — click bounce.
- `ReplicatedStorage.GuiTemplates.WeaponCard` — gained an outline, shown on hover.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.ActionButton` — hover and click
  reaction.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton` — gained an
  outline, shown on hover.

## Notes
- One of the demo effects in the pack is named after something it does not do: the button labelled
  "Stroke Visible On Hover" actually animates a different property entirely. Taking the name at face
  value would have produced the wrong effect on the weapon cards and the equip button. The effect
  that genuinely does what was wanted was taken from elsewhere in the pack.
- The demo's own version of the blur effect wrote the camera's field of view directly. Copying that
  would have let an open menu fight with aiming and sprinting over the same property. Routing it
  through the existing arbitration instead means whichever has priority wins predictably, and closing
  a menu hands the view back rather than forcing it to a fixed number.
- The reference counting is not speculative: the shop and the player card can both be open in
  sequence, and the naive version visibly popped the blur off and straight back on between them.
