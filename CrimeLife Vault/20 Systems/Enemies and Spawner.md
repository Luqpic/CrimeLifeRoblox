---
type: system
tags: [system, enemies, npc-ai, fps]
updated: 2026-11-14
sources: ["CLAUDE.md (Instance tree, Systems)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-AI-6-Types.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Miss-Tracers-And-Spawn-Cap.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Clustered-Enemies-Stop-Attacking.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Enemy-AI-6-Types.md"]
---

# Enemies and Spawner

**Skills:** `roblox-npc-ai`, `roblox-physics`, `roblox-game-systems` (load these for work here)

FPS System place only.

## What it does
Keeps a criminal-side enemy population alive around the map: each spawn point tops up its own enemy type to a per-type cap, the AI patrols, detects, chases, shoots or swings, searches when it loses a living target, and reacts to stun. Kills feed quests, leveling, cash drops and the kill toast.

## Where it lives
- `ServerScriptService.Enemy.Scripts.EnemySpawner`, `ServerScriptService.Enemy.Scripts.EnemyAI`.
- `ReplicatedStorage.Enemy.Constants` (`MAX_CONCURRENT_ENEMIES_PER_TYPE`, recoil-decay constants), `ReplicatedStorage.Enemy.AimConfig`, `ReplicatedStorage.Enemy.templateConfig` (per-type accuracy ceiling and recoil overrides).
- `ServerStorage.EnemyTemplates.*`: nine rigs (see below), each with its weapon Tool inside.
- `Workspace.EnemySpawns`: six `<Type>Spawner` parts, each with an `EnemyType` `StringValue` child.
- `ReplicatedStorage.GuiTemplates.EnemyGUI`: the overhead name and health display, attached at spawn.
- Hit resolution and line of sight: `ServerScriptService.Blaster.Scripts.ShotResolver`, `ReplicatedStorage.Blaster.Utility.findOwningHumanoid` / `castRays` (see [[Weapons and Blaster]]).

