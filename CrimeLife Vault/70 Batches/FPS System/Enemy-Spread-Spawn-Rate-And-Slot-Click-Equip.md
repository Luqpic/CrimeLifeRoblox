# Change Log: Enemy Spread, Spawn Rate, and Clicking a Hotbar Slot

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Enemies clustered on one spot
Every enemy type spawns from a **single** point with a cap of 10, and rigs were placed at exactly that point. Since they no longer collide with each other they stopped launching, but they still stood inside one another -- ten guns piled on the same square metre.

- `EnemySpawner` -- a rig is now placed at a random offset within `SPAWN_SCATTER_RADIUS` (22 studs) of its spawn point. The radius is sampled through a square root so the distribution is even across the disc; sampling it linearly would bunch rigs toward the centre, which is the clustering this is meant to avoid.

Measured over 18 rigs: mean nearest-neighbour **43.0 studs**, closest pair **11.58** (was 0.02 with everything stacked).

## Spawn rate
- `TOP_UP_INTERVAL` 1 -> 2.5 seconds. Measured: about 2 enemies per 5s, down from about 5.

## Clicking a hotbar slot did nothing
The slot's click handler decides "was this a click or a drag" before equipping. That test compared the SLOT'S OWN `AbsolutePosition` against the CURSOR position -- two unrelated absolute positions, where a delta was intended:

```lua
local frameStartPosition = frame.AbsolutePosition          -- captured on press
local wasClick = (frameStartPosition - Vector2.new(mouse.X, mouse.Y)).Magnitude <= 60
```

A click in the middle of a 56px slot already sits ~39px from that corner, and nearer the bottom-right it exceeds the 60px limit outright, so clicking a slot often refused to equip. Worse, with a weapon equipped the cursor is locked to screen centre (`MouseBehavior` `LockCenter`), putting it ~237px away -- so the test failed every time.

That is why clicking a slot played no equip sound: **the equip never ran at all**. The sound itself was fine.

- `InventoryController.SETTINGS` -- captures the CURSOR position on press and measures how far the mouse actually moved, which is what the constant's own comment describes ("how much you can drag a tool before it doesn't equip").

Verified by clicking a slot's lower-right quadrant -- the area the old test rejected outright: the weapon equips and the equip sound plays.
