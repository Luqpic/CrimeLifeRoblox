---
type: system
tags: [system, enemies, npc-ai, fps]
updated: 2026-11-20
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "70 Batches/2026-11-17 Police and Wanted.md", "CLAUDE.md (Instance tree, Systems)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-AI-6-Types.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Miss-Tracers-And-Spawn-Cap.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Clustered-Enemies-Stop-Attacking.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Enemy-AI-6-Types.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-1-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-1-review.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Enemies and Spawner

**Skills:** `roblox-npc-ai`, `roblox-physics`, `roblox-game-systems` (load these for work here)

In the FPS place and, since 2026-11-15, in the city (an exact copy; see "In the city").

## What it does
Keeps a criminal-side enemy population alive around the map: each spawn point tops up its own enemy type to a per-type cap, the AI patrols, detects, chases, shoots or swings, searches when it loses a living target, and reacts to stun. Kills feed quests, leveling, cash drops and the kill toast.

## Where it lives
- `ServerScriptService.Enemy.Scripts.EnemySpawner`, `ServerScriptService.Enemy.Scripts.EnemyAI`, `ServerScriptService.Enemy.Scripts.EnemyRig` (city, 2026-11-17: `build` and `place`, the rig half of the spawner, shared with the police dispatcher).
- `ReplicatedStorage.Enemy.Constants` (`MAX_CONCURRENT_ENEMIES_PER_TYPE`, recoil-decay constants, `ALLY_SIDESTEP` 4), `ReplicatedStorage.Enemy.AimConfig`, `ReplicatedStorage.Enemy.templateConfig` (per-type accuracy ceiling and recoil overrides).
- `ServerStorage.EnemyTemplates.*`: nine rigs (see below), each with its weapon Tool inside.
- `Workspace.EnemySpawns`: six `<Type>Spawner` parts, each with an `EnemyType` `StringValue` child.
- `ReplicatedStorage.GuiTemplates.EnemyGUI`: the overhead name and health display, attached at spawn.
- Hit resolution and line of sight: `ServerScriptService.Blaster.Scripts.ShotResolver`, `ReplicatedStorage.Blaster.Utility.findOwningHumanoid` / `castRays` (see [[Weapons and Blaster]]).

