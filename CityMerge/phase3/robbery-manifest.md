# Robbery System manifest

Measured 2026-11-16 from `Robbery System.rbxl` (window resolved by name, Edit; Play only for the suite in `spec-baseline.md`; nothing changed or saved). Machine-readable script list: `robbery-manifest.tsv` (root, relative path, class, enabled, adler32; Adler-32 over the script `Source` bytes; `Enabled` is `n/a` for ModuleScripts; names are not unique inside a root, e.g. two `Bank Clerk` rigs give two identical `Animate` rows).

**Totals:** 56 roots, 34,115 instances (roots plus descendants), 133 LuaSourceContainers (a root that is itself a script counts as 1), 2,880,020 serialized Base64 bytes. Every root exported to the transfer store as `rob__<index>__<name>.b64` (keys in the table; the index follows service order below, with `StarterPlayerScripts` / `StarterCharacterScripts` children last). Excluded as the brief says: `Workspace.Terrain`, `Workspace.Camera`. Not present in the Robbery place: `ReplicatedFirst`, `Teams` and `SoundService` have no children; `StarterPlayerScripts` holds 6 LocalScripts, `StarterCharacterScripts` 3 Sounds.

Robbery `Workspace` descendants (whole place, Edit) = 32,643.

## Roots

Descendants exclude the root. "Scripts" counts the root if it is a script.