## How it works
- **Roster (as of 2026-09-17).** Spawning, all criminal-side: Thug (Crowbar), Offender (was Criminal), Disrupters (was Armed Criminal, AKM), Smuggler (PB pistol), Bandits (Mossberg 590), Saboteur (FN P-90). Kept but not spawning: Security (Baton), Police, Armed Police; their outfits now dress the quest givers ([[Quests and Dialogue]]). Health, speed and accuracy of the three newest are placeholders on the difficulty curve, not balance.
- **Spawner.** A spawn point is considered only while its own type is below `MAX_CONCURRENT_ENEMIES_PER_TYPE` = 5 (six points, so 30 alive at most). Top-up every `TOP_UP_INTERVAL` = 2.5 s. A rig is placed at a random offset within `SPAWN_SCATTER_RADIUS` = 22 studs, radius sampled through a square root so the disc fills evenly. Rigs go into the `EnemyCharacter` collision group, which does not collide with itself (still collides with world and players; weapon raycasts unaffected).
- Every spawned rig is renamed `Enemy`, keeps its type in the `EnemyTemplate` attribute (shown on the kill toast and nameplate), and has **all its scripts destroyed on spawn**. `EnemyGUI` is attached afterwards for that reason. Roblox's own name/health display is off on all templates.
- **Damage and aim.** Each template carries `DamageOverride` (set to 20% of its weapon's stock damage on 2026-09-11; the shared config otherwise forces a debug value of 3). Melee types carry `EngageRangeFraction`. Ranged enemies accumulate and decay recoil from their weapon's own recoil attributes; Armed Police / Armed Criminal (now Disrupters) have extra accuracy-ceiling and recoil overrides.
- **AI states.** Patrol, Chase, Attack, Search; it reconsiders four times a second. Losing a living target: go to last-seen spot, turn once (about 50 degrees), then hold. A dead target ends pursuit on the spot and returns to Patrol. Melee damage waits for the swing delay, matching the player side.
- **Line of sight** skips past allies: `hasLineOfSight` steps `LINE_OF_SIGHT_ALLY_STEP` = 2.5 studs past anything with a Humanoid in its ancestry, up to `LINE_OF_SIGHT_MAX_ALLY_SKIPS` = 8; walls still block. Bullets themselves still stop on an ally.
- **Stun.** `ShotResolver` stamps `StunnedUntil`; EnemyAI sets `WalkSpeed = 0`, cancels movement and fire loop once, and restarts an automatic weapon's fire loop when the stun lifts. The baton stun is also a 1 s ragdoll stagger ([[Ragdoll]], [[Melee]]).
- **Rewards.** A kill has a 30% chance to drop a physical cash pickup scaled by the enemy's weapon tier ([[Economy and Cash]]); quest credit comes from the spawn-kind tag ([[Quests and Dialogue]]).

## Extend it
- New enemy type: clone a template in `ServerStorage.EnemyTemplates`, **clear every attribute the donor carried** before setting new ones (a Saboteur built from Disrupters would otherwise keep AKM recoil/aim), set `DamageOverride` (and `EngageRangeFraction` for melee), add a `<Type>Spawner` with an `EnemyType` StringValue in `Workspace.EnemySpawns`, and point a quest at it in `QuestConfig`.
- Anything that must run on an enemy goes on after spawn (like `EnemyGUI`), never in the template.
- Population and pacing are the three constants above; tune there, not per point.

## Watch out
- Scripts in a template never run: the spawner strips them.
- In `EnemyGUI` the label `Name` and the script `Text` collide with built-in properties; the scripts deliberately never index them by name. Keep it that way.
- A Tool's geometry sits in its own Model inside the Tool: one `Parent` hop from a hit part does not reach the character. Always use `findOwningHumanoid`.
- Cash/XP tier comes from the weapon's firing mode; there is no shotgun tier, so Smuggler and Bandits pay at pistol rate (accepted).
- An enemy now fires with an ally in its line; the ally absorbs the shot without damage. If that reads badly, add a "don't fire through an ally" check in `_tryFire`, not a change to line of sight.
- `CLAUDE.md`'s instance tree still lists `StandardEnemy`; it was removed on 2026-09-11.
- The enforcement spawn positions were recorded before deletion (2026-09-17) in case the Robbery place wants them; where they were recorded is not stated.
- A staging folder of downloaded outfit assets was left in `ServerStorage` (2026-09-16), to remove once outfits were seen on spawned enemies; whether it was removed is not recorded.

## History
- 2026-09-24: overhead health bar gains a white Health icon; kill toast names the enemy from `EnemyTemplate`. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]] [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- 2026-09-22: per-type cap 10 -> 5 (60 -> 30 alive, plateau measured); missed-shot tracers capped at 150 studs. [[FPS-Miss-Tracers-And-Spawn-Cap]]
- 2026-09-21: ally bodies and carried guns no longer block enemy line of sight; carried weapons no longer absorb hits; guard Baton gets `stunDuration` 1 s. [[FPS-Clustered-Enemies-Stop-Attacking]] [[FPS-Carried-Weapons-Absorbed-Hits]] [[FPS-Baton-Stun-Becomes-A-Stagger]]
- 2026-09-19: 22-stud scatter, top-up 1 -> 2.5 s; `EnemyCharacter` collision group stops rigs climbing each other (rise 365 studs -> 0.3). [[Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip]] [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]
- 2026-09-17: roster becomes criminal-only (Offender, Disrupters, Smuggler, Bandits, Saboteur); cap per type. Search turns once; dead targets are dropped. [[FPS-Enemy-Roster-Rework-3-New-Recruits]] [[FPS-Enemy-Search-State-Spin-Fix]]
- 2026-09-16: six types dressed (three garments unsourced); `EnemyGUI` on every enemy. [[FPS-Enemy-Marketplace-Outfits]] [[FPS-Enemy-Overhead-GUI-Integration]]
- 2026-09-15: stunned enemies resume automatic fire. [[FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes]]
- 2026-09-12: per-enemy recoil override for the two rifle types. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: six types with dedicated spawners; `StringValue` spawn tags; damage to 20%, enemy recoil; rifle rebalance, `StandardEnemy`/`HeavyEnemy` removed; enemy melee swing delay; 30% tiered cash drops. [[FPS-Enemy-AI-6-Types]] [[FPS-Spawner-Rework-Enemy-Nerf-Death-Inventory]] [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]] [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]] [[FPS-Billboard-Scale-And-Cash-Drop-System]]

See [[Batch Log]].
