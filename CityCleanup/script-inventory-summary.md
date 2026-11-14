# Script inventory summary (Task 2, leg 1)

Total rows: 648 (Workspace 636, ServerScriptService 6, StarterGui 3, Lighting 3, StarterPlayer 0, ReplicatedFirst 0). Workspace enabled count: 619 (ModuleScripts counted enabled). Nothing changed in the place.

Service name `StarterGUI` in the CSV is the instance name of the StarterGui service in this place.

## Verdict x rule (rows)

| Rule | destroy | quarantine | total |
|---|---|---|---|
| R1 numeric require / getfenv / loadstring | 7 | 0 | 7 |
| R2 listed names / HD Admin | 144 | 0 | 144 |
| R3 vehicle | 54 | 0 | 54 |
| R4 tycoon kit configs | 28 | 0 | 28 |
| R5 Animate/Animation in Rig | 18 | 0 | 18 |
| R6 name contains Weld (always shadowed by R3) | 0 | 0 | 0 |
| R7 lighting / time quarantine | 0 | 8 | 8 |
| R8 everything else (by group) | 346 | 43 | 389 |
| **Total** | **597** | **51** | **648** |

Adler-32 groups: 104 total; destroy groups (saved to removed-scripts): 82. Note a hash can appear in rows of different rules (e.g. 1f2d341c: 17 destroy via R5 in a Rig, 4 quarantine via R8 under NPCsPlacments).

## Observations the reviewer should know

- R6 (Weld): both Weld scripts (`Weld 2.1` x2 under `Workspace.x6m.Body.Racing Seat`, `MiscWeld` under `Workspace.x6m.A-Chassis Tune.Initialize`) sit in the x6m car, so R3 matched first. R6 fires 0 times; the must-anchor list below is therefore the car.
- R4 matches only by the five config names (28 rows). No ancestor is literally named tycoon, so "any script inside a loose tycoon piece" was not applied beyond those; worker `Animation` scripts inside tycoon pieces are destroy via R8 (animation only).
- R1 beat the quarantine list for the 5 `ClientReplicator` copies (they are a backdoor), so they are destroy, not quarantine.
- R8 destroy groups total 168 rows; R8 quarantine 221 rows (mostly 174 Clothing Shelf label scripts, 27 proximity doors, 11 outfit givers, 4 stock Animates).
- Fix (69k chars) and other long sources are saved in full; `1f2d341c` etc. saved in full. Place file on disk is the other backup.

## Groups (one row per Adler-32)

