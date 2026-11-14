# FPS Systems Into the City Implementation Plan (Phase 2a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring every FPS System service, asset and gameplay anchor into Crimelife City unchanged, prove it behaves there as it does in the FPS place, then move the enemies and quest givers from a test area into the city.

**Architecture:** Roblox Studio serializes whole folders with `SerializationService`, posts them to a localhost-only store on this Mac, and the city window fetches and deserializes them. Nothing passes through an agent's context and no source is retyped, so the copies are exact. The FPS place's Workspace content sits around the world origin, and so does the city's now-empty staging slab: the anchors land on the slab at their original coordinates, which gives a like-for-like first run before anything is moved into the city.

**Tech Stack:** Roblox Studio (two windows), Luau through `mcp__Roblox_Studio__execute_luau`, `SerializationService`, `EncodingService`, `HttpService`, Python 3 standard library for the store, git repo `CrimeLifeRoblox`, the CrimeLife Vault.

**Spec:** `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md` (sections 3, 7 row "2. FPS in", 9). State of the city: `CrimeLife Vault/70 Batches/2026-11-14 City Baseline and Cleanup.md` and `CrimeLife Vault/20 Systems/City Map and Plots.md`.

**Proven on 2026-11-15 (spike, nothing kept):** `SerializationService:SerializeInstancesAsync({ReplicatedStorage.Blaster})` gave 873,531 bytes; a 1,164,708-character Base64 body posted from the FPS window to `http://127.0.0.1:8765` and fetched in the city window deserialized to 1,554 descendants and 21 scripts with 106,794 source characters, matching the source. A service itself (`StarterGui`) cannot be serialized; its children can.

## Global Constraints

- **Source place:** the Studio instance NAMED `FPS System.rbxl`. It is **read-only** for this whole plan: no property writes, no parenting, no Destroy, no save. Play is allowed there only in Task 1 to record the test baseline.
- **Target place:** the Studio instance NAMED `Crimelife city.rbxl`. Ids change when Studio restarts: resolve both by name with `list_roblox_studios` at the start of every task. Never touch `Robbery System.rbxl`, `Test30.4` or any OBT place.
- **Never save, never publish.** The developer saves. Every report ends "NOT saved / NOT published".
- **Changes are made in Edit mode.** Stop Play before any change.
- **Copies are exact.** No script source is edited in this plan. A script that needs changing to run in the city is reported, not patched; fixes belong to Phase 2b.
- **Everything imported is stamped** with string attribute `ImportedFrom = "FPS System"` on its root, so the import can be found and undone.
- **The city's lighting stays.** FPS System's `Lighting` children are not imported.
- **City invariants from Phase 1 hold after every task:** `Workspace.StreamingEnabled = true`; `Workspace.Map`, `Workspace.Plots` (`Plot1`..`Plot8`), `Workspace.Ground` unchanged; `ServerStorage.CityQuarantine` untouched; every BasePart under `Workspace.Map` anchored.
- **Heavy calls yield:** `task.wait()` between roots; one root over 100,000 serialized bytes per `execute_luau` call.
- **The store listens on 127.0.0.1 only** and is stopped at the end of every task that starts it. Its data directory is outside the repo and deleted when the import is verified.
- **Unit tests run in a fresh Play session, Server datamodel**, from a temporary server `Script`, never from Edit (`CrimeLife Vault/40 Tools/Unit Test Runner.md`).
- **Numbers are measured or "not recorded".**
- **Models:** Opus implements; Sonnet may do Task 1's inventory; Fable reviews each task and gates Task 5's placement list.

## Review Focus

1. **A script reaches for a Workspace path that does not exist in the city** (the FPS place's `Workspace.Map` is not the city's `Workspace.Map`). Expected: found before the first run, not as a runtime error. Pinned by Task 1 step 4 (the path table) and Task 4 step 2 (zero new console errors).
2. **Tags or attributes lost in transit.** The blaster, enemy spawner, pickups and UI theme find things by tag. Expected: identical tag counts. Pinned by Task 2 step 4 and Task 3 step 4.
3. **A Workspace anchor lands inside or under city geometry on the slab.** Expected: every anchor's Y matches the FPS place and nothing overlaps `Plot7`, `Plot8` or the city's corner. Pinned by Task 3 step 2.
4. **Streaming hides something a server script expects on the client** (a viewmodel folder, a quest giver the prompt UI looks up). Expected: the same client-visible roots exist in a city Play as in an FPS Play. Pinned by Task 4 step 3.
5. **Two SpawnLocations make spawning random.** Expected: exactly one enabled spawn at any time, stated in every report. Pinned by Task 3 step 5 and Task 5 step 5.

