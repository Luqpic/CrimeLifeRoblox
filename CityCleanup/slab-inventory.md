# Slab inventory (Task 4, leg 1: measure only, nothing moved)

Place: `Crimelife city.rbxl`, Edit. Measured by Luau read-only. Bounding extents use the axis-aligned bounding box (rotated models may be slightly under-reported).

## 1. Totals
- Top-level Workspace children: 1852
- Candidates (pivot |x|,|z| <= 1024, minus exclusions): 1498
- Summed instances of candidates (each child plus descendants): 41,963
- Workspace instances (descendants): 162,303 at start and at end (unchanged)

## 2. Histogram of candidates (237 distinct name+class; top 40 by summed instances)
name | class | count | instances | x range | z range
- Model | Model | 51 | 14215 | -801..877 | -691..733
- Rig | Model | 16 | 3326 | -500..854 | -590..768
- Shelf3 | Model | 1 | 2357 | -736 | -691
- Decoration | Folder | 11 | 1712 | 756..935 | -309..93
- SoundProofWalling | Model | 1 | 1441 | 652 | -110
- Shelf1 | Model | 3 | 1305 | -584..850 | -691..-166
- WareHouseP2 | Model | 1 | 1297 | -649 | 45
- Crime Band | Model | 3 | 1288 | 620..871 | -118..549
- Part | Part | 980 | 990 | -468..1022 | -668..718
- Tailor | Model | 2 | 430 | 574..578 | 569
- Sparkling Water | Model | 2 | 415 | 676..680 | 614..622
- Sparkling Speed Water | Model | 2 | 414 | 658..662 | 614..622
- Sparkling Power Water | Model | 2 | 413 | 640 | 614..626
- Desk1 | Model | 3 | 402 | 606..789 | -400..-325
- Desk2 | Model | 3 | 402 | 616..799 | -400..-325
- Titanium Scraps | Model | 2 | 351 | 640..643 | 597..601
- Diamond Scraps | Model | 2 | 350 | 675..676 | 589..601
- Graphite Scraps | Model | 2 | 350 | 658 | 589..601
- Scrap Worker | Model | 2 | 347 | 628..635 | 597
- Bartenders | Model | 2 | 325 | 572..581 | 556..558
- Lounge Decoration | Model | 2 | 303 | 685..703 | 547..551
- Inner Walls2 | Model | 1 | 254 | 667 | 577
- Inner Walls | Model | 3 | 215 | 625..665 | 482..538
- Diner Booths | Model | 2 | 207 | 577..622 | 522..544
- Stainless Scraps | Model | 2 | 191 | 632..635 | 597..601
- Gold Scraps | Model | 2 | 191 | 667 | 589..601
- Platinum Scraps | Model | 2 | 190 | 649..652 | 597..601
- Bar Foundation | Model | 2 | 187 | 571..577 | 556..557
- Tree Decoration | Model | 2 | 185 | 661..675 | 542..553
- MainHall Lights2 | Model | 1 | 180 | 647 | 537
- Plant3 | Model | 1 | 178 | 868 | -221
- CompterScreens | Model | 1 | 169 | 658 | -109
- MainHall Lights | Model | 3 | 165 | 652..665 | 504..546
- Boxes2 | Model | 2 | 159 | 691..702 | -104..635
- Bar Interior | Model | 2 | 148 | 558..577 | 551..552
- PotPlant1 | Model | 1 | 142 | 696 | -137
- PotPlant2 | Model | 1 | 142 | 697 | -154
- Chair | Model | 5 | 135 | 607..797 | -394..-320
- Side Walls | Model | 5 | 132 | 560..716 | 557..574
- Tailor Desk | Model | 2 | 132 | 574..579 | 565..570
(the rest are small: Conveyor 2.0 x2 = 68 instances, Dummy = 83 at (195,710), TycoonSpawn, etc.; the full 237-row list was measured but not tabulated here)

## 3. 30 largest candidates
name | instances | position (x,y,z) | bounding size
1. Model | 8530 | -149,51,36 | 92x102x361
2. Shelf3 | 2357 | -736,19,-691 | 12x39x75
3. Model | 2284 | -660,20,-691 | 11x40x75
4. SoundProofWalling | 1441 | 652,9,-110 | 27x18x18
5. WareHouseP2 | 1297 | -649,30,45 | 284x167x350
6. Shelf1 | 1263 | -584,19,-691 | 11x39x75
7. Model | 835 | -244,5,566 | 8x10x7
8. Crime Band | 632 | 634,7,549 | 6x15x13
9. Crime Band | 632 | 871,7,-118 | 6x15x13
10. Tailor | 406 | 578,21,569 | 12x5x5
11. Sparkling Water | 390 | 676,10,614 | 127x11x81
12. Sparkling Speed Water | 389 | 658,10,614 | 105x11x85
13. Sparkling Power Water | 388 | 640,10,614 | 93x11x81
14. Decoration (Folder) | 377 | 935,7,92 | 12x10x21
15. Decoration (Folder) | 376 | 915,7,93 | 8x10x25
16. Decoration (Folder) | 375 | 900,7,92 | 13x10x21
17. Titanium Scraps | 326 | 643,4,597 | 70x9x87
18. Diamond Scraps | 325 | 676,10,589 | 27x9x83
19. Graphite Scraps | 325 | 658,10,589 | 52x9x75
20. Scrap Worker | 322 | 635,4,597 | 86x9x92
21. Model | 307 | -229,2,566 | 6x1x6
22. Bartenders | 301 | 572,5,558 | 17x6x15
23. Lounge Decoration | 279 | 703,9,547 | 23x16x22
24. Inner Walls2 | 254 | 667,26,577 | 183x18x158
25. Model | 231 | 858,8,-163 | 18x12x4
26. Model | 231 | 877,8,-159 | 18x12x4
27. Rig | 218 | 618,0,-394 | 4x6x2
28. Rig | 212 | -500,0,-450 | 4x6x2
29. Rig | 212 | -253,0,578 | 4x6x2
30. Rig | 212 | 660,2,-242 | 4x6x2

