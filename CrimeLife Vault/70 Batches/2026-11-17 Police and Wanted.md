---
type: batch
tags: [batch, city, police, wanted, npc-ai, heists, hud, quests]
updated: 2026-11-17
sources: [".superpowers/sdd/2026-11-17-police-and-wanted/progress.md", ".superpowers/sdd/2026-11-17-police-and-wanted/task-1-report.md to task-6-report.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-11-17-police-and-wanted-design.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-11-17-police-and-wanted.md", "CrimeLifeRoblox/CityMerge/police/final-run.md", "CrimeLifeRoblox/CityMerge/after-import.md"]
---

# 2026-11-17 Police and Wanted

Place: `Crimelife city.rbxl` (Edit and Play; the only Studio window, resolved by name before every write). Design `docs/superpowers/specs/2026-11-17-police-and-wanted-design.md` (`1d8eb20`, section 9 added in `1ef7ed9`); plan `docs/superpowers/plans/2026-11-17-police-and-wanted.md` (`97fbfaf`). Ledger with every ruling: `.superpowers/sdd/2026-11-17-police-and-wanted/progress.md`. Commits `a5afcef..57ae7dc` (`a5afcef`, `f7187e4`, `eff6266`, `bb713d6`, `f293f9d`, `91d52a9`, `f434cd2`, `39418cc`, `ce22c96`, `5d6949d`, `61da3aa`, `57ae7dc`), then this note's commit.

## Asked for

The heists had no threat beyond the Bank's guards and the timer. The developer chose the shape in a question round ("A criminal; givers go rogue", "Heist alarms", "Shooting police", "Crimes in public", "Escalate in stars", "Die, lose the haul", "Break sight, then cool down", "No, you still have to escape", and the guards and police at the robberies in their own words, [[CrimeLife Tycoon Decisions]]), then approved the design and asked for it built overnight: "Looks right, write the design. And apply it until the end as I will sleep now". No word on saving, so the place was not saved.

## What changed

**Task 1: heat and alarms** (`a5afcef`, `f7187e4`). `ReplicatedStorage.Wanted.Constants` (every number), pure `HeatModel`, `ServerScriptService.Wanted.WantedService` and `WantedRunner` (2 Hz drain), `Blaster.Events.Damaged` fired by `ShotResolver` for a `Player` shooter. Alarm hooks in `LocationServer` and `HeistServer` (`WantedService.onAlarm`). Review fix: a Knife's bleed ticks fired `Damaged` each, so one stab could reach 2 stars; the ticks no longer fire it, and events from a dead or departed attacker are ignored.

**Task 2: police squads on the enemy AI** (`eff6266`, `bb713d6`, `f293f9d`). `EnemyAI` gains `targetFilter`, `preferTarget`, `canSee`, `investigate`, `getLive`; `EnemyRig` extracted from `EnemySpawner`; pure `SquadPlan`; `PoliceDispatcher` (squads by stars, spawn rings, spawn validator: not in a plot or robbery building, on road or footpath, out of sight, reachable; leavers). The first Play showed a design defect: police spawn out of sight, so the 1-star robber drained to 0 at 8 s, long before the first officer arrived at 34 s. Design section 9 fixed it: an active robbery counts as seen, a 20 s search window follows any rise, officers head for the believed position; then the robbery bypass was limited to the building and `EscapeDistance` through `Getaway:IsNear`. Review fixes also dropped the baseplate as road ground, made glass and poles not hide an officer, and stopped leaving officers counting as "seen".

**Task 3: witnesses and NewsStation guards** (`91d52a9`, `f434cd2`, `39418cc`). `Wanted.Sight` (the one sight probe), `Wanted.Witnesses`; `Witness` tags on the heist civilians and `GuardTemplate`; 3 always-posted NewsStation guards on a generalised `GuardPost`. Guard damage was 0 (from the Robbery place); 12 made the Bank deadly in 2.3 s; settled at 6 per shot. Guards shoot only robbers and wanted players; posted guards respawn after 60 s.

**Task 4: the star meter** (`ce22c96`, `5d6949d`). `WantedHud`: five text-glyph stars on a `UITheme` plate, pulse while seen, blink while draining, hidden at 0 and behind panels; 0 overlaps measured at 1080 x 659. `WantedSeen` and `WantedDraining` attributes from `WantedService`. Review fixes: a nil `CurrentCamera` at start, the fill mapped to the glyph's ink, `WantedDraining` false at once on a rise.

