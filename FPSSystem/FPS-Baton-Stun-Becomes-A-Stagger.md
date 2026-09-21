# Change Log: The Baton Stun Drops the Target Instead of Freezing It

**Date:** 2026-09-21
**Status:** Applied (stagger, recovery and the death-mid-stagger case all confirmed live; the baton
swing that triggers it could NOT be landed in test -- see Blocked below)

## Summary
A baton hit used to lock the target's movement while leaving it standing with its idle animation
still playing, which read as a freeze rather than as having been hit. The same one-second window now
drops the target into a ragdoll and stands it back up.

## Cause of the look
The stun was movement locks only. `ShotResolver` stamps `StunnedUntil` on the target's root part;
`SprintAuthority` clamps a stunned player and `EnemyAI` sets `WalkSpeed = 0` and returns early from
its think. Nothing touched the pose, so the rig kept idling on the spot. The baton is the only weapon
in the game that declares `stunDuration` (1s), so this affects nothing else.

## Why this needed new module code
`RagdollController.ragdoll` is one-way by design -- it is the death presentation, and a corpse never
stands up. It records nothing about what it overwrites, so there was no way back. Recovery cannot
guess those values either: limbs do not all ship with the same `CanCollide` (this rig has **4**
colliding parts alive and **19** ragdolled) and an enemy's parts sit in the `EnemyCharacter`
collision group rather than Default. Restoring assumed values would quietly change how the rig
collides for the rest of its life.

## Changes
`ReplicatedStorage.Modules.RagdollController`:
- `RagdollController.stagger(character, duration)` (new) -- captures what `ragdoll` is about to
  overwrite, ragdolls, and schedules the recovery. A no-op on a character already down, so a second
  hit cannot stack two recoveries.
- `RagdollController.recover(character)` (new) -- puts back the captured `CanCollide` and
  `CollisionGroup` per part, re-enables the `AnimationConstraint`s (which is what hands the pose back
  to animation), destroys the `RagdollRootWeld`, restores `PlatformStand` / `AutoRotate` /
  `WalkSpeed` / `JumpPower`, asks for `GettingUp`, clears the `IsRagdolled` attribute, and hands
  network ownership back to a player for their own character. Refuses on a character that died while
  down -- death owns the body from that point.
- `RagdollController.ragdoll` -- the `onFinished` / `holdDuration` scheduling moved ABOVE the
  already-ragdolled guard. See below; this is a bug this change would otherwise have introduced.

`ServerScriptService.Blaster.Scripts.ShotResolver`:
- The stun branch now also calls `RagdollController.stagger(character, stunDuration)`. The attribute
  and the stagger share one duration deliberately, so the target is never back on its feet while
  still unable to move, or moving again while still limp.

## The bug this nearly introduced
`ragdoll` used to return early when the character was already ragdolled, and its `onFinished`
scheduling sat at the bottom of that same function. An enemy killed DURING a stagger is already
limp, so the death path's `ragdoll(character, { holdDuration, onFinished = destroy })` would have hit
that early return and never scheduled the corpse cleanup -- the body would have lain there forever.
Moving the scheduling above the guard means the death path still cleans up whatever state the body
was already in. Tested explicitly, below.

## Verification
**Stagger and recovery**, driven through `RagdollController.stagger(enemy, 1)`:

| | IsRagdolled | PlatformStand | AnimationConstraints | RagdollRootWeld | colliding parts |
|---|---|---|---|---|---|
| before | nil | false | 15/15 | no | **4** |
| t+0 | true | true | **0/15** | yes | **19** |
| t+0.5 | true | true | 0/15 | yes | 19 |
| t+1.3 | nil | false | **15/15** | no | **4** |

The colliding-part count returning to 4 rather than staying at 19 is the point: the restore uses the
captured value, not a default. The enemy was alive at the end and had resumed its AI
(`AIState = Chase`).

**Killed mid-stagger** -- staggered, then `Health = 0` at t+0.3:
- at t+1.5, past the one-second window: still `IsRagdolled = true`, `PlatformStand = true`. It does
  not stand back up.
- the corpse was still destroyed by the enemy death path, which is the scheduling fix above working.

## Blocked: the swing itself could not be landed in test
A real baton swing never connected in the harness, so the ShotResolver wiring is verified by
inspection rather than by a swing. Casting the baton's own rays by hand showed why, and it is a
separate defect worth its own attention:

```
cast from 3 studs, isolated target, nothing else nearby
  -> hit Workspace.Enemies.Enemy.Mossberg 590.Blaster.TrimD   tagged=nil
```

Every ray hit **the target's own carried weapon**. `castRays` resolves the victim with a single hop,
`raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid")`. That works for a body part, whose
parent is the character, but a Tool's visible geometry sits in its own Model inside the Tool, so the
lookup finds nothing and the hit comes back with `taggedHumanoid = nil` -- no damage, no stun. An
armed enemy's gun absorbs melee swings aimed at its body.

This is the same shape as the line-of-sight fix in `FPS-Clustered-Enemies-Stop-Attacking.md`, one
layer down: that one stopped allies' weapons from blocking *sight*, this is weapons blocking *hits*.
The fix is the same walk-up-the-ancestry lookup, but it belongs in `castRays`, which every shot in
the game runs through -- so it changes whether bullets that strike a carried weapon damage its
holder. That is a gameplay decision and was left alone pending a call.
