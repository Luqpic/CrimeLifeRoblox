---
type: system
tags: [system, city, plots, streaming]
updated: 2026-11-16
sources: ["70 Batches/2026-11-15 FPS Systems Into City.md", "CrimeLifeRoblox/CityMerge/after-import.md", "CrimeLifeRoblox/CityMerge/placement.md", "CrimeLifeRoblox/CityCleanup/after-task5.md", "CrimeLifeRoblox/CityCleanup/after-task6.md", "CrimeLifeRoblox/CityCleanup/workspace-layout-plan.md", "70 Batches/2026-11-14 City Baseline and Cleanup.md"]
---

# City Map and Plots

## What it does

The Crimelife City map in `Crimelife city.rbxl`, cleaned to be the world of CrimeLife Tycoon: art only, six plots for the tycoon bases, streaming prepared for phones. Why and how: [[2026-11-14 City Baseline and Cleanup]]. The design it serves: `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`.

## Where it lives

`Workspace` had six children after the 2026-11-14 cleanup; since 2026-11-15 it has 13 (the table lists the six, then the seven added by [[2026-11-15 FPS Systems Into City]]; 168,624 descendants in Edit):

| Child | Holds |
|---|---|
| `Map` | `City` (25,554 instances), `Robbery` (6 buildings, 83,419), `Roads` (3), `Props` (147), `Loose` (213 unsorted pieces) |
| `Plots` | `Plot1` to `Plot8`, each one Lapis plate (300 by 1 by 361 studs) |
| `Ground` | the origin Baseplate |
| `SpawnLocation`, `Terrain`, `Camera` | unchanged. `SpawnLocation` at (-11, 1.5, 2498.75) is the only enabled spawn; it sits on a four-way road crossing |
| `TycoonPreview` | static preview of the tycoon building on `Plot3` (see below) |
| `Dev` | the FPS test area on the slab (see below) |
| `EnemySpawns`, `Quests`, `Targets`, `AnimVM`, `Accessory Storage` | imported from the FPS place, same names (scripts look them up by name). `EnemySpawns` and `Quests` now stand in the city (below); `Targets` (105 descendants) stays on the slab; `AnimVM` (the viewmodel container) and `Accessory Storage` are empty folders; what `Accessory Storage` is for is not recorded |

`ServerStorage.CityQuarantine` (does not replicate): `Scripts` (8 disabled lighting and time scripts), `Duplicates` (11 models), `LooseTycoon` (1,367 children), `StagingSlab` (103 children).

## The FPS port in the city (2026-11-15)

- **`Workspace.TycoonPreview`** (Model, 47,894 instances, 24,053 parts, all anchored, 23 scripts disabled with `QuarantinedScript = true`; attributes `Preview = true`, `PlotIndex = 3`, `SourceDelta = (564, -123, 1778)`, `ImportedFrom`): the assembled HQ building from `ServerStorage.HQ`, standing on `Plot3`. A **preview only**: not buyable, not the working tycoon. `ServerStorage.HQ` (58,282 descendants) is the untouched source for phases 4 and 5, with the kit's button data intact. Left out of the preview: `Bunker`, the `Fence` compound (370 by 370, the plate is 361 by 300), `Road`, `V1`, 20 stray block-out parts. The assembled building in the source is at x -686 to -473, z 128 to 438, ground floor top Y 124.
- **`Workspace.Dev`** (Folder, `ImportedFrom`): the FPS place's test area, still on the slab around the origin: `FpsMap` (the FPS `Map`, 23 instances), `UI`, `Part`, `Model`, and `DevSpawn` (the FPS `SpawnLocation`, **`Enabled = false`**). To test at the origin, enable `DevSpawn` and disable the city `SpawnLocation` (keep exactly one enabled), and put them back afterwards. `Dev` is a Folder, so it has no streaming mode; it streams out for a player at the city spawn, about 2,500 studs away.
- **The six enemy spawn points** (`EnemySpawns`, tag `EnemySpawnPoint`, child `StringValue` `EnemyType`) stand on the roads and footpaths west, east and +Z of the spawn: Thug (169, 1.5, 2498.75), Smuggler (-11, 1.5, 2678.75), Offender (-291, 2.5, 2498.75), Bandits (-11, 1.5, 2778.75), Disrupters (-351, 2.5, 2498.75), Saboteur (-411, 1.5, 2498.75): 180 to 400 studs from the spawn, weakest nearest. Rules and the full table: [[2026-11-15 FPS Systems Into City]].
- **The six quest givers** (`Quests`, `Level 1 Quest` to `Level 70 Quest`) stand on the sidewalk strip `Map.City.FootPaths.Part` at z 2477.5, pivot Y 2.0035, x from -44.89 to -114.89 (14 studs apart, 40 to 106 studs from the spawn), facing the spawn.
- **Attributes that mark the work:** `ImportedFrom = "FPS System"` is on every root brought over from the FPS place (and on `Dev` and `TycoonPreview`): find all of it by that attribute. `PlacedBy = "CityMerge Task 5, provisional"` is on the twelve moved spawn points and givers (the positions are provisional; old CFrames are in `CityMerge/placement.md`). `CityMergeDeviation` is on the two scripts edited after the import (`Lean`, `WeaponaryShopController`): the only places where the city's code differs from the FPS place.

