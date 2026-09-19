# Change Log: Falling and Climbing Animations Restored (Dead Animation Assets)

**Date:** 2026-09-19
**Status:** Applied (confirmed live through a real fall)

## Summary
Falling played no animation, and climbing had the same fault. The wiring was never at fault --
`Animate2` handles `Freefall` and `Climbing` correctly and was calling `playAnimation` every time.
The animation assets it pointed at simply do not resolve, so the calls played nothing. Both are now
Roblox's default R15 animations.

## Cause
`StarterCharacterScripts.Animate2.fall.FallAnim` had `AnimationId = rbxassetid://79120124804027`.
Loaded through an `Animator` after an explicit `ContentProvider:PreloadAsync`, that asset reports a
track length of **0.000s** -- it never resolves. A zero-length track plays and ends in the same
frame, which is indistinguishable from no animation at all.

Measured, all after preload so the numbers are real:

| animation | asset | length |
|---|---|---|
| FallAnim (before) | 79120124804027 | **0.000s -- dead** |
| ClimbAnim | 132969691712833 | **0.000s -- dead** |
| JumpAnim | 94550951381303 | 0.600s |
| R15 default fall | 507767968 | 0.792s |
| R15 default climb | 507765644 | 1.042s |

## Changes
- `StarterPlayer.StarterCharacterScripts.Animate2.fall.FallAnim` -- `AnimationId`
  `rbxassetid://79120124804027` -> `rbxassetid://507767968`, the Roblox default R15 fall.
- `StarterPlayer.StarterCharacterScripts.Animate2.climb.ClimbAnim` -- `AnimationId`
  `rbxassetid://132969691712833` -> `rbxassetid://507765644`, the Roblox default R15 climb.

The rig is R15 (`Humanoid.RigType = Enum.HumanoidRigType.R15`), confirmed at runtime rather than
assumed. Nothing else changed. `Animate2`'s fall and climb handling, `fallTransitionTime` (0.3) and
`FALL_ANIM_SPEED` (1.0) were all already correct.

## Verification
**Fall** -- dropped the character 60 studs and recorded humanoid states and every animation that
started:
- States: `Freefall -> Landed -> Running`.
- Animations started: `rbxassetid://507767968` (len 0.792) while airborne, then idle
  (`70581846281736`) and the landing animation (`91946150190183`) on touchdown.
- The fall track was confirmed present in `Animator:GetPlayingAnimationTracks()` while airborne, at
  `Speed = 1`.

**Climb** -- spawned a 40-stud `TrussPart` in the play session, walked the character into it with
`Humanoid:Move` and held:
- States: `Climbing` reached.
- Animations started: walk (`122749871988730`, len 0.886) on the approach, then
  `rbxassetid://507765644` (len 1.042) on the truss.
- The climb track was confirmed present in `Animator:GetPlayingAnimationTracks()` at
  `Speed = 1.165`, which is `onClimbing` scaling playback to climb speed, as designed.
- The truss was created and destroyed inside the play session, so nothing persists to the place.

## Notes
- The first measurement taken here was wrong and is recorded so it is not repeated. Reading
  `AnimationTrack.Length` immediately after `LoadAnimation` returned 0.000s for EVERY animation
  including known-good default ids, because `Length` stays 0 until the asset resolves. It looked
  like proof that the asset was dead; it was proof of nothing. The valid test is
  `ContentProvider:PreloadAsync` first, then poll `Length` until it is non-zero or a deadline
  passes. Only animations that had already played in the session (idle, walk, run) read correctly
  on the naive test, which is exactly what made the bad reading look plausible.
- Worth checking where `79120124804027` and `132969691712833` came from. Two dead ids in one
  animation set suggests a batch that was uploaded under a different account or deleted, rather than
  two independent mistakes. The surviving ids in the same set (idle, walk, run, jump, crouch) all
  load, so it was not the whole batch. Both dead ids are now replaced, but if the originals were
  deliberate custom animations rather than accidents, they want re-uploading under an account this
  place can read -- the defaults are a working floor, not necessarily the intended look.
