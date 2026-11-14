# Task 6 — fix round 1: four items, all in `StarterPlayer.StarterPlayerScripts.HeistClient`

Scope: `HeistClient` ONLY. Snapshot first to `.sdd-getaway/snapshots/HeistClient.fix1.before.lua`
(dump `.Source` in chunks via `execute_luau`, write with the Write tool, checksum it) before any
edit. `HeistClient` is not unit-tested, so your gate is: the suite staying within its permitted
failing set, a clean Play-mode console, and property read-backs.

Review verdict was 9/9 on spec and Approved — the feature is correct. These are quality items, two
of which are defects in the requirements I wrote, not in your predecessor's work.

---

## Item 1 (Important) — the `setFillRatio` edge guard is structurally defeated here

Current call site (~line 1273):

```lua
local ratio = (escapeDistance and escapeDistance > 0)
    and math.clamp(1 - urgentRemaining / escapeDistance, 0, 1)
    or 0
setFillRatio(widget, ratio)
```

`setFillRatio`'s guard is `if widget._lastRatio == ratio then return end`, and its own comment
explains the point: *"a Tween is created ONLY when the ratio actually changed, because this runs
every RenderStepped frame and minting ~60 identical tweens a second would both waste allocations and
have them fight each other for the same property."*

That works for the duffel, whose ratio is constant between discrete grants. It does NOT work here:
the input is a continuously varying distance, so the ratio differs every frame the player moves and
the guard never fires. Each frame allocates a closure (`pcall(function() ... :Cancel() end)`), a
goals table and a new Tween Instance — roughly 60 Instances/second for the whole escape run, about
1,200 per escape. The new code's comment claims "the same edge-triggered guard the timer and duffel
use", which is currently not true.

**Fix:** quantise the ratio to the bar's own pixel resolution before calling, so the guard fires on
every frame that would not have moved a pixel:

```lua
-- The bar is 190px wide, so quantise to its pixel resolution: a change smaller
-- than one pixel cannot be seen, and passing it through would defeat
-- setFillRatio's edge guard -- unlike the duffel, whose ratio is constant
-- between discrete grants, this input varies continuously with distance.
ratio = math.floor(ratio * 190) / 190
```

Pixel-identical output, ~190 tweens for a whole run instead of ~1,200. Then make the comment
accurate.

## Item 2 (Important) — my timer change removed the exclusivity that requirement 6 exists to enforce

Current (~line 1129):

```lua
local wantTimer = (session.state == "Active" and session.endsAt ~= nil
    and (zoneOccupancy[location] or amount > 0))
```

Before this change the gate was strictly `zoneOccupancy[location]`. A player can only be physically
inside one location's zone, so at most one timer could ever render at `TIMER_POSITION`. Adding
`or amount > 0` removes that: a player holding bags from two simultaneously-Active locations renders
TWO timers stacked on the same pixels.

That is the identical failure mode the getaway widget's single-selection rule (requirement 6) was
written to prevent — and the fact that rule was demanded at all means concurrent sessions are
considered reachable. **This is my defect: I wrote the `or amount > 0` gate and the de-dup rule, and
did not notice the first broke the invariant the second protects.**

**Fix:** make the timer obey the same one-at-a-time discipline, and pair it with the getaway
selection so the two read as the coherent stack they were designed to be:

- If the player is inside some location's zone with an Active session, that location's timer shows
  (physics already guarantees at most one).
- Otherwise, show the timer for the SAME location the getaway widget selected (`urgentLocation`).
- Never more than one timer visible.

`urgentLocation` is currently computed in the post-loop pass, after the timer block runs. Restructure
however is cleanest — resolving a single `timerLocation` in that same post-loop pass and driving the
show/hide there, mirroring how the getaway widget is driven, is the obvious shape. Keep the existing
`session.state == "Active" and session.endsAt ~= nil` conditions and the edge-guarded `timerShown`
slide transitions exactly as they are; only the *which location* decision changes.

Do NOT simply revert to `zoneOccupancy[location]` alone — keeping the timer visible during the
escape is a deliberate requirement (the clock is what the player is racing).

## Item 3 (Minor, user-visible) — the HUD reads "0" while nothing has banked yet

`commas()` floors. The server banks at `travelled >= escapeDistance`, i.e. `remaining <= 0`. So for
the last ~1 stud the widget shows `0` with a full bar while no payout has happened — the player sees
zero and thinks it is broken. The review spotted the same artifact in the predecessor's own evidence
(a reading of 170.0 studs displaying "29").

**Fix:** use `math.ceil(urgentRemaining)` for the displayed figure so it reads `1` until the bank
actually fires. Keep `commas` for the thousands separator; only the rounding changes.

## Item 4 (Minor) — stale bar on re-show

When a widget stops being urgent, `setFillRatio` is not called, so `_lastRatio` and the fill's Size
keep their last value — typically 1.0 after a successful bank. The next session at that location
slides the widget in showing a FULL bar which then drains over 0.25s, reading as "you have already
escaped" for a quarter second.

**Fix:** reset the fill to 0 on the hide edge, where `SlideOut` is called for a getaway widget.
Verify the reset does not itself animate visibly while the widget is sliding out.

---

## Do NOT change these — already ruled on

- The `session.state == "Active"` term in the widget gate. It is stricter than the server's
  `Getaway`, but `BankInstance:Claim` returns 0 unless ACTIVE and `_seal` clears the participant
  roster, so a post-seal escape banks nothing. The client matches what actually pays. Leave it.
- The `BarTrack` clip Frame (three children rather than the brief's literal two). `setFillRatio`
  writes a Scale size, which needs a 190x6 parent. Correct as built.
- The two prior deviations (dropped unused local, `root` → `characterRoot`). Both benign.

## Report contract

Append to `.sdd-getaway/task-6-report.md`: before/after for all four items, the snapshot checksum,
and — for Item 2 — a demonstration that two concurrent sessions with bags from both now yield
exactly ONE timer and ONE getaway widget. Injected payloads are fine for that, as before; say so.

Return ONLY: status, TOTAL line, failing suite names, the concurrent-session result, and concerns.
