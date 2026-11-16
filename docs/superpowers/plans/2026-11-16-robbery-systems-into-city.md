# Phase 3: Robbery Systems Into the City Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The four heists of the Robbery System place (Bank, SlowFoods, Gas2Go, NewsStation) run in `Crimelife city.rbxl`, at the city's own robbery buildings, and bank their cash into the one `leaderstats.Cash` that `CashService` owns and saves.

**Architecture:** The same transfer as phase 2a (serialize in one Studio window, POST to the local store, deserialize in the other). Each location's scripted models replace the city's art building by one rigid move, so no script path inside the Robbery code changes. The Robbery place's own currency module is replaced at the same path by a thin bridge onto `leaderstats.Cash`; its save layer stays behind. Shared UI modules come over once: where the city already holds a copy, the city's copy is used.

**Tech Stack:** Luau in Roblox Studio; `Roblox_Studio` MCP; `CityMerge/transfer/` (`server.py`, `export.luau`, `import.luau`, `export-source.luau`); the city's `ServerStorage.UnitTest.RunUnitTest` and the Robbery place's `ReplicatedStorage.HeistShared` runner (`TestRunner` / `RunAll` over `ServerScriptService.Heist.Tests`).

**Spec:** `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`: section 7 (phase 3 row: "Swap the city's unscripted robbery buildings for the Robbery place's scripted ones; move robbery cash onto `CashService`; one copy of each shared UI module." Done when "The heist specs pass; a heist banks into `leaderstats.Cash`"), section 9 (cash unification, `CashClaimVFX` and the two config specs, remote audit), section 10 ("The city's layout wins ... Getaway distances are re-measured there"). Vault: `20 Systems/Robbery Heists and Getaway.md`, `Robbery Puzzles.md`, `Robbery Prompts.md`, `80 Decisions/Robbery Decisions.md`.

**Models:** Fable writes the gates and rulings and reviews. Sonnet runs Task 1 and Task 6. Opus builds Tasks 2 to 5.

**Before running:** the developer opens `Crimelife city.rbxl` and `Robbery System.rbxl` in Studio with the MCP plugin on. Saving the city at checkpoints needs the developer's word for that run; the permission given for phase 2b does not carry over.

## Global Constraints

- Target place: **`Crimelife city.rbxl`**, resolved by name with `list_roblox_studios` before every write.
- `Robbery System.rbxl` and `FPS System.rbxl` are frozen references: Play and read only, no edit, no save. `Test30.4` and every OBT place are not touched.
- Never publish. Save the city only if the developer said so for this run; every report ends with the save state.
- **One cash figure.** Only `CashService` creates `leaderstats`; nothing else creates or replaces `leaderstats.Cash`. Robbery cash is written to `leaderstats.Cash` on the server and is saved by `CashService`'s existing listener. No second balance, no second DataStore.
- **One save system.** Only `ProfileGateway` requires ProfileStore or touches a DataStore. The Robbery place's own save code is not imported. `Schema.VERSION` stays 3.
- Every imported root carries attribute `ImportedFrom = "Robbery System"`. Every script edited after import carries `CityMergeDeviation` (append with "; " where one exists) and a row in `CityMerge/after-import.md`, Adler-32 before and after.
- Edited and created sources are exported to `CityScripts/<FullName>.luau` and checked by Adler-32 against the place.
- Baselines to hold: the city's 16 suites **171 / 171 / 0**; the heist suite's failure **set** (by spec and case name, never just the count) is compared, not its total.
- After every task: exactly one enabled `SpawnLocation` in Workspace (`Workspace.SpawnLocation`), no temporary object left, the city's `Workspace.HQ` untouched (the developer's paste; not this plan's to move).
- Remote verdict rule (as in phase 2b): FIX only when a client can (a) act on something it does not own, (b) get an untyped, NaN or out-of-range value written into state or a save, or (c) gain cash, an item or progress without doing the thing. A missing rate limit alone is OK plus a note, unless 100 calls a second does (c) or throws.
- Numbers in every written file are measured in this run or say "not recorded". Git: one commit per task named `Batch: <topic>`, staged by explicit path, `.DS_Store` never, nothing pushed. No key, token, UserId or personal detail in any file.

## Review Focus

