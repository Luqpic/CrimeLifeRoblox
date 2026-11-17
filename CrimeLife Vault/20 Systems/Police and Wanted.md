---
type: system
tags: [system, police, wanted, npc-ai, heists, hud]
updated: 2026-11-17
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "70 Batches/2026-11-17 Police and Wanted.md", "70 Batches/2026-11-17 Police Slow Fill.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-11-17-police-and-wanted-design.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-11-17-police-and-wanted.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-17-police-and-wanted/progress.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-17-police-and-wanted/task-1-report.md to task-6-report.md", "CrimeLifeRoblox/CityMerge/police/final-run.md", "CrimeLifeRoblox/CityScripts/ReplicatedStorage.Wanted.Constants.luau"]
---

# Police and Wanted

**Skills:** `roblox-npc-ai`, `roblox-game-systems`, `roblox-physics` (load these for work here; add `roblox-ui` for the meter)

Crimelife City only, since 2026-11-17 ([[2026-11-17 Police and Wanted]]).

## What it does
Each player has a wanted level of 0 to 5 stars. Heist alarms, hurting police and crimes a witness sees raise it. Police exist only for wanted players: a squad sized by stars spawns out of sight, heads for the robbery or the player, and fights to kill. Armed Police join from 3 stars. Break every officer's (and guard's) sight and the stars drain one at a time; death clears them and drops the haul; banking does not. The Bank and NewsStation have stationed guards. A star meter shows the level. The six quest givers are now crooked cops ([[Quests and Dialogue]]).

## Where it lives
- `ReplicatedStorage.Wanted.Constants`: every number below, nowhere else. `ReplicatedStorage.Wanted.HeatModel` (pure: `raise`, `atLeast`, `stars`, `drainStep`), `ReplicatedStorage.Wanted.SquadPlan` (pure: `target`, `allocate`).
- `ServerScriptService.Wanted.WantedService` (ModuleScript; heat, attributes, drain, listeners) and `WantedRunner` (Script: `start()`, `PoliceDispatcher.start()`, `_step` every 0.5 s under `pcall`).
- `ServerScriptService.Wanted.PoliceDispatcher` (squads, spawn points, `isSeen`, leaving), `Wanted.Sight` (the one line-of-sight probe), `Wanted.Witnesses` (`sees`, `guardSees`).
- `ServerScriptService.Blaster.Events.Damaged` (BindableEvent, fired by `ShotResolver` for a `Player` shooter), beside the existing `Eliminated`.
- `ServerScriptService.Enemy.Scripts.EnemyAI` (`config.targetFilter`, `config.preferTarget`, `canSee`, `investigate`, `getLive`) and `Enemy.Scripts.EnemyRig` (`build`, `place`, extracted from `EnemySpawner`) ([[Enemies and Spawner]]).
- Police templates: `ServerStorage.EnemyTemplates.Police` and `Armed Police`; spawned officers live in `Workspace.Police` (made at the first spawn).
- Alarm hooks: `Heist.Services.LocationServer:TryTriggerRobbery` and `HeistServer.tryTriggerRobbery` call `WantedService.onAlarm`; both register an "active robbery near the building" check through `Getaway:IsNear` ([[Robbery Heists and Getaway]]).
- Guards: `Heist.Components.GuardPost` (generalised), `ServerStorage.GuardTemplate` (tag `Witness`, attribute `WitnessRole = "Guard"`), `Workspace.NewsStationMarkers.GuardPost1..3`.
- Witness tag `Witness` on `HeistShared.ModelTemplates.BankClerk`, `RestaurantShared.ModelTemplates.Cashier`, `NewsStationShared.ModelTemplates.NewsWorker`, `GuardTemplate` and every spawned officer. Since 2026-11-17 the NewsWorker is also `Invulnerable` (as the Cashier and Bank Clerk already were), so no civilian in a heist can be hurt by a player: the "hurting a witness" heat (+0.25) comes from guards only.
- Client: `StarterPlayer.StarterPlayerScripts.WantedHud` builds the `WantedHud` ScreenGui ([[HUD and UI Shell]]).
- NPC-vs-NPC damage rule: `ReplicatedStorage.Blaster.Utility.canDamageHumanoid` (`Witness` clause, final review).
- Tests (`ServerStorage.UnitTest.Cases`): `HeatModel_Test`, `WantedService_Test`, `SquadPlan_Test`, `EnemyTargetFilter_Test`, `PoliceSpawnPoint_Test`, `Witnesses_Test`; heist `GuardSpec`, `WorldSpec`.
- Exports: `CityScripts/` (`ReplicatedStorage.Wanted.*`, `ServerScriptService.Wanted.*`, `StarterPlayer.StarterPlayerScripts.WantedHud.luau`); deviation rows in `CityMerge/after-import.md` ("Police and wanted 2026-11-17").

