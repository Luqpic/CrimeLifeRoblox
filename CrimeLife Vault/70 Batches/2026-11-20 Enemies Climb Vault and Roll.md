---
type: batch
tags: [batch, city, enemies, npc-ai, animation]
updated: 2026-11-20
sources: ["[[2026-11-20 Combat Bugs Interaction Animations Takedown Prompt]] (part 5)", "Play checks, 2026-11-20 late evening", "CityMerge/after-import.md ('Enemies climb, vault and roll 2026-11-20')"]
---

# 2026-11-20 Enemies Climb, Vault and Roll

Part 5 of [[Current Work]]'s late-evening request. Built natively. No new clips: enemies play the player's own group clips.

## Asked for
"enemies can also climb over ledger and roll if needed". Picker, all four: climb ledges when chasing; vault low walls; roll to dodge; roll to reach cover.

## What changed
- **New `ServerScriptService.Enemy.Scripts.EnemyMoves`**, with EnemyAI glue. The clips are `ReplicatedStorage.PlayerMovement.Animations.LedgeClimb` (91136281858672) and `.Roll` (96743750031591), loaded on each enemy's Animator at Action4.
- **Climb and vault.**
  - A path's Jump waypoint is no longer a plain hop. The pathfinder jumps humanoids up about 7 studs, so a Thug simply hopped onto a 6-stud block.
  - `EnemyAI` holds it (`jumpAt`). Each think, `EnemyMoves.checkJump` looks 3 studs ahead at knee height and measures the obstacle's top 0.7 past its face.
  - A top 3.8 to 8 studs up (the player's ledge limits) is a climb (LedgeClimb, 1 s); 1.5 to 3.8 is a vault (the same clip at 1.6x, 0.6 s). Both need 5 studs of headroom on top. The root is anchored, tweened up, then forward onto the top, and unanchored.
  - Anything else (a gap, a step) still jumps within 3 studs of the waypoint.
  - An enemy stuck in a moving state (goal more than 3 studs away, under 1.5 studs/s for 0.6 s) checks the same way (`checkStuck`). That covers no path at all, as with a player up on a ledge.
  - While a move runs, `think` waits (`moveLockUntil`).
- **Roll to dodge.** A gun enemy fighting (Attack or Chase), hit by a player it may fight, has a 30 % chance, at most once per 4 s, to roll 12 studs sideways (Roll clip, WalkSpeed 24 for 0.62 s, `RollingUntil` on the root). It rolls only along a clear line to ground, trying the other side if one is blocked.
- **Roll to cover:** when a cover spot is 6 studs or more away, the enemy rolls there.
- New test `EnemyMoves_Test` (3).

## Verified (Play)
- **Climb:** a 6-stud block (Play only), the player on top, a Thug aggroed: LedgeClimb at 1.2 s, rose from y 8.2 to 14.0, on top of the 11-stud surface at 2.2 s, no hop.
- **Vault:** a 2.5-stud wall, 40 studs wide, between a Thug and the player: LedgeClimb at 0.6 s, over the wall at 1.3 s.
- **Dodge:** 20 hits half a second apart on an attacking Offender: 3 rolls (at 0, 7.1 and 11.4 s), the Roll clip 3 times, about 11 studs each. After moving the dodge behind the target filter: 2 rolls in 16 hits.
- City 394 / 394 / 0 (a first run failed `EnemyTargetFilter_Test`: the dodge ran before the filter and the spec's stand-in enemy has no weapon; fixed by moving it after the filter, which is also right for police and non-wanted players); heist 764 passed / 0 failed. Edit read-back: the 3 scripts match their mirrors; the test parts are gone.

## Not verified
- Roll to cover live (same `rollTo` as the dodge).
- How the clips look on the enemy rigs (checked by clip events and positions, not by eye).
- Climbs onto real city ledges and roofs (tested on a test block).

## Saved
Studio saved to Roblox (version 67, Save, never Publish). NOT published. Nothing pushed.

## Links
[[Enemies and Spawner]] · [[Movement and Stamina]] · [[2026-11-20 Enemy Movement and Store Police]] · [[Current Work]]