## File Structure

| Path | Responsibility |
|---|---|
| `CityMerge/transfer/server.py` | Localhost-only store: `POST /<name>` saves a body, `GET /<name>` returns it. Already in the repo from the spike. |
| `CityMerge/transfer/export.luau` | Run in the FPS window: serializes a list of roots and posts each. Returns a manifest line per root. |
| `CityMerge/transfer/import.luau` | Run in the city window: fetches one root, deserializes, stamps, parents. Refuses to overwrite an existing child of the same name. |
| `CityMerge/fps-manifest.md` | What exists in the FPS place: per root, instances, scripts, serialized bytes; per script, path and Adler-32; tag counts; service settings. |
| `CityMerge/fps-workspace-paths.md` | Every `workspace` / `Workspace` path the FPS scripts reference, with the script and line. |
| `CityMerge/fps-test-baseline.md` | Unit-test results in the FPS place: per suite, run / passed / failed, and the names of failing tests. |
| `CityMerge/after-import.md` | The same manifest measured in the city, diffed against `fps-manifest.md`. |
| `CityMerge/first-run.md` | Console, tests and client checks from the first city Play. |
| `CityMerge/placement.md` | Proposed and applied city positions for enemy spawns and quest givers. |
| `CrimeLife Vault/70 Batches/2026-11-15 FPS Systems Into City.md` | The batch note. |

**What is imported, and where it lands**

| From FPS System | Into the city | Notes |
|---|---|---|
| `ReplicatedStorage.*` except `__ProbeOutside` | `ReplicatedStorage` | 18 roots |
| `ServerScriptService.*` | `ServerScriptService` | all 16 roots, `UnitTestRunner` stays `Disabled` |
| `ServerStorage`: `ProfileStore`, `UnitTest`, `Weapons`, `Cash`, `EnemyTemplates`, `RBX_ANIMSAVES`, `WeaponViewmodelMotionTests`, `WeaponClassMotionTests`, `MeleeStabilityTests` | `ServerStorage` | beside `CityQuarantine` |
| `StarterGui.*` (3) | `StarterGui` | the city's existing `StarterGui` children are listed first; none are removed |
| `StarterPlayer.StarterPlayerScripts.*`, `StarterCharacterScripts.*` | the same containers | |
| `SoundService.Main` | `SoundService` | |
| `Workspace`: `EnemySpawns`, `Quests`, `Targets`, `AnimVM`, `Accessory Storage` | top level of `Workspace`, same names | scripts look these up by name |
| `Workspace.Map` (23 instances), `Workspace.UI`, `Workspace.Part`, `Workspace.Model` | `Workspace.Dev.FpsMap`, `Workspace.Dev.UI`, `Workspace.Dev.Part`, `Workspace.Dev.Model` | renamed container because the city already has `Workspace.Map`; see Task 1 step 4 for the rule if a script needs the old path |
| `Workspace.SpawnLocation` | `Workspace.Dev.DevSpawn` | `Enabled = false` except during the Task 4 run |

**Left behind in the FPS place** (reported in the batch note): `ServerStorage.ArchivedWeaponPickups`, `Gun Pack`, `__MeshProbe`, `Body`; `ReplicatedStorage.__ProbeOutside`; `Workspace."UI Animation Pack - by JakeDev"` (an open item asks whether to delete it); `Workspace.Baseplate`, `Terrain`, `Camera`; all `Lighting` children.

