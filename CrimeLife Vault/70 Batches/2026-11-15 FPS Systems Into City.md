---
type: batch
tags: [batch, city, fps-port, tycoon-preview, placement, streaming]
updated: 2026-11-15
sources: [".superpowers/sdd/2026-11-15-fps-systems-into-city/progress.md", ".superpowers/sdd/2026-11-15-fps-systems-into-city/task-1-report.md to task-5-report.md", "CrimeLifeRoblox/CityMerge/fps-manifest.md", "CrimeLifeRoblox/CityMerge/fps-workspace-paths.md", "CrimeLifeRoblox/CityMerge/fps-test-baseline.md", "CrimeLifeRoblox/CityMerge/after-import.md", "CrimeLifeRoblox/CityMerge/first-run.md", "CrimeLifeRoblox/CityMerge/client-load-order-audit.md", "CrimeLifeRoblox/CityMerge/placement.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-11-15-fps-systems-into-city.md"]
---

# 2026-11-15 FPS Systems Into City

Place: `Crimelife city.rbxl` (Edit and Play). `FPS System.rbxl` was only read, plus Play for the comparison runs. Plan: `docs/superpowers/plans/2026-11-15-fps-systems-into-city.md` (phase 2a). Design it serves: `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`. Ledger with every ruling: `.superpowers/sdd/2026-11-15-fps-systems-into-city/progress.md`. This batch covers two things: the tycoon building, brought forward (A), and the port of the FPS systems (B).

## Asked for

The developer said "Run the plan" (2026-11-15): bring every FPS System service, asset and gameplay anchor into Crimelife City unchanged, prove it behaves there as it does in the FPS place, then move the enemies and quest givers into the city. Before the run started they asked "where's the tycoon building?" and expected to see it in the city. They answered the run's questions before sleeping; the answers are in [[CrimeLife Tycoon Decisions]] under 2026-11-15. The scope for the night was "HQ in the city + FPS playable there", and the instruction was to "run until the very end ... everything is made according to plan and polished".

## What changed

### A. The tycoon building, brought forward

The building had not been moved. In the approved order it is phase 4 (plots and the HQ). The developer's question moved it up.

- **The transfer was refused, and not worked around.** `Test30.4`'s Studio window (a cloud place) rejected the local transfer: its Assistant HTTP allowlist does not include `127.0.0.1` ([[Studio MCP Gotchas]]). The developer pasted `Workspace.HQ` from Test30.4 into the city's `ServerStorage` by hand: 58,282 descendants (`Building`, `Fence`, `Road`, `V1`).
- **`ServerStorage.HQ` is the untouched source.** Phases 4 and 5 start from it, with the tycoon kit's scripts and button data intact, because the design needs each purchase's remove-on-buy list read from the kit's buttons before they are stripped.
- **`Workspace.TycoonPreview` is a static preview** built from it on `Plot3` (the plot nearest the city spawn): a Model with 47,894 instances, 24,053 parts (all anchored), 23 scripts disabled (`QuarantinedScript = true`), attributes `Preview = true`, `PlotIndex = 3`, `SourceDelta = (564, -123, 1778)` and `ImportedFrom`. It is built from `HQ.Building`'s `Ground_Floor`, `Industrial_Floor`, `Executive_Floor`, `Garage_Wing`, `Lift`, `FL2-3` and `Fl0-1`.
- **It is a preview and nothing more.** It cannot be bought, it earns nothing and it is not the working tycoon.
- **Not included, and why:**

| Left in `ServerStorage.HQ` | Why |
|---|---|
| `Bunker` | sits 29 studs below ground |
| `Fence` compound | 370 by 370 studs; the plate is 361 by 300. The developer chose to shrink the yard ([[CrimeLife Tycoon Decisions]]), so the compound waits for phase 4 |
| `Road`, `V1` | not part of the building (the design leaves `HQ.V1` behind) |
| 20 stray block-out parts | dropped from the preview (x > -430 in the source) |

- **What looking at Test30.4 showed:** `HQ.Building`'s floor folders also hold block-out floor plans laid out to the side (x > -430). The assembled building is at x -686 to -473, z 128 to 438, with the ground floor top at Y 124. The preview uses only the assembled part.
- Workspace went from 118,679 (the 2026-11-14 count, [[City Map and Plots]]) to 166,574 descendants with 7 top-level children; the place was saved twice by Claude with the developer's permission, after the paste and after the preview.

