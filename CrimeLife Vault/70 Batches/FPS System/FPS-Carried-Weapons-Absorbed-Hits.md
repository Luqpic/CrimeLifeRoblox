# Change Log: A Carried Weapon Absorbed Hits Aimed at Its Holder

**Date:** 2026-09-21
**Status:** Applied (confirmed live in both directions -- player to enemy and enemy to player)

## Summary
Every shot and swing in the game resolves through `castRays`, which decided who was hit with a single
`Instance.Parent` hop. That is correct for a body part and wrong for anything a character carries, so
a hit on a weapon resolved as hitting nobody. An armed enemy's own gun absorbed melee swings aimed at
its body.

## Cause
```lua
local humanoid = raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid")
```
A body part's parent IS the character, so this works. A Tool's visible geometry sits in its own Model
inside the Tool, so the hop lands on the weapon's Model, finds no Humanoid, and the ray comes back
with `taggedHumanoid = nil` -- no damage, no knockback, no stun.

Measured against an isolated target three studs away, nothing else nearby:

```
-> hit Workspace.Enemies.Enemy.Mossberg 590.Blaster.TrimD   tagged=nil
```

Every ray in the swing hit the target's own shotgun. A baton swing failed to land **20 times in a
row** in that state; the same swing after the fix landed on the **first** attempt.

This is almost certainly what the old "melee needs a certain angle" reports were: only a swing that
missed the weapon and found bare torso registered.

## Changes
- `ReplicatedStorage.Blaster.Utility.findOwningHumanoid` (new) -- walks up from a hit part to the
  character that owns it, through a carried Tool. A wall, a prop or a dropped Tool has no Humanoid
  anywhere above it and still resolves to nil, so cover and scenery are unaffected.
- `ReplicatedStorage.Blaster.Utility.castRays` -- uses it instead of the single hop.
- `ServerScriptService.Blaster.Scripts.ShotResolver` -- its local copy of the same walk, added a day
  earlier for the line-of-sight fix, now requires the shared module. One owner rather than two.

## What this deliberately changes
A bullet that strikes a carried weapon now damages the person holding it. Previously it was absorbed.
That is the same defect seen from the other side and the fix is the same, but it IS a gameplay
change: weapons no longer act as accidental shields.

## Verification
| case | before | after |
|---|---|---|
| baton swing at an enemy carrying an AKM | never landed in 20 attempts | landed on attempt 1 for 45 damage |
| the stagger that swing should trigger | never reached | ragdoll at 0/15 constraints, recovered to 15/15 by t+1.4s |
| a Security guard's baton swung at the player | -- | 45 damage, player ragdolled, `StunnedUntil` 0.98s, recovered by t+1.5s |

Cover was re-checked as part of the line-of-sight work and is unchanged: a solid wall still blocks,
because a wall has no Humanoid in its ancestry.

## Notes
- This sits one layer below `FPS-Clustered-Enemies-Stop-Attacking.md`. That fix stopped allies'
  weapons blocking *sight*; this stops weapons absorbing *hits*. Same root shape -- a Tool's geometry
  is not reachable from a single Parent hop -- in the two different places that ask about it.
- The walk is bounded by the ancestry depth, which for a weapon part is three or four nodes, and runs
  once per ray that connects with something.