| # | Root | Class | Descendants | Scripts | Serialized bytes (Base64) | Store key |
|---|---|---|---|---|---|---|
| 1 | Workspace/Baseplate | Part | 1 | 0 | 5396 | rob__1__Baseplate.b64 |
| 2 | Workspace/SpawnLocation | SpawnLocation | 1 | 0 | 5476 | rob__2__SpawnLocation.b64 |
| 3 | Workspace/Bank | Model | 4526 | 2 | 351624 | rob__3__Bank.b64 |
| 4 | Workspace/BankVault | Model | 7865 | 2 | 242132 | rob__4__BankVault.b64 |
| 5 | Workspace/HeistZones | Folder | 6 | 0 | 4896 | rob__5__HeistZones.b64 |
| 6 | Workspace/HeistMarkers | Folder | 17 | 0 | 16868 | rob__6__HeistMarkers.b64 |
| 7 | Workspace/SlowFoods | Model | 6912 | 4 | 362036 | rob__7__SlowFoods.b64 |
| 8 | Workspace/SlowFoodsZones | Folder | 2 | 0 | 4488 | rob__8__SlowFoodsZones.b64 |
| 9 | Workspace/SlowFoodsMarkers | Folder | 6 | 0 | 15972 | rob__9__SlowFoodsMarkers.b64 |
| 10 | Workspace/Gas2Go | Model | 6445 | 0 | 250532 | rob__10__Gas2Go.b64 |
| 11 | Workspace/Gas2GoZones | Folder | 2 | 0 | 4464 | rob__11__Gas2GoZones.b64 |
| 12 | Workspace/Gas2GoMarkers | Folder | 6 | 0 | 15956 | rob__12__Gas2GoMarkers.b64 |
| 13 | Workspace/Animation Tool | LocalScript | 0 | 1 | 1508 | rob__13__Animation_Tool.b64 |
| 14 | Workspace/Illegal Supplier | Model | 293 | 1 | 58604 | rob__14__Illegal_Supplier.b64 |
| 15 | Workspace/NewsStation | Model | 6519 | 0 | 438844 | rob__15__NewsStation.b64 |
| 16 | Workspace/NewsStationZones | Folder | 2 | 0 | 4492 | rob__16__NewsStationZones.b64 |
| 17 | Workspace/NewsStationMarkers | Folder | 6 | 0 | 15980 | rob__17__NewsStationMarkers.b64 |
| 18 | ReplicatedStorage/HeistShared | Folder | 390 | 4 | 92580 | rob__18__HeistShared.b64 |
| 19 | ReplicatedStorage/SharedSystems | Folder | 10 | 10 | 75328 | rob__19__SharedSystems.b64 |
| 20 | ReplicatedStorage/RestaurantShared | Folder | 330 | 2 | 63156 | rob__20__RestaurantShared.b64 |
| 21 | ReplicatedStorage/Gas2GoShared | Folder | 1 | 1 | 4552 | rob__21__Gas2GoShared.b64 |
| 22 | ReplicatedStorage/NewsStationShared | Folder | 306 | 2 | 55800 | rob__22__NewsStationShared.b64 |
| 23 | ReplicatedStorage/Modules | Folder | 3 | 3 | 10216 | rob__23__Modules.b64 |
| 24 | ReplicatedStorage/UI | Folder | 4 | 4 | 22008 | rob__24__UI.b64 |
| 25 | ReplicatedStorage/DialogModule | ModuleScript | 3 | 1 | 13888 | rob__25__DialogModule.b64 |
| 26 | ServerScriptService/Heist | Folder | 68 | 65 | 337712 | rob__26__Heist.b64 |
| 27 | ServerScriptService/PlayerData | Folder | 4 | 4 | 8464 | rob__27__PlayerData.b64 |
| 28 | ServerScriptService/HeistServer | Script | 0 | 1 | 33632 | rob__28__HeistServer.b64 |
| 29 | ServerScriptService/SlowFoodsServer | Script | 0 | 1 | 8428 | rob__29__SlowFoodsServer.b64 |
| 30 | ServerScriptService/Gas2GoServer | Script | 0 | 1 | 9848 | rob__30__Gas2GoServer.b64 |
| 31 | ServerScriptService/SuppliesServer | Script | 0 | 1 | 6904 | rob__31__SuppliesServer.b64 |
| 32 | ServerScriptService/NewsStationServer | Script | 0 | 1 | 13900 | rob__32__NewsStationServer.b64 |
| 33 | ServerStorage/GuardTemplate | Model | 196 | 0 | 28632 | rob__33__GuardTemplate.b64 |
| 34 | ServerStorage/RBX_ANIMSAVES | Model | 3 | 0 | 2020 | rob__34__RBX_ANIMSAVES.b64 |
| 35 | StarterGui/LockpickGui | ScreenGui | 14 | 0 | 20760 | rob__35__LockpickGui.b64 |
| 36 | StarterGui/HackCodeGui | ScreenGui | 9 | 0 | 19664 | rob__36__HackCodeGui.b64 |
| 37 | StarterGui/WordScrambleGui | ScreenGui | 14 | 0 | 20412 | rob__37__WordScrambleGui.b64 |
| 38 | StarterGui/NotificationGui | ScreenGui | 7 | 0 | 12652 | rob__38__NotificationGui.b64 |
| 39 | StarterGui/DuffelUpgradeGui | ScreenGui | 8 | 0 | 15876 | rob__39__DuffelUpgradeGui.b64 |
| 40 | StarterGui/QuestResponsesGui | BillboardGui | 12 | 0 | 17016 | rob__40__QuestResponsesGui.b64 |
| 41 | StarterPack/PlaceholderPistol_TODO_ReplaceWithRealAsset | Tool | 1 | 0 | 5140 | rob__41__PlaceholderPistol_TODO_ReplaceWithRealAsset.b64 |
| 42 | StarterPack/tommy gun | Tool | 67 | 16 | 85648 | rob__42__tommy_gun.b64 |
| 43 | Lighting/Sky | Sky | 0 | 0 | 1944 | rob__43__Sky.b64 |
| 44 | Lighting/SunRays | SunRaysEffect | 0 | 0 | 868 | rob__44__SunRays.b64 |
| 45 | Lighting/Atmosphere | Atmosphere | 0 | 0 | 1032 | rob__45__Atmosphere.b64 |
| 46 | Lighting/Bloom | BloomEffect | 0 | 0 | 916 | rob__46__Bloom.b64 |
| 47 | Lighting/DepthOfField | DepthOfFieldEffect | 0 | 0 | 1012 | rob__47__DepthOfField.b64 |
| 48 | StarterPlayerScripts/HeistClient | LocalScript | 0 | 1 | 46488 | rob__48__HeistClient.b64 |
| 49 | StarterPlayerScripts/WordScrambleClient | LocalScript | 0 | 1 | 12912 | rob__49__WordScrambleClient.b64 |
| 50 | StarterPlayerScripts/NotificationClient | LocalScript | 0 | 1 | 7432 | rob__50__NotificationClient.b64 |
| 51 | StarterPlayerScripts/UiButtonEffects | LocalScript | 0 | 1 | 8252 | rob__51__UiButtonEffects.b64 |
| 52 | StarterPlayerScripts/SupplierDialogueController | LocalScript | 0 | 1 | 5824 | rob__52__SupplierDialogueController.b64 |
| 53 | StarterPlayerScripts/PromptUiController | LocalScript | 0 | 1 | 4868 | rob__53__PromptUiController.b64 |
| 54 | StarterCharacterScripts/DuffelInitiateSound | Sound | 0 | 0 | 1656 | rob__54__DuffelInitiateSound.b64 |
| 55 | StarterCharacterScripts/DuffelFullSound | Sound | 0 | 0 | 1652 | rob__55__DuffelFullSound.b64 |
| 56 | StarterCharacterScripts/CashOutSuccessSound | Sound | 0 | 0 | 1660 | rob__56__CashOutSuccessSound.b64 |