### B. The FPS port (Tasks 1 to 5)

Seven commits, one per task or leg (`4ddc800`, `76eb7ea`, `1a1551d`, `7d8a360`, `bbe9791`, `41fe3ba`, `287b2a6`), then this note's commit.

**Task 1: transfer method, manifest, baseline** (`4ddc800`). Studio serializes a folder with `SerializationService:SerializeInstancesAsync`, encodes it with `EncodingService` Base64 and posts it with `HttpService:RequestAsync` to a localhost-only store on this Mac (`CityMerge/transfer/server.py`); the city window fetches, deserializes, stamps `ImportedFrom = "FPS System"` and parents it (`CityMerge/transfer/export.luau`, `import.luau`). Nothing passed through an agent's context and no source was retyped. The FPS manifest: 88 roots, 7,988 instances (roots plus descendants), 199 scripts, 3,559,520 Base64 bytes (`CityMerge/fps-manifest.md`). No script references the FPS `Workspace.Map`, which is why the FPS map could go under `Dev` without breaking anything. The FPS baseline: 12 unit-test suites, 147 run, 147 passed, 0 failed.

**Task 2: services** (`76eb7ea`). 78 roots, 5,939 instances, 197 scripts into `ReplicatedStorage` (18 roots), `ServerScriptService` (16), `ServerStorage` (9), `StarterGui` (3), `StarterPlayerScripts` (25), `StarterCharacterScripts` (6) and `SoundService` (1). Settings copied by value: `CameraMaxZoomDistance` 128 to 30, `CharacterWalkSpeed` 16 to 25 (the rest were equal already). `import.luau` now errors unless exactly one root is deserialized.

**Task 3: Workspace anchors** (`1a1551d`). 10 roots, 2,049 instances including roots, plus a `Dev` folder (see [[City Map and Plots]]). No clash with city geometry, no height shift (both baseplates top at Y 0). Workspace 166,574 to 168,624.

**The exact-copy proof (Tasks 2 and 3, by program).** `diff` of the sorted script lists (root, path, class, enabled, Adler-32 of `Source`) between `fps-manifest.tsv` and the city's own manifest printed nothing: **199 script hashes equal across all 88 roots**. Descendant and script counts per root equal for all 88; tags in the imported roots equal (Blaster 21, EnemySpawnPoint 6, NPCprompt 6, Target 7, and the three assistant tags); positions equal to the FPS values (shift 0). The manifest diff has zero differences. Task 2's and Task 3's reviews re-read the live places and agreed.

