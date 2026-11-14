# Reconstruction report — `LocationServer` + `LocationServerSpec`

Status: **COMPLETE — gate met.** Both ModuleScripts rebuilt on disk first, verified there, then
pushed to Studio `009e370d-dae2-402e-88e9-379b254ec753` ("Robbery System", placeId 130328863401144)
and verified live.

On-disk artifacts (built before any Studio call, so a third infrastructure failure would have lost
nothing):

    .sdd-getaway/reconstructed/LocationServer.lua       18,450 B  458 lines
                                                        sha256 03980db560a167093b392980dda0e3709c6586517ddf07acb6b490624be789d2
    .sdd-getaway/reconstructed/LocationServerSpec.lua   20,539 B  535 lines  17 tests
                                                        sha256 5c362bc66a283f1d1934b8257d5abfde2cf8a99ed2d913553ac6abb49a2b54cc

Both were built by **mechanical, anchored string splices** on the snapshots (a Python script that
asserts each anchor matches exactly once), never by retyping. No hand-authored code anywhere.

---

## Step A — `LocationServer.lua`

Base: `snapshots/LocationServer.before.lua` (435 lines, the PRE-feature module).
Re-applied: the literal code blocks in `task-4-brief.md` Steps 3-7.

`diff` against the base is exactly 8 hunks, every one of them the brief's own text:

| # | Site | Change | Source |
|---|---|---|---|
| 1 | requires | `+ local Getaway = require(Heist.Services.Getaway)` after `Forfeit` | brief Step 4 last line |
| 2 | `REFUSAL_MESSAGES` | `cap_exceeded` → `"Duffel Full -- get clear of the building to bank it."` (`--`, **not** an em dash) | brief Step 6 |
| 3 | `new()` state table | `- claimRole = cfg.claimRole or "Claim",` | brief Step 5 |
| 4 | `new()`, before `return self` | + the 19-line `self.getaway = cfg.getaway` / `markerFolder` → `WaitForChild` → `StatusBillboardAnchor` → `Getaway.new{…}` block | brief Step 4, verbatim |
| 5 | after `_pushDuffel` | + `_bankBag` (3-line comment + 10-line body) | brief Step 3, verbatim |
| 6 | `ForgetPlayer` | `+ self.getaway:Forget(player)` immediately after `self.forfeit:Forget(player)` | brief Step 5 |
| 7 | `Tick()` | `+ self.getaway:Step()` immediately after `self:_updateZoneOccupancy()` | brief Step 5 |
| 8 | `Start()` | − the whole claim-zone `zoneService.Entered` handler and its `-- Cash-out on crossing into the claim zone -- automatic, no prompt.` comment (13 lines incl. separator) | brief Step 5 |

Step 7 of the brief (`markerFolder` in the three location scripts) was **not** re-applied — those
three scripts were never lost and already carry it. Verified by boot (see below). Out of scope.

Deliberately **not** applied: anything from `final-fix.md`. That wave reported BLOCKED with zero
changes, so the target state is post-Task-8, pre-final-fix. Concretely this means the rebuild
**keeps**, on purpose:

- the module header's `claim-zone cash-out` mention at line 7 (final-fix Item 4);
- `has_duffel = "You need to claim your duffel first before carrying supplies."` at line 75
  (final-fix Item 2);
- `--` rather than an em dash in `cap_exceeded` at line 73 (final-fix Item 3).

## Step B — `LocationServerSpec.lua`

Base: `snapshots/LocationServerSpec.fix1.before.lua` (511 lines, 17 tests, getaway rig already
present). Added exactly the two assertion sets from `task-4-report.md`.

Both "Before" blocks in that report were first verified to be **present verbatim** in the snapshot
(exact substring match, tab indentation intact), then replaced with the report's "After" blocks —
so the edited tests are the report's literal final text, not a re-derivation.

- Finding 1, `"getting clear banks the floored amount, toasts, then notifies success"`:
  `+2` lines — `expect.equal(lastToast[2], string.format("Banked %d %s.", 1234, Config.CurrencyName), "exact banked-toast wording")`.
