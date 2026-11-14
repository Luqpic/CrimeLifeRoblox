---
type: howto
tags: [howto, enemies, npc]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-AI-6-Types.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Marketplace-Outfits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Overhead-GUI-Integration.md", "Roblox Games/EnemyAI.md", "CLAUDE.md (Systems: Enemies)", "CrimeLifeRoblox/FPSSystem/Stats/KillStatsService.luau"]
---

# Add an Enemy Type

A new kind of enemy that spawns, fights with a real weapon and counts for quests. Data path: a rig template in `ServerStorage.EnemyTemplates` -> a spawn point in `Workspace.EnemySpawns` tagged `EnemyType` -> `EnemySpawner` clones it and tags its spawn kind -> `EnemyAI` runs it -> its shots go through `ShotResolver` like a player's. System: [[Enemies and Spawner]].

Skills: `roblox-npc-ai`, `roblox-game-systems`.

## Steps
1. **Clone an existing rig** in `ServerStorage.EnemyTemplates` and name it. **Clear every donor attribute** before setting new ones (the Saboteur, built from Disrupters, would otherwise carry AKM recoil and aim on a P-90).
2. **Give it a weapon:** a clone of a real Tool from `ServerStorage.Weapons`. Enemies fire through `ShotResolver.resolveShot` with that Tool, so its attributes apply as for a player.
3. **Stats:** health, speed, detection; an explicit `DamageOverride` (the shared config otherwise flattens enemy damage); for melee, `EngageRangeFraction`. Per-type accuracy ceiling and recoil overrides through `EnemyAI` / `ReplicatedStorage.Enemy.AimConfig`. New figures sit on the curve between their level neighbours; say they are placeholders.
4. **Outfit:** marketplace accessories plus `BodyColors` (see the outfits change log). The prebuilt `EnemyGUI` billboard replaces the default nameplate. See [[Nameplates and Billboards]].
5. **Spawn point:** a part in `Workspace.EnemySpawns` with attribute `EnemyType = "<template name>"`, on ground already proven to work and clear of the player spawn. The spawner scatters within a 22-stud radius and caps each type separately (`ReplicatedStorage.Enemy.Constants`).
6. **Quests and stats:** quests target the spawn kind by name ([[Add a Quest]]); `KillStatsService` counts kills per faction from the same `Eliminated` event. Cash and XP on death are worked out from the weapon's fire mode, so a shotgun enemy pays at pistol rate (known, accepted).
7. Rigs join the `EnemyCharacter` collision group (does not self-collide).

## Files to touch
`ServerStorage.EnemyTemplates.<name>`, `Workspace.EnemySpawns`, optionally `Enemy.Constants`, `Enemy.AimConfig`, `QuestConfig`.

## Check
- Spawn it in Play: per-type count stays at or under the cap; it detects, chases and damages.
- Search the whole place for any old name you replaced: none left.
- Nearest-neighbour distances if crowding matters ([[Enemies-Climbing-Each-Other-And-Nameplate-Gap]] style), [[Measure Before and After]].

## Done before
[[FPS-Enemy-AI-6-Types]], [[FPS-Enemy-Marketplace-Outfits]], [[FPS-Enemy-Overhead-GUI-Integration]], [[FPS-Enemy-Roster-Rework-3-New-Recruits]], [[FPS-Spawner-Rework-Enemy-Nerf-Death-Inventory]], [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]], [[Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip]], [[FPS-Miss-Tracers-And-Spawn-Cap]].
