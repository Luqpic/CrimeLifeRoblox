# Change Log: Weapon Stat Billboard, Cash Currency, Damage Upgrade System

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added a floating stat panel above each weapon pickup showing its name, damage, ammo, and fire rate, plus a simple cash currency (earned per enemy kill) and a per-weapon-type damage upgrade a player can buy with it. This was the first currency/economy system in the game, so it also had to decide how cash is earned and how upgrades persist across death (tied to the player and weapon type, not a specific weapon instance, since weapons are lost on death).

## Changes
- `ServerScriptService.Weapons.Scripts.CashService` — new script granting starting cash and a native leaderboard `Cash` stat, incremented on enemy kills only (not player-vs-player).
- `ReplicatedStorage.Weapons.Remotes.UpgradeRequest` — new RemoteEvent for requesting a damage upgrade.
- `ServerScriptService.Weapons.Scripts.WeaponUpgradeService` — new script validating and applying upgrade purchases, recomputing damage from each weapon's stock value plus the player's upgrade level rather than incrementally stacking, so repeat upgrades can't drift.
- `ServerScriptService.Weapons.Scripts.WeaponPickup` — extended to mirror a pickup's stock stats onto attributes the client can read (since `ServerStorage` doesn't replicate), and to apply a player's existing upgrade level to a freshly granted weapon.
- `StarterPlayer.StarterPlayerScripts.WeaponStatBillboard` — new script building a distance-shown stat panel above each pickup with colored stat rows and an upgrade button wired to the new remote.

## Notes
- This pass's cash-per-kill and upgrade cost/cap numbers were later replaced by a tiered cash-drop system and different balancing in a subsequent pass — see later changelog entries for the current values.
- Upgrades are tied to (player, weapon type), not a specific Tool instance, so buying an upgrade persists across death even though the weapon itself doesn't.
