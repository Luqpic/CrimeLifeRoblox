# Change Log: Upgrades Worth Taking, Spend Feedback, Slot Animation, and Baton Sounds

**Date:** 2026-09-16
**Status:** Applied

## Summary
Five changes to the shop and to the Baton. Upgrades now add five damage per level instead of one, and
the stat panel shows the accumulated bonus next to the base figure. Spending cash shows a brief
floating amount that rises and fades. Equipping or removing a weapon makes only the affected slot
pop. The Baton was still using sounds left over from whatever it was first copied from rather than
the Security guard's. And the rotating 3D preview no longer restarts every time you buy, upgrade,
equip or remove something.

## Changes
- `ReplicatedStorage.Weapons.UpgradeConfig` — one shared figure for how much damage a level adds, so
  the number shown and the damage dealt cannot drift apart.
- `ServerScriptService.Weapons.Scripts.WeaponUpgradeService` and `WeaponShopService` — both places
  that work out a weapon's damage now use that shared figure.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the detail panel was doing two
  unrelated jobs in one routine, rebuilding the 3D model whenever it only needed to update text.
  Those are now separate, and only switching to a different weapon rebuilds the model. Adds the
  floating spend amount and the slot animation.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` — the four slots gained the scaling control the
  animation needs.
- `ServerStorage.Weapons.Baton` — its whole sound set replaced with the Security guard's.

## Notes
- The preview resetting was not a display glitch but a consequence of one routine doing two jobs:
  three separate places called it purely to refresh text, and each of those silently destroyed and
  rebuilt the spinning model as a side effect. Splitting the two apart fixes all three at once.
- The Baton's sounds differed in more places than expected. Three were identified up front; checking
  the folder properly found five of seven wrong, because the firing sound is a folder of three
  variants rather than a single entry and all three were wrong. Replacing the whole folder covered
  all of them, and brought the sound falloff distances into line as well — they had been set almost
  twice as far as the guard's.
- The slot animation deliberately does nothing on the first open, and nothing for slots whose
  contents did not change, so buying a weapon you are not carrying pops nothing.
- The upgrade figure is a placeholder rather than tuned balance, as the cost figure beside it already
  was.
