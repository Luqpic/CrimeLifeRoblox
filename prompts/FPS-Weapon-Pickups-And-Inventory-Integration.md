# Change Log: Weapon Pickup System and Custom Inventory Integration

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added the actual interaction that lets a player pick up one of the 16 world weapon pickups and receive that weapon, and integrated a third-party "Custom Inventory" hotbar/backpack asset to replace the native Roblox backpack. Previously pickups existed in the world with prompts but nothing handled triggering them, and the custom inventory asset was sitting unused in its packaged, ungrouped form.

## Changes
- All 16 weapon pickup Models in `Workspace` — tagged for pickup detection, prompt text filled in with each weapon's name.
- `ServerScriptService.Weapons.Scripts.WeaponPickup` — new script granting the matching weapon into the player's backpack on interaction, blocking duplicate grants while already owned, allowing re-acquisition after death.
- `ServerScriptService.Enemy.Scripts.EnemySpawner` — fixed a stale fallback weapon lookup that still pointed at the old `StarterPack` location instead of `ServerStorage.Weapons`.
- Custom Inventory asset — ungrouped per its own packaging instructions and moved into `StarterGui`; its packaging wrapper, README script, and unused camera rig were deleted.
- `StarterGui."Custom Inventory".InventoryController` — wired death handling through the inventory's own exposed lock/unlock API instead of a separate mechanism.
- `StarterPlayer.StarterPlayerScripts.InventoryDeathLock` — removed; superseded by the Custom Inventory's own death-lock wiring, which it would otherwise have fought with (both were toggling backpack visibility independently).

## Notes
- Weapons are granted per-instance (cloned into the backpack), not registered with the inventory UI directly — the inventory UI reacts to anything appearing in the player's backpack automatically, so no separate registration step was needed.
