# Viewmodel hands did not touch the weapon

Status: Fixed and verified live in `FPS System.rbxl` (Edit mode) across all 28 viewmodels, by
measurement. A visual confirmation pass was cut short — see Notes.

## Summary

Reported as "the hands aren't even touching the gun". True, and it was a pre-existing fault in the
procedural animation pass, not something the KeyframeSequence export introduced. The export was
faithful; it just made an existing defect easy to see for the first time.

Worst hand-to-weapon gap across the 28 rigs went from **1.03 studs to 0.25**, mean from **0.366 to
0.041**. Since the arm parts are 0.6 studs thick, a 0.25 centre-line gap is contact.

## Cause

`WeaponViewmodelMotion` seats each arm with a baked rest pose — `rifleRight`, `rifleLeft`,
`pistolRight`, `pistolLeft` — taken from the first frame of the two generic shipped idle clips
(`17649922695` and `17650466245`). Those clips are shared by 19 and 9 weapons respectively and were
never authored against any of these weapon meshes, so the hand they place has no relationship to
where the weapon's grip actually is.

Measuring each hand in weapon-body space showed the error was almost entirely **off-plane** — the
hand sitting beside the weapon rather than on it — and that it clustered by kit:

| Group | n | Bad hand | Off-plane drift |
| --- | --- | --- | --- |
| Rifle-family | 15 | Right | −1.01 to −1.13 studs |
| Shotguns | 4 | Right | **+0.96** studs |
| Pistols / revolvers | 7 | Left | −0.51 to −0.52 studs |

Every hand that already looked correct sat at Z ≈ 0. Note the sign flips between rifles and
shotguns, which is why no single corrected rest constant could fix it — the shotgun `Body` parts are
oriented opposite to the rifles'. This had to be solved per rig.

## Changes

`ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion`, one insertion in `Motion.new` after the
joint table is built:

- `frameInBody(name)` walks the Motor6D chain (`C0 * C1:Inverse()` per hop) to express any joint's
  rest frame in weapon-body space, without touching the rig or waiting on a physics solve.
- For each arm, the end nearer the weapon origin is taken as the hand, its body-local Z is the
  off-plane drift, and that component alone is cancelled by translating `base` in the joint's own
  `Part0` space.

Only the off-plane component is corrected. The clips' along-weapon and vertical hand placement is
left exactly as authored, so the pose reads the same from the first-person camera.

Because the exported KeyframeSequences bake the rest pose, all 49 were regenerated and the working
copies in each staged rig's `AnimSaves` refreshed. `ExportKeyframeSequences.luau` now requires the
motion module through a throwaway clone — see the trap below.

Mirrored to `FPSSystem/ViewmodelAnimations/`.

## Verification

All 28 rigs, runtime idle pose, hand-to-nearest-weapon-surface distance:

- Before: worst 1.03, mean 0.366 studs. 26 of 56 hands over 0.30.
- After: worst 0.25, mean 0.041 studs. **0 of 56 hands over 0.30.** Every hand's body-local Z is
  0.000.
- The regenerated clips were then applied back to the staged rigs the way the animator applies them
  (`C0 = original C0 * Pose.CFrame`) and re-measured: AK47 L 0.00 / R 0.25, AR-18 L 0.00 / R 0.20,
  Spas 12 0.00 / 0.00, M1911 0.00 / 0.00, all at plane Z 0.000. The correction survives the export.

## Notes

**Trap: Studio's Edit-mode module cache silently serves a stale module.** The first measurement
after this fix reported *no change whatsoever* — identical drift figures to three decimals. The
edit was in the source; `require` was returning the previously loaded copy. Requiring a clone of
the ModuleScript instead returned the corrected module and showed every hand at Z = 0.000. Any
Edit-mode tooling that requires a module it has just edited must clone-require, or it will measure
and export the old behaviour and look like a logic bug. This cost a full diagnostic cycle.

The fix is deliberately narrow. It guarantees hands lie in the weapon's plane; it does not claim
each hand is wrapped around the correct feature. Grip placement along and across the weapon still
comes from the generic idle clips, and there are no grip attachments on the models to solve
against — only `MuzzleAttachment`. If a specific weapon still reads wrong, the honest fix is a
per-weapon grip marker, not more inference.

Residual 0.20-0.25 stud gaps on AK47, APS and AR-18 are the right hand sitting just under the
pistol grip rather than wrapped on it. Within the arm's own thickness, so it reads as contact.