## How it works (numbers from `Constants`, 2026-11-17)
- **Heat.** A number 0 to `MAX_HEAT` 5, replicated as player attributes `WantedHeat` and `WantedStars` (= floor). Not saved; leaving clears it.
- **Alarms** set heat to at least `ALARM_LEVELS`: Gas2Go 1, SlowFoods 1, NewsStation 2, Bank 3, for every participant at the trigger (the Bank: `bank:GetParticipants()` plus the trigger player, who may not be enrolled yet).
- **Police hits:** `POLICE_HIT_HEAT` 0.25 per hit, `POLICE_KILL_HEAT` 1 per kill (a killing hit gives both, 1.25). Hits on one officer by one player within `HIT_MERGE_WINDOW` 0.1 s count once (a shotgun blast or a swing is one hit). Bleed ticks fire no `Damaged` (measured: one Knife stab +0.25, five ticks +0). A dead or departed attacker's events are ignored.
- **Crimes in public:** a kill of any NPC +`PUBLIC_KILL_HEAT` 0.5, hurting a `Witness`-tagged NPC +`PUBLIC_HURT_HEAT` 0.25, only when a witness within `WITNESS_RANGE` 120 has line of sight to the attacker. The victim is never its own witness. A player who has left (`Parent` not `Players`) gets no heat and is dropped at the next step. Attacking a player gives nothing; NPC weapons and heist hazards give nothing.
- **Seen.** `WantedSeen` is true while any live, non-leaving officer, or any guard, within `SEEN_RANGE` 150 has line of sight (`Sight.inSight`: legs, root, head and ±`SIGHT_PROBE_SIDE` 1.5 across; parts with transparency >= `SEE_THROUGH_TRANSPARENCY` 0.3 do not block), or while the player is a participant of an active robbery and still in the building or within its `EscapeDistance` of the anchor.
- **Drain.** After any rise in heat a search window of `SEARCH_SECONDS` 20 must pass; then, unseen for `DRAIN_INTERVAL` 8 s, heat drops one step (to the integer below, or minus 1), and again every 8 s. Being seen restarts the 8 s. Checked at `SEEN_CHECK_HZ` 2. `WantedDraining` is true while the unseen timer runs. Death clears to 0.
- **Squads** (`SQUAD_BY_STARS`): 1 star 2 Police; 2 stars 4; 3 stars 4 + 2 Armed; 4 stars 4 + 4; 5 stars 4 + 6. Armed from `ARMED_FROM_STARS` 3. Server cap `POLICE_CAP` 24, shared highest stars first. Top-up every `TOPUP_INTERVAL` 5 s (and at once after an alarm); the dispatcher ticks every `DISPATCH_TICK` 1 s. When stars fall, officers above the new target leave by the leave path at the next tick, per kind, Armed Police first (`SquadPlan.surplus`; measured: 5 -> 2 stars, the 6 Armed left and were gone in 7.5 s, 4 Police stayed).
- **Spawn points.** After an alarm: a ring `ALARM_RING_MIN` 60 to `ALARM_RING_MAX` 120 studs around the location's `StatusBillboardAnchor`; otherwise, and as the fallback, `TOPUP_RING_MIN` 90 to `TOPUP_RING_MAX` 160 around the player. A point must be off the plots and robbery buildings, on road or footpath ground within `GROUND_PROBE` 5 below (stood `SPAWN_HEIGHT` 3 above), out of the player's sight, and reachable by path (`POLICE_AGENT`) to the player or, inside a building, to its `*ExitSpawn`. A search samples up to `SPAWN_SAMPLES` 2,000 points (yielding every 50); the cheap checks (boxes, ground, sight) are free, and the path checks share `SPAWN_PATH_BUDGET` 20 `ComputeAsync` calls per player per round. A round stops at the first search that finds nothing, and an alarm ring that missed is not searched again that round. Measured at the city spawn plaza: 4 in 3,000 samples pass, and 10 officers arrive within 5 s ([[2026-11-17 Police Slow Fill]]).
- **Behaviour.** Officers run the gang `EnemyAI` with `targetFilter` = `WantedStars >= 1` (refused mid-fight drops the target; no retaliation on an unwanted shooter) and `preferTarget` = their squad's player. While the police know where the player is (robbery active near the building, or the search window) they `investigate` the player's position; after that the last spot an officer or guard saw them. A squad whose player is cleared, dead or gone takes another wanted player it can see or leaves: refuse-all filter, patrol `LEAVE_DISTANCE` 200 away, despawn when no player sees it or after `LEAVE_TIMEOUT` 60 s.
- **Guards.** Bank 4 (only during a session, as before); NewsStation `NEWSSTATION_GUARDS` 3 always posted, respawn at their post 60 s after a death outside a session. Both shoot only that robbery's participants and players with 1+ star; `GuardDamage` 6 per shot every 0.9 s. Guards count as witnesses and for "seen". Guards are anchored at their posts and never move. NPC fire (police, gangs, guards) never damages a `Witness`-tagged model (`canDamageHumanoid`): a police volley through a guard leaves it untouched, so `GuardsCleared` needs player kills; players still damage guards and police.
- **Meter.** Five text-glyph stars (U+2605) on a `UITheme` plate, 148 x 36, top centre beside the heist column (right of it on desktop, left of it when the smaller viewport side is under 500); each star clipped by its fraction over the glyph's ink; red pulsing stroke while seen, the next star blinks while draining; hidden at 0 and while a `UI.Panels` panel is open.
- **Kills** of police pay as any enemy (XP, 30 % cash drop) and count on the saved `PoliceKills` (by design, through the existing enemy reward path; not measured in this batch).

