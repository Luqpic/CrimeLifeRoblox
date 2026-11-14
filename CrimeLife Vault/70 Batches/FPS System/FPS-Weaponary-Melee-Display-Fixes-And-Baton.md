# Change Log: Shop Melee Visibility, Detail Tabs, 3D Orientation, Stun and the Baton

**Date:** 2026-09-15
**Status:** Applied

## Summary
Four shop and combat fixes plus a new weapon. The crowbar could never appear in the shop's melee tab because the catalog only listed weapons that had a price, and the crowbar deliberately has none. The category row now hides while browsing a single weapon, and the rotating 3D display no longer shows weapons lying on their side. A new stun effect freezes whatever it hits, and a purchasable baton is the first weapon to use it.

## Changes
- `ServerScriptService.Weapons.Scripts.WeaponShopService` — the shop catalog now lists any weapon with a category rather than only ones with a price, so owned-but-unsellable weapons appear in the tab they belong to.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the category row hides while a weapon's detail view is open and comes back on Back or on reopening the shop; the 3D display now orients each weapon from its own proportions; and a weapon with no price that the player does not currently own shows as not for sale rather than an empty price and a dead buy button.
- `ReplicatedStorage.Blaster.Constants` — added the per-weapon stun duration attribute name.
- `ServerScriptService.Blaster.Scripts.ShotResolver` — a hit from a weapon declaring a stun duration now stamps a shared expiry marker on the target, for players and enemies alike, without the resolver needing to know which it hit.
- `ServerScriptService.Movement.Scripts.SprintAuthority` — reads that marker and holds a stunned player still, blocking sprint for the duration.
- `ServerScriptService.Enemy.Scripts.EnemyAI` — reads the same marker and returns before its state machine runs, so a stunned enemy stops moving and stops firing instead of immediately undoing the stun on its next think.
- `ServerStorage.Weapons.Baton` — new melee weapon cloned from the enemy security baton, with its damage, knockback and swing timing synced to the current crowbar's tuned values rather than the drifted enemy copy, priced at 500, and carrying a one second stun.

## Notes
- The planned fix for the 3D display was a single fixed rotation derived from one rifle. Measured against all seventeen weapons, that framed twelve correctly and left every pistol and melee weapon wrong, because the meshes were authored with at least three different notions of "up" — two weapons were already upright and the fixed rotation actively broke them. The orientation is now derived per weapon from its own proportions, which frames all seventeen, and was confirmed in the live shop on a rifle, a pistol and the crowbar.
- Holding a stunned player at zero speed had the same flaw an earlier movement clamp did: the server lowers the value but a client's own writes never reach the server, so nothing would ever raise it back and a single stun would have frozen the player permanently. The stun and the existing landing slowdown now share one release, so whichever ends last restores normal speed and neither cuts the other short. Verified: speed returns to normal about a second after the hit rather than staying at zero.
- Listing the crowbar in the shop newly exposes a case where a player has given their crowbar away and it has no price to buy it back with. That now reads as not for sale instead of showing an empty price beside a button the server would reject.
- The baton has no icon of its own and reuses the crowbar's first-person viewmodel; both were deliberate, since no icon was supplied and a separate first-person rig is well beyond "works like a crowbar". Its own third-person model, stats and stun are all baton-specific, and its swing animations are identical to the crowbar's.
