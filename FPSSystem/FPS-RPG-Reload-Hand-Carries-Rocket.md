# Change Log: RPG Reload — The Hand Carries the Rocket Into the Tube

**Date:** 2026-09-25
**Status:** Applied — verified live in play (measured) and by frozen-pose screenshots; the place is not
saved to disk by this change.

## Summary
The RPG reload looked like the hand pulling out empty air. It was the AK47's magazine reload: the left
hand followed the AK's (hidden) magazine down and back up, and the rocket simply popped into the tube at
the end. The RPG now has a reload of its own:
1. the hand reaches down out of view and comes back up **holding the rocket**;
2. the launcher is brought across, mouth angled in toward the camera;
3. the rocket is lined up with the bore just ahead of the mouth and **pushed in**, sliding 2.3 studs deep;
4. the hand lets go and returns to its grip.

## Cause
`WeaponViewmodelMotion` profiled the RPG as a `rifle`, so it got the rifle reload track: a Magazine joint
drop with the left hand attached to the magazine. The rocket was welded rigidly to the Body and only its
visibility changed, when the ammo came back at the very end.

## Changes
- `ReplicatedStorage.Blaster.ViewModels.RPG` — the viewmodel's rocket now rides a `Round` part on a new
  `Body -> Round` Motor6D (`RoundJoint`), placed where the hand holds it: under its centreline, 0.6 studs
  ahead of the tube mouth, so the hand never enters the tube. Applied directly, because the RPG's source
  model is no longer in the Workspace; `Blaster/BuildNewPistolsShotguns.luau` carries the same step for
  any rebuild.
- `WeaponViewmodelMotion` — new `launcher` kind (the RPG's profile). `launcherReload` builds the tracks
  per rig after the joints are solved: the hand's rest is measured from the solved joint chain, and while
  the rocket is held the hand's track IS the rocket's track shifted by one constant, so it cannot slide in
  the hand. Keys: picked up off-screen (0.24), rising under the muzzle (0.46), lined up at the mouth
  (0.58), seated (0.74), hand back on the grip (0.90). The reload sound cue moves to 0.05.
- `ViewModelController.showLoadedRound` — the viewmodel's rocket is shown for the whole reload (it is in
  the hand), not only once the ammo is back. The third-person Tool is unchanged: its rocket still appears
  when the reload completes.

## Verification
- Hand-to-rocket distance while the rocket is held: **0.00 studs** — live (every sampled frame between
  pickup and seating) and at three frozen poses (1.05 s / 1.50 s / 1.95 s). The reported live maximum of
  1.38 is from before the pickup, while the hand is still travelling to the rocket off-screen.
- Live 3 s reload: rocket hidden on firing, seated at 1.87 s, ammo back to 1, 0 client and 0 server errors.

## Notes
- **The first live captures showed nothing**, and that was not an animation fault: Studio's screen capture
  lands about 3 s after it is requested — longer than the reload — and at this camera the left arm sits
  2.8 studs from the lens, behind the tube. The motion was therefore checked on frozen copies of the
  viewmodel posed by the real `Motion` code in Edit mode, viewed from outside and from the eye position.
- **The launcher's "holding" tilt was tuned from those frames**: the rifle-style tilt hid the whole carry
  behind the tube, and a stronger pull-back filled the screen with the tube. The kept value is
  `pose(-.10, -.35, .55, 4, 16, 10)`.