Measured end to end on 2026-11-17 (`CityMerge/police/final-run.md`): SlowFoods 1 star, 2 police; banked at 201 studs while seen, cash once, the star stayed; out of sight behind a rise, 0 at 8.0 s and the police gone at the same sample; died while wanted at Gas2Go, 2,000 forfeited, heat 0; Bank 3 stars, 4 + 2; NewsStation 2 stars, guards 6 hp a second; 10 police held for 125 s, never more.

## Extend it
- Tune by number in `Constants` only (heat amounts, drain, squad table, rings, cap). Guard damage and rate are per location Config (`HeistShared.Config`, `NewsStationShared.Config`).
- A new robbery location: add its name to `ALARM_LEVELS`, make it call `WantedService.onAlarm` where it announces `NotifyRobberyTriggered`, register its active-robbery check with `addActiveRobbery` through `Getaway:IsNear`, and add its building and zones to the dispatcher's robbery boxes.
- A new witness: tag the template `Witness` (guards also `WitnessRole = "Guard"`).
- A new police type: a template in `ServerStorage.EnemyTemplates`, a key in `POLICE_TEMPLATES`, a column in `SQUAD_BY_STARS`.

## Watch out
- **An `execute_luau` `require` gets its own module copy.** Heat set through it shows on the meter (same attributes) but never drains or dispatches. Drive heat through the game's paths or a temporary server Script ([[Luau and Scripting Traps]]).
- Police wait at the SlowFoods door: its interior is off the navmesh. They engage when the robber comes out.
- During the 20 s search window police follow the player's live position, across the map if need be.
- Open road is not an escape: officers walk to the last spot they saw you and see you again. Break sight behind a building or a rise.
- At NewsStation the full 2-star squad took about 32 s (3 of 4 at 18 s): spawn points around it are scarce.
- The cap, squads sharing it and every multi-player rule are proven by tests only (Solo has one player).
- Bank participants who join after the trigger get no alarm heat.
- A reset after banking clears the wanted level (it is a death); open for the developer ([[Open Items]]).
- Building a full round of 10 officers makes one server step of about 120 ms.

## History
- 2026-11-17: NewsWorker tagged `Invulnerable` (it keeps `Witness`): witnessed-hurt heat now comes from guards only. [[2026-11-17 Known Issues Pass]]
- 2026-11-17: built in six tasks: heat and alarms; police squads on the enemy AI; witnesses and NewsStation guards; the star meter; the quest givers become crooked cops; closing run. [[2026-11-17 Police and Wanted]]
- 2026-11-17: the slow fill fixed: many cheap samples, a per-round path-check budget. [[2026-11-17 Police Slow Fill]]
- 2026-11-17, final review fixes: the top-up stops at the first failed spawn search; a hurt victim is not its own witness; NPC fire spares `Witness` NPCs (`ReplicatedStorage.Blaster.Utility.canDamageHumanoid`, a deviation); squads shrink to the new star target, Armed first; departed players get no heat. [[2026-11-17 Police and Wanted]]

See [[Batch Log]].