Note: pivots of several models (size 4x6x2 etc.) are not their bbox centre, so size is only the part-bounds.

## 4. Not candidates but on the slab
- Baseplate | Part | 2 instances | 0,-8,0 | 2048x16x2048
- Terrain | Terrain (a BasePart subclass, its pivot is at origin) | 1 | 0,0,0 | excluded by name
- UnderGroundCasino | Model | 4349 | 195,38,40 | 70x77x374 | straddler by name (bbox does not actually exceed the slab; kept out by the ruling, reviewer decides)
- Lapis plate (300x1x361) | Part | 1 | 544,0,229
- Lapis plate (300x1x361) | Part | 1 | 720,0,-207
- SpawnLocations: only `TycoonSpawn` is on the slab (listed as candidate). No other SpawnLocation on the slab.
- Kept robbery buildings on slab: none (no anomaly). `Gas2Go`, `CasinoMain`, `SlowFoods`, `WareHouseRobbery(NotUnderGroundPart)`, `Bank` were not on the slab by pivot. `NewsStation` is just outside (see 5).
- Straddlers by bounding box (beyond slab by more than 100): none found. `CityHighway1`, `Highway2` do not have a pivot on the slab.
- Also not on the slab by pivot (no position): folders `TerrainGraph`, `KinqAndi - Low Poly Terrain`, `Moving Platform Folder (open for settings)` (all empty or tiny, 1/3/2 instances) and `Camera`.

## 5. Just outside (1024 < |x| or |z| <= 1324)
- Part | Part | 12 | 12 instances | first at 1043,18,-326
- CreatedByBB | Part | 1 | 4 | -684,3,1100
- NewsStation | Model | 1 | 6434 | -596,74,1055 (kept robbery building, does not need to move)
- ATM | Model | 1 | 51 | 13,5,1182
The slab edge cuts through nothing large: only 12 loose Parts at x~1043 (just outside) and a stray `CreatedByBB`/ATM.

## 6. City folder vs slab
City has 25,553 instances, 17,689 BaseParts. BaseParts with |x| <= 1024 and |z| <= 1024: 1,063. By sub-folder: Buildings 637, nature 96, FootPaths 74, Advertisement 64, Fences/Borders 63, Props 39, Lights 36, Roads 31, BaseBricks 23. So the southern edge of the city overlaps the slab (visible in screenshot 1, bottom-left corner). The rule leaves City untouched.

## 7. SpawnLocations
- Workspace.SpawnLocation at (-11, 2, 2499) (the real spawn, north end)
- Workspace.TycoonSpawn at (645, 4, 557) (a candidate to move)

## Screenshots
- task4-slab-before-1.jpg (from 0,1500,1500 to origin): grey 2048 slab, with a dark box building at left (x~-150), two thin dark installations near the middle, two blue Lapis plates at upper right (one carrying a white/grey tycoon structure, one with a ring-shaped installation), coloured squares at the far right, and the City's corner overlapping the slab at the bottom-left.
- task4-slab-before-2.jpg (from 650,140,760 to 650,0,570): oblique view of the dense area: a large dark-roofed building in front, then the first blue plate carrying the pale factory/bar structures, the second plate beyond, colourful strips at the far right.

## Applied (after review gate)
Rule: candidates with x < 400 and z > 400 stay (city-corner zone); `UnderGroundCasino` added; x >= 400 goes to `ServerStorage.CityQuarantine.LooseTycoon`, x < 400 and z <= 400 goes to `ServerStorage.CityQuarantine.StagingSlab`. Each moved child got attributes `OriginalCFrame` (Model/BasePart) and `OriginalParent`="Workspace".
- LooseTycoon: 1,367 children, 21,997 instances.
- StagingSlab: 103 children, 21,634 instances (incl. the 8,530-instance Model, UnderGroundCasino 4,349, Shelf3 2,357, Model 2,284).
- Total moved 1,470 children, 43,631 instances. Workspace 162,303 -> 118,672; 382 top-level children left.
- Left in the city-corner zone: 29 candidates, 2,681 instances: Model x19 (1,952), Rig x3 (634), Dummy (83), Part x4 (4), CreatedByBB x2 (8). Later task files them.
- Left outside the slab and untouched: 12 loose Parts at x 1043..1173, z -326..-122 (the coloured squares at the far right in the after screenshot).
- After screenshot `screenshots/task4-slab-after.jpg`: empty grey slab, the two blue Lapis plates with a thin dark strip each, the 12 coloured squares at the far right, a few specks near the bottom centre (corner-zone leftovers), and the City corner at the bottom left.
