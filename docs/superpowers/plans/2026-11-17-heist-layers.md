# Heist Signature Layers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each of the four city robberies one optional signature layer (SlowFoods manager chase, Gas2Go ATM rip-out, NewsStation broadcast takeover, Bank deposit boxes).

**Architecture:** Two shared tasks first (bonus loot in the bag, heavy-loot carry with slow walk and carry banking; small hooks on existing components), then one task per location wiring its layer in its own server script, then a closing task (Plays, vault). Everything lives in the open Studio place and is exported to `CityScripts/`.

**Tech Stack:** Roblox Luau in `Crimelife city.rbxl`, Roblox_Studio MCP tools, the Heist spec suite (`ServerScriptService.Heist.Tests`, `TestRunner`) and the city UnitTest suite.

**Spec:** `docs/superpowers/specs/2026-11-17-heist-layers-design.md`. Code facts (paths, line numbers, constructor contracts): `.superpowers/sdd/2026-11-17-heist-layers/survey.md`. Read both.

## Global Constraints
- Target place **`Crimelife city.rbxl`** only, resolved by name with `list_roblox_studios` before every write. `FPS System.rbxl`, `Robbery System.rbxl`, `Test30.4`, OBT places: read only. **Never publish. Never call `save_place`** (no word to save this run).
- No uploads (meshes, images, sounds, animations) and no asset permission changes: build models from existing parts and existing templates.
- Nothing visible is deleted: removed pieces go to `ServerStorage.CityQuarantine.<Reason>` with `OriginalPath` and `OriginalCFrame` attributes.
- Every edited or new script: `CityMergeDeviation` string attribute (append with "; " where one exists); a row in `CityMerge/after-import.md` under a section "Heist layers 2026-11-17" (create at the end of the file; Adler-32 before and after, "new" for new scripts); exported to `CityScripts/<FullName>.luau` with bytes and Adler-32 matched (procedure in the SDD `context.md`).
- New Heist specs are added to `ServerScriptService.Heist.Tests.RunAll` `SPECS`. Spec shape and fake-player rules: survey section 9 and 0.3.
- Baselines: city suites **262 / 262 / 0** plus new cases; heist suite **620 passed / 1 failed**, failure set only `Zone` "real occupancy sweep", plus new specs all passing. Exactly one enabled `SpawnLocation`; no temporary objects left.
- New tagged instances: update the location's boot asserts and `WorldSpec` in the same task.
- Numbers live in Config modules (they are frozen tables: edit the source). Values below are verbatim from the spec.
- Server re-measures distance on every new prompt and times every hold itself; per-player state keyed by the player value, cleared on `Seal`, `Rearm`, death and leave.
- Git: one commit per task named as the task says, staged by explicit path, never `.DS_Store`, nothing pushed. Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No key, token, UserId or account name in any file.
- Do not edit `Documents/Roblox/CLAUDE.md` or `CrimeLife Vault/90 Reference/Original Prompts/`. Only Task 7 updates the vault.

## Review Focus
1. A heavy-loot carrier dies or leaves: loot drops (or is forgotten), `CarrySpeedCap` is cleared, walk speed returns to normal. Pinned in Task 1 (`CarryStateSpec`).
2. The timer seals mid-layer (manager fleeing, broadcast on air, lockpick open on a box): no payout after seal, everything resets at `Rearm`. Pinned in Tasks 3, 5, 6.
3. Two players race for one thing (the key, one box, the ripped ATM): exactly one wins, paid once. Pinned in Tasks 3, 4, 6.
4. A bag over its cap: `Claim` returns the full amount and the HUD stays sane. Pinned in Task 1 (`BankInstanceSpec`) and the Task 2 HUD check.
5. A player with an attempt on one lockpick target triggers another: only the latest attempt is live and one click is judged once. Pinned in Task 2 (`LockedDoorSpec`).

---

### Task 1: Bonus loot and heavy-loot carry (shared)

**Files (Studio):**
- Modify: `ServerScriptService.Heist.BankInstance`, `ReplicatedStorage.SharedSystems.CarryState`, `ReplicatedStorage.SharedSystems.SupplyObject`, `ServerScriptService.Heist.Services.SupplierSale`, the movement constants module (`ReplicatedStorage.Movement.Constants` per the survey; confirm the path), `StarterPlayer.StarterCharacterScripts.Animate2`, `ServerScriptService.Movement.Scripts.SprintAuthority`, `StarterPlayer.StarterCharacterScripts.Crouching`
- Create: `ServerScriptService.Heist.Services.CarryGetaway`
- Test: `Heist.Tests.BankInstanceSpec` (or the spec that covers `TryAddDuffel`), `CarryStateSpec`, `SupplyObjectSpec`, `SupplierSaleSpec`, new `CarryGetawaySpec`