## How it works
- **Roster (as of 2026-09-17).** Spawning, all criminal-side: Thug (Crowbar), Offender (was Criminal), Disrupters (was Armed Criminal, AKM), Smuggler (PB pistol), Bandits (Mossberg 590), Saboteur (FN P-90). Kept but not spawning from `EnemySpawns`: Security (Baton), Police, Armed Police; their outfits dress the quest givers ([[Quests and Dialogue]]). In the city since 2026-11-17 Police and Armed Police spawn from the police dispatcher for wanted players only ([[Police and Wanted]]). Health, speed and accuracy of the three newest are placeholders on the difficulty curve, not balance.
- **Spawner.** A spawn point is considered only while its own type is below `MAX_CONCURRENT_ENEMIES_PER_TYPE` = 5 (six points, so 30 alive at most). Top-up every `TOP_UP_INTERVAL` = 2.5 s. A rig is placed at a random offset within `SPAWN_SCATTER_RADIUS` = 22 studs, radius sampled through a square root so the disc fills evenly. Rigs go into the `EnemyCharacter` collision group, which does not collide with itself (still collides with world and players; weapon raycasts unaffected).
- Every spawned rig is renamed `Enemy`, keeps its type in the `EnemyTemplate` attribute (shown on the kill toast and nameplate), and has **all its scripts destroyed on spawn**. `EnemyGUI` is attached afterwards for that reason. Roblox's own name/health display is off on all templates.
- **Damage and aim.** Each template carries `DamageOverride` (set to 20% of its weapon's stock damage on 2026-09-11; the shared config otherwise forces a debug value of 3). Melee types carry `EngageRangeFraction`. Ranged enemies accumulate and decay recoil from their weapon's own recoil attributes; Armed Police / Armed Criminal (now Disrupters) have extra accuracy-ceiling and recoil overrides.
- **AI states.** Patrol, Chase, Attack, Search; it reconsiders four times a second. Losing a living target: go to last-seen spot, turn once (about 50 degrees), then hold. A dead target ends pursuit on the spot and returns to Patrol. Melee damage waits for the swing delay, matching the player side.
- **Line of sight** skips past allies: `hasLineOfSight` steps `LINE_OF_SIGHT_ALLY_STEP` = 2.5 studs past anything with a Humanoid in its ancestry, up to `LINE_OF_SIGHT_MAX_ALLY_SKIPS` = 8; walls still block. Bullets themselves still stop on an ally.
- **Ally in the line (2026-11-18).** `EnemyAI:_allyInLine(from, to, target)` runs in `_fireOnce` after the muzzle line-of-sight check: one cast at the bullet's own `rayRadius` from the muzzle to the aim point, with the shot's `castRays`. If the first hit is a humanoid that is not the target and that this shooter cannot damage (another enemy, police, a Witness or Invulnerable NPC), the shot is held and the ally's position and time are recorded. While an ally was in the line within the last two thinks, `_thinkAttack` calls `_sidestep` (a `MoveTo` to a point `ALLY_SIDESTEP` 4 across the line, on the side away from the ally) instead of stopping or following. Melee is exempt (a swing fans its rays, and a ring of melee enemies is the 2026-09-21 case). `hasLineOfSight` is unchanged. Police use the same path.
- **Stun.** `ShotResolver` stamps `StunnedUntil`; EnemyAI sets `WalkSpeed = 0`, cancels movement and fire loop once, and restarts an automatic weapon's fire loop when the stun lifts. The baton stun is also a 1 s ragdoll stagger ([[Ragdoll]], [[Melee]]).
- **Rewards.** A kill has a 30% chance to drop a physical cash pickup scaled by the enemy's weapon tier ([[Economy and Cash]]); quest credit comes from the spawn-kind tag ([[Quests and Dialogue]]).

## In the city
Measured 2026-11-15 for placing the six points in Crimelife City ([[2026-11-15 FPS Systems Into City]]):
- A spawn point is a `Part` (4 by 1 by 4, anchored, `CanCollide` false) in `Workspace.EnemySpawns` with tag `EnemySpawnPoint` and one child, a `StringValue` named `EnemyType`. No attributes.
- `EnemySpawner` reads `point.Position` on every spawn and ignores orientation; the rig appears at the position plus a random scatter within 22 studs, plus 3 studs up. A point is skipped while any living player is within 60 studs. Cap 5 alive per type, top-up every 2.5 s.
- The AI patrols to random points within 70 studs of the spawn point's position at spawn time, with `PathfindingService` (agent radius 2, height 5, can jump); an unreachable target fails and is retried. So a point needs walkable ground for about 22 studs and ideally 70 around it, and must not sit where a patrol reaches a plot or a quest giver.
- Where the six points stand now: [[City Map and Plots]]. The positions are provisional. In the run from the city spawn all 30 enemies came up (5 per type) and 5 of 6 types moved; one Thug stuck at about (215, 5, 2485) against `Building_15`.

## Police on the AI (city, 2026-11-17)
[[2026-11-17 Police and Wanted]]. The gangs pass none of these, so their code path is unchanged (measured: 30 alive, 5 per type, 0 with a filter, in every Play of the closing run).
- `EnemyAI.new(..., config)` takes `config.targetFilter(player): boolean` (consulted in `_findVisibleTarget`, `_targetHumanoid` and `onDamagedBy`: a refused target is dropped mid-fight and an unwanted shooter is not retaliated against) and `config.preferTarget` (a player chosen over the nearest when visible).
- `EnemyAI:canSee(character)` (strict boolean, the AI's own `hasLineOfSight` from the eyes), `EnemyAI:investigate(position)` (Patrol and Search only; the AI's own Chase wins on sight), `EnemyAI.getLive()` (live instances, from `activeEnemies`), `EnemyAI._players()` (a test seam).
- `EnemyRig.build(template, label)` and `EnemyRig.place(character, weapon, cframe, parent)` are the old `trySpawn` body, moved verbatim; the spawner keeps its points, caps and counts. Police are built with the same two calls into `Workspace.Police`.
- `CityMergeDeviation` on `EnemyAI` and `EnemySpawner`; rows in `CityMerge/after-import.md`.

## Extend it
- New enemy type: clone a template in `ServerStorage.EnemyTemplates`, **clear every attribute the donor carried** before setting new ones (a Saboteur built from Disrupters would otherwise keep AKM recoil/aim), set `DamageOverride` (and `EngageRangeFraction` for melee), add a `<Type>Spawner` with an `EnemyType` StringValue in `Workspace.EnemySpawns`, and point a quest at it in `QuestConfig`.
- Anything that must run on an enemy goes on after spawn (like `EnemyGUI`), never in the template.
- Population and pacing are the three constants above; tune there, not per point.

## Watch out
- Scripts in a template never run: the spawner strips them.
- In `EnemyGUI` the label `Name` and the script `Text` collide with built-in properties; the scripts deliberately never index them by name. Keep it that way.
- A Tool's geometry sits in its own Model inside the Tool: one `Parent` hop from a hit part does not reach the character. Always use `findOwningHumanoid`.
- Cash/XP tier comes from the weapon's firing mode; there is no shotgun tier, so Smuggler and Bandits pay at pistol rate (accepted).
- An enemy no longer fires through an ally (2026-11-18): it holds the shot and sidesteps. Measured, a back enemy 35 studs out behind a front enemy at 20 (Disrupters, AKM, 15 s): before 89 shots, 58 into the ally, 0 on the target; after 84 shots, 0 into the ally, 19 on the target, 9.1 studs sidestepped. Police (Mateba): 16 of 18 shots into the ally before, 1 after. A ring of 6 Offenders at 8 studs: 4 of 6 hitting before, 6 of 6 after; 7 Thugs at 3 studs (melee) all still hitting. Still true: `_sidestep` has no ledge or wall check and its extra ray per shot is unmeasured, and `allyInLine` is not cleared when the target changes.
- Armed Police may not fire when standing idle on flat ground: the Scar L muzzle is about 1.5 studs under the floor ([[Police and Wanted]]).
- `CLAUDE.md`'s instance tree still lists `StandardEnemy`; it was removed on 2026-09-11.
- The enforcement spawn positions were recorded before deletion (2026-09-17) in case the Robbery place wants them; where they were recorded is not stated.
- The staging folder of downloaded outfit assets (`ServerStorage.EnemyOutfitStaging`, 2026-09-16) does not exist in the city: searched in every service by exact name and by "outfitstaging" on 2026-11-18, nothing found, nothing moved. `ServerStorage.CityQuarantine.LooseTycoon` and `CityQuarantine.WorkspaceHQ` hold tycoon display outfits, a different thing.
- The three newest types as measured on 2026-11-18 (placeholders, not changed): Smuggler MaxHealth 85, WalkSpeed 11, ChaseSpeed 17, DetectionRadius 95, DamageOverride 4, weapon PB (semi, 480 rpm, range 650); Bandits 100, 12, 19, 110, 3, Mossberg 590 (8 pellets, spread 9, range 550); Saboteur 130, 12, 21, 150, 2, FN P-90 (auto, 850 rpm, range 1000). All three have PreferredRangeFraction 0.6 and Faction Criminal.

## History
- 2026-11-20: the admin panel spawns non-police enemy types (1 to 6, no spawner accounting) and clears them (CLEAR MINE for admin-spawned, CLEAR ALL with `EnemyAI.getLive()` kills with `Health = 0` so the spawner refilled 30 live within 10 s; the spawner's accounting stayed intact). [[Admin Panel]] [[2026-11-20 Admin Animations Third Person]]
- 2026-11-18: enemies hold a shot with an ally in the line and sidestep (`_allyInLine`, `_sidestep`, `ALLY_SIDESTEP` 4; melee exempt); the outfit staging folder does not exist in the city. Tests: Play measurements only, no unit spec. [[2026-11-18 Open Items Pass]]
- 2026-11-17: the Thug that stood stuck at the east road end did not reproduce (185 s Play, five Thugs sampled every 10 s, none within 2 studs for 30 s); no change, because every other point breaks a placement rule. [[2026-11-17 Known Issues Pass]]
- 2026-11-17 (city): target filter, preferred target, `canSee`, `investigate`, `getLive` on `EnemyAI`; `EnemyRig` extracted; Police and Armed Police spawn for wanted players. [[2026-11-17 Police and Wanted]]
- 2026-11-15: ported into the city as an exact copy; the six points moved onto the city's roads. [[2026-11-15 FPS Systems Into City]]
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
