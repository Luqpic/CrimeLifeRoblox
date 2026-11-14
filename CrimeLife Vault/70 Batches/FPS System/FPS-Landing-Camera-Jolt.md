# Change Log: The Camera Jolt on Landing

**Date:** 2026-09-19
**Status:** Applied (measured before and after; see Notes for the condition it does not cover)

## Summary
Sprinting, jumping and landing snapped the camera. The cause was not a shake effect -- there is no
shake system in this place -- but the camera bob rotating by an angle scaled by frame time, so the
one long frame a landing produces came out as one large swing. The angle is now clamped, and the
everyday bob is untouched.

## Cause
`StarterGui.Bobbing Camera` multiplies `Camera.CFrame` by a set of rotations every `RenderStepped`.
Each rotation is an **angle multiplied by `deltaTime`**, not a rate integrated over it:

```lua
deltaTime = deltaTime * 30
...
Camera.CFrame = Camera.CFrame * (... math.rad(func4 * deltaTime) ... math.rad(val * deltaTime)
    ... CFrame.Angles(0, 0, math.rad(func4 * deltaTime * (calcRootMagnitude / 5))) ...)
```

A long frame therefore produces a proportionally **larger** camera swing, rather than the same swing
spread over more time. A landing is exactly where a long frame happens -- contact physics, the
landing animation and its sound all resolve together -- which is why the bob read as a jolt on
touchdown and not while running. The roll term is additionally scaled by horizontal speed
(`calcRootMagnitude / 5`, up to 5x), so a sprint landing is the worst case of the worst case.

Nothing in the script is landing-specific; there was no landing code to delete.

## Changes
`StarterGui.Bobbing Camera` only:
- The frame time used for the rotation angles is clamped to the 30fps value (`math.min(raw, 1)`).
  At 60fps the value is ~0.5 and nothing changes, so ordinary walking and running bob exactly as
  before; a hitch can no longer amplify the swing.
- The existing "this frame was so long the noise terms are meaningless, reset them" guard now tests
  the **unclamped** frame time. Clamping first would have made that branch unreachable.

Nothing else was touched. The script's `CameraAuthority` registrations
(`MinZoomDistance` 0.5, `MaxZoomDistance` 128) are intact, so the zoom range is unchanged -- deleting
the script outright would have dropped the maximum zoom to the authority's default of 30.

## Verification
Camera roll sampled every frame through a real sprint-jump-land, driven by held `LeftShift` + `W`
and a `Space` press, with the touchdown frame itself captured:

| | roll on the touchdown frame | worst per-frame roll step |
|---|---|---|
| before | **-0.97 deg** | -- |
| after | **-0.084 deg** | **0.084 deg** |

Roll reads 0.000 deg on every subsequent frame of the landing window.

## Notes
- The measurement ran at ~67ms per frame (about 15fps in Studio), which is a permanent hitch
  condition and therefore a hard stress test of exactly the path being fixed.
- **The condition this does not cover:** the clamp only bites when a frame is longer than 33ms. On a
  client holding a steady 60fps, `deltaTime` is ~0.5, the clamp never engages, and the bob is
  bit-for-bit what it was. That is deliberate -- the ask was to remove the landing jolt, not the
  bob -- but it means that if the jolt is still visible on a machine that is not dropping frames at
  landing, the cause is the speed-scaled roll term itself rather than frame time, and the fix is to
  damp `calcRootMagnitude` on touchdown or to strip the roll terms entirely.
- Two heavier options were offered and declined: removing the bob altogether, and stripping every
  Z-axis roll term while keeping the positional sway.
- Both temporary probe scripts used across this session (`__LandingProbe`, `__ShakeProbe`) and their
  `StringValue` holders were deleted; confirmed absent.