**Interfaces:**
- Produces:
  - `BankInstance:AddBonus(player, amount: number) -> (boolean, string?)`: reasons `"inactive"`, `"not_participant"`, `"invalid_amount"`; no cap check; fires `DuffelChanged(player, newAmount, "add")`.
  - Movement constants `CARRY_SPEED_CAP_ATTRIBUTE = "CarrySpeedCap"`, `CARRY_SPEED_CAP = 12`.
  - `CarryState:PickUp(...)` sets the character attribute `CarrySpeedCap` to `supplyObject.speedCap` when it is a number; `Drop`, `Consume`, `Forget` clear it. New `CarryState:GetCarried(player) -> supplyObject?`.
  - `SupplyObject` deps `bankOnly: boolean?`, `speedCap: number?` (stored as fields `self.bankOnly`, `self.speedCap`); `startHidden: boolean?` (at `OnSessionStart` stays hidden, no prompt); `SupplyObject:GiveTo(player) -> boolean` (same path as a prompt trigger, `isBlocked`/`hasDuffel` included, refuses when not hidden-and-available); `SupplyObject:Close()` (disarm the steal prompt and highlight until the next `OnSessionStart`).
  - `SupplierSale.try` refuses a carry whose object has `bankOnly == true`, consuming nothing, with the toast "The supplier won't touch that. Get it clear of the building instead."
  - `CarryGetaway.new(cfg) -> CarryGetaway` where cfg = `{ escapeDistance: number, anchor: BasePart, isInsideBuilding: (Player) -> boolean, matches: (supplyObject) -> boolean, value: number, carryState, currency, net, getPlayers: () -> {Player}, addActiveRobbery: ((fn) -> any)? }`; methods `Step()`, `IsNear(player) -> boolean`, `Forget(player)`, `Destroy()`. On escape: `carryState:Consume(player)`, `currency:Add(player.UserId, value)`, `net:Toast(player, "Banked %d Cash.")`, `net:NotifyRobberySuccess(player)`. Built on `Heist.Services.Getaway` with `getDuffel = carrying a matching object and 1 or 0`. When `addActiveRobbery` is given it registers `carrying a matching object and IsNear(player)` (callers pass `WantedService.addActiveRobbery`).

- [ ] **Step 1: Write the failing specs**
  - `AddBonus`: participant in Active with a full bag (`cap` reached) → `AddBonus(p, 3000)` is `true` and `GetDuffel(p) == cap + 3000`; `Claim(p)` then returns `cap + 3000`. Not a participant → `false, "not_participant"`; Idle → `false, "inactive"`; `0` or `-5` → `false, "invalid_amount"`.
  - `CarryState`: pick up an object with `speedCap = 12` → character attribute `CarrySpeedCap == 12`; `Drop` → attribute `nil`; same for `Consume` and `Forget`; an object without `speedCap` sets nothing; `GetCarried(p)` returns the object, then `nil` after `Consume`.
  - `SupplyObject`: `startHidden` → after `OnSessionStart` no steal prompt and model hidden; `GiveTo(p)` calls `onPickup(p, self)` once and a second `GiveTo` returns `false`; `Close()` removes the prompt until the next `OnSessionStart`.
  - `SupplierSale`: a `bankOnly` carry returns a refusal, `currency:Add` not called, still carrying.
  - `CarryGetawaySpec`: carrier of a matching object at 199 studs → no pay; outside at 200 → `currency:Add(userId, value)` once and the carry consumed; inside the building at 300 → no pay; a non-matching carry → no pay; no carry → `IsNear` false.
- [ ] **Step 2: Run the heist suite in Play** (`require(ServerScriptService.Heist.Tests.RunAll)()` via server `execute_luau`): the new cases fail.
- [ ] **Step 3: Implement** the interfaces above. Movement readers: `Animate2` caps `targetWalkSpeed` at the attribute and drops the sprint boost while it is set; `SprintAuthority.tick` caps WalkSpeed at it and forces `granted = false` (read like `StunnedUntil`); `Crouching` uses `math.min(config.Speed, cap)`.
- [ ] **Step 4: Run both suites in Play**: new cases pass, baselines hold. In Play, set `CarrySpeedCap = 12` on the character, hold sprint, sample `Humanoid.WalkSpeed` for 3 s: max ≤ 12.05; clear it: walk returns to 20 and sprint to 38 (record the numbers).
- [ ] **Step 5: Export, deviation rows, commit** `Batch: heist layers shared carry and bonus loot`.

