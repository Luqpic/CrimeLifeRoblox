# Task 5: enemy spawn points and quest givers in the city (dry run)

Place: `Crimelife city.rbxl`, Edit. 2026-11-15. Nothing moved in this leg; all positions below are proposals for the reviewer gate.
Workspace descendants before and after: 168,624.

## Step 1: how placement is defined

### Enemy spawn point
- **What it is:** a `Part` in `Workspace.EnemySpawns`, size (4, 1, 4), Anchored, CanCollide false, Transparency 0, orientation (0, 0, 0), CollectionService tag `EnemySpawnPoint` (`ReplicatedStorage.Enemy.Constants.SPAWN_POINT_TAG`). Its one child is a `StringValue` named `EnemyType` whose value names a template in `ServerStorage.EnemyTemplates`.
- **Attributes:** none. All six parts carry zero attributes (read back with `GetAttributes()`); the type lives in the `EnemyType` child, not an attribute.

| Part | EnemyType value | Attributes |
|---|---|---|
| ThugSpawner | Thug | none |
| SmugglerSpawner | Smuggler | none |
| OffenderSpawner | Offender | none |
| BanditsSpawner | Bandits | none |
| DisruptersSpawner | Disrupters | none |
| SaboteurSpawner | Saboteur | none |

- **How the spawner uses it** (`ServerScriptService.Enemy.Scripts.EnemySpawner`): `pickSpawnPoint` reads `point.Position` (or `WorldPosition` for an Attachment) every time it spawns, through `CollectionService:GetTagged`. **Orientation is ignored:** the rig is placed with `CFrame.new(spawnPosition + scatter + (0, 3, 0))`, where scatter is a random offset within 22 studs (`SPAWN_SCATTER_RADIUS`, sqrt-distributed disc). A point is skipped while any living player is within 60 studs (`MIN_SPAWN_DISTANCE_FROM_PLAYER`). Cap 5 alive per type (`MAX_CONCURRENT_ENEMIES_PER_TYPE`), top-up every 2.5 s.
- **Navigable area:** yes. `EnemyAI` uses `PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})` for chase and patrol. Patrol picks random destinations within `PATROL_RADIUS` = 70 studs of the spawn position (the `spawnPosition` passed into `EnemyAI.new`, the point's position at spawn time, not the rig's scattered position); an unreachable destination simply fails and is retried. When no path exists the AI falls back to `Humanoid:MoveTo` straight at the target. So the point needs walkable ground for about 22 studs (scatter) and ideally connected walkable ground for about 70 studs around it.

### Quest giver
- **What it is:** a `Model` directly under `Workspace.Quests`, named exactly as `QuestConfig`'s `npcName` (`Level 1 Quest`, `Level 10 Quest`, `Level 20 Quest`, `Level 35 Quest`, `Level 50 Quest`, `Level 70 Quest`). An R15 rig: `Humanoid`, `HumanoidRootPart` (PrimaryPart, Anchored, Y = 3 above the model pivot), 15 MeshPart limbs, `Body Colors`, `Shirt`/`Pants` named `Clothing`, outfit Accessories, an `Animate` folder (a LocalScript on `Level 1 Quest`, inert in Workspace). Each model has 302 to 320 descendants and 18 to 21 BaseParts.
- **Prompt:** `HumanoidRootPart.ProximityPrompt`, tag `NPCprompt`, `RequiresLineOfSight = false`, `Style = Custom`, `MaxActivationDistance = 10`.
- **Billboard:** `Head.gui` (BillboardGui, children `name`, `arrow`, `dialog`, Adornee nil so it follows its parent Head).
- **Attributes:** `Outfit` (Security on Level 1 and 10, Police on 20 and 35, Armed Police on 50 and 70). Read by nothing at runtime as far as the grep shows (outfit label only).
- **What the code looks up:** `QuestService` finds `Workspace.Quests:FindFirstChild(npcName)` and tags it `Invulnerable`. `QuestDialogueController` waits for `Workspace.Quests[npcName].HumanoidRootPart.ProximityPrompt` and the `Animate` children (idle/point animations). `DialogModule` uses `npc.Head.gui`, `npc.Humanoid` (animations), `npc.UpperTorso` (Adornee of the player-owned reply billboard) and the walk-away check `(playerRoot.Position - npcRoot.Position).Magnitude`, which is relative, read live. `turnProximityPromptsOn` toggles every `NPCprompt`-tagged prompt.
- **Pivot:** the model pivot is at the feet (Y = 0 on the slab, on `Workspace.Ground.Baseplate` top Y = 0); all six face yaw 0 and the rig faces the pivot's LookVector (HRP LookVector relative to pivot = (0, 0, -1)), so `CFrame.lookAt(pos, spawn)` makes a giver face the spawn.

