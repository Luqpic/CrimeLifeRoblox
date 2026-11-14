# Task 2 report — the `Getaway` service (TDD)

Studio target: "Robbery System (placeId: 130328863401144)", `studio_id = 009e370d-dae2-402e-88e9-379b254ec753`.

## 1. Instances created / modified — confirmed

| Path | ClassName | Action |
|---|---|---|
| `ServerScriptService.Heist.Services.Getaway` | `ModuleScript` | CREATE |
| `ServerScriptService.Heist.Tests.GetawaySpec` | `ModuleScript` | CREATE |
| `ServerScriptService.Heist.Tests.RunAll` | `ModuleScript` | MODIFY (append to `SPECS`) |

Confirmed live via `execute_luau`:

```
Getaway: exists=true className=ModuleScript path=ServerScriptService.Heist.Services.Getaway
GetawaySpec: exists=true className=ModuleScript path=ServerScriptService.Heist.Tests.GetawaySpec
```

## 2. The `RunAll` edit

One line inserted, immediately after `"LocationServerSpec",`, nothing else in the file touched:

```lua
	"LocationServerSpec",
	"GetawaySpec",
}
```

Full current `SPECS` list tail (lines 40-45 of the live module):

```lua
	"NewsStationConfigSpec",
	"MasterComputerSpec",
	"NewsStationSafeSpec",
	"LocationServerSpec",
	"GetawaySpec",
}
```

## 3. Step 1 — spec written

`GetawaySpec` was transcribed verbatim from the brief (14 `suite:test` cases under `TestRunner.new("Getaway")`). No deviations.

## 4. Step 2 — confirm it fails for the right reason

Ran via `execute_luau` (`datamodel_type = "Edit"`):

```lua
local RunAll = require(game.ServerScriptService.Heist.Tests.RunAll)
local ok, res = pcall(RunAll)
return "ok=" .. tostring(ok) .. "\n" .. tostring(res)
```

**First attempt used a plain `require()` on `RunAll` right after editing it** — Studio's session-cached
`require` returned the pre-edit module, so `GetawaySpec` didn't even appear in the report (this is the
exact stale-require trap called out in the operational facts). Re-ran with
`TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)` instead, which picked up the edit.

Full output of the corrected run (only the new/relevant tail shown; the rest of the 36 pre-existing
suites matched the baseline exactly):

```
...
LocationServer: 17 passed, 0 failed
GetawaySpec: 0 passed, 1 failed
    FAIL suite errored :: Getaway is not a valid member of Folder "ServerScriptService.Heist.Services"
TOTAL: 580 passed, 16 failed
```

**Deviation from the brief's predicted shape, noted per instructions:** the brief expected
`Getaway: 0 passed, 14 failed` (one failure per test, all citing the missing module). What actually
happened is `GetawaySpec: 0 passed, 1 failed` — a single combined "suite errored" failure. Root cause:
`local Getaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Getaway)` is the very
first line of the spec function; Luau's dot-indexing (`.Getaway` on a Folder that doesn't have that
child) raises an error immediately at that line, before `TestRunner.new("Getaway")` or any `suite:test`
call is ever reached — so no suite object exists yet, and `RunAll`'s own per-spec `pcall` reports it
under the SPECS-list name (`GetawaySpec`) rather than the suite's declared name (`Getaway`), as a single
error rather than 14 individual test failures. The *reason* is exactly what was expected — the module
not existing — just reported as one error instead of fourteen, since the given spec code (transcribed
verbatim, unmodified) never wraps that `require` in a way that would let 14 independent tests each hit
it separately. This is a shape difference in the test harness's failure reporting, not a different root
cause, so implementation proceeded per Step 3.

## 5. Step 3 — implementation, plus one genuine bug found and fixed

`Getaway` was transcribed verbatim from the brief first. Running the suite against that verbatim version
produced **13 passed, 1 failed**:

```
Getaway: 13 passed, 1 failed
    FAIL re-arms for a second bag after the first is banked :: both bags banked — expected 2, got 1
```