### Task 2: Component hooks (shared)

**Files (Studio):**
- Modify: `ReplicatedStorage.SharedSystems.LockedDoor`, `ReplicatedStorage.SharedSystems.RobbableObject`, `ServerScriptService.Heist.Components.MasterComputer`, `ServerScriptService.Heist.Components.GuardPost`, `ServerScriptService.Heist.Services.Net`, `StarterPlayer.StarterPlayerScripts.NotificationClient`, `StarterPlayer.StarterPlayerScripts.HeistClient` (duffel over-cap only)
- Test: `LockedDoorSpec`, `RobbableObjectSpec`, `MasterComputerSpec`, `GuardSpec`, `NetSpec`

**Interfaces:**
- Produces:
  - `LockedDoor` deps `onSolved: ((player) -> ())?` (called once at a solve, after `LockpickSolved`), `objectText: string?` (prompt ObjectText, default "Locked Door"); `LockedDoor:Open(player) -> boolean` (opens at once if closed and the bank is Active: same tween, sound and prompt disable as a solve; does not call `onSolved`; returns `false` otherwise). One live lockpick attempt per player across all `LockedDoor` instances: a new trigger replaces the player's attempt on any other door, and a stop request is judged only by the door holding the player's live attempt.
  - `RobbableObject` deps `blockedReason: string?` (passed to `onRefused` instead of `"carrying_supplies"` when `isBlocked` refuses), `onRobbed: ((player) -> ())?` (called after a successful rob); `RobbableObject:Close()` (prompt and highlight off, `Robbed = true` until the next `OnSessionStart`).
  - `MasterComputer` dep `onBreached: ((player) -> ())?`, called the first time each player breaches in a session (survey 4.1: next to `_hackedBy[player] = true`).
  - `GuardPost:Alert()`: sets the activation latch so `Update` engages at once; no-op when the guard is dead.
  - `Net` remote `BroadcastHijacked` and `Net:NotifyBroadcastHijacked(playerName: string)` (`FireAllClients`); `NotificationClient` shows `"<b>%s</b> hijacked the News Station broadcast!"` with the alarm box.
  - `HeistClient`: the duffel bar fill clamps at full when the bag is over its cap; the amount text shows the real amount.

- [ ] **Step 1: Write the failing specs**
  - `LockedDoorSpec`: `onSolved` called exactly once with the solver after 4 hits; `Open(p)` in Active opens it and returns `true`, `onSolved` not called; `Open` when open or Idle returns `false`; two doors A and B, player triggers A then B, one stop request at a hit angle for B advances B only and A has no attempt left.
  - `RobbableObjectSpec`: `isBlocked` true with `blockedReason = "no_key"` → `onRefused(p, "no_key")`; `onRobbed(p)` called once on success; `Close()` → no prompt, a trigger does nothing, `OnSessionStart` re-arms.
  - `MasterComputerSpec`: `onBreached(p)` once at the breach, not again when `p` re-triggers.
  - `GuardSpec`: a guard out of activation range of every player but with a `mayTarget` player in sight range fires after `Alert()` and does not without it.
  - `NetSpec`: `BroadcastHijacked` is in the remote list.
- [ ] **Step 2: Run the heist suite**: the new cases fail.
- [ ] **Step 3: Implement** the interfaces above.
- [ ] **Step 4: Run both suites**: pass, baselines hold. In Play, fire `NotifyBroadcastHijacked("Tester")` from a temporary server Script and read the client card's `Body.Text`; give a participant a bag over its cap with `AddBonus` and read the duffel bar fill (≤ full) and the text (real amount).
- [ ] **Step 5: Export, deviation rows, commit** `Batch: heist layers component hooks`.

### Task 3: SlowFoods manager, key and storage safe

