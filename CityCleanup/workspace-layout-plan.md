# Workspace layout plan (dry run, nothing changed)

Place: `Crimelife city.rbxl` (Edit). Measured with execute_luau. Workspace instance count was 118,672 at start of every probe and at the end (unchanged).

## 1. Totals
- Top-level children now: **382**
- Workspace descendants now: **118,672**

## 2. Rules (first match wins; per-rule counts sum to 382)

| Rule | Destination | Top-level children | Instances (incl. self + descendants) | Examples |
|---|---|---|---|---|
| `City` folder | Map.City (the existing folder, moved) | 1 | 25,554 | City |
| Robbery names (Bank, SlowFoods, Gas2Go, NewsStation, CasinoMain, WareHouse*) | Map.Robbery | 6 | 83,419 | Gas2Go, Bank, CasinoMain, WareHouseRobbery(NotUnderGroundPart), NewsStation, SlowFoods |
| CityHighway1, Highway2, Asphalt UnionOperation | Map.Roads | 3 | 1,798 | CityHighway1, Highway2, Union |
| Lapis 300x1x361 Part | Plots (Model) | 8 | 8 | Part x8 (all named "Part") |
| Terrain, Camera, SpawnLocation, Baseplate | stay | 4 | 6 | Terrain, Baseplate, Camera, SpawnLocation |
| Model (name ~= "Model") occurring >=5 times | Map.Props | 141 | 2,063 | Palm_1 x64, Light x41, TriangleOutside x14, Arrow x12, ATM x5, Rig x5 |
| New rule: Model/Folder named Rig, Dummy, ATM, Light, Lights, OutsideLights | Map.Props | 3 (more, see 7) | 415 | Dummy, OutsideLights, Lights |
| Tiny folders (TerrainGraph, KinqAndi - Low Poly Terrain, Moving Platform Folder...) | Map.Loose | 3 | 6 | each x1 |
| Everything else | Map.Loose | 213 | 5,403 | Model x138, Part x51, CreatedByBB x8, Wedge x3, Arches x3, ConcreteWall x3, Wall, ThreeDTextObject, Bunker, SurfaceLight, Decpration1Major, x6m |

Totals by destination: City 1 / 25,554; Robbery 6 / 83,419; Roads 3 / 1,798; Props 144 / 2,478; Loose 216 / 5,409; Plots 8 / 8; stay 4 / 6. Sum 382 children, 118,672 instances.

Note: ATM x5 and Rig x5 are caught by the 5+ rule before the new named rule (same destination, Props). The named rule really only catches Dummy, OutsideLights, Lights.

## 3. Map.Loose in detail (216 children, 5,409 instances)

Histogram (name | class | count | summed instances):

| Name | Class | Count | Instances |
|---|---|---|---|
| Model | Model | 138 | 3,353 |
| x6m | Model | 1 | 949 |
| Decpration1Major | Model | 1 | 723 |
| Barricade | Model | 1 | 157 |
| Part | Part | 51 | 51 |
| ConcreteWall | Model | 3 | 42 |
| Arches | Model | 3 | 42 |
| CreatedByBB | Part | 8 | 32 |
| Bunker | Model | 1 | 22 |
| ThreeDTextObject | Model | 1 | 19 |
| Wall | Model | 1 | 8 |
| KinqAndi - Low Poly Terrain | Folder | 1 | 3 |
| Wedge | WedgePart | 3 | 3 |
| SurfaceLight | Part | 1 | 2 |
| Moving Platform Folder (open for settings) | Folder | 1 | 2 |
| TerrainGraph | Folder | 1 | 1 |

20 largest individually (pos = bounding-box centre; size = bounding box):

| # | Name | Inst | Position | Size | What it is (from contents) |
|---|---|---|---|---|---|
| 1 | x6m | 949 | (-10.6, 4.0, 2516.4) | 8.5 x 6.1 x 17.5 | A vehicle (children Wheels, DriveSeat, Misc, Shadow; 184 Part, 154 Wedge, 80 MeshPart). |
| 2 | Model | 835 | (-243.9, 5.3, 566.5) | 8.3 x 10.5 x 6.9 | Shop shelving/display unit: 480 Part, 240 Decal, 72 Union (product boxes with decals). |
| 3 | Decpration1Major | 723 | (450.8, 12.0, 2301.8) | 20.6 x 107.5 x 98.3 | A big decoration/prop set (tall, 107 studs; 476 Part, 127 MeshPart, 106 sub-models). |
| 4 | Model | 307 | (-228.8, 1.8, 566.2) | 5.7 x 1.1 x 6.2 | Shop floor item cluster (216 Part, 72 Union). |
| 5 | Barricade | 157 | (1131.0, 3.6, 2309.0) | 24.3 x 3.1 x 84.3 | Long low barricade/fence (150 Part). |
| 6 | Model | 89 | (-228.9, 5.3, 566.5) | 10.5 x 8 x 3 | Shop counter/shelf piece (80 Part). |
| 7 | Model | 73 | (257.8, 4.3, 703.3) | 5.6 x 8.7 x 5.2 | Tree with bushes (LowPolyBush, MeshParts). |
| 8-13 | Model x6 | 62 each | around (-228, 4.4-5.2, 566.6) | 2.1 x 0.4 x 2.4 | Identical small decal-covered items (40 Decal, 20 Part), part of the same shop at (-228, 566). |
| 14 | Model | 56 | (257.3, 4.2, 715.4) | 3.5 x 8.4 x 4.0 | Tree (LargeTree, LowPolyBush). |
| 15 | Model | 43 | (257.8, 1.9, 699.4) | 3.6 x 3.8 x 3.4 | Bush group (LowPolyBush x16). |
| 16 | Model | 35 | (256.8, 4.4, 709.7) | 4.4 x 8.8 x 4.5 | Bush/tree. |
| 17-18 | Model x2 | 33 | (-227.2/-230.9, 8.2, 566.5) | 2.4 x 1.9 x 1.6 | Small part-only shop items. |
| 19 | Model | 33 | (207.2, 0.9, 666.9) | 2.4 x 1.9 x 1.6 | Same small item shape as 17-18, standing alone. |
| 20 | Model | 30 | (-565.2, 7.0, 2809.9) | 33 x 1.1 x 10 | Sign/3D text object (ThreeDTextObject children, MeshParts). |

