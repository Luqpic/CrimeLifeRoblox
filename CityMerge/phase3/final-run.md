# Closing run (phase 3, Task 6)

Measured 2026-11-16 in `Crimelife city.rbxl` (resolved by name; `Robbery System.rbxl` not touched). Every number below came from a call in this run. Nothing saved or published; no script changed.

## Step 1: five Plays from the city spawn

Method: Play 1 to 5, each stopped and restarted. Console read through `LogService:GetLogHistory()` in the Client and the Server datamodels (the read landed at 27.6 to 34.9 s of `DistributedGameTime`, not exactly 25 s: each call carries the tool's latency). Error and warning lines counted apart as asset lines when they contain `Failed to load`, `ContentId`, `asset` or `Asset`; every other distinct line listed. One enabled `SpawnLocation` read inside Workspace.

| Play | read at (client / server) | client non-asset lines | client asset lines | server non-asset lines | server asset lines | PlayerGui / PlayerScripts | enabled SpawnLocations in Workspace |
|---|---|---|---|---|---|---|---|
| 1 | 34.3 / 34.9 s | 0 | 356 | 2 | 186 | 28 / 33 | 1 |
| 2 | 28.6 / 29.1 s | 0 | 319 | 2 | 176 | 28 / 33 | 1 |
| 3 | 27.6 / 28.4 s | 0 | 319 | 2 | 160 | 28 / 33 | 1 |
| 4 | 27.6 / 28.1 s | 0 | 315 | 2 | 162 | 28 / 33 | 1 |
| 5 | 27.8 / 28.5 s | 0 | 329 | 2 | 169 | 28 / 33 | 1 |

The two server lines are the same in every Play, both from `Workspace.HQ` (the developer's paste, not touched): `opendoor is not a valid member of Model "Workspace.HQ...Proximity Door.DoorNoHandle"` and `Bar is not a valid member of ServerStorage "ServerStorage"`. The brief expected three; two were logged in all five Plays. 0 client script errors or warnings outside asset lines. (A whole-place scan finds a second enabled `SpawnLocation`, `ServerStorage.CityQuarantine.LooseTycoon.TycoonSpawn`: inert, a known Open Item, not in Workspace.)

## Play 5: suites

Both run from a server `execute_luau` call in the Play server datamodel, no temporary Script (`require(ServerStorage.UnitTest.RunUnitTest)(name)` returns a table of `run` / `passed` / `failed`).

City: 18 suites, each alone and filter `""`: **193 / 193 / 0** (BlasterGuard 4, CosmeticsOwnership 12, CurrencyBridge 21, Palettes 11, ProfileAdoption 17, ProfileGateway 22, PropertyAuthority 8, QuestReach 4, QuestSave 10, Schema 9, ShotRate 5, SkinApplier 14, SpraypaintConstants 8, SpraypaintService 21, SpraypaintTier 8, WeaponTag 1, staminaStep 10, validateRunningState 8).

Heist (`require(ServerScriptService.Heist.Tests.RunAll)()`): **615 passed, 1 failed.** The failure is `Zone`: "the real occupancy sweep ignores non-character geometry" (`sweep must not walk the 1200 parts sharing its volume (took 5.23ms)`), a timing assertion. It also fails in the Robbery place (`spec-baseline.md`: 4.86 ms and 3.41 ms) and in the city's Task 4 run (13.29 and 10.04 ms). `TestRunner` 5 / 5 here (the capability case needs `execute_luau`), `CashClaimVFX` 13 / 13, both cooldown configs pass.

## Play 5: SlowFoods, AK47, quest

Profile cash read by a temporary server Script (`_T6ProfileReader`, writing `profile` and `leaderstats.Cash` into `ServerStorage._T6Profile` every 0.1 s). Both removed before Play stopped.

| step | driven by | result |
|---|---|---|
| Crowbar equipped | client `Weapons.Remotes.EquipRequest:FireServer(Crowbar, true)` | held |
| Robbery triggered | server `PivotTo` into `SlowFoodsZones.RestaurantZone` (100.0, 7.5, 1730) while holding the Crowbar | register prompts enabled (4, hold 8 s) |
| Register robbed | real prompt: camera aimed at its part, `InputHoldBegin`, 8.5 s, `InputHoldEnd` | `Triggered` fired |
| Bank-in | server `PivotTo` along x = 96.8, horizontal distance from `StatusBillboardAnchor` | see table |

| distance | `leaderstats.Cash` | profile `cash` |
|---|---|---|
| before (in the zone) | 500 | 500 |
| 100.0 | 500 | 500 |
| 199.0 | 500 | 500 |
| 201.0 | **2,500** | **2,500** |
| 250.0 | 2,500 | 2,500 |

One credit of 2,000 (one register), banked once, equal in profile and `leaderstats.Cash`.

AK47: `BuyRequest:FireServer("AK47")` from the client: cash 2,500 to 2,300 (profile the same), `WeaponOwned_AK47` true.

Quest: character 5.9 studs from `Workspace.Quests["Level 1 Quest"]`; client `AcceptQuestRequest:FireServer("Level1Thugs")` -> `Accepted`, progress 0. Ten kills fired as `ServerScriptService.Blaster.Events.Eliminated:Fire(player, humanoid)` on a temporary Model with `EnemyTemplate = "Thug"` (not real enemies, destroyed each time): progress 10, `ReadyToTurnIn`, cash 2,300 to 2,375 (profile the same). Client `TurnInQuestRequest:FireServer("Level1Thugs")`: state cleared, completions 1, level 5, XP 40, cash 2,375 to 2,900 (+500 reward +25 level-up bonus; profile 2,900 = `leaderstats.Cash`).

## Step 2: checksums against Task 1's baseline

Definitions as in `phase2b/baseline.md` (Adler-32 over the sorted `<full name>=<Enabled>` of BaseScripts and `<full name>=<Source>` of every container, joined with `\n`), taken in Edit before and after the five Plays.

| | containers | BaseScripts | enabled | Enabled checksum | source checksum |
|---|---|---|---|---|---|
| Task 1 baseline (`spec-baseline.md`) | 326 | 220 | 144 | 4126413690 | 3149783013 |
| now, before Play | 434 | 242 | not recorded | 3576485474 | 4229094150 |
| now, after Play 5 (temporary objects removed) | 434 | 242 | not recorded | 3576485474 | 4229094150 |

Reconstructing the baseline from the current place by program (per-entry length and Adler-32, `adler32_combine`): dropping the 22 added BaseScripts gives Enabled **4126413690**; dropping the 108 added source containers and putting `ReplicatedStorage.Modules.MenuFovBlur` back to its recorded old length and Adler-32 (1,831 / 3514199789) gives source **3149783013**, both equal to the baseline, over 220 and 326 entries. So the scripts whose source differs from the baseline are exactly:

- 1 city script edited: `ReplicatedStorage.Modules.MenuFovBlur` (G7, `acquire()` added).
- 108 scripts added to the baseline set:
  - 102 imported from the Robbery place and still where they were put (containers under a `Robbery System` import stamp, less the three city-new modules inside imported roots). Of these, edited after the import (`after-import.md`, "Phase 3 deviations"): `HeistClient`, `NotificationClient`, `UiButtonEffects`, `CashClaimVFX`, `CashClaimVFXSpec`, `RunAll`, `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer`, `SuppliesServer`, `HeistServer`, `LocationServer`, `LocationServerSpec`, `GamepassManager`, `GamepassManagerSpec`, `Heist.Components.Safe`, `NewsStationSafeSpec`, `RestaurantShared.Config`, `Gas2GoShared.Config`;
  - 1 retired: `ServerStorage.CityQuarantine.RetiredSpecs.CurrencySpec` (imported, moved);
  - 5 new in the city: `ServerScriptService.PlayerData.CurrencyService` (the bridge), `CurrencyBridge_Test`, `WeaponTag_Test`, `Heist.Services.SupplierSale`, `Heist.Tests.SupplierSaleSpec`.
  - Arithmetic: 105 containers sit under a `Robbery System` import stamp (102 imported + `CurrencyService`, `SupplierSale`, `SupplierSaleSpec`), 3 more are named explicitly (`CurrencySpec`, the two city tests): 108.
- 22 added BaseScripts (13 from Task 2, 9 from Task 3), all imported with `Enabled = false` and `ImportEnabled`; enabled count 144 to 166 after `ImportEnabled` was applied (`after-import.md`).

No other script differs: every city-original container (326, MenuFovBlur aside) has the baseline source. `Workspace` descendants 236,393, 1 enabled `SpawnLocation` in Workspace, 0 temporary objects (`^_T%d`), after the run.

NOT saved / NOT published
