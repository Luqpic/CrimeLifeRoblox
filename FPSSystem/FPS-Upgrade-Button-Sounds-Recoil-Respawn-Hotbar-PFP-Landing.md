# Change Log: Upgrade Button Style, Sound Volume Pass, Enemy Recoil, Respawn Timing, Hotbar Restyle, Player Card Photo Fix, Landing Slowdown

**Date:** 2026-09-12
**Status:** Applied

## Summary
A batch of nine smaller changes: made the weapon upgrade button red and taller; added a pickup sound that reuses each weapon's own equip sound; raised equip and cash pickup sound volumes; reduced two rifle-enemy types' recoil without affecting a player using the same guns; lengthened the death/respawn countdown from 2 to 5 seconds; removed the hotbar's black outline to match the leveling bar's cleaner look; fixed the player card's blank profile photo (a wrong Roblox API enum name); and added a brief movement slowdown after landing a jump, whether or not the player was sprinting.

## Changes
- `ReplicatedStorage.GuiTemplates.WeaponStatPanel` — upgrade button recolored red and enlarged; other rows resized to keep their previous size.
- `ServerScriptService.Weapons.Scripts.WeaponPickup` — now plays the picked-up weapon's own equip sound.
- All 16 weapons' equip sounds, and the cash pickup sound — volume raised.
- `ReplicatedStorage.Enemy.templateConfig`, `ServerScriptService.Enemy.Scripts.EnemyAI` — added a per-enemy recoil override, applied only to Armed Police/Armed Criminal.
- `StarterPlayer.StarterPlayerScripts.DeathScreen`, `ServerScriptService.Ragdoll.Scripts.PlayerRagdoll` — respawn countdown lengthened from 2 to 5 seconds, with the underlying respawn timer adjusted to match.
- `StarterGui."Custom Inventory".InventoryController.toolButton` — outline removed.
- `StarterPlayer.StarterPlayerScripts.PlayerCardController` — fixed the invalid enum name that caused a blank profile photo.
- `ReplicatedStorage.Movement.Constants`, `ServerScriptService.Movement.Scripts.SprintAuthority` — added a landing-recovery movement slowdown, independent of sprint state.

## Notes
- The player card photo bug was confirmed by directly reproducing the error live before fixing it, not assumed.
