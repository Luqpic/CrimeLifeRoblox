# Remote ownership audit: Crimelife city.rbxl (phase 2b, Task 2)

Leg 1 (audit only, no edit to the place). Read 2026-11-15 from the Studio instance `Crimelife city.rbxl`
and from `CityScripts/`. Line numbers are the ones read in this run.

Verdict rule (brief): FIX only when a client can (a) act on something it does not own, (b) get an
untyped, NaN or out-of-range value written into state or a save, or (c) gain cash, XP, a weapon, a skin
or quest credit without doing the thing. A missing rate limit alone is OK plus a note.

## Inventory (measured)

A scan of every LuaSourceContainer for `OnServerEvent` / `OnServerInvoke` found exactly 14 hooks, matching
the brief's table line for line. No `RemoteFunction` exists in ReplicatedStorage; there is no `OnServerInvoke`.

Server-to-client only (no `OnServerEvent` anywhere in the place):

| Remote | Class | Fired from |
|---|---|---|
| `Blaster.Remotes.ReplicateShot` | UnreliableRemoteEvent | `ShotResolver` 754 (`FireClient` per other player) |
| `Blaster.Remotes.DamageIndicator` | RemoteEvent | `ShotResolver` 215, 230 |
| `Blaster.Remotes.DamageDirection` | RemoteEvent | server-to-client; no server listener |
| `Blaster.Remotes.KillConfirmed` | RemoteEvent | `LevelingService` 268 |

## Client-to-server handlers

