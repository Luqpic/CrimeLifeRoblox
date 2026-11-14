# Task 3 Report — `EscapeDistance = 200` in all four configs

Studio instance: "Robbery System (placeId: 130328863401144)", `studio_id = 009e370d-dae2-402e-88e9-379b254ec753` (confirmed via `list_roblox_studios` before any write).

Status: **Complete.** All four configs edited, Step 3 verification passes (four lines reading `200`), Step 4 suite run and compared against the permitted failing set — no regression.

---

## Before / after of each of the four edit sites

### 1. `ReplicatedStorage.HeistShared.Config`

**Before** (lines 9–13, pre-edit):
```lua
Config.SessionDuration = 600 -- 10 minutes (spec addendum, 2026-09-09), up from 8
Config.CooldownDuration = 1800
Config.DuffelCap = 15000 -- up from 10000 (spec addendum, 2026-09-09)
Config.AccrualPerSecond = 133
Config.GuardCount = 4
```

**After** (lines 9–25):
```lua
Config.SessionDuration = 600 -- 10 minutes (spec addendum, 2026-09-09), up from 8
Config.CooldownDuration = 1800
Config.DuffelCap = 15000 -- up from 10000 (spec addendum, 2026-09-09)
-- Studs the player must get from this location's StatusBillboardAnchor,
-- measured horizontally and only once clear of the building, before a
-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
-- neighbouring locations 165-205 apart it reads as "about one block over"
-- without pushing the player through another location's grounds.
-- A starting value, not a tuned one -- expect to adjust after playtesting.
-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
-- from inside the vault if Getaway's inside-the-building gate were ever
-- removed. See Getaway's own header.
Config.EscapeDistance = 200
Config.AccrualPerSecond = 133
Config.GuardCount = 4
```

Placement rationale: this file has no blank lines separating `SessionDuration`/`CooldownDuration`/`DuffelCap`/`AccrualPerSecond`/`GuardCount`/etc — they're one unbroken run of top-level assignments before the `-- Gate behaviour` section header. Inserted `EscapeDistance` directly after `DuffelCap` (the third named "session tunable"), matching that no-blank-line style.

### 2. `ReplicatedStorage.RestaurantShared.Config`

**Before** (lines 26–31, pre-edit):
```lua
Config.CooldownDuration = 60
Config.DuffelCap = 4000
-- No time-based accrual mechanic exists at SlowFoods (lump-sum registers
-- only, via BankInstance:TryAddDuffel) -- defined as 0, not left nil, so a
-- stray GetAccrualRate/Accrue call is inert instead of erroring on nil*n.
Config.AccrualPerSecond = 0
```

**After** (lines 26–42):
```lua
Config.CooldownDuration = 60
Config.DuffelCap = 4000
-- Studs the player must get from this location's StatusBillboardAnchor,
-- measured horizontally and only once clear of the building, before a
-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
-- neighbouring locations 165-205 apart it reads as "about one block over"
-- without pushing the player through another location's grounds.
-- A starting value, not a tuned one -- expect to adjust after playtesting.
-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
-- from inside the vault if Getaway's inside-the-building gate were ever
-- removed. See Getaway's own header.
Config.EscapeDistance = 200
-- No time-based accrual mechanic exists at SlowFoods (lump-sum registers
-- only, via BankInstance:TryAddDuffel) -- defined as 0, not left nil, so a
-- stray GetAccrualRate/Accrue call is inert instead of erroring on nil*n.
Config.AccrualPerSecond = 0
```

Placement rationale: same "beside SessionDuration/DuffelCap/CooldownDuration" grouping — inserted directly after `DuffelCap`, before the pre-existing `AccrualPerSecond` comment block, with no blank line, matching this file's own no-blank-line-within-group style. **Did not touch** the `CooldownDuration = 60` line or its surrounding pre-existing DEBUG comment (known-failing baseline, expects 1200 — out of scope).

### 3. `ReplicatedStorage.Gas2GoShared.Config`

**Before** (lines 17–22, pre-edit):
```lua
Config.CooldownDuration = 60
Config.DuffelCap = 4000 -- matches SlowFoods' base
-- No time-based accrual mechanic exists at Gas2Go either (lump-sum
-- registers/ATM only, via BankInstance:TryAddDuffel) -- same reasoning as
-- RestaurantShared.Config.
Config.AccrualPerSecond = 0
```

