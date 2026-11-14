# SDD ledger — plan: /Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/Getaway-Distance-Claim-And-GUI.PLAN.md

Spec: /Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/Getaway-Distance-Claim-And-GUI.md (read, is the binding authority)
Studio: "Robbery System" placeId 130328863401144, studio_id 009e370d-dae2-402e-88e9-379b254ec753

## Environment rulings (made before Task 1)

**Ruling: the skill's git machinery is replaced, not skipped.** — `scripts/sdd-workspace`,
`scripts/task-brief` and `scripts/review-package` all abort with "not a git repository"; the game
code is live Roblox Studio state, not files under version control. Substitutions: briefs and
reports are hand-written into this workspace; the per-task review package is the task's brief +
report + a `script_read` of every script the task touched + the spec-suite output, instead of a
`git diff`; the per-task checkpoint is a green spec suite instead of a commit. — **Cost if wrong:**
reviewers see current file state rather than a true diff, so a reviewer could miss that an
implementer also changed something outside its task. Mitigated by naming the exact scripts each
task may touch in its brief and having the reviewer read all of them.

**Ruling: no worktree isolation is possible; the live place is the workspace.** — Studio has no
branch to fork. The rollback point is the place file on disk. — **Cost if wrong:** a bad edit is
recovered by the user reverting to their last save, losing any unsaved Studio work. I will require
a confirmed save before Task 4, the first task that mutates game-behaviour code. Tasks 1-3 are
additive (new keys, a new module, new config fields) and carry no meaningful revert risk.

**Ruling: Task 1's open question is resolved — the third UITheme table is `UITheme.BodyOffset`.** —
Read live: flat panels take `Vector2.zero` (`TimerNormal`, `TimerUrgent`, `DuffelPanel`, `Toast`,
`DropSupplies` all do); only ribbon-overhang panels take `RIBBON_OFFSET = Vector2.new(9, 19)`. The
getaway widget is a flat panel, so both new keys take `Vector2.zero`. — **Cost if wrong:** the
widget's live children would be offset by 9,19 px inside the slice. Visible immediately in Task 6's
screenshot.

## Pre-flight conflict scan

### Cross-task rows (tasks sharing a file or an interface)

| Tasks | Produces → consumes | Finding |
|---|---|---|
| T1 → T6 | `UITheme.Assets.GetawayNormal` / `.GetawayNear`, `UITheme.Size.GetawayNormal` | Clean. Names match exactly. T6 reaches them via `imagePanel(name, "GetawayNormal", pos)`, which indexes `UITheme.Size[key]` and `UITheme.Assets[key]` — so the key spelling is load-bearing in both tables. |
| T2 → T4 | `Getaway.new` / `:Step` / `:Forget` | Clean. T4 injects via `cfg.getaway` in specs and constructs directly in `new()`. |
| T2 → T5 | `Getaway.new` / `:Step` | Clean. Bank passes `anchor` + `isInsideBuilding` union. Note T5 never calls `:Forget` — the Bank has no `ForgetPlayer` equivalent. Not a defect; the latch self-clears when the duffel hits 0. |
| T3 → T4, T5, T6 | `Config.EscapeDistance` | Clean. T4 reads `cfg.config.EscapeDistance`, T5 reads `Config.EscapeDistance`, T6 reads each location's own config module from ReplicatedStorage. |
| T2 vs T3 | GetawaySpec hardcodes `escapeDistance = 200` | Not a conflict. It is a unit test with an injected value; reading the config there would couple the unit test to a tunable. |
| T4 → T7 | T4 removes `claimRole` + handler; T7 removes the parts + boot asserts | Clean, and order-dependent. T7 must not run before T4/T5, or the boot assert drops `Claim` while handlers still bind that role. Plan order (4,5,7) is correct. |
| T5 ↔ T7 | Both modify `HeistServer` | Clean. Different regions (claim handler + refusal message vs. boot asserts), executed sequentially. |
| T2 ↔ T7 | T2 edits `RunAll`; T7 edits `WorldSpec` | Clean. Different files. |

### Per-task internal consistency

| Task | Its tests vs its code, its creates vs its later touches | Finding |
|---|---|---|
| T1 | Figma frames → UITheme keys → Step 7 verification reads those keys back | Clean once BodyOffset is resolved (see ruling above). |
| T2 | 14 spec tests vs the module | Clean. Checked each assertion against the implementation. Both negative tests fire the intended assert: `{escapeDistance=200}` alone trips the `isInsideBuilding` assert; `escapeDistance = 0` with all callbacks trips the positive-distance assert first. |
| T3 | 4 config edits | Clean. Step 4 correctly anticipates that a `*ConfigSpec` asserting an exact key set may need `EscapeDistance` added. |
| T4 | Rewritten rig vs `_bankBag` + `cfg.getaway` | Clean. Forward-declared `location` is safe because the callbacks only run after `new()` returns. Step 1 note 1 correctly flags that `setOccupants("Claim", ...)` silently no-ops once the fixture zone is gone. |
| T5 | Bank wiring | Clean. `bankBag` closes over `bank`/`currency`/`net`/`Config`, all defined earlier in the file. |
| T6 | Widget + render loop | **Gap:** Step 5's snippet writes `getawayRemaining[location]` and Step 6 reads it after the loop, but no step declares `local getawayRemaining = {}` (nor `getawayShown`, `locationAnchors`, `escapeDistances`, `getawayWidgets`). Carried into the brief as an explicit instruction rather than left to inference. |
| T7 | Asserts + WorldSpec + deletion | Clean. Step 6's expected count change (16→15 failures) is the stated tripwire. |
| T8 | Verification only | Clean. |

### Plan text the review rubric may flag as a defect

**Ruling: the `_bankBag` / `bankBag` duplication between T4 and T5 stands.** — A reviewer is likely
to flag the payout body existing in both `LocationServer:_bankBag` and `HeistServer`'s local
`bankBag` as verbatim duplication. The spec mandates it, and `LocationServer`'s own header gives
four still-valid reasons the Bank is deliberately not a consumer of that module (different
participant model, no auto-enrolment, live accrual rate, a zoneService.Exited handler). Unifying
them would mean giving `LocationServer` a mode switch for the Bank — the larger blast radius the
header already rejected. — **Cost if wrong:** ~8 lines stay duplicated across two files; a future
change to the payout must be made twice. Cheap to unify later if the Bank is ever migrated.
I will let the reviewer raise it and adjudicate against this ruling rather than pre-judging it.

---

## Task log

Task 1: dispatched (opus, general-purpose) — Figma design + export + upload + UITheme pinning.
  Brief: task-1-brief.md · Report: task-1-report.md
  Scope fence: UITheme only, additive (6 entries across Assets/Size/BodyOffset).
Task 2: brief prepared while Task 1 runs (no file overlap — T1 owns UITheme, T2 owns Getaway/GetawaySpec/RunAll).
Task 3: brief prepared.

## Late-arriving context: /Users/luqpic/Documents/Roblox/CLAUDE.md

Loaded after Task 1 was dispatched. Nothing in it invalidates work so far:

- "A second place, **Robbery System** ... never edit it unless it is named explicitly." The user's
  opening message names Robbery System explicitly, so this work is authorised. The attached
  studio_id used throughout is the Robbery System place, not the FPS default.