### Stored positions or neighbours
- No script stores an absolute position of a spawn point or a giver: the spawner reads `point.Position` per spawn, the AI keeps that value per enemy for patrol (fine, set at spawn time), the dialogue reads positions live.
- No giver has an ObjectValue, joint or weld pointing outside its model, and no Seat (scanned every descendant). No spawn point has any child other than `EnemyType`. Moving each with `PivotTo` is self-contained.

### What else is in `Workspace.Quests`
Nothing. Its six children are the six givers: 1,892 descendants = 6 models + their 1,886 descendants (318 + 313 + 320 + 302 + 320 + 313); 119 BaseParts = 19 + 20 + 21 + 18 + 21 + 20.

### Enemy type order (weakest to strongest)
From the quest ladder (`QuestConfig.requiredLevel`) and template stats: Thug (level 1 quest, MaxHealth 90, melee Crowbar) < Smuggler (10, 85, pistol) < Offender (20, 90) < Bandits (35, 100, shotgun) < Disrupters (50, 110, AKM) < Saboteur (70, 130, P-90, DetectionRadius 150). Note all six are criminal-side; the Police / Armed Police / Security templates exist but no spawn point produces them.

## Method

- City player spawn: `Workspace.SpawnLocation` at (-11, 1.5, 2498.75), standing on `Workspace.Map.City.Roads.Road`, ground Y = 1.0. The spawn sits in a four-way road intersection.
- Containers inspected under `Workspace.Map.City`: `Advertisement`, `WorkingOn`, `nature`, `Buildings`, `Robberies`, `Fences/Borders`, `Lights`, `FootPaths`, `BaseBricks`, `Props`, `Roads`. The brief's guesses exist: **`Map.City.Roads` and `Map.City.FootPaths` are used.** `Map.Roads` (top-level highways) was also accepted as a road container but no proposed point lands on it. `Map.City.BaseBricks` (block ground, top Y 1.75) was not accepted.
- **Overlay found and handled:** `Map.City.Roads.NIghtLights.SurfaceLightRoad` is a 933 x 1 x 1816 invisible light plane at Y 13.5 to 14 over the whole city (CanCollide false, CanQuery true, Transparency 1). Every downward ray hit it first. All raycasts and the box check therefore use `RespectCanCollide = true` (non-collidable parts are not ground and not obstacles). Without that, no candidate in the city can pass.
- Ray: straight down from Y = 201.5 at each candidate, `RaycastParams` Include `Workspace.Map`, RespectCanCollide.
- Valid when: hit is a descendant of `Map.City.Roads`, `Map.City.FootPaths` or `Map.Roads`; hit Y within 3 studs of 1.0 (extra rule I added so an elevated highway cannot qualify); normal within 10 degrees of vertical; `GetPartBoundsInBox` at hit + (0, 6.1, 0), size (6, 11.8, 6), Include `Map`, `TycoonPreview`, `Plots`, RespectCanCollide, finds nothing but the hit part; horizontal distance to every plot (all 8 `Workspace.Plots` parts, not only 1 to 6) at least 20; outside `TycoonPreview`'s bounding box; horizontal distance to every `Map.Robbery` child's bounding box at least 60; for enemy points, `workspace:Raycast` from hit + (0, 3, 0) for 30 studs toward the spawn (Include Map, TycoonPreview, Plots, RespectCanCollide) returns nothing.
- Extra evidence for enemy points: scatter-disc ground check, 24 rays at radius 11 and 22 around the point, counting hits within 3 studs of ground level.