**After** (lines 17–33):
```lua
Config.CooldownDuration = 60
Config.DuffelCap = 4000 -- matches SlowFoods' base
-- Studs the player must get from this location's StatusBillboardAnchor,
-- measured horizontally and only once clear of the building, before a
-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
-- neighbouring locations 165-205 apart it reads as "about one block over"
-- without pushing the player through another location's grounds.
-- A starting value, not a tuned one -- expect to adjust after playtesting.
-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
-- from inside the vault if Getaway's inside-the-building gate were ever
-- removed. See Getaway's own header.
Config.EscapeDistance = 200
-- No time-based accrual mechanic exists at Gas2Go either (lump-sum
-- registers/ATM only, via BankInstance:TryAddDuffel) -- same reasoning as
-- RestaurantShared.Config.
Config.AccrualPerSecond = 0
```

Placement rationale: identical pattern to RestaurantShared — inserted after `DuffelCap`, before the existing `AccrualPerSecond` comment. **Did not touch** `CooldownDuration = 60` (known-failing baseline, expects 600 — out of scope).

### 4. `ReplicatedStorage.NewsStationShared.Config`

**Before** (lines 17–22, pre-edit):
```lua
Config.CooldownDuration = 1200 -- 20 minutes, confirmed by the project owner
Config.DuffelCap = 10000 -- confirmed by the project owner
-- No time-based accrual mechanic exists at NewsStation either (lump-sum
-- registers/ATM only, via BankInstance:TryAddDuffel) -- same reasoning as
-- every other non-Bank location's own Config.
Config.AccrualPerSecond = 0
```

**After** (lines 17–33):
```lua
Config.CooldownDuration = 1200 -- 20 minutes, confirmed by the project owner
Config.DuffelCap = 10000 -- confirmed by the project owner
-- Studs the player must get from this location's StatusBillboardAnchor,
-- measured horizontally and only once clear of the building, before a
-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
-- neighbouring locations 165-205 apart it reads as "about one block over"
-- without pushing the player through another location's grounds.
-- A starting value, not a tuned one -- expect to adjust after playtesting.
-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
-- from inside the vault if Getaway's inside-the-building gate were ever
-- removed. See Getaway's own header.
Config.EscapeDistance = 200
-- No time-based accrual mechanic exists at NewsStation either (lump-sum
-- registers/ATM only, via BankInstance:TryAddDuffel) -- same reasoning as
-- every other non-Bank location's own Config.
Config.AccrualPerSecond = 0
```

Placement rationale: same pattern again — inserted after `DuffelCap`, before the existing `AccrualPerSecond` comment. This file's `CooldownDuration = 1200` is NOT one of the two known-failing baselines (Restaurant/Gas2Go); it was left untouched and NewsStationConfig shows 0 failures below, confirming no drift.

All four edits were applied via `multi_edit`, anchored on quoted code (never line numbers), per the operational constraint that `script_grep`/`script_read` line numbers disagree.

---

## Step 3 verification output (via `TestRunner.freshRequire`, to bypass Studio's stale `require` cache)

```lua
local RS = game:GetService("ReplicatedStorage")
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)
local out = {}
for _, n in ipairs({"HeistShared","RestaurantShared","Gas2GoShared","NewsStationShared"}) do
	local Config = TestRunner.freshRequire(RS[n].Config)
	table.insert(out, n .. ".EscapeDistance = " .. tostring(Config.EscapeDistance))
end
return table.concat(out, "\n")
```

Output:
```
HeistShared.EscapeDistance = 200
RestaurantShared.EscapeDistance = 200
Gas2GoShared.EscapeDistance = 200
NewsStationShared.EscapeDistance = 200
```

All four resolve to `200`. No `nil`s — all four edits landed.

---

## Step 4 — full suite output

```lua
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)
local RunAll = TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)
local ok, res = pcall(RunAll)
return "ok=" .. tostring(ok) .. "\n" .. tostring(res)
```