## Place settings

| Item | Value |
|---|---|
| `Workspace.StreamingEnabled` | true (radii not recorded for the Robbery place; city: 128 min / 512 target, `first-run.md`) |
| `PhysicsService` collision groups | 1: `Default` (mask -1). The city has only `Default` too. Nothing to carry. |
| `SpawnLocation`s | 1: `Workspace.SpawnLocation`, `Enabled = true`, position (-33.0, 2.81, -240.8). No other SpawnLocation in the place. |

## CollectionService tags in use (count > 0)

Tags that belong to the place content (all robbery-only by name in the city, except `NPCprompt`):

| Tag | Count | Tag | Count | Tag | Count |
|---|---|---|---|---|---|
| BankClerk | 2 | Gas2GoAccessBarrier | 27 | NewsStationOilHazard | 15 |
| BankRegister | 3 | Gas2GoBarrel | 2 | NewsStationRegister | 2 |
| BankSafe | 2 | Gas2GoRegister | 2 | NewsStationSafe | 3 |
| CashRegister | 4 | Gas2GoATM | 1 | NewsStationZone | 1 |
| Cashier | 3 | Gas2GoZone | 1 | NewsStationExitSpawn | 1 |
| CounterBarrier | 4 | Gas2GoExitSpawn | 1 | NewsStationCamera | 2 |
| HeistATM | 2 | SlowFoodsAccessBarrier | 3 | NewsStationATM | 1 |
| HeistAccessBarrier | 1 | SlowFoodsSupplyBox | 2 | NewsStationAccessBarrier | 2 |
| HeistBank | 2 | SlowFoodsZone | 1 | NPCSpawner | 9 |
| HeistC4Point | 1 | SlowFoodsExitSpawn | 1 | NPCprompt | 1 (city: 6) |
| HeistCoverPoint | 6 | HeistGate | 5 | Weapon | 1 |
| HeistDeathVolume | 1 | HeistGuardPost | 4 | HeistLaser | 16 |
| HeistExitSpawn | 1 | HeistTeleporter | 2 | HeistTerminal | 2 |
| HeistZone | 5 | ThreeDTextObject | 13 | ThreeDTextObjectBoundingBox | 13 |

`ThreeDTextObject*` are all under `Workspace` (plugin text objects, 13 each; city has 27 of its own). `Weapon` is on `StarterPack.PlaceholderPistol_TODO_ReplaceWithRealAsset` only (not on the tommy gun).

Studio / plugin tags (live on `CoreGui` and `PluginGuiService` instances, not place content): `Theme_Accent` 17, `Theme_GridItem` 50, `Theme_PlaceHolder` 84, `Theme_Primary` 34, `Theme_PrimaryText` 263, `Theme_Secondary` 36, `Theme_SecondaryText` 69, `RigEdit` 6, `VFXStudio_ThemeableUI` 3, `gui-object-defaults` 1, `size-full` 1, `data-testid=--studio-foundation--stylesheet-wrapper` 1; with count 0: `_BrushtoolBrushed`, `TagEditorTagContainer`, `_RigEditor_RiggingTemp_`, `_RigScaler_RiggingTemp_`. The same counts exist in the city (same Studio session tooling).

## Not recorded

`StreamingMinRadius` / `StreamingTargetRadius` of the Robbery place; per-property diff of `StarterGui.QuestResponsesGui` against the city's.

## Store

Transfer store: `CityMerge/transfer/server.py` on 127.0.0.1:8765, root directory in the session scratchpad (path in the Task 1 report), `rob__*` exports in it. It also holds scratch files from this run (`robtsv.txt`, `citytsv.txt`, `rob_*.lua`, part dumps) and older `src.*` files from phase 2a.
