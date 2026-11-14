# Task 8 brief — play-mode verification

---

## Task 8: Play-mode verification at all four locations

Script-level correctness is not sufficient — this changes the core payout loop.

- [ ] **Step 1: SlowFoods, Gas2Go, NewsStation — full run each**

For each: trigger the robbery, fill a bag, leave the building, and confirm the widget appears, counts down, fills its bar, swaps to the gold near-complete bake in the last 50 studs, and that the cash banks at 0 with the existing toast and cash burst. `screen_capture` each.

- [ ] **Step 2: The Bank — the regression this whole design guards against**

Trigger the Bank robbery, fill the bag in the vault, and confirm **no payout happens** while anywhere in the vault or the underground gauntlet, despite being up to 314 studs horizontally from the anchor. Then return to the lobby, exit, and confirm the run banks normally. **If the Bank pays out underground, `isInsideBank` is wrong — stop and fix it before continuing.**

- [ ] **Step 3: Timer visibility**

Confirm the heist timer stays on screen during the escape run and still slides away when the session ends.

- [ ] **Step 4: Reachability of 200 studs from every location**

The map is only ~490 studs across at its widest. Walk each location's escape in a couple of directions and confirm 200 studs of walkable space genuinely exists. **If any location cannot reach it, report that rather than quietly lowering `EscapeDistance`** — it is the user's call.

- [ ] **Step 5: Failure path**

Let a session expire mid-escape. Confirm the bag is lost with the existing "Run failed"/"died" messaging and **no cash is credited**.

- [ ] **Step 6: Final suite run and honest report**

Run the suite once more and report the actual numbers. Expected `593 passed, 15 failed`, with the 15 being the baseline table minus the `WorldSpec` ClaimZone row. Report any deviation rather than explaining it away.


---

## What is already proven, and what is NOT

**Proven (do not re-do):** `Getaway`'s distance maths (14 unit tests); `LocationServer`'s payout and
inside-gate (17 tests incl. a 400-studs-but-inside case); the Bank's three-role union verified by a
live `ZoneOccupancy` probe reading `inside=true` at 314 studs in VaultZone; the widget's render path
and layout via property read-backs; one-timer/one-widget under concurrent sessions.

**NOT proven — this is your job.** Nobody has ever triggered a real robbery in this place and
carried a bag to a payout. Every verification so far used unit tests, static reading, or injected
remote payloads. Specifically unproven:

1. The real trigger → accrue → escape → cash-lands loop, end to end, at any location.
2. **THE BIG ONE:** that the Bank does NOT pay out while the player is in the vault or the
   underground gauntlet, 314 studs horizontally from its anchor. This is the single failure this
   whole design exists to prevent. Everything says it is right; nothing has watched it happen.
3. That 200 studs of WALKABLE space actually exists from each location. The map is only ~490 studs
   across at its widest.
4. The session-expiry failure path: bag lost, no cash credited.

## Approach — drive it server-side, do not fight the input simulator

`screen_capture` returns a uniform magenta frame in Play mode here (confirmed, three attempts; it
works once Play stops). Do not burn time on it.

Use `start_stop_play`, then `execute_luau` with `datamodel_type: "Server"` to drive real game state:
teleport the character with `PivotTo`, equip a real weapon Tool tagged with `HeistConfig.Tags.Weapon`
inside the lobby to fire the GENUINE trigger path, let the heartbeat accrue, then teleport in steps
and observe. Read outcomes from real state, not from your own bookkeeping:

- `player.leaderstats.Cash.Value` before/after — the authoritative payout signal.
- The `DuffelState` / `Toast` / `RobberySuccess` remotes, observed from `datamodel_type: "Client"`.
- `zoneService` occupancy indirectly via the `ZoneOccupancy` remote.

**Sample the Bank case densely.** Walk outward from the vault in steps and record
(position, horizontal distance from anchor, inside?, Cash) at each. The pass condition is that Cash
does NOT change anywhere inside the building — including at distances well beyond 200 — and DOES
change once outside and past 200.

## Honesty contract — this matters more than a green result

Report what you actually observed. If you cannot complete a location, say so and say why. If you
substitute a simulated step for a real one, label it. **Do not describe an injected payload or a
teleport-only sequence as an end-to-end robbery.** A partial verification honestly labelled is worth
far more to me than a confident claim I then have to distrust. If something fails, that is a
GOOD outcome for this task — it is exactly what the task exists to find.

For item 3 (reachability), if you cannot establish walkable space reliably, say so plainly and
leave it for a human playtest rather than guessing from geometry.

## Report contract

Full report to `.sdd-getaway/task-8-report.md`: a table per location (triggered? bag filled? escape
distance at payout? cash delta?), the dense Bank sample table, the expiry-path result, and an
explicit list of what you could NOT verify.

Return ONLY: status, a one-line result per location, the Bank underground result (the critical one),
the expiry-path result, and everything you could not verify.