1. **A heist voided mid-haul** (death, timer out, player leaves): nothing is banked, `leaderstats.Cash` and the saved profile cash do not move, and no error is logged. Pinned in Task 4.
2. **Banking once.** A claim credits each participant once; a second claim, or the getaway firing twice, pays nothing more. Pinned by the heist specs (the "dupe fix") and a Task 4 Play check.
3. **Streaming while escaping.** At 150 and 250 studs from the location (past the 128-stud minimum radius) the getaway widget still shows the right distance and banks at 200; status badges over far locations still show their state. Pinned in Task 4.
4. **Robbery cash is saved.** After a bank, the profile's `cash` equals `leaderstats.Cash`. Pinned in Task 4.
5. **Two HUDs on one screen.** Robbery HUD elements (timer, duffel bar, getaway widget, toasts) do not overlap the city's HUD at 1080 x 659 or at 844 x 390 (a phone in landscape). Pinned in Task 4.

---

## File Structure

| Path | Role |
|---|---|
| `CityMerge/phase3/robbery-manifest.md`, `.tsv` | Every Robbery root: class, descendants, scripts, store key; one row per script with Adler-32. |
| `CityMerge/phase3/classification.md` | Each root's verdict (carry / use city copy / leave behind / bridge) and each name collision's ruling. Written in Task 1, ruled at the gate. |
| `CityMerge/phase3/currency-api.md` | The Robbery `CurrencyService`'s public API and every caller. |
| `CityMerge/phase3/locations.md` | Per location: Robbery root set and bounds, the city art counterpart and bounds, the transform, fit and overlap checks, getaway measurements. |
| `CityMerge/phase3/spec-baseline.md` | Heist suite run in the Robbery place: totals and the failure set by name. |
| `CityMerge/phase3/client-load-order-audit.md` | Robbery client lookups under the city's streaming, as in phase 2a. |
| `CityMerge/phase3/remote-audit.md` | One row per Robbery client-to-server remote. |
| `CityMerge/phase3/first-run.md`, `final-run.md` | Task 4 and Task 6 measurements. |
| `CityScripts/*.luau` | Exports of every script created or edited in the city. |

---

### Task 1: Survey, manifest, baselines (two legs, controller gate between)

**Files:** Create the five `CityMerge/phase3/` files named above for this task (`robbery-manifest.*`, `classification.md`, `currency-api.md`, `locations.md` first half, `spec-baseline.md`).

**Interfaces:**
- Produces: store keys `rob__<n>__<name>.b64`; the gate-approved `classification.md` and per-location transforms that Tasks 2 and 3 apply verbatim; `currency-api.md`, which Task 2 implements.

Skills to load: `roblox-studio-mcp`.

**Leg 1: measure (no write to either place)**

- [ ] **Step 1: Transfer store up.** `lsof -ti tcp:8765 | xargs kill`, then `python3 CityMerge/transfer/server.py <scratch dir>` in the background (it needs the root directory argument). `curl` a missing key returns `404`.