- "Verify the result, not the arithmetic ... read the resulting property back — especially
  `AbsolutePosition`, `AbsoluteSize`." → **must be folded into Task 6's brief**: the widget's
  layout is not proven by a successful edit, only by reading the absolutes back.
- Known traps that bear directly on Task 6 and Task 8, to carry into those briefs verbatim:
  - **TweenService is render-driven.** With the Studio viewport collapsed, `RenderStepped` reports
    0 FPS and tweens do not advance. The getaway bar's fill tween and the studs countdown both ride
    `RenderStepped` — an implementer testing with a collapsed viewport will see a frozen widget and
    mis-diagnose it as broken code. Flag this in Task 6 AND Task 8.
  - **`AnchorPoint` and `Position` must agree.** `AnchorPoint (0, 0.5)` with `Position.Y = 0` puts a
    bar's centre on its track's top edge — exactly the fill-bar shape Task 6 builds.
  - **`AbsolutePosition` is measured below the top-bar inset while an overlay that ignores the inset
    is not.** `HeistHUD` sets `IgnoreGuiInset = true`, so any absolute check on the new widget must
    account for ~36px.
  - `UIPadding` offsets children rather than insetting the frame; `ZIndexBehavior` is a ScreenGui
    global, not per-element.
- "Prefer the shared module over a local rebuild" — consistent with the plan's use of the existing
  `imagePanel`, `setFillRatio`, `commas` and `UITransitions` helpers rather than new ones.

### Task 1 verification (controller, live) and rulings

Verified independently, not taken from the report:
- `UITheme` via `freshRequire`: `GetawayNormal`=`rbxassetid://140089160384517`,
  `GetawayNear`=`rbxassetid://132824223302657`, both `Size` `240,76`, both `BodyOffset` `0,0`.
  `TimerNormal` untouched. Scope fence held.
- Figma node `128:6` real geometry: frame 240×76; `AccentEdge` x14 y14 6×48; `STUDS` x184 y24 40×18;
  `GET AWAY` x34 y44 190×18; `Track` x34 y64 190×6.
- Exported PNG corner alpha = 0 on all four corners, centre = (23,26,34) = `#171A22`. The
  opaque-background trap that silently broke a previous slice batch is NOT present.
- Account confirmed `muhammadluqmanhayyan@gamuda.tech`, Full seat.