### Widening and why
- On the 180-stud ring at 15-degree steps only **4** candidates pass (0, 90, 180, 270 degrees): the spawn is at an intersection, so the ring crosses the four road arms and otherwise lands on `BaseBricks` block ground (fails "road or footpath"). The rule needs six, so it cannot be satisfied at one radius.
- Valid angles per radius: 140 and 160: 0, 90, 180, 270; 180: same four; 200: 0, 15, 90, 180, 270, 345; 220: 0, 15, 30, 90, 165, 180, 195, 270, 330, 345; 240: 30, 90, 150, 165, 195, 210, 255, 270, 285, 330; 260: 90, 165, 195, 255, 285.
- **Change:** one point per type on graded radii 140, 160, 180, 200, 220, 260, weakest nearest, placed on the four road arms (east, west, north, south), at least 60 studs apart. This also gives the "weakest nearest, strongest farthest" order, which a single ring cannot. 240 was skipped for Saboteur because 240 on the north arm is 20 studs from Offender at 180 and the east/west arms fail at 240; 260 north passes. An earlier draft put Disrupters at 220 east; it passed but its scatter disc reached only 14/24 ground-level hits (the east arm ends near x 170, street lights and props intrude), so it was moved to 220 west (23/24).
- Quest givers: the brief's rule works unchanged. Nearest long FootPaths strip to the spawn: `Workspace.Map.City.FootPaths.Part` at (-115, 1.5, 2477.5), size 5 x 1 x 172 along X (the sidewalk on the north edge of the south-west block), 26.0 studs from the spawn. Row along its centreline (z = 2477.5), going west from the point 40 studs from the spawn, 14 studs apart. All seven nearest strips passed; this one was taken because it is the nearest.

## Enemy spawn points (first proposal, NOT approved: superseded by "Gate revision" below)

