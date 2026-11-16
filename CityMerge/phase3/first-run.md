# First run of the heists in the city (phase 3, Task 4)

Measured 2026-11-16 in `Crimelife city.rbxl` (resolved by name for every call). `Robbery System.rbxl`: one read-only Edit query (spawn and SlowFoods anchor positions); not played, not written. Every number below came from a call in this run; "not recorded" where none was made. Nothing saved or published.

## Method

- Six solo Plays from the city spawn (`Workspace.SpawnLocation`, the only enabled one). Play 1 before any change; Plays 2 to 6 after the audit fixes (`client-load-order-audit.md`) and the HUD edits, in the order the edits were made (see that file's verification table).
- Console: `LogService:GetLogHistory()` in the Server and Client datamodels at 25 s of `DistributedGameTime`, distinct lines by exact text, asset lines (`Failed to load ...`, `ContentId ... failed`) counted apart.
- Suites: a temporary server `Script` (`_T4Runner`) ran `RunUnitTest` per suite and with filter `""`, then `require(ServerScriptService.Heist.Tests.RunAll)()`; results passed back through `StringValue`s in `ServerStorage`.
- Profile cash: a temporary server `Script` (`_T4ProfileReader`) wrote `ProfileGateway.get(player).Data.cash` and `leaderstats.Cash` into `ServerStorage._T4Profile` every 0.1 s; read from server `execute_luau`.
- Session state, duffel and payouts on the client: a recorder connected to the real `HeistShared.Remotes` (`HeistState`, `DuffelState`, `ZoneOccupancy`, `Toast`, `RobberySuccess`) appending to a client-only `StringValue`; the getaway widget read from `PlayerGui.HeistHUD.<Location>Getaway` (`Visible`, `Studs.Text`, `Image` = `UITheme.Assets.GetawayNormal` / `GetawayNear`).
- Every temporary object removed before Play stopped; Edit afterwards: 0 `_T4*` objects.

How each step was driven:

| step | driven by |
|---|---|
| moving the character | server `Character:PivotTo` (beside the entrance, into the zone, out in steps) |
| holding a weapon | client `ReplicatedStorage.Weapons.Remotes.EquipRequest:FireServer(Crowbar, true)` (the city's real equip remote) |
| robbery trigger | the location's own server path: entering the interior zone while holding the `Weapon`-tagged Crowbar (`zoneService.Entered`, entry point A) |
| prompts (registers, terminals, C4, Go to Vault, Vault Door, Return to Lobby) | the real `ProximityPrompt` on the client: camera aimed at the prompt's part, then `InputHoldBegin` / `InputHoldEnd` for its `HoldDuration`. Found here: a prompt is shown (and can be held) only while its part is on screen; with the first-person camera facing away, `InputHoldBegin` and a real `E` key press did nothing |
| puzzles | none needed on these paths: no word scramble, lockpick or keypad was used (the Bank safe and NewsStation computer were not robbed; see "Not recorded") |
| death | server `Humanoid.Health = 0` |
| character removed | server `Character:Destroy()`, then `Player:LoadCharacter()` |

## Step 1: suites (Play 1; repeated in Play 4 after all changes)

City: 18 suites, each alone and filter `""`: **193 / 193 / 0** in both Plays (the 16 phase-2b suites 171 / 171 / 0, `CurrencyBridge_Test` 21 / 21 / 0, `WeaponTag_Test` 1 / 1 / 0).

Heist suite (`RunAll`): **586 passed, 13 failed** in both Plays. Failure set:

| spec | case | in the baseline set? |
|---|---|---|
| CashClaimVFX | 9 cases (Task 2's measured 3 / 9) | yes (G5 changed it; Task 5's) |
| RestaurantConfig | carries the spec's tunables (`CooldownDuration` 1200 vs 60) | yes (Task 5's) |
| Gas2GoConfig | carries the spec's tunables (`CooldownDuration` 600 vs 60) | yes (Task 5's) |
| TestRunner | freshRequire (lacking `PluginOrOpenCloud`) | yes, method effect of the temporary Script |
| Zone | real occupancy sweep (took 13.29 ms in Play 1, 10.04 ms in Play 4) | yes, the baseline's timing-sensitive case (4.86 ms in the Robbery place); environmental |

