# Task 3 duplicates: proposed verdicts (Steps 1-2, nothing changed in the place)

Measured 2026-11-14 on `Crimelife city.rbxl`, Workspace = 262,040 instances. Child index = position in `workspace:GetChildren()` (1-based). Centre and size = `Model:GetBoundingBox()`. Distances are 3D, in studs.

City folder centre (union of part AABBs under `Workspace.City`, rotation aware): **(64.86, 181.28, 1719.19)**, size 3043 x 416 x 4152. `Baseplate` at (0,-8,0), 2048 x 16 x 2048. `on_staging_slab` = |x| <= 1024 and |z| <= 1024.

| group | model name | child idx | instances | centre (x, y, z) | size | on_staging_slab | dist to other copy | dist to City centre | verdict | reason |
|---|---|---|---|---|---|---|---|---|---|---|
| Gas2Go | Gas2Go | 75 | 6407 | -982.39, 18.69, 1988.07 | 101.2 x 38.9 x 163.9 | no | 2281.1 | 1093.4 | keep | nearer City centre, in the city |
| Gas2Go | Gas2Go | 80 | 6407 | -470.89, 19.44, -234.93 | 101.2 x 38.9 x 163.9 | yes | 2281.1 | 2032.7 | quarantine | 50+ apart, farther, on slab |
| CasinoMain | CasinoMain | 95 | 3891 | -702.90, 114.90, 2789.89 | 307.7 x 264.2 x 300.6 | no | 3129.7 | 1319.2 | keep | nearer City centre, in the city |
| CasinoMain | CasinoMain | 388 | 3987 | 81.95, 113.90, -239.76 | 307.7 x 264.2 x 300.6 | yes | 3129.7 | 1960.2 | quarantine | 50+ apart, farther, on slab (the slab copy has MORE instances, 3987 vs 3891; see odd) |
| NewsStation | NewsStation | 99 | 6434 | -596.00, 74.06, 1054.79 | 180.0 x 150.1 x 175.6 | no | 1332.8 | 943.2 | keep | nearer City centre, in the city |
| NewsStation | NewsStation | 271 | 6434 | -872.71, 75.06, -249.00 | 180.0 x 150.1 x 175.6 | yes | 1332.8 | 2182.7 | quarantine | 50+ apart, farther, on slab |
| SlowFoods | SlowFoodsB | 236 | 6399 | 78.63, 37.14, 1753.85 | 232.3 x 81.5 x 177.3 (rotated 90 deg) | no | 2058.9 | 148.9 | keep | nearer City centre, in the city; keeps the name `SlowFoodsB`, Task 5 may rename |
| SlowFoods | SlowFoods | 116 | 6000 | -332.66, 40.76, -263.50 | 177.3 x 81.5 x 233.0 | yes | 2058.9 | 2027.0 | quarantine | 50+ apart, farther, on slab (counts differ 6.2%, inside the 10% rule) |
| WareHouseRobbery | WareHouseRobbery(NotUnderGroundPart) | 125 | 56397 | -32.27, 31.50, 3151.13 | 252.25 x 65.00 x 429.54 | no | 3570.5 | 1443.0 | keep | nearer City centre, in the city |
| WareHouseRobbery | WareHouseRobbery(NotUnderGroundPart) | 149 | 56295 | -648.88, 31.50, -365.77 | 252.25 x 65.00 x 429.54 | yes | 3570.5 | 2208.8 | quarantine | 50+ apart, farther, on slab |
| Bank | Bank | 347 | 3891 | 1217.75, 220.76, 2342.00 | 132.5 x 438.0 x 162.0 | no | 2908.2 | 1311.0 | keep | nearer City centre, in the city |
| Bank | Bank | 269 | 3893 | -173.75, 219.01, -211.75 | 132.5 x 438.0 x 162.0 | yes | 2908.2 | 1946.0 | quarantine | 50+ apart, farther, on slab |
| Crime Band | Crime Band | 586 | 632 | 633.67, 7.42, 548.87 | 5.7 x 14.7 x 12.7 | yes | 708.0 | 1312.8 | left for Task 4 | Review gate: both on slab among loose tycoon pieces, handled by Task 4 |
| Crime Band | Crime Band | 1362 | 632 | 870.66, 7.11, -118.27 | 5.7 x 14.7 x 12.7 | yes | 708.0 | 2013.9 | left for Task 4 | Review gate: both on slab among loose tycoon pieces, handled by Task 4 |
| Dummy | Dummy | 544 | 694 | 630.20, 2.70, 447.10 | 4 x 5 x 1 | yes | n/a | n/a | quarantine | test rig (brief rule) |
| Dummy | Dummy | 668 | 694 | 483.50, 4.50, 203.00 | 4 x 5 x 1 | yes | n/a | n/a | quarantine | test rig |
| Dummy | Dummy | 715 | 694 | 733.00, 4.50, -134.50 | 4 x 5 x 1 | yes | n/a | n/a | quarantine | test rig |
| Dummy | Dummy | 1010 | 694 | 830.50, 4.50, -171.00 | 4 x 5 x 1 | yes | n/a | n/a | quarantine | test rig |
| AI Dummy | AI Dummy | 543 | 13945 | 597.50, 2.70, 497.00 | 4 x 5 x 1 | yes | n/a | n/a | quarantine | test rig, 13,945 instances |

