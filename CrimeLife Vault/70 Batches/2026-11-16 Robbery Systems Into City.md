---
type: batch
tags: [batch, city, robbery, heists, economy, remotes, phase-3]
updated: 2026-11-16
sources: [".superpowers/sdd/2026-11-16-robbery-systems-into-city/progress.md", ".superpowers/sdd/2026-11-16-robbery-systems-into-city/final-fix-report.md", ".superpowers/sdd/2026-11-16-robbery-systems-into-city/task-1-report.md to task-6-report.md", "CrimeLifeRoblox/CityMerge/phase3/classification.md", "CrimeLifeRoblox/CityMerge/phase3/robbery-manifest.md", "CrimeLifeRoblox/CityMerge/phase3/currency-api.md", "CrimeLifeRoblox/CityMerge/phase3/locations.md", "CrimeLifeRoblox/CityMerge/phase3/spec-baseline.md", "CrimeLifeRoblox/CityMerge/phase3/client-load-order-audit.md", "CrimeLifeRoblox/CityMerge/phase3/first-run.md", "CrimeLifeRoblox/CityMerge/phase3/remote-audit.md", "CrimeLifeRoblox/CityMerge/phase3/final-run.md", "CrimeLifeRoblox/CityMerge/after-import.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-11-16-robbery-systems-into-city.md"]
---

# 2026-11-16 Robbery Systems Into City

Place: `Crimelife city.rbxl` (Edit and Play). `Robbery System.rbxl` was read and played once for baselines (Task 1), never written; `FPS System.rbxl` untouched. Plan: `docs/superpowers/plans/2026-11-16-robbery-systems-into-city.md` (phase 3, after [[2026-11-15 FPS Hardening In City]]). Ledger with every ruling: `.superpowers/sdd/2026-11-16-robbery-systems-into-city/progress.md`. Commits `f3e4338..775c447` (`aa6c585`, `3293de3`, `ac16bed`, `df82a72`, `5c0658c`, `d1c745d`, `09c9de8`, `775c447`), then this note's commit.

## Asked for

Phase 3: bring the four heists of `Robbery System.rbxl` (Bank, SlowFoods, Gas2Go, NewsStation) into the city so they run there at the city's own buildings, paying into the city's cash. The developer's calls: "Plan phase 3" (the plan) and, on seeing it, "Run, save checkpoints" (save the place after each task whose review is clean; never publish). The Robbery place is now the frozen reference, the city the running home ([[Robbery Heists and Getaway]]).

## What changed

**Task 1: survey, baselines and the gate** (`aa6c585`, `3293de3`). `CityMerge/phase3/robbery-manifest.md`: 56 roots in the Robbery place, classified carry 38, use the city's 5, bridge 1, rename 1, leave 11. Baselines (`spec-baseline.md`): the Robbery heist suite's stable failure set is the vault's 14 (12 `CashClaimVFX`, 2 `CooldownDuration`) plus two environmental cases; the city 171 / 171 / 0; city source checksum 3149783013, Enabled checksum 4126413690 over 326 containers. Twelve gate rulings G1 to G12 (`classification.md`, "Gate rulings"), listed in [[CrimeLife Tycoon Decisions]].

**Task 2: code and currency** (`ac16bed`). 25 roots outside `Workspace` imported from the transfer store (1,378 instances, 94 scripts, all Adler-32 equal to the manifest), their 13 Scripts and LocalScripts enabled only after parenting. One cash system: a bridge at `ServerScriptService.PlayerData.CurrencyService` gives the Robbery code its `CurrencyAdapter` API (`Load`, `Get`, `Add`, `PendingCount`, `Save`, `FlushAll`, `Release`) and writes only `player.leaderstats.Cash`, which the city's `CashService` mirrors into the profile (`CityMerge/phase3/currency-api.md`). The Robbery save layer stayed behind and `CurrencySpec` moved to `ServerStorage.CityQuarantine.RetiredSpecs`. `CashClaimVFX` builds no cash display of its own and flies coins to `Custom Inventory.cashDisplay`; the Robbery notification ScreenGui became `HeistNotificationGui`; `MenuFovBlur.acquire` added; `UiButtonEffects` carried; 38 weapons tagged `Weapon` with `WeaponTag_Test` (melee cannot start a robbery otherwise). Tests: 18 suites, 193 / 193 / 0 (`CurrencyBridge_Test` 21, `WeaponTag_Test` 1).