```
ok=true
TestRunner: 5 passed, 0 failed
Config: 5 passed, 0 failed
World: 50 passed, 1 failed
    FAIL each single-room zone has real floor immediately beneath its own bottom :: ClaimZone: no floor found within 6 studs of the zone's own bottom (probed from Y=9.00) -- a zone floating over the wrong room or the wrong height passes every tag/role check but has no floor under it — expected truthy, got nil
BankInstance: 34 passed, 0 failed
Duffel: 20 passed, 0 failed
Currency: 11 passed, 0 failed
Gate: 19 passed, 0 failed
Zone: 15 passed, 0 failed
Access: 20 passed, 0 failed
Laser: 22 passed, 0 failed
Hazard: 22 passed, 0 failed
Guard: 17 passed, 0 failed
Net: 8 passed, 0 failed
C4: 32 passed, 0 failed
Forfeit: 10 passed, 0 failed
AccessBarrier: 5 passed, 0 failed
GamepassManager: 13 passed, 0 failed
UITransitions: 7 passed, 0 failed
CounterBarrier: 7 passed, 0 failed
NPCReactionAnimator: 24 passed, 0 failed
RobbableObject: 30 passed, 0 failed
RestaurantConfig: 3 passed, 1 failed
    FAIL carries the spec's tunables :: CooldownDuration (20 minutes) — expected 1200, got 60
NPCSpawnManager: 8 passed, 0 failed
CashClaimVFX: 0 passed, 12 failed
    FAIL construction builds a persistent Cash display showing the initial value :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL PlaySequence animates the display up to the exact new value, no drift :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL the displayed value never exceeds the true new value mid-animation :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL burst count is fixed regardless of the claimed amount -- not scaled to the amount :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL burst icons are ImageLabels using the real cash decal, not procedural shapes :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL burst icons spawn at the configured burstOrigin, not screen center, when one is supplied :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL burstOrigin defaults to screen center when none is supplied (e.g. in tests) :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL cleans up every burst icon and the burst ScreenGui once the sequence completes :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL calling PlaySequence when the value hasn't changed is a no-op :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL a second claim animates from the previous displayed value, not from zero :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL the passive leaderstats listener updates the display when no claim animation is in progress :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
    FAIL a same-claim passive Value-change racing a PlaySequence call does not swallow the animation :: ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'
VaultDoor: 15 passed, 0 failed
HighlightSequencer: 13 passed, 0 failed
DisplayLights: 7 passed, 0 failed
Safe: 28 passed, 0 failed
SafeCode: 6 passed, 0 failed
DuffelBagAttachment: 16 passed, 0 failed
Gas2GoConfig: 3 passed, 1 failed
    FAIL carries the spec's tunables :: CooldownDuration (10 minutes) — expected 600, got 60
SupplyObject: 25 passed, 0 failed
CarryState: 11 passed, 0 failed
LockedDoor: 24 passed, 0 failed
NewsStationConfig: 5 passed, 0 failed
MasterComputer: 18 passed, 0 failed
NewsStationSafe: 5 passed, 0 failed
LocationServer: 17 passed, 0 failed
Getaway: 14 passed, 0 failed
TOTAL: 594 passed, 15 failed
```

---

## Comparison against expectations

**Brief's Step 4 expectation** ("still `593 passed, 16 failed`"): actual is `594 passed, 15 failed` — off by exactly one test, in the direction of one FEWER failure.

**Operational fact #7's permitted failing set** (the authoritative judgment criterion, since it explicitly supersedes totals as non-deterministic):

| Suite | Permitted | Actual | Match |
|---|---|---|---|
| World | x1 (ClaimZone floor) | 1 failed (ClaimZone floor) | ✅ |
| RestaurantConfig | x1 (CooldownDuration) | 1 failed (CooldownDuration) | ✅ |
| Gas2GoConfig | x1 (CooldownDuration) | 1 failed (CooldownDuration) | ✅ |
| CashClaimVFX | x12 (WaitForChild on nil) | 12 failed (WaitForChild on nil) | ✅ |
| SupplyObject | x0 or x1 (flaky) | 0 failed | ✅ (within permitted range) |
| Getaway | 0 failed | 0 failed | ✅ |
| LocationServer | 0 failed | 0 failed | ✅ |

Sum of the non-flaky permitted failures: 1 + 1 + 1 + 12 = 15, exactly matching the actual `TOTAL: 594 passed, 15 failed`. The one-test difference from the brief's `593/16` figure is fully explained by `SupplyObject`'s documented wall-clock flakiness (0 failed this run vs. the 1 baseline) — not by anything this task touched.

**No new failures in any `*ConfigSpec`.** `Config` (HeistShared): 5/5 passed. `RestaurantConfig`: only the pre-existing `CooldownDuration` failure. `Gas2GoConfig`: only the pre-existing `CooldownDuration` failure. `NewsStationConfig`: 5/5 passed. None of the four gained a new key-set assertion failure from adding `EscapeDistance` — no spec-expectation edits were needed or made.

**No suite outside the permitted set failed.** No regression introduced.

---

## Scope confirmation

Only the four named `Config` ModuleScripts were modified, each by adding exactly one field (`Config.EscapeDistance = 200`) plus its required reasoning comment, placed beside `SessionDuration`/`DuffelCap`/`CooldownDuration` per each file's own formatting. No existing config VALUE was changed. The two known-failing `CooldownDuration` baselines (Restaurant: expects 1200, has 60; Gas2Go: expects 600, has 60) were left untouched. No spec files needed editing since no `*ConfigSpec` gained a new failure.