**Settings copied by value** (Task 2 step 5): `StarterPlayer.CameraMaxZoomDistance = 30`, `CharacterWalkSpeed = 25`, `CharacterUseJumpPower = false`, `CharacterJumpHeight = 7.2`, `EnableMouseLockOption = true`, `LoadCharacterAppearance = true`; `Players.RespawnTime = 3`; `Workspace.FallenPartsDestroyHeight = -500`. Collision groups: the FPS place registers none beyond `Default`.

---

### Task 1: Transfer tool, FPS manifest and test baseline

**Files:**
- Create: `CityMerge/transfer/export.luau`, `CityMerge/transfer/import.luau`, `CityMerge/fps-manifest.md`, `CityMerge/fps-workspace-paths.md`, `CityMerge/fps-test-baseline.md`
- Existing: `CityMerge/transfer/server.py`

**Interfaces:**
- Produces: `export.luau` exposing `export(roots: {Instance}, prefix: string) -> {string}` (one manifest line per root: name, class, descendants, scripts, bytes, store key). Store key format: `<prefix>__<index>__<sanitised name>.b64`, sanitised to `[A-Za-z0-9_.-]`.
- Produces: `import.luau` exposing `import(key: string, parent: Instance, newName: string?) -> Instance`, which errors if `parent` already has a child with the final name, sets `ImportedFrom = "FPS System"` on the root, and returns it.
- Produces: `fps-manifest.md`, the reference every later task diffs against.

- [ ] **Step 1: Write `export.luau` and `import.luau`** to the interfaces above. Base64 through `EncodingService`; bodies posted with `HttpService:RequestAsync` to `http://127.0.0.1:8765/<key>`; one root per request.

- [ ] **Step 2: Round-trip test, nothing kept.** Start `server.py` with a data directory in the session scratchpad. In the FPS window export `ReplicatedStorage.Persistence` with prefix `test`. In the city window fetch and deserialize it **without parenting**, and compare with the source: descendant count 1, and Adler-32 of `Schema.Source` equal on both sides. Destroy the unparented copy.
Expected: equal hashes. Then confirm the city's `#workspace:GetDescendants()` is unchanged (118,679 at the end of Phase 1; record the number read).

- [ ] **Step 3: Write `fps-manifest.md`** from the FPS window, read-only: for every root in the File Structure table, descendants, scripts and serialized bytes; for every `LuaSourceContainer` in those roots, full path, class, `Enabled` and Adler-32; `CollectionService` tag counts restricted to instances inside those roots; the settings listed under "Settings copied by value" as read; the world bounding box of each Workspace root to be imported and the top Y of the FPS `Baseplate`.

- [ ] **Step 4: Write `fps-workspace-paths.md`.** Search every script in the manifest for `workspace` and `Workspace` followed by `.`, `:FindFirstChild`, `:WaitForChild` or `[`. One row per hit: script path, line number, the path referenced. Then a summary: the distinct top-level Workspace names the code needs.
**Rule:** a name the code needs must exist at that exact path in the city. If the code references `Workspace.Map` (the FPS one), stop and report it with the script and lines: the city's `Workspace.Map` is the city map, and resolving that clash is a decision, not a guess.

- [ ] **Step 5: Record the FPS test baseline.** In the FPS window start Play. From a temporary server `Script` (created in Play, so it is discarded when Play stops) run `require(ServerStorage.UnitTest.RunUnitTest)("")` and, per suite, record run / passed / failed and the names of failing tests into `fps-test-baseline.md`. Also save the console's distinct error lines after 15 s. Stop Play; confirm the FPS window is in Edit and its instance counts equal the manifest's.
Expected: the totals are written down whatever they are. This is the reference, not a gate.

- [ ] **Step 6: Stop the store. Commit.**

```bash
git add CityMerge
git commit -m "Batch: FPS manifest, transfer tool and test baseline"
```

---

### Task 2: Import code and assets (everything outside Workspace)

**Files:**
- Create: `CityMerge/after-import.md`

**Interfaces:**
- Consumes: `export`, `import`, `fps-manifest.md`.
- Produces: the FPS services present in the city under the same names and paths. Task 3 adds the Workspace roots; Task 4 runs it.

