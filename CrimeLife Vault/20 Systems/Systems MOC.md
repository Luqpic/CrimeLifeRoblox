---
type: moc
tags: [moc, system]
updated: 2026-11-14
sources: ["CLAUDE.md (Instance tree, Systems)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Batch Log.md"]
---

# Systems MOC

What exists in CrimeLife and where it lives, one note per system. Each note has a `Skills:` line naming the `roblox-*` skills to load for work there. The **FPS System** place is the primary place; the **Robbery System** place shares UI modules with it but is a separate project: never edit it unless it is named.

## FPS combat

- [[Weapons and Blaster]]: data-driven guns, `ShotResolver` hit authority, knockback, the RPG.
- [[Viewmodels and Weapon Animation]]: first-person rigs, donor-skeleton swap, linear KeyframeSequences.
- [[Melee]]: Crowbar, Baton stagger, Knife bleed and backstab.
- [[Damage Direction]]: the on-screen hit-direction indicator.
- [[Ragdoll]]: player and enemy ragdolls.

## Progression and economy

- [[Economy and Cash]]: `CashService`, `leaderstats.Cash`, cash drops, the coin bursts.
- [[Weapon Shop and Upgrades]]: the Weaponary, permanent ownership, loadout slots, damage upgrades.
- [[Leveling and Renown]]: kill XP, level cap 70, seven criminal ranks.
- [[Spraypaint]]: the earned currency (once called Renown).
- [[Cosmetics and Skins]]: tint palettes and the Skins card.
- [[Gamepasses]]: passes, Cash products, the RPG pass.
- [[Persistence and Saves]]: ProfileStore saves, forward-only schema.

## UI

- [[HUD and UI Shell]]: `UI.Panels`, `UI.Effects`, `UI.Transitions`, Figma slices.
- [[Inventory and Hotbar]]: custom inventory, hotbar, slot picking.
- [[Notifications]]: stacked toast cards, the queue behind panels.
- [[Death Screen]]: "YOU DIED", HUD hiding, respawn.
- [[Player Card]]: the player card panel.
- [[Nameplates and Billboards]]: player and enemy overheads, weapon stat billboard.
- [[Camera Authority]]: camera claims, FOV and blur.

## World and NPCs

- [[Enemies and Spawner]]: enemy types, spawner, AI.
- [[Quests and Dialogue]]: quest givers, dialogue replies, quest log.
- [[Movement and Stamina]]: sprint, stamina, landings, lean.

## City map

- [[City Map and Plots]]: the cleaned Crimelife City map, the eight plots, streaming, the quarantine folders.

## Robbery place

- [[Robbery Prompts]]: the liquid-fill proximity prompt (shared with the FPS place).
- [[Robbery Heists and Getaway]]: locations, duffel bag, getaway distance, supplier, location status.
- [[Robbery Puzzles]]: lockpicking, word-scramble hack, safe keypad, Bank gauntlet.

Related: [[Decisions MOC]] · [[Open Items MOC]] · [[Batch Log]]