(Dummy distance columns are not needed: the rule is all quarantine.)

Ties/rules applied: every "keep" in the seven distance-rule groups is both off the slab and nearer the City centre, so the slab tie-break was never needed except Crime Band where both are on the slab. No pair is under 50 studs apart (smallest: Crime Band 708), so the "destroy the copy with fewer instances" rule applies to nothing; every non-kept copy is quarantined, none destroyed.

## Proposed totals
- keep: 6 (Gas2Go 75, CasinoMain 95, NewsStation 99, SlowFoodsB 236 (renamed SlowFoods after quarantine), WareHouse 125, Bank 347)
- quarantine: 11 (6 slab copies + 4 Dummy + AI Dummy)
- left for Task 4: Crime Band x2 (review gate)
- destroy: 0
- instances proposed to leave Workspace: 6407 + 3987 + 6434 + 6000 + 56295 + 3893 + 4 x 694 + 13945 = **99,737** (Workspace 262,040 -> about 162,303)

## Odd / for the reviewer
1. **Crime Band**: both copies are on the staging slab (586 at z 549, 1362 at z -118). Verdict follows the distance rule (nearer City centre), but neither is in the city. Likely both are stray props; reviewer may prefer quarantining both, or keeping both and deferring to the props task. 632 instances each.
2. **CasinoMain**: the copy on the slab (388) has 96 more instances than the city copy (95): 3987 vs 3891. Same size. Kept the city copy per the slab rule; reviewer may want to compare content (the slab one may be the newer one). Also `UnderGroundCasino` (4349) is a different model, not touched.
3. **SlowFoods / SlowFoodsB**: the kept copy is `SlowFoodsB` (the city copy); the quarantined is the plain `SlowFoods`. Footprint is the same building rotated 90 deg. Instance counts differ 6.2%.
4. **No groups with three or more copies** among 300+ instance models, except the 4 `Dummy`.
5. **Both copies inside the city**: none. Every group has exactly one slab copy except Crime Band (both) and the Dummies.
6. **Size differences over 10%**: none among the pairs; all pairs have identical bounding sizes.
7. **Further scan** of all 1863 Workspace children with 300+ instances (names stripped of trailing B/digits, counts within 10%): no other Model pairs. Not reported as duplicates: three `Decoration` Folders (idx 831, 927, 969; 377 / 375 / 376 instances) are Folders, not buildings, left for the props task. The unnamed `Model` entries (idx 26: 8530, 118: 2284, 301: 307, 328: 835) have no counterpart within 10%. `Shelf1`/`Shelf3`, `CityHighway1`/`Highway2` differ by far more than 10% or by name.
8. `Workspace.City.Robberies` (4 children) and `Workspace.City.WorkingOn` are empty of parts; the robbery buildings all sit at the top level of Workspace, as expected for Task 5.
9. City centre uses part AABBs (not nested model boxes), and `Roads` reaches z = -357, which nudges the centre slightly south. The verdicts hold with a wide margin (nearest margin: Crime Band, which is slab vs slab).
10. Screenshots: `CityCleanup/screenshots/task3-slab-aerial.jpg` (camera 0,1500,1500 to origin) and `task3-city-aerial.jpg` (camera 65,1800,400 to 65,0,1900). Copies are not highlighted (read-only leg).
