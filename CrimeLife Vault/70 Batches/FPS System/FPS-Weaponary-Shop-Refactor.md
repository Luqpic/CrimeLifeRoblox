# Change Log: Weaponary Shop Replaces World Pickups

**Date:** 2026-09-15
**Status:** Applied

## Summary
Replaced the sixteen weapon pickup stations scattered around the map with a single purchasable shop, and capped how many weapons a player can own at four. Weapons now cost cash and are chosen from a browsable catalog with categories, stats and prices, instead of being collected by walking up to them. The crowbar became the free starting weapon every player spawns with. Equipping itself was left completely alone — only one weapon was ever held at a time anyway, so "carry four" is an ownership limit rather than a new mechanic.

## Changes
- `ServerStorage.Weapons.*` — every weapon gained a category and, for the fifteen sellable ones, a price. The crowbar deliberately has no price, and that absence is what marks it as not for sale.
- `StarterPack.Crowbar` — a crowbar is now granted on every spawn, so a new or freshly respawned player is never weaponless.
- `Workspace` → `ServerStorage.ArchivedWeaponPickups` — all sixteen pickup stations moved out of the world, preserved rather than deleted.
- `ServerScriptService.Weapons.Scripts.WeaponPickup` and `StarterPlayer.StarterPlayerScripts.WeaponStatBillboard` — deleted; both existed only to serve pickups that no longer sit in the world.
- `ReplicatedStorage.Weapons.Remotes.BuyRequest` — new remote for purchases, matching the existing remotes' sandboxing so the packaged inventory scripts can fire it.
- `ServerScriptService.Weapons.Scripts.WeaponShopService` — new server script that publishes a read-only catalog of sellable weapons for clients to browse, and validates every purchase: ownership, the four-weapon cap, the swap target, and funds are all checked before anything is charged or destroyed.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` and `.WeaponCard` — new shop panel and weapon card templates.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — new client script driving the shop: category tabs, a stat detail view, buy and upgrade actions, and a swap picker for when the player is already at four weapons.
- `StarterGui.Custom Inventory` — hotbar capped at four slots, the old overflow panel's keybind disabled, its toggle button removed, and a new shop button added in its place. Upgrades still go through the existing upgrade service, unchanged.

## Notes
- The original plan connected the shop's action button once but rebuilt its handler on every detail view, which meant the button stayed bound to the first weapon ever opened — every later purchase would have bought that one instead. The currently displayed weapon is now tracked outside the handler.
- The shop's live refresh was also bound to the player's backpack a single time at startup. Roblox replaces the backpack on every respawn, so the shop silently stopped updating the moment a player first died. It now rebinds whenever a new backpack appears; this was reproduced and then confirmed fixed across a death.
- Weapons are still lost on death, as they were before, but re-acquiring one now costs cash rather than a walk to a pickup station. Upgrade levels are unaffected and persist independently of ownership, so a rebought weapon returns at its previously upgraded damage.
- The shop's Melee tab is always empty, since the only melee weapon is the unsellable crowbar. Harmless, but worth removing if no paid melee weapon is planned.
- Four of the weapons filed under auto-rifles are statistically submachine guns. Category is a per-weapon attribute rather than a hardcoded list, so reclassifying them or adding a fifth category is a data change, not a code change.
