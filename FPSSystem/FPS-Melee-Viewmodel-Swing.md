# Change Log: A Real Swing for Melee Viewmodels

**Date:** 2026-09-20
**Status:** Applied (arc verified numerically against the shipped code; not yet seen swinging in game
-- see Notes)

## Summary
Melee weapons had no hit motion in first person. Both melee viewmodels ship the generic **gun** Shoot
animations, which are recoil, so a crowbar swing read as a twitch. The viewmodel now swings through a
wind-up, strike and settle arc, driven in code. Third person is untouched.

## Cause
`ReplicatedStorage.Blaster.ViewModels.Crowbar` and `.Baton` both carry:

```
Animations.Shoot   rbxassetid://6783943440
Animations.Shoot2  rbxassetid://6783954162
Animations.Shoot3  rbxassetid://6783965485
```

Those three ids are the same ones every gun in the game uses. They are a forward-held recoil kick,
not a swing, and `playShootAnimation` was playing them for melee exactly as for a rifle.

## Why this is code rather than an animation asset
A real swing would be a `KeyframeSequence` uploaded to Roblox and referenced by id. Uploading an
animation is not something the Studio bridge used here can do -- it can upload images, not animation
clips. Rather than ship three placeholder ids or leave melee unanimated, the arc is composed into the
pivot `ViewModelController:update` already applies to the whole viewmodel every frame. That costs one
extra CFrame multiply per frame, adds no instances, and covers any melee weapon without authoring a
clip each.

The tradeoff is real and worth stating: this is a rigid-body swing of the whole viewmodel, so the
arms and weapon move as one piece. A hand-authored clip could bend the elbow and wrist. If that
matters more than the time to author and upload three clips, the same trigger point can drive a real
track instead -- `playShootAnimation` is the only place that would change.

## Changes
`ReplicatedStorage.Blaster.Scripts.ViewModelController`:
- `MELEE_SWING_DURATION` 0.4s, `MELEE_SWING_REACH` 0.7 studs, `MELEE_SWING_WINDUP` 0.28 of the
  duration, and a per-variant rotation table -- overhead chop for `Shoot`, right-to-left for
  `Shoot2`, left-to-right for `Shoot3`, so consecutive swings differ.
- `meleeSwingCurve` -- returns negative during the wind-up, snaps out on a cubic ease, settles back
  on a quadratic.
- `getMeleeSwingCFrame` -- identity unless a swing is in flight, so every gun pays one nil check per
  frame and nothing else. Clears its own state when the swing ends.
- `update` -- multiplies that CFrame into the existing `PivotTo`, after the bob.
- `playShootAnimation` -- for a weapon declaring `meleeHitEffect`, starts the swing INSTEAD of
  playing the gun track. The variant name is still chosen and still returned, so the third-person
  character animation the caller drives is unaffected.
- `playReloadAnimation` -- cancels an in-flight swing, for the same reason it already stops the shoot
  tracks.

## Verification
The shipped `getMeleeSwingCFrame` was driven over a synthetic timeline (overhead variant):

| progress | pitch | forward |
|---|---|---|
| 0.00 | +0.0 deg | -0.00 studs |
| 0.10 | +10.0 deg | -0.09 |
| 0.28 | +18.7 deg | -0.17 (top of the wind-up, weapon drawn back) |
| 0.35 | -39.7 deg | +0.37 (strike) |
| 0.50 | **-74.8 deg** | **+0.70** (full extension, matches MELEE_SWING_REACH) |
| 0.70 | -30.8 deg | +0.29 |
| 0.90 | -3.4 deg | +0.03 |
| >= 1.00 | identity | state cleared |

The `Shoot2` variant reaches -60.0 yaw and +54.7 roll at the same point, so it reads as a horizontal
slash rather than the same chop.

At rest the addition is a no-op: with the crowbar equipped and no swing running, the viewmodel's
rotation relative to the camera measured **0.00 deg on all three axes across 39 consecutive frames**,
confirming the new multiply does not disturb the resting pose or the guns' path.

## Notes
- **Not verified:** the swing firing from a real click. Synthetic mouse input does not reach the
  Studio window in this environment -- the same limitation that makes `screen_capture` return a blank
  frame -- so a click produced no shot and the probe recorded a stationary viewmodel. The arc is
  proven, the trigger wiring is not. One swing in game will confirm it.
- The numbers are deliberately plain constants at the top of the file. If the swing feels slow,
  `MELEE_SWING_DURATION` is the dial; if it does not reach far enough, `MELEE_SWING_REACH`.
- Melee swing sound, trail and the per-swing hit deduplication are all unchanged -- they already
  hung off `playShootAnimation` and still do.