**Task 3: the four locations placed** (`df82a72`, `5c0658c`). The 14 Robbery roots in `Workspace` (plus `Illegal Supplier`) imported and moved by one transform each so every location lands within 0.000 to 0.0004 stud of plan on its city twin, with the entrance floor at the city's ground. The city's art twins (Bank, SlowFoods, Gas2Go, NewsStation) moved to `ServerStorage.CityQuarantine.ReplacedByHeist`; the casino and warehouse stay art. The Bank's vault sits 147.75 studs underground (y -154 to -44) below its transformed spot, split from the lobby by containment (G1). Three `openCFrame` literals transformed in-script (G12). Both `LinkedTeleporter` ObjectValues arrived nil (each root is serialized on its own) and were re-linked. Getaway rings clear of obstacles: SlowFoods 10 of 32 points, Gas2Go 18, NewsStation 15, Bank 5 (`EscapeDistance` kept at 200). Coordinates in `CityMerge/phase3/locations.md`.

**Task 4: first run, load-order audit, HUD** (`d1c745d`). `CityMerge/phase3/first-run.md`: all four heists bank once into Cash with the profile equal, nothing more at 250 studs; death and the timer void the bag. Streaming: no client could see the four `StatusBillboardAnchor`s or the Illegal Supplier's `Interaction` at the spawn, so the four marker Folders became Models of the same name with `ModelStreamingMode = Persistent` (no script path changed) and `Illegal Supplier` became Persistent (`client-load-order-audit.md`). HUD: `HeistClient` `HUD_TOP` 12 to 2 and `DUFFEL_TOP` + 2 (the timer covered the city stamina bar); `NotificationClient` `INSET_Y` 90 to 108 (the stack sat inside the city notification container); `UiButtonEffects` dims `Custom Inventory.cashDisplay` during a heist modal; `HeistClient` no longer re-enables the Backpack core GUI (G10).

**Task 5: remote audit and the spec debts** (`09c9de8`, `775c447`). `CityMerge/phase3/remote-audit.md`: 8 client-to-server remotes with 13 handlers (all through `Net`), 10 prompt `Triggered` kinds, 0 `RemoteFunction`s. Fixes:

| Defect | Fix |
|---|---|
| `SubmitSupplierChoice` had no reach check: a client sold carried supplies for 10,000 to 20,000 from 1,000 studs away | the sale decided in the new `Heist.Services.SupplierSale`: refused unless the living character is within 15 studs of `Illegal Supplier.Interaction` (`SupplierSaleSpec`, 6 cases with the dead-seller one) |
| A character removed without dying kept the bag (the respawn banked it past 200 studs; measured in Task 4) | `CharacterRemoving` forfeits the bag under the Active and participant guard, in `LocationServer` and `HeistServer`; `SuppliesServer` also drops its carry |
| A client-reported `PromptGamePassPurchaseFinished` cached ownership true (placeholder id `0` would grant the x4 duffel) | `GamepassManager` confirms with `UserOwnsGamePassAsync`, up to 3 pcall'd attempts 2 s apart, clearing a cached false first (review found the first fix lost to a stale false after a real purchase) |
| NewsStation safe codes could be tried faster than the prompt hold (the hold is enforced on the client) | `Safe` opt-in `enforceHold`: one player's attempts at least the prompt's `HoldDuration` apart |

Spec debts: `CashClaimVFX` requires `UITheme` at module scope (the 12 failing specs), and the two cooldowns set to the specs' values (`RestaurantShared.Config` 1200, `Gas2GoShared.Config` 600). `CashClaimVFXSpec` was rewritten for G5. `LockpickStopRequested` rated OK with a note.

