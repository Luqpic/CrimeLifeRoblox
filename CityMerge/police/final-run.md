# Closing run (police and wanted level, Task 6)

Measured 2026-11-17 in `Crimelife city.rbxl` (the only Studio window, resolved by name). No script changed. Nothing saved or published. Every number below came from a call in this run. Times are `workspace.DistributedGameTime` (game seconds) unless marked "+", which is seconds from the step's own start.

Method, all Plays: Solo Play through the Studio MCP. The player was moved by a server `PivotTo`; robberies were started by equipping the Crowbar from the client through `Weapons.Remotes.EquipRequest` while standing in the location's zone (the real `ChildAdded` trigger); registers were robbed through their real prompt (camera aimed at the part from the client, `InputHoldBegin`, 8.7 s, `InputHoldEnd`); the knife stab went through the real `Blaster.Remotes.Shoot` remote. While the robber had to survive, an invisible `ForceField` (`Visible = false`) was on the character; it was taken off for the death step and the Bank-guard reading. Heat, stars, `WantedSeen` and `WantedDraining` were read from the player's attributes; police from live Humanoids in `Workspace.Police`.

## Step 1: the loop (Play A)

| step | driven by | result |
|---|---|---|
| SlowFoods alarm | pivot into `SlowFoodsZones.RestaurantZone` (100, 7.5, 1730), Crowbar equipped | `WantedHeat` 1, `WantedStars` 1, `WantedSeen` true (active robbery) |
| Police arrive | the dispatcher | 2 Police (target for 1 star), 0 Armed; nearest 120 studs at the first logger read, closing 117, 108, 99, 92, 86, 79 over 3 s, then holding at the door, 47 studs from the robber inside (the interior is off the navmesh, known) |
| Register robbed | real prompt at (100.0, 5.7, 1723.7), 6.4 studs | `Triggered` fired; that register's prompt removed |
| Bank-in while wanted | pivot along x = 96.8, 4 s at each distance from the anchor (horizontal) | see the table below |
| Escape, first try | pivot to the road at (-20, 4, 1724), 195 studs from both officers | not an escape: both officers walked to 51 studs and saw the robber on the open road; heat 1, seen true for 20 s and more (correct by the rules) |
| Escape | pivot to (-269, 17, 1607), road, 275 studs away, a terrain rise between it and the officers' last spot (every officer head ray blocked) | +0 seen false; +5.5 draining true; **+8.0 heat 0, stars 0, police 0** (both despawned at the same 0.5 s sample) |
| Rob again (Gas2Go) | Crowbar unequipped, pivot onto `Gas2Go.BuildingGasStation.Floor` (-962, 5, 2028), Crowbar equipped | heat 1; register at (-960.2, 6.4, 2022.7) robbed through its prompt |
| Die while wanted | `ForceField` removed, pivot to `Gas2GoExitSpawn` (-986.6, 5, 1967.6), 60 studs from the anchor | killed by the police in 2.9 s; log `[Forfeit] run 1: <player> forfeited 2000 (died)`; **heat 0, stars 0, police 0** 1.5 s after death; `leaderstats.Cash` 2,500 (unchanged: the haul was lost, the earlier bank-in kept) |
| Bank alarm | pivot into `HeistZones.BankZone` on `Workspace.Bank.Part` (1220.7, 12.9, 2323.5), Crowbar equipped | **heat 3, stars 3; 4 Police + 2 Armed Police** at the first sample; 7 `Guard` models in Workspace (4 Bank, 3 NewsStation) |
| Bank to NewsStation | `ForceField` removed, `Humanoid.Health = 0` (a forced death, not a police kill) | heat 0, police 0 1.5 s later |
| NewsStation alarm | pivot to (-646, 5.5, 1000) inside `NewsroomZone`, Crowbar equipped | **heat 2, stars 2**; the 3 NewsStation guards within 80 studs |
| Guards engage | `ForceField` off for 4 s | hp 100 -> 94 (+0.38 s), 88 (+1.37), 83 (+2.37), 78 (+3.35): 6 per hit about every 0.98 s from one guard in sight (the +1 steps between are regeneration) |
| NewsStation police | the dispatcher | 3 Police at +18 s after the alarm, the 4th at about +32 s (target 4, 0 Armed at 2 stars) |
| Knife stab on an officer | a `ServerStorage.Weapons.Knife` clone given to the Backpack, equipped through `EquipRequest`; the player 3 studs in front of an officer, facing it; one `Shoot` with the six rays claimed on the officer | **heat 2.00 -> 2.25 at +0.05 s and nothing more**; officer hp 100 -> 70 (the cut), then 66, 62, 58, 54, 50 at +1.05 to +5.14 s (five bleed ticks of 4), heat 2.25 throughout |

Bank-in while wanted (SlowFoods, one register robbed):

| distance from anchor | game time | heat | seen | `leaderstats.Cash` |
|---|---|---|---|---|
| inside | 103.2 | 1.00 | true | 500 |
| 55 | 107.2 | 1.00 | true | 500 |
| 100 | 111.2 | 1.00 | true | 500 |
| 150 | 115.2 | 1.00 | true | 500 |
| 199 | 119.2 | 1.00 | true | 500 |
| 201 | 120.7 | 1.00 | true | **2,500** |
| 201, 3 s later | 123.8 | 1.00 | true | 2,500 |
| 205 | 125.8 | 1.00 | true | 2,500 |

The cash banked once (+2,000, one register) and the star stayed. At 201 the robber was past `EscapeDistance`, so `seen` was the officers' own sight (they followed the robber out).

