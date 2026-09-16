# Change Log: Enemies No Longer Spin in Place After Losing You

**Date:** 2026-09-17
**Status:** Applied

## Summary
An enemy that killed a player would walk over to the body and then rotate on the spot continuously
for several seconds. It now turns once to look around, as was always intended, and then holds still
for the rest of the time it spends searching.

## Changes
- `ServerScriptService.Enemy.Scripts.EnemyAI` — the look-around turn performed on reaching a lost
  target's last known position now happens once per search rather than on every decision tick.

## Notes
- Nothing about this was specific to dying. An enemy reconsiders what to do four times a second, and
  the turn had no guard stopping it repeating, so it simply kept adding another fifty degrees every
  quarter second for as long as the enemy stayed near the spot it lost you. Over a five second search
  that is roughly twenty turns, which reads as continuous spinning. Losing a living player who
  outruns the enemy's detection range produced exactly the same thing.
- The patrol behaviour already solved this correctly for its own arrival step, which is what
  confirmed the search behaviour was simply missing the equivalent guard rather than being wrong in
  some deeper way.
- The guard resets each time an enemy freshly enters a search, so an enemy that searches, gives up,
  and later searches again still gets its one turn on each occasion.
- The size of the turn, how long a search lasts, and how enemies spot and re-acquire targets are all
  unchanged. Only the repetition was removed.