**Task 6: closing run and this record.** Five Plays and both suites in `CityMerge/phase3/final-run.md`; the checksum difference list below; the vault updated; the commit `Batch: robbery systems into the city`.

## Decisions

Claude's calls (the gate's G1 to G12 and the controller's rulings from the ledger) are in [[CrimeLife Tycoon Decisions]] under 2026-11-16, each with its cost if wrong. The developer's words for the run: "Plan phase 3", "Run, save checkpoints", "Both are open, go".

## Verified

- **Closing run** (`CityMerge/phase3/final-run.md`), five Plays from the city spawn, each read at 27.6 to 34.9 s of `DistributedGameTime`: 0 client non-asset lines, 2 server non-asset lines (both from `Workspace.HQ`, the same in every Play), PlayerGui 28, PlayerScripts 33, one enabled `SpawnLocation` in Workspace.
- **Suites in Play 5:** city 18 suites, 193 / 193 / 0 (each alone and filter `""`); heist suite 615 passed, 1 failed: the `Zone` occupancy sweep timing assertion (5.23 ms against its limit), which also fails in the Robbery place.
- **SlowFoods banked once, in Play 5:** entered the zone holding the Crowbar, robbed one register through its real prompt (hold 8 s), moved to 201 studs from the anchor: `leaderstats.Cash` and profile 500 to 2,500, unchanged at 250. AK47 bought through `BuyRequest` (2,500 to 2,300); quest accepted at 5.9 studs, ten kills fired through the Blaster `Eliminated` event, turned in (2,375 to 2,900: 500 reward plus a 25 level-up bonus).
- **Checksums against Task 1's baseline:** with the 22 added BaseScripts dropped the Enabled checksum is 4126413690; with the 108 added source containers dropped and `ReplicatedStorage.Modules.MenuFovBlur` put back to its recorded old length and Adler-32 the source checksum is 3149783013: both the baseline values. So the scripts that differ are exactly: 1 city script edited (`MenuFovBlur`), 102 imported from the Robbery place (19 of them edited after the import), 1 retired (`CurrencySpec`), 5 new in the city (`CurrencyService`, `CurrencyBridge_Test`, `WeaponTag_Test`, `SupplierSale`, `SupplierSaleSpec`); every other city script has its baseline source. Now 434 containers, 242 BaseScripts, Enabled checksum 3576485474, source checksum 4229094150, unchanged by the five Plays.
- Every task was reviewed against the live place and approved (Task 5 after one fix round).
- Final state: one enabled `SpawnLocation` in Workspace, 0 temporary objects, `Workspace.HQ` untouched.

## Not verified

- **Puzzles by hand:** a real lockpick, the word scramble, the safe keypad and the hack code were not exercised in the city; nor were the Bank's ATMs, registers and safe (the Bank duffel came from vault accrual only).
- **A real E press and two players.** Prompts were held through `InputHoldBegin` with the camera aimed at them (a prompt shows only while its part is on screen); a person has not pressed E, and no heist was run with two players.
- **The Bank's getaway on foot from the vault**, and the ring's 5 clear points: only the road exit was walked (`first-run.md`).
- **844 x 390 on a live device** (positions computed from the same layout numbers, not read live) and a capture of the heist HUD.
- **The `CharacterRemoving` wiring in `LocationServer`:** proven by reading and the Bank Play, not run for the three on `LocationServer`.
- **A real gamepass purchase**: the duffel ids are placeholder `0`; the confirm is proven by specs through the ownership seam.
- Kills in the quest check were fired events on a temporary model, not real enemies; the Play 5 reads landed up to 10 s after 25 s.

## Left open