No new failure. `World` 51 / 51 in both Plays (also after the marker Folders became Models).

## Step 2: console at 25 s (Play 1)

Reference: the city before the import has no recorded line list (Task 1 recorded counts only); Task 2's pre-import Play had 47 server / 37 client distinct lines, all asset and test-driven families.

- Server: 35 distinct; 33 asset; 2 non-asset, both the known `Workspace.HQ` lines (`opendoor is not a valid member of Model "Workspace.HQ...DoorNoHandle"`, `Bar is not a valid member of ServerStorage`). Nothing new.
- Client: 53 distinct; 42 asset; 11 non-asset warnings, 0 errors:
  - 6 `[HeistClient] <location> status billboard not found` / `has no StatusBillboardAnchor` (NewsStation's pair came later, at about 48 s) and `Infinite yield possible on 'Workspace.Illegal Supplier:WaitForChild("Interaction")'`: streaming. Fixed (audit FIX rows).
  - `Infinite yield possible on PlayerGui:WaitForChild(...)` for `Custom Inventory` (x8), `WordScrambleGui`, `HeistNotificationGui`, `QuestResponsesGui`: the late StarterGui copy already recorded in the FPS audit (2026-11-15); the GUIs arrived (PlayerGui 28 in later reads). Not a fault; not seen in Plays 2 to 6.
- Plays 2 to 6: client 0 non-asset warnings and 0 errors at 25 s; server only the two `Workspace.HQ` lines.

## Step 4: a heist end to end

Getaway: `EscapeDistance` 200 at every location; distance = horizontal distance from the location's `StatusBillboardAnchor`. Profile and `leaderstats.Cash` read together from `_T4Profile`.

### SlowFoods (Play 2)

Route: exit spawn (96.8, 1778.8), then north along x = 96.8 at floor level (an Edit raycast walk every 4 studs from the exit spawn found floor below y 8 the whole way to 400 studs). Session 120 s. Triggered at 63.7 s (`HeistState` Active, 1:41 left at the first read; the `RobberyTriggered` card showed). Two registers robbed through their prompts (hold 8 s each): duffel 2,000 then 4,000 / 4,000 (`DuffelState` at 108.8 s and 125.1 s). `ZoneOccupancy` inside = false at 138.2 s.

| step | horizontal | getaway widget (client) | duffel | `leaderstats.Cash` | profile `cash` |
|---|---|---|---|---|---|
| before | in the zone | hidden | 4,000 / 4,000 | 500 | 500 |
| 100 | 100.00 | shown, `100`, Normal | 4,000 | 500 | 500 |
| 150 | 150.00 | shown, `50`, Near | 4,000 | 500 | 500 |
| 199 | 199.00 | shown, `1`, Near | 4,000 | 500 | 500 |
| 201 | 201.00 | hidden (bag empty) | 0 (`DuffelState` base 0 at 178.0 s) | **4,500** | **4,500** |
| 250 | 250.00 | hidden | 0 | 4,500 | 4,500 |

One credit of 4,000 = the duffel (`Toast` "Banked 4000 Cash.", `RobberySuccess`, both at 178.0 s). The session then ran out at 181.5 s (`HeistState` Cooldown, duffel base 0): nothing more. Badge (client `StatusImage`) Active during the run, Cooldown at the 250 read.

### Bank (Play 2)

Session 600 s. Beside the entrance (exit spawn 1142.9, 2305.8), into the lobby (`BankZone`) holding the Crowbar: `HeistState` Active and `RobberyTriggered` at 228.8 s. Terminal 1 and 2 prompts (hold 0.4 s): both terminal highlights went off. `Attach C4` prompt on `TeleporterBankA` (hold 5 s), the 5 s countdown, then `Go to Vault` (the real teleporter step): landed at `TeleporterBankB` (1404.3, -114.9, 2294.6), joining the roster. Through the gauntlet by `PivotTo` (lasers, guard room and obby pit not played: `GuardDamage` is 0, and the move stood beside the door), `Vault Door` handle prompt (hold 10 s; the button prompt with line of sight did not trigger), door open after 8.2 s; ATM prompts appeared. Into `VaultZone`: accrual at 133 / s (`DuffelState` rate 133). `Return to Lobby` prompt on `TeleporterBankB`: back at `TeleporterBankA` with 3,029 / 15,000. The time spent finding the prompt behaviour above left 2:20 on the clock, so the ATMs, registers and safe were not robbed.

Route out (Edit check, raycasts every 4 studs from the exit spawn along the bearing, transparent and non-collidable parts skipped: road or footpath the whole way to 260 studs; 175 and 200 degrees were the only two of 72 bearings that were): exit spawn (1142.9, 2305.8), then bearing 200 degrees (west-south-west, along the road in front of the Bank): (1123.8, 2298.8) at 100, (1076.7, 2281.7) at 150, (1030.5, 2264.9) at 199, (1028.7, 2264.2) at 201, (982.6, 2247.4) at 250. (In Play the drop raycast did not skip transparent parts: the 199 step stood on a palm leaf at y 12.6, the others on the road.)

| step | horizontal | getaway widget (client) | duffel | `leaderstats.Cash` | profile `cash` |
|---|---|---|---|---|---|
| before (lobby) | in the building | hidden | 3,029 / 15,000 | 4,500 | 4,500 |
| 100 | 100.00 | shown, `101`, Normal | 3,029 | 4,500 | 4,500 |
| 150 | 150.00 | shown, `51`, Normal | 3,029 | 4,500 | 4,500 |
| 199 | 199.00 | shown, `2`, Near | 3,029 | 4,500 | 4,500 |
| 201 | 201.00 | hidden | 0 | **7,529** | **7,529** |
| 250 | 250.00 | hidden | 0 | 7,529 | 7,529 |

One credit of 3,029 = the duffel (`Toast` "Banked 3029 Cash." and `RobberySuccess` at 765.3 s); nothing more at 250. The widget read 1 stud above the server distance at 100, 150 and 199 (the client rounds up, and the character settles by up to a stud after the pivot).

### Gas2Go and NewsStation (Play 2): trigger and one claim

| location | trigger | claim | out to 201 / 250 | cash / profile before -> after |
|---|---|---|---|---|
| Gas2Go | into `Gas2GoZone` holding the Crowbar: `RobberyTriggered` card | one `Gas2GoRegister` prompt (hold 8 s): 2,000 / 4,000 | (-986, 1827) at 201 (on `Buildings.Hood.Building_18` roof), (-986, 1778) at 250 | 7,529 -> 9,529 at 201, 9,529 at 250 |
| NewsStation | into `NewsroomZone` holding the Crowbar | one `NewsStationRegister` prompt: 2,000 / 10,000 | along the anchor -> exit spawn bearing, on `Workspace.Ground.Baseplate` | 9,529 -> 11,529 at 201, 11,529 at 250 |

Final of Play 2: `leaderstats.Cash` 11,529, profile `cash` 11,529. Every bank-in credited once and equalled the duffel; profile equalled `leaderstats.Cash` at every read.

## Step 5: voided hauls (Play 3, SlowFoods, one register = 2,000 each run)

| run | how | credit | errors | state (client `HeistState`) |
|---|---|---|---|---|
| A: death | `Health = 0` at 58.6 s, bag 2,000 | none: cash / profile 500 / 500 before, after, and after respawn at the city spawn (783 studs out) | none | Active 37.3 s -> Cooldown 153.2 s (timer) -> Idle 213.1 s |
| B: timer | stood 150 studs out with 2,000 and let the 120 s run out | none: 500 / 500 | none | Active 262.9 s -> Cooldown 381.8 s with `DuffelState` base 0 at the same tick -> Idle 441.5 s. Not teleported (already outside) |
| C: character removed | `Character:Destroy()` at 480.5 s with 2,000, then `LoadCharacter()` | **credited 2,000**: 500 -> 2,500 (profile 2,500) at 484.5 s, `Toast` "Banked 2000 Cash." | none | Active 456.5 s; Cooldown 575.8 s; no second credit |

Run C does not meet the brief's "no credit". Cause (code): `LocationServer` voids a bag only on `Humanoid.Died` and on session end, and forgets the player only on `PlayerRemoving`; a character removed without dying leaves the bag and the roster entry, and `Getaway` banks it once a character stands 200 studs out. The city spawn is 783 studs from SlowFoods, so the respawn itself banks it. The same code runs in the Robbery place, where the spawn is 138 studs from SlowFoods (Edit read), so there the respawned player banks the bag after walking about 62 studs. Not caused by the merge; recorded, not fixed (rule). The `SessionDuration` override was not needed: run B used the real 120 s (`RestaurantShared.Config` is frozen; its `Debug.FastLifecycle` would have made it 10 s).

## Step 6: HUD

Viewport 1080 x 659 (top bar inset 58). 844 x 390 cannot be set from the MCP (no device emulator control, `Phone Testing`); its boxes are computed from the same `Position` / `Size` / `AnchorPoint` / inset and the `HudClusterScale` formula (`clamp(H / 1080, 44 / 76, 1)`), with the model checked against live `AbsolutePosition` / `AbsoluteSize` at 1080 x 659 (all 6 city elements equal). Screen pixels, [x, y, w x h].

City elements: stamina bar [420, 78, 240x10]; notification stack container [780, 551, 280x84] (transparent, empty when nothing is shown); level bar [410, 574, 260x14]; level-up popup [360, 223, 360x90] (only while a level-up shows); hotbar [425, 599, 231x51]; cash [70, 601, 164x46]; quest log button [16, 494, 46x46]. At 844 x 390: stamina [302, 78], stack [544, 282], level bar [292, 321], popup [242, 129], hotbar [313, 333, 219x49], cash [67, 335, 155x44], quests [16, 233, 44x44].

| Robbery element | before (1080) | after (1080) | after (844 x 390) |
|---|---|---|---|
| timer | [420, 12, 240x76] | [420, 2, 240x76] | [302, 2] |
| duffel | [390, 96, 300x92] | [390, 88, 300x92] | [272, 88] |
| getaway | [420, 196, 240x76] | [420, 188, 240x76] | [302, 188] |
| toast | [330, 280, 420x48] | [330, 272, 420x48] | [212, 272] |
| notification card (with alarm box) | [644, 447, 420x122], live | [644, 429, 420x122], live (Play 4) | [408, 160] |

Overlapping pairs found and moved (the Robbery side, smallest offset):
1. Timer x stamina bar (y 78..88), both sizes: `HeistClient` `HUD_TOP` 12 -> 2 (timer ends at 78) and `DUFFEL_TOP` + 2 (duffel starts at 88): no single shift clears both (the bar sits in the 8 px gutter), and a wider gutter for every gap would push the toast onto the level bar at 844 x 390.
2. Notification card x city notification stack (18 px), both sizes: `NotificationClient` `INSET_Y` 90 -> 108, card bottom on the container's top edge (live: card bottom 551, container top 551, no overlap).

Overlaps left, all involving an element that shows only for seconds:
- level-up popup x getaway and x toast (1080); x getaway, duffel and card (844 x 390): the popup is centred at 35 % height and shows only during a level-up; clearing it would mean moving the whole heist strip.
- toast x notification stack (844 x 390 only): the 420 px toast is centred on an 844 px screen and the stack is bottom-right; no vertical move clears it without covering the getaway widget.

Cash dimming (Task 2 carry): `UiButtonEffects` now hides `Custom Inventory.cashDisplay` during a heist modal. Play 3: `LockpickGui.Enabled = true` -> `cashDisplay.Visible` false and `HeistHUD.Enabled` false; closed -> both back.

Screen capture: one at 1080 x 659 in Play 4 (city spawn, heist strip and card not on screen at that moment): no capture of the heist elements. 844 x 390: no capture.

## After the run (Edit)

432 source containers, 242 BaseScripts, 166 enabled, Enabled checksum 3576485474 (unchanged), source checksum 2842082509 (Task 3: 784918162; only `HeistClient`, `NotificationClient`, `UiButtonEffects` changed, `after-import.md`); `Workspace` descendants 236,393 (unchanged); 1 enabled SpawnLocation (`Workspace.SpawnLocation`); 0 `_T4*` objects; `Workspace.HQ` 58,277 descendants, untouched. Marker containers Model / Persistent, `Illegal Supplier` Persistent.

## Not recorded

- Bank ATMs, Bank registers and the Bank safe (keypad through `SubmitSafeCode`): not robbed (time). The Bank duffel came from vault accrual only.
- Word scramble, lockpick, hack code: not exercised.
- 844 x 390 live readings and its capture.
- Run C in the Robbery place (read from code and the spawn distance, not played).

NOT saved / NOT published
