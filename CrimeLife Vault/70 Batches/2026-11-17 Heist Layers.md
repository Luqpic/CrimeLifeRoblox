---
type: batch
tags: [batch, city, heist, robbery, carry, layers]
updated: 2026-11-18
sources: [".superpowers/sdd/2026-11-17-heist-layers/progress.md", ".superpowers/sdd/2026-11-17-heist-layers/task-1-report.md to task-7-report.md", "docs/superpowers/specs/2026-11-17-heist-layers-design.md", "docs/superpowers/plans/2026-11-17-heist-layers.md", "CityMerge/after-import.md (section Heist layers 2026-11-17)"]
---

# 2026-11-17 Heist Layers

Seven tasks, commits `0de8260..8698e1a` plus this note (state as of 2026-11-18; a whole-branch final review and a fix wave run after it and will amend this note). One optional signature layer inside each of the four robberies, so they stop feeling "samey". Casino and Warehouse wait.

## Asked for
The developer: robberies "feel samey". Approach A (one signature layer per location, built mostly from existing pieces) and the four layers were approved; the developer told the controller to proceed to the end while away, so the spec's open points are controller rulings ([[CrimeLife Tycoon Decisions]]). Anti-goals: the base robbery plays exactly as today when a layer is ignored, no payout that skips the getaway, no client-trusted payout.

## What changed
**Task 1, shared pieces** (`53a6fee`)
- `BankInstance:AddBonus(player, amount)`: bag loot over the cap (reasons `inactive`, `not_participant`, `invalid_amount`).
- Heavy-loot carry: `CarryState` sets the character attribute `CarrySpeedCap` (12, `Movement.Constants`) when the carried `SupplyObject` has a `speedCap`; `Animate2`, `SprintAuthority` and `Crouching` cap WalkSpeed at it and grant no sprint. `SupplyObject` gained `bankOnly`, `speedCap`, `startHidden`, `GiveTo`, `Close`; `SupplierSale` refuses `bankOnly` carries ("bank_only"); new `Heist.Services.CarryGetaway` banks a heavy carry at 200 studs outside the building, with or without an active session.
- Measured (client, W + LeftShift, 3 s): no cap sprint 38; with the cap max 12, `IsSprinting` never true; cleared, WalkSpeed 20 within 0.2 s and sprint 38 again.

**Task 2, component hooks** (`92d9e43`)
- `LockedDoor`: `onSolved`, `objectText`, `Open(player)`, and one live lockpick attempt per player across all doors. `RobbableObject`: `blockedReason`, `onRobbed`, `Close`. `MasterComputer`: `onBreached`. `GuardPost:Alert()`. `Net` remote `BroadcastHijacked` plus a `NotificationClient` card. `HeistClient` shows an over-cap bag ("17,500 / 15,000", bar full).

**Task 3, SlowFoods manager chase** (`d522c0c`)
- A fleeing Manager (Cashier clone, WalkSpeed 8) runs for `ManagerEscapePoint` at the front of the restaurant; "Take Key" (hold 1, 10 studs) gives the key (player attribute `SlowFoodsKey`); the key opens the storage-room `LockedDoor` at once ("Use Key", F) and the new `StorageSafe` (3000 through `AddBonus`, `payWith = "bonus"`). New `Heist.Components.FleeingManager`.
- Measured: Manager run 14.66 s at WalkSpeed 8 (115.3 studs, one final sample; 20.17 s at first, before a topple fix); the room's only way in is the `LockedDoor` (flood fill, 342 cells). Solo layer done with about 20 s of the 120 left; Play showed 7,500 Cash after banking (+7,000).

**Task 4, Gas2Go ATM rip-out** (`ce9d788`)
- New `Heist.Components.ATMRipOut`: the ATM keeps "Rob ATM" and gains "Rip Out ATM" (hold 10, F, server-timed); either closes the other. The rip is a 9000 heavy carry (`ATMCarryTool`, scaled 0.5), banked by `CarryGetaway`; the supplier refuses it. `SupplyObject` gained an opt-in server-timed hold (`enforceHold`) and refuses a trigger with no armed prompt; `EquipService` ignores equip and unequip while carrying (a hotbar swap fired a Deagle during a carry).
- Measured: Triggered at 9.995, 10.01 and 10.03 s; carry max WalkSpeed 12.00, `IsSprinting` false; banked +9000 once at 203 studs.

