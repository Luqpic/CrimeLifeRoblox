# Change Log: Shotgun Knockback Moved to the Killing Blow

**Date:** 2026-09-19 (fling reworked and retuned 2026-09-20)
**Status:** Applied (confirmed live, all cases measured)

## Summary
A shotgun now spends its whole knockback on the shot that kills and none on a shot the target
survives. Melee is untouched and still pushes on every swing.

## What was already happening
`ShotResolver` applied `knockbackForce / raysPerShot` on every pellet that connected, to living and
dying targets alike. The fling on death was never explicit -- it fell out of two things:

1. A living target's humanoid actively resists the push, so a non-lethal shotgun hit only ever
   produced a twitch.
2. `RagdollController` zeroes every part's velocity as it ragdolls, and the `Died` signal fires
   inside `TakeDamage` -- so by the time `applyDamage` reaches its knockback line, the corpse is
   limp, at rest, and no longer resisting. The same impulse that a living target shrugged off became
   the fling.

So the behaviour asked for already existed by accident. This makes it deliberate, and removes the
push from survivors.

## Changes
- `ReplicatedStorage.Blaster.Constants` -- new `KNOCKBACK_ON_KILL_ATTRIBUTE = "knockbackOnKill"`.
  Opt-in, following the same attribute-extension pattern the rest of the weapon system uses.
- `ServerScriptService.Blaster.Scripts.ShotResolver` -- a weapon declaring `knockbackOnKill` applies
  the **full** `knockbackForce` on the ray that kills and nothing otherwise. Weapons without it keep
  the per-ray push exactly as before. The full force is correct rather than a per-pellet share
  because only the one pellet that lands the kill reaches that line; the rest return at the
  `Health <= 0` guard at the top of `applyDamage`.
- `knockbackOnKill = true` set on all five shotgun tools: `Mossberg 590`, `Benelli M4`,
  `Itacha Mag-10`, `Spas 12` in `ServerStorage.Weapons`, and the `Mossberg 590` inside
  `ServerStorage.EnemyTemplates.Bandits` -- so an enemy with a shotgun kills a player the same way.

## Verification
Driven through `ShotResolver.resolveShot` against a live enemy pinned 10 studs out and level with the
shooter:

| case | damage | killed | speed straight after the shot | travelled |
|---|---|---|---|---|
| shotgun, target survives | 60.0 | no | **0.0** | -- |
| shotgun, target dies | 15.0 | yes | **57.0** | 2.26 studs |
| crowbar, target survives | 45.0 | no | **85.2 / 101.4 / 93.1** at 2 / 3 / 5 studs | -- |

The kill reading of 57.0 matches the Mossberg's `knockbackForce` of 55 plus its 0.25 upward
component. The survivor takes nothing. Melee still pushes a living target, which is the regression
that mattered.

## Notes
- The melee control missed at 4 and 10 studs before landing at 2, 3 and 5 -- the crowbar's `range` is
  6, so the longer shots were simply out of reach, not a failure of the knockback.
- The first two harness attempts produced nothing usable and are worth recording. Enemies walk, so a
  target positioned and then shot a beat later had wandered out of the cone; and positioning with the
  shooter's full `CFrame` dropped the target to Y = -0.65, below the floor, so every pellet hit
  `Workspace.SpawnLocation`. Casting the rays by hand and printing what each one struck is what
  showed that -- the earlier "no damage" readings looked like a code fault and were a harness fault.
- Knockback direction is unchanged: the unit vector from the shooter to the hit point, plus a quarter
  of the force upward.


---

# Addendum, 2026-09-20: The Fling Did Nothing, and Why

The first version was verified only by the velocity reading immediately after the shot (57.0 studs/s)
and a 0.7s displacement of 2.26 studs. That velocity was real and the fling still did not happen --
the corpse travelled about two studs, which is what prompted "the knockback wasn't that noticeable".

## Two causes, both measured

1. **The impulse was wiped by the ragdoll.** `RagdollController` zeroes every part's velocity as it
   hands the body to physics, and for an enemy that runs a frame AFTER the humanoid dies -- not
   inline with `Died`. So the push applied inside `applyDamage` was erased before it moved anything.
   Measured on the frame of the shot: root at **152.6 studs/s**; on the very next frame, **3.3**;
   total travel **1.76 studs**. The `IsRagdolled` attribute read `nil` at the moment the knockback
   was applied, which is what gave it away.
2. **Pushing the root alone does not move the body.** A ragdolled rig is fourteen separate assemblies
   held together by BallSocketConstraints. Measured: a 155 studs/s push on the root alone settled
   **1.95 studs** away, because the other thirteen limb assemblies dragged it to a halt.

## The fix
`ShotResolver.flingRagdoll` waits for `RagdollController.isRagdolled`, gives it one further frame so
the zeroing pass is behind it, then sets the velocity on **every** BasePart in the character except
those inside a carried Tool.

## Tuning
The response is steep and had to be measured rather than derived. Mean settled distance over
three to four kills per value, upward share 0.35:

| fling speed | mean distance | range |
|---|---|---|
| 30 | 12.78 studs | 10.73 .. 14.15 |
| **38** | **19.13 studs** | **18.33 .. 19.96** |
| 45 | 23.87 studs | 18.66 .. 26.47 |
| 100 | 107.96 studs | -- |
| 150 | 237.05 studs | -- |

`knockbackForce` is now **38** on all four shotguns and on the Bandits' Mossberg. The four previously
differed (55 / 55 / 75 / 58); they are uniform now because at this sensitivity that spread would have
produced wildly different distances rather than a subtle difference in weight.

## Verification, end to end through the real shot path
| case | damage | killed | travelled |
|---|---|---|---|
| Spas 12, target dies | 15.0 | yes | **20.05 studs** |
| Spas 12, target survives | 30.0 | no | **0.00 studs** |

Melee is still untouched: `Crowbar` and `Baton` keep `knockbackForce` 90 with no `knockbackOnKill`,
so they take the unchanged per-ray branch.

## Notes
- The earlier entry's claim that the fling worked was wrong, and the reason is worth keeping: a
  velocity reading taken on the frame of the shot proves an impulse was applied, not that it
  survived. Distance after the body settles is the only honest measure.
- Distance varies with terrain -- the same speed measured 16.5 studs in one batch and 41 in another
  when the corpses landed on different ground. The table above is same-batch, so the comparison
  between rows holds even though any single number will vary in play.