All in [[Open Items]]. New: the Bank escape ring has 5 of 32 clear points (`EscapeDistance` kept at 200); the checks that need a person; the removal toast says "You died before banking"; the duffel gamepass ids are still `0`; two gamepass systems (`GamepassManager`, `MonetizationService`); two notification styles on screen; the casino and warehouse are still art with no heist; the Task 2, 4 and 5 deferred minors; the three `Workspace.HQ` lines (two of them seen this run). Closed: the two cash systems, `CashClaimVFX` and the config specs, the robbery half of the remote audit, (the 26 leftover city prompts stay open: 2 went with the quarantined buildings, 4 remain in `Workspace.Map`, the other 20 are not located).

## Final review

Whole-batch review (Fable): **ready with fixes**, no Critical. Two Important findings: (1) the heist NPCs (Illegal Supplier, Bank Clerks, Cashiers) could be killed with city weapons, and each kill paid city XP and a kill toast; (2) `HeistServer`, `LocationServer`, `SuppliesServer` and `GamepassManager` connected `PlayerAdded` after yielding, with nothing for players already in the game. One fix wave, measured 2026-11-16 in one Play from the city spawn (commit `Batch: phase 3 final review fixes`):

| fix | change | check |
|---|---|---|
| Heist NPCs not killable for XP | CollectionService tag `Invulnerable` (read by `canDamageHumanoid` on the humanoid's parent Model) on `Workspace["Illegal Supplier"]["Illegal Supplier"]`, `HeistShared.ModelTemplates.BankClerk` and `RestaurantShared.ModelTemplates.Cashier` (also Gas2Go's cashiers, same template). `NPCSpawnManager` spawns by `Clone()`, which keeps the tag. Bank guards (`ServerStorage.GuardTemplate`) untagged. No code edit | `canDamageHumanoid(player, ...)`: false for the supplier, both spawned Bank clerks, a SlowFoods and a Gas2Go cashier; true for a `GuardTemplate` clone and a city `Enemy`. A real Spas 12 volley through `Blaster.Remotes.Shoot` (8 pellets claimed, 4 studs away): ammo 8 -> 7 (shot resolved), supplier health 100 -> 100, XP 0 -> 0, no `KillConfirmed`, no `Eliminated`. Control, same path, at a guard clone: health 100 -> 0, XP 0 -> 15, one `Eliminated` |
| Players already present | the four `PlayerAdded:Connect` calls now go through `ReplicatedStorage.Utility.safePlayerAdded`; handler bodies unchanged; the `PlayerRemoving` handlers need nothing (a player who left before the hook has nothing to clean) | read back from the exports; a full SlowFoods duffel (4,000 / 4,000, two registers) voided on death: `DuffelState` base 0, toast "You died before banking. Bag lost.", `leaderstats.Cash` 500 before, after and after respawn (786 studs out), profile cash 500 |
| Stale false over a confirmed true | `GamepassManager:PlayerOwnsGamepass` skips the write when the entry is already `true` after the yielding check | spec "a stale false arriving after a confirmed true does not overwrite it": 19 / 1 before the guard, 20 / 0 after |

Suites in the same Play: heist 616 passed, 1 failed (the `Zone` occupancy sweep timing, 10.19 ms); city 18 suites 193 / 193 / 0. Found in this run and left open: the NewsStation workers (`NewsStationShared.ModelTemplates.NewsWorker`) are still damageable (`canDamageHumanoid` true); not in the ruling. Rulings: [[CrimeLife Tycoon Decisions]] (2026-11-16).

## Links

[[Robbery Heists and Getaway]] · [[Robbery Puzzles]] · [[Robbery Prompts]] · [[Economy and Cash]] · [[City Map and Plots]] · [[Notifications]] · [[Gamepasses]] · [[Unit Test Runner]] · [[Luau and Scripting Traps]] · [[Camera and Input Traps]] · [[CrimeLife Tycoon Decisions]] · [[2026-11-15 FPS Hardening In City]] · [[Open Items]] · [[Batch Log]]

**Saved to `Crimelife city.rbxl` at checkpoints after Tasks 2 to 5; the controller saves once more after this task. NOT published.**
