---
type: batch
tags: [batch, city, cleanup, streaming, malware]
updated: 2026-11-14
sources: [".superpowers/sdd/2026-11-14-city-baseline-and-cleanup/progress.md", ".superpowers/sdd/2026-11-14-city-baseline-and-cleanup/task-1-report.md to task-6-report.md", "CrimeLifeRoblox/CityCleanup/baseline-2026-11-14.md", "CrimeLifeRoblox/CityCleanup/after-task2.md to after-task6.md", "CrimeLifeRoblox/CityCleanup/script-inventory-summary.md", "CrimeLifeRoblox/CityCleanup/duplicates.md", "CrimeLifeRoblox/CityCleanup/slab-inventory.md", "CrimeLifeRoblox/CityCleanup/workspace-layout-plan.md"]
---

# 2026-11-14 City Baseline and Cleanup

Place: `Crimelife city.rbxl` (Edit). Plan: `docs/superpowers/plans/2026-11-14-city-baseline-and-cleanup.md`. Design it serves: `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`.

## Asked for

Make the Crimelife City map light enough to become the CrimeLife Tycoon map: measure it, remove the foreign scripts and duplicate buildings, find the six plots, tidy the Workspace and prepare streaming. The developer said "Yes, use your judgement" to removing free-model scripts and duplicates, and later "just proceed until the end", so every question that came up during the run was settled by a ruling, recorded in the run's ledger (`.superpowers/sdd/2026-11-14-city-baseline-and-cleanup/progress.md`). The art was not simplified: the design keeps the city's look.

## What changed