| # | Remote | Handler : line | Arguments and type check | Ownership (what the client names, and the proof) | NaN / range | 100 calls/s | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | `Blaster.Remotes.Shoot` | `Blaster` 83 -> `onShootEvent` 18 | `timestamp` number, not NaN (`validateNumber`, vSA 18); `blaster` real `Tool` (`validateInstance`, vSA 21); `origin` CFrame with non-NaN Position and LookVector (`validateCFrame`, vSA 24); `tagged` table, every key a string, every value a real `Humanoid` (`validateSimpleTable`, vSA 27) | Tool: `blaster.Parent ~= character` -> reject (`validateShot` 38). Character alive (29), not reloading (44), ammo > 0 unless infinite (51-55), origin within 5 + 0.4 x speed studs of the root (59-63). Claimed humanoids: each re-checked by `validateTag` (team rule, wall check, aim cone of 10 studs) against the server's recast of the SAME ray index (`ShotResolver` 672-686) | timestamp: NaN rejected (vSA 18); 1e18 > now rejected (vS 13); negative < now - 1 rejected (vS 16); non-integer is legal (it is the spread seed). origin inf: fails the distance check (vS 61). **Key gap:** `tonumber(indexString)` (`ShotResolver` 672) folds `"1"`, `"01"`, `"1.0"`, `" 1"`, `"+1"`, `"1e0"`, `"0x1"` all to index 1 (measured in Studio), and the table size is uncapped, so one ray can be claimed N times against one humanoid; each claim passes `validateTag` (same ray) and calls `applyDamage` (703), which only stops at Health <= 0 | No server rate-of-fire check exists (`rateOfFire` is read only by the client `BlasterController` 214 and `EnemyAI` 444). A gun empties its magazine as fast as packets arrive; an infinite-ammo melee weapon swings without limit. No throw | **FIX** (c): a single shot claiming one ray many times deals N x damage and takes the kill, so the Eliminated listeners pay cash, XP, Spraypaint and quest progress for hits that never happened. **FIX** (controller ruling): no server rate of fire. Fixed: F3, F4. Note: any claimed timestamp from the last second is accepted, so after an idle spell one burst passes before the cap holds (about 12 AK47 shots, 2 swings of a 30 rpm weapon); accepted as a consequence of using claimed timestamps |
| 2 | `Blaster.Remotes.Reload` | `Blaster` 84 -> `onReloadEvent` 46 | `blaster` real `Tool` (`validateInstance`, 48) | Tool: `blaster.Parent ~= character` -> reject (`validateReload` 11); not already reloading (15) | no numbers from the client; `reloadTime` and `magazineSize` read from the server Tool | RELOADING attribute blocks repeats until the delay ends; at most one pending `task.delay` per tool | OK |
| 3 | `Cosmetics.Remotes.EquipSkinRequest` | `CosmeticsService` 128 -> `handleEquipRequest` 107 | `weaponName`, `paletteKey` strings (108) | Weapon: must be a `Tool` in `ServerStorage.Weapons` (114-116), which bounds the attribute and save key; weapon ownership is NOT checked (the attribute is a per-type preference, nothing is granted). Palette: `ownsPalette` (118 -> 27-43): unknown key false; Vip palette needs the server-set `Owned_Vip` attribute; Spraypaint palette needs the server-set owned attribute; free palettes true | no numbers | each call = 1 SetAttribute, 1 `ProfileGateway.mirror`, a re-skin of held copies; no DataStore call per request (mirror writes the in-memory profile) | OK. Note: a skin choice can be stored for a weapon type the player does not own; harmless, nothing is granted |
| 4 | `Monetization.Remotes.PromptProductPurchase` | `MonetizationService` 61 | `key` string (62), looked up in `Constants.CashTiers` (65) | names a tier key, never a product id; cash is granted only in `ProcessReceipt` (93-117) | no numbers | unconfigured key -> one `print` per call (69), echoing the client's string into the server log; configured -> a prompt on the caller's own screen | OK. Note: log spam only |
| 5 | `Monetization.Remotes.PromptGamepassPurchase` | `MonetizationService` 75 | `key` string (76), looked up in `Constants.Gamepasses` (79) | names a pass key; ownership is published only from `UserOwnsGamePassAsync` (133-136) or `PromptGamePassPurchaseFinished` (146-156) | no numbers | same as 4 | OK. Note: same log spam |
| 6 | `UpdateRunningState` | `RunningState` 27 -> `onUpdateRunningState` 10 | `isRunning` boolean (`validateRunningState` 24); character with a `HumanoidRootPart` (28-34) | own character only; `SprintAuthority.setIntent` (77-89) grants sprint only when stamina is not locked out | no numbers | same value repeated inside 0.05 s rejected (38); alternating values pass, each = 1 SetAttribute on the own root | OK |
| 7 | `Quests.Remotes.AcceptQuestRequest` | `QuestService` 65 | `questId` string (66), must exist in `QuestConfig.Quests` (69) | names a quest; required level checked against the server-set `Level` attribute (82-85); one-shot (78). **No check that the player is at the giver** | no numbers | one-shot per quest; cheap | **FIX** (c): quest credit (acceptance) from anywhere on the map, never having talked to the giver |
| 8 | `Quests.Remotes.TurnInQuestRequest` | `QuestService` 130 | `questId` string (131), must exist (134) | entry must be `ReadyToTurnIn` (141), which only the server's kill tracker sets (118-122). **No check that the player is at the giver** | no numbers | after the first turn-in the entry is Completed or cleared; cheap | **FIX** (c): cash + XP reward (148, 150) handed in from anywhere |
| 9 | `Spraypaint.Remotes.BuySkinRequest` | `SpraypaintService` 219 -> `handleBuySkinRequest` 192 | `paletteKey` string (`handleBuyRequest` 163); `weaponName` string (200) | Palette must exist and be Spraypaint-sourced (166-169), not already owned (170), priced (173-179); `spend` (76-90) refuses non-positive, non-integer or unaffordable amounts. Weapon: `Tool` in `ServerStorage.Weapons` (203-205); ownership not checked (same preference-only reasoning as row 3) | price is server data; no client number | after the first success the owned check (170) refuses; failed calls are pure reads | OK |
| 10 | `Weapons.Remotes.EquipRequest` | `EquipService` 22 | `equip` boolean (23); `tool` real `Tool` (`validateInstance`, 43) | Tool: `tool.Parent ~= backpack` -> reject (50); alive (40). Unequip needs no tool and only unequips the caller | no numbers | each call = one EquipTool / UnequipTools on the own humanoid | OK |
| 11 | `Weapons.Remotes.UpgradeRequest` | `WeaponUpgradeService` 74 | `weaponName` string (77); must be a `Tool` in `ServerStorage.Weapons` with a numeric `damage` (81-88) | Weapon: `WeaponOwned_<name> ~= true` -> reject (100). The attribute is server-written only | no client number; level is read from the server attribute (111), cost = 50 x next level (`UpgradeConfig` 7) checked against Cash (114) | each call spends cash or returns; no level cap, but every level is paid for | OK. Note: no MAX level |
| 12 | `Leveling.Remotes.SetLevelRequest` | `LevelingService` 30 | `targetLevel` number (34) | `player.UserId ~= ADMIN_USER_ID` -> reject (31); one hard-coded admin account | negative, 0, 1e18 and inf clamp into 1..LEVEL_CAP (39). **NaN passes**: `math.floor(NaN)` and `math.clamp(NaN, 1, 70)` both return NaN (measured), so NaN would reach `leaderstats.Level`, the `Level` attribute and `profile.Data.level` (44-56). Reachable only from the admin account | admin only | **FIX** (controller ruling, F5): NaN refused beside the type check |
| 13 | `Weapons.Remotes.BuyRequest` | `WeaponShopService` 320 | `weaponName` string (321); `Tool` in `ServerStorage.Weapons` (325-328) | Gamepass weapon: server-set pass attribute required (335-339). Cash weapon: numeric `Price` (340), not already owned (`isWeaponOwned` 344 -> 166-169), Cash >= price (350) | price is server data | after the first success `isWeaponOwned` refuses; handler does not yield, so no double-spend race | OK |
| 14 | `Weapons.Remotes.SetLoadoutSlotRequest` | `WeaponShopService` 369 | `weaponName` string (370); `slotIndex` nil or number with `% 1 == 0` and 1..4 (373-376) | Weapon: `isWeaponOwned` (378) | NaN: `NaN % 1` is NaN, `~= 0` -> rejected; inf: `inf % 1` is NaN -> rejected; negative and 1e18 out of 1..4 -> rejected; 2.5 -> rejected | each call clones a fresh Tool into the Backpack and mirrors the loadout | OK. Note below |