**Root cause (genuine bug in the brief's given implementation, not a taste difference):** in the given
`Step()`, the fired-latch is only cleared in the `if self.getDuffel(player) <= 0 then self._fired[player]
= nil end` branch — i.e. only when a *future* call to `Step()` happens to observe `duffel <= 0` at that
moment. In the failing test, `onEscaped` zeroes the duffel synchronously during the first `Step()` call
(good), but the test then sets `state.duffels.p1 = 500` (simulating "robbed again") *before* a second
`Step()` ever runs. Because no `Step()` call ever witnesses `duffel == 0` in between, the re-arm branch
never fires, `_fired[player]` stays `true` forever, and the player is permanently locked out of banking
a second bag — a real production bug (any off-tick bag refill between two heartbeats would trigger it),
not just a test artifact.

**Fix applied** (inside the existing `elseif` fire branch, immediately after `self.onEscaped(player)`):

```lua
					self.onEscaped(player)
					-- If onEscaped cleared the bag (the common case: bank:Claim
					-- zeroes it), re-arm immediately rather than waiting for a
					-- future Step to observe duffel==0 -- if the bag is refilled
					-- before that Step runs, that branch is never reached and the
					-- latch would stay stuck true, permanently blocking a second
					-- payout. onEscaped implementations that deliberately leave
					-- the bag alone (bank:Claim returning 0 post-session) still
					-- latch correctly, since getDuffel stays > 0 here.
					if self.getDuffel(player) <= 0 then
						self._fired[player] = nil
					end
```

This re-arms the latch the instant we know the bag is empty, instead of deferring to whichever future
`Step()` happens to catch it at zero. Verified this does not break the sibling test "does not re-fire
every tick when onEscaped leaves the bag alone" (that test's `onEscaped` never touches the duffel, so
`getDuffel(player)` stays `1000` after firing, the new check is false, and the latch correctly stays
set) — confirmed by the full green run below.

The `_state ~= ACTIVE` / `IsParticipant` anti-dupe guards mentioned in the global constraints belong to
`BankInstance:Claim`, which this module does not touch — not applicable to this fix.

No other bugs found. The rest of the given implementation (`horizontalDistance`, `Getaway.new`'s
assertions and `anchor`-vs-`getAnchorPosition` resolution, `DistanceRemaining`, `Forget`) was transcribed
verbatim and needed no changes.

## 6. Step 4 — full green run

Ran (via `TestRunner.freshRequire` on `RunAll`, again to avoid the stale-require trap after editing
`Getaway`):

```
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

## 7. Totals vs. baseline — explicit comparison

Original brief baseline table (pre-task, measured immediately before the plan was written):
`TOTAL: 579 passed, 16 failed` — World×1, RestaurantConfig×1, Gas2GoConfig×1, CashClaimVFX×12,
SupplyObject×1 (flaky, sometimes 0).

Per the brief's own CORRECTION section, the integer totals are not a reliable tripwire (the suite was
measured at both 579/16 and 580/15 with no relevant change, `SupplyObject`'s wall-clock test being
non-deterministic under Studio's viewport-collapsed `RenderStepped` behavior). Judgment is by the **set
of failing suite names**, not the total.

- **Pre-Getaway run (Step 2), this session:** `TOTAL: 580 passed, 16 failed`. Failing names: World×1,
  RestaurantConfig×1, Gas2GoConfig×1, CashClaimVFX×12, GetawaySpec×1 (expected — module didn't exist
  yet). `580 = 579 baseline + 1` because `SupplyObject` happened to pass this run (the documented flake).
- **Post-Getaway run (Step 4), this session:** `TOTAL: 594 passed, 15 failed`. Failing names: World×1,
  RestaurantConfig×1, Gas2GoConfig×1, CashClaimVFX×12. `SupplyObject` passed again this run (0 of its
  permitted 0-or-1). `Getaway` is clean: 14 passed, 0 failed.
- **Comparison to the 579/16 baseline:** `594 - 579 = 15` new passes = the 14 new `Getaway` tests + 1
  (the `SupplyObject` flake resolving to pass instead of fail this run). Failed count dropped from 16 to
  15 for the same reason (`SupplyObject`'s flake, not a fix). The failing-suite **names** are exactly the
  permitted set from the CORRECTION section: `World×1, RestaurantConfig×1, Gas2GoConfig×1,
  CashClaimVFX×12, SupplyObject×0` — no suite outside that set failed, and no name in that set is
  missing. This is the intended Task 2 target set.

## 8. Findings / out-of-scope items (reported, not fixed)

- **`CashClaimVFX` cluster (12 failures)** — already diagnosed per the brief as a test-harness artifact
  of `TestRunner.freshRequire` destroying the clone before `_buildPersistentGui`'s lazy
  `require(script.Parent:WaitForChild("UITheme"))` runs. Confirmed still present, unchanged, out of
  scope per the brief. Not touched.
- **`WorldSpec` ClaimZone failure** — confirmed still present, unchanged. Per the brief this is expected
  to disappear in Task 7 when that part is deleted; not touched here.
- **`RestaurantConfigSpec` / `Gas2GoConfigSpec` CooldownDuration failures** — confirmed still present,
  unchanged, out of scope for this task.
- **`SupplyObjectSpec` flaky timing test** — observed 0 failures in both runs this session (never hit
  the flake), consistent with the brief's "either result is fine."
- **Genuine bug fixed in the given `Getaway:Step()` implementation** — see Section 5. The fired-latch
  re-arm was one tick late, which the brief's own "re-arms for a second bag" test caught. Fixed inline,
  scoped to the `Getaway` module only; no other files touched to make this fix.
- **Scope fence respected:** only the two ModuleScripts listed were created, and only the one line was
  appended to `RunAll`'s `SPECS` list. `LocationServer`, `HeistServer`, `HeistClient`, Config modules,
  and ClaimZone parts were not touched.
