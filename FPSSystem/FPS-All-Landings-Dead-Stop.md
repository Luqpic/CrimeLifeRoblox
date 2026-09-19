# Change Log: Every Landing Stops the Player Dead

**Date:** 2026-09-20
**Status:** Applied (confirmed live on a plain standing jump)

## Summary
The dead stop on touchdown no longer depends on having been sprinting. Every landing -- a
sprint-jump, a hop on the spot, a step off a low ledge -- costs all momentum and rebuilds it over the
same ramp. This removes the sprint-detection machinery that existed only to tell those cases apart.

## Changes
- `ReplicatedStorage.Movement.Constants` -- `LANDING_RECOVERY_WALK_SPEED_SOFT` (12) deleted. There is
  one floor now, `LANDING_RECOVERY_WALK_SPEED` = 0, and it applies to every landing.
- `ServerScriptService.Movement.Scripts.SprintAuthority` -- the `landingWasSprint` state field, its
  initialisation, its per-character reset, the sprint test on `Landed`, and the floor selection in
  the clamp are all gone. The clamp ramps from 0 unconditionally.
- `StarterPlayer.StarterCharacterScripts.Animate2` -- `onLanded` no longer tests
  `isRunning or wasSprintingAtJump`; it always opens the recovery. `wasSprintingAtJump` and its
  assignment in `onJumping` are deleted, since nothing reads them any more.

Net effect on the codebase is a deletion: one constant, one state field, one detection rule and one
branch removed.

## Verification
A plain standing jump -- no sprint key, no movement input, the case that previously took the soft
floor of 12:

```
t+0.035  ws=0.00
t+0.102  ws=0.00     <- dead stop, same as a sprint landing
t+0.167  ws=5.83
t+0.301  ws=7.32
t+0.434  ws=13.14
t+0.501  ws=20.00    <- back to the walk baseline
```

Identical shape to the sprint-landing trace recorded in the previous entry: ~0.12s pinned at zero,
then the 50 studs/s^2 ramp back to the baseline by ~0.5s.

## Notes
- The tuning knobs are unchanged and still shared between client and server:
  `LANDING_RECOVERY_HOLD` 0.12s, `LANDING_RECOVERY_ACCELERATION` 50, `LANDING_RECOVERY_DURATION`
  0.55s.
- Worth knowing this now applies to very small drops too -- walking off a kerb costs the same 0.5s
  recovery as a sprint-jump. If that reads as sluggish in ordinary movement, the fix is a fall-height
  or fall-speed threshold on opening the window, not a return of the sprint test.
