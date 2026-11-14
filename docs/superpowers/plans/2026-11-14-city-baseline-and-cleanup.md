# City Baseline and Cleanup Implementation Plan (Phases 0 and 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure Crimelife City as it stands, then turn it into a clean, lighter, streamed map with no foreign scripts, ready to receive the FPS systems in phase 2.

**Architecture:** Every change is made live in the `Crimelife city.rbxl` Studio window through the `Roblox_Studio` MCP, in Edit mode. One re-runnable probe produces the same numbers before and after every task. Nothing heavy is deleted outright: it moves to `ServerStorage.CityQuarantine`, which costs clients nothing and can be moved back. Only scripts proven to be junk or unsafe are destroyed, after their sources are saved to the repo.

**Tech Stack:** Roblox Studio (Edit and solo Play), Luau through `mcp__Roblox_Studio__execute_luau`, git repo `CrimeLifeRoblox`, the CrimeLife Vault.

**Spec:** `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md` (sections 3, 7 and 10). Evidence: `CrimeLife Vault/90 Reference/Four Places Survey 2026-11-14.md`.

## Global Constraints

- **Target place:** the Studio instance whose name is `Crimelife city.rbxl`. Its id changes when Studio restarts: call `list_roblox_studios` at the start of every task and pick it by name. Never write to `FPS System.rbxl`, `Robbery System.rbxl`, `Test30.4` or any OBT place.
- **Never save, never publish.** The developer saves. Every report ends "NOT saved / NOT published" and reminds the developer to save.
- **No in-Studio fallback exists** (the developer chose to merge without a copy). Task 1 does not start until the developer confirms a Finder copy of `Crimelife city.rbxl` exists, or says to go without one.
- **Edit mode only for changes.** Stop Play before any change.
- **Heavy calls yield.** A `.Parent` write of a large subtree freezes Studio: move or destroy one top-level model per `execute_luau` call, and call `task.wait()` between chunks of at most 1,000 instances in loops.
- **`Workspace.ModelStreamingBehavior` must be `Legacy`** (OBT's tycoon core, ported in phase 5, loses plots under `Improved`).
- **Numbers are measured or marked "not recorded".** Take 3 readings a few seconds apart for anything frame-related; a collapsed viewport (`ViewportSize` 1, 1) makes frame numbers meaningless.
- **Models:** Sonnet executes tasks 1 to 7. Fable reviews the delete lists produced by tasks 2 and 3 **before** anything is destroyed or moved, and reviews the final report.
- **Six players, eight plates:** six plots are live, two are spare.
- The casino stays as a building; nothing playable is added to it.

## Review Focus

1. **A deleted script was driving something a player sees or needs** (a door, a light, a weld that holds a model together). Expected: nothing falls apart or goes dark. Pinned by Task 2 step 6 (unanchored-part count does not rise; before and after screenshots match).
2. **A "duplicate" building was a deliberate second location.** Expected: a far-apart copy is quarantined, not destroyed, and listed in the report. Pinned by Task 3 step 2's distance rule.
3. **Streaming hides the ground under a spawning player.** Expected: the player spawns standing, not falling. Pinned by Task 6 step 4.
4. **Streaming removes far landmarks the city relies on for orientation.** Expected: the developer sees the skyline change in the Task 6 screenshots and accepts it or names landmarks to keep persistent.
5. **A move of a 56,000-instance model freezes Studio and drops the connection mid-task.** Expected: the task resumes from the inventory file without redoing or double-moving. Pinned by Task 3 step 4 (each move re-checks the model's current parent first).

## File Structure

| Path | Responsibility |
|---|---|
| `CityCleanup/probe.luau` | The one measurement script. Returns a text report. Run unchanged before and after every task. |
| `CityCleanup/baseline-2026-11-14.md` | Probe output before any change, plus the agreed targets. |
| `CityCleanup/script-inventory.csv` | Every script in the city: path, class, name, lines, Adler-32, verdict, reason. |
| `CityCleanup/removed-scripts/<adler32>.luau` | One saved source per distinct script that is destroyed. |
| `CityCleanup/duplicates.md` | Each duplicate group: copies, positions, distance apart, verdict. |
| `CityCleanup/after-<task>.md` | Probe output after each task. |
| `CrimeLife Vault/70 Batches/2026-11-14 City Baseline and Cleanup.md` | The batch note. |

Studio layout produced by this plan:

```
Workspace
  Ground        (Model, Persistent: Baseplate; made in Task 6)
  Map
    City        (the existing City folder, moved in)
    Robbery     (Bank, SlowFoods, Gas2Go, NewsStation, CasinoMain, UnderGroundCasino, WareHouse models: one of each)
    Roads       (CityHighway1, Highway2, road unions)
    Props       (Palm_1, Light, Arrow, signs, small repeated models)
    Loose       (unnamed top-level Parts and Models not matched by the rules above)
  Plots         (Plot1 .. Plot8: the eight Lapis plates)
ServerStorage
  CityQuarantine
    Duplicates  (far-apart second copies)
    LooseTycoon (the tycoon pieces pasted loose into Workspace)
    Scripts     (kept-for-decision scripts, Disabled)
```

---

### Task 1: Baseline and targets (Phase 0)

**Files:**
- Create: `CityCleanup/probe.luau`, `CityCleanup/baseline-2026-11-14.md`

**Interfaces:**
- Produces: the probe. Later tasks run `CityCleanup/probe.luau` unchanged and diff against `baseline-2026-11-14.md`. Produces the **targets table** at the foot of the baseline file, which Task 7 checks against.

- [ ] **Step 1: Confirm the fallback.** Ask the developer: "Is there a Finder copy of `Crimelife city.rbxl`? Reply yes, or 'go without'." Do not continue without one of those two answers.

- [ ] **Step 2: Write `CityCleanup/probe.luau`.** It runs in Edit, yields every 20,000 descendants, and returns one string with these lines, in this order:

```
workspace_instances=<n>
baseparts=<n>  meshparts=<n>  unions=<n>
unanchored_parts=<n>
scripts_total=<n>  scripts_enabled=<n>
lights=<n>  particle_emitters=<n>  decals_textures=<n>
top_level_children=<n>
streaming_enabled=<bool>
top20_models: <name> <instances> (one per line, top-level and one level down, largest first)
serverstorage_instances=<n>
studio_memory=<game.Stats.PerformanceStats.Memory:GetValueString()>
```

- [ ] **Step 3: Run the probe in Edit** and save its output verbatim into `CityCleanup/baseline-2026-11-14.md`.
Expected: `workspace_instances` within 1% of 264,072 and `scripts_total` within 1% of 636 (the 2026-11-14 survey). A larger gap means the wrong place is attached or the file changed: stop and report.

- [ ] **Step 4: Take the Play reading.** Start solo Play. From a **Client** call read `workspace.CurrentCamera.ViewportSize` (must not be 1, 1), then 3 readings, 5 s apart, of `Stats.FrameRateManager` (`PerformAverage`, `RenderThreadAverage`, `Batches`) and `Stats:GetTotalMemoryUsageMb()`. Capture `get_console_output` and count error lines. Take 3 screenshots from fixed camera CFrames (record the CFrames in the baseline file: spawn view, a street-level view toward the Bank, an aerial view of the whole city). Stop Play. Append all of it to the baseline file.

- [ ] **Step 5: Propose targets and get them agreed.** Append a table to the baseline file with a **Baseline**, **Target** and **Why** column for: Workspace instances replicated to clients, enabled foreign scripts (target 0), console errors at join (target 0), unanchored map parts (target 0), client memory in Play, `PerformAverage`. Derive the instance target from the top-20 list: baseline minus every model Task 3 and Task 4 are expected to remove. Show the table to the developer and record their answer. The targets are theirs to change.

- [ ] **Step 6: Commit**

```bash
git add CityCleanup/probe.luau CityCleanup/baseline-2026-11-14.md
git commit -m "Batch: city baseline and targets"
```

---

### Task 2: Remove foreign scripts

**Files:**
- Create: `CityCleanup/script-inventory.csv`, `CityCleanup/removed-scripts/*.luau`, `CityCleanup/after-task2.md`

**Interfaces:**
- Consumes: the probe.
- Produces: `ServerStorage.CityQuarantine.Scripts` (Folder) holding every script with verdict `quarantine`, each with `Enabled = false` and a string attribute `OriginalPath`.

- [ ] **Step 1: Build the inventory.** For every `LuaSourceContainer` in `Workspace`, `ServerScriptService`, `StarterGui`, `StarterPlayer`, `Lighting` and `ReplicatedFirst`, write a CSV row: full path, class, name, line count, Adler-32 of `Source`, and whether the source contains any of `require(` followed by a number, `getfenv`, `loadstring`, `HttpService`, `InsertService`, `MarketplaceService`, `TeleportService`, `MessagingService` (plain `string.find`, one column per needle). Return the rows in chunks under 80,000 characters per call.
Expected: row count equals the probe's `scripts_total` plus the scripts in the other services.

- [ ] **Step 2: Assign verdicts by these rules, first match wins.**

| Rule | Verdict |
|---|---|
| Source contains a numeric `require`, `getfenv` or `loadstring` | `destroy` (unsafe) |
| Name is `Kill_25`, `DamageScript_25`, `Instructions Of Use`, `README`, `TheFix`, `Smooth Color Changing Script`, or anything under `HD Admin` | `destroy` |
| Belongs to a vehicle (ancestor Model contains a `VehicleSeat` or a `DriveSeat`) | `destroy` (cars come from OBT in phase 6; the vehicle stays as an anchored prop) |
| `DropperConfig`, `UpgraderConfig`, `OwnerOnlyDoorScript`, `CurrencyCollectorConfig`, `PartCollectorConfig`, or any script inside a loose tycoon piece | `destroy` (the kit is not used; see the spec, section 6) |
| `Animate` or `Animation` inside a `Rig` / `Dummy` | `destroy` (NPCs come from FPS System in phase 2) |
| Name contains `Weld` | `destroy`, and add its parent model to a **must-anchor** list |
| `Day/Night Cycle`, `MainLighting`, `DayCycleRotation`, `TimeScript`, everything under `StarterGui.TImeScripts`, `FirstPersonPhotoMode`, `Graphics  Script- ServerScriptService`, `ClientReplicator`, the `LocalScript` in `Lighting` | `quarantine` (lighting and time of day are decided in phase 2) |
| Anything else, including the unnamed `Script` instances | Group by Adler-32. Read one source per group. `destroy` if it only animates, spins, recolours, plays a sound or kills on touch; `quarantine` if it opens a door, runs a lift, or the reader cannot tell. Record the one-line reason. |

- [ ] **Step 3: Save sources.** For each distinct Adler-32 with verdict `destroy`, write its source to `CityCleanup/removed-scripts/<adler32>.luau` with a first-line comment naming one original path and the count of copies.

- [ ] **Step 4: Fable review gate.** Hand `script-inventory.csv` to the reviewer with the question "is any `destroy` row something the city needs?". Apply the reviewer's changes to the verdicts. Do not continue until the reviewer answers.

- [ ] **Step 5: Apply.** In Edit, in chunks of 200 scripts with `task.wait()` between: destroy the `destroy` rows; set `Enabled = false`, set `OriginalPath`, and move the `quarantine` rows into `ServerStorage.CityQuarantine.Scripts`. Then anchor every `BasePart` in every model on the must-anchor list.

- [ ] **Step 6: Verify.** Run the probe; save as `CityCleanup/after-task2.md`.
Expected: `scripts_enabled=0`; `unanchored_parts` not higher than baseline; `workspace_instances` lower than baseline by the number of scripts removed, give or take the instances parented under them. Start Play, read the console: zero error lines from Workspace scripts. Retake the 3 screenshots at the recorded CFrames and compare with the baseline set: buildings, roads and props unchanged. Stop Play.

- [ ] **Step 7: Commit**

```bash
git add CityCleanup/script-inventory.csv CityCleanup/removed-scripts CityCleanup/after-task2.md
git commit -m "Batch: city foreign scripts removed"
```

---

### Task 3: Duplicate buildings

**Files:**
- Create: `CityCleanup/duplicates.md`, `CityCleanup/after-task3.md`

**Interfaces:**
- Consumes: the probe's `top20_models`.
- Produces: `ServerStorage.CityQuarantine.Duplicates` (Folder). Exactly one copy of each robbery building remains in `Workspace`; Task 5 moves those into `Workspace.Map.Robbery`.

- [ ] **Step 1: Find the groups.** Two top-level models are a duplicate group when their names match after stripping a trailing `B` or digits, and their instance counts differ by less than 10%. Known from the survey: `WareHouseRobbery(NotUnderGroundPart)` x2, `Bank` x2, `CasinoMain` x2, `NewsStation` x2, `Gas2Go` x2, `SlowFoods` / `SlowFoodsB`, `Crime Band` x2, the `Dummy` x4 (693 each), `AI Dummy`. For each copy record its bounding-box centre and size.

- [ ] **Step 2: Decide each group by distance between centres.**

| Case | Action |
|---|---|
| Centres under 50 studs apart (pasted on top of each other) | Destroy the copy with fewer instances |
| Centres 50 studs or more apart | Keep the copy nearer the centre of the `City` folder's bounding box; move the other to `CityQuarantine.Duplicates` with attributes `OriginalCFrame` and `OriginalParent` |
| `AI Dummy` and the 693-instance `Dummy` models | Move all to `CityQuarantine.Duplicates` (test rigs, not map) |

Write the table (group, copies, centres, distance, verdict) to `CityCleanup/duplicates.md`.

- [ ] **Step 3: Fable review gate.** The reviewer reads `duplicates.md` and one aerial screenshot with the copies highlighted, and confirms or changes each verdict.

- [ ] **Step 4: Apply, one model per `execute_luau` call.** Each call first checks the model is still parented where the table says; if it is already in quarantine or gone, it reports "already done" and changes nothing. After each call, confirm the Studio connection with `list_roblox_studios` before the next.

- [ ] **Step 5: Verify.** Run the probe; save as `CityCleanup/after-task3.md`.
Expected: each group has exactly one copy under `Workspace`; `workspace_instances` dropped by the summed instance counts of the removed copies (within 1%); `serverstorage_instances` rose by the quarantined total. Retake the aerial screenshot.

- [ ] **Step 6: Commit**

```bash
git add CityCleanup/duplicates.md CityCleanup/after-task3.md
git commit -m "Batch: city duplicate buildings quarantined"
```

---

### Task 4: Loose tycoon pieces out of Workspace

**Files:**
- Create: `CityCleanup/after-task4.md`

**Interfaces:**
- Produces: `ServerStorage.CityQuarantine.LooseTycoon` (Folder). No tycoon piece remains in `Workspace`; the real HQ arrives from Test30.4 in phase 4.

- [ ] **Step 1: Find the cluster.** Take the bounding box of the top-level children named `TycoonSpawn`, `TycoonColorPart`, `CurrencyCollector`, `PartCollectingArea`, `Conveyor`, `Conveyor 2.0` and every top-level `Drop` and `UpgraderPart`. Grow it by 40 studs. A top-level child belongs to the cluster when its pivot lies inside that box **and** it is not inside the `City` folder and not one of the Task 3 buildings.
Expected: the cluster contains the outfit, bar, tailor, scrap, garden-wall, desk and cardboard models listed in the 2026-11-14 survey. Report the count and the box.

- [ ] **Step 2: Sanity check before moving.** If the box overlaps any of the eight Lapis plates or any Task 3 building, stop and report: the cluster rule is wrong for this layout.

- [ ] **Step 3: Move** the cluster's children into `CityQuarantine.LooseTycoon`, 100 top-level children per call, each stamped with `OriginalCFrame`.

- [ ] **Step 4: Verify.** Probe to `CityCleanup/after-task4.md`.
Expected: no top-level `Workspace` child named `TycoonSpawn`, `DropperConfig` or `Drop`; `top_level_children` dropped by the moved count. Screenshot the cluster's box: empty ground.

- [ ] **Step 5: Commit**

```bash
git add CityCleanup/after-task4.md
git commit -m "Batch: loose tycoon pieces quarantined"
```

---

### Task 5: Organise Workspace and name the plots

**Files:**
- Create: `CityCleanup/after-task5.md`

**Interfaces:**
- Produces: `Workspace.Map.{City,Robbery,Roads,Props,Loose}` and `Workspace.Plots.Plot1` to `Plot8`. Each plot Part has attributes `PlotIndex` (number 1 to 8) and `Spare` (boolean; true on exactly two). Phases 3 and 4 rely on these names.

- [ ] **Step 1: Create the folders** shown under File Structure.

- [ ] **Step 2: Move top-level children by these rules, first match wins**, 200 per call:

| Match | Destination |
|---|---|
| The `City` folder | `Map.City` (moved as one; one call) |
| `Bank`, `SlowFoods`, `Gas2Go`, `NewsStation`, `CasinoMain`, `UnderGroundCasino`, names starting `WareHouse` | `Map.Robbery` |
| `CityHighway1`, `Highway2`, any `UnionOperation` with material `Asphalt` | `Map.Roads` |
| A Part with `BrickColor` `Lapis` and size 300 x 1 x 361 | `Plots` |
| `Terrain`, `Camera`, `SpawnLocation`, `Baseplate` | stay |
| Any Model whose name occurs 5 or more times at top level (`Palm_1`, `Light`, `Arrow`, `TriangleOutside`, ...) | `Map.Props` |
| Everything else | `Map.Loose` |

- [ ] **Step 3: Name the plots.** Sort the eight plates by Z then X; name them `Plot1` to `Plot8`; set `PlotIndex`. Set `Spare = true` on the two farthest from the centre of `Map.City`'s bounding box, `false` on the other six. Anchor all eight.

- [ ] **Step 4: Anchor the map.** Set `Anchored = true` on every `BasePart` under `Workspace.Map` (chunks of 1,000 with `task.wait()`).

- [ ] **Step 5: Verify.** Probe to `CityCleanup/after-task5.md`.
Expected: `top_level_children` is 6 (`Map`, `Plots`, `Terrain`, `Camera`, `SpawnLocation`, `Baseplate`); `unanchored_parts=0`; `workspace_instances` equals the Task 4 figure plus the 6 new folders. `Workspace.Plots` has 8 children, 2 with `Spare = true`. Retake the 3 screenshots: unchanged from Task 3's.

- [ ] **Step 6: Commit**

```bash
git add CityCleanup/after-task5.md
git commit -m "Batch: city workspace organised, plots named"
```

---

### Task 6: Streaming and cheap part settings

**Files:**
- Create: `CityCleanup/after-task6.md`

**Interfaces:**
- Produces: a streamed city. Phase 2 can assume `StreamingEnabled = true`, `ModelStreamingBehavior = Legacy`.

- [ ] **Step 1: Set streaming.** Try by script: `workspace.StreamingEnabled = true`, `ModelStreamingBehavior = Legacy`, `StreamingIntegrityMode = PauseOutsideLoadedArea`, `StreamOutBehavior = Opportunistic`, `StreamingMinRadius = 128`, `StreamingTargetRadius = 512`. These radii are starting values. If any write is refused ("lacking capability"), stop and ask the developer to set exactly those six values in the Properties panel, then read back what can be read.

- [ ] **Step 2: Keep the ground and plots persistent.** Create Model `Workspace.Ground`, move `Baseplate` into it, and set `ModelStreamingMode = Persistent` on it. Wrap the eight plates the same way: make `Workspace.Plots` a Model (not a Folder) with `ModelStreamingMode = Persistent`. `Terrain` is always present and needs nothing.

- [ ] **Step 3: Cheap part settings.** Under `Workspace.Map`, in chunks of 1,000: `CanTouch = false` on every `BasePart`; `CastShadow = false` on every `BasePart` whose largest dimension is under 2 studs. Count how many of each were changed.

- [ ] **Step 4: Verify the spawn.** Start Play. From a Client call, within one call: wait for the character, then sample `HumanoidRootPart.Position.Y` every 0.25 s for 5 s.
Expected: Y stays within 5 studs of its first value (the player is standing, not falling). Read the console: zero errors.

- [ ] **Step 5: Measure.** Same Play session: the 3 `FrameRateManager` readings, `Stats:GetTotalMemoryUsageMb()`, and from the Client `#workspace:GetDescendants()` (the streamed-in count). Retake the 3 screenshots. Stop Play. Probe in Edit. Save everything to `CityCleanup/after-task6.md`.
Expected: the Client's streamed-in instance count is below the Edit `workspace_instances`.

- [ ] **Step 6: Show the developer** the baseline and Task 6 screenshot sets side by side, and ask whether any far landmark that vanished must stay visible. Any they name gets `ModelStreamingMode = Persistent`.

- [ ] **Step 7: Commit**

```bash
git add CityCleanup/after-task6.md
git commit -m "Batch: city streaming on"
```

---

### Task 7: Check against targets and record the batch

**Files:**
- Create: `CrimeLife Vault/70 Batches/2026-11-14 City Baseline and Cleanup.md`
- Modify: `CrimeLife Vault/70 Batches/Batch Log.md` (new top row), `CrimeLife Vault/90 Reference/Four Places Survey 2026-11-14.md` (add an "After cleanup" section; do not rewrite the measured baseline), `CrimeLife Vault/90 Reference/Places and Studio Windows.md` (Crimelife City as the merge target, the `Map` / `Plots` / `CityQuarantine` layout), `CrimeLife Vault/60 Open Items/Open Items.md`, `CrimeLife Vault/50 Engine Traps/Streaming and Replication Traps.md` (only if a trap cost time)

**Interfaces:**
- Consumes: the targets table from Task 1 and every `after-*.md`.

- [ ] **Step 1: Fill the targets table's "Result" column** from `after-task6.md`. For each target write met or missed, with the number.

- [ ] **Step 2: If the instance target is missed,** list the 10 heaviest remaining models from the probe with their counts and put them in Open Items as candidates for simplification. Do not simplify art in this plan: the design keeps the city's look, and which buildings to thin is the developer's call.

- [ ] **Step 3: Write the batch note** from `Templates/Batch Note Template.md`: asked for, what changed, before and after numbers, what was destroyed (with the `removed-scripts` path), what sits in `CityQuarantine` and how to move it back (`OriginalCFrame`, `OriginalParent`, `OriginalPath`), disproved theories, verified and not verified. Not verified by this plan, to state plainly: real phone performance, anything with two players, the look of the city under streaming on a low-end device.

- [ ] **Step 4: Update the other vault notes** listed under Files. New Open Items: decide lighting and time of day from `CityQuarantine.Scripts`; decide the fate of `CityQuarantine.Duplicates`; the developer saves the place.

- [ ] **Step 5: Fable reviews** the batch note against the `after-*.md` files: every number in the note appears in a probe output.

- [ ] **Step 6: Commit, and report.**

```bash
git add "CrimeLife Vault" CityCleanup
git commit -m "Batch: city baseline and cleanup"
```

The report to the developer ends: "NOT saved / NOT published. Please save `Crimelife city.rbxl`."

---

## What this plan does not do

Phases 2 to 6 of the design each get their own plan, written after this one's numbers are in: the FPS port depends on what streaming and the cleaned layout turn out to be.