**Files (Studio):**
- Modify: `ServerScriptService.SlowFoodsServer`, `ReplicatedStorage.RestaurantShared.Config`, `WorldSpec`
- Create: `ServerScriptService.Heist.Components.FleeingManager` (controller), Manager template `RestaurantShared.ModelTemplates.Manager` (clone of `Cashier`, renamed, overhead "Manager"), `Workspace.SlowFoods.NPCSpawners.ManagerSpawner` (`NPCSpawner` tag, `NPCTemplate = "Manager"`), `SlowFoodsMarkers.ManagerEscapePoint`, the storage safe model (clone of a Bank safe model, Bank tag removed, `Highlight`, `ParticleEmitter`, a rob sound), test `Heist.Tests.FleeingManagerSpec`
- Config (verbatim): `ManagerKeyRange = 10`, `ManagerSafeAmount = 3000`, `ManagerKeyHold = 1`

**Interfaces:**
- Consumes: Task 1 `AddBonus`; Task 2 `LockedDoor:Open`, `RobbableObject` `blockedReason`.
- Produces: `FleeingManager.new(model, deps) -> FleeingManager` (the `NPCSpawnManager` controller contract: `.model`, `OnSessionStart`, `Seal`, `Destroy`); deps `{ bank, config, escapePoint: BasePart, measure: ((player) -> number?)?, onKeyTaken: (player) -> (), pathTo: ((model, Vector3) -> ())? }`; state `self.state: "idle" | "fleeing" | "caught" | "escaped"`; `TryTakeKey(player) -> (boolean, string?)` (reasons `"not_fleeing"`, `"not_participant"`, `"too_far"`).
- Key: player attribute `SlowFoodsKey = true` for one player per run; cleared on seal, death, leave and rearm.

- [ ] **Step 1: Failing spec `FleeingManagerSpec`**: `OnSessionStart` → state `fleeing` and `pathTo` called with the escape point; `TryTakeKey` by a participant at 9 studs → `true`, state `caught`, `onKeyTaken(p)` once; a second player then → `false, "not_fleeing"`; at 11 studs → `false, "too_far"`; non-participant → `false, "not_participant"`; reaching the escape point → state `escaped`, `TryTakeKey` refused; `Seal` while fleeing → stops, no key possible.
- [ ] **Step 2: Run, see it fail.**
- [ ] **Step 3: Implement** the controller (unanchors the root on flee; pathing per survey 3.5; Scared track when caught; hidden when escaped until `Rearm` respawns it), a second `NPCSpawnManager` in `SlowFoodsServer` after the cashiers, a "Take Key" prompt on the Manager (hold `ManagerKeyHold`, `RequiresLineOfSight = false`), a "Use Key" prompt on `Workspace.SlowFoods.LockedDoor`'s handle visible to all but accepted only from the key holder (calls `door:Open(player)`), the storage safe as `RobbableObject` unlocked at session start, `isBlocked = not key holder`, `blockedReason = "no_key"`, toast "You need the manager's key.", paying through `bank:AddBonus(player, ManagerSafeAmount)` (if `RobbableObject` only calls `TryAddDuffel`, add a dep `payWith: "bonus"`; say which in the report). Boot asserts and `WorldSpec` for the new spawner, marker and safe.
- [ ] **Step 4: Run both suites; Play check**: force a SlowFoods robbery, measure the manager's run time to the escape point (target about 15 s, record it); take the key, open the door with it, rob the safe: bag +3000 over the cap, banked at 200 studs (`leaderstats.Cash` delta recorded). Confirm the whole layer fits the 120 s session solo (record times).
- [ ] **Step 5: Export, deviation rows, commit** `Batch: SlowFoods manager chase`.

### Task 4: Gas2Go ATM rip-out

**Files (Studio):**
- Modify: `ServerScriptService.Gas2GoServer`, `ReplicatedStorage.Gas2GoShared.Config`, `WorldSpec` if structure changes
- Create: `Gas2GoShared.ModelTemplates.ATMCarryTool` (Tool from a copy of the ATM parts welded to a `Handle`, `CanBeDropped = false`, `RequiresHandle = true`, attribute `IsSupplyCarryTool = true`), a "Rip Out ATM" prompt template (clone of `RobATMPrompt`, ActionText "Rip Out ATM", HoldDuration `ATMRipHold`)
- Config (verbatim): `ATMRipAmount = 9000`, `ATMRipHold = 10`

**Interfaces:**
- Consumes: Task 1 (`SupplyObject` `bankOnly`/`speedCap`/`Close`, `CarryGetaway`, `CarryState`), Task 2 (`RobbableObject` `onRobbed`/`Close`).
- Produces: nothing for later tasks.

