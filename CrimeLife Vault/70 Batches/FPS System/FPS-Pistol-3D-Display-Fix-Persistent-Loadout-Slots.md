# Change Log: Pistol Shop Display, and Permanent Ownership with Loadout Slots

**Date:** 2026-09-16
**Status:** Applied

## Summary
Two unrelated faults in the weaponry shop. Every pistol showed barrel-upright in the rotating 3D
preview instead of lying horizontal like the rifles. Separately, buying a fifth weapon once you
already owned four destroyed one of the ones you had — permanently, so buying it back cost full price
again. Ownership is now permanent and uncapped; the four slots decide only which owned weapons you
actually carry, and moving a weapon out of a slot never loses it.

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the preview derives each weapon's
  orientation from its own shape again, and turns on the spot rather than drifting. Ownership and
  slot contents are read from values kept on the player instead of by scanning what is in hand, and
  an Equip/Dequip button was added beside Upgrade.
- `ServerScriptService.Weapons.Scripts.WeaponShopService` — ownership is permanent and uncapped;
  buying now only grants ownership and never places a weapon in your hands. The four slots are
  published as player values, and are what gets restored on respawn.
- `ReplicatedStorage.Weapons.UpgradeConfig` — one shared place that turns a weapon name into a safe
  value name, now used for ownership as well as upgrade level.
- `ReplicatedStorage.Weapons.Remotes` — a new request for setting or clearing a loadout slot.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` — an Equip button added to the detail panel.

## Notes
- This corrects an earlier entry. The "3D display orientation" change logged on 15 September applied
  one fixed rotation to every weapon. That was applied, and then turned out to be the direct cause of
  the pistols displaying wrongly: the code it had replaced worked each weapon's orientation out from
  its own shape and framed all seventeen correctly, where the single fixed rotation framed twelve and
  left every pistol and melee weapon wrong. The by-shape method has been restored, so that earlier
  entry should be read as superseded rather than as describing what is in the game now.
- The same fixed-rotation change had a second fault nobody had reported: weapons drifted in a small
  circle in the preview box instead of turning on the spot. That is fixed by the same restoration.
- One thing a weapon's shape genuinely cannot settle is which way up it is, since a weapon's outline
  is much the same either way round. A per-weapon override was kept for exactly that case, unset on
  every weapon except the AK47.
- Deliberate design decision, stated so it can be reversed if unwanted: buying no longer equips a
  weapon even when a slot is free. Equipping is always a separate, explicit choice of slot. Total
  ownership has no limit any more; only the four carry slots do.
- Ownership, upgrade levels and slot assignments still last only for the session. Nothing here adds
  saving between visits, which the game does not do for cash or level either.