**Task 5, NewsStation broadcast takeover** (`b1c571e`)
- New `Heist.Components.BroadcastDesk` (lobby corner, about 16 studs from `MasterComputer`): the first hack arms it; "Go Live" (hold 1) starts 45 s of air time counted only while a participant is within 12 studs (pauses, never resets); city card, heat floor of 3 stars, every guard alerted; completion pays each participant in range 6000 through `AddBonus`.
- Measured: `WantedStars` 2 to 3 at go-live; pause label `LIVE 0:24` at +0.5 s and +10.5 s away, `0:19` after 5 s back; `AIRED` and a 6000 bag; banked +6000 once at 205 studs.

**Task 6, Bank deposit boxes and gold bar** (`f31fb99`, fixes `8698e1a`)
- `DepositBoxLoot.roll` (gold chance 0.5, others cash 2 in 3), new `Heist.Components.DepositBoxes` (8 `LockedDoor`s unlocked by the vault-door latch; cash 1500 through `AddBonus`; one gold bar of 8000 as a heavy carry; hands-full drops it at the box). `SupplyObject` startHidden bug fixed (the bar stood visible at Idle).
- The gold carrier's route out (obby jumps at speed 12) was the must-fix: the first answer moved obby pads for everyone, the review rejected it, and the final one leaves the base obby exactly as before and adds two carrier-only ledges (`CarrierLedge`, `CarrierLedge2`): invisible and non-colliding except for characters with `CarrySpeedCap` (collision groups `Carrier` and `CarrierLedge`, set by `CarryState`; a `CarrierLedgeView` LocalScript shows them to carriers only).
- Measured (fix round, scripted capped trials, 10 per jump): J1 9/10, J2 to J7 10/10 each; uncapped, every jump lands on the original pads and a character placed on a ledge falls to y -121.9. Full real carrier route (before the fix round): 500 to 10,140 at 202.4 studs = duffel 1,640 + gold 8,000, each once.

**Task 7, this note and the closing runs**: the vault updates and the Plays below.

## Decisions
The rulings are in [[CrimeLife Tycoon Decisions]] (section "2026-11-17: heist signature layers"). In short: layer cash rides over the cap; heavy loot outlives the timer and the supplier refuses it; the Manager flees out the front door; Manager name through `Humanoid.DisplayName`; ATM carry guard in `EquipService` kept; the ATM rip refuses while the bag holds Gas2Go loot; broadcast desk in the lobby corner; carrier route fixed with carrier-only ledges, not by changing the obby; and the developer's standing instruction (2026-11-18) to reuse assets already in the game.

