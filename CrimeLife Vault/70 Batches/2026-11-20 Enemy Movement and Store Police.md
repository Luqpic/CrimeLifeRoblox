---
type: batch
tags: [batch, city, enemies, npc-ai, police, robbery, bugs]
updated: 2026-11-20
sources: ["[[2026-11-20 Combat Bugs Interaction Animations Takedown Prompt]] (bugs 1 to 3)", "Play measurements, 2026-11-20 late evening", "CityMerge/after-import.md ('Enemy movement and store police 2026-11-20')"]
---

# 2026-11-20 Enemy Movement and Store Police

The three bugs of [[Current Work]]'s late-evening request. Built natively. Each was measured in Play before it was fixed.

## Asked for
- "Sometimes when I shoot teh thugs, they would freeze despite having some health left"
- "The polices would bug out, when tehy run and chase you, they tend to freeze as if they have high ping. I want them to move fluidly."
- "When you rob small franchises like slowfoods and gas2go, the polices wouldn't enter the building. They should and you can have a gun fight inside of the store."

Picker: "Squads follow + a store wave".

## Causes found
1. **Stop and go.** `_followPath` issued the next waypoint only on the 0.25 s think, and a 4-stud waypoint takes a runner 0.2 s. While a first path computed, nothing was issued at all.
   - Measured on 5 chasing Thugs (WalkSpeed 18): 13 to 35 % of frames nearly still, stops of up to 0.82 s, mean speed 11 to 14.
   - Network ownership was already the server's (`EnemyRig`).
2. **Standing on the last seen spot.** A chaser that lost sight walked to where it last saw the player and stood there for as long as the player stayed within detection range. Chase had no way out.
   - Search then stood on its spot for the whole 5 s as well.
   - Logged: every stop over 0.3 s had no path and the enemy on its move target.
3. **The wound did not show.** The kneel clip ran at Action, the same priority as the Thug's two Crowbar hold clips, so it blended away. A wounded Thug just stood still for 6 s.
4. **SlowFoods was off the navmesh** at `AgentRadius` 2 (its double door has 4-stud leaves): NoPath to every point inside; 1.75 and below get in. `Wanted.Constants.POLICE_AGENT` used 2 as well, so `_reaches` said no.
5. **Squads were sent to the entrance on purpose:** `believedPosition` returned a robbery building's ExitSpawn ("the interior is off the navmesh").
6. Store waves did not exist; police that came stopped at 60 % of their 90-stud engage range, outside.

## What changed
- **EnemyAI movement:**
  - The next waypoint goes out on `Humanoid.MoveToFinished` (`_currentWaypoint`, `_nextWaypoint`).
  - It heads straight for the goal while a first path computes.
  - `AgentRadius` 2 → 1.5.
- **EnemyAI chase and search:**
  - Lost sight at the last seen spot: Chase → Search.
  - Search looks round once, then sweeps spots 8 to 12 studs round the last known position, at least 7 from where the enemy stands (`Constants.SEARCH_SWEEP_RADIUS` 12), moving on the same think.
  - `investigate` keeps the sweep unless the place moved more than 12 studs.
- **EnemyAI flank:** a flank spot must see the target (`Stealth.solidCast`). Otherwise it tries the other side, then gives up flanking. In the Gas2Go shop three flankers had piled up against a wall.
- **Finishers:** the kneel clip at Action4.
- **Police:**
  - `POLICE_AGENT` radius 1.5.
  - `believedPosition` gives the robber's own position when a path from the building's entrance reaches them (rechecked every 3 s), else the entrance, so the Bank vault past the obby pit still gets the entrance.
  - Squad officers close in to 0.1 of their engage range (about 9 studs) while their robber is in such a building, and go back to their own range after.
- **Store waves:**
  - `HeistPolice` now runs at SlowFoods and Gas2Go: 2 officers at 60 s, +1 every 60 s, at most 3 (`Config.HeistPolice`, with `preferredRangeFraction` 0.1).
  - Each wave spawns from new markers `SlowFoodsMarkers` / `Gas2GoMarkers.HeistPoliceSpawn1..2` just outside the exit spawn, and is driven by the location's `heartbeatExtras`.
  - `HeistPolice` applies a plan's `preferredRangeFraction` per officer.
- **In Edit:** the 4 markers, each with a Police Edit rig standing on it (feet on the floor) facing the store, like the Bank and NewsStation markers.

## Verified (Play)
- **Chase:** 4 Thugs chasing after the fix: Chase frames under 2 studs/s 12 to 17 % (accelerating and turning; there were no Chase stops over 0.3 s in the run before the last tweak). The 6 stops over 0.3 s left in the final run were the look round and moments after the test teleported the player 110 studs. Before: 13 to 35 %, with stops up to 1.5 s.
- **SlowFoods robbery:** the wave stood up at the markers at 61 s and was fighting inside by 66 s; the star squad was inside by 74 s; 4 officers inside at 4 to 12 studs.
- **Gas2Go robbery:** wave at the markers at 61 s; after the close-in, flank and squad fixes all 4 officers were inside the shop within 6 to 10 studs by 90 s, flanking and taking cover, at least 6.7 studs apart.
- City 391 / 391 / 0 (temporary Script); heist 764 passed / 0 failed. Edit read-back: the 10 scripts match their mirrors (length and Adler-32), the 4 markers and rigs are in Edit.

## Not verified
- What a client sees of the police moving (the measurements are the server's).
- Squads at the Bank and NewsStation with the new believed position (the vault past the obby pit should still get the entrance; not run).
- `WantedService.setStars(player, 2)` at the spawn produced no squad in 40 s. Not investigated; squads did come at the stores.

## Trap found
Copying a heist police marker copies its Edit rig: `EditRig.take` then moves the copy onto the old rig's spot at boot (all four new markers stood up at NewsStation). [[Physics and Character Traps]]

## Saved
Studio saved to Roblox (version 65, Save, never Publish). NOT published. Nothing pushed.

## Links
[[Enemies and Spawner]] · [[Police and Wanted]] · [[Robbery Heists and Getaway]] · [[2026-11-20 Smarter Enemies]] · [[Current Work]]
