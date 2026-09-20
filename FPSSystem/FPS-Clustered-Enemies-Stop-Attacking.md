# Change Log: Clustered Enemies Stopped Attacking

**Date:** 2026-09-21
**Status:** Applied (confirmed live, including that real cover still blocks)

## Summary
Thugs that surrounded a standing player would land a few hits and then stall -- standing in a ring,
doing nothing, until the player moved and the cycle repeated. They were blocking each other's line of
sight. An ally in the way now counts as clear; a wall still counts as cover.

## Cause
`castRays` excludes exactly one thing from its occlusion query: the shooter's own character. Another
enemy standing in front -- or, more often, the weapon it is carrying -- stops the cast. Because an
enemy cannot damage another enemy, `canDamageHumanoid` returns false for that hit, so the result
comes back with `taggedHumanoid = nil`, and `ShotResolver.hasLineOfSight` read that as blocked.

That answer then froze the enemy, because of how the two AI states are wired:
- `EnemyAI:_thinkAttack` drops to `Chase` the moment line of sight fails.
- `EnemyAI:_thinkChase` only returns to `Attack` while line of sight holds.

An enemy already standing on top of its target has nowhere to path to, so `Chase` does nothing
visible. It stands still until something moves and the cast happens to clear -- exactly the reported
"they hit, stop, and stall, and it repeats when I move".

Measured before the fix, six thugs ringed at 3.2 studs around a stationary player:

```
#1 AIState=Attack  LOS=true   hit SolarAudio.HumanoidRootPart   (tagged=SolarAudio)
#2 AIState=Attack  LOS=true   hit SolarAudio.UpperTorso         (tagged=SolarAudio)
#3 AIState=Attack  LOS=true   hit SolarAudio.LeftUpperArm       (tagged=SolarAudio)
#4 AIState=Attack  LOS=true   hit SolarAudio.HumanoidRootPart   (tagged=SolarAudio)
#5 AIState=Chase   LOS=false  hit Enemy.FN P-90.Blaster.TrimB   (tagged=nil)   <- an ally's gun
#6 AIState=Patrol  LOS=false  hit Enemy.Pi Bandit.Handle        (tagged=nil)   <- an ally's gun
```

The blockers are carried weapon geometry as often as bodies, which is why a tighter crowd makes it
worse: more guns between more shooters and the target.

## Changes
`ServerScriptService.Blaster.Scripts.ShotResolver` only:
- `findOwningHumanoid` (new, local) -- walks up from a hit part to the character that owns it,
  through a carried Tool. A blaster's visible geometry sits in its own Model inside the Tool, so a
  single `Parent` check does not find the character.
- `hasLineOfSight` -- now a bounded loop. If the cast is stopped by anything with a humanoid above
  it in the ancestry, the query steps past that blocker and looks again. A wall has no humanoid
  anywhere above it, so real cover returns false exactly as before.
- `LINE_OF_SIGHT_ALLY_STEP` = 2.5 studs (wide enough to clear a torso in one step) and
  `LINE_OF_SIGHT_MAX_ALLY_SKIPS` = 8 (bounded so a pile-up cannot spin).

If stepping past a blocker reaches the target, the function returns true -- nothing but allies was
ever in the way.

Nothing in `EnemyAI` changed. The state machine was behaving correctly on the answer it was given;
the answer was wrong.

## Verification
Seven thugs ringed at 3.0 studs around a stationary player, after the fix:

```
LOS passing: 7/7    in Attack: 7/7
```

...even though the raw cast's first hit was another enemy's blaster, leg or root part in six of the
seven. The player's health went **100 -> 0 in under 6 seconds** while ringed, where before they
would stand untouched.

Cover discrimination, same enemy and same positions each time:

| situation | line of sight |
|---|---|
| clear ground, 12 studs apart | true |
| solid wall between them | **false** |
| wall removed | true |
| an ally standing in the exact spot the wall was | **true** |

Same position, different blocker, opposite answer -- which is the whole point of the change.

## Notes
- This is shared with the AI's detection and target acquisition, not only its attack gating, so
  enemies also stop losing track of a target because a squadmate walked in front. That is the same
  bug and the same fix, not a separate behaviour.
- Player line of sight is unaffected in practice: a player on a team already had teammates pass
  through the cast via the team collision group, which is the same idea this adds for enemies, who
  have no team by design.
- The damage cast itself is deliberately untouched. Bullets still stop on an ally's body, so an
  enemy can still shield another from fire; only the "can I see you" question changed.
- Worth watching: an enemy will now open fire with an ally directly in its line. The shot resolves
  against whatever the bullet actually hits, so the ally absorbs it and takes no damage -- the shot
  is wasted rather than misdirected. If that reads badly, the fix is a separate "don't fire through
  an ally" check in `_tryFire`, not a change back here.
