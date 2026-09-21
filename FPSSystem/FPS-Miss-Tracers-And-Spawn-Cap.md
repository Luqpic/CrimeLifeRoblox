# Change Log: Missed Shots Stop Painting the Sky, and Half the Crowd

**Date:** 2026-09-22
**Status:** Applied (both confirmed live with measurements)

## Summary
Enemy fire left long streaks hanging across the sky. It was not their aim -- it was the tracer for a
MISS being drawn to the weapon's full range and timed by that distance. Separately, the enemy ceiling
is halved.

## Cause of the sky full of lines
Nothing was leaking or failing to despawn. Three existing numbers multiplied badly:

- Most guns here have `range = 1000` (AKM, Scar L, FN P-90; the M1911 is 900).
- A ray that hits nothing still reports its position at the far end of that range, so a missed shot's
  tracer was drawn a full **1000 studs**.
- `laserBeamEffect` times the bolt's travel as `distance / LASER_BEAM_VISUAL_SPEED`, and that speed
  is **200** studs/s -- so a 1000-stud miss crawled across the map for **5.00 seconds**.

Misses are most of what an AI enemy fires, deliberately, and with a crowd of them the streaks
overlapped faster than they expired. The screenshot is dozens of 1000-stud beams, each mid-way
through a five-second flight.

## Changes
`ReplicatedStorage.Blaster.Utility.drawRayResults`:
- `MISS_TRACER_LENGTH` = 150 studs. A ray that hit **nothing** has its tracer drawn only that far
  along the same direction.
- A ray that hit something is untouched and still runs to the impact point, however distant.

Nothing about aim, spread or accuracy changed. Enemies miss exactly as often as before; a miss simply
stops being a line across the map.

`ReplicatedStorage.Enemy.Constants`:
- `MAX_CONCURRENT_ENEMIES_PER_TYPE` 10 -> **5**. There are six spawn points, so the ceiling goes from
  60 to 30.

## Verification
Tracer, driven through the real `drawRayResults`:

| case | drawn length | lifetime |
|---|---|---|
| miss, ray reported 1000 studs | **150** | **0.75s** |
| the same miss, before | 1000 | 5.00s |
| hit at 400 studs | **400**, unchanged | 2.00s |

The hit row is the one that matters for not breaking anything: long connecting shots still draw the
whole way, so only misses got shorter.

Spawn ceiling, counted live after ~63 seconds of the spawner topping up:

```
30 alive (previously 60)
BanditsSpawner=5  DisruptersSpawner=5  OffenderSpawner=5
SaboteurSpawner=5 SmugglerSpawner=5    ThugSpawner=5
```

It plateaus at exactly five per point rather than drifting up, so the cap holds rather than merely
slowing the fill.

## Notes
- 150 studs was chosen so the streak still reads as a shot leaving the muzzle while expiring in
  0.75s. If misses still feel cluttered in a firefight, that constant is the single dial; lowering
  `LASER_BEAM_VISUAL_SPEED` would do the opposite, since lifetime is distance divided by it.
- The change applies to player misses too, not only enemies. A player emptying a magazine into the
  sky had exactly the same effect; it was simply never seen because one player misses far less often
  than thirty enemies.
- The old behaviour meant tracer lifetime grew with distance, so the least useful tracers -- the ones
  that hit nothing and flew furthest -- lasted the longest. That relationship is what actually made
  this visible, not any single number.
