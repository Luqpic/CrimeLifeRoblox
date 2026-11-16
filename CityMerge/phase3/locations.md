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

## 6. Applied results (Task 3, 2026-11-16)

Second half: what was applied in `Crimelife city.rbxl` (Edit), measured in this run. Every root imported unparented with `CityMerge/transfer/import.luau`'s `import`, moved, then parented to `Workspace` at top level under its own name, one root at a time. A Model moved with `PivotTo(T * GetPivot())`; a Folder's children one by one with the same `T` (`T = CFrame.new(tx, ty, tz) * CFrame.Angles(0, math.rad(yaw), 0)`, gate G2 / G3 values, equal to section 3).

### 6.1 Placement

Planned box = the Robbery set's parts transformed by `T` (computed in the Robbery place, read only); placed box = the same parts read back in the city. Box = axis-aligned box of every BasePart's oriented extents.

| Location | Roots | yaw / (tx, ty, tz) | Parts | Placed box (min .. max) | Centre planned | Centre placed | Off |
|---|---|---|---|---|---|---|---|
| SlowFoods | `SlowFoods`, `SlowFoodsZones`, `SlowFoodsMarkers` | 90 / (369.771, -1.062, 1823.750) | 5,222 | (-10.000, -1.063, 1637.000) .. (167.259, 77.903, 1870.000) | (78.630, 38.420, 1753.500) | (78.630, 38.420, 1753.500) | 0.000 |
| `Illegal Supplier` (G11) | `Illegal Supplier` | SlowFoods T | 17 | n/a | (30.720, 3.847, 1713.800) | (30.720, 3.847, 1713.800) | 0.000 |
| Gas2Go | `Gas2Go`, `Gas2GoZones`, `Gas2GoMarkers` | 180 / (-1087.400, -0.039, 1710.200) | 5,397 | (-1033.500, -0.039, 1906.138) .. (-931.771, 48.461, 2070.700) | (-982.635, 24.211, 1988.419) | (-982.635, 24.211, 1988.419) | 0.000 |
| NewsStation | `NewsStation`, `NewsStationZones`, `NewsStationMarkers` | 90 / (-297.000, 0.000, 773.600) | 5,490 | (-686.000, 0.000, 967.000) .. (-506.000, 149.125, 1142.575) | (-596.000, 74.562, 1054.788) | (-596.000, 74.562, 1054.788) | 0.000 |
| Bank (Bank side) | `Bank` + 4 folder children (below) | 0 / (1044.500, 1.750, 2455.000) | 3,317 | (1139.900, 1.250, 2261.000) .. (1284.000, 439.775, 2423.000) | (1211.950, 220.512, 2342.000) | (1211.950, 220.512, 2342.000) | 0.000 |
| Bank (vault side) | `BankVault` + 15 folder children (below) | Bank T, then dy -147.750 | 5,464 | (1319.675, -154.000, 2237.000) .. (1411.300, -44.000, 2619.000) | (1365.488, -99.000, 2428.000) | (1365.488, -99.000, 2428.000) | 0.000 |

Entrance (exit spawn) floor: raycast down from the spawn centre, the spawn itself, parts with Transparency >= 0.95 and non-collidable parts skipped.

| Location | Exit spawn (placed) | City ground before quarantine (twin present, imports excluded) | Entrance floor after quarantine | Difference |
|---|---|---|---|---|
| SlowFoods | (96.771, 5.938, 1778.750) | 1.000 (`Map.Robbery.SlowFoods.Part`) | 1.000 (`SlowFoods.Exterior.Model.Part`) | 0.000 |
| Gas2Go | (-986.600, 1.500, 1967.600) | 1.000 (`Map.Robbery.Gas2Go.Part`) | 1.000 (`Gas2Go.Platform.Part`) | 0.000 |
| NewsStation | (-614.000, 7.000, 988.600) | 1.000 (`Map.Robbery.NewsStation.Part`) | 1.000 (`NewsStation.Outdoor Parking.Part`) | 0.000 |
| Bank | (1142.900, 2.250, 2305.800) | 2.000 (`Map.City.FootPaths.Union`) | 2.000 (the same footpath: the Robbery Bank has no floor of its own at its entrance) | 0.000; the spawn's bottom (1.750) sits 0.250 into the footpath (G3's stated cost) |

Quarantine: `Map.Robbery.SlowFoods` (6,398 descendants), `.Gas2Go` (6,406), `.NewsStation` (6,433), `.Bank` (3,890) now in `ServerStorage.CityQuarantine.ReplacedByHeist` (new Folder), each with `OriginalCFrame` (its pivot), `OriginalParent` (`Workspace.Map.Robbery`), `OriginalPath`. `Map.Robbery` keeps `CasinoMain` and `WareHouseRobbery(NotUnderGroundPart)`. The twins hold no scripts, no SpawnLocation; SlowFoods and Gas2Go carry `ThreeDTextObject` / `ThreeDTextObjectBoundingBox` tags (11 and 2), which no script in the place reads.

### 6.2 Bank vault (G1)

Split by centre (part position) inside the `BankVault` box in Robbery coordinates, padded 2: x 273.175 .. 368.800, y -2 .. 104, z -199 .. 166.