- Finding 2, `"ForgetPlayer clears every piece of per-player skeleton state"`:
  `+22` lines — the `"p2"` latch scenario (`AddParticipant → TryAddDuffel(50) → RemoveParticipant →
  setPosition → Tick`), `latchSetAfterEscape`, `latchAfterForget`, and the 10-line design comment.

511 + 2 + 22 = 535. `suite:test(` count 17 before and 17 after. No test added, removed or weakened.

## Step C — cross-check against the recorded live positions

| Anchor | Recorded | Rebuild | |
|---|---|---|---|
| `cap_exceeded` | L73 | **L73** | match |
| `has_duffel` (final-fix "~line 75") | L75 | **L75** | match |
| Getaway construction | L218-240 | L218-**236** | starts right, **4 lines short** |
| `_bankBag` | ~L270-279 | L**266**-275 | 4 lines short |
| `getaway:Forget` | L347 | L**343** | 4 lines short |
| `getaway:Step()` in `Tick()` | L364 | L**358** | 6 lines short |

L73 and L75 landing exactly confirms the `+1` require / `−1` `claimRole` arithmetic through the
top of the file. The remaining offsets are **cumulative and fully accounted for**: a constant
`−4` from the Getaway construction onward, growing to `−6` only inside `Tick()`.

### Judgement call: 6 lines of comment prose are unrecoverable, and I did not invent them

Solving the offsets as simultaneous equations pins them precisely:

- `getaway:Forget` at L347 requires exactly **38** inserted lines between the `claimRole` deletion
  and `ForgetPlayer`. `_bankBag` is a known 14-line insertion (blank + 3-line comment + 10-line
  body, all from the brief), which forces the Getaway construction insertion to be **24** lines.
  The brief's literal block plus its blank separator is **20**. Missing: **4 lines**.
- `getaway:Step()` at L364 with `_updateZoneOccupancy()` at L361 leaves **2 lines** between them
  that the brief's one-line instruction does not produce.

Both gaps sit exactly where a rationale comment belongs, and the parallel Task 5 work on
`HeistServer` put a 5-line comment above its Getaway construction and a 5-line comment above its
`getaway:Step()` (quoted in `task-5-report.md` §3 and §4). `progress.md` even records the
`Tick()` rationale in prose — *"`zoneService:Update()` must precede `getaway:Step()`, or the
400-stud player would bank on tick 1"* — but **no input file records the original wording**.

I chose to ship the code-exact rebuild with those 6 comment lines absent rather than write
plausible replacements to make the line numbers line up. Fabricating prose to satisfy a checksum is
the failure mode the dispatch warned about, and a comment cannot be validated by the test gate.
Nothing executable is missing: all 8 code edits are the briefs' literal text, and the suite, the
mutation-proven latch assertion and a live four-location boot all pass.

**This is the one gap. If the original comment text exists anywhere (a Studio script-history entry,
an editor session, a copy of the review transcript), pasting those two blocks back in at L218 and
L362 restores byte parity; nothing else needs to change.**

Also unverifiable and immaterial: the live source's trailing newline. Both rebuilt files end with
one; the snapshots do too (and the `Write` tool strips trailing whitespace, so per-line trailing
spaces could never have survived a snapshot round-trip either way).

## Step D — push and verify

Pushed with `execute_luau` (`datamodel_type: Edit`), created via `Instance.new("ModuleScript")` +
`.Source` + parent, in two chunks each (`[==[ … ]==]`; the spec contains one `]]` at
`occupancy[byRole[role]]`, so level-2 brackets were required). Verified live against disk by three
independent measures:

| | len | byte sum | djb2 | lines |
|---|---|---|---|---|
| `LocationServer` disk | 18450 | 1619873 | 2684608934 | 458 |
| `LocationServer` live | 18450 | 1619873 | 2684608934 | 458 |
| `LocationServerSpec` disk | 20539 | 1750310 | 2221642923 | 535 |
| `LocationServerSpec` live | 20539 | 1750310 | 2221642923 | 535 |

Byte-exact on both.

