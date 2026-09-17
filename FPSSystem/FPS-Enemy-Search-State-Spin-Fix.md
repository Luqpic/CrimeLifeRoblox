# Change Log: Enemies No Longer Spin in Place, or Run at Your Corpse

**Date:** 2026-09-17
**Status:** Applied

## Summary
Two related faults in how an enemy behaves when it loses its target. An enemy that killed a player
would walk to the body and then rotate on the spot continuously for several seconds; it now turns
once to look around, as was always intended, and then holds still. And an enemy no longer treats a
dead target as something to go and look for at all — it gives up where it stands and returns to
patrolling, instead of running over to the body and loitering there. Losing track of a target that
is still alive is unchanged: the enemy still goes to where it last saw you and looks around once.

## Changes
- `ServerScriptService.Enemy.Scripts.EnemyAI` — the look-around turn now happens once per search
  rather than on every decision tick, and chasing or attacking a target that has died now ends the
  pursuit immediately rather than starting a search at the body.

## Notes
- The spinning was nothing to do with dying. An enemy reconsiders what to do four times a second and
  the turn had no guard stopping it repeating, so it kept adding another fifty degrees every quarter
  second for as long as it stayed near the spot where it lost you. Over a five second search that is
  roughly twenty turns. Losing a living player who outran the enemy produced exactly the same thing.
- The patrol behaviour already solved this correctly for its own arrival step, which confirmed the
  search behaviour was simply missing the equivalent guard rather than being wrong more deeply.
- The corpse-chasing came from the code being unable to tell two different situations apart. Losing a
  target covers both "it died" and "it is alive but I cannot reach or see it", and both were being
  handled the same way — go to where it was last seen. For a dead target that location is the body.
  The two are now told apart, and only the dead case gives up on the spot.
- Every other route into searching was checked rather than assumed. There are three, and all three
  are only ever reached while the target is confirmed alive, so none of them could produce the same
  behaviour by another path.
- Returning to patrol already did the right full disengage, including discarding the route the enemy
  was part-way through walking. Without that it would have kept walking toward the body for a while
  before noticing. This was verified rather than taken on trust.
- The size of the turn, how long a search lasts, retaliation when shot, and how enemies spot and
  re-acquire targets are all unchanged.
