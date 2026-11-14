---
type: system
tags: [system, city, plots, streaming]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CityCleanup/after-task5.md", "CrimeLifeRoblox/CityCleanup/after-task6.md", "CrimeLifeRoblox/CityCleanup/workspace-layout-plan.md", "70 Batches/2026-11-14 City Baseline and Cleanup.md"]
---

# City Map and Plots

## What it does

The Crimelife City map in `Crimelife city.rbxl`, cleaned to be the world of CrimeLife Tycoon: art only, six plots for the tycoon bases, streaming prepared for phones. Why and how: [[2026-11-14 City Baseline and Cleanup]]. The design it serves: `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`.

## Where it lives

`Workspace` has six children:

| Child | Holds |
|---|---|
| `Map` | `City` (25,554 instances), `Robbery` (6 buildings, 83,419), `Roads` (3), `Props` (147), `Loose` (213 unsorted pieces) |
| `Plots` | `Plot1` to `Plot8`, each one Lapis plate (300 by 1 by 361 studs) |
| `Ground` | the origin Baseplate |
| `SpawnLocation`, `Terrain`, `Camera` | unchanged |

`ServerStorage.CityQuarantine` (does not replicate): `Scripts` (8 disabled lighting and time scripts), `Duplicates` (11 models), `LooseTycoon` (1,367 children), `StagingSlab` (103 children).

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
- The place holds no CrimeLife scripts yet, and the free-model scripts are gone on purpose: see [[Luau and Scripting Traps]], "Free-model backdoors". Do not copy parts or models back from an old place file without scanning them.
- `Map.Loose` is unsorted (138 unnamed Models); `Plot7`, `Plot8` and the origin Baseplate remain from the slab.
- `Robbery` buildings are about 83,419 instances in total; the warehouse alone is about 56,000.
- Not saved: until the developer saves `Crimelife city.rbxl`, the cleanup exists only in the open Studio session ([[Open Items]]).

## History

See [[Batch Log]]. Created by [[2026-11-14 City Baseline and Cleanup]].
