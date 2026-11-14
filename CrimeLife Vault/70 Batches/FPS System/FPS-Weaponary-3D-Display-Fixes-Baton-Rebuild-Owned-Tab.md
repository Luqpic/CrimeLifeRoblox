# Change Log: 3D Display Orientation, Baton Rebuild, Owned Shop Tab

**Date:** 2026-09-15
**Status:** Applied

## Summary
Fixed the shop's rotating 3D weapon display, rebuilt the baton so it actually works, and added an "Owned" tab. Guns were displaying upside down and pistols were standing on end; melee weapons now stand upright and turn more slowly than guns. The baton, which did not work at all, was rebuilt as a straight duplicate of the crowbar so its mechanics are identical by construction rather than by re-syncing settings.

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the display now works out each weapon's orientation from the weapon itself rather than applying one fixed rotation; melee weapons stand upright and spin at half a gun's rate; and the camera distance is worked out from the footprint the weapon actually sweeps as it turns, so nothing overflows the box mid-spin.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the grid can now filter on ownership, backing the new tab.
- `ServerStorage.Weapons.Baton` — rebuilt as a duplicate of the current crowbar, then reskinned with the baton's own third-person model, given its own first-person viewmodel, and kept as the only weapon that stuns.
- `ReplicatedStorage.Blaster.ViewModels.Baton` — its own independent first-person viewmodel, recolored dark metal rather than mesh-swapped, so the hand joints and swing trail that live on that part survive.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` — an "Owned" tab sits between "All" and "Melee".

## Notes
- The planned fix was to flip the sign of a single fixed rotation. Measured across all seventeen weapons, a fixed rotation frames only twelve correctly in either direction — the meshes carry at least three different notions of "up", so the five it misses are not flipped but genuinely mis-posed, with every pistol standing on its end. Flipping the sign would have corrected the rifles the report was about while leaving those five wrong.
- Matching each weapon's axes, which the previous pass did, still leaves the up/down direction free — which is exactly how guns ended up upside down while measuring as correctly framed. The direction is now pinned by the weapons' own landmarks: every one carries a muzzle attachment, which fixes which way the barrel points, and fourteen of seventeen carry a magazine, which hangs below the bore and fixes which way is up. All fourteen now display magazine-down, and all seventeen muzzle-forward.
- The three without a magazine are the two melee weapons, where up and down are not meaningful and which now stand upright anyway, and the shotgun, whose up direction is not pinned by any landmark. If the shotgun specifically looks inverted, that is the one to report.
- The new "Owned" tab was specified to sit at position two, which collided with the melee tab already there and left the row's order undefined. The tabs are now numbered explicitly.
- The baton was verified by actually hitting an enemy with the purchased weapon, not by reading its settings: it deals the same damage and knockback as the crowbar and additionally stuns, while the crowbar stuns nothing. Worth noting for future tests that aiming head-on at an enemy at chest height hits the gun it is holding rather than the enemy, which silently produces a zero-damage result.
