# Robbery locations: survey and proposed transforms (first half, PROPOSAL)

Measured 2026-11-16, read-only in both windows (queries only; Play touched neither place). Robbery = `Robbery System.rbxl`, city = `Crimelife city.rbxl`. Every number below came from a call made in this run; "not recorded" where none was made. The rows under "Proposed transform" are what the gate rules on; the second half of this file (applied results) is written by Tasks 2 and 3.

## 1. Robbery root sets (Step 5)

Combined world bounding box of every BasePart under the set's roots (oriented-box corners, so rotated parts count correctly). Entrance = the location's exit spawn (`*ExitSpawn` tag, the point a banked player returns to); entrance floor = raycast down from the spawn centre with the spawn itself excluded.

| Location | Root set (Workspace) | Parts | X range | Y range | Z range | Footprint X x Z | Footprint centre (X, Z) | Entrance (exit spawn) | Entrance floor |
|---|---|---|---|---|---|---|---|---|---|
| Bank | `Bank`, `BankVault`, `HeistZones`, `HeistMarkers` | 3313 + 5449 + 6 + 13 | 95.4 .. 366.8 | -8.0 .. 438.0 | -218.0 .. 164.0 | 271.4 x 382.0 | (231.1, -27.0) | (98.4, 0.5, -149.2) | 0.000 (`Workspace.Baseplate`) |
| SlowFoods | `SlowFoods`, `SlowFoodsZones`, `SlowFoodsMarkers` | 5218 + 2 + 2 | -46.3 .. 186.7 | 0.0 .. 79.0 | -379.8 .. -202.5 | 233.0 x 177.3 | (70.2, -291.2) | (45.0, 7.0, -273.0) | 2.062 (`SlowFoods.Exterior.Model.Part`) |
| Gas2Go | `Gas2Go`, `Gas2GoZones`, `Gas2GoMarkers` | 5393 + 2 + 2 | -155.6 .. -53.9 | 0.0 .. 38.2 | -360.5 .. -195.9 | 101.7 x 164.6 | (-104.8, -278.2) | (-100.8, 1.54, -257.4) | 1.039 (`Gas2Go.Platform.Part`) |
| NewsStation | `NewsStation`, `NewsStationZones`, `NewsStationMarkers` | 5486 + 2 + 2 | -369.0 .. -193.4 | 0.0 .. 149.1 | -389.0 .. -209.0 | 175.6 x 180.0 | (-281.2, -299.0) | (-215.0, 7.0, -317.0) | 1.000 (`NewsStation.Outdoor Parking.Part`) |

Individual roots (Robbery): `Bank` x 97.0..239.5, z -194.0..-32.0 (142.5 x 162.0); `BankVault` x 275.2..366.8, z -197.0..164.0 (91.6 x 361.0); `HeistZones` x 100.1..366.0, z -218.0..163.0, y -8.0..82.0; `HeistMarkers` x 95.4..338.6, y 0..136.9. The `StatusBillboardAnchor`s float at y 136.4 (Bank), 62.8 (SlowFoods), 48.0 (Gas2Go), 57.0 (NewsStation).
Not in any set: `Illegal Supplier` (about (109.9, 4.9, -339.0), 4.0 x 5.2 x 1.5; see G11 in `classification.md`), `Baseplate`, `SpawnLocation`, `Animation Tool`.

## 2. City counterparts (`Workspace.Map.Robbery`)

| Counterpart | Parts | X range | Y range | Z range | Footprint X x Z | Centre (X, Z) | Pivot |
|---|---|---|---|---|---|---|---|
| Bank | 3284 | 1151.5 .. 1284.0 | 1.8 .. 439.8 | 2261.0 .. 2423.0 | 132.5 x 162.0 | (1217.8, 2342.0) | (1217.8, 220.8, 2342.0) |
| SlowFoods | 5404 | -10.0 .. 167.3 | -3.6 .. 77.9 | 1637.7 .. 1870.0 | 177.3 x 232.3 | (78.7, 1753.9) | (78.6, 37.1, 1753.9) |
| Gas2Go | 5390 | -1033.0 .. -931.8 | -0.8 .. 38.1 | 1906.1 .. 2070.0 | 101.2 x 163.9 | (-982.4, 1988.1) | (-982.4, 18.7, 1988.1) |
| NewsStation | 5440 | -686.0 .. -506.0 | -1.0 .. 149.1 | 967.0 .. 1142.6 | 180.0 x 175.6 | (-596.0, 1054.8) | (-596.0, 74.1, 1054.8) |

`CasinoMain` and `WareHouseRobbery(NotUnderGroundPart)` stay as art. The four twins are the same buildings as the Robbery art: after the proposed transform, 3228 of 3313 (Bank), 5064 of 5218 (SlowFoods), 5351 of 5393 (Gas2Go) and 5404 of 5486 (NewsStation) Robbery parts have a city part of the same size within 1 stud horizontally and 1.5 vertically (the matched offsets spread under 3.0 studs on every axis).