- [ ] **Step 2: Manifest.** In the Robbery window: every child of `Workspace` (not `Terrain`, `Camera`), `ReplicatedStorage`, `ReplicatedFirst`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPack`, `StarterPlayerScripts`, `StarterCharacterScripts`, `SoundService`, `Lighting`, `Teams`: class, descendants, scripts. Export every root with `CityMerge/transfer/export.luau` (keys `rob__<n>__<name>.b64`). The `.tsv` holds one row per LuaSourceContainer: root, relative path, class, Enabled, Adler-32. Also record `Workspace.StreamingEnabled`, every CollectionService tag in use with its instance count, every `PhysicsService` collision group, and every `SpawnLocation` with `Enabled`.

- [ ] **Step 3: Collisions.** For every Robbery root, and for every name under `PlayerGui` that a Robbery script creates or waits for, find the same full name in the city. Classify each as `identical` (every script Adler-32 equal), `differs` (list the scripts that differ, with a one-line summary of the diff, read from both sides), `robbery-only`, or `same name, different thing`. Do the same for tag names and collision group names.

- [ ] **Step 4: Currency.** Read `ServerScriptService.PlayerData` whole. Write `currency-api.md`: every public function of `CurrencyService` (name, parameters, return, whether it yields, what it writes, whether it creates `leaderstats`), every caller across the Robbery place (`script_grep` for `CurrencyService` and `PlayerData`), and what else `PlayerData` does (its own DataStore, leaderstats, other values).

- [ ] **Step 5: Locations.** For each of Bank, SlowFoods, Gas2Go, NewsStation: the set of Robbery Workspace roots that belong to it (the models named in its server script, its `*Markers` folder, zones, tagged parts; Bank also `BankVault`, `HeistZones` and anything under them), their combined world bounding box, and the floor height of the entrance. The city counterpart under `Workspace.Map.Robbery` (`Bank`, `SlowFoods`, `Gas2Go`, `NewsStation`), its bounding box and the ground height at its entrance (raycast down). Every absolute coordinate written in a Robbery script (`script_grep` for `Vector3.new(` and `CFrame.new(` with numeric literals in server and client code, and every coordinate assertion in `WorldSpec`).

- [ ] **Step 6: Heist suite baseline.** One Play in the Robbery window (Play only; nothing changes in that place), run the suite from a temporary server Script exactly as `HeistShared.RunAll` is meant to be called, with Studio not minimised. Record totals and the failure set by spec and case name. Expected from the vault: 594 passed / 14 failed, 12 in `CashClaimVFX` and one `CooldownDuration` case each in the SlowFoods (`RestaurantConfig`) and `Gas2GoConfig` specs. Any other failure is listed with its message. Repeat once; a case failing in only one run is marked environmental.

- [ ] **Step 7: City baseline.** In the city: the 16 suites (expect 171 / 171 / 0), the whole-place checksums as `CityMerge/phase2b/baseline.md` defines them, Workspace descendant count, client descendants at the spawn at 25 s.

- [ ] **Step 8: Propose, then stop for the gate.** Fill `classification.md` and the transform rows of `locations.md` by the rules below, then report to the controller. Nothing is imported in this leg.

**Rules the proposal follows (the gate rules on each row against them):**
- **Carry:** every root a heist, puzzle, prompt, supplier or HUD script needs at runtime, found by following `require` and instance lookups from the five server scripts (`HeistServer`, `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer`, `SuppliesServer`) and `HeistClient`, plus `ServerScriptService.Heist` with its `Tests`.
- **Use the city copy:** a root classed `identical`; and `ReplicatedStorage.UI`, `DialogModule`, `PromptUiController`, `UiButtonEffects` and any other module the Robbery decisions say was copied from FPS word for word, even where it now differs, because the city's copies carry phase 2 fixes. Where the Robbery copy has behaviour the city copy lacks, the row says what, and the gate decides.
- **Leave behind:** the map, terrain, lighting, baseplate and spawn of the Robbery place, anything only a test map needs, and the save layer of `PlayerData`.
- **Bridge:** `PlayerData.CurrencyService` (Task 2).
- **Same name, different thing:** the Robbery one is renamed with the prefix `Heist` and every Robbery reference updated, unless the gate rules that one system should serve both (for example one notification stack). Expected case: `StarterGui.NotificationGui` (Robbery, global location cards) against the city's runtime `NotificationGui` (`ReplicatedStorage.Modules.NotificationController`).
- **One cash display:** if the Robbery HUD draws its own cash card, it is left behind and `CashClaimVFX` flies to the city's cash HUD element instead.
- **Transform per location:** a translation, plus a yaw from {0, 90, 180, 270}, applied to the location's whole root set about one pivot, so that the set's footprint centre lands on the city counterpart's footprint centre and its entrance floor on the city ground at that point. The yaw is the one whose rotated footprint differs least from the city counterpart's (sum of the X and Z extent differences). The city counterpart is then moved to `ServerStorage.CityQuarantine.ReplacedByHeist` with `OriginalCFrame`, `OriginalParent`, `OriginalPath` attributes, as phase 1 did, not deleted.
- **Fit:** after the transform, list every city part outside the replaced building that the location's parts intersect (`GetPartBoundsInBox` over each location part), every plot, quest giver and enemy point within 120 studs, and the distance to the city spawn. A location whose footprint exceeds the city counterpart's by more than 20 studs on either axis, or that intersects a road, plot or other building, goes to the gate with numbers; the gate either accepts or asks the developer, and that location waits.
- **Absolute coordinates** found in Step 5 are moved by the same transform in the script that holds them (a deviation), or replaced by a lookup of a marker that moves with the location; the gate picks per row.

**Leg 2: after the gate** — no implementation steps; the gate's rulings are written into `classification.md` and `locations.md`, then:

- [ ] **Step 9: Commit.** `git commit -m "Batch: robbery survey and baselines"`.

---

### Task 2: Code into the city, disabled, and the currency bridge

**Files:**
- Import (place): every root classified `carry` that lives outside `Workspace`.
- Create (place): `ServerScriptService.PlayerData.CurrencyService` (the bridge), `ServerStorage.UnitTest.Cases.CurrencyBridge_Test`.
- Modify (place): renames ruled at the gate.

**Interfaces:**
- Consumes: `classification.md`, `currency-api.md`.
- Produces: `ServerScriptService.PlayerData.CurrencyService` with exactly the public API in `currency-api.md`; every imported `Script` and `LocalScript` with `Enabled = false` and attribute `ImportEnabled` holding its source `Enabled`, which Task 3 restores.

Skills to load: `roblox-data-stores`, `roblox-testing`.

- [ ] **Step 1: Write the failing test `CurrencyBridge_Test`.** Against a stand-in player that has a `leaderstats` Folder with an `IntValue` `Cash` = 500 (built in the test, never parented to `Players`). Cases, using the names in `currency-api.md`:
  - adding 100 makes `Cash` 600 and returns what the original returns on success;
  - adding `0/0`, `-5`, `math.huge`, `"100"` or `nil` leaves `Cash` at 500 and returns what the original returns on refusal;
  - a non-integer amount follows the original's rounding (state which in the test name);
  - a stand-in with no `leaderstats` returns the refusal value, does not error and does not create `leaderstats`;
  - for each other function in the API (balance read, spend, and so on), one success case and one refusal case with the same values.

- [ ] **Step 2: Run it.** Expected: the module is missing, every case fails.

- [ ] **Step 3: Implement the bridge.** A ModuleScript at the original path with the original API, reading and writing only `player.leaderstats.Cash.Value`. It never creates `leaderstats`, never yields, never touches a DataStore; a refused call is silent unless the original warned. Nothing else of `PlayerData` is imported. `ImportedFrom = "Robbery System"`, `CityMergeDeviation = "bridge onto leaderstats.Cash; the Robbery save layer stays behind"`.

- [ ] **Step 4: Run it.** Expected: all cases pass; the 16 old suites still 171 / 171 / 0.

- [ ] **Step 5: Import the rest.** `CityMerge/transfer/import.luau` for each `carry` root outside Workspace, in manifest order; it errors on any name collision, which means the gate missed one: stop and report. Then disable every imported `Script` and `LocalScript` and set `ImportEnabled`. Apply the gate's renames. Check: every imported script's Adler-32 equals the manifest, except the renamed ones (listed with their new Adler-32 in `after-import.md`).

- [ ] **Step 6: Play check.** One Play from the city spawn: 0 new error or warning lines against Task 1's city baseline (the imported scripts are off), all suites as Step 4.

- [ ] **Step 7: Commit.** Export the bridge and the test to `CityScripts/`. `git commit -m "Batch: robbery code into the city, currency bridged onto Cash"`.

---

### Task 3: The four locations into the city

**Files:**
- Import (place): every `carry` root inside `Workspace`.
- Move (place): the four city counterparts to `ServerStorage.CityQuarantine.ReplacedByHeist`.
- Modify (place): scripts holding absolute coordinates, per the gate; `ModelStreamingMode` where the gate or Step 5 says.
- Fill: `CityMerge/phase3/locations.md` (result columns).

Skills to load: `roblox-world-building`, `roblox-performance`.

- [ ] **Step 1: Import and place, one location at a time.** Import its roots into `Workspace` at top level under their own names (the Robbery scripts index them by path, so they are not grouped). Apply the gate's transform with `PivotTo` on each root about the location's one pivot. Quarantine the city counterpart. Read back: the location's bounding box centre within 1 stud of the planned point; entrance floor within 0.5 stud of the city ground.

- [ ] **Step 2: Spawns.** Every imported `SpawnLocation` is set `Enabled = false` unless a Robbery script requires it enabled (then it gets `Neutral = false` and a team the player never joins, and the row says so). Exactly one enabled `SpawnLocation` remains: `Workspace.SpawnLocation`.

- [ ] **Step 3: Coordinates.** Apply the gate's per-row fixes for absolute coordinates (Task 1 Step 5). `WorldSpec` assertions on world positions are moved by their location's transform; nothing else in the specs changes here.

- [ ] **Step 4: Getaway in the city.** Per location: horizontal distance from its `StatusBillboardAnchor` to each other location's anchor, to the nearest plot, to the city spawn, to the quest-giver row and to each enemy point; 32 points on the 200-stud ring around the anchor, each raycast down: ground or road found, not inside another building, not inside a plot. A location where fewer than 8 of the 32 points are clear ground, or whose 200-stud ring takes in another location's anchor, goes in the report for the controller (the `EscapeDistance` line in its Config is the knob; it is not changed in this task).

- [ ] **Step 5: Streaming.** Every `Model` among the imported roots gets `ModelStreamingMode` left at its source value, except the models holding a `StatusBillboardAnchor`, which become `Persistent` when the model is under 200 descendants; a larger one is listed for Task 4's audit instead. Record the client descendant count at the city spawn at 25 s against Task 1's.

- [ ] **Step 6: Enable.** Restore every imported script's `Enabled` from `ImportEnabled`, then remove the attribute.

- [ ] **Step 7: Check and commit.** Edit mode: Workspace descendants, the whole-place checksums, the one-spawn rule. `git commit -m "Batch: four heist locations placed at the city's robbery buildings"`.

---

### Task 4: First run, client audit, a heist banks into Cash

**Files:** `CityMerge/phase3/first-run.md`, `client-load-order-audit.md`; place edits only for audit FIX rows; tests as named below.

Skills to load: `roblox-testing`, `roblox-ui`.

- [ ] **Step 1: Suites.** One Play from the city spawn: the city suites (171 / 171 / 0 plus `CurrencyBridge_Test`, 0 failed) and the heist suite. The heist failure set must be the Robbery baseline's set or smaller, except `WorldSpec` rows already moved in Task 3. Any new failure is diagnosed: a cause in the city (streaming, a path, a collision) is fixed in the city as a deviation; a cause that also fails in the Robbery place is environmental and recorded.

- [ ] **Step 2: Console.** Server and client distinct warning and error lines at 25 s against Task 1's city baseline; every new line is explained or fixed.

- [ ] **Step 3: Client load-order audit.** As `CityMerge/client-load-order-audit.md` did for FPS: every Robbery client script's lookup of a Workspace instance or a sibling, by `.` index or by `WaitForChild` without a timeout, with a verdict `SAFE` (reason) or `FIX` (the `WaitForChild(name, 10)` form, or a server-replicated value, for a part that can stream out). Anchors and billboards needed beyond 128 studs that Task 3 Step 5 could not make `Persistent` are FIX rows. Apply the FIX rows, then three Plays from the city spawn with 0 client errors.

- [ ] **Step 4: A heist end to end, through the game's own paths.** For SlowFoods (the simplest) and then the Bank: walk the character there (server `PivotTo` beside the entrance), trigger the robbery through its real prompt or remote, take items through `RobbableObject`'s real path, and move the character out in steps to 100, 150, 199, 201 and 250 studs. Read at each step: the session state, duffel value, the getaway widget's shown distance and style on the client, `leaderstats.Cash`, and (from a temporary server Script) the profile's `cash`. Expected: nothing banked before 200 and outside the building; at 201 one credit equal to the duffel value; at 250 nothing more; profile `cash` equals `leaderstats.Cash`. Puzzles that automation cannot drive (word scramble, lockpick, keypad) are driven through their server remotes with the correct answer read from server state, and the report says so. Gas2Go and NewsStation: trigger and one claim only.

- [ ] **Step 5: Voided hauls.** Three runs: the character dies with a full duffel; the session timer runs out (shorten `SessionDuration` in the Play's server datamodel only, which Play discards on stop); the character is removed mid-heist. Each: no credit, no error, the location returns to Idle then Cooldown as the specs describe.

- [ ] **Step 6: HUD.** At 1080 x 659 and at 844 x 390: `AbsolutePosition` / `AbsoluteSize` of the timer, duffel bar, getaway widget and a notification card, against every visible city HUD element (cash, level, stamina, hotbar, quest log button, notification stack). Overlapping pairs are listed; the Robbery element moves by the smallest offset that clears it, inside its own script or GUI, as a deviation. A screen capture of each size if capture works; otherwise "no capture".

- [ ] **Step 7: Commit.** `git commit -m "Batch: heists run in the city and bank into Cash"`.

---

### Task 5: Robbery remote audit and the two old spec debts (two legs, controller gate between)

**Files:** `CityMerge/phase3/remote-audit.md`; place edits for FIX rows; `ReplicatedStorage.SharedSystems.CashClaimVFX`; the SlowFoods and Gas2Go Config modules or their specs.

Skills to load: `roblox-security`, `roblox-networking`.

**Leg 1:**
- [ ] **Step 1: Audit,** one row per Robbery client-to-server remote (`HeistShared.Remotes`, `Net`, and any other `OnServerEvent` / `OnServerInvoke` in the imported code), columns and verdict rule as `CityMerge/phase2b/remote-audit.md`. Pay attention to: claim and sell paths (who may claim, how often, how much), puzzle answers (the server holds the answer; a client cannot skip a stage), `SubmitSupplierChoice` (re-checks `CarryState`), anything that takes a position or an Instance from the client, and the reach of each prompt-backed action (as phase 2b did for quests). Stop and report the FIX rows.

**Leg 2 (after the gate):**
- [ ] **Step 2: Fix each approved row** test first: a spec in `Heist.Tests` when the logic lives in a Heist module, a case in `ServerStorage.UnitTest.Cases` otherwise; red, fix, green.
- [ ] **Step 3: `CashClaimVFX`.** Move its lazy `require` to module scope (the vault's diagnosis); its 12 specs pass.
- [ ] **Step 4: Cooldowns.** `RestaurantConfig` and `Gas2GoConfig` say `CooldownDuration = 60`; their specs expect 1200 and 600. Ruling for this plan: the spec values win, because a spec pinned them on purpose and 60 s reads as a test shortcut; set the Configs to 1200 and 600. If the developer has said otherwise before this task runs, follow the developer.
- [ ] **Step 5: Suites.** Heist suite: failure set empty except cases recorded as environmental in Task 1; city suites all pass. Commit: `git commit -m "Batch: robbery remotes audited, heist specs green"`.

---

### Task 6: Closing run and vault

**Files:** `CityMerge/phase3/final-run.md`; vault: a batch note `70 Batches/<date> Robbery Systems Into City.md`, the Batch Log, `20 Systems/Robbery Heists and Getaway.md`, `Robbery Puzzles.md`, `Robbery Prompts.md`, `Economy and Cash.md`, `City Map and Plots.md`, `Notifications.md` if the gate merged or renamed a notification system, Open Items, `80 Decisions` (Claude's rulings and the developer's words, quoted), `50 Engine Traps` for new traps.

- [ ] **Step 1: Five Plays from the city spawn,** read at 25 s: 0 client and 0 server script errors other than asset-load lines and the three known `Workspace.HQ` lines (if `Workspace.HQ` is still there), PlayerGui and PlayerScripts counts recorded, one enabled spawn. Play 5 also: both suites; the SlowFoods heist banked once (cash and profile); an AK47 purchase and a quest turn-in still work.
- [ ] **Step 2: Checksums.** The scripts whose Adler-32 differ from Task 1's city baseline are exactly the imported, bridged and edited ones; list them.
- [ ] **Step 3: Vault.** Per `Vault Conventions.md`. The Robbery system notes now describe the city as the running home and the Robbery place as the frozen reference. Open Items closes: the two cash systems, `CashClaimVFX` and the config specs, the robbery half of the remote audit, the city's 26 leftover prompts if they left with the quarantined buildings. It adds: anything the gate sent to the developer, the getaway results that need tuning, the casino and warehouse (still art, no heist), the duffel gamepass ids (still `0`), and checks that need a person (a real lockpick and word scramble by hand, two players in one heist).
- [ ] **Step 4: Commit.** Stop the transfer store. `git commit -m "Batch: robbery systems into the city"`. Report ends with the save state.

---

## Not in this plan

- The casino and the warehouse: they stay art. A casino heist is new work.
- Hauling loot home, materials, the drop-off and the drivable car: phase 6.
- Moving the getaway maths into one shared module: phase 6, when it changes (design section 9).
- Unifying `GamepassManager` with the city's `MonetizationService`: both work, both hold placeholder ids; an Open Item, not this phase.
- Tuning `EscapeDistance` or any price: measured here, tuned in playtests.
