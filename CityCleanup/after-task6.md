# After Task 6: streaming prepared (`Crimelife city.rbxl`, Edit, NOT saved, NOT published)

## Streaming properties
Before: StreamingEnabled=false, ModelStreamingBehavior=not readable, StreamingIntegrityMode=Default, StreamOutBehavior=Default, StreamingMinRadius=64, StreamingTargetRadius=1024.

| Property | Write | Read back |
|---|---|---|
| StreamingEnabled | ok | true |
| ModelStreamingBehavior | REFUSED: `ModelStreamingBehavior is not a valid member of Workspace` (reads also fail: "is not a scriptable property") | not readable (stays at engine default) |
| StreamingIntegrityMode | ok | PauseOutsideLoadedArea |
| StreamOutBehavior | ok | Opportunistic |
| StreamingMinRadius | ok | 128 |
| StreamingTargetRadius | ok | 512 |

NEEDS DEVELOPER: set `Workspace.ModelStreamingBehavior = Legacy` in the Properties panel (not scriptable). Until then it is the engine default.

## Structure and part settings
Workspace children: Terrain, Camera, Map, Plots, SpawnLocation, Ground. `Ground` (Model, Persistent) holds Baseplate; `Plots` (Model) Persistent.
Under Map: 97,888 BaseParts; CanTouch changed on 97,888; CastShadow changed on 40,325 (largest dimension under 2). SpawnLocation keeps CanTouch=true.

## Spawn check (Play, Client): PASS
21 samples over 5 s, Y = 5.09 every sample (range 0.00). Character at (-13.34, 5.09, 2494.32).

## Measurements
Edit probe (unchanged probe.luau, plus a children line): workspace_instances=118679, baseparts=97899, meshparts=10332, unions=5000, unanchored_parts=0, scripts_total=1 scripts_enabled=0, lights=1014, particle_emitters=4, decals_textures=4689, top_level_children=6, streaming_enabled=true, serverstorage_instances=143383, studio_memory=5.4GB. (Baseline 264,072 instances.)

Play (Studio-hosted, compare like for like only; ViewportSize 1080x659):

| Reading | PerformAverage | RenderThreadAverage | Batches | Memory MB |
|---|---|---|---|---|
| 1 | 7.9681 | 7.3447 | 239 | 6266.02 |
| 2 (+5 s) | 1.9855 | 4.3343 | 227 | 6276.54 |
| 3 (+5 s) | 2.1798 | 4.1588 | 201 | 6276.95 |
| Baseline 1-3 | 5.5949 / 5.6292 / 5.8995 | 9.7157 / 10.6801 / 9.8172 | 898 / 905 / 912 | 7830.04 / 7832.60 / 7834.16 |

Client `#workspace:GetDescendants()` under streaming: 20,593 (Edit: 118,679).

Streaming view (Client): Map.Robbery has 6 children; 1 has a BasePart loaded.
| Building | Distance from character | BaseParts present |
|---|---|---|
| SlowFoods | 747 | no |
| WareHouseRobbery(NotUnderGroundPart) | 658 | no |
| CasinoMain | 758 | yes |
| Gas2Go | 1093 | no |
| Bank | 1259 | no |
| NewsStation | 1555 | no |

Console after about 15 s: 9 distinct lines: AssetDelivery "Failed to construct v3 batch request entry" (empty id), `rbxassetid://0` failed, `188608071` not approved, `130839932` no permission, four matching "Failed to load sound ..." lines (empty id, 0, 188608071, 130839932), and "Animation Spoofer cannot run while game is running".

## Screenshots
`screenshots/after-task6-{spawn,aerial,bank,street}.jpg`. Edit mode loads everything, so they do not show streaming; the Client table above does.