City ground at the transformed entrance (raycast down from the transformed exit-spawn height, collidable parts only, parts with Transparency >= 0.95 skipped):

| Location | Transformed entrance | Ground, twin present | Ground, twin excluded |
|---|---|---|---|
| Bank | (1142.9, 2.25, 2305.8) | 2.000 (`Map.City.FootPaths.Union`) | 2.000 (same) |
| SlowFoods | (96.8, 5.94, 1778.8) | 1.000 (`SlowFoods.Part`, the twin's floor) | none |
| Gas2Go | (-986.6, 1.50, 1967.6) | 1.000 (`Gas2Go.Part`, the twin's floor) | none |
| NewsStation | (-614.0, 7.00, 988.6) | 1.000 (`NewsStation.Part`, the twin's floor) | 0.000 (`Ground.Baseplate`) |

## 3. Proposed transform per location

Each location's whole root set is moved with one transform: `CFrame.new(tx, ty, tz) * CFrame.Angles(0, math.rad(yaw), 0) * partCFrame` (rotation about the world origin, then translation; equal to a rotation about the set's footprint centre followed by a translation). Verified read-only in the city: the transformed set's bounding box equals the twin's on every axis within the differences below.

Rule fit = sum of the X and Z extent differences between the rotated set footprint and the twin footprint (rotated set X x Z against twin X x Z), per yaw:

| Location | Yaw 0 / 180 | Yaw 90 / 270 | Proposed yaw | (tx, ty, tz) | Transformed set X x Z | Twin X x Z | Difference X / Z | Fit (limit 20 per axis) |
|---|---|---|---|---|---|---|---|---|
| SlowFoods | 110.7 | 0.7 | **90** (270 ties) | (369.771, -1.062, 1823.750) | 177.3 x 233.0 | 177.3 x 232.3 | 0.0 / +0.7 | fits |
| Gas2Go | 1.2 | 125.6 | **180** (0 ties) | (-1087.400, -0.039, 1710.200) | 101.7 x 164.6 | 101.2 x 163.9 | +0.5 / +0.7 | fits |
| NewsStation | 8.8 | 0.0 | **90** (270 ties) | (-297.000, 0.000, 773.600) | 180.0 x 175.6 | 180.0 x 175.6 | 0.0 / 0.0 | fits |
| Bank | 358.9 | 358.9 | **0** (all four tie; G2) | (1044.500, +1.750 registration or +2.000 rule, 2455.000) | 271.4 x 382.0 | 132.5 x 162.0 | +138.9 / +220.0 | **does not fit: gate (G1)** |

How yaw and translation were derived: the rule leaves ties (SlowFoods and NewsStation 90/270, Gas2Go 0/180, Bank all four); each tie was broken by registering the Robbery building art onto its twin (yaws 0, 90, 180, 270; translation found by voting over the 400 largest parts, then refined over all parts; median offsets above). Translation by the brief's rule (set footprint centre onto twin centre) differs from the registration by, in (X, Z): SlowFoods (+0.03, +0.30), Gas2Go (+0.25, -0.35), NewsStation (0.00, 0.00), Bank (-57.9, -86.0) (G3). Centres computed from the 0.1-rounded boxes above. Vertical: the rule (entrance floor onto city ground) gives SlowFoods -1.062, Gas2Go -0.039, NewsStation 0.000 (equal to the registration) and Bank +2.000 (registration +1.750).

The twin is then moved to `ServerStorage.CityQuarantine.ReplacedByHeist` with `OriginalCFrame`, `OriginalParent`, `OriginalPath` (Tasks 2 and 3; not done here).

## 4. Fit after the transform (Step 5)

Method: every part of the set (art = the main models and `BankVault`; volumes = the `*Zones` and `*Markers` folders) transformed by the proposal above; `workspace:GetPartBoundsInBox(transformed CFrame, size - 0.2 per axis)` with the twin excluded; distinct city parts counted by group. Face contact does not count (0.1 stud shrink per side). The twin's own parts queried the same way give the baseline in the last column.

| Location | Class | City parts hit, by group (distinct parts) | Twin's own overlaps (same query) |
|---|---|---|---|
| SlowFoods | art | `Map/City/Buildings` 30, `Map/City/FootPaths` 10, `Map/City/Lights` 12, `Map/City/BaseBricks` 3 | Buildings 30, FootPaths 11, Lights 12, BaseBricks 3, Roads 1 |
| SlowFoods | volumes | none | n/a |
| Gas2Go | art | Buildings 12, nature 38, Roads 2, FootPaths 1, `Map/Loose/CreatedByBB` 2, `Map/Loose/Part` 1 | the same counts |
| Gas2Go | volumes | nature 27, Buildings 12, FootPaths 2, BaseBricks 1, Roads 1, CreatedByBB 2, Loose Part 2 | n/a |
| NewsStation | art | Buildings 27 (e.g. `RestrictedArea.BlockerBlock`), BaseBricks 2, Roads 1, CreatedByBB 3 | Buildings 27, BaseBricks 2, Roads 1, CreatedByBB 3, `Ground` 1 |
| NewsStation | volumes | Roads 1, CreatedByBB 2 | n/a |
| Bank | art (`Bank` only) | Buildings 3, FootPaths 3, nature 6, CreatedByBB 3, `Props/Lights` 5, `Props/OutsideLights` 4 | the same counts |
| Bank | **`BankVault` (new ground)** | `Map/City/Buildings` **33** (e.g. `UpperCity.Building_104`), Roads 1, nature 9, `Props/Palm_1` 3 | none: the twin has no vault |
| Bank | volumes | Buildings 48, nature 13, FootPaths 1, Roads 2, CreatedByBB 3, `Props/OutsideLights` 2, `Props/Palm_1` 4 | n/a |

Reading: SlowFoods, Gas2Go and NewsStation add no intersection that the twin does not already have (counts equal; SlowFoods one FootPaths part and one Roads part fewer). The overlaps are against `Map.City.Buildings` neighbours and the like that the existing art already touches. Only the Bank vault adds new intersections. Not recorded: the same check for the Bank at the set-centre translation (G3), and any test beyond bounding-box overlap (per-part collision, raycasts).

Plots (8), quest givers (6) and enemy spawn points (6) within 120 studs (XZ distance from the transformed set box): **none, for all four**. Distance to the city spawn (`Workspace.SpawnLocation`, (-11, 2, 2499)):

| Location | Transformed set box | To spawn, box edge | To spawn, centre |
|---|---|---|---|
| SlowFoods | x -10.0..167.3, y -1.1..77.9, z 1637.0..1870.0 | 628.8 | 750.6 |
| Gas2Go | x -1033.5..-931.8, y 0.0..48.5, z 1906.1..2070.7 | 1015.4 | 1097.5 |
| NewsStation | x -686.0..-506.0, y 0.0..149.1, z 967.0..1142.6 | 1443.7 | 1558.0 |
| Bank (whole set) | x 1139.9..1411.3, y -6.2..439.8, z 2237.0..2619.0 | 1150.9 | 1288.5 |
| Bank (`BankVault` only) | x 1319.7..1411.3, y 1.7..103.8, z 2258.0..2619.0 | not recorded | not recorded |

## 5. Absolute coordinates in Robbery scripts (Step 5)

Scan of every script (server, client, tests, tools) for `Vector3.new(` / `CFrame.new(` calls with three or more numeric literals and nothing else inside, plus a read of `WorldSpec`:

| Script, line | Literal | Kind | Proposed value under the location's T | Gate picks |
|---|---|---|---|---|
| `ServerScriptService.SlowFoodsServer` 198 | `openCFrame = CFrame.new(131.888, 6.062, -293.044) * CFrame.Angles(0, math.rad(180), 0)` | world, `LockedDoor` open pose | (76.727, 5.000, 1691.862), yaw 270 (-90) | transform in script or lookup (G12) |
| `ServerScriptService.Gas2GoServer` 252 | `openCFrame = CFrame.new(-111.893, 5.539, -337.486) * CFrame.Angles(0, math.rad(90), 0)` | world, `LockedDoor` open pose | (-975.507, 5.500, 2047.686), yaw 270 (-90) | G12 |
| `ServerScriptService.NewsStationServer` 276 | `openCFrame = CFrame.new(-231.65239, 17.775013, -375.499969) * CFrame.Angles(0, math.rad(-45), 0)` | world, `LockedDoor` open pose | (-672.500, 17.775, 1005.252), yaw 45 | G12 |
| `ServerScriptService.SuppliesServer` 69 | `root.CFrame * CFrame.new(0, 0, -2)` | relative | none needed | n/a |
| `ServerScriptService.Heist.Services.DuffelBagAttachment` 32 | `CFrame.new(0, -0.3, 0.65) * CFrame.Angles(0, math.rad(180), 0)` | relative to the torso | none | n/a |
| `ServerScriptService.Heist.Tests.*` (GateSpec, AccessSpec, C4Spec, NPCSpawnManagerSpec, VaultDoorSpec, SupplyObjectSpec, CarryStateSpec, LockedDoorSpec, DuffelSpec, ForfeitSpec, DuffelBagAttachmentSpec; 48 lines) | fixture positions near the origin | local to the test | none | n/a |
| `StarterPack.tommy gun.*` (1 line) | gun script | left behind | n/a | n/a |

`HeistClient` and every other client script: no such literal found by this scan (a call with a variable or expression argument would not be found). The `LockedDoor` closed pose is read from the door part at runtime; `Gate` `OpenOffset` is applied as `closed * CFrame.new(offset)` (the part's own space). `WorldSpec` (51 cases) contains no world coordinate: it asserts tag counts, parent paths (`workspace.Bank`, `BankVault`, `SlowFoods`, `Gas2Go`, `HeistMarkers`, `HeistZones`), distances relative to a model's own pivot, local-space containment of parts in zone volumes, and one floor raycast (from 0.5 above each zone's bottom, 6 studs down: a floor must exist under every zone). After import that assertion needs city ground or a building floor under each transformed zone; for the Bank vault zones that is not given (G1).