### Sanity greps (live `.Source`)

    claimRole                0    <- required 0
    head back to claim it    0    <- required 0
    _bankBag                 2    (definition + onEscaped call site)
    getaway:Step()           1
    getaway:Forget           1
    markerFolder             4
    Getaway                  5
    Claim                    2    (bank:Claim + the spec name in _bankBag's comment)

Live line positions read back: L73 `cap_exceeded`, L218 `self.getaway = cfg.getaway`,
L266 `function LocationServer:_bankBag(player)`, L343 `self.getaway:Forget(player)`,
L358 `self.getaway:Step()`.

### Suite

`TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)`

```
World: 50 passed, 0 failed
LocationServer: 17 passed, 0 failed
Getaway: 14 passed, 0 failed
TOTAL: 594 passed, 14 failed
```

Failing set exactly `{ RestaurantConfig 1 (CooldownDuration), Gas2GoConfig 1 (CooldownDuration),
CashClaimVFX 12 (WaitForChild on nil) }` — the permitted set, unchanged.

**First run was a false negative and is worth recording.** It reported `TOTAL: 581 passed, 27
failed` with 13 extra failures in `Hazard` (1), `UITransitions` (3), `CounterBarrier` (4) and
`SupplyObject` (5). Measured `RenderStepped` at that moment: **1 fps** (Heartbeat 18) — the
documented collapsed-viewport trap, where TweenService does not advance and every tween assertion
fails. After the boot check forced the viewport to draw, `RenderStepped` measured **15 fps** and all
13 came back green with nothing else changed. 581 + 13 = 594 and 27 − 13 = 14, so the arithmetic
closes exactly on the flake. No test or assert was touched.

### Boot check — all four locations

`start_stop_play(true)` → `get_console_output` → `start_stop_play(false)`:

```
[NewsStationServer] NewsStation booted: ... Safe=3, zones=1
[HeistServer]       Bank booted: ... zones=5, alarmLights=0, templights=12
[Gas2GoServer]      Gas2Go booted: ... pulseLights=7, zones=1
[SlowFoodsServer]   SlowFoods booted: ... zones=1
```

No assertion, no `require` error, no `LocationServer` error of any kind. This also exercises the one
path no unit test covers: the real `markerFolder` → `workspace:WaitForChild` →
`StatusBillboardAnchor` → `Getaway.new` construction, at all three locations — it would have
asserted at boot otherwise. It confirms the three location scripts still pass `markerFolder`.

Remaining console noise is pre-existing and environmental: DataStore 403s (API access off in
Studio), `rbxassetid://90` sound 404s, and `GetConnectedParts` warnings from the weapon tool.

### No collateral

- `strayInteriorFixtures = 0`; zero parts above Y=5000 in Workspace — the spec's `rig.teardown()`
  cleaned up after itself across two full suite runs.
- Scope honoured: exactly two instances created. `HeistServer`, `HeistClient`, `Getaway`,
  `GetawaySpec`, `UITheme`, every Config, `WorldSpec`, the three location scripts and all of
  Workspace were read but never written.

---

## Things I noticed and did not change

1. **The 6 missing comment lines** (above). The only known divergence from the lost original.
2. **`final-fix.md`'s seven items are all still open.** The wave that was blocked by this data loss
   never ran. Items 2, 3, 4 and 6 target the two modules just restored, and the module is now back
   in exactly the state those items describe (`claim-zone cash-out` in the header, "claim your
   duffel" in `has_duffel`, `--` vs the Bank's em dash, `_bankBag`'s `amount <= 0` bail untested).
   That wave is now unblocked and can run as written.
3. **Cause of the deletion is still unknown** and nothing here addresses it. Both modules exist only
   in the open Studio session; the place file on disk predates all of this work. Saving the place
   would be the cheapest insurance, and I did not do it — it is a write outside my scope.
4. `workspace:GetDescendants()` reads 32,641 against the 32,636 recorded during Task 4's review.
   The delta predates this session (Task 7 untagged four zones between those two measurements) and
   is not from the suite: the fixture check above is clean both before and after a run.