**Assets reused versus built from parts** (from the reports; the developer's instruction came in during Task 6, earlier tasks were already clone-first):

| Layer object | Reuse or parts |
|---|---|
| Manager | Reused: clone of the Cashier template; name through `Humanoid.DisplayName` |
| SlowFoods `StorageSafe` | Reused: clone of a Bank safe model |
| `ATMCarryTool` | Reused: copies of the ATM's own 48 parts and 2 text models, scaled 0.5 |
| Prompt templates (`RipOutATMPrompt`, `PickUpATMPrompt`, `PickUpGoldBarPrompt`) and gold bar sounds | Reused: clones of existing prompts and of a Gas2Go barrel's sounds |
| `BroadcastDesk` | Reused: `Desk` clone of the 13-part newsroom desk, `Computer` clone of `ClipNews Building.Computer`; the Highlight and `LiveBillboard` are authored |
| Gold bar (`BankVault.GoldBar`, `GoldBarTool`) | Reused: the `GoldB` mesh quarantined from HQ (the earlier parts-built bar was swapped out) |
| `CarrierLedge`, `CarrierLedge2` | Reused: clones of the obby's own 4 x 4 pad model |
| Deposit-box cabinet and 8 boxes | Built from parts: no box, drawer or small locker exists (the HQ and Gas2Go lockers are 8 to 9 studs tall) |

## Verified
Place `Crimelife city.rbxl`, resolved by name. Nothing was saved or published.

**Suites** (one Play): city `[SUMMARY] 262 run, 262 passed, 0 failed, 10.116s`; heist `TOTAL: 707 passed, 0 failed` (the `Zone` sweep passed this time; earlier runs 706 / 1, failure only that case, 8.93 ms). New heist cases by task: 21, 9, 15, 11, 10, 16 and 4 in the fix round (86 on the 621 baseline).

**Three closing Plays** (each fresh from Stop, player under an invisible `ForceField`, real prompts held through client `InputHoldBegin` with the camera aimed; shortcuts: `PivotTo` for movement and the Crowbar equipped to start the robbery). Non-asset warnings and errors read from `LogService` history, server and client (an asset line contains `Failed to load`, `ContentId` or `asset`):
1. **Gas2Go, ATM robbed by hand, rip ignored** (not run by hand before): `RobATMPrompt` held 8.6 s; ATM stays standing (48 parts visible), no carry; Cash 500 at 100 and 190 studs, 3,500 at 205 (+3000 once). Server 0, client 0.
2. **SlowFoods, Manager ignored** (Take Key not pressed): Manager gone from `Workspace.SlowFoods` by the time one register hold ended (escape, not timed); the safe hold without a key left `Robbed` false and `SlowFoodsKey` nil (the toast text was not captured by my probe); Cash 500 at 100 studs, 2,500 at 220 (+2000 once). Server 0, client 0.
3. **Bank, robbery started, layer ignored**: all 8 deposit-box prompts disabled before the vault opens; `GoldBar.Bar.Transparency` 1; both ledges read transparency 1 on a non-carrying client. Server 0 (client not read).

After: Edit shows 1 enabled `SpawnLocation`, no `Tmp` script or Workspace instance, no Workspace attribute, no stray test attribute. The Edit scan matched only pre-existing `Temp_Remove` and `TempLight` names (TycoonPreview, HQ copies, Bank lights and their quarantine) and plugin GUI `Template` objects.

**Place file.** `stat` reads `Nov 17 16:56:20 2026` for `Roblox Games/Crimelife city.rbxl`; the batch's first commit (`0de8260`) is Nov 17 19:24 and the last (`8698e1a`) Nov 18 01:51. So the file on disk predates every commit of this batch: it holds none of it.

## Not verified
- The full Bank gold route was last walked for real before the fix round; after it, only scripted capped trials (not human input). The z 2472 jump went 10/10 there, but the inbound jump at base speed, and the whole route as one real carry, were not re-walked in a closing Play.
- Two players: a crew racing a key, a rip, a box, a desk. Specs cover the box race and the box seal only.
- Never seen by eye: prompts and the OFF AIR billboard did not render in captures taken with a scripted camera (read from events and properties).
- A person in the game: no layer was played by hand; a leaver mid-broadcast; the broadcast `Alert()` effect (guards were already active in the run).
- The Zone sweep passed in this run; the heist suite ran in a Play that also logged about 90 `VaultDoor` line 38 "no PrimaryPart" errors from its own specs. They did not appear in the three fresh Plays; I did not compare against a pre-batch run.
- The toast text for a keyless safe (Play 2).

## Left open
In [[Open Items]], section "Heist layers leftovers (2026-11-17)": no getaway widget for heavy loot, the ATM that vanished once, the obby carrier ledges' queries and collision-group order, a hands-full gold bar despawning, the parked minors of tasks 1 to 6, and the save.

## Links
[[Robbery Heists and Getaway]] [[Robbery Puzzles]] [[Movement and Stamina]] [[Police and Wanted]] [[Notifications]] [[Open Items]] [[CrimeLife Tycoon Decisions]] [[2026-11-17 Police and Wanted]]

NOT saved / NOT published
