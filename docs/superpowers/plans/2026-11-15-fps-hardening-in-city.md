# Phase 2b: FPS Hardening in the City Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three items the design assigns to phase 2 (remote ownership audit, the `ZIndexBehavior.Global` ScreenGuis, saving quest progress) and the script faults the first city run left open, all in `Crimelife city.rbxl`.

**Architecture:** Every change is made in the live city place through the `Roblox_Studio` MCP and the changed script is exported to `CityScripts/` in the repo, so each task has a git diff a reviewer can read. Quest saves follow the existing persistence pattern (`Schema.template` field, `ProfileGateway.registerHydrator`, `ProfileGateway.mirror`). No new service, no new remote.

**Tech Stack:** Luau in Roblox Studio; `Roblox_Studio` MCP (`execute_luau`, `multi_edit`, `script_read`, `start_stop_play`, `get_console_output`, `screen_capture`); `ServerStorage.UnitTest.RunUnitTest`; the local transfer store `CityMerge/transfer/server.py` (127.0.0.1:8765).

**Spec:** `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md` (the phase table's phase 2 row, and the list of existing-system fixes just before section 10). Evidence: `CityMerge/first-run.md`, `CityMerge/client-load-order-audit.md`, vault `60 Open Items/Open Items.md`.

**Models:** Fable runs the gates and rulings. Opus builds Tasks 2 and 3 (security and save judgment). Sonnet builds Tasks 1, 4 and 5 and does the reviews.

## Global Constraints

- Target place: **`Crimelife city.rbxl`**, resolved by name with `list_roblox_studios` before every write. Ids change on restart.
- `FPS System.rbxl` is frozen: Play and read only, no edit. `Robbery System.rbxl`, Test30.4 and every OBT place are not touched at all.
- Never publish. Do not save the place unless the developer has said so for this run; every report ends with the save state ("NOT saved / NOT published" or what was saved).
- `Schema.VERSION` stays **3**. Fields are only added to `Schema.template`.
- Only `ProfileGateway` may require ProfileStore.
- Every script edited in the city gets the attribute `CityMergeDeviation` (a one-line reason string) and a row in `CityMerge/after-import.md` under "Deviations from the FPS place", with its Adler-32 before and after.
- Unit tests run from a temporary server `Script` in Play, results passed back through a `StringValue` in `ServerStorage`, both removed before Play stops (method: `CityMerge/first-run.md`, "Method"). `execute_luau` has its own `require` cache and cannot read profiles.
- Baseline to hold: 12 suites, **147 / 147 / 0**. After this plan: every old case still passes, 0 failed.
- A new test case module's name must not be a substring of another case's name (`RunUnitTest` filters by substring).
- Numbers in every written file are measured in this run, or the cell says "not recorded".
- Git: work on `main`, one commit per task named `Batch: <topic>`, `.DS_Store` left out, nothing pushed.
- No key, token or user detail in any file or request.

## Review Focus

1. **A saved quest whose id is gone from `QuestConfig`, or whose target was lowered.** A player must join without an error and without a stuck quest. Pinned in Task 3, `QuestSave_Test`.
2. **Bad values in saved data or remote arguments** (NaN, negative, huge, a string where a number belongs, a table where a string belongs). Refused or clamped, never written. Pinned in Task 3 (`QuestSave_Test`) and Task 2 (one test per fixed handler).
3. **A quest accept or turn-in fired from across the map, with no character, or while dead.** Refused by the server. Pinned in Task 2 (`QuestReach_Test` and a Play check).
4. **Quest progress earned before the profile is bound.** Nothing is written from half-restored state, and the hydrator's result wins. Pinned in Task 3 (`ProfileAdoption_Test` case).
5. **A ScreenGui flipped to `Sibling` that gains rows after the measurement** (shop grid, quest log, notifications). Its paint order is measured again after a purchase, a notification and an accepted quest. Pinned in Task 4.

---

## File Structure

| Path | Role |
|---|---|
| `CityScripts/<FullName>.luau` | Exported source of every city script this plan touches, named by its full path with dots (`ServerScriptService.Quests.Scripts.QuestService.luau`). Before and after each edit. |
| `CityMerge/transfer/export-source.luau` | Snippet: POST one script's `Source` to the transfer store. |
| `CityMerge/phase2b/baseline.md` | Checksums, test counts and console counts before any change. |
| `CityMerge/phase2b/remote-audit.md` | One row per client-to-server remote, verdict and fix. |
| `CityMerge/phase2b/zindex-audit.md` | One row per Global ScreenGui, paint order result and decision. |
| `CityMerge/phase2b/paint-order.luau` | Measurement tool with its own self-check. Not shipped in the place. |
| `CityMerge/phase2b/final-run.md` | The closing regression run. |

---

### Task 1: Baseline and source snapshot

**Files:**
- Create: `CityMerge/transfer/export-source.luau`, `CityMerge/phase2b/baseline.md`
- Create: `CityScripts/*.luau` for the 26 scripts listed in Step 3

**Interfaces:**
- Produces: `CityScripts/<FullName>.luau` files that later tasks overwrite after editing; the export procedure (Step 2) that later tasks repeat.

- [ ] **Step 1: Start the transfer store.** `lsof -ti tcp:8765 | xargs kill` (ignore "no process"), then run `python3 CityMerge/transfer/server.py` in the background. Check: `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8765/none` returns `404`.

- [ ] **Step 2: Write `CityMerge/transfer/export-source.luau`.** A snippet for `execute_luau` (Edit) that takes a list of instance paths, and for each POSTs `Source` to `http://127.0.0.1:8765/src.<n>` (`n` = list index, `Content-Type: text/plain`) and returns one line per script: index, full name, byte length, Adler-32. Adler-32 is the function already used in `CityMerge/transfer/export.luau`: reuse it, do not rewrite it. On disk: `curl -s http://127.0.0.1:8765/src.<n> > "CityScripts/<FullName>.luau"`.

- [ ] **Step 3: Export these 26 sources and verify each.**
  `ServerScriptService`: `Blaster.Scripts.Blaster`, `Blaster.Scripts.Blaster.validateShot`, `Blaster.Scripts.Blaster.validateReload`, `Blaster.Scripts.Blaster.validateShootArguments`, `Cosmetics.Scripts.CosmeticsService`, `Monetization.Scripts.MonetizationService`, `Movement.Scripts.RunningState`, `Quests.Scripts.QuestService`, `Spraypaint.Scripts.SpraypaintService`, `Weapons.Scripts.EquipService`, `Weapons.Scripts.WeaponUpgradeService`, `Weapons.Scripts.LevelingService`, `Weapons.Scripts.WeaponShopService`, `WeaponAnimationPreview`.
  `ReplicatedStorage`: `Persistence.Schema`, `Quests.QuestConfig`, `UI.CashBurst`.
  `StarterPlayer.StarterPlayerScripts`: `AdminLevelController`, `CashShopController`, `DamageDirectionIndicator`, `DeathScreen`, `GamepassShopController`, `PromptUiController`, `QuestLogController`, `WeaponaryShopController`.
  `StarterPlayer.StarterCharacterScripts`: `Lean`.
  (`validateShot`, `validateReload` and `validateShootArguments` are children of the `Blaster` script.)
  Verify: `python3 -c "import zlib,sys;print(zlib.adler32(open(sys.argv[1],'rb').read()))" <file>` equals the Adler-32 the snippet returned, for every file. A mismatch is a stop.

- [ ] **Step 4: Record the baseline in `CityMerge/phase2b/baseline.md`.** In Edit: the two whole-place checksums exactly as `CityMerge/first-run.md` Step 6 defines them (BaseScripts count, enabled count, Enabled checksum, source containers count, source checksum). Expected from the last run: 196 / 121 / 336067737 and 297 containers; the source checksum is whatever is measured now (two scripts changed after that table). Then one Play from `Workspace.Dev.DevSpawn` (enable it, disable the city `SpawnLocation`, restore both after): unit tests per suite (expect 147 / 147 / 0), server and client distinct non-asset warning and error lines at 25 s.

- [ ] **Step 5: Commit.** `git add CityScripts CityMerge/transfer/export-source.luau CityMerge/phase2b/baseline.md && git commit -m "Batch: phase 2b baseline and source snapshot"`

---

### Task 2: Remote ownership audit (two legs, controller gate between)

**Files:**
- Create: `CityMerge/phase2b/remote-audit.md`
- Create (place): `ServerStorage.UnitTest.Cases.QuestReach_Test`, plus one case module per other FIX row
- Modify (place, then re-export): `ReplicatedStorage.Quests.QuestConfig`, `ServerScriptService.Quests.Scripts.QuestService`, and whichever handlers Leg 1 marks FIX

**Interfaces:**
- Produces: `QuestConfig.MAX_INTERACT_DISTANCE: number` and `QuestConfig.withinReach(a: Vector3, b: Vector3): boolean`, used by Task 3's edit of the same script (Task 3 must keep them).

Skills to load: `roblox-security`, `roblox-networking`.

The 14 client-to-server handlers (measured 2026-11-15):

| Remote | Handler |
|---|---|
| `Blaster.Remotes.Shoot`, `Reload` | `Blaster.Scripts.Blaster` 83, 84 |
| `Cosmetics.Remotes.EquipSkinRequest` | `CosmeticsService` 128 |
| `Monetization.Remotes.PromptProductPurchase`, `PromptGamepassPurchase` | `MonetizationService` 61, 75 |
| `UpdateRunningState` | `Movement.Scripts.RunningState` 27 |
| `Quests.Remotes.AcceptQuestRequest`, `TurnInQuestRequest` | `QuestService` 65, 130 |
| `Spraypaint.Remotes.BuySkinRequest` | `SpraypaintService` 219 |
| `Weapons.Remotes.EquipRequest` | `EquipService` 22 |
| `Weapons.Remotes.UpgradeRequest` | `WeaponUpgradeService` 74 |
| `Leveling.Remotes.SetLevelRequest` | `LevelingService` 30 |
| `Weapons.Remotes.BuyRequest`, `SetLoadoutSlotRequest` | `WeaponShopService` 320, 369 |

`Blaster.Remotes.ReplicateShot`, `DamageIndicator`, `DamageDirection` and `KillConfirmed` are server-to-client: confirm no `OnServerEvent` exists for them and list them as such.

**Leg 1: audit (no edit)**

- [ ] **Step 1: Fill `remote-audit.md`, one row per handler.** Columns: remote; handler and line; arguments and the type check on each; **ownership** (what the client names, and the line that proves it belongs to this player: Tool parent, `WeaponOwned_*`, `ownsPalette`, the admin UserId, and so on); NaN and range (every number argument: what `NaN`, a negative, a non-integer and 1e18 do); what it costs if fired 100 times a second; verdict `OK` or `FIX`; for FIX the smallest change and the test.
  Read the handler and every validator it calls to the end (`validateShot`, `validateReload`, `validateShootArguments`, `handleBuyRequest`, `ownsPalette`, `isWeaponOwned`, how `ShotResolver` treats `claimedTags`).
  **Verdict rule:** FIX only when a client can (a) act on something it does not own, (b) get an untyped, NaN or out-of-range value written into state or a save, or (c) gain cash, XP, a weapon, a skin or quest credit without doing the thing. A missing rate limit alone is OK plus a note, unless 100 calls a second does (c) or throws.
  Already known FIX (from the planning read): `AcceptQuestRequest` and `TurnInQuestRequest` have no distance check; a client can accept and hand in from anywhere.

- [ ] **Step 2: Stop and report the FIX rows to the controller.** The controller approves, changes or rejects each before any edit.

**Leg 2: fixes**

- [ ] **Step 3: Write the failing test `QuestReach_Test`.**

```lua
return function(t)
	local QuestConfig = require(game.ReplicatedStorage.Quests.QuestConfig)
	local expect = t.expect
	t.test("reach is a positive number", function()
		expect.equal(typeof(QuestConfig.MAX_INTERACT_DISTANCE), "number")
		expect.truthy(QuestConfig.MAX_INTERACT_DISTANCE > 0)
	end)
	t.test("a player at the giver is within reach", function()
		expect.truthy(QuestConfig.withinReach(Vector3.new(0, 3, 0), Vector3.new(0, 3, 0)))
	end)
	t.test("a player one stud past the limit is not", function()
		local d = QuestConfig.MAX_INTERACT_DISTANCE + 1
		expect.falsy(QuestConfig.withinReach(Vector3.new(d, 0, 0), Vector3.zero))
	end)
	t.test("a NaN position is never within reach", function()
		expect.falsy(QuestConfig.withinReach(Vector3.new(0 / 0, 0, 0), Vector3.zero))
	end)
end
```

- [ ] **Step 4: Run it.** Expected: 4 run, 0 passed (`withinReach` is nil).

- [ ] **Step 5: Implement.** In `QuestConfig`: `MAX_INTERACT_DISTANCE` and `withinReach(a, b)` (`(a - b).Magnitude <= MAX_INTERACT_DISTANCE`; a NaN magnitude compares false, which is the wanted result). Value: read the walk-away distance `W` that `StarterPlayerScripts.QuestDialogueController` uses to end a conversation; set the constant to `math.max(30, W + 10)` and write `W` in the audit. In `QuestService`: one local `canReach(player, quest)` used by both handlers, false when the player has no character, no `HumanoidRootPart`, `Humanoid.Health <= 0`, or the giver (`Workspace.Quests[quest.npcName]`) has no `HumanoidRootPart`; otherwise `withinReach` of the two root positions. Both handlers return early when it is false.

- [ ] **Step 6: Run `QuestReach_Test`.** Expected: 4 / 4 / 0.

- [ ] **Step 7: For each other approved FIX row,** the same cycle: a case module named after the handler (`<Handler>Guard_Test`) with the row's failing input, run red, the smallest fix in the handler or its validator, run green. Where a handler lives in a `Script` and has no seam, move the check into the module it already requires (as `CosmeticsService.handleEquipRequest` did), not into a new module.

- [ ] **Step 8: Play check from the city spawn** (`Workspace.SpawnLocation`, no spawn swap). Client: `AcceptQuestRequest:FireServer("Level1Thugs")` from the spawn (about 40 studs from the nearest giver, more than the limit unless `W` forces a larger one; if within the limit, first move the character 200 studs away with a server `PivotTo`): `Quest_Level1Thugs_State` stays `""`. Move the character to 5 studs from `Level 1 Quest` (server `PivotTo`), fire again: state `Accepted`. All suites: old 147 pass, new cases pass, 0 failed.

- [ ] **Step 9: Record and commit.** Set `CityMergeDeviation` on each edited script, add the rows to `after-import.md`, re-export the edited sources to `CityScripts/`, finish `remote-audit.md` (every row has a verdict and, for FIX, the test name and result). `git commit -m "Batch: remote ownership audit in the city"`

---

### Task 3: Quest progress is saved

**Files:**
- Modify (place, then re-export): `ReplicatedStorage.Persistence.Schema`, `ReplicatedStorage.Quests.QuestConfig`, `ServerScriptService.Quests.Scripts.QuestService`
- Modify (place): `ServerStorage.UnitTest.Cases.Schema_Test`, `ProfileAdoption_Test`
- Create (place): `ServerStorage.UnitTest.Cases.QuestSave_Test`

**Interfaces:**
- Consumes: Task 2's `QuestConfig.withinReach` and `canReach` in `QuestService` (keep both).
- Produces: `Schema.template.quests` (`[questId] = { state: string, progress: number }`), `Schema.template.questCompletions` (`[questId] = number`), `QuestConfig.restore(savedQuests: any, savedCompletions: any): ({ [string]: { progress: number, state: string } }, { [string]: number })`.

Skills to load: `roblox-data-stores`, `roblox-testing`.

`QuestConfig.restore` rules (pure, no Instances):
- A non-table argument counts as an empty table.
- Drop any id not in `QuestConfig.Quests`.
- An entry is kept only if `state` is one of `STATE_ACCEPTED`, `STATE_READY_TO_TURN_IN`, `STATE_COMPLETED` and the entry is a table.
- `progress`: not a number or NaN gives 0; otherwise `math.clamp(math.floor(progress), 0, objectiveTarget)`.
- `Accepted` with progress at the target becomes `ReadyToTurnIn`. `ReadyToTurnIn` always has progress equal to the target.
- Completions: kept only for known ids, when the value is a number that is not NaN and is at least 1; stored as `math.floor`.
- Returns new tables; never returns or mutates its arguments.

- [ ] **Step 1: Write the failing tests.** `QuestSave_Test`:

```lua
return function(t)
	local QuestConfig = require(game.ReplicatedStorage.Quests.QuestConfig)
	local expect = t.expect
	local A, R = QuestConfig.STATE_ACCEPTED, QuestConfig.STATE_READY_TO_TURN_IN
	local target = QuestConfig.Quests.Level1Thugs.objectiveTarget

	t.test("an accepted quest comes back with its progress", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = A, progress = 4 } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = A, progress = 4 } })
	end)
	t.test("a quest id that no longer exists is dropped", function()
		local q, c = QuestConfig.restore({ Gone = { state = A, progress = 1 } }, { Gone = 3 })
		expect.equal(next(q), nil)
		expect.equal(next(c), nil)
	end)
	t.test("progress at or past the target reads as ready, at the target", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = A, progress = target + 5 } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = R, progress = target } })
	end)
	t.test("bad progress becomes 0 and a bad state is dropped", function()
		local q = QuestConfig.restore({
			Level1Thugs = { state = A, progress = 0 / 0 },
			Level10Smugglers = { state = A, progress = -7 },
			Level20Offender = { state = "Hacked", progress = 2 },
			Level35Bandits = "nope",
		}, {})
		expect.deepEqual(q, {
			Level1Thugs = { state = A, progress = 0 },
			Level10Smugglers = { state = A, progress = 0 },
		})
	end)
	t.test("completions keep whole positive counts only", function()
		local _, c = QuestConfig.restore({}, { Level1Thugs = 3.9, Level10Smugglers = 0, Level20Offender = "x", Level35Bandits = 0 / 0 })
		expect.deepEqual(c, { Level1Thugs = 3 })
	end)
	t.test("non-table input is an empty save, and the input is never returned", function()
		local q, c = QuestConfig.restore(nil, 7)
		expect.equal(next(q), nil)
		expect.equal(next(c), nil)
		local saved = {}
		expect.falsy(QuestConfig.restore(saved, saved) == saved)
	end)
end
```

  In `Schema_Test`, add `"quests"` and `"questCompletions"` to the field list in "the template carries every field the spec names" and to the list in "every table default is empty, not shared".

  In `ProfileAdoption_Test`, one new case, "quest progress written before the bind is not saved, and a restored quest wins": `Gateway.mirror` on an unbound stand-in with a callback that writes `p.Data.quests.Level1Thugs` must not run the callback (assert a flag stays false); then load a key, set `profile.Data.quests = { Level1Thugs = { state = "Accepted", progress = 4 } }` and `questCompletions = { Level1Thugs = 2 }`, and assert `QuestConfig.restore(profile.Data.quests, profile.Data.questCompletions)` returns progress 4 and completions 2. End the session as the neighbouring cases do.

- [ ] **Step 2: Run.** Expected: `QuestSave_Test` 6 run, 0 passed; `Schema_Test` 2 failed; the new adoption case fails on `restore` being nil.

- [ ] **Step 3: Implement.**
  - `Schema.template`: `quests = {},` and `questCompletions = {},` with a one-line comment each giving the shape. `VERSION` unchanged.
  - `QuestConfig.restore` per the rules above.
  - `QuestService`: require `ProfileGateway`. `safePlayerAdded` sets `playerQuests[player] = playerQuests[player] or {}` (the hydrator may have run first). One local `save(player, questId)` that mirrors the entry (`profile.Data.quests[questId] = entry and { state = entry.state, progress = entry.progress } or nil`) and the completions count read from the attribute; call it after every change: accept, each counted kill, turn-in. One local `hydrate(player, profile)` in the shape `WeaponUpgradeService.hydrate` uses (`profile = profile or ProfileGateway.get(player)`), which calls `QuestConfig.restore`, replaces `playerQuests[player]`, and for every id in `QuestConfig.Quests` sets the state, progress and completions attributes (completions 0 when absent). `ProfileGateway.registerHydrator(hydrate)`. Update the header comment: state is saved, not session-only.
  - The turn-in order stays: pay, count the completion, change state, publish, then `save`.

- [ ] **Step 4: Run all suites.** Expected: `QuestSave_Test` 6 / 6, `Schema_Test` all pass, `ProfileAdoption_Test` all pass, every other suite as the baseline, 0 failed.

- [ ] **Step 5: Round trip through the game's own path** (one Play, character moved next to `Level 1 Quest` by a server `PivotTo`, all reads from a temporary server `Script`):

| step | expected |
|---|---|
| client fires `AcceptQuestRequest("Level1Thugs")` | attribute state `Accepted`; `profile.Data.quests.Level1Thugs` = `{ state = "Accepted", progress = 0 }` |
| 3 Thug kills by the method in `first-run.md` ("Purchase and kill") | progress attribute 3; profile progress 3 |
| 7 more kills | state `ReadyToTurnIn`, progress 10, same in the profile |
| client fires `TurnInQuestRequest("Level1Thugs")` | cash up by 500, XP up by 100, `Quest_Level1Thugs_Completions` 1; `profile.Data.quests.Level1Thugs` nil; `profile.Data.questCompletions.Level1Thugs` 1 |
| accept again, 2 kills, then run the deployed hydrators against the bound profile on a stand-in player (`Gateway._runHydrators`) | stand-in attributes: state `Accepted`, progress 2, completions 1 |

  Console: no new warning or error line against Task 1's baseline.

- [ ] **Step 6: Record and commit.** `CityMergeDeviation` on `Schema`, `QuestConfig`, `QuestService`; rows in `after-import.md`; re-export the three sources. `git commit -m "Batch: quest progress saved in the city"`

---

### Task 4: `ZIndexBehavior.Global` ScreenGuis

**Files:**
- Create: `CityMerge/phase2b/paint-order.luau`, `CityMerge/phase2b/zindex-audit.md`
- Modify (place, then re-export): the creating script of each ScreenGui that passes the rule; `StarterGui."Custom Inventory"` (property only)

Skills to load: `roblox-ui`.

The ten candidates (measured 2026-11-15; `NotificationGui` is already `Sibling`, `Freecam` is Roblox's own and is left alone):

| ScreenGui | Made by |
|---|---|
| `CashShopGui` | `StarterPlayerScripts.CashShopController` line 26 |
| `GamepassShopGui` | `GamepassShopController` 26 |
| `WeaponaryShopGui` | `WeaponaryShopController` 113 |
| `QuestLogGui` | `QuestLogController` 16 |
| `DeathScreenGui` | `DeathScreen` 54 |
| `PromptUiGui` | `PromptUiController` 20 |
| `AdminLevelGui` | `AdminLevelController` 61 |
| `DamageDirectionIndicator` | `DamageDirectionIndicator` 29 |
| the cash burst gui | `ReplicatedStorage.UI.CashBurst` 62 |
| `Custom Inventory` | saved in `StarterGui` (a Creator Store package: change the property only, never its scripts) |

**The rule:** a ScreenGui is flipped to `Sibling` only when its paint order under `Global` and under `Sibling` is the same list, in every measurement below. Otherwise it stays `Global`, and the audit lists the overlapping pairs that would swap, for the developer to look at.

- [ ] **Step 1: Write `paint-order.luau` with its self-check.** `paintOrder(root: ScreenGui, mode: "Global" | "Sibling"): { string }` returns the GuiObjects in paint order, each as its path from the root with sibling indexes (`Shop[1]/Grid[2]/Card[7]`).
  - Global: every GuiObject descendant, stable-sorted by `ZIndex`, ties in depth-first pre-order of `GetChildren()`.
  - Sibling: depth-first, each parent before its children, children stable-sorted by `ZIndex`.
  Self-check, run in Edit on Frames built under a ScreenGui that is never parented: (a) all `ZIndex` 1 gives the same list in both modes; (b) the notification case (card `ZIndex` 4 with a label `ZIndex` 1, beside a card `ZIndex` 3) gives different lists, and under Global the label comes before its own card. Both must pass before the tool is used.

- [ ] **Step 2: Measure (one Play from the city spawn, Client datamodel).** For each candidate, at 25 s: the mode it has, both lists, equal or not; where not equal, the pairs whose order swaps and whose `AbsolutePosition`/`AbsoluteSize` rectangles overlap. Then, in the same Play: buy the AK47 through `BuyRequest`, raise one notification (drive the `Spraypaint` attribute from the client, as `Notification-Blank-Card-ZIndexBehavior` describes), accept `Level1Thugs` (character moved next to the giver), and measure all ten again. Record both passes in `zindex-audit.md`. Take a `screen_capture` of each panel that can be shown without a click; if capture times out, write "no capture" in that row.

- [ ] **Step 3: Flip the ones that pass.** Script-made: one line after the `Instance.new("ScreenGui")`, `<var>.ZIndexBehavior = Enum.ZIndexBehavior.Sibling`, with the comment `-- Sibling: see UI Layout Traps, "ZIndexBehavior is a global on the ScreenGui"`. `Custom Inventory`: set the property in Edit. Nothing else in those scripts changes.

- [ ] **Step 4: Verify (a second Play, same sequence as Step 2).** For each flipped ScreenGui: `ZIndexBehavior` reads `Sibling`; its paint order list equals the Global list recorded in Step 2, in both passes; the first GuiObject's `AbsoluteSize` equals the figure in `CityMerge/first-run.md` Step 3. All suites pass. Console: no new line against the baseline. A capture beside the Step 2 capture where capture works.

- [ ] **Step 5: Record and commit.** `CityMergeDeviation` on each edited script, rows in `after-import.md`, re-export. `zindex-audit.md` ends with two lists: flipped, and left `Global` with the reason. `git commit -m "Batch: ScreenGuis moved to Sibling where paint order is unchanged"`

---

### Task 5: First-run leftovers, closing run, vault

**Files:**
- Modify (place, then re-export): `StarterPlayer.StarterCharacterScripts.Lean`
- Modify (place): `ServerScriptService.WeaponAnimationPreview` (`Enabled` only); create `Workspace.FX` (Folder)
- Create: `CityMerge/phase2b/final-run.md`
- Vault: `70 Batches/2026-11-15 FPS Hardening In City.md` (from `Templates/Batch Note Template.md`), `70 Batches/Batch Log.md`, `60 Open Items/Open Items.md`, `20 Systems/Persistence and Saves.md`, `Quests and Dialogue.md`, `HUD and UI Shell.md`, `50 Engine Traps` where a new trap was found, `80 Decisions/CrimeLife Tycoon Decisions.md` for the rulings

- [ ] **Step 1: `Lean` line 41.** `m6d = lowerTorso.Root` becomes `m6d = lowerTorso:WaitForChild("Root", 10)` followed by a quiet `return` when nil, matching the three lookups above it. The `else` branch (`humanoidRootPart.RootJoint`) gets the same treatment.

- [ ] **Step 2: `Workspace.FX`.** Create an empty `Folder` named `FX` directly under `Workspace` (attribute `PlacedBy = "phase 2b"`). `StarterCharacterScripts.Crouching` line 250 parents its dust there; the script is not edited. Check in Play, Client: `workspace:FindFirstChild("FX")` is not nil.

- [ ] **Step 3: `WeaponAnimationPreview`.** Set `ServerScriptService.WeaponAnimationPreview.Enabled = false` with `CityMergeDeviation = "preview rig folder is not in the city"`. It drives a Studio-only preview folder the city does not have. Check: the `Infinite yield possible on 'Workspace:WaitForChild("WeaponAnimationPreview")'` line is gone from the server console.

- [ ] **Step 4: Closing run, written to `final-run.md`.** Five Plays from the city spawn, each read at 25 s: PlayerGui 21 children, PlayerScripts 28, 0 client and 0 server script errors (asset-load lines excluded, as in `first-run.md`), 0 `Infinite yield` warnings, `WalkSpeed` 20. In Play 5 also: all suites (old 147 pass, new cases pass, 0 failed); the AK47 purchase (500 to 300, saved); one kill (XP 0 to 10, saved); the Task 3 accept, kill, turn-in row; the whole-place checksums in Edit afterwards, with the list of every script whose Adler-32 differs from Task 1's baseline (it must equal the list of scripts this plan edited, and nothing else).

- [ ] **Step 5: Vault.** Batch note with what changed, what was measured, what is not verified and the save state. Remove from Open Items what closed (remote ownership audit, quest progress not saved, the flipped ScreenGuis, `Lean` line 41, `workspace.FX`, the preview warning) and add what opened (ScreenGuis left `Global` with their swap pairs, any rate-limit notes from the audit, the phone and two-player checks still owed). Update the three system notes' "Where it lives", "Extend it" and History. Follow `Vault Conventions.md`.

- [ ] **Step 6: Commit.** Stop the transfer store (`lsof -ti tcp:8765 | xargs kill`). `git add -A . ':!.DS_Store' && git commit -m "Batch: FPS hardening in the city"`. Report ends with the save state.

---

## Not in this plan (stays in Open Items)

- Re-placing the enemy points and quest givers, the stuck Thug, the streaming radii, `ModelStreamingBehavior`: the developer's hand or decision.
- Whether the city's 26 leftover prompts get the FPS prompt face (`PromptUiController`): a decision, and phase 3 replaces those prompts.
- Rate limiting as a system: only noted per remote in the audit, unless the verdict rule makes one a FIX.
- Gamepass ids, unpublished animations, asset permissions, anything needing a published place, a phone or a second player.
