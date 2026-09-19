# Change Log: The Landing Camera Jolt, Actual Cause

**Date:** 2026-09-19
**Status:** Applied (measured at the level of the defect; see Notes for what was not observed)

## Summary
The camera jolt on a sprint landing was a regression introduced by this session's own landing-recovery
change. Holding `WalkSpeed` at 0 on touchdown made the camera bob script divide by ~zero, and its
lean term exploded by roughly three orders of magnitude. The bob script now normalises against a
reference pace that cannot collapse.

## Cause
`StarterGui.Bobbing Camera` derives its lean from how fast the character is moving **relative to its
own WalkSpeed**:

```lua
val2 = clamp(lerp(val2, -Camera.CFrame:VectorToObjectSpace(velocity / math.max(WalkSpeed, 0.01)).X * 0.04, ...), -0.12, 0.1)
```

`math.max(WalkSpeed, 0.01)` is a divide-by-zero guard, not a sane floor. The sprint-landing change
made `WalkSpeed` exactly 0 at touchdown while the character is still carrying ~25 studs/s, so the
divisor became 0.01 and the expression became a ~2500x amplifier. Measured at touchdown, driven by a
real strafing sprint-jump-land:

```
t+0.000  ws=0.00  divisor=0.01  leanTarget=-18.542     <- normal value is about 0.02
t+0.003  ws=0.00  divisor=0.01  leanTarget=+10.642     <- sign inverted on the next frame
```

`val2` is clamped to +-0.12 rad, so those targets slammed it onto the rail and flipped it frame to
frame -- a hard camera snap at exactly the moment of touchdown, which is what the recording shows.

## Changes
`StarterGui.Bobbing Camera`:
- The lean now divides by `math.max(humanoid.WalkSpeed, MovementConstants.WALK_SPEED_BASELINE)`. A
  reference pace cannot collapse, so the term stays in its intended range no matter what the landing
  recovery does to `WalkSpeed`.
- Earlier in the same session: the rotation angles' frame time is clamped to the 30fps value, and the
  existing hitch guard was repointed at the unclamped value. That change is kept -- it is correct on
  its own -- but it was **not** the cause and did not fix the reported problem.

## Verification
Same strafing sprint-jump-land, with the probe reporting the old and new expressions side by side:

| | at touchdown (ws = 0) | next frame | once ws > 20 |
|---|---|---|---|
| old expression | **+50.669** | **+71.481** | +0.028 |
| new expression | **+0.025** | **+0.036** | +0.028 |

The clamp is +-0.1, so the old values overshot it by 500-700x while the new ones sit inside it at the
same magnitude as the steady-state value. Once `WalkSpeed` recovers past the baseline the two
expressions agree exactly (+0.028 / +0.028), which is the proof that ordinary walking and running are
unchanged. Camera roll on the touchdown frame fell from +0.434 deg / +0.659 deg across earlier runs to
+0.100 deg, and reads 0.000 deg on every following frame.

## Notes
- The first attempt at this blamed frame-time amplification and was wrong about the cause. It was
  measured only as "roll is small now" at 15fps, which was too coarse to distinguish a fixed jolt
  from a missed sample. The report of it as fixed was premature.
- **Not observed:** the jolt's absence on screen. Studio renders at ~15fps here with `screen_capture`
  returning a blank frame, so the confirmation is the input value, not the picture. The recording that
  demonstrated the problem is the right way to confirm the fix.
- The divisor change slightly reduces lean while crouched (WalkSpeed below the baseline now divides by
  the baseline instead of the lower value). That is a side effect, and arguably the same bug in
  miniature.