- [ ] **Step 1: Failing spec** (add to `Gas2GoConfigSpec` and a new case in `CarryGetawaySpec` or a `Gas2GoRipSpec`): config values above; rob first → rip prompt closed; rip first → rob prompt closed; the rip-out object has `bankOnly = true`, `speedCap = 12`.
- [ ] **Step 2: Run, see it fail.**
- [ ] **Step 3: Implement**: the ATM gets a `SupplyObject` (rip-out) beside its `RobbableObject` (rob); they close each other through `onRobbed` and the rip-out's `onPickup`; pickup toast "Carry it 200 studs clear of the gas station to cash in."; a `CarryGetaway` (`anchor = Gas2GoMarkers.StatusBillboardAnchor`, `escapeDistance = Config.EscapeDistance`, inside = the `Station` zone, `value = ATMRipAmount`, `addActiveRobbery = WantedService.addActiveRobbery`) stepped from a new `heartbeatExtras`, forgotten on player removing. If one model cannot carry both components (both drive its `Highlight` and pivot; `SupplyObject` welds and re-parents parts), split the ATM into two models at the same spot or make the rip-out object hide the rob model; report which.
- [ ] **Step 4: Run both suites; Play check**: rip out, walk speed ≤ 12 (sampled), firing a gun does nothing (ammo unchanged), the supplier refuses it, die → it drops with a re-pickup prompt, re-pick, bank at 200 studs: `leaderstats.Cash` +9000 once.
- [ ] **Step 5: Export, deviation rows, commit** `Batch: Gas2Go ATM rip-out`.

### Task 5: NewsStation broadcast takeover

**Files (Studio):**
- Modify: `ServerScriptService.NewsStationServer`, `ReplicatedStorage.NewsStationShared.Config`, `ReplicatedStorage.Wanted` nothing (use `addHeat`), `WorldSpec`
- Create: `ServerScriptService.Heist.Components.BroadcastDesk`, `Workspace.NewsStation.BroadcastDesk` (model from existing parts near `MasterComputer`, `Highlight`, Studio-authored BillboardGui with a TextLabel for "LIVE m:ss"), test `Heist.Tests.BroadcastDeskSpec`
- Config (verbatim): `BroadcastSeconds = 45`, `BroadcastRange = 12`, `BroadcastPayout = 6000`, `BroadcastHeatFloor = 3`

**Interfaces:**
- Consumes: Task 1 `AddBonus`; Task 2 `MasterComputer.onBreached`, `GuardPost:Alert`, `Net:NotifyBroadcastHijacked`.
- Produces: `BroadcastDesk.new(model, deps)`; deps `{ bank, config, now, measure: (player) -> number?, onLive: (player) -> (), onComplete: ({Player}) -> () }`; methods `Arm()`, `TryGoLive(player) -> (boolean, string?)` (reasons `"not_armed"`, `"already_live"`, `"done"`, `"not_participant"`, `"too_far"`), `Update()`, `OnSessionStart()`, `Seal()`, `Forget(player)`; `self.state: "locked" | "armed" | "live" | "done"`; `self.airSeconds: number`.

- [ ] **Step 1: Failing spec `BroadcastDeskSpec`** (fake clock): locked until `Arm()`; `TryGoLive` by a participant within 12 → `live`, `onLive(p)` once; air time grows only while a living participant is within 12 (pause when none, not reset); at 45 s → `done`, `onComplete` gets exactly the participants within 12 at that moment; `Seal` while live → no `onComplete`; second `TryGoLive` → `"already_live"` / `"done"`.
- [ ] **Step 2: Run, see it fail.**
- [ ] **Step 3: Implement** and wire in `NewsStationServer`: `onBreached` → `desk:Arm()`; "Go Live" prompt (hold 1); `onLive` → `net:NotifyBroadcastHijacked(player.Name)`, for every participant `WantedService.addHeat(p, BroadcastHeatFloor - getHeat(p), "broadcast")` when below the floor, every guard `:Alert()`; `Update` from `heartbeatExtras`; the BillboardGui text from `airSeconds`; `onComplete` → `bank:AddBonus(p, BroadcastPayout)` and a toast each.
- [ ] **Step 4: Run both suites; Play check**: hack, go live: the card shows city-wide (client `Body.Text`), stars ≥ 3, guards fire; step away 10 s and back: air time paused, not reset; at 45 s bag +6000; bank it.
- [ ] **Step 5: Export, deviation rows, commit** `Batch: NewsStation broadcast takeover`.