**Task 5: the givers become crooked cops** (`61da3aa`, `57ae7dc`). The lines live in `QuestDialogueController`, not `QuestConfig` (a deviation from the design's guess); one shared set; ranked nameplates `OFC. DOYLE` to `CHIEF HARLAN` ([[Quests and Dialogue]]).

**Task 6: closing run and this record.** No code changed. `CityMerge/police/final-run.md`: the loop, the load, five Plays and both suites; the vault updated.

## Decisions

The developer's words and Claude's calls with their costs are in [[CrimeLife Tycoon Decisions]] under 2026-11-17 ("police and the wanted level"). The design's own calls (numbers, crooked cops) are open to correction.

## Verified

From `CityMerge/police/final-run.md`, all 2026-11-17:
- **The loop, in one Play:** SlowFoods alarm, 1 star, 2 police at the door; one register robbed through its prompt; banked at 201 studs while seen: `leaderstats.Cash` 500 to 2,500 once, the star stayed (seen at every distance from inside to 205). Out of sight behind a rise 275 studs away: draining from +5.5 s, heat 0 and both officers gone at +8.0 s (an open-road spot 195 studs away was no escape: they walked up and saw the robber). Gas2Go robbed, then killed by the police while wanted: `Forfeit` "forfeited 2000 (died)", heat 0 and police 0 1.5 s later, cash unchanged. Bank alarm: 3 stars, 4 Police + 2 Armed. NewsStation alarm: 2 stars, 3 guards, hits of 6 about every second from the guard in sight; 4 police by about 32 s.
- **Knife stab on an officer** (Task 1's unpinned item): one `Shoot` through the real remote, heat 2.00 to 2.25, five bleed ticks of 4 on the officer, no further heat.
- **Load (Solo, one player at 5 stars):** police alive sampled every second for 125 s: min 10, max 10, never above 24 (the 24 cap with several players is proven by `SquadPlan_Test` only). Client `Heartbeat` 16.92 ms with no police, 16.89 ms with 10; about 300 client descendants per officer (3,002 under `Workspace.Police`); Studio process memory 10,007 to 10,067 MB, `LuaHeap` 1,083 to 1,088 MB. Server `Heartbeat` 16.92 ms, physics 60. After the clear the unprotected player took no damage in 49 s and the 10 officers were gone by then.
- **Five Plays from the city spawn, not wanted:** 0 client non-asset lines; 3 server lines, all from `Workspace.HQ` (the same in every Play); PlayerGui 29, PlayerScripts 34 (each +1: `WantedHud`); 0 police, heat 0; 6 quest givers with prompts; 1 enabled `SpawnLocation`. Gangs as before: 30 alive at 70.9 s, 5 per type, none with a `targetFilter` or `preferTarget`.
- **Suites (Play 5):** city 251 / 251 / 0; heist 620 passed, 1 failed (the `Zone` sweep timing, 3.17 ms).
- Every build task was reviewed against the live place and approved.
- Final state in Edit: 1 enabled `SpawnLocation`, no `Workspace.Police`, no temporary object.

## Not verified

- Anything with two players (Solo only): the shared 24 cap, a second robber, squad preference, bystanders at a guard.
- A phone: frame time and memory with police; the meter at 844 x 390 live.
- Render frame time: the Studio viewport read 1 x 1 during the load run (`RenderStepped` 0 frames); only `Heartbeat` was measured. Memory is the Studio process's, not a device's.
- How the chase and the shooting feel; a real conversation with a crooked cop; the meter on screen this run.
- The vault path for police at the Bank; police kill rewards and the saved `PoliceKills` counter.
- The Bank-to-NewsStation step used a forced death (`Health = 0`), not a police kill; the robber's survival during the chase used an invisible `ForceField`.

## Left open

All in [[Open Items]] under "Police and the wanted level (2026-11-17)": saving the place, the numbers to tune, the Bank guards' lethality, the checks that need a person, police waiting at the SlowFoods door, the live-position chase in the search window, the slow NewsStation squad, and every deferred minor from the ledger. New engine trap: a plugin-context `execute_luau` holds its own module copies ([[Luau and Scripting Traps]]).

## Links

[[Police and Wanted]] · [[Enemies and Spawner]] · [[Robbery Heists and Getaway]] · [[Quests and Dialogue]] · [[HUD and UI Shell]] · [[Melee]] · [[Luau and Scripting Traps]] · [[CrimeLife Tycoon Decisions]] · [[2026-11-16 Robbery Systems Into City]] · [[Open Items]] · [[Batch Log]]

NOT saved: the developer gave no word to save this run; every script is exported to `CityScripts/` and committed. NOT published.