vSA = `validateShootArguments`, vS = `validateShot`.

## Notes on OK rows

- **Shoot, rate of fire.** Rated OK in Leg 1; the controller ruled it FIX (100 swings a second kill
  everything in reach and pay out). See F4.
- **Shoot, seed choice.** The timestamp is both the replay check and the spread seed, and it may be anything
  in the last second, so a crafted client can pick a seed with a favourable spread. Minor.
- **Shoot, non-blaster Tool.** A Tool in the character without an `_ammo` attribute makes `ammo <= 0`
  (`validateShot` 53) throw. The throw ends that one handler call; nothing is written.
- **SetLoadoutSlotRequest, re-slot.** Moving a weapon that is currently held in the character to another
  slot clears the old slot, does not destroy the held Tool (418-419 only touches `slots`; 434 only looks in
  the Backpack), and grants a fresh copy into the Backpack: the player holds two copies of a weapon they own,
  the new one with a full magazine. Not (a), (b) or (c) (the weapon is owned), so a note.
- **Skin for an unowned weapon (rows 3, 9) and the second copy on re-slot (row 14):** controller ruling
  OK plus this note, no change.
- **Rate limits.** Only `UpdateRunningState` has one (and Shoot after F4). None of the other handlers yields on a DataStore or web
  call per request, so 100 calls a second costs attribute writes and in-memory profile writes only.

## FIX rows: smallest change and failing test

### F1, F2: `AcceptQuestRequest` (QuestService 65), `TurnInQuestRequest` (QuestService 130)

- Gap: neither handler checks where the player is, so both work from anywhere.
- Walk-away distance `W` = **10** studs: `ReplicatedStorage.DialogModule` 279 `local range = 10`, used by
  the loop at 280-298 that ends a conversation when `distance > range`. `QuestDialogueController` 117 builds
  every quest dialogue through `DialogModule.new`. The givers' ProximityPrompts also have
  `MaxActivationDistance` 10. So `MAX_INTERACT_DISTANCE = math.max(30, W + 10) = 30`.
- Spawn to givers (measured): Level 1 Quest 40.2, Level 10 52.5, Level 20 65.5, Level 35 78.9,
  Level 50 92.4, Level 70 106.1 studs. All exceed 30, so the brief's Step 8 refusal from the spawn works
  without the 200-stud move.
- Fix (brief Step 5): `QuestConfig.MAX_INTERACT_DISTANCE` and `QuestConfig.withinReach(a, b)`; in
  QuestService one local `canReach(player, quest)` and an early return in both handlers.
- Test: `ServerStorage.UnitTest.Cases.QuestReach_Test` (brief Step 3, verbatim). Red: 4 run, 0 passed.

### F3: `Shoot` (Blaster 83), duplicate ray-index claims

- Gap: `claimedTags` keys are only type-checked as strings. `tonumber` maps many spellings to one index, so
  one ray can be claimed against the same humanoid any number of times and each claim deals damage.
- Smallest fix: in `Blaster.validateShootArguments`, after the `validateSimpleTable` check (27-29), reject
  any key that is not the canonical spelling of its own number:
  `for key in tagged do if tostring(tonumber(key)) ~= key then return false end end`.
  This is the client-trust layer, so the AI path through ShotResolver (no `claimedTags`) is untouched, and a
  real client is unaffected (it builds keys with `tostring(index)`: `ReplicatedStorage.Blaster.Scripts.BlasterController` 164, read
  this run).