Seven steps, one commit each (`d6e0c52` to `4018d6c`, then this note's commit).

1. **Baseline.** `CityCleanup/probe.luau` measured the place before anything changed: 264,072 Workspace instances, 636 scripts (619 enabled), 2,431 unanchored parts, streaming off. It matched the 2026-11-14 survey exactly ([[Four Places Survey 2026-11-14]]).
2. **Scripts.** 648 scripts were inventoried across Workspace and the other services (Workspace 636). 597 were destroyed, 8 lighting and time scripts were moved to `ServerStorage.CityQuarantine.Scripts`, and 43 were disabled in place (details below). 104 `x6m` car parts were anchored.
3. **Duplicates.** The second copy of each robbery building, four `Dummy` rigs and `AI Dummy` (11 models, 99,737 instances) went to `ServerStorage.CityQuarantine.Duplicates`. Nothing was destroyed.
4. **Staging slab.** The place had a second area around the origin Baseplate (2048 by 2048 studs) holding stray copies and a loose copy of the tycoon kit. 1,470 top-level children went to quarantine (43,631 instances).
5. **Layout and plots.** Workspace now has six top-level children. The eight Lapis plates became `Workspace.Plots.Plot1` to `Plot8`.
6. **Streaming.** `StreamingEnabled` is on with the values below; `Map` parts have `CanTouch` off and small parts `CastShadow` off.
7. **This note.** Targets checked, vault updated.

### Before and after

| Measure | Baseline | After (`after-task6.md`) |
|---|---|---|
| Workspace instances (Edit) | 264,072 | 118,679 |
| Client `#workspace:GetDescendants()` at spawn, streaming on | not applicable (streaming off) | 20,593 |
| Parts / MeshParts / unions | 197,712 / 17,827 / 11,198 | 97,899 / 10,332 / 5,000 |
| Scripts in Workspace (total / enabled) | 636 / 619 | 1 / 0 |
| Unanchored parts | 2,431 | 0 |
| Lights | 1,993 | 1,014 |
| Top-level Workspace children | 1,876 | 6 |
| `ServerStorage` instances | 1 | 143,383 |
| Client memory in Play | 7,830.04 / 7,832.60 / 7,834.16 MB | 6,266.02 / 6,276.54 / 6,276.95 MB |
| PerformAverage | 5.5949 / 5.6292 / 5.8995 | 7.9681 / 1.9855 / 2.1798 |
| RenderThreadAverage | 9.7157 / 10.6801 / 9.8172 | 7.3447 / 4.3343 / 4.1588 |
| Batches | 898 / 905 / 912 | 239 / 227 / 201 |

Memory and the three averages are Studio-hosted readings (Play inside a Studio that also holds the Edit data model). They are **not comparable beyond like for like**, and no frame-rate claim is made from them. The first after-reading of PerformAverage (7.97) is higher than any baseline reading; the next two are lower. Three readings do not settle which way it went.

### Provisional targets (the developer has not agreed them)

The full table with a Result column is in `CityCleanup/baseline-2026-11-14.md`.

| Target | Result |
|---|---|
| Workspace instances <= 163,700 | Met on the Edit count: 118,679 |
| Enabled scripts 0 | Met: 0 enabled, 1 disabled script left in Workspace |
| Console errors at join 0 | **Missed**: 9 distinct lines after about 15 s of Play; no baseline count exists, so no like-for-like comparison |
| Unanchored map parts 0 | Met: 0 |
| Client memory no worse than baseline | Lower, but Studio-hosted: not called met |
| PerformAverage no worse than baseline | Mixed, Studio-hosted, three readings: not called met |

The remaining console lines are asset permission and empty-id load failures (`rbxassetid://0`, `188608071` not approved, `130839932` no permission, four matching sound loads) and "Animation Spoofer cannot run while game is running". They come from assets, not from the removed scripts.

## What was removed, and what only moved

### Malware found and removed

Three kinds of foreign code were found and destroyed. Sources are saved in `CityCleanup/removed-scripts/` (82 files, one per distinct script, named by Adler-32 hash). The trap is written up in [[Luau and Scripting Traps]] (heading "Free-model backdoors").

- Five copies of `ServerScriptService.ClientReplicator`: one obfuscated line using `getfenv` and a reversed-string `require` with a numeric asset id, which runs only outside Studio. A backdoor.
- `Workspace.Terrain.Fix`: a 69,317-character infector payload, mostly blank lines before the code, with the header "studio Hardware56. Removing this may cause severe damage to your game".
- The HD Admin loader, `require(3239236979)`, under `Workspace.HD Admin.Settings.Loader`.

No source used `HttpService`, `InsertService`, `MarketplaceService`, `TeleportService` or `MessagingService`. The place file on disk (`Crimelife city copy.rbxl`, byte-identical to `Crimelife city.rbxl`) is the pre-cleanup backup; place files from before this batch still contain the malware, so do not publish them.

### Destroyed

597 scripts, plus the whole `Workspace.HD Admin` folder. These were free-model code, decor loops (colour cycling, blinking lights, bobbing bricks), kill-on-touch bricks, animation-only scripts and the tycoon kit's loose config modules. Each distinct source is saved in `CityCleanup/removed-scripts/`; the per-script verdict is in `CityCleanup/script-inventory.csv`.

### Only moved: `ServerStorage.CityQuarantine`

| Folder | Holds | Size |
|---|---|---|
| `Scripts` | 8 lighting and time-of-day scripts, `Enabled = false` | 8 scripts |
| `Duplicates` | the second copy of each robbery building, 4 `Dummy`, `AI Dummy` | 11 models, 99,737 instances |
| `LooseTycoon` | the loose tycoon kit pieces from the slab (x >= 400) | 1,367 children, 21,997 instances |
| `StagingSlab` | everything else stray on the slab | 103 children, 21,634 instances |

**To move something back:** models, parts and folders moved to `Duplicates`, `LooseTycoon` and `StagingSlab` carry `OriginalParent` ("Workspace") and, except Folders, `OriginalCFrame`; the 8 scripts in `CityQuarantine.Scripts` carry `OriginalPath` (a string) and no CFrame. For a model or part, set `Parent = workspace` (it will then sit outside the `Map` folders) and `PivotTo(OriginalCFrame)` (a Part: set `CFrame`). For a script, re-parent it by hand to the place named in `OriginalPath` and set `Enabled = true`. This recipe has not been tested. `ServerStorage` does not replicate, so quarantined items cost clients nothing. Scripts that were disabled in place carry `QuarantinedScript = true`: 43 were disabled this way (proximity doors, outfit givers and similar, kept for a decision), and most travelled into quarantine with their models; 1 remains in Workspace. Find them all by that attribute.

`StagingSlab` holds `UnderGroundCasino` and `WareHouseP2`, which look like the underground halves of the casino and warehouse robberies. Phase 3 brings the Robbery place's scripted buildings; the developer should know these exist.

## Decisions

All rulings are in the ledger; the ones that shape the map:

- **The staging slab.** The place had a second area around the origin Baseplate holding stray copies; the city's southern corner overlaps it (1,063 `City` parts inside the slab footprint). A city-corner zone (x < 400 and z > 400) was deliberately left alone, so nothing of the city was quarantined by mistake. 29 candidates (2,681 instances) in that zone went to `Map.Loose` or `Map.Props` in step 5.
- **Which copy of a duplicate stayed:** the one off the slab and nearer the city centre (64.86, 181.28, 1719.19). `SlowFoodsB` was renamed `SlowFoods` to match the Robbery place. Every pair was at least 708 studs apart; nothing was destroyed.
- **Plots.** Six Lapis plates (300 by 1 by 361) are in the city, 349 to 558 studs apart: they are `Plot1` to `Plot6`. Two more sit on the slab at (544, 0, 229) and (720, 0, -207): `Plot7` and `Plot8` with `Spare = true`. This confirms the developer's "6 placeholder blue baseplates".
- **Non-lighting scripts worth keeping were disabled in place** (`QuarantinedScript = true`) rather than moved, so they stay with their models.
- **Cars and props.** `x6m`, `Decpration1Major` and `Barricade` went to `Map.Props`.
- **Streaming values** (before: off, unreadable, Default, Default, 64, 1024): `StreamingEnabled = true`, `StreamingIntegrityMode = PauseOutsideLoadedArea`, `StreamOutBehavior = Opportunistic`, `StreamingMinRadius = 128`, `StreamingTargetRadius = 512`. `Ground` (holds the Baseplate) and `Plots` are `Persistent`.
- **`ModelStreamingBehavior` could not be set by script** (the write fails with "is not a valid member of Workspace", reads fail as "not a scriptable property"). It is **not confirmed `Legacy`**: the developer must set it in the Properties panel.
- **Tycoon purchases remove parts** (new developer requirement, recorded in `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md` and [[CrimeLife Tycoon Decisions]]); not part of this batch.

## Verified

- Probe counts after every step (`after-task2.md` to `after-task6.md`); each drop equals the instances moved (for example 162,303 - 118,672 = 43,631).
- 0 enabled scripts in any service; no `ClientReplicator`, `HD Admin` or `Terrain.Fix` left; 82 destroyed hashes equal the 82 saved files.
- Every moved item has its restore attributes; one top-level model of each robbery building remains and their pivots did not move.
- Spawn check in Play: 21 samples over 5 s, Y = 5.09 every sample.
- Under streaming, the client held 20,593 descendants; `Map.Robbery` has 6 children and only 1 had parts loaded (`CasinoMain`).
- Tasks 1 to 6 were each reviewed against the live place and ended with no open Critical or Important finding (Task 1's two Important findings were labelling fixes). Task 6 was reviewed the same way and approved with no Critical or Important finding: the five scriptable streaming values, the six top-level children, `Ground` and `Plots` as Persistent, 0 `CanTouch` and 0 unanchored parts under `Map`, and 118,679 instances were all confirmed on the live place. That review did not run Play, so the spawn check and the client-side streaming table rest on the implementer's single run.

### Disproved

- **"The road strip is gone."** After step 2 the far aerial screenshot lacked a road strip in the left park, though part counts were identical. A close capture of the same park (camera (-350, 450, 2950) looking at (-350, 0, 2400)) showed the roads present. It was a render artifact: a road co-planar with the ground, seen from more than 3,000 studs. Nothing was lost.
- **"The Bank screenshot shows the city Bank."** The baseline camera pointed at the slab Bank at (-173.75, 219, -211.75). The city Bank is at (1217.75, 220.76, 2342).

## Not verified

- Real phone performance. The Studio-hosted readings say nothing about a phone.
- Anything with two players.
- How the city looks under streaming on a low-end device. Edit mode loads everything, so the screenshots do not show streaming.
- That `Workspace.ModelStreamingBehavior` is `Legacy`.
- Whether every removed script's absence is harmless in play: only a 15 s solo Play was run after each change. Casino colour-cycling parts and blinking alarm lights are now static because their scripts are gone.
- Console errors at join: no baseline count was recorded (the output tool truncates), so the 9 distinct lines after cleanup cannot be compared.

## Left open

All in [[Open Items]], dated 2026-11-14: save the place; set `ModelStreamingBehavior`; agree the targets; look at streaming on a real phone; lighting from `CityQuarantine.Scripts`; the fate of `Duplicates`, `LooseTycoon` and `StagingSlab`; `Map.Loose` (213 unsorted pieces); the spare plates and the origin Baseplate; and the heaviest remaining models.

## Links

[[City Map and Plots]] · [[Four Places Survey 2026-11-14]] · [[Places and Studio Windows]] · [[Luau and Scripting Traps]] · [[Open Items]] · [[Batch Log]] · [[CrimeLife Tycoon Decisions]]

**NOT saved / NOT published.**
