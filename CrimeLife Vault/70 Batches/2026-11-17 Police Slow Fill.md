---
type: batch
tags: [batch, police, wanted, npc-ai]
updated: 2026-11-17
sources: ["CrimeLifeRoblox/CityScripts/ServerScriptService.Wanted.PoliceDispatcher.luau", "CrimeLifeRoblox/CityScripts/ReplicatedStorage.Wanted.Constants.luau", "CrimeLifeRoblox/CityScripts/ServerStorage.UnitTest.Cases.PoliceSpawnPoint_Test.luau"]
---

# 2026-11-17 Police Slow Fill

## Asked for
"Fix the slow police fill": the open bug from [[2026-11-17 Police and Wanted]]. At the city spawn plaza, a forced 5 stars brought 1 officer in 60 s.

## What changed
- **The cause, measured at the city spawn plaza** (-7, 5, 2503):
  - Only 4 of 3,000 ring samples (90 to 160 studs) passed the cheap checks; 820 of them were road, and the rest of those were in the player's sight. The open road grid is in view out to 320 studs: 160 to 240 had 0 of 120, 240 to 320 had 2 of 120.
  - With `SPAWN_TRIES` 40 a search found a point about 5 % of the time, and a round stopped at its first miss.
  - The path checks were never the limit: no sample got as far as one.
- **The fix, in `PoliceDispatcher`:**
  - `isValidSpawn` is split into `_cheapReason` (boxes, ground, sight: rays only) and `reachesPlayer` (the path check, through the `_reaches` seam). `isValidSpawn` itself behaves as before.
  - `findSpawn` samples up to `SPAWN_SAMPLES` 2,000 points, yielding every 50, and runs the path check only on points that pass the cheap checks.
  - The path checks share a budget per player per round, `SPAWN_PATH_BUDGET` 20 `ComputeAsync` calls; a search stops when the budget is spent.
  - A round still stops at its first search that finds nothing.
- **`Constants`:** `SPAWN_TRIES` 40 is replaced by `SPAWN_SAMPLES` 2000 and `SPAWN_PATH_BUDGET` 20, with the measurements in comments.
- **New test (`PoliceSpawnPoint_Test`):**
  - when no path leads anywhere, a 10-officer round spends exactly 20 path checks and spawns none;
  - when every path leads, it spends 10 path checks and spawns 10;
  - when every sample is in sight, it spends no path checks and spawns none.

## Decisions
- **Budget the expensive checks only.** This was the re-review's suggestion in [[2026-11-17 Police and Wanted]]. Cheap misses cost rays, not path computations, so they are not counted. Cost if wrong: more ray work per round where points are scarce (measured below as small).
- **The rule that police never spawn in the player's sight is kept** ([[CrimeLife Tycoon Decisions]], the police design's anti-goals). Letting police spawn far off in sight would have been cheaper; it was not done.
- **2,000 samples per search** (about 93 % to find a point at 1 in 750). Cost if wrong: one number to tune.

## Verified
- City suites 258 / 258 / 0, the new test included (Play, temporary server Script).
- **The fill, in Play at the city spawn plaza** (player held in place, heat topped to 5 every 0.5 s):
  - before the fix: 1 officer in 60 s;
  - after it: the first officer at 1.0 s and all 10 by 5 s, in one round with 10 path checks; 10 held to 45 s.
  - An intermediate run with 400 samples per search got 5 officers in 30 s, with 6 of 11 searches missing; that is why the count is 2,000.
- **Cost:**
  - one 2,000-sample miss took 0.68 s spread over frames, with a worst server step of 36 ms against a 28 ms baseline;
  - the 10-officer round had one 120 ms step, from building 10 officers in one round (that happened before this change too).
- The exports in `CityScripts/` match Studio by Adler-32 (Constants 3,331 bytes, PoliceDispatcher 21,708, PoliceSpawnPoint_Test 7,231).

## Not verified
- The Bank and NewsStation alarm fills were not timed again (that code path changed only by the shared budget).
- The heist suite was not run (it does not load the dispatcher).
- Not checked on a phone, or with two players.

## Left open
- Building 10 officers in one round makes one server step of about 120 ms. Spreading the builds over frames would remove it if it shows up in a playtest.
- NOT saved (no word to save this run). NOT published.

## Links
[[Police and Wanted]] [[Open Items]] [[2026-11-17 Police and Wanted]]