## Step 2: load (Play B)

Solo allows one wanted player, so the most police it can show is that player's 5-star squad, 10. The 24 cap with several wanted players is proven by `SquadPlan_Test` only.

Method: a temporary server Script required the runner's `WantedService` (a Script shares the game's module copy; an `execute_luau` require does not), raised heat to 5 and topped it back to 5 every second for 125 s, counting live police each second; at the end it called `WantedService.clear`. The player stood at the city spawn (-11.1, 5.1, 2494.4) under an invisible `ForceField`. Client readings were 10 s windows from a Client `execute_luau`. The Studio viewport read 1 x 1 (the pane was hidden), so `RenderStepped` gave 0 frames: there is no render frame time in this run, only `Heartbeat`. Memory is the Studio process's `Stats` totals (edit and play data models together), not a phone figure.

| reading | no police (13 to 23 s) | 8 police replicated (90 to 100 s) | 10 police (132 to 142 s) |
|---|---|---|---|
| client `Heartbeat` average / max | 16.92 / 95.3 ms (591 frames) | 16.98 / 115.9 ms (589) | 16.89 / 107.7 ms (592) |
| client `Workspace` descendants | 103,331 | 112,438 | 118,613 |
| client game descendants | 114,458 | 123,608 | 129,829 |
| client descendants under `Workspace.Police` | 0 | 2,370 | 3,002 (about 300 per officer) |
| `Stats:GetTotalMemoryUsageMb()` | 10,007 | 10,046 | 10,067 |
| `LuaHeap` | 1,083 MB | 1,085 MB | 1,088 MB |
| `Instances` | 287 MB | 293 MB | 296 MB |

The descendant growth from the first column is not all police: the baseline was read while the gangs were still filling (11 to 12 of 30 alive at 25 s in every Play) and while streaming loaded around the spawn. The police share is the `Workspace.Police` row.

Server, with 10 police: `Heartbeat` average 16.92 ms, max 85.3 ms (591 frames in 10 s); `GetRealPhysicsFPS` 59.9 to 60.1.

Police alive, sampled every second for 125 s at 5 stars: **min 10, max 10** (6 of them Armed), never above 24.

After the clear, with the `ForceField` taken off: the player's hp stayed 100 for the whole 49 s that followed (no officer hurt a player who is no longer wanted); police alive 10, 8 at +10 s, 7 at +25 s, 5 at +35 s, 0 at +49 s (the last ones at the 60 s leave timeout, counted from the clear).

## Step 3: five Plays from the city spawn, not wanted

Console read through `LogService:GetLogHistory()` in the Server and Client data models at 25 s. An error or warning line counts as an asset line when it contains `Failed to load`, `ContentId`, `asset` or `Asset` (the phase 3 rule); every other line is listed.

| Play | read at (server / client) | server non-asset | server asset | client non-asset | client asset | PlayerGui / PlayerScripts | live gangs at 25 s | police | heat | quest givers with a prompt | enabled SpawnLocations |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 25.0 / 26.0 | 3 | 149 | 0 | 326 | 29 / 34 | 11 | 0 | 0 | 6 | 1 |
| 2 | 25.1 / 26.0 | 3 | 152 | 0 | 316 | 29 / 34 | 12 | 0 | 0 | 6 | 1 |
| 3 | 25.3 / 26.0 | 3 | 155 | 0 | 319 | 29 / 34 | 12 | 0 | 0 | 6 | 1 |
| 4 | 25.4 / 26.3 | 3 | 159 | 0 | 320 | 29 / 34 | 12 | 0 | 0 | 6 | 1 |
| 5 | 25.1 / 25.9 | 3 | 139 | 0 | 309 | 29 / 34 | 11 | 0 | 0 | 6 | 1 |

The three server lines are the same in every Play, all from `Workspace.HQ` (not touched): `Bar is not a valid member of ServerStorage` once and `opendoor is not a valid member of Model "Workspace.HQ...Proximity Door.DoorNoHandle"` twice. 0 client lines outside asset lines. PlayerGui and PlayerScripts are each one more than phase 3's 28 / 33: the `WantedHud` ScreenGui and its LocalScript.

Gangs as before: Play 1 at 70.4 s, 29 alive (Bandits, Disrupters, Offender, Saboteur, Smuggler 5 each, Thug 4, still filling); Play 5 at 70.9 s, `EnemyAI.getLive()` read from a temporary Script: 30 (5 of each of the six types), 0 with a `targetFilter`, 0 with a `preferTarget`, no `Workspace.Police`.

Suites, Play 5, from a server `execute_luau`:
- City `require(ServerStorage.UnitTest.RunUnitTest)("")`: **251 run, 251 passed, 0 failed.**
- Heist `require(ServerScriptService.Heist.Tests.RunAll)()`: **620 passed, 1 failed**; the failure is `Zone` "the real occupancy sweep ignores non-character geometry" (3.17 ms), the known timing case.

After the five Plays, in Edit: 1 enabled `SpawnLocation` in Workspace, no `Workspace.Police`, 0 objects named `_T6*` in Workspace, ServerScriptService, ServerStorage or ReplicatedStorage.

## Not measured here

- Two players: a second robber, the shared 24 cap, squads sharing the cap, a bystander near a guard.
- A phone: frame time and memory on a device; the 844 x 390 meter position (computed in Task 4).
- How the chase and the shooting feel; a real conversation with a crooked cop; the vault path for police at the Bank.
- The star meter on screen this run (viewport 1 x 1).
