# Change Log: A Sprint Landing Now Costs All Momentum

**Date:** 2026-09-19
**Status:** Applied (confirmed live with real keyboard input; one unrelated oddity noted)

## Summary
Landing from a sprint drops `WalkSpeed` to zero, holds it there briefly, then hands momentum back
over a ramp, so the player has to rebuild speed instead of carrying the sprint straight through the
landing animation. The mechanism already existed on both the client and the server; it was capped at
a jog rather than a stop, the two copies disagreed with each other, and the server's half released in
one step.

## What was already there
- `Animate2.onLanded` set `isRecoveringFromLanding`, capped `WalkSpeed` at
  `originalWalkSpeed * 0.4` (**8**) and held it for **0.35s**, after which `move()` accelerated back
  at `runAcceleration` (50 studs/s^2).
- `SprintAuthority` opened its own window on `Landed` and clamped `WalkSpeed` to **12** for **0.5s**.

Two descriptions of the same moment, 8 and 12, with nothing keeping them in step.

## Changes
### `ReplicatedStorage.Movement.Constants`
- `LANDING_RECOVERY_WALK_SPEED` 12 -> **0** — the floor for a sprint landing.
- `LANDING_RECOVERY_WALK_SPEED_SOFT` = **12** (new) — the floor for an ordinary landing, which is
  the value every landing used to get. Stepping off a low ledge should not stop you dead.
- `LANDING_RECOVERY_HOLD` = **0.12s** (new) — time pinned at the floor before momentum returns.
- `LANDING_RECOVERY_ACCELERATION` = **50** (new) — studs/s^2 back to the baseline, the same figure
  `Animate2` already accelerates at.
- `LANDING_RECOVERY_DURATION` 0.5 -> **0.55s**, sized to outlast the curve (0.12 + 20/50 = 0.52) so
  the window closing is a no-op rather than a step.

### `ServerScriptService.Movement.Scripts.SprintAuthority`
- Records `landingWasSprint` on touchdown and picks the sprint floor or the soft floor from it.
- The clamp **ramps** instead of sitting flat: `floor + ACCELERATION * (elapsed - HOLD)`, capped at
  the walk baseline — the same curve the client follows.
- The clamp now drives `WalkSpeed` in **both** directions during the window instead of only
  downward.

### `StarterPlayer.StarterCharacterScripts.Animate2`
- `LANDING_RECOVERY_SPEED` and `LANDING_RECOVERY_LOCK_DURATION` now read
  `MovementConstants.LANDING_RECOVERY_WALK_SPEED` and `.LANDING_RECOVERY_HOLD` instead of local
  numbers, so client and server cannot drift apart again.

## Two faults found by measuring, not by reading
1. **Sprint landings were taking the soft floor.** The first version detected a sprint landing from
   `getHorizontalSpeed(rootPart)` at the server's own `Landed` event. On a landing the client
   measured at **25.4 studs/s**, the server's copy read below `MIN_DRAIN_SPEED` (22), so the landing
   was classed as ordinary and clamped to 12 — the trace showed `ws=12.00` where 0 was expected.
   Detection now reads the granted `IsSprinting` attribute, which this same module owns and which
   cannot disagree with itself, with the velocity test kept as a fallback.
2. **The release wiped the momentum the client had rebuilt.** Clamping only downward left the
   server's own `WalkSpeed` pinned at the floor for the whole window, because a client's writes
   never reach the server. The end-of-window release then stepped it from the floor to the baseline,
   and that step replicated down: measured, the client was at **25.6** and was stamped back to
   **20**. Following the ramp upward leaves the server already at the baseline when the window
   closes.

## Verification
Real input, not a synthetic drop: a temporary probe `LocalScript` recorded every frame through a
landing while `LeftShift` + `W` were held and `Space` pressed. Sprint landing confirmed at
touchdown (`horiz=25.39`, `IsSprinting=true`). `actual` is measured horizontal velocity.

```
t+0.000  ws=0.00   actual=25.4   <- touchdown, sprint revoked
t+0.049  ws=0.00   actual=5.5
t+0.124  ws=0.00   actual=0.0    <- dead stop reached
t+0.165  ws=0.00   actual=0.0
t+0.232  ws=4.03   actual=4.0    <- momentum returning
t+0.299  ws=6.51   actual=6.5
t+0.365  ws=9.85   actual=9.8
t+0.433  ws=18.20  actual=18.1
t+0.566  ws=20.00  actual=20.1   <- back to walk baseline
t+0.633  sprint=true             <- sprint re-granted, window closed
```

The player stops dead within ~0.12s of touchdown, stays stopped for ~0.17s, and is back at walk pace
by ~0.57s, with sprint available again at ~0.63s. Measured velocity tracks the ceiling the whole
way, so this is real deceleration and acceleration rather than a ceiling nothing obeys.

The probe was deleted afterwards; `StarterPlayerScripts.__LandingProbe` and the `__LandingSamples`
holder are both confirmed gone.

## Notes
- The soft floor for ordinary landings is unchanged at 12, so only sprint landings feel different.
- Sprint is revoked for the length of the window, which is pre-existing behaviour and is what makes
  the player rebuild the sprint rather than resume it. That is why walk pace comes back before
  sprint does.
- **Unexplained, worth one look, not introduced here:** after the recovery window, `WalkSpeed`
  oscillated between 20.00 and 25.83 rather than settling at the sprint speed `Animate2` configures
  (`originalWalkSpeed` 20 + `runSpeedBoost` 18 = 38). In that part of the trace `actual` had fallen
  to ~0, so the character had run into geometry and the test cannot say whether this is a real
  sprint-speed fault or an artifact of being blocked. It was not chased because it sits outside the
  landing behaviour asked for.