- Test: `ServerStorage.UnitTest.Cases.BlasterGuard_Test`, requiring the `validateShootArguments` module with
  a real `Tool` and `Humanoid` made by `Instance.new`:
  - `{ ["1"] = h, ["2"] = h }` -> true (a shotgun hitting one target with two pellets stays legal)
  - `{ ["1"] = h, ["01"] = h }` -> false (red today: returns true)
  - `{ ["1e0"] = h }` -> false (red today)

### F4: `Shoot` (Blaster 83), server rate of fire (controller ruling)

- Preconditions checked: `validateShot` 13-17 bounds the claimed timestamp to [server now - 1 s, server now];
  `rateOfFire` is rounds per minute (BlasterController waits `60 / rateOfFire` between Shoot events in Semi
  222, Auto 234 and Burst 253); a shotgun's pellets are one Shoot (`raysPerShot`), a melee swing is one
  Shoot (fired after a fixed `swingDelay`); all 38 Tools in `ServerStorage.Weapons` declare `rateOfFire`
  (30 to 1200). So the rule applies as ruled.
- Fix: new pure module `Blaster.validateFireInterval(lastTimestamp, timestamp, rateOfFire)`; `validateShot`
  calls it last and records the accepted claimed timestamp per player and per weapon NAME, cleared on
  PlayerRemoving. Refused when `timestamp - last < 0.9 * 60 / rateOfFire`.
- Fix round 1 (review finding): the state was first keyed by Tool instance. SetLoadoutSlotRequest hands out
  a fresh Tool on every call (row 14), and a fresh Tool had no last timestamp, so slot-move, EquipRequest,
  Shoot repeated swung without limit. Now keyed by `tool.Name`. Play, Crowbar (rof 90, 7.5 per claimed ray)
  on an anchored enemy, second shot 0.22-0.24 s after the first from the fresh Tool: before 85 -> 77.5 -> 70
  (two hits), after 130 -> 122.5 -> 122.5 (refused); a third swing 0.7 s later landed (-> 115).
- Note (accepted): any claimed timestamp from the last second of server time is accepted, so after an idle
  spell a client can send one burst back-dated across that second before the cap holds (about 12 AK47
  shots at 600 rpm, 2 swings of a 30 rpm weapon). Accepted as the consequence of judging claimed timestamps.
- Test: `ShotRate_Test` (first shot passes, one interval passes, half an interval refused, same timestamp
  refused, NaN refused).

### F5: `SetLevelRequest` (LevelingService 30), NaN (controller ruling)

- Fix: line 34 refuses `targetLevel ~= targetLevel` beside the type check. No pure seam added.
- Proof: Play, as the admin (the Studio test account matched `ADMIN_USER_ID`): `FireServer(0/0)` left
  Level 1, XP 0, leaderstats.Level 1. Not run before the fix (it would have written NaN into the session's
  profile), so the red side is by reading only.

## Leg 2 results (2026-11-15)

| Row | Test | Red (before fix) | Green (after fix) | Play check after fix |
|---|---|---|---|---|
| F1, F2 | `QuestReach_Test` | 4 run, 0 passed, 4 failed | 4 / 4 / 0 | From spawn (36.0 studs from Level 1 Quest): `Quest_Level1Thugs_State` stays nil (was `Accepted` before the fix, 38.4 studs). Server PivotTo 5.0 studs from the giver: `Accepted`. Turn-in shares `canReach`: read, not run |
| F3 | `BlasterGuard_Test` | 4 run, 2 passed, 2 failed (the two duplicate-key cases) | 4 / 4 / 0 | One Shoot with keys 1/01/1.0 on a Thug: before the fix 70 -> 40 (3 hits), after 80 -> 80 (shot refused) |
| F4 | `ShotRate_Test` | 1 run, 0 passed, 1 failed (module missing) | 5 / 5 / 0 | Two Shoot, same timestamp, AK47 (damage 10): before 90 -> 70, after 90 -> 80 (one hit). Three Shoot at the weapon's pace (`task.wait(60/600)`): 80 -> 50 (all three land) |
| F5 | none (read-not-run red) | n/a | n/a | NaN from the admin client refused (above) |

All suites after the fixes: 160 run, 160 passed, 0 failed (the 12 old suites 147 / 147 / 0 plus 13 new).
No `[FAIL]` line; no Quest/Blaster/Leveling error in the server or client log.