## The heists in the city (2026-11-16)

- **Four locations** replaced the city's art buildings: SlowFoods (with `Illegal Supplier`), Gas2Go, NewsStation and the Bank, each placed by one transform (`CityMerge/phase3/locations.md`). The art twins are in `ServerStorage.CityQuarantine.ReplacedByHeist` with `OriginalCFrame`, `OriginalParent`, `OriginalPath`. `CasinoMain` and `WareHouseRobbery(NotUnderGroundPart)` stay art in `Workspace.Map.Robbery`.
- **Entrances** (exit spawns): Bank (1142.9, 2.25, 2305.8), SlowFoods (96.8, 5.94, 1778.8), Gas2Go (-986.6, 1.50, 1967.6), NewsStation (-614.0, 7.00, 988.6). Nearest plot 362 studs (SlowFoods) to 710; spawn 782 to 1,585; no anchor within 200 studs of another.
- **Bank vault underground:** 147.75 studs below its transformed spot, y -154 to -44, above `FallenPartsDestroyHeight` (-500); the Terrain under it (646 solid voxels) was cleared.
- **New Workspace children:** the 14 imported roots plus `Illegal Supplier` (`ImportedFrom = "Robbery System"`; `Workspace` 29 direct children, 236,393 descendants). The four marker containers (`HeistMarkers`, `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`) are Models, `Persistent`; `Illegal Supplier` is `Persistent`.
- **Prompts:** the old "26 leftover prompts saved `Default`" stay an Open Item: measured 2026-11-16, 2 went with the quarantined buildings and 4 are still in `Workspace.Map` (3 warehouse buttons, the casino button); where the other 20 are is not recorded; `PromptUiController` forces `Custom` at runtime ([[Robbery Prompts]]).

## How it works

- **Plots.** `Plot1` to `Plot6` are the six plates inside the city; `Plot7` and `Plot8` were on the old staging slab and carry `Spare = true`. Each plate has the attribute `PlotIndex` (1 to 8). `Plots` is a Model and `Persistent`, so plates never stream out.
- **Streaming** (set 2026-11-14): `StreamingEnabled = true`, `StreamingIntegrityMode = PauseOutsideLoadedArea`, `StreamOutBehavior = Opportunistic`, `StreamingMinRadius = 128`, `StreamingTargetRadius = 512`. `Ground` is `Persistent`. At spawn a client held 20,593 descendants and only 1 of the 6 robbery buildings was loaded.
- **Parts.** Every part under `Map` is anchored; `CanTouch` is off on all 97,888 of them and `CastShadow` is off on 40,325 small ones. `SpawnLocation` keeps `CanTouch`.
- **Restore.** Models, parts and folders in `Duplicates`, `LooseTycoon` and `StagingSlab` carry `OriginalParent` ("Workspace") and, except Folders, `OriginalCFrame`: set `Parent = workspace` (outside the `Map` folders) and `PivotTo(OriginalCFrame)`. The 8 scripts in `CityQuarantine.Scripts` carry `OriginalPath` (a string) and no CFrame: re-parent by hand and set `Enabled = true`. Not tested. Scripts disabled in place have `QuarantinedScript = true`.

## Extend it

Not recorded: no system code exists yet. The plots feed the tycoon phase of the design; purchases there will remove parts ([[CrimeLife Tycoon Decisions]]).

## Watch out

- `Workspace.ModelStreamingBehavior` is not scriptable and is **not confirmed `Legacy`**: set it in the Properties panel.
- Under a 512-stud target radius, far landmarks and robbery buildings are not loaded at spawn. Nobody has looked at it on a phone.
- Since 2026-11-15 the place holds the CrimeLife scripts ported from the FPS place; the free-model scripts are gone on purpose: see [[Luau and Scripting Traps]], "Free-model backdoors". Do not copy parts or models back from an old place file without scanning them.
- `Map.Loose` is unsorted (138 unnamed Models); `Plot7`, `Plot8` and the origin Baseplate remain from the slab.
- `Robbery` buildings are about 83,419 instances in total; the warehouse alone is about 56,000.
- Saved by Claude at checkpoints on 2026-11-15 and 2026-11-16 (last after phase 3 Task 5), never published ([[Save and Publish Rules]]). Anything done after that checkpoint exists only in the open session.
- The city map's `ProximityPrompt`s are saved `Default` (4 left in `Workspace.Map` since the heist buildings replaced the art); the imported `PromptUiController` forces every prompt to the FPS `Custom` face as it streams in ([[Open Items]]).
- East arm of the city's road crossing: valid road only 180 to 220 studs from the spawn (`Building_15` across its end); one Thug stood stuck there at about (215, 5, 2485).

## History
- 2026-11-16: the four heists placed on the city's Robbery buildings, vault underground, art quarantined ([[2026-11-16 Robbery Systems Into City]]).

See [[Batch Log]]. Created by [[2026-11-14 City Baseline and Cleanup]]. 2026-11-15: FPS systems, `Dev`, placed enemies and givers, `TycoonPreview` ([[2026-11-15 FPS Systems Into City]]).
