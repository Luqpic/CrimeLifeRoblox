---
type: reference
tags: [reference, places, merge, tycoon, survey]
updated: 2026-11-14
sources: ["Read-only Studio survey through the Roblox_Studio MCP, 2026-11-14", "docs/crimelife-hq-blueprint.html"]
---

# Four Places Survey 2026-11-14

A read-only count of the four Studio places that will be merged into CrimeLife Tycoon. Nothing was changed. The merge target and the cleanup calls are in [[CrimeLife Tycoon Decisions]]; the two older places are described in [[Places and Studio Windows]].

## The four places

| Place | File or id | What it holds |
|---|---|---|
| FPS System | `FPS System.rbxl` (local) | The only place with tested game code: guns, melee, enemies, quests, shop, skins, leveling, saves. See [[Systems MOC]]. |
| Robbery System | `Robbery System.rbxl` (local) | Heists, puzzles, getaway; shares UI modules with FPS. |
| Crimelife City | `Crimelife city.rbxl` (local) | The main map. Art only. **The merge target.** |
| Test30.4 | PlaceId 94388758790319, universe 10770697737 (cloud) | The tycoon building. Art plus a marketplace tycoon kit. |

## Crimelife City (measured)

- Workspace: 264,072 instances, 197,712 parts, 17,827 MeshParts, 11,198 unions.
- `StreamingEnabled` is **false**.
- 636 scripts sit loose in Workspace and none are CrimeLife code: 348 unnamed `Script`, 84 `Smooth Color Changing Script`, 36 `Animation`, 30 `Kill_25`, 22 `Animate`, 11 `DamageScript_25`, 11 `Instructions Of Use`, plus vehicle chassis scripts.
- `ReplicatedStorage` and `ReplicatedFirst` are empty. `ServerScriptService` holds 6 scripts (one graphics script, five `ClientReplicator`).
- Heavy and duplicated models: `WareHouseRobbery(NotUnderGroundPart)` twice (56,396 and 56,294 instances), `City` folder 25,563, `Bank` twice (3,894 and 3,892), `CasinoMain` twice (3,978 and 4,074), `NewsStation` twice (6,448 each), `Gas2Go` twice (6,413 each), `SlowFoods` and `SlowFoodsB` (6,000 and 6,399), `UnderGroundCasino` 4,348, `AI Dummy` 13,944.
- A copy of the tycoon building's parts is pasted loose into Workspace (droppers, conveyors, outfits, `TycoonSpawn`, 21 `DropperConfig` modules), not inside one model.
- The developer says six blue baseplates mark the base plots. Not located or measured in this survey.

## After cleanup (2026-11-14)

Measured after the city cleanup ([[2026-11-14 City Baseline and Cleanup]]); the section above is the baseline and is unchanged. Source: `CityCleanup/after-task6.md`. Edit mode, not saved.

- Workspace: 118,679 instances (baseline 264,072), 97,899 parts, 10,332 MeshParts, 5,000 unions, 0 unanchored parts.
- `StreamingEnabled` is **true** (`StreamingMinRadius` 128, `StreamingTargetRadius` 512, `StreamingIntegrityMode = PauseOutsideLoadedArea`, `StreamOutBehavior = Opportunistic`). `ModelStreamingBehavior` is not scriptable and is not confirmed `Legacy`. A client holds 20,593 descendants at spawn.
- Scripts in Workspace: 1, disabled (baseline 636, 619 enabled). Five backdoor copies of `ClientReplicator`, `Terrain.Fix` and the HD Admin loader were destroyed; see [[Luau and Scripting Traps]].
- Six top-level Workspace children: `Terrain`, `Camera`, `Map`, `Plots`, `SpawnLocation`, `Ground`.
  - `Map`: `City` (25,554), `Robbery` (6 buildings, 83,419), `Roads` (3, 1,798), `Props` (147, 4,307), `Loose` (213, 3,580).
  - `Plots`: `Plot1` to `Plot6` (the six blue plates in the city) and `Plot7`, `Plot8` (on the old staging slab, `Spare = true`). This confirms the developer's six placeholder baseplates.
  - `Ground`: the origin Baseplate.
