---
type: moc
tags: [moc, howto]
updated: 2026-11-14
sources: ["CLAUDE.md (How to work in this project)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Batch Log.md"]
---

# How-To MOC

Recipes for adding things along CrimeLife's real data path (FPS System place unless a recipe says otherwise). The rule: follow the data path and never fork shared code; extend by data (a Tool attribute, a config row, a palette entry, a spawn point) that the shared code already reads. See [[Shared Code Extended by Attributes]].

Every recipe names the system note to read, the 1 to 3 skills to load ([[Roblox Skills]]), the check to run, and the change logs that did it before. Measure before and after ([[Measure Before and After]]); read the result back live, then record the change as a batch in [[Batch Log]]. Claude never saves or publishes the place; the developer saves.

## Weapons
- [[Add a Gun]]: a `SPECS` row in the re-runnable build script (donor-skeleton swap), a motion profile, a `MuzzleAttachment`; shop and skins follow.
- [[Add a Melee Weapon]]: a Crowbar-mechanism clone with a new mesh and melee attributes.
- [[Add a Weapon Attribute]]: an opt-in constant in `Blaster.Constants`, read by the shared code, nil = old behaviour.
- [[Add a Viewmodel Animation]]: procedural motion in `WeaponViewmodelMotion`, then the KeyframeSequence export.

## World
- [[Add an Enemy Type]]: a template in `ServerStorage.EnemyTemplates` and a spawn point tagged `EnemyType`.
- [[Add a Quest]]: a `QuestConfig` entry and a giver in `Workspace.Quests`.

## Money and cosmetics
- [[Add a Gamepass]]: a `Monetization.Constants` entry and a `GamepassOwned_<key>` server check.
- [[Add a Cosmetic Skin]]: one row in `Cosmetics.Palettes`.

## Interface and sound
- [[Add a Menu Panel]]: a Figma-sliced template on `UI.Panels`, `UI.Effects`, `UI.Sounds`, `UI.Transitions`.
- [[Add a Notification]]: one `NotificationController.show` call from a client controller.
- [[Add a Sound]]: the weapon's `Sounds` folder, `UI.Sounds`, or a controller constant.

## Testing
- [[Add a Unit Test]]: a `_Test` case for `ServerStorage.UnitTest`, run in Play.

## Not written (no source to ground them yet)
- Robbery System recipes (a new robbery location, a new puzzle prompt): the Robbery change logs cover single changes, not a repeatable path. See [[Robbery Prompts]] and [[Robbery Heists and Getaway]] until one is written.
- Badges, codes, cutscenes: CrimeLife has no recorded work on them.
- Admin commands: only `/setlevel` and its F2 panel exist (`AdminLevelController`, [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]]); one example is not yet a recipe. See [[Leveling and Renown]].
