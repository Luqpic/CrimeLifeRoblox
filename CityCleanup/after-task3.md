# After Task 3 (probe output, unchanged probe.luau, 2026-11-14)

```
workspace_instances=162303
baseparts=124608  meshparts=13135  unions=6685
unanchored_parts=2064
scripts_total=43  scripts_enabled=0
lights=1376  particle_emitters=10  decals_textures=6655
top_level_children=1852
streaming_enabled=false
top20_models:
  WareHouseRobbery(NotUnderGroundPart) 56397
  City 25554
  City/Buildings 13465
  Model 8530
  City/nature 6935
  NewsStation 6434
  Gas2Go 6407
  SlowFoods 6399
  Gas2Go/BuildingGasStation 5468
  NewsStation/Model 4950
  UnderGroundCasino 4349
  Bank 3891
  CasinoMain 3891
  WareHouseRobbery(NotUnderGroundPart)/Shelf3 2357
  (Shelf3 rows repeat)
serverstorage_instances=99750
studio_memory=5.4GB
```

Before: workspace 262,040, serverstorage 12. Moved: 99,737 (6407+3987+6434+6000+56295+3893+4x694+13945). Workspace now 162,303 = 262,040 - 99,737 exactly. ServerStorage 99,750 = 12 + 99,737 + the new `Duplicates` folder (`CityQuarantine` already existed).
Kept copies still at their table centres: Gas2Go (-982.39,18.69,1988.07), CasinoMain (-702.90,114.90,2789.89), NewsStation (-596.00,74.06,1054.79), SlowFoods (was SlowFoodsB) (78.63,37.14,1753.85), WareHouse (-32.27,31.50,3151.12), Bank (1217.75,220.76,2342.00). Exactly one top-level model of each name. No top-level `AI Dummy` or `SlowFoodsB`. One top-level `Dummy` remains: an 83-instance model at (195, 2.5, 710), not one of the four 694-instance rigs, left alone.