### Task 6: Bank deposit boxes and gold bar

**Files (Studio):**
- Modify: `ServerScriptService.HeistServer`, `ReplicatedStorage.HeistShared.Config`, `WorldSpec`, whatever refuses a carrier on the way out of the vault (report it)
- Create: `ReplicatedStorage.HeistShared.DepositBoxLoot` (pure), `Workspace.BankVault.DepositBoxes` (8 box models from parts in open vault-level floor, each with a hinged door part and `ProximityPart Handle`), `Workspace.BankVault.GoldBar` (model from parts, `Highlight`), `HeistShared.ModelTemplates.GoldBarTool` (`IsSupplyCarryTool = true`), tests `Heist.Tests.DepositBoxLootSpec`
- Config (verbatim): `DepositBoxCount = 8`, `DepositBoxCash = 1500`, `GoldBarChance = 0.5`, `GoldBarValue = 8000`

**Interfaces:**
- Consumes: Task 1 (`AddBonus`, `SupplyObject` `startHidden`/`GiveTo`/`bankOnly`/`speedCap`, `CarryGetaway`), Task 2 (`LockedDoor` `onSolved`/`objectText` and the one-attempt rule).
- Produces: `DepositBoxLoot.roll(rng: Random, count: number, goldChance: number) -> {string}` with values `"cash" | "empty" | "gold"`.

- [ ] **Step 1: Failing spec `DepositBoxLootSpec`**: length `count`; at most one `"gold"`; over 2,000 seeded rolls of 8 the share of runs with gold is 0.5 ± 0.05 and, among non-gold boxes, cash is 2/3 ± 0.05; `goldChance = 0` → no gold; `goldChance = 1` → exactly one.
- [ ] **Step 2: Run, see it fail.**
- [ ] **Step 3: Implement**: each box a `LockedDoor` (`objectText = "Deposit Box"`, `location = "Bank"`, small `openCFrame` swing) registered after the safes, unlocked with the existing `vaultDoor.isOpen` latch (boxes refuse before it); contents rolled at `OnSessionStart`; `onSolved(p)`: cash → `bank:AddBonus(p, DepositBoxCash)` + toast "+1,500"; empty → toast "Empty."; gold → `goldBar:GiveTo(p)` + toast "Gold bar! Carry it 200 studs clear of the bank." (if refused because already carrying: toast and the bar stays for a re-solve-free pickup by that player: report how). Gold bar = `SupplyObject` with `startHidden`, `bankOnly`, `speedCap = 12`; a `CarryGetaway` (`isInsideBank`, Bank anchor, `GoldBarValue`) stepped in the heartbeat and forgotten in player cleanup. Walk the route out with a carrier and fix what refuses it.
- [ ] **Step 4: Run both suites; Play check**: open the vault (test shortcut allowed, say which), solve boxes until each outcome is seen at least once (seed or force contents; say how), carry the gold bar out of the vault to 200 studs: `leaderstats.Cash` +8000 once; one click with two box attempts judged once.
- [ ] **Step 5: Export, deviation rows, commit** `Batch: Bank deposit boxes`.

### Task 7: Closing Plays and vault

**Files:**
- Vault (`CrimeLife Vault/`): batch note `70 Batches/2026-11-17 Heist Layers.md` from `Templates/Batch Note Template.md`, a line at the top of `70 Batches/Batch Log.md`, `20 Systems/Robbery Heists and Getaway.md`, `Robbery Puzzles.md`, `Movement and Stamina.md`, `Police and Wanted.md` (carriers count as robbing, broadcast heat), `Notifications.md`, `60 Open Items/Open Items.md` (no getaway widget for heavy loot; anything parked), `80 Decisions/CrimeLife Tycoon Decisions.md` (the five rulings in the spec's last section plus the plan's rulings)

- [ ] **Step 1:** Three clean Plays (one per layer path not yet run end to end in a fresh Play): console free of new errors (asset-permission lines excepted).
- [ ] **Step 2:** Both suites once more: city 262 + new cases, all pass; heist failure set only `Zone`.
- [ ] **Step 3:** One enabled `SpawnLocation`; no `Tmp` scripts; no stray test attributes.
- [ ] **Step 4:** Vault updates as listed; the batch note ends with "NOT saved / NOT published".
- [ ] **Step 5:** Commit `Batch: heist signature layers`.
