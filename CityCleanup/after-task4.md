# After Task 4 (staging slab cleared)

Probe: `CityCleanup/probe.luau`, unchanged, Edit mode, `Crimelife city.rbxl`.

workspace_instances=118672
baseparts=97899  meshparts=10332  unions=5000
unanchored_parts=385
scripts_total=1  scripts_enabled=0
lights=1014  particle_emitters=4  decals_textures=4689
top_level_children=382
streaming_enabled=false
serverstorage_instances=143383
studio_memory=5.2GB

Before: Workspace 162,303 instances, 1,852 top-level children, ServerStorage 99,750.
Moved: 1,470 top-level children, 43,631 instances (LooseTycoon 1,367 / 21,997; StagingSlab 103 / 21,634).
Workspace drop 162,303 - 118,672 = 43,631 = moved instances. ServerStorage 99,750 + 43,631 + 2 new folders = 143,383.

Checks
- No top-level Workspace child named TycoonSpawn, DropperConfig, Drop, UpgraderPart, Crime Band, UnderGroundCasino, WareHouseP2.
- Still on the slab with x >= 400 or z <= 400: Baseplate, Terrain, two Lapis plates (544,0,229) and (720,0,-207). Nothing else.
- Workspace.SpawnLocation at (-11, 2, 2499). Robbery building pivots identical before and after (Gas2Go -982,19,1988; CasinoMain -703,115,2790; NewsStation -596,74,1055; SlowFoods 79,37,1754; WareHouseRobbery(NotUnderGroundPart) -32,32,3151; Bank 1218,221,2342).
- Workspace.City descendants: 25,553. Enabled scripts in Workspace: 0.