Pattern: the unnamed "Model"s are mostly a shop interior cluster near (-228, 566), a tree/bush cluster near (257, 703), and various small props.

## 4. The eight plates (all Lapis, 300 x 1 x 361, rotated 0,90,0, all already Anchored, all currently named "Part")

Sorted by Z then X. Slab = |x|<=1024 and |z|<=1024.

| Current name | Position | Size | On slab | Proposed | PlotIndex | Spare | Nearest neighbour plate (studs) | BaseParts standing on it (y>0.5 above) |
|---|---|---|---|---|---|---|---|---|
| Part | (-425.5, 0.5, 1720) | 300,1,361 | no | Plot1 | 1 | false | 349.0 | 0 |
| Part | (-425.5, 0.5, 2069) | 300,1,361 | no | Plot2 | 2 | false | 349.0 | 0 |
| Part | (-15.5, 0.5, 2069) | 300,1,361 | no | Plot3 | 3 | false | 410.0 | 0 |
| Part | (786.8, 0.5, 2607.3) | 300,1,361 | no | Plot4 | 4 | false | 558.5 | 0 |
| Part | (663.5, 0.5, 3152) | 300,1,361 | no | Plot5 | 5 | false | 349.0 | 1 (from City) |
| Part | (663.5, 0.5, 3501) | 300,1,361 | no | Plot6 | 6 | false | 349.0 | 0 |
| Part | (720.5, 0.5, -207) | 300,1,361 | yes | Plot7 | 7 | true | 470.2 (the other slab plate) | 67 (all inside `City`) |
| Part | (544.5, 0.5, 229) | 300,1,361 | yes | Plot8 | 8 | true | 470.2 (the other slab plate) | 3 (all inside `City`) |

Six on the city, two on the slab, confirmed. Spare = true on exactly Plot7 and Plot8. Nearest-neighbour for the slab plates is each other (470.2); the city plates' neighbours are city plates.

Standing on plates: the 67 and 3 parts on the slab plates are inside `Workspace.City` (that is, leftover City parts sitting at the slab, 70 parts); Plot5 has 1 City part on it. Moving the plates to `Plots` does not move those parts.

## 5. Roads

| Item | Class | Material | Instances | Position |
|---|---|---|---|---|
| CityHighway1 | Model | (model) | 974 | (762.0, 21.7, 3179.7) |
| Highway2 | Model | (model) | 823 | (-985.3, 10.4, 1844.1) |
| Union | UnionOperation | Asphalt | 1 | (1098.6, 0.5, 2389.5) |

Asphalt UnionOperations: **1 at top level, 8 inside City** (the 8 stay in City; the rule is top-level only).

## 6. Anchoring preview

Parts under the future Map that are unanchored (plates and stay-items excluded): **385** of 97,899 BaseParts in Workspace. By top-level ancestor: ATM 210, Rig 63, Model 60, Part 19, City 18, Dummy 15. Robbery and Roads have none.

## 7. Ambiguities and oddities
- ATM x5 and Rig x5 match both the 5+ rule and the new named rule (same destination, no conflict). A single `Light` appears 41 times (also named-rule). All of these are Props.
- All 8 plates share the name "Part"; matching depends on BrickColor Lapis + size, which matched exactly 8.
- Plots was assumed to be a Model, per ruling; stray Parts standing on the two slab plates (70, inside `City`) and Plot5 (1) are not moved with plates.
- `Barricade` (157, single instance), `x6m` (vehicle, 949) and `Decpration1Major` (723) land in Loose by default; they are named and large, reviewer may prefer Props (or Vehicles).
- 138 unnamed `Model`s and 51 `Part`s go to Loose (3,353 and 51 instances).
- The Asphalt `Union` at top level, hence Roads, is a single piece; the other 8 Asphalt unions inside City are not moved.
- CreatedByBB x8 (Part, 4 instances each) and the three tiny folders go to Loose.

## Applied (2026-11-14)

Reviewer rulings applied: `x6m`, `Decpration1Major` and `Barricade` went to Map.Props; City parts on the slab plates stayed in `Map.City`; Plots is a Model with no PrimaryPart.

| Destination | Children | Instances |
|---|---|---|
| Map.City (existing folder moved) | 1 | 25,554 |
| Map.Robbery | 6 | 83,419 |
| Map.Roads | 3 | 1,798 |
| Map.Props | 147 | 4,307 |
| Map.Loose | 213 | 3,580 |
| Plots (Model) | 8 | 8 |
| stay (Baseplate, Terrain, Camera, SpawnLocation) | 4 | 6 |

Plates: Plot1..Plot6 are the six city plates sorted by Z then X; Plot7 (720.5, 0.5, -207) and Plot8 (544.5, 0.5, 229) are the slab plates with Spare = true; PlotIndex 1..8; all anchored. City parts standing on the slab plates (not touched): 67 on Plot7, 3 on Plot8, 70 in all; 1 on Plot5.

Anchoring: 385 unanchored BaseParts under Map set to Anchored = true (of 97,888). Nothing destroyed, no CFrame touched. Result recorded in `after-task5.md`: top-level children 6, unanchored 0, workspace_instances 118,678 (118,672 + 6 containers).