**What was left behind in the FPS place** (not imported, by the plan): `ServerStorage.ArchivedWeaponPickups`, `Gun Pack`, `__MeshProbe`, `Body`; `ReplicatedStorage.__ProbeOutside`; `Workspace."UI Animation Pack - by JakeDev"` (166 descendants; an Open Item already asks whether to delete it); `Workspace.Baseplate`, `Terrain`, `Camera`; all `Lighting` children (the city's lighting stays).

**Task 4: first run** (`7d8a360`, `bbe9791`, `41fe3ba`). Solo Play in both places, same code, console read from `LogService`. The plan's stop gate became a fix loop ("Fix it in the city and continue"): leg 1 measured, the controller approved a fix list, legs 2 and 3 fixed and re-ran.

| Reading | City | FPS System |
|---|---|---|
| Unit tests (12 suites, run / passed / failed) | 147 / 147 / 0 | 147 / 147 / 0 |
| Cash, level, XP at start; profile bound | 500, 1, 0; yes | 500, 1, 0; yes |
| Purchase through `BuyRequest` of AK47 | cash 500 to 300, owned, saved to the profile | same |
| Kill (Thug, health 90) | XP 0 to 10, saved | same |
| Enemies alive, six spawn points each producing their own type | 30 (5 per type) | 26 (a top-up still in progress) |
| PlayerGui children | 21 (the 21st is the city's own inert `StarterGui.TImeScripts`) | 20 |
| Client `#workspace:GetDescendants()` and its cost | 30,541; 11.69 ms | 8,261; 4.35 ms |
| Streaming radii (min / target) | 128 / 512 | 64 / 1024 |

The two places match on every line that matters: **147 / 147 in both; the purchase and the kill are identical.** The differences that remain are the city's own content and its size. One city-only console error was found: `Lean` line 25.

**The two deviations from the FPS place** (the only edits made to imported code; both are marked with the attribute `CityMergeDeviation` and listed in `CityMerge/after-import.md`):

| Script | What | Old length / Adler-32 | New length / Adler-32 |
|---|---|---|---|
| `StarterPlayer.StarterCharacterScripts.Lean` | `character.Humanoid`, `character.HumanoidRootPart` and `character.LowerTorso` become `WaitForChild(name, 10)` with a quiet return on nil | 5,696 / 2478388517 | 5,970 / 3351089419 |
| `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` | line 20 only: `require(script.Parent.SkinsCardController)` becomes `require(script.Parent:WaitForChild("SkinsCardController"))` | 54,021 / 1830119947 | 54,037 / 193228620 |

- **Why `Lean`:** the script starts about 39 ms before its character's `HumanoidRootPart` exists in the city (measured from `CharacterAdded`: `Lean` at 0.032 s, `LowerTorso` 0.064 s, `HumanoidRootPart` 0.071 s). Line 25 errored in every city Play. It is the open bug the vault has carried since 2026-09-24 ([[Open Items]]); fixed in the city only.
- **Why `WeaponaryShopController`:** in 2 of 3 Plays after the `Lean` fix, the sibling module `SkinsCardController` had not yet reached `PlayerScripts` when line 20 ran. The script errored, the weapon shop and the skins card were never built, and PlayerGui had 19 children instead of 21. In the same Plays `StarterGui`'s copy arrived more than 5 s late (`Infinite yield possible` on `PlayerGui:WaitForChild("Custom Inventory")` from 7 scripts). Buying would have been broken, so this was a must-fix.
- **The class audit** (`CityMerge/client-load-order-audit.md`): the controller ruled to fix the class, not the instance. Every client script was searched for direct indexing of a separately-replicated instance (PlayerScripts siblings, PlayerGui children, character parts, ReplicatedStorage children): **138 rows, 4 FIX (the three `Lean` lookups and `WeaponaryShopController` line 20), 134 SAFE.** The 85 `ReplicatedStorage` rows are SAFE by observation only: 0 such errors in 10 city Plays, and in both failing Plays eight direct `ReplicatedStorage` paths in `WeaponaryShopController` lines 12 to 19 succeeded just before line 20 failed. Nothing could be tested for them. The trap is written up in [[Streaming and Replication Traps]].
- **Five clean Plays** after the fixes: PlayerGui 21 each time, shop and skins card built, 0 script errors, 0 `Infinite yield` warnings, PlayerScripts 28, `Lean` present, `WalkSpeed` 20, purchase 500 to 300, unit tests 147 / 147. Respawn at 10 s was checked in two of them (21 children, 0 errors).
- The mirror `FPSSystem/Cosmetics/WeaponaryShopController.luau` is now an out-of-date mirror and was not changed. `Lean` has no repo mirror.
- **Not changed, on purpose:** `PromptUiController`. It forces every `ProximityPrompt` in `Workspace` to `Style = Custom` and draws the FPS face on it; the city holds 26 prompts saved `Default`. Whether they should get the FPS style is the developer's call (Open Items); the script is shared with the Robbery place, so a change must be made in both.

**Task 5: placement** (`287b2a6`). `CityMerge/placement.md` has the whole derivation. The measured facts the placement had to respect are in [[Enemies and Spawner]] and [[Quests and Dialogue]].

*Why the first proposal was rejected.* It put the points on graded radii of 140 to 260 studs from the spawn on the four road arms. The controller rejected it because the Thug point at 140 let a Thug patrol into detection range of the spawn (patrol 70 plus scatter 22 reaches about 48 studs from the spawn, inside the 80-stud detection radius, so a player at the spawn would be under fire), the arm toward Plot3 let Bandits patrol onto a tycoon plot (the Bandits point was 79.8 studs from Plot3), and a west point at 160 could patrol into the quest-giver row. The approved quest-giver row was kept.

*Rules for every enemy point* (all hold for the six applied points): at least 180 studs from `SpawnLocation`; at least 120 from every plot (`Plot1` to `Plot6`) and from the `TycoonPreview` box; at least 130 from every quest giver; at least 60 from every other point and from every robbery building; on `Map.City.Roads` or `Map.City.FootPaths` with a clear box, a clear line to the spawn and walkable scatter; not on the arm toward Plot3 (the -Z arm). Weakest nearest, strongest farthest.

| Point | Type | Arm | Position | From spawn | Nearest plot 1 to 6 | Nearest giver |
|---|---|---|---|---|---|---|
| `ThugSpawner` | Thug | east | (169, 1.5, 2498.75) | 180.0 | Plot3, 279.8 | 214.9 |
| `SmugglerSpawner` | Smuggler | +Z | (-11, 1.5, 2678.75) | 180.0 | Plot3, 459.8 | 204.1 |
| `OffenderSpawner` | Offender | west | (-291, 2.5, 2498.75) | 280.0 | Plot2, 279.8 | 177.4 |
| `BanditsSpawner` | Bandits | +Z | (-11, 1.5, 2778.75) | 280.0 | Plot5, 542.1 | 303.2 |
| `DisruptersSpawner` | Disrupters | west | (-351, 2.5, 2498.75) | 340.0 | Plot2, 279.8 | 237.1 |
| `SaboteurSpawner` | Saboteur | west | (-411, 1.5, 2498.75) | 400.0 | Plot2, 279.8 | 296.9 |

Nearest robbery building to any point: 230.8 (`SaboteurSpawner`, `CasinoMain`). The east arm has valid road only from 180 to 220 studs (`Building_15` stands across its end), so it holds one point; Offender's west 240 and 260 failed on a bin in the line to the spawn, so it went to 280.

| Giver | Pivot (Y 2.0035, z 2477.5) | From spawn |
|---|---|---|
| `Level 1 Quest` | x -44.89 | 40.0 |
| `Level 10 Quest` | x -58.89 | 52.4 |
| `Level 20 Quest` | x -72.89 | 65.4 |
| `Level 35 Quest` | x -86.89 | 78.8 |
| `Level 50 Quest` | x -100.89 | 92.4 |
| `Level 70 Quest` | x -114.89 | 106.0 |

The givers stand on the sidewalk strip `Map.City.FootPaths.Part` (-115, 1.5, 2477.5), 14 studs apart, and face the spawn. All twelve moved instances carry `PlacedBy = "CityMerge Task 5, provisional"`; the old CFrames are in `placement.md` ("Applied"). The positions are **provisional**: re-place by hand if they read badly.

*The run from the city spawn* (one solo Play, `Dev.DevSpawn` disabled, readings at about 46 s and 76 s): 30 enemies alive (5 per type), the nearest 150.4 studs from the player, none within 100 studs of the spawn and none inside a plot; 5 of the 6 types moved; the six givers present with their prompts (`HumanoidRootPart` Y 5.0035, as intended); PlayerGui 21; player health 100; cash 500; unit tests 147 / 147; server 0 non-asset errors; client 0 game-script errors. Exceptions: **one of the five Thugs stood still at about (215, 5, 2485)** against `Building_15` for the whole run, and the client logged 8 CoreGui load-timeout errors (Roblox's own modules; the Task 4 Plays did not show them).

## Decisions

- **Crimelife City is now the primary place.** `FPS System.rbxl` is frozen as the reference the port was taken from. Claude's call, following the approved design (the developer chose the city as the merge target on 2026-11-14). Rule notes updated: [[Which Project This Is]], [[Start Here]], [[Places and Studio Windows]]. The `FPSSystem/` mirrors in the repo mirror the FPS place as exported; two city scripts now deviate (`Lean` and `WeaponaryShopController`), and `FPSSystem/Cosmetics/WeaponaryShopController.luau` is out of date.
- **Fix it in the city** when the city behaves differently (the developer's answer): the Task 4 gate became a fix loop; the FPS place stayed untouched.
- **Fix the class, not the instance:** the audit of every client script rather than one more `WaitForChild`. Cost if wrong: extra yields in scripts that were already safe; revert per script from the FPS place.
- **`PromptUiController` is left alone**; the city's 26 `Default` prompts become an Open Item.
- **Enemy placement rules** (above) and **the preview on `Plot3`**: Claude's calls; `PivotTo` moves the preview to another plot if wrong.
- **Saving.** The developer allowed Claude to save `Crimelife city.rbxl` at checkpoints during this overnight run ("Yes, save at checkpoints"). Claude saved it six times: after the paste, after the preview, then after Tasks 2, 3, 4 and 5. Never published. This was a permission for one night: [[Save and Publish Rules]]. The on-disk backup `Crimelife city BACKUP pre-cleanup 2026-08-20.rbxl` was copied first. The 2026-11-14 Open Item asking the developer to save the city is therefore **closed** and removed from [[Open Items]].
- Decisions recorded under 2026-11-15 in [[CrimeLife Tycoon Decisions]].

## Verified

- The exact copy: 199 script hashes equal across 88 roots, 0 descendant or tag mismatches, 0 position shifts, by program (see above). Tasks 1 to 4 were each reviewed against the live places and approved; Tasks 2 to 4 had no Critical or Important finding. Task 1's two Important findings were tool hardening (`import.luau` took `arr[1]` unchecked, fixed in Task 2; `export.luau` indices unique only for distinct `startIndex`, parked: all 88 exports exist with distinct keys).
- Both places, same code: 12 suites 147 / 147 / 0; profile bound; purchase 500 to 300; kill XP 0 to 10; six spawn points each producing their own type.
- Five clean city Plays after the two deviations (above); the Task 4 review read the live places and found only `Lean` and `WeaponaryShopController` differing from FPS, by the approved lines.
- The run from the city spawn with the placed enemies and givers (above); the twelve anchors read back at the applied positions.
- Invariants after the batch: Workspace 168,624 descendants, exactly one enabled `SpawnLocation` (the city's), `StreamingEnabled` true, `Plots` 8 children, 0 unanchored `BaseParts` under `Workspace.Map`.
- Task 5 was reviewed the same way and approved with no Critical or Important finding: every placement rule was recomputed from the live positions and holds (five numbers sit exactly on their limits: two points at 180.0 studs from the spawn, three pairs 60.0 apart), quest-giver spacing is 14.0 with 0.00 degrees of facing error, and nothing else moved. The reviewer measured the east point's surroundings: `Building_15`'s near face is about 24 studs away and only 44 of 64 sample rays within 70 studs land on road or footpath, which accounts for the stuck Thug.

## Not verified

- **Anything a person must do at the keyboard:** how shooting feels, pressing E on a quest giver (automation cannot trigger the `Custom` prompts), the weapon shop by real clicks, a quest-dialogue reply by click.
- **Two players**, and **a phone**.
- **Persistence on a published place.** Everything ran on the mock store (`ProfileStore.Mock`); the city is unpublished.
- **The HQ preview's fit** was checked by one screenshot and its bounding numbers, not walked.
- **The cause of the stuck Thug.** The reading is that its patrol targets past x 220 hit `Building_15` and the path fails, or it is wedged at the building's base; not tested.
- **That the late-sibling rescue works.** The race did not recur in the five Plays, so `WeaponaryShopController`'s `WaitForChild` is verified to change nothing when the sibling is present, not to rescue the late case.
- **`ModelStreamingBehavior` is `Legacy`**: still unreadable by script, still open from 2026-11-14.
- **Screenshots.** `screen_capture` timed out repeatedly late in this session (cause not recorded), so the placement was verified by property read-back, not by eye ([[Studio MCP Gotchas]], [[Screen Captures]]).
- **Not run:** pathfinding over the 70-stud patrol areas of the placed enemies.

## Left open

All in [[Open Items]], dated 2026-11-15: the provisional placement; the stuck Thug; the leftover prompts' style; about 79 asset-permission warnings per Play from `TycoonPreview` and `ServerStorage.HQ`; the enabled `TycoonSpawn` in quarantine; `Documents/Roblox/CLAUDE.md` still naming FPS System as primary; the checks that need a person; the open bugs and watch-list items found by the first run. Phase 2b (its own plan, to be written from `CityMerge/first-run.md`) carries the remote ownership audit, the eleven `ZIndexBehavior.Global` ScreenGuis and quest progress not being saved. Phases 3 to 6 (Robbery, plots and the HQ, the tycoon core, the haul) follow; phases 4 and 5 start from `ServerStorage.HQ`.

## Links

[[City Map and Plots]] · [[Enemies and Spawner]] · [[Quests and Dialogue]] · [[Streaming and Replication Traps]] · [[Studio MCP Gotchas]] · [[Which Project This Is]] · [[Start Here]] · [[Places and Studio Windows]] · [[Save and Publish Rules]] · [[CrimeLife Tycoon Decisions]] · [[2026-11-14 City Baseline and Cleanup]] · [[Open Items]] · [[Batch Log]]

**Saved to `Crimelife city.rbxl` (checkpoint after Task 5) / NOT published.**