- `ServerStorage.CityQuarantine` holds what was moved out: `Scripts`, `Duplicates`, `LooseTycoon`, `StagingSlab`. `ServerStorage` is 143,383 instances and does not replicate.
- Duplicates are gone: one copy each of `WareHouseRobbery(NotUnderGroundPart)`, `Bank`, `CasinoMain`, `NewsStation`, `Gas2Go` and `SlowFoods` remains, in `Map.Robbery`. `AI Dummy` and the four `Dummy` rigs are quarantined.
- Studio-hosted Play readings (like for like only): memory 6,266.02 to 6,276.95 MB (baseline 7,830.04 to 7,834.16), PerformAverage 7.9681 / 1.9855 / 2.1798 (baseline 5.5949 to 5.8995). Real phone numbers: not recorded.

Layout and watch-outs: [[City Map and Plots]].

## Test30.4 (measured)

- Workspace: 87,456 instances, 37,690 parts, 292 scripts. `StreamingEnabled` is true.
- `Workspace.HQ` (58,278 instances): `Building` 52,304, `V1` 4,631, `Fence` 1,230. **`HQ.Building` is the model to carry over.**
- `Workspace.Ace` (28,769 instances), of which `Old` is 27,020. Left behind.
- Scripts: 236 unnamed `Script`, 34 `Animation`, 14 `DropperConfig`, one each of `UpgraderConfig`, `CurrencyCollectorConfig`, `PartCollectorConfig`, `TeleportHandler`; 3 `OwnerOnlyDoorScript`. This is a marketplace tycoon kit, not CrimeLife code.
- No code in `ReplicatedStorage`; one script in `ServerScriptService`.

## The HQ blueprint

`docs/crimelife-hq-blueprint.html` (drawn 2026-09-30, status "Layout approved") is the drawing set for the tycoon building. Whether `HQ.Building` matches it room for room has not been checked.

- Plot 360 by 360 studs, HQ footprint 200 by 200, 20 studs floor to floor, levels B1, F1, F2, F3. Origin at the plot's north-west corner, +X east, +Z south.
- 26 button-pad strips (P1 to P26), one inside each room's door.
- **Four money lines:**

| Line | Where | Chain |
|---|---|---|
| Scrap Foundry | F1, stage 1 | 6 scrap droppers, moulder, conveyor, part collector (Stainless up to Diamond) |
| Counterfeit Printers | F2, stage 3 | 6 presses, conveyor, cash pile in the Counting Room |
| Chop Shop | Garage, stage 6 | Car lift, 2 strip bays, parts conveyor, crusher |
| Gold Refinery | B1, stage 7 | 5 furnaces, mould conveyor, vault gold stack |

- **Nine unlock stages** (prices are the blueprint's placeholders, not a balanced curve):

| Stage | Name | Price band |
|---|---|---|
| 0 | Start-up | $0 to $100 |
| 1 | Foundry and F1 shell | $50 to $30K |
| 2 | Bar and Stage | $10K to $60K |
| 3 | F2 and Printers | $50K to $300K |
| 4 | Weaponry and Tailor | $30K to $1M |
| 5 | F3 Executive | $250K to $1.5M |
| 6 | Garage | $500K to $3M |
| 7 | Bunker | $2M to $10M |
| 8 | Perimeter and finale | $5M to $25M |

- Build rules in the blueprint: the top owned floor always wears a temporary roof cap; a chain-link fence marks the plot from stage 0; each room ships its floor and lights with its structure button so an unbought room looks empty, not broken.

## What this means for the merge

- There is no CrimeLife-owned tycoon code. The kit is rebuilt on the FPS place's cash and save code ([[Economy and Cash]], [[Persistence and Saves]]), not ported.
- The city needs a cleanup and streaming pass before any system is added: it is far too heavy for phones as measured ([[Phones First and Keep Optimised]]).
- Six plots of 360 by 360 studs must fit the six blue baseplates. Not checked.

Related: [[Tycoon Market Research 2026-11]], [[Reference MOC]].