- [ ] **Step 1: Record the city's "before".** List the existing children of `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPlayer.StarterPlayerScripts`, `StarterPlayer.StarterCharacterScripts`, `SoundService`, with instance counts. Expected from Phase 1: only `ServerStorage.CityQuarantine` (plus `TerrainSaveData`) and whatever the city's `StarterGui` holds. Any name that an import would collide with: stop and report.

- [ ] **Step 2: Export** from the FPS window, prefix `p2`, the roots in the first six rows of the File Structure table. Save the returned manifest lines.

- [ ] **Step 3: Import** each into its container in the city, one root per call for anything over 100,000 bytes (`Blaster`, `Weapons`, `EnemyTemplates`, `GuiTemplates`). Confirm the connection after each heavy call.

- [ ] **Step 4: Verify against the manifest**, written to `CityMerge/after-import.md`: per root, descendants and scripts equal; every script's Adler-32 equal at the same relative path (report the count compared and the count equal: they must be the same number); tag counts inside the imported roots equal the manifest's; `UnitTestRunner.Disabled` is still true; every root carries `ImportedFrom`.
Expected: zero differences. A difference is a failed import of that root: destroy the imported root, re-export, re-import, re-verify.

- [ ] **Step 5: Copy the settings by value** listed in File Structure. Record each before and after.

- [ ] **Step 6: Check the city invariants** (Global Constraints) and that `ServerStorage.CityQuarantine` has the same descendant count as before (143,371 inside the four folders plus the folders themselves; read it before Step 3 and compare).

- [ ] **Step 7: Stop the store. Commit.**

```bash
git add CityMerge/after-import.md
git commit -m "Batch: FPS services imported into the city"
```

---

### Task 3: Import the gameplay anchors onto the slab

**Files:**
- Modify: `CityMerge/after-import.md` (add a Workspace section)

**Interfaces:**
- Consumes: `fps-manifest.md` (bounding boxes, Baseplate top Y), `fps-workspace-paths.md`.
- Produces: `Workspace.EnemySpawns`, `Workspace.Quests`, `Workspace.Targets`, `Workspace.AnimVM`, `Workspace."Accessory Storage"`, and `Workspace.Dev` (Folder) holding `FpsMap`, `UI`, `Part`, `Model`, `DevSpawn`.

- [ ] **Step 1: Height check.** Compare the FPS `Baseplate` top Y from the manifest with the top Y of the city's `Workspace.Ground.Baseplate` (expected 0 for both). If they differ, every imported Workspace root is shifted by the difference with `PivotTo`, and the shift is recorded.

- [ ] **Step 2: Clash check before importing.** For each Workspace root's bounding box from the manifest: it must lie inside the slab footprint (|x| <= 1024, |z| <= 1024); it must not intersect the footprints of `Plot7` (centre (720.5, -207)) or `Plot8` (centre (544.5, 229)), each 300 by 361 rotated 90 degrees; and a region query of the same box in the city must return no BasePart from `Workspace.Map`.
Expected: no clash. A clash is reported with the root and the overlapping parts; that root is imported shifted along X by the smallest multiple of 100 studs that clears it, and the shift is recorded.

- [ ] **Step 3: Export and import** the Workspace roots, prefix `p2w`, to the destinations in the File Structure table. Rename on import where the table says so. Set `DevSpawn.Enabled = false`.

- [ ] **Step 4: Verify.** Per root: descendants, scripts, script hashes and tag counts equal the manifest (`EnemySpawnPoint` 6, `NPCprompt` 6, `Target` 7, `WeaponPickup` and `Blaster` as the manifest says for these roots). Positions: the pivot of each root equals the FPS pivot plus any recorded shift.