**Ruling: the suite tripwire is the SET of failing spec names, never the integer count.** — The
count moved 579/16 → 580/15 with no relevant change. The flip is `SupplyObject`'s "the countdown
ticks down over real time and auto-hides/re-anchors when it reaches 0" — a wall-clock timing test,
which `/Users/luqpic/Documents/Roblox/CLAUDE.md` predicts is render-state dependent ("TweenService
is render-driven... with the viewport collapsed, RenderStepped reports 0 FPS"). The subagent's own
diagnosis (that the baseline had 2 `World` failures) is wrong: that would have made the baseline 17,
not 16. `World` was 50/1 at baseline and is 50/1 now. — **Cost if wrong:** a real regression in
`SupplyObject` gets mistaken for flake. Mitigated by tracking names: the permitted failing set is
{World×1 (ClaimZone floor), RestaurantConfig×1, Gas2GoConfig×1, CashClaimVFX×12, SupplyObject×0-1
(flaky)}. Anything outside that set is a regression regardless of the total.

**Ruling: the frames live on page `03 · Export Slices`, not `02 · Redesign` as the spec said.** —
Verified the 23 existing export slices are on `03` and the upload pipeline consumes that page; `02`
holds composed mockups. My spec sentence came from a memory describing where mockups live. The
subagent matched the pipeline, which is right. — **Cost if wrong:** a future session looking for the
slices on `02` does not find them. Mitigated by recording it here and in the changelog.

**Ruling: the near state recolours BOTH the accent edge and the `GET AWAY` caption to gold.** —
Verified visually; the state change reads clearly at 1x. The Timer family carries state colour on
the edge and the Duffel family on the caption, so borrowing the timer's edge alone would have been
a weak signal. — **Cost if wrong:** purely cosmetic, one re-export.

**Ruling: exporting via Figma MCP `download_assets` instead of REST `/v1/images` is accepted.** —
The sandbox blocked the credential lookup the REST route needs. Same artifact (4x node render), and
the corner-alpha check above proves the trap the REST route is warned about is absent. — **Cost if
wrong:** none identified; the uploaded assets resolve and render is proven in Task 6.

**Ruling: Task 1's review was performed inline by me, not by a dispatched reviewer.** — There is no
diff to hand a reviewer, and every check that mattered (live UITheme state, real node geometry,
decoded pixel alpha) is a live query I ran directly and more precisely than a reviewer reading
prose could. — **Cost if wrong:** a second pair of eyes did not see an additive 6-key data change.
Tasks 2, 4, 5 and 6 carry real logic and WILL get independent reviewers.

**Noted, not a defect:** task-1-report.md line 49 describes the track as "x16 y66, 268×12", which is
impossible in a 240-wide frame and contradicts its own line 312. The artifact is correct (190×6 at
34,64, confirmed above); only the prose is wrong. Task 6 must use the node geometry, not that line.

**Carry-forward to Task 6 (authoritative, from the node):**
- live studs number: `UDim2.fromOffset(34, 12)`, size 144×32, `TextXAlignment.Right` (baked STUDS at x184, 6px gap)
- progress fill: origin `UDim2.fromOffset(34, 64)`, max size 190×6, corner radius 3
- Studio's `require` cache will return a stale `UITheme` without the new keys — use `freshRequire`
  or restart Studio before concluding they are missing.

Task 1: complete (UITheme 6 entries verified live, Figma frames 128:6/129:6, review done inline).

### Task 2 — controller verification and a correction to my own plan

Verified live, independently of the report:
- `Heist.Services.Getaway` and `Heist.Tests.GetawaySpec` exist as ModuleScripts; `RunAll` registers
  `"GetawaySpec"` (39 specs). Services children unchanged otherwise — scope fence held.
- `Getaway: 14 passed, 0 failed`. TOTAL 594/15. Failing set = {World 1, RestaurantConfig 1,
  Gas2GoConfig 1, CashClaimVFX 12}; SupplyObject flaked to 0 this run. Exactly the permitted set.

**MY BUG, correctly caught by the implementer.** The `Getaway:Step()` I wrote in the plan cleared
the fired-latch only inside the `getDuffel(player) <= 0` branch. In the "re-arms for a second bag"
case the duffel is refilled BETWEEN two `Step()` calls, so that branch never executes, `_fired`
stays `true` permanently, and the player can never bank a second bag for the rest of the session.
My pre-flight scan asserted "T2: Clean. Checked each assertion against the implementation" — that
assertion was wrong; I traced 13 of the 14 tests and missed this one.

The fix (verified by reading the live source, lines 86-113, and by re-tracing all 14 tests myself):
re-arm immediately after `onEscaped` returns, conditional on the bag actually being empty at that
moment. This preserves the latch for the abnormal path where `onEscaped` does NOT empty the bag
(`bank:Claim` returns 0 once the session is no longer Active), which is the case the latch exists
for. Traced against tests 5, 6, 7 and 11 — all four behave correctly under the fix.

**Ruling: the implementer's fix stands as written.** — It is minimal, correct, and carries a comment
explaining the refill-between-Steps race. — **Cost if wrong:** none identified; the abnormal-path
latch is still exercised by test 7 ("does not re-fire every tick when onEscaped leaves the bag
alone"), which passes.

**Noted:** Step 2's predicted failure shape (`0 passed, 14 failed`) was also wrong in my plan — a
missing module makes the spec error at its first line, so it reports as one combined suite error,
not 14 independent failures. The implementer judged "fails for the right reason" correctly.

### Task 2 review (independent, sonnet)

Spec compliance ✅. Task quality: Approved. Zero Critical, zero Important.
Reviewer independently re-ran the suite rather than trusting the report: Getaway 14/0, TOTAL 594/15,
permitted failing set exactly. Confirmed GetawaySpec is a byte-for-byte match of the brief, that the
module reads no workspace/zone/currency/remote, that `isInsideBuilding` is stored verbatim and never
computed, and that the latch fix cannot weaken the inside-the-building gate (it sits inside the
branch that gate already guards).

**⚠️ "Cannot verify whether RunAll had other lines touched" — RESOLVED by me.** The reviewer had no
prior snapshot. I did: I read RunAll lines 1-70 during planning. Current lines 47-72 are identical
to the pre-task lines 46-71 (shifted one by the insertion) — same Studio-only tripwire comment, same
`IsStudio()` guard and warn string, same `folder`/`results` setup, same `pcall(TestRunner.freshRequire(mod))`.
Only `"GetawaySpec"` at line 44 was added.

Task 2: minor (deferred): "fires exactly once per bag" would also pass with no latch at all, because
  the default rig's onEscaped zeroes the duffel and the top-branch gate alone suppresses re-fire. The
  latch IS uniquely isolated by "does not re-fire every tick when onEscaped leaves the bag alone", so
  this is coarseness, not a coverage gap. My test code, not the implementer's.
Task 2: minor (deferred): "rejects a construction missing its required dependencies" passes only
  `{escapeDistance=200}`, so Luau short-circuits on the first assert (`isInsideBuilding`) and the
  test does not independently prove `getDuffel`/`onEscaped`/`getPlayers` are each required. My test
  code, not the implementer's.

Task 2: complete (Getaway + GetawaySpec + RunAll registration, review clean, 2 minors deferred).

**Ruling: Task 4 carries its own rollback; it no longer waits on the user's Studio save.** — I added a
STEP ZERO to task-4-brief.md requiring the implementer to dump the current `.Source` of all five
files it may touch into `.sdd-getaway/snapshots/*.before.lua` and confirm they are non-empty before
any edit, reporting BLOCKED if a snapshot fails. This is a more precise rollback than a whole-place
save (per-file, exact) and removes the dependency on the user being at the keyboard. The save is
still worth having as belt-and-braces and I have asked for it twice. — **Cost if wrong:** if the
implementer skips STEP ZERO and also breaks something, recovery falls back to the user's last manual
save. Mitigated by requiring the byte sizes in the report, which I will check before accepting.

**Ruling: the Task 7 part deletion will NOT be delegated.** — Deleting the four `*ClaimZone` parts is
an irreversible world mutation and one of this skill's four named stop-conditions. A subagent cannot
obtain the user's approval, and a subagent relaying "I was blocked, you do it" would be permission
laundering. So Task 7 splits: an implementer does the boot-assert and `WorldSpec` edits, and I ask
the user directly and perform the deletion myself once they approve. — **Cost if wrong:** one extra
round trip with the user. Correct by construction otherwise.

### Task 3 — controller verification

Verified via freshRequire against the tunable values I recorded during planning, BEFORE the task ran:
all four configs now carry `EscapeDistance = 200`, and `SessionDuration` / `DuffelCap` /
`AccrualPerSecond` / `CooldownDuration` show ZERO drift in all four modules. No `*ConfigSpec` gained
a failure, so no spec-expectation edits were needed. Failing set unchanged and permitted.

Reviewed inline rather than by a dispatched reviewer, same basis as Task 1: a four-field additive
data change where the meaningful check (no drift on existing values + green suite) is a live query I
ran directly and more precisely than a reviewer reading prose could.

Task 3: complete (4 Config modules, EscapeDistance=200, no drift, review inline).

### Task 4 — implementer KILLED by an API error; work verified complete anyway

The agent terminated with "API Error: Connection refused (ConnectionRefused)". Its last emitted line
was "All paths verified. Writing the full report." — so it died during report-writing, not mid-edit.
**No task-4-report.md exists.** I reconstructed state from ground truth instead:

- All five STEP ZERO snapshots written and non-empty: LocationServer 17507 B, LocationServerSpec
  18065 B, SlowFoodsServer 10020 B, Gas2GoServer 12560 B, NewsStationServer 19013 B.
- `LocationServer`: requires Getaway ✓, `_bankBag` ✓, `claimRole` GONE ✓, Claim handler GONE ✓,
  `getaway:Step()` ✓, `getaway:Forget` ✓, `markerFolder` ✓, old "head back to claim it" message GONE ✓.
- `LocationServerSpec`: Claim fixture zone GONE ✓, `setPosition` ✓, requires Getaway ✓, old
  "claim-zone entry banks" test GONE ✓. 17 test labels, same count as before — two rewritten, none lost.
- All three location scripts carry `markerFolder` ✓.
- Both new tests read verbatim and genuinely drive distance: one sets position (250,6000,0) and
  asserts floored 1234 + toast + RobberySuccess + emptied bag; the other sets the player INSIDE at
  (400,6000,0) and asserts zero payout with the bag intact — the Bank-vault case in miniature.
- Suite: LocationServer 17/0, Getaway 14/0, TOTAL 594/15, failing set exactly the permitted four.

**Ruling: accept Task 4's implementation without resurrecting the agent for its report.** — The
report would add intent and self-reported concerns; the snapshots plus live source plus a green
suite are ground truth, which is strictly stronger evidence. Resuming a crashed agent to narrate
work I have already verified buys little. — **Cost if wrong:** a concern the implementer noticed but
never wrote down is lost. Mitigated by giving the reviewer a real before/after diff (the snapshots),
which is a better review surface than any of Tasks 1-3 had.

### Task 4 review (independent, opus) — Spec ✅ 8/8, quality Approved, 2 Important

Reviewer could not use HttpService (disabled, and enabling it would be a place edit), so it hashed
every line of all five live scripts in Luau, shipped the hashes out, and ran an LCS diff against the
five snapshots in Python — an exact mechanical before/after, not eyeballing. It also re-ran the
suite itself and checked Workspace descendant counts before/after (32636 → 32636, no leaked fixtures).

Both brief-mandated checks came back clean and I confirmed both against the snapshot myself:
- Forward-declared `location` is safe: declared before `cfg`, assigned with `local` correctly
  dropped, and its closures are reached only from `Getaway:Step()`/`_bankBag`, which run only inside
  `location:Tick()`. Neither `new()` nor `Start()` steps the getaway.
- No `setOccupants("Claim", ...)` survives anywhere, so nothing passes vacuously through the removed
  fixture role. 17 tests before, 17 after — two rewritten in place, none deleted.

Scope fence clean: 6 edit sites in LocationServer, rig + 2 tests in the spec, exactly one line in
each location script. All four `*ClaimZone` parts still present. `HeistServer` has zero Getaway
references and still carries the old "head back to claim it" wording (Task 5's territory, correctly
untouched).

Task 4: fix round 1/5 dispatched — 2 Important, both test-only:
  1. The rewritten payout test asserts the toast RECIPIENT but no longer its MESSAGE. Confirmed
     against snapshot line 231, which pinned `string.format("Banked %d %s.", 1234, Config.CurrencyName)`.
     `"Banked %d %s."` exists in two places place-wide with no spec asserting either, so the payout
     message could break at all three locations with a green suite. Also inconsistent with the
     file's own convention — snapshot lines 339 and 352 pin their message text.
  2. `getaway:Forget` is implemented but untested — delete the line and the suite stays green.
     Real consequence: `Getaway._fired` is keyed by player and `Step()` only iterates
     `getPlayers()`, so a disconnected player never reaches the re-arm branch and the latch holds a
     strong reference to a departed Player forever. `Forget` is the only clearer.
  Fix dispatch requires a mutation check: comment out `getaway:Forget`, confirm the NEW assertion
  fails, restore, confirm green — so the test cannot be vacuous.

Task 4: minor (deferred): `_bankBag`'s `amount <= 0` bail lost its only test. Unreachable via the
  getaway path (Step skips bagless players) but still reachable in production with duffel > 0 when
  the session sealed or the player is not a participant — which is exactly the case Getaway's latch
  comment depends on.
Task 4: minor (deferred): the real construction path (`markerFolder` → `WaitForChild` →
  `StatusBillboardAnchor` → `Getaway.new`) is exercised by no test, since every spec injects
  `cfg.getaway`. Preconditions checked by hand instead: all three folders exist with an anchor Part.
Task 4: minor (deferred): the inside-gate test is all-negative and only meaningful paired with the
  positive test. It does earn its keep by pinning `Tick()`'s ordering — `zoneService:Update()` must
  precede `getaway:Step()`, or the 400-stud player would bank on tick 1.
Task 4: minor (deferred): `HeistServer` still shows "Duffel Full — head back to claim it." at the
  Bank until Task 5 lands. Correctly out of Task 4's scope.

**Ruling: EscapeDistance stays at 200 into playtest; I am not retuning it mid-plan.** — The reviewer
measured the real map: anchors sit exactly at their interior-zone centres, and anchor-to-anchor
horizontal distances are SlowFoods↔Gas2Go 205.3, Gas2Go↔NewsStation 165.9, SlowFoods↔Bank 165.3,
NewsStation↔Bank 487.0. So at 200 studs you cannot bank a Gas2Go job while standing at NewsStation,
nor a SlowFoods job while standing at the Bank, and the SlowFoods↔Gas2Go run clears the bar by only
5 studs. Travel is roughly 3x the old claim zones (55-83 studs). That is a tuning call, not a
correctness bug, and Task 8 Step 4 already exists to test reachability. Changing it now would
invalidate the tests just written. — **Cost if wrong:** the getaway feels too long in playtest and
the constant changes; it lives in four Config modules precisely so that is a one-line edit per
location. Surfaced to the user with the numbers rather than decided silently.

Task 4: fix round 1/5 (2 addressed, 0 open) — both Important findings closed, test-only.
  Mutation proof as required: disabling `self.getaway:Forget(player)` dropped LocationServer to
  16/1 with the NEW assertion as the sole failure ("getaway latch cleared — expected falsy, got
  true"); restoring returned 17/0 and a TOTAL identical to the pre-disable run. The test is not
  vacuous.
  Controller-verified: live `ForgetPlayer` body contains `self.getaway:Forget(player)` uncommented,
  no commented-out getaway call anywhere in LocationServer, spec pins `lastToast[2]` again, latch
  assertion present, still exactly 17 tests.

  **Implementer design call, flagged by it for confirmation — I accept it.** Finding 2's test needed
  a SECOND synthetic player rather than reusing "p1". The reason is a genuine property of the
  service: `Getaway:Step()` re-arms same-tick when `getDuffel <= 0` after `onEscaped`, and the
  normal `_bankBag` success path zeroes the duffel — so a same-player successful escape sets and
  clears the latch within one Tick and is never observably set. A persisting latch only exists on
  `Claim`'s refusal path (player not a current participant), which is exactly the real scenario
  Finding 2 cares about: a departed player whose bag was never paid out. Forcing that onto "p1"
  would have made p1's existing roster-cleared assertion trivially true regardless of ForgetPlayer,
  degrading six existing assertions to close one gap. Using "p2" isolates the new coverage.
  — **Cost if wrong:** one extra synthetic player in one test; the six original assertions keep
  their meaning. Strictly better than the alternative.

Task 4: re-review clean — Finding 1 ADDRESSED (lastToast[2] restored via the same string.format
  convention as the sealed-refusal test; "bag emptied" coverage kept; pure addition, nothing removed).
  Finding 2 ADDRESSED — re-reviewer verified the same-tick re-arm reasoning against Getaway.lua and
  BankInstance.lua itself: `Claim` zeroes the bag only while `IsParticipant`, so p2 (added →
  TryAddDuffel(50) → RemoveParticipant → escape) hits `Claim`'s refusal path, the bag stays at 50,
  and `_fired["p2"]` persists across the Tick. Only `getaway:Forget` clears it. The six original p1
  assertions confirmed byte-identical — nothing shadowed or weakened. Test count 17 before and after.
  No new Critical/Important breakage. LocationServer 17/0, Getaway 14/0, permitted failing set exactly.
  Noted: `LocationServer.before.lua` is the pre-TASK baseline (no getaway at all), not a pre-FIX
  baseline — correct, and the re-reviewer used `LocationServerSpec.fix1.before.lua` for the spec diff
  and a direct live read to confirm ForgetPlayer.

Task 4: complete (LocationServer + spec + 3 location scripts, 1 fix round, review clean, 4 minors deferred).

### Task 5 — controller verification and rulings

Verified live: requires Getaway ✓, `local function bankBag` ✓, `local function isInsideBank` ✓ and
`updateZoneOccupancy` now DELEGATES to it (union written once, not twice) ✓, `getaway:Step()` ✓,
`getaway:Forget` in PlayerRemoving ✓, `role ~= "Claim"` handler gone ✓, boot assert still expects 6
HeistZone parts (Task 7's job) ✓, new wording present ✓. Snapshot HeistServer.before.lua 45,249 B,
adler32-matched to the live pre-edit source.

**Render freeze confirmed independently by me, not taken from the report.** Measured
`RenderStepped = 0.0 fps` against `Heartbeat = 59.1 fps`, and a 0.25s linear tween still reading
0.000 after 1.01s while stuck in `PlaybackState.Playing`. This is exactly the trap
`/Users/luqpic/Documents/Roblox/CLAUDE.md` documents. The 13 extra failures (Hazard 1,
UITransitions 3, CounterBarrier 4, SupplyObject +4) are all tween or wall-clock assertions and are
environmental. Structural corroboration: `RunAll` loads only ModuleScripts under `Heist.Tests`, and
`HeistServer` is a bootstrapping Script no spec requires — so a HeistServer-only edit cannot move
any suite result at all.

**Ruling: accept both forced deviations from my plan's ordering.** — (a) `isInsideBank` had to be
declared ABOVE `updateZoneOccupancy`, not beside the Getaway block: in Lua a local referenced above
its declaration resolves to a nil global, so my literal ordering would have called nil every tick.
(b) The Getaway is constructed after `bankBag` rather than immediately after `updateZoneOccupancy`,
because `Getaway.new` asserts on a nil `onEscaped`. My plan's ordering was simply wrong; both
deviations preserve its stated rationale and the bodies/comments are verbatim. — **Cost if wrong:**
none; the alternative does not run.

**Ruling: accept the unrequested `getaway:Forget(player)` in PlayerRemoving.** — Beyond the brief,
but it mirrors `LocationServer:ForgetPlayer` and prevents exactly the leak Task 4's review proved
is real (`_fired` keyed by player, `Step` only iterates `getPlayers()`, so a departed player's latch
is never cleared). Refusing it would have shipped the Bank with a leak the other three locations
are tested against. — **Cost if wrong:** one line to remove; it cannot misfire, since Forget only
clears a latch entry.

**Ruling: the second "head back to claim it" WILL be fixed, injected into the review's fix round.** —
`HeistServer` has two occurrences; my Task 5 text named only `REFUSAL_MESSAGES.cap_exceeded`, so the
heartbeat's own Duffel Full toast still tells Bank players to return to a zone that no longer pays
out. The spec's rationale for the first applies identically to the second. The implementer correctly
refused to pick silently. I am NOT patching it from the controller session — controller fixes skip
review — so it rides the fix round with whatever the reviewer finds. — **Cost if wrong:** none; it
is a string with no callers.

Task 5: review dispatched. Suite CANNOT be used as a gate for it until the viewport draws again.

### Task 5 review (independent, opus) — spec 6/7 + 1 partial, quality: Changes requested

Method was the strongest of the plan: HTTP is disabled so it could not `diff` directly, so it
reconstructed the expected "after" from `HeistServer.before.lua` + the six edits (each splice
anchored on quoted content, matching exactly once) and hash-matched both sides —
`47214 bytes, h1=d7bcd0f4, h2=928542de` on both. That proves the six edits are the ONLY differences
across the whole ~1000-line file, and retroactively validates the snapshot as byte-accurate. It also
compiled the live source via `loadstring` without running it.

It re-derived the union from code rather than trusting the implementer's probe, and went further:
measured rotation-aware horizontal distance bands for all 8 corners of every volume —
Lobby [0.0..78.2], BankVaultZone1 [141.4..242.8], BankVaultZone2 [188.6..258.6],
BankVaultZone3 [209.0..319.6], Vault [292.0..336.1], with ClaimZone excluded at [80.7..95.1].
Contiguous coverage 141.4→336.1, no gap above the 200-stud line. Drop any one role and the bug
returns (without Vault, 292-336 banks underground; without BankVaultZone, 188.6-319.6 does).
It also ruled out a payout-killer: leaving the building is not a forfeit cause, and `_seal` has one
call site (timer expiry), so nothing voids the bag during the run.

Task 5: fix round 1/5 dispatched — 3 items, all mine rather than the implementer's:
  1. Stale "head back to claim it" toast at line 1019 (NOT 1018 as reported; script_read wins),
     plus the now-false comment above `cap_exceeded` that claims both share wording.
  2. Important — the three-role union survives in a SECOND verbatim copy in the `onForfeit`
     closure (lines 182-187), so requirement 3's "union in exactly one place" is unmet. Pre-existing
     code, but Task 5's whole point was extracting that helper. Drift hazard: add a fourth interior
     volume, update `isInsideBank`, miss this, and a forfeited player there is never teleported out.
     My requirement was stricter than my own brief, which named only `updateZoneOccupancy`.
  3. Important — `workspace:WaitForChild("HeistMarkers"):WaitForChild("StatusBillboardAnchor")` at
     line 847 is untimed and unasserted. If either is ever renamed, HeistServer blocks FOREVER with
     no error: trigger, PlayerAdded/Removing and the entire heartbeat never wire up, while the
     "Bank booted" print above it still fires so it looks healthy. Diverges from the reviewed
     `LocationServer` (10s + assert) and `HeistClient:344` (10s). **This line is my brief's verbatim
     text — my defect.**

Task 5: minor (deferred): report cited the stale toast at line 1018; it is 1019.
Task 5: ⚠️ carried to Task 8 (cannot be closed by reading): no end-to-end Bank payout executed;
  spatial gaplessness of the gauntlet proven only by distance bands (necessary, not sufficient —
  two volumes can share a band yet be spatially disjoint); multi-player untested.

Task 5: fix round 1/5 (3 addressed, 0 open). Snapshot HeistServer.fix1.before.lua 47,213 B.
  Controller-verified live: forward decl `local isInsideBank` present; definition is
  `function isInsideBank(player)` with NO `local` (the failure mode that would have left the
  forward-declared local nil and called nil at session end — checked explicitly, absent);
  `onForfeit` now reads `local isInside = isInsideBank(player)`; anchor lookup is the bounded
  10s + assert form; `loadstring` COMPILES OK; zero remaining "head back to claim it" game-wide.

  **My instruction was wrong and the implementer correctly refused to follow it literally.** I
  predicted `zoneService:IsInside("Lobby"` would appear exactly ONCE after the fix. It appears
  twice, correctly: (1) inside `isInsideBank`'s own canonical body, and (2)
  `if not zoneService:IsInside("Lobby", player) then return end` guarding `tryTriggerRobbery` —
  the weapon-equip robbery trigger, which deliberately checks the LOBBY ALONE, not the union.
  Routing that through `isInsideBank` would mean equipping a weapon deep in the Vault or the
  underground gauntlet fires a fresh robbery trigger — a functional regression. It verified the
  onForfeit safety question independently too (onForfeit ← `_seal` ← `Step` ← the heartbeat
  task.spawn wired at the end of the script; no boot-time path) before making the change.

**Ruling: two `IsInside("Lobby")` call sites is the correct end state, not an unmet requirement.** —
The requirement was "the three-role UNION lives in one place", which is now true; the lobby-only
trigger check is a different predicate that merely shares one term. — **Cost if wrong:** none; the
alternative is a live regression.

Task 5: complete (HeistServer wired + 3-item fix round, re-review clean: all ADDRESSED, compile OK,
  whole-file diff exactly 6 hunks). Re-reviewer confirmed the yield-boundary safety argument:
  `task.spawn`'s body runs synchronously only to its first yield, and `RunService.Heartbeat:Wait()`
  is the loop's first statement, so the whole script (including isInsideBank's definition at 788)
  has executed before `onForfeit` can fire. `local isInsideBank` appears exactly once (line 144);
  every other occurrence is a reference into that same upvalue — no shadowing.

### Task 7 — USER DECISION OBTAINED (asked directly, not delegated)

Presented the four parts itemized (all plain Parts, no descendants, only a `ZoneRole=Claim`
attribute + their location's zone tag) with three options. **The user chose: untag them, keep the
geometry.** Not deletion.

**Ruling: Task 7 retires the Claim zones by removing tag + ZoneRole attribute, not by `Destroy()`.**
— Functionally identical for every code path (`CollectionService:GetTagged` stops returning them,
so the boot assert sees 5 HeistZone parts and WorldSpec's manifest matches), clears the pre-existing
WorldSpec "ClaimZone: no floor found" failure the same way a deletion would, and is reversible by
re-adding one tag — which matters because there is no version control for this place. — **Cost if
wrong:** four invisible Parts remain in Workspace as dead geometry a future session may puzzle over;
mitigated by recording it in the changelog. This supersedes the plan's Task 7 Steps 2 and 4.

### Task 7 — complete (untagging, per the user's choice)

Controller-verified live: all four parts EXIST with 0 tags and 0 attributes at unchanged positions —
the approved untag, no deletion. Tag counts HeistZone 5, SlowFoodsZone 1, Gas2GoZone 1,
NewsStationZone 1. `WorldSpec` counts by `GetTagged`, so untagging satisfied it exactly as a
deletion would; no assert was weakened. Suite 594/14 with `World: 50 passed, 0 failed` — the
pre-existing "ClaimZone: no floor found" failure is GONE, which was the designed success signal.

**VIEWPORT RECOVERED mid-task** — measured RenderStepped 14.6 fps vs Heartbeat 58.5, and a 0.2s
tween reaching 100.0/Completed. Hazard, UITransitions, CounterBarrier and SupplyObject all returned
to green, confirming those 13 failures were environmental exactly as diagnosed. **Tasks 6 and 8 are
unblocked.**

**Ruling: ratify the deletion of the WorldSpec test "the Claim and Lobby zones do not overlap".** —
It resolved the Claim zone by role and indexed it, so it dies with `attempt to index nil` once the
zone is untagged. Its invariant — that banking required physically crossing the door — belonged to
the Claim ZONE and has no analogue under a distance gate; it cannot be rewritten, only retired, and
`GetawaySpec` now owns the equivalent guarantee. The implementer replaced it in place with a comment
recording the removal and the reasoning, and correctly flagged it for my ratification rather than
deleting a test silently. — **Cost if wrong:** an invariant nobody re-checks; but the invariant
describes geometry the game no longer depends on.

**Ruling: accept the three extra scripts edited beyond the brief.** — `SlowFoodsServer`,
`Gas2GoServer` and `NewsStationServer` each carried their own `#zones == 2` + `roles.Claim` boot
assert that my Step 3 never mentioned (it named only HeistServer). Without changing them those three
locations would not boot at all after untagging. Script edits and untagging were done back to back
so the inconsistent window was never left open. — **Cost if wrong:** none; the alternative is three
dead locations. My brief was incomplete.

Task 7: minor (deferred): NewsStationServer's boot assert has no test coverage — WorldSpec has no
  NewsStation zone assertions at all. Its only proof is the clean-boot `zones=1` line and a compile.
Task 7: minor (deferred): nothing in the world marks the four parts as deliberately retired; only
  the script comments do. A descriptive attribute breadcrumb was offered and not taken.

**Tooling trap recorded to memory** (`roblox-mcp-multi-edit-replace-all-lies`): `multi_edit` with
`replace_all: true` reported "11 edits applied" while changing NOTHING at two target sites. Only the
suite caught it. The returned edit count is not evidence — read the region back.

Task 7: complete (4 zones untagged, 5 scripts, World failure cleared, review pending).

### Task 6 — controller verification

Verified live in source: all five tables the plan used-but-never-declared are declared
(`getawayWidgets`, `getawayShown`, `getawayRemaining`, `locationAnchors`, `escapeDistances`) — the
gap my pre-flight scan caught and carried into the brief. Widget uses the slice, near-state swaps to
`GetawayNear`, timer gate is `zoneOccupancy[location] or ...`, `GETAWAY_POSITION` is in the derived
chain and the toast re-derives below it. Geometry in the shipped code is `fromOffset(34,12)` 144x32
`TextXAlignment.Right` and `fromOffset(34,64)` 190x6 — and my plan's erroneous "190x32" prose is
ABSENT. Suite 594/14, World 50/0, Getaway 14/0, LocationServer 17/0, SupplyObject 25/0.

**My plan's Step 4 prose would have shipped a visual bug.** It said the studs box should be "190x32
matching the timer", but the baked `STUDS` suffix starts at x184, so a 190-wide box from x34 runs to
x224 and collides with it. The corrected 144-wide right-aligned figure came from the node geometry I
put in the brief after catching the task-1 report's self-contradiction. Caught twice, upstream.

Task 6: minor (deferred): `screen_capture` returns a uniform magenta frame in Play mode (three
  attempts) though RenderStepped measured 14.6 fps INSIDE Play and tweens completed; the same call
  works the instant Play stops. So visual proof is by property read-back, not pixels. The image in
  task-6-report.md is a LABELLED Edit-mode reconstruction, not the live widget.
Task 6: minor (deferred): the GUI inset measured 58px in this viewport, not the ~36px the project
  notes state — it is viewport-dependent. All elements read exactly 58 above their declared offset,
  so the layout is right; only the documented constant is misleading.
Task 6: minor (deferred), and MINE: my Step 7 timer change (`zoneOccupancy[location] or amount > 0`)
  means heist timers are no longer strictly zone-exclusive — a player holding bags from two
  simultaneous sessions could see two timers stacked at one position. The getaway widget IS
  de-duplicated (I required that); the timer is not. Same class as the pre-existing duffel overlap,
  but introduced by my change rather than inherited.

**Ruling: the widget's `session.state == "Active"` gate is correct and NOT a divergence to fix.** —
The implementer flagged it as stricter than the server's `Getaway`, which does not check session
state, worrying the widget could hide while the server still banked. It cannot: `BankInstance:Claim`
returns 0 unless `_state == ACTIVE`, so once a session is not Active no payout is possible and
hiding the widget matches the effective behaviour exactly. — **Cost if wrong:** none identified; the
client is if anything more accurate than `Getaway`'s own gate.

Task 6: fix round 1/5 (4 addressed, 0 open). Snapshot HeistClient.fix1.before.lua 61,572 B,
  SHA-256 9b9cca63…, rolling hash verified in BOTH Luau and Python against live.
  Live measurements, not assertions: Item 1 — fill scale lands on exact 1/190 multiples against a
  190x6 BarTrack; tween count over a real 200-stud run drops 749 → 190 at 60fps and STAYS 190 at
  144/240fps. Item 2 — with SlowFoods+Gas2Go both Active and bags from both: outside both zones
  = 1 timer + 1 widget; inside Gas2Go's zone = 1 timer (Gas2Go) + 1 widget (SlowFoods). The OLD
  gate evaluated on the identical payloads is true for 2 locations — the defect was reproduced
  before being fixed. Item 3 — at a true 59.7 studs the HUD now reads "60" (was "59"). Item 4 —
  fill reads 0.000000 after the hide edge and climbs 0→0.70 on re-show across 198 sampled frames,
  never showing a full bar. Suite 594/14, permitted set exactly, run twice identically.
  Payloads were injected (stated plainly by the implementer); character, PrimaryPart, anchors,
  configs and the render loop were all real.

**Ruling: accept the two-tier timer rule; do NOT add the offered third fallback tier.** — The
implementer correctly noted the timer now hides in states where `urgentLocation` is nil: no
PrimaryPart, missing anchor, unresolved EscapeDistance. But each of those is already degenerate:
a missing anchor or config warns at boot and the getaway widget cannot function at all, and the
no-PrimaryPart window means the character died — which runs `Forfeit:Die` → `VoidDuffel`, so
`amount` is 0 and the timer would hide under the OLD gate too. A third tier would add branching for
states that cannot materially occur. — **Cost if wrong:** the clock blinks off for a frame or two in
a state where the getaway widget is also blank; visible in Task 8 if real.

Task 6: minor (deferred): Item 4's reset fires at the START of the 0.4s slide-out, so the bar flies
  off empty. Moving it to just before SlideIn (while parked off-screen) would be invisible by
  construction — a one-line move the implementer offered.
Task 6: minor (deferred): `190` is a bare literal in the quantiser and must stay in lockstep with
  `getawayTrack.Size = UDim2.fromOffset(190, 6)` ~200 lines away, with nothing enforcing it.
Task 6: minor (deferred): timer and getaway widget can legitimately name DIFFERENT locations
  (inside one building while escaping another), and neither slice carries a location label, so a
  player could read it as a bug. Correct per spec; worth knowing.

**Environment findings recorded:**
- **The `Write` tool silently strips trailing whitespace.** A snapshot came out one byte short
  because a line ended with a space; caught only by per-chunk hashing. So Write-produced snapshots
  in this plan are FUNCTIONALLY exact (trailing whitespace is semantically irrelevant in Lua) but
  not guaranteed byte-exact. My earlier "byte-exact rollback" phrasing was too strong.
- **Stray `python3 -m http.server` on port 8731 — found and killed by me** (PID 15931, running
  since 19:31, i.e. left over from Task 1's Figma→Roblox upload pipeline, serving
  `.sdd-getaway/snapshots/`). Bound to 127.0.0.1 so never network-exposed. Port confirmed closed,
  no other http.server processes remain. Worth adding a teardown step to that pipeline's memory.

Task 6: re-review clean — all 4 ADDRESSED, no new breakage. Diff provably confined to the
  RenderStepped closure (lines 1-1096 byte-identical; +58 lines = exactly the file's total growth).
  Reviewer confirmed the restructure's key properties itself: `timerLocation` is a single value so
  at most one timer is driven; the hide branch re-evaluates every location every frame (a
  straight-line loop, not transition-only) so a deselected location is forced through SlideOut the
  next frame; `timerShown`'s edge guard is intact; both branches re-check Active + endsAt (the
  getaway pass does not check endsAt); the clock/urgency block is byte-identical, only the
  show/hide decision moved. Item 4 cancels the in-flight tween and clears `_lastRatio` before
  writing Size directly, so nothing can fight the reset. Suite 594/14, permitted set exactly.

Task 6: complete (widget + timer pairing, 1 fix round, re-review clean, 3 minors deferred).

=== ALL SEVEN CODE TASKS COMPLETE. Task 8 (verification) is all that remains. ===

### Task 8 — PASS (genuine end-to-end, no injected payloads)

Method verified honest: real Weapon-tagged Tool equips, real ProximityPrompt holds via
InputHoldBegin/End, the Bank's FULL gauntlet played (Terminal 1 → Terminal 2 → 5s C4 hold →
detonation → vault prompt — the only path that calls AddParticipant for the Bank). Movement between
map points teleported (labelled); Gas2Go and NewsStation escapes WALKED with real pathfinding.

THE CRITICAL RESULT: a full 15,000 bag sat in VaultZone at 313.4 studs from the anchor for ~96s
(~960 consecutive Getaway:Step calls) and cash never moved off 15,000. Dense samples at 313.4 /
296.3 / 290.6 / 229.6 studs — all inside=true, all cash unchanged. The 229.6 sample is decisive:
past EscapeDistance, unambiguously inside, zero payout. Refused at 199.0, fired at 204.0.
The server even sent "Duffel Full — get clear of the building to bank it." and still paid nothing.
`isInsideBank` is correct. The failure this design exists to prevent does not occur.

Per location: SlowFoods 4,000 banked at 206.0 (nothing at 199.0) · Gas2Go 4,000 walked out, banked
at 204.0 · NewsStation 7,000 walked out, banked at 203.9 · Bank 15,000 by real vault accrual,
banked at 204.0. Widget hidden inside, counts down, bar fills, gold bake swaps at exactly 50 studs
remaining on all four. Toast + RobberySuccess on every payout.
Expiry: forfeited 2000 (timer_expired), cash unchanged, widget and timer both slid away.
Bonus finding: fell into the underground DeathVolume mid-sample — forfeited 15000 (death_pit),
"You fell. Bag lost.", cash unchanged. The death path works with a full bag.
Reachability: Baseplate is 2048x2048 flat, so the ~490-stud built extent is not the constraint.
Walked Bank ExitSpawn → 206.6 studs in 8.2s; SlowFoods ExitSpawn → 207.0 in 9.9s.

**My plan's expected suite figure was wrong and Task 8 caught it.** I wrote 593/15; actual is
594/14. My arithmetic never accounted for (a) the WorldSpec overlap test Task 7 deleted, nor (b)
the SupplyObject flake. 608 tests now = 595 baseline + 14 Getaway - 1 deleted. Consistent.

Task 8: complete (PASS).

Task 8: could NOT verify (carried to the final report, not resolved):
  - A Bank run WALKED from the vault out: the Bank interior is not on the navmesh (ComputeAsync
    from the lobby returns NoPath), so in-Bank movement was PivotTo. Exterior leg proven walkable.
  - SlowFoods/Bank escapes as continuous walks (sampled by teleport; walkability proved separately).
  - Anything visual beyond property read-backs — no screenshots, and at ~15 FPS tween smoothness
    is unverified.
  - NewsStation safes / the full 10,000 cap (safe code minigame skipped).
  - Multiplayer (one player only, though three sessions were Active at once with no HUD conflict).
  - A second Bank session (1800s cooldown allowed exactly one).
  - Guard engagement while carrying a bag.
  - DataStore persistence — API access off in Studio, all saves 403'd. Payouts verified in-session
    only, so nothing proves the cash survives a rejoin.

## !!! DATA LOSS — LocationServer + LocationServerSpec deleted from the live place !!!

Discovered by the final-fix agent, which correctly made ZERO changes and reported BLOCKED rather
than working around it or restoring the wrong snapshot. Confirmed by me independently:
`Heist.Services` has 6 children (no LocationServer), `Heist.Tests` has 39 (no LocationServerSpec).
Suite 577/15 with `LocationServerSpec :: module missing`. **The place is runtime-broken**:
SlowFoodsServer, Gas2GoServer and NewsStationServer all `require(Heist.Services.LocationServer)`,
so three of four locations would error at boot.

**Cause unknown.** The final whole-feature review read LocationServer live and quoted its line
numbers, so it existed then; the window between that and the fix dispatch contains only my own
reads and one Bash write to a scratch file. I am not attributing it to a subagent without evidence.

Recovery options examined:
- **Studio undo — tried, exactly once, and it is NOT the answer.** I fingerprinted every script
  this plan touched (source hashes) plus the zone tag counts, called `ChangeHistoryService:Undo()`,
  and detected ZERO changes — the deletion is not on the undo stack. Redid immediately and
  re-verified the fingerprint: 0 mismatches, state identical to before the experiment.
- **Autosave — none usable.** `130328863401144_AutoRecovery_0.rbxl` is dated Sep 6, two weeks stale.
- **Place file on disk — too old.** `Robbery System.rbxl` is 2026-09-19 13:40, before this work began.
- **`snapshots/LocationServer.before.lua` — MUST NOT be restored as-is.** It is the PRE-getaway
  module: still has `claimRole`, the claim-zone `Entered` handler and "head back to claim it", and
  zero getaway references. Restoring it verbatim would silently revert Task 4 at three locations and
  reinstate the Claim zone. The blocked agent flagged this correctly and I confirmed it.

**Ruling: reconstruct rather than revert, because the reconstruction inputs are complete.** —
`task-4-brief.md` contains the exact implementation code I authored for every edit site
(`_bankBag`, the Getaway construction, the `Tick()` call, `ForgetPlayer`, the refusal message,
`markerFolder`); `task-4-report.md` carries fix round 1's full before/after for both spec changes;
`LocationServerSpec.fix1.before.lua` is the post-Task-4 spec needing only those two assertions; and
the final review independently quoted the live bodies and their line numbers. The verification gate
is unambiguous and pre-existing: `LocationServer: 17 passed, 0 failed`, TOTAL 594/14, and a clean
four-location boot. — **Cost if wrong:** a subtly-wrong reconstruction of verified code. Mitigated
by the 17-test gate, a boot check, and cross-checking against the final review's quoted bodies.

**Reconstruction attempt 1 died on its first step** — same "API Error: Connection refused
(ConnectionRefused)" that killed Task 4's implementer. Verified it left NO partial state: Services
still 6 children, Tests still 39, no stray instances, Getaway/GetawaySpec intact, HeistServer 47,480
and HeistClient 64,796 bytes (both matching the final review's figures). Retrying with a
resilience change: build both files ON DISK in `.sdd-getaway/reconstructed/` and verify them there
FIRST, pushing to Studio only once they are complete — so a third failure loses nothing.

### Reconstruction attempt 2 — COMPLETE, gate met

Controller-verified live: LocationServer 18,450 B; Spec 20,539 B with 17 tests. `claimRole` 0 hits,
"head back to claim it" 0 hits, claim-zone Entered handler gone; `_bankBag` 2, `getaway:Step` 1,
`getaway:Forget` 1, `markerFolder` 4. `_bankBag` body byte-correct INCLUDING the load-bearing
"Fired after currency:Add" ordering comment. Module requires OK; all three location scripts resolve
it with the right marker folders. LocationServer 17/0, Getaway 14/0, World 50/0, TOTAL 594/14.
All four locations boot clean — which incidentally exercised the previously-untested real
`markerFolder` → `StatusBillboardAnchor` → `Getaway.new` path at three locations.

Built by mechanical anchored splices on disk first, then pushed and verified byte-exact (length,
byte sum and djb2 all matching). No retyping.

**The one honest gap, and it was handled correctly.** Line anchors match at `cap_exceeded` L73 and
`has_duffel` L75, but drift by a constant -4 from the Getaway construction and -6 from
`getaway:Step()`. Solved as simultaneous equations, the shortfall is exactly 4 comment lines above
the Getaway construction block and 2 above `self.getaway:Step()` in `Tick()` — both places where a
rationale comment belongs, and Task 5 put 5-line comments at both analogous spots in `HeistServer`.
No input records the original wording, so the agent shipped the code-exact rebuild rather than
fabricate prose to make a checksum line up. Every executable line is the briefs' literal text.
**Ruling: accept the gap.** — Comment prose carries no behaviour, the executable reconstruction is
verified by 17 tests and a clean boot, and inventing plausible-looking rationale comments would be
worse than an acknowledged absence: a future reader would trust fabricated reasoning. — **Cost if
wrong:** two rationale comments are missing; the ledger records what they said in substance.

Also confirmed the viewport trap again: first suite run after the rebuild read 581/27 with
RenderStepped at **1 fps**; after the boot check forced drawing it read 15 fps and all 13 extra
failures went green with no code change. 581+13 = 594, 27-13 = 14.

The agent correctly did NOT apply `final-fix.md` — that wave reported BLOCKED with zero changes, so
the correct reconstruction target is post-Task-8 / pre-final-fix. Its seven items remain open.

**!! THE RESTORED MODULES EXIST ONLY IN THE OPEN STUDIO SESSION !!** The place file on disk is
2026-09-19 13:40, predating all eight tasks. A Studio crash now loses the ENTIRE feature, not just
these two modules. Escalated to the user as the top priority.

**USER DECISIONS (asked directly, both answered):**
1. **GetawayMath refactor: FILED, not done.** Recorded as known debt in the changelog. Rationale:
   it restructures the exact arithmetic end-to-end testing validated, right after unexplained data
   loss, in a place whose only copy is an unsaved Studio session. The risk it addresses is latent —
   it needs someone to edit one of the two copies before the HUD can lie.
2. **The other six final-review items: run now.** All textual or additive; none touch the escape
   arithmetic.

### Final fix wave — Items 2-7 applied; gate UNPROVEN (viewport, not code)

Suite read 583/27. The 13 excess failures are exactly the four viewport-sensitive suites, and the
implementer measured before blaming code: RenderStepped **0.0** fps vs Heartbeat 59.6 — zero, not
merely low. I re-measured myself and got the same. Two enter/leave Play cycles and a camera nudge
did not revive it. Arithmetic reconciles exactly: 583+13 = 596 passed, 27-13 = 14 failed = the
permitted set. The three must-be-zero suites are already zero because they do not render:
**World 51/0** (Item 5 added one), **Getaway 14/0**, **LocationServer 18/0** (Item 6 added one).
596 = the 594 baseline + 2 new passing tests. **This is a reconciliation plus a measured root
cause, NOT an observed green run** — it needs re-running with a live viewport before anyone calls
it done.

**Item 2's replacement string was too long and I caught it by measuring, not by eye.** The
implementer flagged that it could not check for clipping and asked. `TextService:GetTextBoundsAsync`
at the toast's real font/size says its 89-char string renders **543.5px** in a **420px** slice, with
`TextWrapped=false` and `TextScaled=false` — it would have shipped visibly truncated. Measured five
candidates and replaced it with `"You need to bank your duffel first before carrying supplies."`
at **372.5px**: the minimal edit from the original (claim→bank), preserving the file's own
"You need to X first before Y" shape, and actually NARROWER than the 376px string it replaces.
How to bank is what the on-screen getaway widget already tells the player, so the instruction does
not need to be in this toast. Applied by me directly (one string, guarded on exactly-one-occurrence,
read back, recompiled OK) rather than spending a full dispatch on it.

All three refusal messages are now consistent, with the em dash matching HeistServer.

**BLOCKED ON THE USER — two things, neither of which I can do:**
1. Bring the Studio window forward so the viewport draws, so the gate can be observed rather than
   reconciled. Expected then: `596 passed, 14 failed`.
2. Save the place. Everything — all eight tasks plus the two reconstructed modules — exists only in
   the open Studio session; the disk file predates all of it, and modules have already vanished
   once this session.
