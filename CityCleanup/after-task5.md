# After Task 5 (`Crimelife city.rbxl`, Edit, not saved, not published)

## Probe output (verbatim, `CityCleanup/probe.luau` unchanged)

```
workspace_instances=118678
baseparts=97899  meshparts=10332  unions=5000
unanchored_parts=0
scripts_total=1  scripts_enabled=0
lights=1014  particle_emitters=4  decals_textures=4689
top_level_children=6
streaming_enabled=false
top20_models:
  Map 118663
  Map/Robbery 83420
  Map/City 25554
  Map/Props 4308
  Map/Loose 3581
  Map/Roads 1799
  Plots 9
  SpawnLocation 2
  Baseplate 2
  Plots/Plot8 1 ... Plots/Plot1 1 (all eight, 1 each)
  Baseplate/Texture 1
  SpawnLocation/Decal 1
serverstorage_instances=143383
studio_memory=5.1GB
```

Arithmetic: 118,672 (Task 4 figure) + 6 new containers (Map, Robbery, Roads, Props, Loose, Plots) = 118,678. Matches.
Top-level children are exactly Baseplate, Terrain, Camera, Map, Plots, SpawnLocation (6).
`scripts_total=1, enabled=0`: one script remains in Workspace and it is disabled; zero enabled scripts.

## Live-place checks
- `Workspace.Map.City` descendants: 25,553 (as before).
- `Map.Robbery`: 6 children (Bank, SlowFoods, Gas2Go, NewsStation, CasinoMain, WareHouseRobbery(NotUnderGroundPart)), 83,419 descendants. Pivots identical before and after the move (read before: warehouse -32.27, 31.50, 3151.13; Bank 1217.75, 220.76, 2342 (matches the kept Bank in duplicates.md); SlowFoods 78.63, 37.14, 1753.85 (matches kept SlowFoodsB); Gas2Go -982.39, 18.69, 1988.07; NewsStation -596, 74.06, 1054.79; CasinoMain -702.90, 114.90, 2789.89).
- `Workspace.Plots`: Model, no PrimaryPart, 8 children Plot1..Plot8, PlotIndex 1..8, Spare=true on Plot7 (720.5, 0.5, -207) and Plot8 (544.5, 0.5, 229) only; all anchored.
- SpawnLocation at (-11.0, 1.5, 2498.75), unchanged; Baseplate and SpawnLocation anchored.
- Map children: City, Robbery, Roads, Props, Loose. Roads 3 children / 1,798; Props 147 / 4,307; Loose 213 / 3,580.
- Step 4: 97,888 BaseParts under Map; 385 were unanchored and were set to Anchored = true.

## Screenshots
`screenshots/after-task5-aerial.jpg`, `after-task5-bank.jpg`, `after-task5-spawn.jpg` (same camera positions as the baseline).