| adler32 | n | lines | name(s) | verdict | rule(s) | reason | example path |
|---|---|---|---|---|---|---|---|
| 1f2d341c | 21 | 805 | LocalScript:Animate | destroy | R5,R8 | REVIEW: stock Animate; all 21 destroy (R5 in Rig, R8 under NPCsPlacments) | `Workspace.Rig.Animate` |
| 59e19ad1 | 1 | 21947 | Script:Fix | destroy | R1 | R1: Terrain.Fix, 69,317 chars, mostly blank lines then payload: header says "studio Hardware56. Removing this may cause severe damage" (classic backdoor/infector bait) | `Workspace.Terrain.Fix` |
| db56cd8b | 7 | 16 | Script:Instructions Of Use | destroy | R2 | listed name or under HD Admin | `Workspace.City.Advertisement.BillBoardStyle_1#0.AddImageHere.Instructions Of Use` |
| a453cdb6 | 4 | 16 | Script:Instructions Of Use | destroy | R2 | listed name or under HD Admin | `Workspace.City.Advertisement.BillBoardStyle_2#0.AddImageHere.Instructions Of Use` |
| 8b96e423 | 1 | 21 | Script:Classification[READ] | destroy | R8 | comment-only notes, no code | `Workspace.City.Robberies.Classification[READ]` |
| e2fb2912 | 29 | 10 | Script:Script | destroy | R8 | blinks a PointLight on a loop (decor) | `Workspace.Model.0.2FlashAlarm.Flash.Script` |
| f77557d8 | 1 | 13 | Script:Script | destroy | R8 | bobs a brick up/down on a loop (animation) | `Workspace.Model.Part.Script` |
| 53e83c57 | 41 | 6 | Script:DamageScript_25, Script:Kill_25 | destroy | R2 | listed name or under HD Admin | `Workspace.Model.Model.BigLazer.DamageScript_25` |
| 0e154a82 | 1 | 14 | Script:ScripterInstructions | destroy | R8 | comment-only scripter notes, no code | `Workspace.Model.NPCsPlacments.ScripterInstructions` |
| 53dc3c56 | 8 | 6 | Script:Script | destroy | R8 | kills on touch (-15 health) | `Workspace.Model.SecurityCDamagePart_15.Script` |
| c784f153 | 92 | 50 | Script:Script | destroy | R8 | rainbow recolour loop | `Workspace.CasinoMain.Triangle3.Part.Script` |
| 8ea1f1ba | 84 | 50 | Script:Smooth Color Changing Script | destroy | R2 | listed name or under HD Admin | `Workspace.CasinoMain.Model.Part.Smooth Color Changing Script` |
| dd54236c | 1 | 7 | Script:About | destroy | R2 | listed name or under HD Admin | `Workspace.HD Admin.About` |
| dfc4dbb7 | 1 | 226 | ModuleScript:Settings | destroy | R2 | listed name or under HD Admin | `Workspace.HD Admin.Settings` |
| 57907899 | 1 | 14 | Script:Loader | destroy | R1 | R1: HD Admin Loader: require(3239236979) (remote module) | `Workspace.HD Admin.Settings.Loader` |
| 6e5c0227 | 1 | 72 | ModuleScript:Commands | destroy | R2 | listed name or under HD Admin | `Workspace.HD Admin.CustomFeatures.Server.Modules.Commands` |
| e6d59128 | 1 | 42 | ModuleScript:ClientCommands | destroy | R2 | listed name or under HD Admin | `Workspace.HD Admin.CustomFeatures.Client.Modules.ClientCommands` |
| b95867ff | 1 | 31 | ModuleScript:Events | destroy | R2 | listed name or under HD Admin | `Workspace.HD Admin.CustomFeatures.Client.SharedModules.Events` |
| f7966ede | 1 | 12 | LocalScript:SoundScript V2 | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Screen.SoundScript V2` |
| ffbd0d3e | 2 | 2 | Script:TheFix | destroy | R2 | listed name or under HD Admin | `Workspace.x6m.DriveSeat.Screen.SoundScript V2.TheFix` |
| 7f0f42c0 | 1 | 8 | LocalScript:FOV | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Screen.FOV` |
| d983599a | 1 | 31 | Script:Gui Giver | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Gui Giver` |
| 1a8689c7 | 3 | 12 | Script:Control | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.HornLaunch.Control` |
| c186847d | 1 | 19 | LocalScript:Horn | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.HornLaunch.Control.G.Horn` |
| a26e8455 | 1 | 19 | LocalScript:Horn | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.HornRev.Control.G.Horn` |
| abc28461 | 1 | 19 | LocalScript:Horn | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Horn.Control.G.Horn` |
| e093ea22 | 1 | 24 | Script:Speedometer V3 | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Speedometer V3` |
| acbb48eb | 1 | 12 | LocalScript:SpeedGUIScript | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Speedometer V3.speedo.SpeedMeter.SpeedGUIScript` |
| 85dd9e6b | 3 | 15 | Script:Control | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Brake.Control` |
| fdb0a21e | 1 | 20 | LocalScript:Lights3 | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Brake.Control.G.Lights3` |
| baed9de4 | 1 | 18 | LocalScript:Lights3 | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Left.Control.G.Lights3` |
| c5ec9f26 | 1 | 18 | LocalScript:Lights3 | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.DriveSeat.Right.Control.G.Lights3` |
| 146e8c81 | 1 | 254 | ModuleScript:A-Chassis Tune | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune` |
| 23c71918 | 1 | 636 | LocalScript:Drive | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.A-Chassis Interface.Drive` |
| 621a4798 | 1 | 5 | LocalScript:LocalScript | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.A-Chassis Interface.Handbrake.LocalScript` |
| 3d05c502 | 1 | 9 | LocalScript:LocalScript | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.A-Chassis Interface.Warn.LocalScript` |
| d8ba3689 | 1 | 219 | ModuleScript:README | destroy | R2 | listed name or under HD Admin | `Workspace.x6m.A-Chassis Tune.README` |
| 5e2b60da | 1 | 32 | LocalScript:AC6_MSteer_Camera | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.AC6_MSteer_Camera` |
| 76de6f57 | 1 | 28 | LocalScript:Smoke [FE+] | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Smoke [FE+]` |
| 2d90e20e | 1 | 31 | Script:Handler | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Smoke [FE+].Smoke_FE.Handler` |
| 8df19d77 | 1 | 197 | LocalScript:Simulated | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.[SS6] Dynamic Friction.Simulated` |
| e810e523 | 1 | 50 | LocalScript:AC6_Stock_Sound | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.AC6_Stock_Sound` |
| b3c355a2 | 1 | 54 | Script:Handler | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.AC6_Stock_Sound.AC6_FE_Sounds.Handler` |
| 5234c18b | 1 | 50 | LocalScript:AC6_SOUND_IDLE | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.AC6_SOUND_IDLE` |
| 7d27107e | 1 | 43 | Script:Handler | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.AC6_SOUND_IDLE.AC6_FE_Sounds.Handler` |
| b64fa29d | 1 | 21 | LocalScript:Ignition | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Ignition` |
| f7d5d1cc | 1 | 76 | LocalScript:Backfire [FE+] | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Backfire [FE+]` |
| fcb6fd77 | 1 | 46 | Script:Handler | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Backfire [FE+].Backfire_FE.Handler` |
| aecada8c | 1 | 269 | LocalScript:Lights | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Lights [FE+].Lights` |
| 998d689a | 1 | 59 | Script:Handler | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Lights [FE+].Lights_FE.Handler` |
| 60241df1 | 1 | 4 | Script:TimeScript | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.Time.TimeLable.TimeScript` |
| f53086b2 | 1 | 38 | LocalScript:AC6_First_Person_Gauges | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.AC6_First_Person_Gauges` |
| 111915ad | 1 | 80 | LocalScript:FirstPerson | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Plugins.FirstPerson` |
| 9860f4cc | 1 | 637 | Script:Initialize | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Initialize` |
| 76308646 | 1 | 49 | ModuleScript:MiscWeld | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.A-Chassis Tune.Initialize.MiscWeld` |
| 9d1a6c7b | 4 | 8 | Script:Player Positioner | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.Body.Seat.Player Positioner` |
| d4921ca6 | 4 | 178 | LocalScript:L | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.Body.Seat.Player Positioner.L` |
| 1cfc7478 | 3 | 16 | Script:Script | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.Body.whole int ok.Dials.Neon Dials.Script` |
| 4aa26aeb | 1 | 22 | Script:_main | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.Body.Brakes._main` |
| b292db1d | 2 | 37 | Script:Weld 2.1 | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.Body.Racing Seat.Weld 2.1` |
| 65b527e5 | 1 | 7 | Script:TimeScript | destroy | R3 | inside a vehicle model (x6m / Body) holding a VehicleSeat/DriveSeat | `Workspace.x6m.Body.Dash.DashSc.G.TimeScript` |
| 11df8812 | 1 | 584 | LocalScript:Animate | destroy | R5 | default Animate in a Rig (NPCs come from FPS System) | `Workspace.Rig.Animate` |
| 79680048 | 1 | 63 | Script:Settings | quarantine | R8 | moving platform / lift settings + logic (63+ lines) | `Workspace.Moving Platform Folder (open for settings).Settings` |
| 77b4bed9 | 1 | 29 | Script:Day/Night Cycle | quarantine | R7 | lighting / time of day, decided in phase 2 | `Workspace.Day/Night Cycle` |
| 0c304152 | 13 | 6 | Script:Animation | destroy | R8 | plays an idle animation on a worker NPC (inside a tycoon piece) | `Workspace.Stainless Scraps.Decoration.Stainless Scrap Producer.Worker.Animation` |
| 55e96c38 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Stainless Scraps.DropperConfig` |
| 79a595f0 | 3 | 49 | Script:OwnerOnlyDoorScript | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Back Door.OwnerOnlyDoorScript` |
| f302dcf9 | 27 | 28 | Script:Script | quarantine | R8 | proximity door: opens and closes a door | `Workspace.Back Door.Proximity Door.DoorNoHandle.door.Script` |
| 5ce957e6 | 87 | 5 | Script:Script | destroy | R8 | REVIEW: cosmetic label sync loop on Clothing Shelf | `Workspace.Clothing Shelf.Name.InformationLabel.Script` |
| 5d057755 | 87 | 5 | Script:Script | destroy | R8 | REVIEW: cosmetic label sync loop on Clothing Shelf | `Workspace.Clothing Shelf.Price.Frame.Frame.Price.Script` |
| 1450ba74 | 3 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Classic Outfit.ClickPart.Script` |
| c5dfba66 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Mercenary Outfit.ClickPart.Script` |
| dc3fba6a | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Guard Outfit.ClickPart.Script` |
| 0fabba0c | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Coordinator Outfit.ClickPart.Script` |
| ee09ba06 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Theif Outfit.ClickPart.Script` |
| 3134ba12 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Bandit Outfit.ClickPart.Script` |
| 96e63efe | 23 | 6 | Script:Animation | destroy | R8 | plays an idle animation on a bartender/NPC rig | `Workspace.Bartenders.Barista.Animation` |
| 3dd4cae7 | 1 | 23 | Script:Script | quarantine | R8 | barista ProximityPrompt: deducts realstats.Cash and gives a Drink tool from ServerStorage.Bar | `Workspace.Bartenders.Barista.ProxPart.ProximityPrompt.Script` |
| a445ba60 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Ranger Outfit.ClickPart.Script` |
| 52c7ba18 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Camo Outfit.ClickPart.Script` |
| d7a7ba02 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Thug Outfit.ClickPart.Script` |
| 0fa1ba0c | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Brawler Outfit.ClickPart.Script` |
| 8819a551 | 1 | 62 | Script:Script | quarantine | R8 | uniform giver (ClickPart prompt): sets shirt/pants, sets MaxHealth 5600; 62 lines. Only 1450ba74 read in full; Mercenary/Guard differ from it on lines 20-21 only; other outfit scripts same length, assumed ID-only differences | `Workspace.Punk Outfit.ClickPart.Script` |
| dae14329 | 1 | 5 | ModuleScript:PartCollectorConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.PartCollectingArea.PartCollector.PartCollectorConfig` |
| 8be16c93 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Sparkling Power Water.DropperConfig` |
| 05f16c77 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Sparkling Speed Water.DropperConfig` |
| 0df56c77 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Sparkling Water.DropperConfig` |
| a657730b | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Scraps.DropperConfig` |
| 82381af1 | 1 | 5 | ModuleScript:CurrencyCollectorConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.CurrencyCollector.Giver.CurrencyCollectorConfig` |
| 64a1fd8c | 2 | 21 | ModuleScript:UpgraderConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Bar Moulder.UpgraderConfig` |
| 04f96cd0 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Gold Scraps.DropperConfig` |
| b54c6ca1 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Graphite Scraps.DropperConfig` |
| d5816ca9 | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Platinum Scraps.DropperConfig` |
| a3f06c9a | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Titanium Scraps.DropperConfig` |
| a6676c4b | 1 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Scrap Worker.DropperConfig` |
| 7eef5ef5 | 1 | 10 | Script:TeleportHandler | quarantine | R8 | elevator: ProximityPrompt teleports the player (MoveTo) to destination | `Workspace.Elevator.Elevator.Teleporters.TeleportHandler` |
| ec1b6ccb | 2 | 30 | ModuleScript:DropperConfig | destroy | R4 | tycoon kit config/door script (kit not used) | `Workspace.Diamond Scraps.DropperConfig` |
| 4baaef1e | 1 | 68 | Script:Graphics  Script- ServerScriptService | quarantine | R7 | lighting / time of day, decided in phase 2 | `ServerScriptService.Graphics  Script- ServerScriptService` |
| 215e4e4a | 5 | 1 | Script:ClientReplicator | destroy | R1 | R1: ClientReplicator: obfuscated getfenv call that runs a numeric require when not in Studio (backdoor) | `ServerScriptService.ClientReplicator` |
| 215c240e | 1 | 3 | LocalScript:FirstPersonPhotoMode | quarantine | R7 | lighting / time of day, decided in phase 2 | `StarterGUI.FirstPersonPhotoMode` |
| ad276660 | 1 | 16 | Script:Script | quarantine | R7 | lighting / time of day, decided in phase 2 | `StarterGUI.TImeScripts.SunRays.Script` |
| a77abd64 | 1 | 27 | Script:Script | quarantine | R7 | lighting / time of day, decided in phase 2 | `StarterGUI.TImeScripts.TimeSelection.BackGround.Script` |
| af5859fc | 2 | 12 | LocalScript:LocalScript, Script:MainLighting | quarantine | R7 | lighting / time of day, decided in phase 2 | `Lighting.MainLighting` |
| b3096fc7 | 1 | 11 | Script:DayCycleRotation | quarantine | R7 | lighting / time of day, decided in phase 2 | `Lighting.DayCycleRotation` |

## Must-anchor list (R6 parents; all inside the car)

- `Workspace.x6m.A-Chassis Tune.Initialize`
- `Workspace.x6m.Body.Racing Seat.Weld 2`
- plus the whole vehicle: `Workspace.x6m` (its scripts are destroyed under R3; it stays as an anchored prop)

## Review gate changes (applied)
- 1f2d341c, 5ce957e6, 5d057755 -> destroy. Destroy groups now 82.
- Quarantine handling: R7 rows (8) move to ServerStorage.CityQuarantine.Scripts, Enabled=false, OriginalPath; other quarantine rows disabled in place with QuarantinedScript=true. CSV column `action` records this.
- HD Admin: destroy the whole Workspace.HD Admin folder.