Proposed Y = ground hit Y + 0.5 (each spawner's pivot is 0.5 above the slab top today: part centre Y 0.5, ground Y 0). Orientation stays (0, 0, 0); the spawner ignores it anyway.

| Point | Enemy type | Current position | Proposed position | Ground surface | Dist from spawn | Nearest plot (dist) | Nearest robbery bldg (dist) | Clear box | Strip to spawn | Scatter disc |
|---|---|---|---|---|---|---|---|---|---|---|
| ThugSpawner | Thug (weakest) | (-159.90, 0.50, 230.50) | (129.00, 1.50, 2498.75) | Workspace.Map.City.Roads.Road | 140.0 | Plot3, 279.8 | WareHouseRobbery, 526.2 | 0 parts | clear | 24/24 |
| SmugglerSpawner | Smuggler | (-183.60, 0.50, -45.60) | (-171.00, 1.50, 2498.75) | Workspace.Map.City.Roads.Road | 160.0 | Plot3, 279.8 | CasinoMain, 452.5 | 0 parts | clear | 24/24 |
| OffenderSpawner | Offender | (265.20, 0.50, 157.50) | (-11.00, 1.50, 2678.75) | Workspace.Map.City.Roads.Road | 180.0 | Plot3, 459.8 | WareHouseRobbery, 346.2 | 0 parts | clear | 24/24 |
| BanditsSpawner | Bandits | (230.00, 0.50, -60.20) | (-11.00, 1.50, 2298.75) | Workspace.Map.City.Roads.Road | 200.0 | Plot3, 79.8 (TycoonPreview 82.8) | SlowFoods, 428.8 | 0 parts | clear | 24/24 |
| DisruptersSpawner | Disrupters | (80.20, 0.50, 325.90) | (-231.00, 1.50, 2498.75) | Workspace.Map.City.Roads.Road | 220.0 | Plot2, 280.1 | CasinoMain, 397.1 | 0 parts | clear | 23/24 (one ray on a bin, `BinDesign_1`) |
| SaboteurSpawner | Saboteur (strongest) | (12.10, 0.50, -202.10) | (-11.00, 1.50, 2758.75) | Workspace.Map.City.Roads.Road | 260.0 | Plot3, 539.8 | WareHouseRobbery, 266.2 | 0 parts | clear | 24/24 |

All six: hit normal 0.0 degrees, hit Y 1.0. Closest pairs: Smuggler and Disrupters 60.0 (same west arm), Offender and Saboteur 80.0 (same north arm); every other pair over 100.
Arms: Thug east; Smuggler and Disrupters west; Offender and Saboteur north; Bandits south (toward Plot3).

## Quest givers (proposed)

Proposed pivot Y = ground hit Y + 0 (each giver's pivot is at its feet today: pivot Y 0 on ground Y 0). Facing: `CFrame.lookAt(pos, (-11, Y, 2498.75))`; yaw below is the resulting Y orientation.

| Giver | Current pivot (yaw) | Proposed pivot | Proposed yaw (faces spawn) | Ground surface | Dist from spawn | Clear box |
|---|---|---|---|---|---|---|
| Level 1 Quest | (-7.40, 0.00, 56.40) (0) | (-44.89, 2.00, 2477.50) | -122.09 | Workspace.Map.City.FootPaths.Part | 40.0 | 0 parts |
| Level 10 Quest | (-19.80, 0.00, 57.60) (0) | (-58.89, 2.00, 2477.50) | -113.93 | Workspace.Map.City.FootPaths.Part | 52.4 | 0 parts |
| Level 20 Quest | (-7.80, 0.00, 44.80) (0) | (-72.89, 2.00, 2477.50) | -108.95 | Workspace.Map.City.FootPaths.Part | 65.4 | 0 parts |
| Level 35 Quest | (-20.20, 0.00, 47.30) (0) | (-86.89, 2.00, 2477.50) | -105.64 | Workspace.Map.City.FootPaths.Part | 78.8 | 0 parts |
| Level 50 Quest | (-7.90, 0.00, 38.80) (0) | (-100.89, 2.00, 2477.50) | -103.30 | Workspace.Map.City.FootPaths.Part | 92.4 | 0 parts |
| Level 70 Quest | (-19.20, 0.00, 37.10) (0) | (-114.89, 2.00, 2477.50) | -101.56 | Workspace.Map.City.FootPaths.Part | 106.0 | 0 parts |

All six: hit part is the same strip `Workspace.Map.City.FootPaths.Part` (-115, 1.5, 2477.5) (the name `Part` is not unique in `FootPaths`; identify it by that position), normal 0.0, nearest plot 258.5, nearest robbery building 512.5 or more.
Alternatives that also passed all six: the mirror strip on the north side (z = 2521.5, distances 40.0 to 105.4) and the strips along z at x = -31.5 and x = 12.5, both directions.

## Screenshot

Not recorded: `screen_capture` timed out twice (once with markers, once retried alone). The 12 markers (red 4 x 20 x 4 at the enemy points, green at the givers) were created under `Workspace.__PlacementMarkers` and the folder was destroyed; read back gone, Workspace 168,624.

## What I am unsure of

1. **Enemies stand in the road.** Every enemy point is on a road arm because the ring otherwise lands on block ground (`BaseBricks`), which the rule excludes. If the city later gets traffic, these points will need to move onto sidewalks or block ground.
2. **Thugs may reach the spawn.** Thug point at 140, patrol radius 70 plus scatter 22 lets a Thug wander to about 48 studs from the spawn, inside its 80-stud detection radius; players at the spawn could be engaged by Thugs. That fits "short walk to enemies" but contradicts "not on top of the spawn" if it reads badly; 160 or 180 would avoid it.
3. **Bandits' patrol can reach the tycoon plot.** Bandits point is 79.8 from Plot3 (82.8 from TycoonPreview); patrol radius 70 + scatter 22 can bring them onto the plot edge. Pathfinding has not been run here (Edit mode, no navmesh test).
4. Smuggler and Disrupters share the west arm at exactly 60.0 apart, the minimum.
5. No pathfinding test of the 70-stud patrol area; only the 30-stud straight strip toward the spawn and the 22-stud scatter disc were checked.
6. The `RespectCanCollide` choice (to see past the city-wide light plane) also means non-collidable decorative parts are ignored by the box check; such parts would be walk-through anyway.
7. The Level 1 Quest model's `Animate` is a LocalScript (others are Folders); unchanged by placement, noted only.

## Gate revision (enemy points)

The gate approved the quest-giver row and rejected the first enemy points: Thugs could patrol into detection range of the spawn, the arm toward Plot3 lets Bandits reach the plot, and a west point at 160 could patrol into the giver row. New rules for every point: at least 180 from the `SpawnLocation`; at least 120 from every plot `Plot1`..`Plot6` footprint and from `TycoonPreview`'s box; at least 130 from every proposed quest giver; at least 60 from every other point and every robbery building's box; on `Map.City.Roads` or `Map.City.FootPaths` with the earlier checks; not on the arm toward Plot3.

**Arm naming.** The gate called the arm leading to Plot3 "north". In world terms that is the -Z arm (Plot3 is at z 2069, the spawn at z 2498.75). So "south" in the gate's starting proposal is read as the +Z arm (away from Plot3), and the -Z arm is not used. East is +X, west is -X. The -Z arm would fail the 120-from-plot rule anyway (79.8 at 200 studs).

**Arm scan** (every 20 studs along each arm, all rules applied):
- East (+X): passes at 180, 200, 220 only. From 240 the ray lands on `Map.City.Buildings.UpperCity.Building_15` (a building across the road end, roof Y 178); 280 to 320 on `BaseBricks` with Building_15 / Building_13 blocking; 380 and 400 blocked toward the spawn by Building_13; 420 box hits a `FootPaths.Wedge`. **The east arm runs out of road after 220, so it holds only one point.**
- West (-X): 180 to 220 fail giver < 130 (79, 98, 118); 240 and 260 fail the straight line toward the spawn (blocked by `Map.City.Props.BinDesign_1`); 280 to 420 pass.
- +Z: 180 to 280 pass; 300 box hits a `FootPaths.Wedge`; 320 and 340 land on `Building_63` (roof Y 108); 360 on `BaseBricks`, blocked; 380 and beyond no ground hit.

**Stepping from the starting proposal:** Thug E180 passes. Smuggler +Z180 passes. Offender W240 fails (bin in the strip), W260 fails (same), **W280** passes. Bandits E260 fails and the east arm has no valid road past 220 (and 220 is only 40 from Thug), so it goes to the next free slot keeping the order: **+Z280** (+Z 240 and 260 also pass but would put Bandits nearer than Offender). Disrupters: +Z cannot hold a third point (valid range 180 to 280, already 180 and 280), so **W340** (60 past Offender). Saboteur W300 is taken by the spacing; **W400** (60 past Disrupters; W420 also passes but its scatter disc is 21/24).

**Final order, weakest nearest:** Thug 180 = Smuggler 180 < Offender 280 = Bandits 280 < Disrupters 340 < Saboteur 400. Ties are where two arms share a distance; the order never inverts.

| Point | Type | Arm | Position (applied) | Ground surface | Dist from spawn | Nearest plot 1-6 (dist) | TycoonPreview | Nearest giver | Nearest robbery bldg | Nearest other point | Normal | Clear box | Line to spawn | Scatter disc |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ThugSpawner | Thug | E | (169.00, 1.50, 2498.75) | Map.City.Roads.Road (Y 1.0) | 180.0 | Plot3 279.8 | 293.3 | 214.9 | WareHouseRobbery 526.2 | Smuggler 254.6 | 0.0 | 0 parts | clear | 23/24 |
| SmugglerSpawner | Smuggler | +Z | (-11.00, 1.50, 2678.75) | Map.City.Roads.Road (Y 1.0) | 180.0 | Plot3 459.8 | 462.8 | 204.1 | WareHouseRobbery 346.2 | Bandits 100.0 | 0.0 | 0 parts | clear | 24/24 |
| OffenderSpawner | Offender | W | (-291.00, 2.50, 2498.75) | Map.City.FootPaths.Part (Y 2.0) | 280.0 | Plot2 279.8 | 329.3 | 177.4 | CasinoMain 341.7 | Disrupters 60.0 | 0.0 | 0 parts | clear | 24/24 |
| BanditsSpawner | Bandits | +Z | (-11.00, 1.50, 2778.75) | Map.City.Roads.Road (Y 1.0) | 280.0 | Plot5 542.1 | 562.8 | 303.2 | WareHouseRobbery 246.2 | Smuggler 100.0 | 0.0 | 0 parts | clear | 24/24 |
| DisruptersSpawner | Disrupters | W | (-351.00, 2.50, 2498.75) | Map.City.FootPaths.Part (Y 2.0) | 340.0 | Plot2 279.8 | 363.7 | 237.1 | CasinoMain 286.2 | Offender 60.0 | 0.0 | 0 parts | clear | 24/24 |
| SaboteurSpawner | Saboteur | W | (-411.00, 1.50, 2498.75) | Map.City.Roads.Road (Y 1.0) | 400.0 | Plot2 279.8 | 404.2 | 296.9 | CasinoMain 230.8 | Disrupters 60.0 | 0.0 | 0 parts | clear | 24/24 |

Plot distances are horizontal distances to the plot part's footprint; Plot7 and Plot8 are also farther than 120 from every point.

## Applied (2026-11-15, Edit, not saved)

Spawn points moved by setting `Position` (size and rotation read back unchanged). Quest givers moved with `PivotTo(CFrame.lookAt(pos, spawn at the same Y))`. The giver pivot Y is 2.0035: its pivot was 0.0035 above the slab ground (Y 0) before, and the sidewalk top is Y 2.0. Each moved instance has the attribute `PlacedBy = "CityMerge Task 5, provisional"`. Nothing else moved: `Workspace.Targets` and `Workspace.Dev` are still on the slab.

Old CFrames are the way back (`part.CFrame = old` / `model:PivotTo(old)`):

| Instance | Old CFrame | New CFrame |
|---|---|---|
| ThugSpawner | CFrame.new(-159.9, 0.5, 230.5) | CFrame.new(169, 1.5, 2498.75) |
| SmugglerSpawner | CFrame.new(-183.6, 0.5, -45.6) | CFrame.new(-11, 1.5, 2678.75) |
| OffenderSpawner | CFrame.new(265.2, 0.5, 157.5) | CFrame.new(-291, 2.5, 2498.75) |
| BanditsSpawner | CFrame.new(230, 0.5, -60.2) | CFrame.new(-11, 1.5, 2778.75) |
| DisruptersSpawner | CFrame.new(80.2, 0.5, 325.9) | CFrame.new(-351, 2.5, 2498.75) |
| SaboteurSpawner | CFrame.new(12.1, 0.5, -202.1) | CFrame.new(-411, 1.5, 2498.75) |
| Level 1 Quest | CFrame.new(-7.4, 0.0035, 56.4) | CFrame.new(-44.8885, 2.0035, 2477.5, -0.5312, 0, -0.8472, 0, 1, 0, 0.8472, 0, -0.5312) (yaw -122.09) |
| Level 10 Quest | CFrame.new(-19.8, 0.0035, 57.6) | CFrame.new(-58.8885, 2.0035, 2477.5, -0.4056, 0, -0.9141, 0, 1, 0, 0.9141, 0, -0.4056) (yaw -113.93) |
| Level 20 Quest | CFrame.new(-7.8, 0.0035, 44.8) | CFrame.new(-72.8885, 2.0035, 2477.5, -0.3247, 0, -0.9458, 0, 1, 0, 0.9458, 0, -0.3247) (yaw -108.95) |
| Level 35 Quest | CFrame.new(-20.2, 0.0035, 47.3) | CFrame.new(-86.8885, 2.0035, 2477.5, -0.2696, 0, -0.9630, 0, 1, 0, 0.9630, 0, -0.2696) (yaw -105.64) |
| Level 50 Quest | CFrame.new(-7.9, 0.0035, 38.8) | CFrame.new(-100.8885, 2.0035, 2477.5, -0.2301, 0, -0.9732, 0, 1, 0, 0.9732, 0, -0.2301) (yaw -103.30) |
| Level 70 Quest | CFrame.new(-19.1981, 0.0035, 37.1011) | CFrame.new(-114.8885, 2.0035, 2477.5, -0.2004, 0, -0.9797, 0, 1, 0, 0.9797, 0, -0.2004) (yaw -101.56) |

All old rotations were identity (yaw 0). Read-back after the move: each giver's `HumanoidRootPart` is at (x, 5.0035, 2477.5), exactly pivot * its old pivot-relative offset (error 0.0000); `Anchored` unchanged on every BasePart (each model has 1 anchored part, its HumanoidRootPart, so 6 anchored and 113 unanchored in all); nothing anchored or unanchored. Workspace 168,624 before and after.

Screenshots: `task5-placed.jpg` (camera (-11, 420, 2760) to (-11, 0, 2499)) and `task5-givers.jpg` (camera (-11, 8, 2499) to (-80, 4, 2477.5)) were each tried once, separately: both timed out, **not recorded**.

## Run (Step 5)

One solo Play from the city `SpawnLocation` (the only enabled one; `Dev.DevSpawn` disabled). A temporary server Script sampled at about 46 s and 76 s of game time (Play had been running about 20 s when the probe started; the two samples are 30 s apart).

| Reading | first sample (~46 s) | second sample (~76 s) |
|---|---|---|
| Enemies alive in `Workspace.Enemies` | 20 | 30 (5 per type, the cap) |
| Per type: count [distances from own point] | Bandits 4 [3,13,21,40]; Disrupters 5 [20,56,44,61,7]; Offender 5 [30,42,67,35,22]; Saboteur 3 [9,24,22]; Smuggler 1 [7]; Thug 2 [48,6] | Bandits 5 [20,58,40,20,16]; Disrupters 5 [24,30,49,7,18]; Offender 5 [35,29,1,63,19]; Saboteur 5 [23,39,38,6,58]; Smuggler 5 [26,16,23,1,67]; Thug 5 [48,46,21,38,19] |
| Nearest enemy to the player's character | 181.2 | 150.4 |
| Nearest enemy to the SpawnLocation (horizontal) | 182.3 | 150.6 |
| Enemies within 100 of the SpawnLocation | 0 | 0 |
| Enemies inside any plot footprint | 0 | 0 |
| Enemy root Y range | 4.2 to 7.2 | 4.2 to 8.2 (standing on the ground; no fall-through, no pile-up) |
| Player Humanoid.Health | 100 | 100 (also 100 after the tests) |
| leaderstats.Cash | 500 | 500 |

Movement, one enemy per type followed from the first to the second sample (30 s): Bandits 23.0, Disrupters 10.8, Offender 25.5, Saboteur 31.7, Smuggler 25.1 studs; **Thug 0.0**. A follow-up 8 s window over all 30: every type moves (Thug 62.1, 40.4, 57.7, 72.3 and **0.0**). The same Thug stood still at (215, 5.0, 2485) through both checks: it is on the east arm near where the road ends against Building_15, about 46 studs from its point (inside the 22 scatter + 70 patrol range); it looks stuck (path to its patrol targets failing, or wedged against the building's base). Not fixed in this leg.

Client (one call, game time 28.6 s): all six givers present, each `HumanoidRootPart` Y 5.0035 (0.000 from the intended Y), each with its `ProximityPrompt`; PlayerGui 21 children. Client console: no error from a game script; 8 distinct non-asset errors, all from Roblox's own CoreGui modules (`GraphQL extendSchema:708` and `StarterScript:239` "Script timeout: exhausted allowed execution time", and the PlayerList / TopBar / ApolloClient modules that failed to load after it). These are engine core scripts timing out during load, not this project's code; they were not in the Task 4 list. Server console: 0 non-asset errors, 0 `[FAIL]` lines.

Unit tests (temporary server Script, per suite): PropertyAuthority 8/8/0, validateRunningState 8/8/0, staminaStep 10/10/0, Palettes 11/11/0, SkinApplier 14/14/0, CosmeticsOwnership 12/12/0, SpraypaintConstants 8/8/0, SpraypaintService 21/21/0, SpraypaintTier 8/8/0, Schema 9/9/0, ProfileGateway 22/22/0, ProfileAdoption 16/16/0: **147 / 147 / 0**, same as Task 4.

After Play: Edit; `#workspace:GetDescendants()` 168,624; exactly one enabled SpawnLocation (`Workspace.SpawnLocation`); no `Workspace.Enemies` in Edit; the temporary scripts and values gone; the twelve anchors read back at the applied positions with `PlacedBy`.