- With the vault (dy): `HeistZones.VaultZone`, `BankVaultZone1`, `BankVaultZone2`, `BankVaultZone3`; `HeistMarkers.CoverPoint1`..`6`, `GuardPost1`..`4`, `DeathVolume`; `BankVault` (holds `TeleporterBankB`).
- With the Bank: `HeistZones.BankZone` (lobby), `ClaimZone`; `HeistMarkers.ExitSpawn` (`HeistExitSpawn`), `StatusBillboardAnchor`; `Bank` (holds `TeleporterBankA`). Every teleporter and exit spawn landed on its own side.
- Lowest city geometry in the vault set's XZ box (x 1319.675 .. 1411.300, z 2237.000 .. 2619.000), searched y -600 .. 1000 with the imports excluded: BaseParts 295, lowest bottom -0.000 (`Map.City.Roads.Road`); Terrain 646 solid voxels, lowest voxel bottom -4. Target top -4 - 40 = -44; vault top before the drop 103.750: **dy = -147.750**.
- After the drop: `GetPartBoundsInBox` over the vault set's box, imports excluded: **0 city parts**; `ReadVoxels` over the box (grid-aligned y -156 .. -44): **0 solid voxels**. Vault floor `BankVault.Floor` at y -98.0 under `VaultZone`. Bottom -154.0 is above `FallenPartsDestroyHeight` (-500). `TeleporterBankA` (1268.75, 15.03, 2343.29), `TeleporterBankB` (1404.30, -117.50, 2294.57).
- `LinkedTeleporter` ObjectValues of both teleporters came in nil (cross-root references do not survive per-root serialization) and were re-linked.

### 6.3 Coordinates (Step 3)

G12 applied to `SlowFoodsServer` 198, `Gas2GoServer` 252, `NewsStationServer` 276 (values and checksums in `after-import.md`); each literal re-derived from its location's T equals the section 5 table within 0.0004 stud and the stated yaw. `WorldSpec`: no world coordinate (the floor probe at line 615 is relative to each zone); unchanged. The 5 `Vector3`/`CFrame` attributes in the 14 roots are `OpenOffset`s in the part's own space; unchanged.

### 6.4 Spawns (Step 2)

No SpawnLocation among the 14 roots (exit spawns are tagged Parts). Enabled SpawnLocations: `Workspace.SpawnLocation` only (`Workspace.Dev.DevSpawn` is disabled, as before).

### 6.5 Getaway (Step 4)

Horizontal distances from each `StatusBillboardAnchor`. Ring: 32 points at 200 studs, each raycast down from y 1000 with the location's own roots excluded (Transparency >= 0.95 skipped); clear = the hit is under `Map.City.Roads`, `Map.Roads`, `Map.City.FootPaths`, `Map.City.BaseBricks`, `Workspace.Ground`, a part named `Ground`, or Terrain, and the point is not inside the XZ box of any `Map.City.Buildings` child, `Map.Robbery` child, another location's main model or a plot (323 boxes).

| Location | Anchor | Other anchors | Nearest plot | City spawn | Nearest quest giver | Enemy points (min; all) | Ring clear | Other anchor within 200 |
|---|---|---|---|---|---|---|---|---|
| SlowFoods | (91.7, 61.7, 1723.8) | Gas2Go 1120, NewsStation 995, Bank 1278 | Plot3 362 | 782 | Level 1 Quest 766 | 779 (Thug 779, Offender 864, Disrupters 893, Saboteur 924, Smuggler 961, Bandits 1060) | 10 / 32 (12 no hit: past the map edge; canopies 4, plots 3, buildings 1, other 2) | none |
| Gas2Go | (-986.0, 48.0, 2028.2) | SlowFoods 1120, NewsStation 1050, Bank 2226 | Plot2 562 | 1083 | Level 70 Quest 980 | 743 (Saboteur 743, Disrupters 790, Offender 839, Smuggler 1172, Bandits 1230, Thug 1247) | 18 / 32 | none |
| NewsStation | (-631.5, 57.0, 1040.1) | SlowFoods 995, Gas2Go 1050, Bank 2253 | Plot1 710 | 1585 | Level 70 Quest 1527 | 1475 (Saboteur 1475, Disrupters 1485, Offender 1498, Thug 1664, Smuggler 1752, Bandits 1846) | 15 / 32 (6 no hit) | none |
| Bank | (1220.7, 138.1, 2323.6) | SlowFoods 1278, Gas2Go 2226, NewsStation 2253 | Plot4 518 | 1244 | Level 1 Quest 1275 | 1066 (Thug 1066, Smuggler 1282, Bandits 1313, Offender 1522, Disrupters 1581, Saboteur 1641) | **5 / 32** (UpperCity buildings 104 / 105 / 106 / 73 / 75 roofs, palms, canopies) | none |

For the controller: **Bank, 5 of 32 clear** (under 8; its `EscapeDistance` in `Config` is the knob, not changed here). No ring takes in another anchor.

### 6.6 Streaming (Step 5)

`Workspace.StreamingEnabled = true` (min 128, target 512). Every imported Model keeps its source `ModelStreamingMode` (`Default`). No Model holds a `StatusBillboardAnchor`: all four anchors are direct children of the `*Markers` / `HeistMarkers` Folders, so the Persistent rule changed nothing. Listed for Task 4's audit: the anchors stream as loose parts (the boot Play's client logs "has no StatusBillboardAnchor" for all four from the city spawn), and `Illegal Supplier` streams with `Default` (client `WaitForChild("Interaction")` infinite-yield warning).

Client at the city spawn, 25.1 s into Play: `game` descendants 106,177 (Task 1: 93,272 at 25.4 s), PlayerGui 28 children, PlayerScripts 33.
