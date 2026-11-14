# After Task 2 (`Crimelife city.rbxl`, Edit, not saved)

## Probe output (verbatim, `probe.luau` unchanged)

```
workspace_instances=262040
baseparts=197712  meshparts=17827  unions=11198
unanchored_parts=2327
scripts_total=43  scripts_enabled=0
lights=1993  particle_emitters=10  decals_textures=7106
top_level_children=1863
streaming_enabled=false
top20_models:
  WareHouseRobbery(NotUnderGroundPart) 56397
  WareHouseRobbery(NotUnderGroundPart) 56295
  City 25554
  AI Dummy 13945
  AI Dummy/AnimSaves 13801
  City/Buildings 13465
  Model 8530
  City/nature 6935
  NewsStation 6434
  NewsStation 6434
  Gas2Go 6407
  Gas2Go 6407
  SlowFoodsB 6399
  SlowFoods 6000
  Gas2Go/BuildingGasStation 5468
  Gas2Go/BuildingGasStation 5468
  NewsStation/Model 4950
  NewsStation/Model 4950
  UnderGroundCasino 4349
  CasinoMain 3987
serverstorage_instances=12
studio_memory=5.4GB
```

## Diff against baseline
| Metric | Baseline | After |
|---|---|---|
| workspace_instances | 264072 | 262040 (-2032: 592 destroyed scripts, 1 moved, plus their children e.g. default Animate trees, HD Admin folder) |
| baseparts / meshparts / unions | 197712 / 17827 / 11198 | identical |
| unanchored_parts | 2431 | 2327 (-104, the x6m parts anchored) |
| scripts_total / enabled | 636 / 619 | 43 / 0. 43 = the disabled-in-place rows in the CSV (action `disable_in_place`), all in Workspace |
| lights / decals | 1993 / 7106 | identical |
| particle_emitters | 11 | 10 (one emitter was a descendant of a destroyed script tree) |
| top_level_children | 1876 | 1863 |
| serverstorage_instances | 1 | 12 (CityQuarantine, Scripts, 8 moved scripts, plus their children) |

## Console after Play (15 s wait)
No script errors from Workspace scripts. The tool output may be truncated; the categories seen: asset load failures (`Requester does not have permission for Asset` 130839932, `Asset is not approved` 188608071, `rbxassetid://0` and empty asset id requests) and `Failed to load sound` for the same ids, plus a plugin line "Animation Spoofer cannot run while game is running". Gone vs baseline: x6m Racing Seat, Moving Platform, Barista Bar, Terrain.Fix, HD Admin Loader requires and A-Chassis clamping warnings.

## Screenshots (Edit; files `screenshots/after-task2-*.jpg`)
- Spawn: visually identical to baseline.
- Bank street: identical.
- Aerial: buildings, ground and blocks look the same; a visible difference in the left park area (a road strip near the red patches and a curve at the far left of the baseline view is not drawn). Part counts are identical, so no road part was destroyed; cause not determined (possible render LOD or a part property); flagged for follow-up.
Expected: colour-cycling parts and blinking lights are now static.
