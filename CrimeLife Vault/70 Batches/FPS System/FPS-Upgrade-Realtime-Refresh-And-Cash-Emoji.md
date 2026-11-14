# Change Log: Upgrades Appeared Not to Apply, and the Cash Symbol

**Date:** 2026-09-16
**Status:** Applied

## Summary
Upgrading a weapon looked as though it had done nothing: the damage figure in the shop stayed where
it was. The upgrade had in fact applied every time — the weapon really was dealing more damage — but
the panel was repainting itself a fraction too early and showing the figure from before the upgrade,
then never correcting itself. The panel now repaints when the new level actually arrives. The money
symbol throughout the shop was also changed from the money bag to a banknote.

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the panel's repaint after an upgrade
  is now triggered by the new level arriving rather than by a fixed short wait. The money symbol
  changed in all four places the shop shows a figure: the upgrade cost, the buy price, the price on
  each weapon card, and the floating spend amount.

## Notes
- Worth recording that the reported fault and the actual fault were different. The report was that
  damage was not being applied to the weapon. Testing it in a running game showed the opposite: the
  server found the held weapon and raised its damage from 45 to 50 exactly as intended, and the code
  that works out damage on a hit reads that value fresh each time. So the weapon was always correct
  and only the number on screen was wrong. Patching where the problem appeared to be would have
  changed working code.
- The cause was a race. After asking for an upgrade the panel waited a tenth of a second and then
  repainted. When the new level took longer than that to reach the player — which it often does — the
  repaint read the old level, drew the old damage, and nothing refreshed it again until the panel was
  closed and reopened. Repainting when the level actually arrives removes the timing assumption
  rather than lengthening the wait, so it cannot come back on a slower connection.
- Only the shop's own figures changed symbol. Nothing else in the game that shows cash was touched.