- [ ] **Step 5: Spawns and streaming.** Exactly one enabled `SpawnLocation` exists (the city's at about (-11, 1.5, 2498.75)). Set `ModelStreamingMode = Persistent` on `Workspace.Dev` only if it is a Model; it is a Folder, so instead record that the slab is 2,500 studs from the city spawn and is streamed out for a player there, which is intended.

- [ ] **Step 6: Run `CityCleanup/probe.luau`** and append its output to `after-import.md`. Expected: `unanchored_parts` equals the unanchored parts inside the imported roots as counted in the FPS place (state both numbers), `scripts_enabled` equals the enabled Workspace scripts in the manifest for these roots, and nothing under `Workspace.Map` changed (97,888 BaseParts, 0 unanchored).

- [ ] **Step 7: Stop the store, delete its data directory. Commit.**

```bash
git add CityMerge/after-import.md
git commit -m "Batch: FPS gameplay anchors imported onto the slab"
```

---

### Task 4: First run in the city, against the FPS baseline

**Files:**
- Create: `CityMerge/first-run.md`

**Interfaces:**
- Consumes: `fps-test-baseline.md`.
- Produces: the list of differences between the city run and the FPS run. Phase 2b starts from this list.

- [ ] **Step 1: Spawn at the slab for this run.** In Edit: `Dev.DevSpawn.Enabled = true`, the city `SpawnLocation.Enabled = false`. Record both.

- [ ] **Step 2: Console.** Start Play, wait 20 s, save the console's distinct error and warning lines.
Expected: the set of distinct lines equals the FPS baseline's set plus the 9 asset-permission lines recorded for the city on 2026-11-14. Every line in neither set is listed with the script that raised it.

- [ ] **Step 3: Client checks, in one Client call.** `PlayerGui` children and, for each ScreenGui the FPS baseline shows, `Enabled` and the `AbsoluteSize` of its first frame; the children of `StarterPlayerScripts` as running under `PlayerScripts`; the character's `Humanoid.WalkSpeed`; whether `Workspace.EnemySpawns`, `Workspace.Quests` and the viewmodel container exist on the client. Take the same readings in an FPS-place Play and put the two columns side by side.
Expected: identical lists; sizes equal for the same viewport.

- [ ] **Step 4: Unit tests.** From a temporary server `Script` run every suite as in Task 1 step 5.
Expected: per suite, the same run count and the same set of failing test names as the baseline. A test that passes in FPS and fails in the city is listed with its error text.

- [ ] **Step 5: Server checks.** After 30 s: the count of live enemies and the spawn points they came from; `leaderstats.Cash` equals the schema's starting cash (500); the profile is bound (read through a temporary server Script, not from the plugin VM).

- [ ] **Step 6: Stop Play. Restore the spawns** (`DevSpawn.Enabled = false`, city spawn enabled). Confirm Edit mode and the city invariants.

- [ ] **Step 7: Write `first-run.md`:** what matched, what differed, and for each difference the most likely cause from the code (a missing path, a streaming assumption, a setting). No fixes are made here.

- [ ] **Step 8: Commit.**

```bash
git add CityMerge/first-run.md
git commit -m "Batch: FPS systems first run in the city"
```

**Gate:** if a test that passes in FPS fails in the city, or the console shows an error from an imported script that the FPS baseline lacks, Task 5 does not start. The run stops, and the difference list goes to the developer with a proposed fix for each, because fixing means editing source and this plan copies exactly.

---

### Task 5: Move the play into the city

**Files:**
- Create: `CityMerge/placement.md`

**Interfaces:**
- Consumes: a clean Task 4.
- Produces: `Workspace.EnemySpawns` points and the quest givers under `Workspace.Quests` standing in the city near the city spawn. `Workspace.Targets` (the shooting range) and `Workspace.Dev` stay on the slab.

- [ ] **Step 1: Read how placement is defined.** From the imported code and the vault notes `20 Systems/Enemies and Spawner.md` and `20 Systems/Quests and Dialogue.md`: what a spawn point is (a Part tagged `EnemySpawnPoint`, and which attributes it carries), what makes up one quest giver (model, prompt, tag `NPCprompt`), and whether any script stores absolute positions. Write the answer at the top of `placement.md`.

- [ ] **Step 2: Propose positions (dry run, nothing moved).**
  - **Enemy spawn points (6):** candidates on a ring 180 studs from the city `SpawnLocation`, every 15 degrees. For each, raycast straight down from Y + 200 against `Workspace.Map` only. Accept a candidate when the hit part's ancestor is `Map.City.Roads` or `Map.City.FootPaths`, the hit normal is within 10 degrees of vertical, and a 6 by 12 by 6 box above the hit is empty. Take the first six accepted that are at least 60 studs apart.
  - **Quest givers:** a row along the nearest `FootPaths` part to the city spawn, starting 40 studs from the spawn, 14 studs apart, each facing the spawn, feet on the surface found by the same raycast.
  - Write a table: item, old position, proposed position, hit part name, distance from spawn. Take one aerial screenshot with the proposed points marked by temporary neon parts, then delete the markers.

- [ ] **Step 3: Fable gate.** The reviewer reads `placement.md` and the screenshot and confirms or changes each position. These positions are provisional: the developer will re-place by hand.

- [ ] **Step 4: Apply.** `PivotTo` each spawn point and each quest giver model. Nothing else moves. Record old and new CFrames in `placement.md` (the old ones are the way back).

- [ ] **Step 5: Run it.** City spawn enabled, `DevSpawn` disabled. Start Play. Within 60 s: enemies are alive within 300 studs of the character (count, and nearest distance); each quest giver model is present on the client within the streaming radius, standing (its root part's Y is within 1 stud of the proposed Y); the console shows no line that Task 4 did not. Then run the unit tests once more: the same result as Task 4.
Expected: all hold. Stop Play; confirm Edit and the invariants.

- [ ] **Step 6: Commit.**

```bash
git add CityMerge/placement.md
git commit -m "Batch: enemies and quest givers placed in the city"
```

---

### Task 6: Record the batch and change the project rule

**Files:**
- Create: `CrimeLife Vault/70 Batches/2026-11-15 FPS Systems Into City.md`
- Modify: `CrimeLife Vault/70 Batches/Batch Log.md` (new top row), `CrimeLife Vault/10 Rules/Which Project This Is.md`, `CrimeLife Vault/00 Start/Start Here.md`, `CrimeLife Vault/90 Reference/Places and Studio Windows.md`, `CrimeLife Vault/20 Systems/City Map and Plots.md`, `CrimeLife Vault/60 Open Items/Open Items.md`, `CrimeLife Vault/80 Decisions/CrimeLife Tycoon Decisions.md`

- [ ] **Step 1: Batch note** from the template: asked for, what changed, the manifest diff (zero differences or the list), the first-run comparison, the placement table, what was left behind in the FPS place, verified and not verified. Not verified, to state plainly: anything needing a person at the keyboard (shooting feel, pressing E on a quest giver, the shop by real clicks), two players, a phone, persistence on a published place.

- [ ] **Step 2: Change the rule.** From this batch the primary place is **Crimelife City** (`Roblox Games/Crimelife city.rbxl`); `FPS System.rbxl` is frozen as the reference the port was taken from and is not edited. Update `Which Project This Is`, `Start Here` and `Places and Studio Windows` to say so, dated 2026-11-15, and record it in `CrimeLife Tycoon Decisions` as Claude's call following from the approved design (the developer chose the city as the merge target on 2026-11-14). The repo mirrors in `FPSSystem/` stay where they are and now mirror the city's copies.

- [ ] **Step 3: Open Items.** Add: `Documents/Roblox/CLAUDE.md` still names FPS System as the primary place (the developer's file; one line to change). Add everything from `first-run.md` that needs a fix. Add Phase 2b's three carried items if not already listed: the remote ownership audit, the eleven `ZIndexBehavior.Global` ScreenGuis, quest progress not saved. Add: positions from Task 5 are provisional.

- [ ] **Step 4: Commit and report.**

```bash
git add "CrimeLife Vault" CityMerge
git commit -m "Batch: FPS systems into the city"
```

The report ends: "NOT saved / NOT published. Please save `Crimelife city.rbxl`."

---

## What this plan does not do

**Phase 2b (its own plan, written from `first-run.md`):** the fixes the design assigns to phase 2 that need source changes and tests: the remote ownership audit, the eleven `ZIndexBehavior.Global` ScreenGuis, saving quest progress, and whatever the first run shows. They are kept out of this plan so that the port stays an exact copy and any difference in behaviour can only come from the place, not from an edit.

Robbery (phase 3), plots and the HQ (phase 4), the tycoon core (phase 5) and the haul (phase 6) follow.
