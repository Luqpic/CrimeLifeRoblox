# After import: FPS services in the city (Task 2)

Measured 2026-11-15 in `Crimelife city.rbxl` (Edit). Source `FPS System.rbxl` was only read.

## Before
Empty: ReplicatedStorage, ServerScriptService, StarterPlayerScripts, StarterCharacterScripts, SoundService. ServerStorage: TerrainSaveData (1), CityQuarantine (143,382 incl. itself), HQ (58,283). StarterGui: `TImeScripts` (43). No name collisions, so nothing moved to PreImportLeftovers (folder not created).

## Imported (78 roots, 5,939 instances incl. roots, 197 scripts)
ReplicatedStorage 18, ServerScriptService 16, ServerStorage 9, StarterGui 3, StarterPlayerScripts 25, StarterCharacterScripts 6, SoundService 1. Every root carries `ImportedFrom = "FPS System"`; no duplicate names in any container. Heavy roots (Blaster, EnemyTemplates, Weapons) one per call, connection confirmed after each.

## Verification (by program)
- Script rows: `city-manifest.tsv` vs `fps-manifest.tsv` minus the 2 Workspace rows (sorted): 197 compared, 197 equal, `diff` empty.
  `diff <(sort fps-manifest-without-Workspace) <(sort city-manifest.tsv)` printed nothing.
- Per-root descendants and script counts vs manifest table rows 1-78: equal for all 78 (diff empty).
- Tags inside imported roots: Blaster 21, 1788975189 1, Assistant:68432017... 1, Assistant:fd7caafa... 1. The same restricted count read from FPS gives the identical four. The manifest's "in roots" column also counts the Workspace roots (EnemySpawnPoint 6, NPCprompt 6, Target 7, Assistant:68432017 3 vs 1 here), which Task 3 imports.
- `ServerScriptService.UnitTestRunner.Disabled` = true.

## Settings (FPS values read first, equal to the plan list)
CameraMaxZoomDistance 128 -> 30; CharacterWalkSpeed 16 -> 25; CharacterUseJumpPower false -> false; CharacterJumpHeight 7.2 -> 7.2; EnableMouseLockOption true -> true; LoadCharacterAppearance true -> true; Players.RespawnTime 3 -> 3; Workspace.FallenPartsDestroyHeight -500 -> -500. None refused.

## Invariants
StreamingEnabled true; Workspace.Map, Plots (8 children), Ground, TycoonPreview present; Workspace 166,574 descendants, 7 children (unchanged); CityQuarantine 143,381 descendants and HQ 58,282 (unchanged from before).

## Tool fix
`import.luau` now errors (after destroying the results) unless exactly one root is deserialized. The three dry-run behaviours (collision error, `ImportedFrom` stamp, clear 404 error) were confirmed first on `UpdateRunningState`.

NOT saved / NOT published

# After import: Workspace gameplay anchors (Task 3)

Measured 2026-11-15 in `Crimelife city.rbxl` (Edit). `FPS System.rbxl` only read. Nothing saved or published.

## Pre-checks
- Height: city `Workspace.Ground.Baseplate` top Y = 0.000 (pos (0,-8,0), size 2048x16x2048); FPS Baseplate top Y = 0.00. No Y shift.
- Plate footprints from CFrame and Size (AABB): Plot7 x[540,901] z[-357,-57]; Plot8 x[364,725] z[79,379].
- Clash check before importing (boxes from the manifest, bottom raised 0.1; `GetPartBoundsInBox`, OverlapParams Include only `Workspace.Map` and `Workspace.TycoonPreview`; `Ground` excluded). Tested: Quests, Targets, Map, UI, Part, SpawnLocation, and each of the 6 enemy spawn points separately. All 12 boxes: inside |x|,|z| <= 1024, 0 Map/TycoonPreview parts, no intersection with Plot7/Plot8. No clash, no X shift for any root.

## Imported (10 roots, 2,049 instances incl. roots, plus the `Dev` folder)
`Workspace`: EnemySpawns (12 descendants), Quests (1,892), Targets (105), AnimVM (0), "Accessory Storage" (0). `Workspace.Dev` (Folder, `ImportedFrom`): FpsMap (23, from Map), UI (5), Part (1), Model (0), DevSpawn (1, from SpawnLocation, `Enabled = false`). Every root and `Dev` carries `ImportedFrom = "FPS System"`. Descendant counts equal the manifest for all 10 (2,039 descendants + 10 roots).

## Verification (by program)
- Script rows: `city-manifest.tsv` vs `fps-manifest.tsv`, both complete, sorted. Only normalisation: `Workspace/Dev/UI` -> `Workspace/UI` in the city file (sed on the root column; the other Workspace root, Quests, keeps its name). `diff` printed nothing. Lines compared 200 (header + 199 script rows), lines equal 200 (`comm -12` = 200). Covers all 88 roots.
- Tags inside imported roots (all 88 roots): Blaster 21, EnemySpawnPoint 6, NPCprompt 6, Target 7, 1788975189 1, Assistant:68432017... 3, Assistant:fd7caafa... 1. Equal to the manifest "in roots" column; RigEdit, WeaponPickup, Theme_* 0 as in the manifest. 0 mismatches.
- Pivot (PVInstance roots) or part bounding box (folders), city vs manifest: EnemySpawns (-185.6,0,-204.1)-(267.2,1,327.9); Quests (-22.2,0,36.2)-(-5.4,5.8,58.3); Targets (-30.5,0,-5.4)-(26.5,14.7,109); FpsMap (-32,0,-9)-(32,16,111); UI pivot (-66.2,0.5,10.8), Part pivot (-67.556,0.225,2.296) with FPS CFrame rotation, DevSpawn pivot (12,0.5,51) all equal the FPS values read from FPS (shift 0). 0 mismatches.

## SpawnLocations in the whole place
| path | position | Enabled |
|---|---|---|
| Workspace.SpawnLocation (city) | (-11.00, 1.50, 2498.75) | true |
| Workspace.Dev.DevSpawn | (12.00, 0.50, 51.00) | false |
| ServerStorage.CityQuarantine.LooseTycoon.TycoonSpawn | (644.93, 3.89, 557.18) | true |
Imported roots contain no other SpawnLocation. The third is not imported and not active (it sits in `ServerStorage`, inside `CityQuarantine`, which the plan says stays untouched), so it was not changed. In the world exactly one SpawnLocation is enabled (the city's). Open question for the developer: it will become a live spawn if `LooseTycoon` is ever moved into Workspace.

## Streaming
`Workspace.Dev` is a Folder, so no ModelStreamingMode. The slab is about 2,500 studs from the city spawn and is streamed out for a player there; intended.

## Probe (`CityCleanup/probe.luau`, unchanged; the Map and TycoonPreview lines come from extra read-only checks)
```
workspace_instances=168624
baseparts=122191  meshparts=17553  unions=7519
unanchored_parts=124
scripts_total=26  scripts_enabled=2
lights=1134  particle_emitters=39  decals_textures=8019
top_level_children=13
streaming_enabled=true
serverstorage_instances=205409
studio_memory=6.1GB
Map baseparts=97888 unanchored=0
TycoonPreview desc=47894
Plots children=8 Ground desc=2
```
- workspace_instances: 166,574 + 2,039 descendants + 10 roots + 1 (`Dev`) = 168,624. Measured 168,624.
- unanchored_parts 124 = unanchored BaseParts inside the imported roots as they are in FPS (Quests 113, FpsMap 9, UI 1, Part 1; read from FPS: 124). 0 elsewhere.
- scripts_enabled 2 = the two enabled Workspace scripts in the manifest (Quests Animate, UI Script). Top-level children 7 -> 13 (5 roots + Dev + the unchanged 7, minus none: 7+5+1).
- `Workspace.Map` 97,888 BaseParts, 0 unanchored; `TycoonPreview` 47,894 descendants; Plots 8 children; Ground 2 descendants; StreamingEnabled true.

## Screenshot
`CityMerge/screenshots/task3-slab.jpg`, camera (120,220,330) looking at (0,0,50). Flat grey baseplate to the horizon; near the centre the small test map (two grey ramps/platforms, red crates, small figures from the quest givers and targets, a round spawn pad) and two tiny specks far left and right (enemy spawn points). The Studio HUD (weapon, card, shield, cash, cart buttons, Cash 0) from the imported StarterGui overlays the left side.

Store stopped (port 8765 closed) and its data directory deleted.

NOT saved / NOT published

# Deviations from the FPS place

The import was byte-exact (Task 2/3). These are the deliberate edits made afterwards in the city only; the FPS place keeps the original.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-15 | `StarterPlayer.StarterCharacterScripts.Lean` (LocalScript) | 5,696 / 2478388517 (= FPS) | 5,970 / 3351089419 | In the city the character's `HumanoidRootPart` arrives after `Lean` starts (measured: Lean 0.032 s, HumanoidRootPart 0.071 s after `CharacterAdded`), so `character.HumanoidRootPart` at line 25 errored in every city Play. The three direct lookups (`Humanoid`, `HumanoidRootPart`, `LowerTorso`) now use `WaitForChild(name, 10)` and return quietly on nil; one comment line marks the change. Every other byte is unchanged (reverting the two spans reproduces the old source exactly). Known open bug from the FPS place (Open Items, 2026-09-24). |
| 2026-11-15 | `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` (LocalScript) | 54,021 / 1830119947 (= FPS) | 54,037 / 193228620 | Line 20 only: `require(script.Parent.SkinsCardController)` -> `require(script.Parent:WaitForChild("SkinsCardController"))`. In 2 of 3 city Plays the sibling module had not yet been copied into PlayerScripts, the script errored, and the weapon shop and skins card were never built. Attribute `CityMergeDeviation = "2026-11-15 waits for late-arriving instances"`. Audit of the whole class: `client-load-order-audit.md`. Mirror `FPSSystem/Cosmetics/WeaponaryShopController.luau` is a stale FPS mirror (49,960 bytes) and was not changed. |

The script carries the attribute `CityMergeDeviation = "2026-11-15 Lean waits for character parts"`. No repo mirror of `Lean` exists (`FPSSystem/` holds none; no file in the repo contains its source), so none was updated.

Remote ownership audit (phase 2b Task 2, `phase2b/remote-audit.md`), same columns:

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-15 | `ReplicatedStorage.Quests.QuestConfig` (ModuleScript) | 4,565 / 3617513536 (as imported) | 5,014 / 2874046250 | Remote audit (phase 2b Task 2): adds `MAX_INTERACT_DISTANCE = 30` (`max(30, W + 10)`, W = 10 = DialogModule walk-away range) and `withinReach(a, b)`. Used by QuestService; Task 3 keeps them. Test `QuestReach_Test`. `CityMergeDeviation = "2026-11-15 quest reach: MAX_INTERACT_DISTANCE and withinReach"`. |
| 2026-11-15 | `ServerScriptService.Quests.Scripts.QuestService` (Script) | 6,338 / 3020256532 (as imported) | 7,101 / 1546813160 | Remote audit: `AcceptQuestRequest` and `TurnInQuestRequest` were honoured from anywhere. One local `canReach` (alive, own HumanoidRootPart, giver HumanoidRootPart, `withinReach`); both handlers return early when false. `CityMergeDeviation = "2026-11-15 accept and turn-in require standing at the giver"`. |
| 2026-11-15 | `ServerScriptService.Blaster.Scripts.Blaster.validateShootArguments` (ModuleScript) | 1,004 / 2424007007 (as imported) | 1,274 / 3693592609 | Remote audit: `tonumber` folded "01", "1.0", "1e0" etc. onto ray 1, so one ray could be claimed (and damage dealt) many times per Shoot. Every claimed key must now equal `tostring(tonumber(key))`, the client's own spelling (BlasterController 164). Test `BlasterGuard_Test`. `CityMergeDeviation = "2026-11-15 claimed hit keys must be canonical, one per ray"`. |
| 2026-11-15 | `ServerScriptService.Blaster.Scripts.Blaster.validateShot` (ModuleScript) | 2,012 / 2386274073 (as imported) | 2,902 / 3565084835 | Remote audit: no server rate of fire existed. Last check: per player and per weapon NAME (fix round 1: keyed by Tool instance, a fresh Tool from SetLoadoutSlotRequest restarted the clock), a shot is refused when its claimed timestamp is less than 0.9 x `60 / rateOfFire` after the last accepted shot's; state cleared on PlayerRemoving. `CityMergeDeviation = "2026-11-15 server rate of fire on claimed timestamps"`. |
| 2026-11-15 | `ServerScriptService.Blaster.Scripts.Blaster.validateFireInterval` (ModuleScript, NEW) | (absent in FPS) | 1,147 / 2461960568 | Remote audit: the pure rate-of-fire rule `validateShot` calls, so the test can call it. Test `ShotRate_Test`. `CityMergeDeviation = "2026-11-15 new: pure rate-of-fire rule for validateShot"`. |
| 2026-11-15 | `ServerScriptService.Weapons.Scripts.LevelingService` (Script) | 11,048 / 2525621758 (as imported) | 11,110 / 284623911 | Remote audit: `SetLevelRequest` (admin only) let NaN through `math.floor` and `math.clamp` into Level and the save. Line 34 now also refuses `targetLevel ~= targetLevel`. `CityMergeDeviation = "2026-11-15 SetLevelRequest refuses NaN"`. |

New test case modules (city only, exported to `CityScripts/`): `ServerStorage.UnitTest.Cases.QuestReach_Test` (788 / 4199154368), `BlasterGuard_Test` (1,294 / 2229383301), `ShotRate_Test` (1,272 / 1910810662).

Quest progress saved (phase 2b Task 3), same columns:

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-15 | `ReplicatedStorage.Persistence.Schema` (ModuleScript) | 2,636 / 926383738 (as imported) | 2,816 / 2680666850 | Adds `quests = {}` (`[questId] = { state, progress }`) and `questCompletions = {}` (`[questId] = count`) to the template; `VERSION` stays 3 (Reconcile fills them). `CityMergeDeviation = "2026-11-15 quests and questCompletions fields (quest progress saved)"`. |
| 2026-11-15 | `ReplicatedStorage.Quests.QuestConfig` (ModuleScript) | 5,014 / 2874046250 (Task 2) | 6,674 / 3462569414 | Adds pure `QuestConfig.restore(savedQuests, savedCompletions)`: drops unknown ids, bad states and bad entries, clamps progress, Accepted at target becomes ReadyToTurnIn, keeps whole completions >= 1, returns new tables. Test `QuestSave_Test`. Attribute appended: `"...; 2026-11-15 restore() for saved quest state"`. |
| 2026-11-15 | `ServerScriptService.Quests.Scripts.QuestService` (Script) | 7,101 / 1546813160 (Task 2) | 8,577 / 3078525795 | Quest state was session-only. Requires `ProfileGateway`; local `save(player, questId)` mirrors the entry and completions after accept, each counted kill and turn-in; local `hydrate` (WeaponUpgradeService shape) restores through `QuestConfig.restore` and publishes every quest's attributes; `safePlayerAdded` keeps a table the hydrator already set. `canReach` kept. Attribute appended: `"...; 2026-11-15 quest state saved through ProfileGateway"`. |
| 2026-11-15 | `ServerStorage.UnitTest.Cases.Schema_Test` (ModuleScript) | 3,688 / 1558435936 | 3,768 / 4116836260 | `quests`, `questCompletions` added to both field lists. `CityMergeDeviation = "2026-11-15 quests and questCompletions in the field lists"`. |
| 2026-11-15 | `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` (ModuleScript) | 18,152 / 2120294281 | 19,046 / 4287975109 | New case "quest progress written before the bind is not saved, and a restored quest wins". `CityMergeDeviation = "2026-11-15 case: quest progress before the bind is not saved, restore wins"`. |

New test case module: `ServerStorage.UnitTest.Cases.QuestSave_Test` (1,915 / 731278334), `CityMergeDeviation = "2026-11-15 new: QuestConfig.restore rules"`. All six sources exported to `CityScripts/`; on-disk Adler-32 equals the place.

Quest restore does not replay the completion toast (phase 2b Task 3, fix round 1), same columns:

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-15 | `ReplicatedStorage.Quests.QuestConfig` (ModuleScript) | 6,674 / 3462569414 | 6,900 / 1331490080 | One constant `RESTORED_ATTRIBUTE = "QuestsRestored"` shared by server and client. Attribute appended: `"...; 2026-11-15 RESTORED_ATTRIBUTE"`. |
| 2026-11-15 | `ServerScriptService.Quests.Scripts.QuestService` (Script) | 8,577 / 3078525795 | 8,992 / 2852790903 | `hydrate` resets `profile.Data.quests` / `questCompletions` to `{}` only when not a table, and sets `QuestsRestored = true` last. Attribute appended: `"...; 2026-11-15 hydrate sets QuestsRestored last, resets non-table quest fields"`. |
| 2026-11-15 | `StarterPlayer.StarterPlayerScripts.QuestFeedbackController` (LocalScript) | 3,283 / 1810268451 | 3,847 / 965953225 | Measured: hydration raising `Quest_Level1Thugs_Completions` 0 -> 1 showed a QUEST COMPLETE card and played the sound. A completions change seen while the script's own `questsRestored` flag (set from the attribute's changed signal, so same-frame changes keep their order) is false now only seeds the last-seen count. `CityMergeDeviation = "2026-11-15 completions seen before QuestsRestored are a seed, not a completion"`. |
| 2026-11-15 | `ServerStorage.UnitTest.Cases.QuestSave_Test` (ModuleScript) | 1,915 / 731278334 | 3,101 / 1803481558 | Four cases: Accepted at the target, ReadyToTurnIn with low progress, huge and infinite progress, Completed kept. Attribute appended. |

`QuestDialogueController` (line 132) reads the completions count for its dialogue text only; no celebration, so unchanged.

ScreenGuis moved to Sibling (phase 2b Task 4, `phase2b/zindex-audit.md`), same columns. Each edit is one line after the `Instance.new("ScreenGui")`: `<var>.ZIndexBehavior = Enum.ZIndexBehavior.Sibling` with the comment `-- Sibling: see UI Layout Traps, "ZIndexBehavior is a global on the ScreenGui"`. Each script carries `CityMergeDeviation = "2026-11-15 ScreenGui ZIndexBehavior Sibling (paint order unchanged, phase 2b Task 4)"`. `PromptUiController` is shared in spirit with the Robbery place; this is the city copy only.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-15 | `StarterPlayer.StarterPlayerScripts.PromptUiController` (LocalScript) | 5,248 / 1225139167 (as imported) | 5,379 / 932925811 | `PromptUiGui` paint order equal under Global and Sibling in every measurement (0 and 4 objects). |
| 2026-11-15 | `StarterPlayer.StarterPlayerScripts.AdminLevelController` (LocalScript) | 7,363 / 11968854 (as imported) | 7,491 / 3139161519 | `AdminLevelGui` equal (6 objects). |
| 2026-11-15 | `StarterPlayer.StarterPlayerScripts.DamageDirectionIndicator` (LocalScript) | 3,400 / 1750238707 (as imported) | 3,534 / 2728768684 | `DamageDirectionIndicator` equal (empty at rest; live arrows all `ZIndex` 1). |
| 2026-11-15 | `ReplicatedStorage.UI.CashBurst` (ModuleScript) | 5,163 / 2916064367 (as imported) | 5,292 / 1256638673 | `CashSpendBurst` equal (8 coins, all `ZIndex` 1). |

`StarterGui."Custom Inventory"`: `ZIndexBehavior` property checked and left `Global` (not order-equal: 123 swapped pairs); no property change made, no script of it touched. Left `Global` as well: `CashShopGui`, `GamepassShopGui`, `WeaponaryShopGui`, `QuestLogGui`, `DeathScreenGui` (reasons in `phase2b/zindex-audit.md`).

First-run leftovers (phase 2b Task 5), same columns:

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-15 | `StarterPlayer.StarterCharacterScripts.Lean` (LocalScript) | 5,970 / 3351089419 | 6,038 / 2152900123 | `lowerTorso.Root` and `humanoidRootPart.RootJoint` became `WaitForChild(name, 10)` with a quiet `return` when nil, matching the three lookups above them. Attribute appended: `"...; 2026-11-15 Root / RootJoint lookups wait instead of indexing (phase 2b Task 5)"`. Exported to `CityScripts/`; on-disk Adler-32 equals the place. |

Not a source change, same deviation record:

- `ServerScriptService.WeaponAnimationPreview` (Script): `Enabled` true -> false (source unchanged, 2,906 / 2351876902). `CityMergeDeviation = "preview rig folder is not in the city"`. It drives a Studio-only preview folder the city does not have. BaseScripts enabled 121 -> 120.
- `Workspace.FX`: new empty `Folder` (attribute `PlacedBy = "phase 2b"`). `StarterCharacterScripts.Crouching` parents its dust there; the script is not edited.

NOT saved / NOT published

# Phase 3 deviations from the Robbery place

Phase 3 Task 2 (2026-11-16): every `carry` root outside `Workspace` imported from the transfer store with `ImportedFrom = "Robbery System"`: 25 roots, 1,378 instances incl. roots, 94 scripts. All 94 imported scripts' Adler-32 equal `phase3/robbery-manifest.tsv` (diffed by program, 94 / 94). The 13 imported `Script` / `LocalScript`s have `Enabled = false` and `ImportEnabled = true` (their source value); Task 3 restores them. Afterwards: 423 source containers, 233 BaseScripts, 144 enabled (unchanged), Enabled checksum 4096731555, source checksum 3379933426; `Workspace` descendants 226,903 (unchanged); 1 enabled SpawnLocation (`Workspace.SpawnLocation`).

Edits after the import, same columns ("old" for an imported script is the Robbery value, equal to the manifest):

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-16 | `ServerScriptService.PlayerData.CurrencyService` (ModuleScript, NEW in the city) | (Robbery original not imported) | 2,062 / 3995652172 | Bridge (G4, `phase3/currency-api.md`): the Robbery `CurrencyAdapter` API (`Load`, `Get`, `Add`, `PendingCount`, `Save`, `FlushAll`, `Release`) as a singleton writing only `player.leaderstats.Cash` (`Add` floors, refuses non-numbers, NaN, infinite and <= 0 and returns the unchanged balance; no `leaderstats` or no player returns 0). Never creates `leaderstats`, never yields, no DataStore; `CashService`'s Value listener persists. Test seam `_playerFor` (default `Players:GetPlayerByUserId`). Its `PlayerData` Folder holds nothing else. `CityMergeDeviation = "bridge onto leaderstats.Cash; the Robbery save layer stays behind"`. Test `CurrencyBridge_Test`. |
| 2026-11-16 | `ReplicatedStorage.Modules.MenuFovBlur` (ModuleScript, city copy) | 1,831 / 3514199789 | 2,220 / 2299064013 | G7: `acquire()` added (the Robbery copy's lines, own comment); `open` / `close` unchanged. `CityMergeDeviation = "2026-11-16 acquire() added from the Robbery copy (phase 3 G7)"`. |
| 2026-11-16 | `ReplicatedStorage.SharedSystems.CashClaimVFX` (ModuleScript) | 13,210 / 4113373555 | 12,437 / 1758279696 | G5: no own `CashDisplay` ScreenGui. `_buildPersistentGui` now spawns a lookup of `PlayerGui["Custom Inventory"].cashDisplay` (`WaitForChild`, 10 s each, constructor does not block); `_render` is empty (the city's `CashHud` owns the readout); `_targetPosition(space)` returns the frame centre `AbsolutePosition + AbsoluteSize / 2` as an offset inside the burst ScreenGui, or nil when absent, in which case coins fade where they scattered (no fly-to). Rest unchanged (unused frame constants left). `CityMergeDeviation = "one cash display: no own CashDisplay, coins fly to Custom Inventory.cashDisplay (phase 3 G5)"`. |
| 2026-11-16 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 65,609 / 2648115454 | 65,736 / 525480268 | G10: line 815 `SetCoreGuiEnabled(Backpack, not carrying)` and line 827 `SetCoreGuiEnabled(Backpack, true)` now pass `false`; no other Backpack call in Robbery client code. `CityMergeDeviation = "Backpack core GUI never re-enabled (phase 3 G10)"`. |
| 2026-11-16 | `StarterPlayer.StarterPlayerScripts.NotificationClient` (LocalScript) | 7,576 / 3587576695 | 7,663 / 2079666609 | G6: waits `HeistNotificationGui` (line 26) and the header comment names it. `CityMergeDeviation = "waits HeistNotificationGui (phase 3 G6)"`. |
| 2026-11-16 | `StarterPlayer.StarterPlayerScripts.UiButtonEffects` (LocalScript) | 9,629 / 1935977856 | 9,675 / 3043343507 | G6: the two `NotificationGui` references (PANELS line 125, ambient line 164) now `HeistNotificationGui`. `CityMergeDeviation = "HeistNotificationGui (phase 3 G6)"`. |
| 2026-11-16 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,491 / 2641049495 | 2,569 / 2672186133 | G4: `"CurrencySpec"` commented out of `SPECS` (else it reports "module missing"). `CityMergeDeviation = "CurrencySpec left out of SPECS (retired, phase 3 G4)"`. |

Not a source change:

- `StarterGui.NotificationGui` (Robbery ScreenGui) renamed `HeistNotificationGui` (G6); no scripts inside. `CityMergeDeviation` set.
- `ServerScriptService.Heist.Tests.CurrencySpec` moved to `ServerStorage.CityQuarantine.RetiredSpecs` (new Folder), source unchanged (3,999 / 1781011967 = manifest). G4.
- G9: all 38 Tools under `ServerStorage.Weapons` tagged `Weapon` (CollectionService); 38 `Weapon`-tagged instances in the place. Guard test `WeaponTag_Test`.

New test case modules (city only, exported to `CityScripts/`): `ServerStorage.UnitTest.Cases.CurrencyBridge_Test` (4,519 / 1400801589, 21 cases), `WeaponTag_Test` (685 / 3125862015, 1 case). All nine sources above exported; on-disk Adler-32 equals the place.

Phase 3 Task 3 (2026-11-16): the 14 `carry` roots inside `Workspace` imported at top level under their own names (`ImportedFrom = "Robbery System"`), placed by `phase3/locations.md` section 6; the four city twins moved to `ServerStorage.CityQuarantine.ReplacedByHeist`. Their 9 BaseScripts (Animate LocalScripts and the builder's note Scripts) were disabled with `ImportEnabled` before parenting, then all 22 `ImportEnabled` scripts in the place (Task 2's 13 + these 9) restored to `Enabled = true` and the attribute removed. Afterwards: 432 source containers, 242 BaseScripts, 166 enabled, Enabled checksum 3576485474, source checksum 784918162; `Workspace` descendants 236,393; 1 enabled SpawnLocation (`Workspace.SpawnLocation`; `Workspace.Dev.DevSpawn` stays disabled; no SpawnLocation among the imports).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-16 | `ServerScriptService.SlowFoodsServer` (Script) | 10,173 / 3260473240 | 10,278 / 2040003535 | G12: line 198 `openCFrame` = `CFrame.new(76.727, 5.000, 1691.862) * CFrame.Angles(0, math.rad(-90), 0)` (the Robbery literal kept in a trailing comment). Re-derived from the SlowFoods T: 0.0000 stud, yaw 270. `CityMergeDeviation = "LockedDoor openCFrame transformed to the city location (phase 3 G12)"`. |
| 2026-11-16 | `ServerScriptService.Gas2GoServer` (Script) | 12,710 / 2773693458 | 12,817 / 803557551 | G12: line 252 `openCFrame` = `CFrame.new(-975.507, 5.500, 2047.686) * CFrame.Angles(0, math.rad(-90), 0)`. Re-derived: 0.0001 stud, yaw 270. Same attribute text. |
| 2026-11-16 | `ServerScriptService.NewsStationServer` (Script) | 19,168 / 2679640195 | 19,275 / 39267605 | G12: line 276 `openCFrame` = `CFrame.new(-672.500, 17.775, 1005.252) * CFrame.Angles(0, math.rad(45), 0)`. Re-derived: 0.0004 stud, yaw 45. Same attribute text. |

Not a source change:

- `Workspace.Bank.TeleporterBankA.LinkedTeleporter.Value` and `Workspace.BankVault.TeleporterBankB.LinkedTeleporter.Value` re-linked to each other: the only two cross-root references in the 14 roots (found by a scan of ObjectValues, joints, constraints and PrimaryParts in the Robbery place), lost because each root is serialized on its own.

The three sources exported to `CityScripts/`; on-disk Adler-32 equals the place.

Phase 3 Task 4 (2026-11-16): first run, client load-order audit (`phase3/client-load-order-audit.md`), HUD step. Afterwards: 432 source containers, 242 BaseScripts, 166 enabled, Enabled checksum 3576485474 (unchanged), source checksum 2842082509 (only the three rows below changed); `Workspace` descendants 236,393 (unchanged); 1 enabled SpawnLocation (`Workspace.SpawnLocation`).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-16 | `StarterPlayer.StarterPlayerScripts.UiButtonEffects` (LocalScript) | 9,675 / 3043343507 | 9,933 / 3916961254 | Task 2 carry: the focus mode waited 20 s for the Robbery `CashDisplay`, which G5 removed. It now finds `Custom Inventory.cashDisplay` and hides it by `Visible` while a heist modal is open (not by the ScreenGui's `Enabled`, which the city's `UiTransitionBinder` owns, and not through `Transitions.bindFrame`, whose transparency tracker would fight the city's fade of the same tree). `CityMergeDeviation` appended: "heist focus mode hides Custom Inventory.cashDisplay by Visible (phase 3 Task 4)". |
| 2026-11-16 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 65,736 / 525480268 | 65,942 / 574845500 | HUD: the timer (screen y 12..88) covered the city `StaminaBar` (y 78..88, top centre). `HUD_TOP` 12 -> 2 and `DUFFEL_TOP` gets `+ 2`: timer 2..78, duffel 88..180, getaway 188..264, toast 272..320 (all derived, as the file's own comment requires). `CityMergeDeviation` appended: "HUD_TOP 12 -> 2 and duffel gap +2, strip clear of city StaminaBar (phase 3 Task 4)". |
| 2026-11-16 | `StarterPlayer.StarterPlayerScripts.NotificationClient` (LocalScript) | 7,663 / 2079666609 | 7,855 / 368995753 | G6 / HUD: the stack's bottom (`1, -90`) sat 18 px inside the city `NotificationGui.Container` (`1, -24`, 84 tall, so its top is `1, -108`). `INSET_Y` 90 -> 108 at every screen size. `CityMergeDeviation` appended: "INSET_Y 90 -> 108, stack clear of city NotificationGui.Container (phase 3 Task 4)". |

Not a source change (audit FIX rows, streaming):

- `Workspace.HeistMarkers`, `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`: Folder replaced by a `Model` of the same name with the same children and attributes, `ModelStreamingMode = Persistent`; `CityMergeDeviation` set on each. Paths (`workspace.<name>.StatusBillboardAnchor`, tags) unchanged; no script checks the class. So `StatusBillboardAnchor` and its `StatusBillboard` are on every client from any distance: `HeistClient`'s getaway distance and status badges, and server `Getaway` read the same Part.
- `Workspace["Illegal Supplier"]` (already a Model): `ModelStreamingMode` Default -> `Persistent`; `CityMergeDeviation` set. `SupplierDialogueController` holds its `Interaction` prompt and rig by reference from script start.

The three sources exported to `CityScripts/`; on-disk Adler-32 equals the place.

NOT saved / NOT published

Phase 3 Task 5 (2026-11-16): Robbery remote audit (`phase3/remote-audit.md`) and the two spec debts. Sixteen sources (two new). After: 1 enabled SpawnLocation (`Workspace.SpawnLocation`), `Workspace` 29 direct children (unchanged), no temporary object (the Play probes lived only in the Play datamodel).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-16 | `ServerScriptService.Heist.Services.SupplierSale` (ModuleScript, NEW in the city) | (none) | 1,845 / 159481646 | Audit row 4 FIX: the supplier sale decided on the server. `try(player, deps)` -> amount, outcome (`sold` / `no_supplies` / `too_far`); refuses unless the living character's root is within 15 studs (`MAX_DISTANCE`, prompt 10 + 5) of `deps.supplierPosition`, before `CarryState:Consume`; a refusal keeps the carry. `CityMergeDeviation = "new in the city: supplier sale needs the seller within 15 studs (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.Heist.Tests.SupplierSaleSpec` (ModuleScript, NEW) | (none) | 3,478 / 4114906781 | 5 cases: paid within reach, refused at 1,000 studs (carry kept, Consume not called), refused with no character, 15 / 15.5 boundary, nothing carried. |
| 2026-11-16 | `ServerScriptService.SuppliesServer` (Script) | 6,956 / 3279388031 | 7,886 / 1620753643 | Row 4: `SubmitSupplierChoice` goes through `SupplierSale.try` with `illegalSupplier.Interaction.Position`; `too_far` answers nothing. Controller item 3: `player.CharacterRemoving` drops a carry where the character stood (no-op after a death). `CityMergeDeviation = "supplier sale through Heist.Services.SupplierSale (15-stud reach) and carry dropped on CharacterRemoving (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 18,609 / 2352934560 | 19,356 / 2128671370 | Controller FIX (character removed mid-heist): `_onCharacterRemoving(player)` calls `forfeit:Die(bank, player, "died")` when Active and a participant; wired to `player.CharacterRemoving` in `Start`'s PlayerAdded. `CityMergeDeviation = "CharacterRemoving forfeits the bag like a death (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.HeistServer` (Script) | 47,791 / 785049546 | 48,408 / 1992145438 | Same hook for the Bank in its PlayerAdded. Same attribute text. |
| 2026-11-16 | `ServerScriptService.Heist.Tests.LocationServerSpec` (ModuleScript) | 22,343 / 735058247 | 24,130 / 2041343054 | 2 cases: removal voids the bag and the respawn past 200 banks nothing (real `Forfeit`); removal while Idle or by a non-participant forfeits nothing. `CityMergeDeviation = "two CharacterRemoving cases (phase 3 Task 5)"`. |
| 2026-11-16 | `ReplicatedStorage.SharedSystems.GamepassManager` (ModuleScript) | 4,939 / 1212531507 | 5,580 / 1466278867 | Row 10 FIX: `_onPurchaseFinished` confirms a `wasPurchased` event with `pcall(_ownershipCheck)` (`UserOwnsGamePassAsync`) and caches only a confirmed true; `Init`'s `PromptGamePassPurchaseFinished` calls it; `_setCached` comment updated. `CityMergeDeviation = "PromptGamePassPurchaseFinished confirmed with UserOwnsGamePassAsync before caching (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.Heist.Tests.GamepassManagerSpec` (ModuleScript) | 7,239 / 3248931884 | 9,094 / 1349270393 | 4 cases through the existing `_ownershipCheck` seam: confirmed -> cached, denied -> nothing cached, error -> nothing cached and no throw, not purchased -> no check. `CityMergeDeviation = "purchase-finished confirmation cases (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.Heist.Components.Safe` (ModuleScript) | 12,841 / 2846564146 | 13,871 / 986742147 | Row 2 FIX: opt-in `enforceHold`: one player's attempts at least the prompt's own `HoldDuration` apart (read at `Unlock`), shared across opted-in safes (module-level weak-keyed table); inside the floor `TrySubmitCode` returns `too_soon` and keeps the pending try. `clock` dep (default `os.clock`). Bank safes do not opt in. `CityMergeDeviation = "opt-in enforceHold: attempts at least the prompt's HoldDuration apart per player (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.NewsStationServer` (Script) | 19,275 / 39267605 | 19,460 / 1123707390 | Row 2: its three `Safe.new` calls pass `enforceHold = true` (`RobSafePrompt.HoldDuration`, 8 today). `CityMergeDeviation` appended "; NewsStation safes enforceHold (phase 3 Task 5)". |
| 2026-11-16 | `ServerScriptService.Heist.Tests.NewsStationSafeSpec` (ModuleScript) | 7,620 / 263829839 | 10,468 / 1333155286 | 2 cases: refused at 7.9 s with the try kept, accepted at 8.0 s; the floor is per player across safes and does not hold another player back. `CityMergeDeviation = "hold-time floor cases (phase 3 Task 5)"`. |
| 2026-11-16 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,569 / 2672186133 | 2,614 / 3188154631 | `"SupplierSaleSpec"` added to `SPECS`. Attribute appended "; SupplierSaleSpec registered (phase 3 Task 5)". |
| 2026-11-16 | `ReplicatedStorage.SharedSystems.CashClaimVFX` (ModuleScript) | 12,437 / 1758279696 | 12,623 / 816478649 | Brief Step 3: `UITheme` required at module scope (the lazy require in `makeCoin` ran after `freshRequire` destroyed its clone). Attribute appended "; UITheme required at module scope (phase 3 Task 5)". |
| 2026-11-16 | `ServerScriptService.Heist.Tests.CashClaimVFXSpec` (ModuleScript) | 10,277 / 2809086604 | 11,323 / 3039798395 | **Deviation from the Robbery spec, reason G5:** the "persistent Cash display" case (and two `_label.Text` asserts) pinned the self-built `CashDisplay` that G5 removed; replaced by "construction reads the initial value and builds no cash display of its own" and "coins target the city's Custom Inventory.cashDisplay once it exists". The decal case read a literal `rbxassetid://18885492705` that `UITheme.Assets.Coin` no longer holds (the theme moved to a new slice in the Robbery place, attribute-free here); it now reads the theme. `CityMergeDeviation = "updated to the G5 single cash display; coin read from UITheme (phase 3 Task 5)"`. |
| 2026-11-16 | `ReplicatedStorage.RestaurantShared.Config` (ModuleScript) | 3,643 / 2590101496 | 3,701 / 2765807960 | Brief Step 4: `CooldownDuration` 60 -> 1200 (the spec's 20 minutes; the developer said nothing otherwise). `CityMergeDeviation = "CooldownDuration 60 -> 1200, the spec value (phase 3 Task 5)"`. |
| 2026-11-16 | `ReplicatedStorage.Gas2GoShared.Config` (ModuleScript) | 3,142 / 3666878612 | 3,199 / 3526898118 | Same, 60 -> 600 (10 minutes). `CityMergeDeviation = "CooldownDuration 60 -> 600, the spec value (phase 3 Task 5)"`. |

All sixteen sources exported to `CityScripts/` with `transfer/export-source.luau`; on-disk Adler-32 equals the place (16 / 16).

NOT saved / NOT published

Fix round 1 (2026-11-16, review of Task 5): a real in-game purchase could stay unrecognised for the session, because a heist had usually cached `false` already and `UserOwnsGamePassAsync` may answer a stale false right after a purchase. Same columns; "old" is the Task 5 value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-16 | `ReplicatedStorage.SharedSystems.GamepassManager` (ModuleScript) | 5,580 / 1466278867 | 6,364 / 1846783466 | `_onPurchaseFinished`: on `wasPurchased` clears this user's cached entry for the pass, then confirms in `task.spawn` with up to 3 `pcall(_ownershipCheck)` attempts, `_confirmRetryDelay` (2 s, injectable) apart; caches true on the first confirmed true, else leaves the entry nil so the next read re-queries. `wasPurchased` false changes nothing. Attribute appended "; purchase clears a stale cached entry and confirms up to 3 times, 2 s apart (phase 3 Task 5 fix round 1)". |
| 2026-11-16 | `ServerScriptService.Heist.Tests.GamepassManagerSpec` (ModuleScript) | 9,094 / 1349270393 | 11,371 / 2397584779 | The purchase cases rewritten for the async confirm (delay 0): confirmed first try; cached false then confirmed on the 2nd attempt -> owned; never confirmed -> next read re-queries; denied caches nothing (3 attempts); error x3 no throw; not purchased keeps the cached entry. Attribute appended "; stale-cache purchase cases (phase 3 Task 5 fix round 1)". |
| 2026-11-16 | `ServerScriptService.Heist.Tests.CashClaimVFXSpec` (ModuleScript) | 11,323 / 3039798395 | 11,490 / 3531921895 | Decal case also asserts `icon.Image ~= ""` and `^rbxassetid://%d+$`. Attribute appended "; decal must be a non-empty rbxassetid (fix round 1)". |
| 2026-11-16 | `ServerScriptService.Heist.Tests.SupplierSaleSpec` (ModuleScript) | 3,478 / 4114906781 | 4,191 / 113863477 | Dead-seller case: Health 0 at 3 studs from the supplier is refused, carry kept. Attribute appended "; dead-seller case (fix round 1)". |

The four sources re-exported to `CityScripts/`; on-disk Adler-32 equals the place (4 / 4).

NOT saved / NOT published

Final review fixes (2026-11-16, whole-batch review of phase 3). Same columns; "old" is the latest value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-16 | `ServerScriptService.HeistServer` (Script) | 48,408 / 1992145438 | 48,431 / 4059546395 | `Players.PlayerAdded:Connect` -> `require(ReplicatedStorage.Utility.safePlayerAdded)(...)`, so players already present get the hooks; handler body unchanged. Attribute appended "; PlayerAdded through safePlayerAdded, covers players already present (phase 3 final review)". |
| 2026-11-16 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 19,356 / 2128671370 | 19,379 / 2088958855 | Same in `Start` (the returned connection still goes into `conns`). Same attribute text. |
| 2026-11-16 | `ServerScriptService.SuppliesServer` (Script) | 7,886 / 1620753643 | 7,909 / 1266664936 | Same. Same attribute text. |
| 2026-11-16 | `ReplicatedStorage.SharedSystems.GamepassManager` (ModuleScript) | 6,364 / 1846783466 | 6,681 / 754457998 | `Init`'s `PlayerAdded` through `safePlayerAdded`; `PlayerOwnsGamepass` returns true without writing when the entry became `true` while the check yielded (a confirm landed). Attribute appended "; PlayerAdded through safePlayerAdded; a stale false never overwrites a cached true (phase 3 final review)". |
| 2026-11-16 | `ServerScriptService.Heist.Tests.GamepassManagerSpec` (ModuleScript) | 11,371 / 2397584779 | 12,231 / 3341640635 | Case "a stale false arriving after a confirmed true does not overwrite it" (the stub caches true, then answers false): 19 / 1 before the guard, 20 / 0 after. Attribute appended "; stale-false-after-confirmed-true case (phase 3 final review)". |

Not a source change:

- CollectionService tag `Invulnerable` added to `Workspace["Illegal Supplier"]["Illegal Supplier"]` (the Model holding the Humanoid: `canDamageHumanoid` reads the tag on `Humanoid.Parent`), `ReplicatedStorage.HeistShared.ModelTemplates.BankClerk` and `ReplicatedStorage.RestaurantShared.ModelTemplates.Cashier` (used by SlowFoods and Gas2Go). `NPCSpawnManager` spawns by `Clone()`, which keeps tags: in Play the 2 Bank clerks, 3 SlowFoods and 2 Gas2Go cashiers carried it. Each of the three has `CityMergeDeviation` "Invulnerable tag: heist NPC not killable for city XP (phase 3 final review)". `ServerStorage.GuardTemplate` and `NewsStationShared.ModelTemplates.NewsWorker` untagged. Before: 0 `Invulnerable` objects in Edit; after: 3.

The five sources exported to `CityScripts/` with `transfer/export-source.luau`; on-disk Adler-32 equals the place (5 / 5). After: 1 enabled SpawnLocation (`Workspace.SpawnLocation`), `Workspace` 29 direct children, no temporary object.

NOT saved / NOT published

# Police and wanted 2026-11-17

Task 1 (heat model and WantedService). Same columns as above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Blaster.Scripts.ShotResolver` (ModuleScript) | 36,738 / 1560462989 | 37,245 / 2124116100 | `damagedEvent = events.Damaged`; `damagedEvent:Fire(shooter, humanoid, amount)` beside `taggedEvent:Fire` at the three damage sites (bleed tick, explosion, direct hit), only when the shooter is a `Player`. Attribute (new) "fires Blaster.Events.Damaged beside Tagged for a Player attacker (police and wanted Task 1)". |
| 2026-11-17 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 19,379 / 2088958855 | 19,661 / 1203330187 | `TryTriggerRobbery`: after `NotifyRobberyTriggered`, `WantedService.onAlarm(self.name, self.bank:GetParticipants())` (lazy require; a location without an alarm level, such as the spec's `TestLoc`, gives nothing). Attribute appended "; robbery trigger calls WantedService.onAlarm with the participants (police and wanted Task 1)". |
| 2026-11-17 | `ServerScriptService.HeistServer` (Script) | 48,431 / 4059546395 | 48,837 / 425282900 | `tryTriggerRobbery`: after `NotifyRobberyTriggered("Bank", ...)`, `WantedService.onAlarm("Bank", participants plus the trigger player)`. Attribute appended "; robbery trigger calls WantedService.onAlarm with the participants plus the trigger player (police and wanted Task 1)". |

New: `ReplicatedStorage.Wanted` (Folder) with `Constants`, `HeatModel`; `ServerScriptService.Wanted` (Folder) with `WantedService` (ModuleScript), `WantedRunner` (Script); `ServerScriptService.Blaster.Events.Damaged` (BindableEvent); cases `ServerStorage.UnitTest.Cases.HeatModel_Test`, `WantedService_Test`.

The nine sources exported to `CityScripts/` with `transfer/export-source.luau`; on-disk Adler-32 equals the place (9 / 9). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Fix round 1 (2026-11-17, Task 1 review). Same columns; "old" is the latest value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Blaster.Scripts.ShotResolver` (ModuleScript) | 37,245 / 2124116100 | 37,258 / 1179613095 | No `Damaged` per bleed tick (the cut that started the bleed already counted; a bleed kill still fires `Eliminated`); header comment says so. Attribute appended "; no Damaged per bleed tick (police and wanted Task 1 fix round 1)". |

New sources changed (not deviations): `ServerScriptService.Wanted.WantedService` 7,246 / 1552071783 -> 8,474 / 783838274 (`attackerActive` dep: hits and kills from a dead or departed attacker ignored; seen provider under `pcall`, a throw = not seen, warned at most once a minute; `_onDamagedEvent`, `_onEliminatedEvent`, `_onPlayerRemoving` exposed as the handlers `start()` connects); `ServerScriptService.Wanted.WantedRunner` 389 / 3775104625 -> 556 / 847429352 (`_step` under `pcall`); `ServerStorage.UnitTest.Cases.WantedService_Test` 8,092 / 2339253098 -> 10,741 / 667327529 (4 cases; deps restored even when building the cases throws).

The four sources re-exported to `CityScripts/`; on-disk Adler-32 equals the place (4 / 4). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 2 (2026-11-17, police on the enemy AI and the dispatcher). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Enemy.Scripts.EnemyAI` (ModuleScript) | 38,235 / 760454415 | 39,701 / 1795397229 | `EnemyAI:_accepts(player)` (config `targetFilter`, absent for gangs = always true) consulted in `_findVisibleTarget`, `_targetHumanoid` (a refused target is dropped mid-fight) and `onDamagedBy`; `EnemyAI._players()` seam (= `Players:GetPlayers()`); public `EnemyAI:canSee(character): boolean` on the existing `ShotResolver.hasLineOfSight`; `EnemyAI.getLive()` over the existing `activeEnemies` registry. Attribute (new) "config.targetFilter in _findVisibleTarget/_targetHumanoid/onDamagedBy, canSee, getLive, _players seam (police and wanted Task 2)". |
| 2026-11-17 | `ServerScriptService.Enemy.Scripts.EnemySpawner` (Script) | 18,321 / 4047349777 | 11,091 / 1886183207 | Rig building (`stripClientScripts`, `ensureCollisionGroup`, `prepareWeapon`, nameplate, tag, `EnemyTemplate`, pivot, equip, collision group, network owner, ragdoll prep) moved verbatim to the new `Enemy.Scripts.EnemyRig` (`build`, `place`), shared with the police dispatcher; `trySpawn` calls them in the same order. Attribute (new) "rig building moved verbatim to Enemy.Scripts.EnemyRig, shared with the police dispatcher (police and wanted Task 2)". |

New: `ReplicatedStorage.Wanted.SquadPlan` 1,319 / 2600976218; `ServerScriptService.Enemy.Scripts.EnemyRig` 9,235 / 833191980; `ServerScriptService.Wanted.PoliceDispatcher` 17,115 / 2593411831; cases `SquadPlan_Test` 2,281 / 3198336116, `EnemyTargetFilter_Test` 3,298 / 1253920254, `PoliceSpawnPoint_Test` 1,917 / 442859324. Changed new sources (not deviations): `ReplicatedStorage.Wanted.Constants` 1,396 / 1865194749 -> 2,416 / 249291217 (dispatcher numbers); `ServerScriptService.Wanted.WantedService` 8,474 / 783838274 -> 8,982 / 2208437914 (signal helper; `Alarmed(locationName, players)` fired by `onAlarm`); `ServerScriptService.Wanted.WantedRunner` 556 / 847429352 -> 673 / 399239200 (starts `PoliceDispatcher`).

The eleven sources exported to `CityScripts/`; on-disk Adler-32 equals the place (11 / 11). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 2 fix round 1 (2026-11-17: design section 9 and the review). Same columns; old = the latest value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Enemy.Scripts.EnemyAI` (ModuleScript) | 39,701 / 1795397229 | 40,610 / 2586628771 | `config.preferTarget` (police: its squad's player) taken in `_findVisibleTarget` whenever visible (gangs: none, unchanged); `EnemyAI:investigate(position)` (from Patrol or Search only, heads there as Search does); `EnemyAI._activeEnemies` exposed for the test. Attribute appended "; config.preferTarget and investigate(position) (police and wanted Task 2 fix round 1)". |
| 2026-11-17 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 19,661 / 1203330187 | 19,943 / 2011283273 | `Start` registers `WantedService.addActiveRobbery(player -> Active and participant)`, disconnected by `Destroy`. Attribute appended "; Start registers WantedService.addActiveRobbery for its Active participants (police and wanted Task 2 fix round 1)". |
| 2026-11-17 | `ServerScriptService.HeistServer` (Script) | 48,837 / 425282900 | 49,108 / 1930538091 | Registers `WantedService.addActiveRobbery` for the Bank's Active participants. Attribute appended "; registers WantedService.addActiveRobbery for the Bank's Active participants (police and wanted Task 2 fix round 1)". |

New sources changed (not deviations): `ReplicatedStorage.Wanted.Constants` 2,416 / 249291217 -> 2,887 / 2748218085 (`SEARCH_SECONDS` 20, `LEAVE_TIMEOUT` 30 -> 60, sight probe side and see-through numbers); `ServerScriptService.Wanted.WantedService` 8,982 / 2208437914 -> 10,527 / 4033096710 (search window, `addActiveRobbery`, `knowsWhere`); `ServerScriptService.Wanted.PoliceDispatcher` 17,115 / 2593411831 -> 20,106 / 2732147937 (ground = roads and footpaths only, glass and pole-proof sight, believed position, preferTarget, leavers not "seen", anchor cleared, top-up on its own thread, spawn log behind `debug`); cases `WantedService_Test` 10,741 / 667327529 -> 13,189 / 1203546623, `EnemyTargetFilter_Test` 3,298 / 1253920254 -> 5,957 / 291556854, `PoliceSpawnPoint_Test` 1,917 / 442859324 -> 3,439 / 609772528.

The nine sources re-exported to `CityScripts/`; on-disk Adler-32 equals the place (9 / 9). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 2 fix round 2 (2026-11-17: the robbery keeps a participant "seen" only near the robbery). Same columns; old = the latest value above (Getaway: the place before this round).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Heist.Services.Getaway` (ModuleScript) | 5,204 / 51305358 | 5,734 / 2317195041 | `Getaway:IsNear(player)`: inside the building (the injected `isInsideBuilding`) or horizontally closer than `escapeDistance` to the anchor (its own `horizontalDistance`); no character = not near. Attribute (new) "Getaway:IsNear(player): inside or within escapeDistance of the anchor (police and wanted Task 2 fix round 2)". |
| 2026-11-17 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 19,943 / 2011283273 | 20,074 / 3295735053 | The active-robbery check also needs `self.getaway:IsNear(player)`. Attribute appended "; the active-robbery check also needs getaway:IsNear (police and wanted Task 2 fix round 2)". |
| 2026-11-17 | `ServerScriptService.HeistServer` (Script) | 49,108 / 1930538091 | 49,256 / 1964564583 | The Bank's active-robbery check moved below `Getaway.new` and also needs `getaway:IsNear(player)` (Lobby, Vault or BankVaultZone, or within EscapeDistance). Attribute appended "; the active-robbery check also needs getaway:IsNear, registered after the getaway is built (police and wanted Task 2 fix round 2)". |

Case changed (not a deviation): `ServerStorage.UnitTest.Cases.WantedService_Test` 13,189 / 1203546623 -> 15,457 / 1908116138 (3 cases). `Getaway` exported to `CityScripts/` for the first time. The four sources' on-disk Adler-32 equals the place (4 / 4). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 3 (2026-11-17, witnesses and NewsStation guards). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Heist.Components.GuardPost` (ModuleScript) | 9,843 / 1939221827 | 10,998 / 1315880415 | `config.GuardsAlwaysPosted`: the guard is spawned in `new`, a live one stays at `Seal`, a fresh one replaces it at `Rearm`; `_moveToCover` and `Rearm` skip cover when `config.Tags.HeistCoverPoint` is absent (hold the post); `spawnGuard(marker.CFrame, config.GuardSpawnLift)`, `defaultSpawn` lifts by `lift or 3` (the Bank unchanged: no flag, lift 3). Attribute (new) "config.GuardsAlwaysPosted (guard from boot, kept at Seal, replaced at Rearm), cover optional when config.Tags has no HeistCoverPoint, config.GuardSpawnLift (default 3) (police and wanted Task 3)". |
| 2026-11-17 | `ServerScriptService.NewsStationServer` (Script) | 19,460 / 1123707390 | 20,609 / 4028888056 | Boot assert: exactly `Wanted.Constants.NEWSSTATION_GUARDS` (3) `NewsStationGuardPost` parts; `[T.NewsStationGuardPost] = GuardPost` in the registry; `damage` dep (HeistServer's); `post:Update()` in `heartbeatExtras`. Attribute appended "; 3 NewsStationGuardPost GuardPost components (boot assert, registry, damage dep, heartbeat Update) (police and wanted Task 3)". |
| 2026-11-17 | `ReplicatedStorage.NewsStationShared.Config` (ModuleScript) | 4,544 / 1767577253 | 5,452 / 3133755255 | `GuardsAlwaysPosted = true`, `GuardSpawnLift = 0`, `GuardActivationRange` 60, `GuardSightRange` 120, `GuardFireInterval` 0.9, `GuardDamage` 0 (the Bank's values); tag `NewsStationGuardPost`. Attribute (new) "guard settings GuardsAlwaysPosted, GuardSpawnLift, Guard* combat numbers, tag NewsStationGuardPost (police and wanted Task 3)". |
| 2026-11-17 | `ServerScriptService.Heist.Tests.WorldSpec` (ModuleScript) | 49,042 / 3496098806 | 50,282 / 3545750290 | Manifest: `NewsStationGuardPost` = 3; new test: each post inside `NewsroomZone`, Transparency 1, not colliding, anchored, in `NewsStationMarkers`. Attribute (new) "NewsStationGuardPost count 3 and a placement test (police and wanted Task 3)". |
| 2026-11-17 | `ServerScriptService.Heist.Tests.GuardSpec` (ModuleScript) | 8,130 / 1317285606 | 9,721 / 3536925508 | One case: `GuardsAlwaysPosted` (guard from construction, none extra at session start, kept at Seal, fresh at Rearm, no cover, lift handed to `spawnGuard`). No attribute (test). |

World (not scripts): `Workspace.NewsStationMarkers.GuardPost1` (-668, 14.25, 986; upper floor, faces the three safes), `GuardPost2` (-664, 2.25, 986; ground floor, faces `MasterComputer`), `GuardPost3` (-634, 2.25, 1003; faces the entrance), each a 2 x 1 x 2 anchored Part, Transparency 1, CanCollide/CanQuery/CanTouch false, centred on the floor top, tag `NewsStationGuardPost`, attribute `Covers`. Tag `Witness` added to `HeistShared.ModelTemplates.BankClerk`, `RestaurantShared.ModelTemplates.Cashier` (SlowFoods and Gas2Go), `NewsStationShared.ModelTemplates.NewsWorker`, `ServerStorage.GuardTemplate`; `GuardTemplate` attribute `WitnessRole = "Guard"`.

New: `ServerScriptService.Wanted.Sight` 2,769 / 2676598123 (the line-of-sight probe and the ray params, moved out of `PoliceDispatcher` unchanged except an optional `ignore`); `ServerScriptService.Wanted.Witnesses` 2,173 / 111339273; case `Witnesses_Test` 3,002 / 3079264878. Changed new sources (not deviations): `PoliceDispatcher` 20,106 / 2732147937 -> 18,687 / 585788091 (uses `Sight`; `isSeen` also true when `Witnesses.guardSees`); `WantedService` 10,527 / 4033096710 -> 10,729 / 1711108376 (`deps.witness` = `Witnesses.sees` at the attacker's root).

The ten sources exported to `CityScripts/`; on-disk Adler-32 equals the place (10 / 10). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 3 fix round 1 (2026-11-17, guards that bite, only at robbers). Same columns; "old" is the latest value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Heist.Components.GuardPost` (ModuleScript) | 10,998 / 1315880415 | 12,166 / 1323913687 | `GuardPost.mayTarget(bank, player)` = participant or `WantedStars >= 1`; `selectTarget` takes an optional predicate and `Update` passes `mayTarget` (Bank and NewsStation alike: bystanders are not shot). `_handleDeath` records `_diedAt`; `Update` outside an Active session calls `_respawnIfDue`: a posted guard dead `config.GuardRespawnSeconds` is replaced at its post. Attribute appended "; targets only a participant or a wanted player (mayTarget), posted guard dead outside a session respawns after config.GuardRespawnSeconds (police and wanted Task 3 fix round 1)". |
| 2026-11-17 | `ReplicatedStorage.HeistShared.Config` (ModuleScript) | 14,070 / 180119306 | 14,266 / 3018040884 | `GuardDamage` 0 -> 12, the `Police` template's `DamageOverride` (EnemyRig writes it over the Mateba's 60). Attribute (new) "GuardDamage 0 -> 12, the Police template's DamageOverride (police and wanted Task 3 fix round 1)". |
| 2026-11-17 | `ReplicatedStorage.NewsStationShared.Config` (ModuleScript) | 5,452 / 3133755255 | 5,681 / 3212811427 | `GuardDamage` 0 -> 12; `GuardRespawnSeconds` 60. Attribute appended "; GuardDamage 12, GuardRespawnSeconds 60 (police and wanted Task 3 fix round 1)". |
| 2026-11-17 | `ServerScriptService.Heist.Tests.GuardSpec` (ModuleScript) | 9,721 / 3536925508 | 12,206 / 1737840580 | Two cases: bystander / participant / wanted bystander targeting; posted respawn at 60 s, none while Active. No attribute (test). |

Changed new sources (not deviations): `Wanted.Sight` 2,769 / 2676598123 -> 2,811 / 600028089 (`ignore` may be a list); `Wanted.Witnesses` 2,173 / 111339273 -> 2,363 / 1749821196 (every witness's body left out of the rays); case `Witnesses_Test` 3,002 / 3079264878 -> 4,154 / 3584903647 (a second witness in the line of view, real probe).

The seven sources exported to `CityScripts/`; on-disk Adler-32 equals the place (7 / 7). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 3 fix round 2 (2026-11-17, guard damage tuned for the Bank). Same columns; "old" is the latest value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ReplicatedStorage.HeistShared.Config` (ModuleScript) | 14,266 / 3018040884 | 14,301 / 3575820392 | `GuardDamage` 12 -> 6 (four guards at 12 killed a robber in the open in 2.3 s). Attribute appended "; GuardDamage 12 -> 6 (police and wanted Task 3 fix round 2)". |
| 2026-11-17 | `ReplicatedStorage.NewsStationShared.Config` (ModuleScript) | 5,681 / 3212811427 | 5,669 / 538875747 | `GuardDamage` 12 -> 6, as at the Bank. Attribute appended "; GuardDamage 12 -> 6 (police and wanted Task 3 fix round 2)". |

The two sources exported to `CityScripts/`; on-disk Adler-32 equals the place (2 / 2). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 4 (2026-11-17, the wanted star meter). No existing script edited, so no `CityMergeDeviation` row.

New: `StarterPlayer.StarterPlayerScripts.WantedHud` (LocalScript) 5,291 / 1430248998: builds the `WantedHud` ScreenGui in code (`ZIndexBehavior = Sibling`, `ResetOnSpawn = false`, `CoreUISafeInsets`, its own `UIScale` 1); five star glyphs on a `UITheme` plate (`Color.panel`, `UICorner` 8, `UIStroke`), fill by a left-to-right clip, stroke pulse while `WantedSeen`, blink on the next star while `WantedDraining`, hidden at 0 and while a `UI.Panels` panel is open. Top centre: offset +160 right of centre, or -160 left of centre when `min(viewport) < Blaster.Constants.UI_SMALL_SCREEN_THRESHOLD` (500).

Changed new sources (not deviations): `WantedService` 10,729 / 1711108376 -> 11,318 / 1789475611 (each `_step` publishes `WantedSeen` = active-robbery bypass or the seen provider, and `WantedDraining` = neither seen nor in the search window; both false at join and when heat reaches 0; the seen provider is now asked on every step, not only outside the search window); case `WantedService_Test` 15,457 / 1908116138 -> 17,374 / 2745169990 (two cases).

The three sources exported to `CityScripts/`; on-disk Adler-32 equals the place (3 / 3). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 4 fix round 1 (2026-11-17, star meter camera, fill and stale draining). No existing script edited. "old" is the latest value above.

Changed new sources (not deviations): `WantedService` 11,318 / 1789475611 -> 11,465 / 542011034 (`addHeat` and `onAlarm` set `WantedDraining = false` at once: the search window starts with the rise); case `WantedService_Test` 17,374 / 2745169990 -> 18,083 / 2348801503 (one case); `WantedHud` 5,291 / 1430248998 -> 6,348 / 732449840 (follows `workspace.CurrentCamera`, nil-safe, re-binds `ViewportSize`; the fraction is laid over the glyph's ink from `TextBounds`, rounded to whole px; no pulse or blink while a panel hides the plate).

The three sources exported to `CityScripts/`; on-disk Adler-32 equals the place (3 / 3). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 5 (2026-11-17, quest givers become crooked cops). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.QuestDialogueController` (LocalScript) | 9,078 / 3223924563 | 9,190 / 404181644 | The givers' spoken lines (built here from `QuestConfig` fields, not stored in `QuestConfig`) rewritten as crooked officers paying off the books: completed, ready, in progress, under level, offer (first and repeat), accept and turn-in quips; placeholders, replies and logic unchanged. Attribute (new) "spoken lines rewritten: the givers are crooked cops paying off the books (police and wanted Task 5)". |

World (not scripts): `Workspace.Quests.<giver>.Head.gui.name.Text` only (model names and `npcName` unchanged): `Level 1 Quest` "LEVEL 1 QUEST" -> "GUARD DOYLE - LV 1"; `Level 10 Quest` "LEVEL 10 QUEST" -> "GUARD PIKE - LV 10"; `Level 20 Quest` "LEVEL 20 QUEST" -> "SGT. MARSH - LV 20"; `Level 35 Quest` "LEVEL 35 QUEST" -> "LT. GRADY - LV 35"; `Level 50 Quest` "LEVEL 50 QUEST" -> "CPT. VOSS - LV 50"; `Level 70 Quest` "LEVEL 70 QUEST" -> "CHIEF HARLAN - LV 70". `QuestConfig` not edited.

The one source exported to `CityScripts/` for the first time; on-disk Adler-32 equals the place (1 / 1). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 5 fix round 1 (2026-11-17, crooked-cop ranks and the under-level line). Same columns; "old" is the latest value above.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.QuestDialogueController` (LocalScript) | 9,190 / 404181644 | 9,176 / 4006366522 | Under-level line "Not yet, kid. Make a name for yourself first." -> "Not yet, kid. Earn a rep first.". Attribute unchanged. |

World (not scripts): `Workspace.Quests["Level 1 Quest"].Head.gui.name.Text` "GUARD DOYLE - LV 1" -> "OFC. DOYLE - LV 1"; `Workspace.Quests["Level 10 Quest"].Head.gui.name.Text` "GUARD PIKE - LV 10" -> "OFC. PIKE - LV 10".

The one source re-exported to `CityScripts/`; on-disk Adler-32 equals the place (1 / 1). After: 1 enabled SpawnLocation, no temporary object.

Final review fixes (2026-11-17). Same columns; "old" is the latest value above (or the place before this wave).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ReplicatedStorage.Blaster.Utility.canDamageHumanoid` (ModuleScript, from the FPS place) | 2,166 / 453962573 | 2,553 / 2408345008 | NPC fire (police, gangs, guards) never damages a model tagged `Witness` (guards, heist civilians): a police volley through a Bank guard cannot kill it and fire `GuardsCleared`. Players unchanged. `CityMergeDeviation` set (was none): "Witness NPCs (guards, heist civilians) not damaged by NPC fire (police and wanted final review 2026-11-17)". First export to `CityScripts/`. |

New sources changed (not deviations): `ReplicatedStorage.Wanted.SquadPlan` 1,319 / 2600976218 -> 1,715 / 920340455 (`surplus`); `ServerScriptService.Wanted.PoliceDispatcher` 18,687 / 585788091 -> 20,421 / 3144991636 (`_spawnRound` stops at the first failed search, the alarm ring searched once; `shed` sends officers above the star target away, Armed first; seams `_findSpawn`, `_spawnOfficer`); `ServerScriptService.Wanted.WantedService` 11,465 / 542011034 -> 12,214 / 2218288967 (`inGame` dep: a departed player gets no heat and is dropped at the next step; the victim passed to the witness check); `ServerScriptService.Wanted.Witnesses` 2,363 / 1749821196 -> 2,548 / 2589221737 (`sees(position, except)`); cases `EnemyTargetFilter_Test` -> 7,659 / 741410838, `PoliceSpawnPoint_Test` -> 5,172 / 4118714214, `SquadPlan_Test` 2,281 / 3198336116 -> 2,884 / 1681095352, `WantedService_Test` 18,083 / 2348801503 -> 21,569 / 2875280365, `Witnesses_Test` 4,154 / 3584903647 -> 4,635 / 1257629373 (7 cases written, one of them replacing the stub-witness case: +6).

The ten sources exported to `CityScripts/`; on-disk Adler-32 equals the place (10 / 10). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

## Known issues pass 2026-11-17

Task 1 (city cleanup). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 20,074 / 3295735053 | 20,132 / 3584032727 | A character removed mid-heist forfeits with its own cause `removed` and the toast "Your character was removed. Bag lost." instead of the death toast. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.LocationServerSpec` (ModuleScript) | 24,130 / 2041343054 | 24,257 / 3258815741 | The removal case reads the cause through Forfeit's `notify` and asserts `removed`. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.CashClaimVFX` (ModuleScript) | 12,623 / 816478649 | 11,096 / 1118537320 | Dead code removed: the five cash-frame/value constants, `formatWithCommas`, the empty `_render` and its five callers, `self._gui` in `Destroy`. Attribute appended. |

World (not scripts): `Workspace.HQ` (Folder, 58,277 descendants, 23 scripts, 21 Humanoids; no script, ObjectValue or path references it) moved to `ServerStorage.CityQuarantine.WorkspaceHQ.HQ` (the `WorkspaceHQ` folder carries `OriginalPath` "Workspace.HQ", `OriginalCFrame` identity: a Folder has no pivot, its children keep their world CFrames). The 4 `ProximityPrompt`s under `Workspace.Map.Robbery` saved `Default` (3 warehouse buttons, `CasinoMain.OpenBTN`) are now `Custom` (Default 4 -> 0, Custom 0 -> 4). `ReplicatedStorage.NewsStationShared.ModelTemplates.NewsWorker` tags: Witness -> Invulnerable, Witness. Thug point not moved (see the task report).

The three sources exported to `CityScripts/`; on-disk Adler-32 equals the place (3 / 3). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 2 (re-slot copy, skin ownership, join toast). Same columns; old = the place before this task (first export: none on disk).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Weapons.Scripts.WeaponShopService` (Script) | 18,779 / 654312028 | 19,042 / 2603572961 | Moving a weapon between slots keeps the live Tool (held or in the Backpack) instead of granting a second one. Attribute set. |
| 2026-11-17 | `ServerScriptService.Cosmetics.Scripts.CosmeticsService` (ModuleScript) | 7,185 / 2805852613 | 7,807 / 1500760674 | `ownsWeapon`; `EquipSkinRequest` refuses a weapon the player does not own. Attribute set. |
| 2026-11-17 | `ServerScriptService.Spraypaint.Scripts.SpraypaintService` (ModuleScript) | 14,428 / 741528517 | 14,939 / 478840120 | `BuySkinRequest` refuses an unowned or unknown weapon before the charge; `hydrate` sets `SpraypaintRestored` last. Attribute set. |
| 2026-11-17 | `ReplicatedStorage.Spraypaint.Constants` (ModuleScript) | 2,179 / 2067918910 | 2,338 / 1366304406 | `RESTORED_ATTRIBUTE` = "SpraypaintRestored". Attribute set. First export. |
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.SpraypaintHud` (LocalScript) | 4,345 / 1480707121 | 5,000 / 2462626152 | Changes before `SpraypaintRestored` re-seed the baseline: no join-time toast; a real gain after it toasts once. Attribute set. First export. |
| 2026-11-17 | `ServerStorage.UnitTest.Cases.CosmeticsOwnership_Test` | 5,901 / 3272276246 | 6,650 / 1084816824 | Stand-ins own Crowbar; owned/unowned skin case (+1). First export. |
| 2026-11-17 | `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` | 19,046 / 4287975109 | 19,148 / 3943199417 | Two stand-ins own Crowbar before a skin request. |
| 2026-11-17 | `ServerStorage.UnitTest.Cases.SkinOwnership_Test` (new) | none | 2,346 / 79508782 | Three cases: owned weapon bought and equipped, unowned refused (nothing stored or charged), non-string or unknown weapon refused before the charge (+3). |

The eight sources exported to `CityScripts/`; on-disk Adler-32 equals the place (8 / 8). City suites 262 / 262 / 0; heist 620 passed / 1 failed (Zone sweep only). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 3 (weapon descriptions, reload readout, dry fire, RPG, muzzles). Same columns; old = the place before this task (first export: none on disk).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ReplicatedStorage.Blaster.Scripts.GuiController` (ModuleScript) | 6,182 / 2060541739 | 6,623 / 3610573378 | A shotgun (`isShotgun`) shows its shell count rising through the shell-by-shell reload instead of a static dash; magazine weapons keep the dashes. `playDryFire` plays the new child Sound `DryFire`. Attribute set. First export. |
| 2026-11-17 | `ReplicatedStorage.Blaster.Scripts.BlasterController` (ModuleScript) | 18,342 / 3161426517 | 18,826 / 1436954061 | A trigger press the client's own fire-rate cooldown holds back (`self.shooting`) plays the dry-fire cue, once per press, not for Auto fire or melee. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Blaster.Scripts.ShotResolver` (ModuleScript) | 37,258 / 1179613095 | 37,622 / 1129572665 | The RPG blast's flash is a particle burst cloned from `Blaster.Objects.RPGBlast` instead of an engine `Explosion` (whose bang cannot be silenced); damage, Tagged/Damaged/Eliminated and knockback unchanged. Attribute appended. |
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` (LocalScript) | 54,037 / 193228620 | 54,188 / 3423576501 | A gamepass weapon's grid card reads OWNED (owned colour) once the pass is owned, instead of GAMEPASS. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Weapons.Scripts.WeaponShopService` (Script) | 19,042 / 2603572961 | 19,057 / 135750645 | `CATALOG_ATTRIBUTES` carries `Description`, so the shop's detail card can show it (the catalog copied only listed attributes). Attribute appended. |

Instances (not scripts): `Description` on all 38 `ServerStorage.Weapons` Tools; `MuzzleAttachment` moved and given a `FlashEmitter` on the Glock 17, Benelli M4 and Spas 12; new `ReplicatedStorage.Blaster.Scripts.GuiController.DryFire` (Sound) and `ReplicatedStorage.Blaster.Objects.RPGBlast` (Part). Details: `CityMerge/known-issues/weapons.md`.

The five sources exported to `CityScripts/`; on-disk Adler-32 equals the place (5 / 5). City suites 262 / 262 / 0; heist 620 passed / 1 failed (Zone sweep only). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 4 (walk speed, level-up popup, nameplates). Same columns; old = the place before this task (first export: none on disk).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `StarterPlayer.StarterCharacterScripts.Animate2` (LocalScript) | 24,177 / 3211711448 | 24,681 / 4181753046 | The backward WalkSpeed clamp keys on input (`isInputBackwards`, `Humanoid.MoveDirection`), not velocity: pressed against a wall, collision bounce read as walking backwards and swung WalkSpeed 20 / 25.83. Backward walking still clamps to 20; the reversed walk animation is unchanged. Attribute set. First export. |
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.LevelingHud` (LocalScript) | 9,375 / 3990833154 | 11,920 / 4084567681 | `placePopup()` at each level-up, from the live heist HUD boxes: desktop, the popup's top on the toast's bottom (centred, full size); smaller side under `UI_SMALL_SCREEN_THRESHOLD`, scaled to the gap left of the duffel (0.71 at 844 x 390) and centred on the duffel vertically; no heist HUD, the template's place. Attribute set. First export. |

Step 3 (two names over a player): no change. `IndicatorClient` draws only damage numbers for the shooter; nothing clones `Workspace.Dev.UI.OverheadGui`.

The two sources exported to `CityScripts/`; on-disk Adler-32 equals the place (2 / 2). City suites 262 / 262 / 0; heist 621 passed / 0 failed (the Zone sweep passed this run). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Fix wave after the whole-branch review (`Batch: known issues pass fixes`). Same columns; old = the place before the wave.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.LevelingHud` (LocalScript) | 11,920 / 4084567681 | 12,131 / 4111193995 | `placePopup` needs only the camera and the toast on desktop; the duffel widget is required only in the small-screen branch (missing there: the template's place). Attribute appended. |
| 2026-11-17 | `ServerScriptService.Weapons.Scripts.WeaponShopService` (Script) | 19,057 / 135750645 | 19,054 / 1661690566 | `restoreEquippedWeapons` asks `findLiveTool` (Backpack and character) before granting, so a held Tool is not duplicated. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Spraypaint.Scripts.SpraypaintService` (ModuleScript) | 14,939 / 478840120 | 14,858 / 524183879 | Stale comment ("handleBuyRequest validates weaponName") dropped with the type check after it, unreachable behind the guard above. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.CashClaimVFX` (ModuleScript) | 11,096 / 1118537320 | 11,096 / 4226909799 | Orphaned CashHud comment moved to where `_displayedValue` is set in `new`. Attribute appended. |

Exported to `CityScripts/`; on-disk Adler-32 equals the place (4 / 4). City suite 262 / 262 / 0. After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

## Heist layers 2026-11-17

Task 1 (shared bonus loot and heavy-loot carry, `Batch: heist layers shared carry and bonus loot`). Same columns; old = the place before this task (none = new script).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Heist.BankInstance` (ModuleScript) | 11,944 / 2753960156 | 12,615 / 1455160887 | `AddBonus(player, amount)`: TryAddDuffel's guards (`inactive`, `not_participant`, `invalid_amount`) with no cap check; fires `DuffelChanged(..., "add")`. Attribute set. First export. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.CarryState` (ModuleScript) | 4,750 / 3260318798 | 5,687 / 3427714956 | `PickUp` sets the character attribute `CarrySpeedCap` from a numeric `supplyObject.speedCap`; `Drop`/`Consume`/`Forget` clear it on the current character (none: no error). New `GetCarried(player)`. Attribute set. First export. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.SupplyObject` (ModuleScript) | 21,402 / 4234262248 | 23,058 / 517730419 | Deps `bankOnly`, `speedCap` (fields), `startHidden` (OnSessionStart leaves it hidden, no prompt); `GiveTo(player)` (prompt path via `_take`, isBlocked/hasDuffel included, only when hidden and available); `Close()` (prompt, highlight and GiveTo off until OnSessionStart). Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Services.SupplierSale` (ModuleScript) | 1,845 / 159481646 | 2,222 / 4116315993 | Refuses a carry whose object has `bankOnly == true` with `0, "bank_only"` (after the reach check, nothing consumed); `BANK_ONLY_TOAST`. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.Movement.Constants` (ModuleScript) | 4,387 / 169647085 | 4,805 / 3711248031 | `CARRY_SPEED_CAP_ATTRIBUTE = "CarrySpeedCap"`, `CARRY_SPEED_CAP = 12`. Attribute set. First export. |
| 2026-11-17 | `StarterPlayer.StarterCharacterScripts.Animate2` (LocalScript) | 24,681 / 4181753046 | 25,120 / 2723549544 | `resolveMovementTargets`: while `CarrySpeedCap` is set the target is `min(20, cap)` (no sprint boost) and WalkSpeed is clamped to the cap at once. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Movement.Scripts.SprintAuthority` (ModuleScript) | 10,951 / 294162375 | 11,627 / 4057754890 | `tick`: `CarrySpeedCap` forces `granted = false`, clamps WalkSpeed down to the cap (after the landing ramp, before stun) and joins the below-baseline release. Attribute set. First export. |
| 2026-11-17 | `StarterPlayer.StarterCharacterScripts.Crouching` (LocalScript) | 11,560 / 3591834587 | 11,931 / 1491634994 | Crouch speed `min(config.Speed, CarrySpeedCap)`. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.SuppliesServer` (Script) | 7,909 / 1266664936 | 8,169 / 1008868426 | `bank_only` sale outcome: `net:Toast` with `BANK_ONLY_TOAST`, then `SupplierResult(player, "bank_only")`. Attribute appended. |
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.SupplierDialogueController` (LocalScript) | 5,684 / 994812562 | 5,826 / 3068383468 | `bank_only` result closes the plate (no quip; the toast says why). Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Services.CarryGetaway` (ModuleScript) | none | 2,612 / 1555401882 | New: banks a matching carried object for `value` Cash at the getaway; wraps `Heist.Services.Getaway` (`getDuffel` = carrying a matching object and 1 or 0); optional `addActiveRobbery`. Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.BankInstanceSpec` (ModuleScript) | 18,856 / 3141173296 | 20,711 / 2909984286 | 2 AddBonus cases. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.CarryStateSpec` (ModuleScript) | 8,455 / 2856210109 | 10,726 / 82790989 | 6 cases: CarrySpeedCap set/cleared by Drop, Consume, Forget; none without speedCap; no character; GetCarried. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.SupplyObjectSpec` (ModuleScript) | 24,283 / 3956730909 | 27,619 / 1485979581 | 5 cases: fields, startHidden, GiveTo once, GiveTo refusals, Close. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.SupplierSaleSpec` (ModuleScript) | 4,191 / 113863477 | 4,963 / 2622975094 | Stub gains `GetCarried`; bank_only case. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.CarryGetawaySpec` (ModuleScript) | none | 4,621 / 1058397731 | New: 6 cases (199 / 200 / inside at 300 / non-matching / no carry / addActiveRobbery + Destroy). Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,614 / 3188154631 | 2,662 / 4031934301 | `CarryGetawaySpec` registered. Attribute appended. |

The 17 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (17 / 17). City suites 262 / 262 / 0; heist 641 passed / 0 failed (21 new; the Zone sweep passed this run). Play: `CarrySpeedCap = 12` with sprint held, client WalkSpeed max 12 over 3 s and IsSprinting never granted; cleared, walk 20 and sprint 38; server WalkSpeed 12 then 20. After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 2 (component hooks, `Batch: heist layers component hooks`). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ReplicatedStorage.SharedSystems.LockedDoor` (ModuleScript) | 17,973 / 2205808909 | 20,342 / 2712482612 | Deps `onSolved(player)` (once at a solve, after `LockpickSolved`, pcall) and `objectText` (prompt ObjectText, default "Locked Door"); `Open(player) -> boolean` (closed + Active: `_open()` = same tween/sound/prompt-off as a solve, no `onSolved`); module table player -> door: a trigger drops the player's attempt on any other door, stop/exit judged only by the owning door, entry cleared on solve, exit, `OnSessionStart`, `Seal` (weak keys). Old Adler from the pre-edit source rebuilt by reversing the edit (no export existed). Attribute set. First export. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.RobbableObject` (ModuleScript) | 11,782 / 2283063084 | 12,614 / 2576670976 | Deps `blockedReason` (onRefused reason when `isBlocked` refuses, default `carrying_supplies`) and `onRobbed(player)` (after a successful rob, pcall); `Close()` (Robbed = true, prompt and highlight off, `_unlocked` kept true so a later `Unlock()` is a no-op until `OnSessionStart`). Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Components.MasterComputer` (ModuleScript) | 13,116 / 861509204 | 13,430 / 2781019617 | Dep `onBreached(player)`, called (pcall) after `RevealHackCode` at the breach; a re-trigger of a hacked player does not reach it. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Components.GuardPost` (ModuleScript) | 12,166 / 1323913687 | 12,455 / 2201465702 | `Alert()`: sets `_activated` when the guard is alive (no-op when dead), so `Update` engages without a player in activation range. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Services.Net` (ModuleScript) | 17,468 / 1330551155 | 17,801 / 819661523 | Remote `BroadcastHijacked` in `REMOTE_NAMES`; `NotifyBroadcastHijacked(playerName)` = `FireAllClients(playerName)`. Attribute set. First export. |
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.NotificationClient` (LocalScript) | 7,855 / 368995753 | 8,183 / 3481984699 | `BroadcastHijacked` listener: `show("<b>%s</b> hijacked the News Station broadcast!", true)` (existing template, alarm box). Attribute appended. |
| 2026-11-17 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 65,942 / 574845500 | 66,147 / 2113189410 | Duffel: `amount = max(base, extrapolate(...))` (extrapolate clamps at the cap), the full-state text shows `amount / cap`; the fill ratio already clamps at 1. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.LockedDoorSpec` (ModuleScript) | 26,872 / 3324850995 | 30,344 / 3186798962 | 3 tests: onSolved + objectText; Open; one live attempt per player (two doors on one shared net). `newDoor` passes `onSolved`/`objectText`. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.RobbableObjectSpec` (ModuleScript) | 21,338 / 42264812 | 23,855 / 526984950 | 3 tests: blockedReason, onRobbed, Close (incl. a later Unlock). Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.MasterComputerSpec` (ModuleScript) | 22,770 / 1444510797 | 23,744 / 3961500699 | 1 test: onBreached once, not on re-trigger. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.GuardSpec` (ModuleScript) | 12,206 / 1737840580 | 14,334 / 2029584357 | 2 tests: Alert engages a guard with a participant at 90 studs (activation 60, sight 120; `_candidates` stubbed on the instance), not without; Alert on a dead guard is a no-op. Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.NetSpec` (ModuleScript) | 3,295 / 2989902110 | 3,316 / 3946991700 | `BroadcastHijacked` pinned in the remote list. Attribute set. First export. |

The 12 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (12 / 12). City suites 262 / 262 / 0; heist 649 passed / 1 failed (9 new; the failure is the Zone "real occupancy sweep" timing). Play: `NotifyBroadcastHijacked("Tester")` from a temporary server Script -> client card `Body.Text` = `<b>Tester</b> hijacked the News Station broadcast!`, AlarmBox visible, card 420 x 122. A participant at 15,000 + `AddBonus` 2,500 = 17,500 (cap 15,000) pushed through `SendDuffel("Bank", ...)`: `AmountText` "17,500 / 15,000", `BarFill` Size {1,0},{1,0}, 268 px of its 268 px track. After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 3 (SlowFoods manager chase, `Batch: SlowFoods manager chase`). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.SlowFoodsServer` (Script) | 10,278 / 2040003535 | 15,074 / 1990621141 | Second `NPCSpawnManager` (template `Manager`, tag `SlowFoodsManager`, controller `FleeingManager`, escape point `SlowFoodsMarkers.ManagerEscapePoint`); key holder = player attribute `SlowFoodsKey`, one per run, cleared on Seal, Rearm, death (`Humanoid.Died`) and leave (`onPlayerRemoving`); "Use Key" prompt (key F / ButtonY, hold 0, 10 studs, server re-measured) on `LockedDoor`'s handle, enabled at session start, off on Seal / open / lockpick solve (`onSolved`), non-holder toast "You need the manager's key."; `StorageSafe` `RobbableObject` (RobSafePrompt, `ManagerSafeAmount`, `payWith = "bonus"`, `isBlocked` = not the key holder, `blockedReason = "no_key"`); boot asserts for the Manager spawner (exactly 1), template, escape point and safe. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.RestaurantShared.Config` (ModuleScript) | 3,701 / 2765807960 | 4,029 / 202853836 | `ManagerKeyRange = 10`, `ManagerSafeAmount = 3000`, `ManagerKeyHold = 1`. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.RobbableObject` (ModuleScript) | 12,614 / 2576670976 | 12,918 / 1220821837 | Dep `payWith`: `"bonus"` pays through `bank:AddBonus`; any other value keeps `TryAddDuffel` (default path unchanged, pinned). Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Components.FleeingManager` (ModuleScript) | none | 8,682 / 3380317797 | New: the Manager controller (`new/OnSessionStart/Seal/Destroy/.model`, `state`, `TryTakeKey`), server-timed "Take Key" hold, pathing (GuardPost pattern, AgentRadius 1), hidden at the escape point until Rearm. Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.FleeingManagerSpec` (ModuleScript) | none | 7,893 / 714939718 | New: 11 cases. Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.RobbableObjectSpec` (ModuleScript) | 23,855 / 526984950 | 25,490 / 1551121651 | 3 cases: default refuses over the cap, `payWith = "bonus"` pays over it once, bonus refuses a non-participant. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.WorldSpec` (ModuleScript) | 50,282 / 3545750290 | 52,330 / 3965556520 | Spawners 9 -> 10 (+1 Manager under SlowFoods); 1 case: Manager template (DisplayName, Witness + Invulnerable, untagged), ManagerEscapePoint, StorageSafe (no BankSafe tag, Highlight, SafeRobSound beside a ParticleEmitter). Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,662 / 4031934301 | 2,721 / 162300076 | `FleeingManagerSpec` registered. Attribute appended. |

Studio objects (not scripts): `RestaurantShared.ModelTemplates.Manager` (clone of Cashier: Humanoid DisplayName "Manager", DisplayDistanceType Subject, NameDisplayDistance 60, WalkSpeed 8; tags Witness, Invulnerable), `Workspace.SlowFoods.NPCSpawners.ManagerSpawner` (clone of CashierSpawner1, `NPCTemplate = "Manager"`, at (94.7, 1.5, 1714)), `Workspace.SlowFoodsMarkers.ManagerEscapePoint` (2x1x2, invisible, at (150, 1.5, 1785)), `Workspace.SlowFoods.StorageSafe` (clone of a Bank safe, BankSafe tag removed, its two SurfaceGuis left out, at (62.5, 2.625, 1706.5) against the storage room's south wall facing the room).

The 8 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (8 / 8). City suites 262 / 262 / 0; heist 664 passed / 1 failed (15 new; the failure is the Zone "real occupancy sweep" timing). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 4 (Gas2Go ATM rip-out, `Batch: Gas2Go ATM rip-out`). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.Gas2GoServer` (Script) | 12,817 / 803557551 | 14,597 / 1826010825 | The ATM is built as `Heist.Components.ATMRipOut` (Rob ATM as before + Rip Out ATM); pickup = `CarryState:PickUp(ATMCarryTool)` + toast "Carry it 200 studs clear of the gas station to cash in."; `hasDuffel` like the barrels; a `CarryGetaway` (StatusBillboardAnchor, `EscapeDistance`, inside = the location's `zoneService` on `Station`, `ATMRipAmount`, `WantedService.addActiveRobbery`) stepped from a new `heartbeatExtras` and forgotten in `onPlayerRemoving`. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.Gas2GoShared.Config` (ModuleScript) | 3,199 / 3526898118 | 3,445 / 792494017 | `ATMRipAmount = 9000`, `ATMRipHold = 10`. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.SharedSystems.SupplyObject` (ModuleScript) | 23,058 / 517730419 | 24,248 / 4043999258 | Deps `enforceHold` + `clock`: a prompt with a HoldDuration is honoured only after a server-seen `PromptButtonHoldBegan` at least HoldDuration - 0.15 s earlier (FleeingManager's pattern; HoldDuration 0 re-pickup exempt); `_onTriggered` refuses when no prompt is armed (a late trigger after `Close`). Default path unchanged. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Weapons.Scripts.EquipService` (Script) | 2,377 / 880165296 | 2,854 / 400156196 | Equip and unequip requests are ignored while `CarryState:IsCarrying(player)`. Measured before: hotbar key on the Deagle swapped the carry Tool out (CarryState's Unequipped re-equip lost) and 3 shots fired (ammo 10 -> 7). Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Components.ATMRipOut` (ModuleScript) | none | 2,813 / 2224404498 | New: RobbableObject (rob) + SupplyObject (rip: bankOnly, speedCap = `Movement.Constants.CARRY_SPEED_CAP`, enforceHold) on the one ATM model; each closes the other; Seal closes an untouched ATM (stays standing) and hides a ripped one; Rearm puts a ripped one back, promptless. Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.Gas2GoRipSpec` (ModuleScript) | none | 6,808 / 2152186568 | New: 9 cases (config, template, both armed, rob closes rip, rip closes rob, server-timed hold, bankOnly/speedCap/value, untouched ATM through Seal/Rearm, ripped ATM back at Rearm). Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.Gas2GoConfigSpec` (ModuleScript) | 2,896 / 672064278 | 3,144 / 2481795204 | 1 case: ATMRipAmount 9000, ATMRipHold 10. Attribute set. First export. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.SupplyObjectSpec` (ModuleScript) | 27,619 / 1485979581 | 29,051 / 3470988621 | 1 case: enforceHold (no hold / short hold refused, full hold honoured, instant re-pickup exempt, default unchanged); Close case also refuses a late trigger. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,721 / 162300076 | 2,775 / 2345635765 | `Gas2GoRipSpec` registered. Attribute appended. |

Studio objects (not scripts): `ReplicatedStorage.Gas2GoShared.PromptTemplates` (new Folder) with `RipOutATMPrompt` (clone of RobATMPrompt: "Rip Out ATM" / "ATM Machine", hold 10, key F / ButtonY so it shows beside Rob ATM's E under OnePerButton) and `PickUpATMPrompt` (clone of RepickupSuppliesPrompt: "Pick Up ATM" / "ATM Machine", hold 0); `ReplicatedStorage.Gas2GoShared.ModelTemplates` (new Folder) with `ATMCarryTool` (Tool, CanBeDropped false, RequiresHandle true, `IsSupplyCarryTool = true`, Grip (0, 0, -0.5); invisible massless 1x1x1 `Handle` plus copies of the ATM's 48 parts and its 2 text models, scaled 0.5 to 2 x 3.75 x 1.75, unanchored, non-colliding, massless, welded to the Handle).

The 9 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (9 / 9). City suites 262 / 262 / 0; heist 675 passed / 1 failed (11 new; the failure is the Zone "real occupancy sweep" timing). After: 1 enabled SpawnLocation, no temporary object.

NOT saved / NOT published

Task 5 (NewsStation broadcast takeover, `Batch: NewsStation broadcast takeover`). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-17 | `ServerScriptService.NewsStationServer` (Script) | 20,609 / 4028888056 | 22,014 / 1247793448 | Builds `Heist.Components.BroadcastDesk` on `Workspace.NewsStation.BroadcastDesk` (registered on the bank before the MasterComputer); MasterComputer `onBreached` -> `desk:Arm()`; `onLive` -> `net:NotifyBroadcastHijacked(name)`, each participant below `BroadcastHeatFloor` gets `WantedService.addHeat(p, floor - heat, "broadcast")` and a toast, every guard post `:Alert()`; `onComplete` -> `bank:AddBonus(p, BroadcastPayout)` + toast; `Update` in `heartbeatExtras`, `Forget` in `onPlayerRemoving`. Attribute appended. |
| 2026-11-17 | `ReplicatedStorage.NewsStationShared.Config` (ModuleScript) | 5,669 / 538875747 | 6,179 / 2656520198 | `BroadcastSeconds = 45`, `BroadcastRange = 12`, `BroadcastPayout = 6000`, `BroadcastHeatFloor = 3`. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Components.BroadcastDesk` (ModuleScript) | none | 7,440 / 306373648 | New: states locked / armed / live / done; "Go Live" prompt (hold 1, server-timed, range `BroadcastRange`); air time counts while a living participant is within range (pauses, never resets); at `BroadcastSeconds` the participants in range go to `onComplete`; Seal ends it unpaid; billboard text OFF AIR / GO LIVE / LIVE m:ss / AIRED. Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.BroadcastDeskSpec` (ModuleScript) | none | 8,505 / 4013410658 | New: 9 cases (config values, locked until Arm, go live once, refusals, pause not reset, completion payees once, two payees, Seal while live, server-timed hold). Attribute set. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.WorldSpec` (ModuleScript) | 52,330 / 3965556520 | 53,808 / 2928575922 | 1 case: `NewsStation.BroadcastDesk` has a Highlight and a BillboardGui with a TextLabel, stands inside NewsroomZone within 25 studs of the MasterComputer, all parts anchored, no script inside. Attribute appended. |
| 2026-11-17 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,775 / 2345635765 | 2,833 / 1650630827 | `BroadcastDeskSpec` registered. Attribute appended. |

Studio objects (not scripts): `Workspace.NewsStation.BroadcastDesk` (Model, pivot at the computer): `Desk` (clone of the MasterComputer's 13-part desk, at (-674, 4.125, 1002.5), length along x, in the lobby corner against the west wall in front of the big screen, about 16 studs from the MasterComputer through the counter), `Computer` (clone of the `ClipNews Building.Computer` at (-670.2, 6.6, 994.0), on the desk facing the lobby), `Highlight` (red, off until armed), `LiveBillboard` (BillboardGui on `Computer.Part`, 160 x 44, 3.5 studs up, MaxDistance 80) with `LiveLabel` (TextLabel, red GothamBold on a dark rounded panel). No uploads.

The 6 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (6 / 6). City suites 262 / 262 / 0; heist 686 passed / 0 failed (10 new; the Zone "real occupancy sweep" passed this run). After: 1 enabled SpawnLocation, no temporary object.

Task 6 (Bank deposit boxes and gold bar, `Batch: Bank deposit boxes`). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ServerScriptService.HeistServer` (Script) | 49,256 / 1964564583 | 51,780 / 4096149803 | After the safes: `goldBar` = `SupplyObject` on `Workspace.BankVault.GoldBar` (`startHidden`, `bankOnly`, `speedCap` = `CARRY_SPEED_CAP`, `isBlocked` = carrying, `onPickup` -> `carryState:PickUp(GoldBarTool)`), registered; `depositBoxes` = `Heist.Components.DepositBoxes` over `BankVault.DepositBoxes.DepositBox1..8` (roll = `Config.Debug.DepositBoxContents` or `DepositBoxLoot.roll(Random.new(), count, GoldBarChance)`), registered; `goldGetaway` = `CarryGetaway` (`isInsideBank`, `HeistMarkers.StatusBillboardAnchor`, `GoldBarValue`, `addActiveRobbery`) stepped after `getaway:Step()` and forgotten on PlayerRemoving; `depositBoxes:Unlock()` in the vault-door latch. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.HeistShared.Config` (ModuleScript) | 14,301 / 3575820392 | 14,889 / 2378396731 | `DepositBoxCount = 8`, `DepositBoxCash = 1500`, `GoldBarChance = 0.5`, `GoldBarValue = 8000`; `Config.Debug.DepositBoxContents = false` (Play-check seam, off). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.SupplyObject` (ModuleScript) | 24,248 / 4043999258 | 24,500 / 2804342072 | A `startHidden` object is hidden from construction (it showed at Idle until its first session: the gold bar sat visible on the box cabinet at boot, measured Transparency 0 in Play). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.HeistShared.DepositBoxLoot` (ModuleScript) | none | 688 / 2170676514 | New, pure: `roll(rng, count, goldChance)` -> at most one "gold" (chance goldChance), the rest "cash" 2/3, "empty" 1/3. Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Components.DepositBoxes` (ModuleScript) | none | 4,172 / 4270750360 | New: one bank component holding 8 `LockedDoor`s ("Deposit Box", location "Bank", hinge swing 100 deg); contents rolled at `OnSessionStart` with doors shut and promptless; `Unlock` arms them (once, Active only); `onSolved`: cash -> `AddBonus` + "+1,500", empty -> "Empty.", gold -> `GiveTo` unless carrying, then if not carrying the bar it is `DropAt` in front of the box with "Gold bar! Your hands are full: it's on the floor.". Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.DepositBoxLootSpec` (ModuleScript) | none | 2,439 / 255462757 | New: 5 cases (config values and seam off, shape, 2,000 seeded runs, goldChance 0 and 1). Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.DepositBoxesSpec` (ModuleScript) | none | 8,872 / 1787526396 | New: 10 cases (roll at session start, locked until Unlock, Bank payload, cash, empty, gold given, gold when the pickup did not happen, gold while carrying, one click two attempts judged once, Seal and next session, Unlock outside Active). Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.SupplyObjectSpec` (ModuleScript) | 29,051 / 3470988621 | 29,513 / 2118824583 | 1 case: startHidden hidden from construction; a drop still shows the authored look. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.WorldSpec` (ModuleScript) | 53,808 / 2928575922 | 56,392 / 2273501295 | 1 case: 8 deposit boxes (Hinge PrimaryPart, ProximityPart Handle, inside VaultZone), GoldBar with a Highlight, GoldBarTool, PickUpGoldBarPrompt, PlaceWhatYouWawnt gone, CarrierLedge beside the moving platform. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,833 / 1650630827 | 2,949 / 1427489501 | `DepositBoxLootSpec` and `DepositBoxesSpec` registered. Attribute appended. |

Studio objects (not scripts): `Workspace.BankVault.DepositBoxes` (Model: `Cabinet` body, top, plinth and 8 dark slots; `DepositBox1..8`, each `Hinge` (PrimaryPart) + `Door` + `Plate` + `ProximityPart Handle`; built from parts: no deposit box, drawer or small locker exists in the place) on the vault's east side, now at x 1377.9..1382.3, z 2608.3..2616.7 against the east wall (built at x 1371..1375, moved east in Studio after the build; read back in fix round 1), doors facing the aisle; `Workspace.BankVault.GoldBar` (Model: `Bar` = clone of the quarantined HQ bunker `GoldB` MeshPart, mesh rbxassetid://136863571256426, plus a Highlight and the supply pickup/drop sounds cloned from Gas2Go); `ReplicatedStorage.HeistShared.ModelTemplates.GoldBarTool` (Tool, `IsSupplyCarryTool`, Handle = the same `GoldB` mesh); `ReplicatedStorage.HeistShared.PromptTemplates.PickUpGoldBarPrompt` (clone of RepickupSuppliesPrompt, "Pick Up Gold Bar" / "Gold Bar"). `Workspace.BankVault.PlaceWhatYouWawnt` moved to `ServerStorage.CityQuarantine.DepositBoxPlaceholder` (OriginalPath, OriginalCFrame). Carrier route out of the vault (obby, Challenge 4): `Workspace.BankVault.CarrierLedge` (clone of the obby's 4x4 pad model) at (1361.8, -95.25, 2511) beside the moving platform's far end; the obby pad group at z 2472 (pad model, 2 supports, 3 light models) moved +1.5 studs in x (each has `HeistLayersMovedFrom`); restored in fix round 1, see below. No uploads.

The 10 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (10 / 10). City suites 262 / 262 / 0; heist 702 passed / 1 failed (the Zone "real occupancy sweep" only). After: 1 enabled SpawnLocation in Workspace, no temporary object.

Task 6 fix round 1 (`Batch: Bank deposit boxes fixes`). Same columns; old = the value after Task 6 (or the place before, for scripts Task 6 did not touch).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ServerScriptService.HeistServer` (Script) | 51,780 / 4096149803 | 51,820 / 3009172709 | `CARRY_SPEED_CAP` required at the top with the other requires (was inline). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Components.DepositBoxes` (ModuleScript) | 4,172 / 4270750360 | 4,498 / 3653495619 | Each box's LockedDoor gets `canAttempt = bank:IsParticipant` (a bystander's trigger starts nothing and leaves the contents); `_onSolved` returns at once outside an Active session (every branch, gold included). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.LockedDoor` (ModuleScript) | 20,342 / 2712482612 | 20,562 / 4039671875 | Optional `canAttempt(player)` dep checked in `_onTriggered` after the Active check; absent = as before. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.CarryState` (ModuleScript) | 5,687 / 3427714956 | 6,398 / 2443621705 | With the `CarrySpeedCap` attribute, the character's parts in Default move to collision group `Carrier` (and back to Default when the cap clears): carriers collide with the carrier-only ledges. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.CarrierLedgeView` (LocalScript) | none | 1,592 / 1438720945 | New: while the local character has `CarrySpeedCap`, parts and textures of models tagged `CarrierLedge` show their `CarrierTransparency`; otherwise 1. Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.DepositBoxesSpec` (ModuleScript) | 8,872 / 1787526396 | 11,442 / 2429208161 | 4 cases: seal with a lockpick in flight on a gold box (later clicks judge and give nothing), two players race one gold box (one solve, one GiveTo, one gold toast), non-participant refused, no payout from an inactive solve. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.CarryStateSpec` (ModuleScript) | 10,726 / 82790989 | 11,116 / 3332034957 | The capped-carry cases also check `Carrier` group on pickup and Default after Drop / Consume / Forget; an uncapped carry stays Default. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.WorldSpec` (ModuleScript) | 56,392 / 2273501295 | 57,429 / 2099133150 | Ledge pins: `Carrier` and `CarrierLedge` groups registered, Default/CarrierLedge not collidable, Carrier collides with CarrierLedge and Default; `CarrierLedge` and `CarrierLedge2` tagged, in place, every part in group CarrierLedge and Transparency 1. Attribute appended. |

Studio objects: the obby pad group at z 2472 restored to its original CFrames (6 instances, read back: largest CFrame component difference 1e-6; `HeistLayersMovedFrom` removed); `Destination 1` at its original (1366.3, -95, 2508.8). Collision groups `Carrier` and `CarrierLedge` registered (Default/CarrierLedge off, Carrier/CarrierLedge on, Carrier/Default on). `Workspace.BankVault.CarrierLedge` and new `CarrierLedge2` (both clones of the obby's own 4 x 4 pad model; CarrierLedge2 at (1363.2, -94.25, 2476.9) between the beam end and the z 2472 pad): tag `CarrierLedge`, every part in group `CarrierLedge`, Transparency 1 (authored value kept in attribute `CarrierTransparency`, textures too), CanTouch off, ModelStreamingMode Atomic.

The 8 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (8 / 8). City suites 262 / 262 / 0; heist 706 passed / 1 failed (the Zone "real occupancy sweep" only). After: 1 enabled SpawnLocation in Workspace, no temporary object.

NOT saved / NOT published

## Open items pass 2026-11-18

Task 1 (police, wanted level and enemy AI, `Batch: open items police and enemy AI`). Same columns; old = the place before this task.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ServerScriptService.Wanted.WantedService` (ModuleScript) | 12,214 / 2218288967 | 14,516 / 2846783794 | Developer decision 1: `_onDied` clears heat only after damage the server saw within `RESET_DAMAGE_SECONDS`; otherwise (a self-reset) the heat carries and the search window and drain restart at the death. Damage = a `HealthChanged` drop the player survived, or a Blaster `Tagged` hit while no ForceField is on (`_onTaggedEvent`, connected in `start()`); a drop straight to 0 is what a client reset looks like on the server (measured), so it is not damage. `inActiveRobbery(player)`; `_onPlayerRemoving` also forgets the damage time. Attribute set. |
| 2026-11-18 | `ServerScriptService.Wanted.PoliceDispatcher` (ModuleScript) | 21,708 / 1953592970 | 22,319 / 1938311026 | Developer decision 3: `believedPosition` = the robbery's entrance or the player's position during an active robbery, else the last-seen spot, also in the search window (no live tracking). `tick` keeps a squad while its player is wanted but between characters (a self-reset). Attribute set. |
| 2026-11-18 | `ServerScriptService.Enemy.Scripts.EnemyAI` (ModuleScript) | 40,610 / 2586628771 | 42,838 / 3716075725 | `_allyInLine` (gun weapons only: the first hit on the muzzle-to-aim line, at the bullet's radius, is a humanoid the shooter cannot damage and not the target) holds the shot in `_fireOnce`; `_thinkAttack` calls `_sidestep` (walk `ALLY_SIDESTEP` across the line, away from the ally) while an ally was in the line within two thinks. Melee exempt (the 2026-09-21 cluster). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Wanted.Constants` (ModuleScript) | 3,331 / 1706559087 | 3,575 / 2502907630 | `RESET_DAMAGE_SECONDS = 5`. Attribute set. |
| 2026-11-18 | `ReplicatedStorage.Enemy.Constants` (ModuleScript) | 6,525 / 631277248 | 6,732 / 667011660 | `ALLY_SIDESTEP = 4`. Attribute set. First export. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.WantedService_Test` (ModuleScript) | 21,569 / 2875280365 | 24,594 / 1301158880 | "death clears heat" becomes four cases: a death right after damage clears; a self-reset keeps the stars (damage 5.5 s earlier does not count) and the window and drain restart at the death; a lethal `Tagged` hit clears; a `Tagged` hit under a ForceField does not count. Attribute set. |

The 6 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (6 / 6). City suites 265 / 265 / 0 (262 + 4 new - 1 replaced); heist 707 passed / 0 failed. Officer rig builds (item 3): no change, measured already one build per frame. Outfit staging folder: not in the city. After: 1 enabled SpawnLocation in Workspace, no temporary object, no Workspace attribute.

NOT saved / NOT published

Task 2 (heist layers final review fixes and layer leftovers, `Batch: heist layers final review fixes`). Same columns; old = the place before this task (`LocationServerSpec`: its last row above / git HEAD, not checksummed in Studio before the edit; `Forfeit` and `ForfeitSpec`: exported from Studio at the start of this task, first export).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ReplicatedStorage.HeistShared.Config` (ModuleScript) | 14,889 / 2378396731 | 15,577 / 273243205 | `DepositBoxClickWindow = 0.25` (M2), `MaxBagGrant = 100000`, `CarryGetawayAttribute = "CarryGetaway"`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.BankInstance` (ModuleScript) | 12,615 / 1455160887 | 12,888 / 683301957 | `AddBonus` and `TryAddDuffel` refuse NaN, infinite, non-positive and > `MaxBagGrant` (`invalid_amount`). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.LockedDoor` (ModuleScript) | 20,562 / 4039671875 | 23,631 / 2231801165 | C1: a click is judged only while `canAttempt` still allows it and a living character is within the prompt range + 6 studs (`measure`, injectable); otherwise the attempt drops and `LockpickSolved` closes the screen. A death drops the attempt (`Humanoid.Died:Once`). M4: `Forget(player)`, run by each door on `PlayerRemoving`; `Destroy` drops every attempt. M2: opt-in `maxLatencyCompensation` (default 1 s), header comment rewritten. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Components.DepositBoxes` (ModuleScript) | 4,498 / 3653495619 | 4,970 / 2575992680 | I1: `canAttempt` = participant and not carrying. Passes `measure` and `maxLatencyCompensation = config.DepositBoxClickWindow`. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.SupplyObject` (ModuleScript) | 24,500 / 2804342072 | 26,301 / 1711032110 | M3: opt-in `checkReach` (+ `measure`) on the prompt path (not on `GiveTo`). `Forget(player)` clears a begun hold. `GiveTo` returns false when `onPickup` returned false. `getawayLocation` field. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.RobbableObject` (ModuleScript) | 12,918 / 1220821837 | 15,226 / 955798949 | M1: opt-in `enforceHold` (+ `clock`, `_onHoldBegan`, `_onPromptTriggered`) copied from SupplyObject. M3: opt-in `checkReach` (+ `measure`). `Forget(player)`. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.CarryState` (ModuleScript) | 6,398 / 2443621705 | 6,851 / 3014874475 | A heavy carry also sets the character attribute `CarryGetaway` to the object's `getawayLocation` (cleared with the cap). Re-equip lock comment corrected (EquipService closes the swap). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Services.Forfeit` (ModuleScript) | 3,306 / 4250171293 | 3,869 / 2591699457 | I2 (controller ruling): optional `carryState`; an `Eject` from inside consumes a heavy carry (object with a numeric `speedCap`) before the teleport. Attribute set. First export. |
| 2026-11-18 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 20,132 / 3584032727 | 20,877 / 1915285561 | `has_duffel` "You're already holding a bag. Bank it first."; new `not_participant` "Join the robbery first."; optional `onDied(player)` hook at every character death; its `Forfeit` gets the carry state (I2 for Gas2Go). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Components.ATMRipOut` (ModuleScript) | 2,813 / 2224404498 | 4,508 / 4174048036 | A boot copy (unparented, taken before either component touches the model) rebuilds a missing or part-short ATM at `Rearm`. `Forget(player)`. Rob and rip `checkReach`; rip `getawayLocation = "Gas2Go"`; `onPickup` result passed through. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Components.FleeingManager` (ModuleScript) | 8,682 / 3380317797 | 9,165 / 1199256278 | `Forget(player)`, connected to `PlayerRemoving`, disconnected in `Destroy`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Components.BroadcastDesk` (ModuleScript) | 7,440 / 306373648 | 8,323 / 3307015662 | I1: optional `isBlocked` refuses Go Live (`carrying_supplies`) and drops carriers from the payees. Optional `onRefused(player, reason)` on a refused prompt press. Attribute appended. |
| 2026-11-18 | `ServerScriptService.NewsStationServer` (Script) | 22,014 / 1247793448 | 22,509 / 2612295366 | Desk `isBlocked` = carrying; refusals toasted for `not_participant` and `carrying_supplies`; the per-participant go-live toast removed (the city card says it); `onDied` forgets the Go Live hold. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Gas2GoServer` (Script) | 14,597 / 1826010825 | 14,921 / 1747985791 | `atmRipOut` forward-declared; `Forget` on leave and (`onDied`) death; rip `onPickup` returns the `PickUp` result. Attribute appended. |
| 2026-11-18 | `ServerScriptService.SlowFoodsServer` (Script) | 15,074 / 1990621141 | 15,841 / 1238792724 | Storage safe: `isBlocked` = carrying or no key (carrier told the carry message), `enforceHold`, `checkReach`; its hold forgotten on leave and death. "Use Key" tells a non-participant "Join the robbery first.". Attribute appended. |
| 2026-11-18 | `ServerScriptService.HeistServer` (Script) | 51,820 / 3009172709 | 53,166 / 1059659372 | `Forfeit` gets the carry state (I2: the seal eject takes the gold bar). Gold bar `getawayLocation = "Bank"`, `checkReach`, `onPickup` returns the `PickUp` result. Death pit calls `WantedService.markHurt` before `Health = 0`. Deferred at boot: every registered collision group except `Carrier` set non-collidable with `CarrierLedge`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Wanted.WantedService` (ModuleScript) | 14,516 / 2846783794 | 14,984 / 583930857 | Public `markHurt(player)`; a death that clears heat also clears `hurtAt` (Task 1 review minor 1). Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterCharacterScripts.Crouching` (LocalScript) | 11,931 / 1491634994 | 12,128 / 2420100717 | The stand-up speed is capped by `CarrySpeedCap` on the same frame (`carryCapped`). Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 66,147 / 2113189410 | 66,908 / 3845503917 | Developer decision 2: the getaway widget counts for a heavy carry too (`CarryGetaway` attribute equals the location), with or without an Active session. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.DepositBoxesSpec` (ModuleScript) | 11,442 / 2429208161 | 15,126 / 3233840170 | `measure` injected; 4 cases (solve finished from 200 studs, roster and death, carrier, click window); the carrying case drives `_onSolved`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.LockedDoorSpec` (ModuleScript) | 30,344 / 3186798962 | 35,096 / 3398623736 | `measure` injected in `newDoor`; 5 cases (reach, canAttempt per click, death, Forget/Destroy, click window). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.SupplyObjectSpec` (ModuleScript) | 29,513 / 2118824583 | 31,438 / 4276891337 | 3 cases (GiveTo refused carry, checkReach, Forget). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.RobbableObjectSpec` (ModuleScript) | 25,490 / 1551121651 | 27,754 / 3348964819 | 2 cases (enforceHold with Forget, checkReach). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.BroadcastDeskSpec` (ModuleScript) | 8,505 / 4013410658 | 10,239 / 1214447117 | 2 cases (carrier refused and refusals reported, carrier not paid). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.ForfeitSpec` (ModuleScript) | 7,680 / 3105030185 | 11,235 / 465997756 | 2 cases (heavy carry lost inside only; a gold holder in the vault at seal: no carry, no payout). Attribute set. First export. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.CarryStateSpec` (ModuleScript) | 11,116 / 3332034957 | 11,542 / 3799212739 | The capped-carry cases also pin `CarryGetaway` set and cleared; supplies set none. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.Gas2GoRipSpec` (ModuleScript) | 6,808 / 2152186568 | 9,617 / 2503303253 | `measure` injected; 4 cases (Forget, reach and location wiring, rebuild of a missing ATM, keep a whole one and rebuild a part-short one). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.FleeingManagerSpec` (ModuleScript) | 7,893 / 714939718 | 8,400 / 940425162 | 1 case (Forget). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.BankInstanceSpec` (ModuleScript) | 20,711 / 2909984286 | 21,750 / 2584225683 | 1 case (NaN, infinities and > `MaxBagGrant` refused by both). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.LocationServerSpec` (ModuleScript) | 24,257 / 3258815741 | 25,709 / 2880402448 | 2 cases (`onDied`; `not_participant` and `has_duffel` wording). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.WorldSpec` (ModuleScript) | 57,429 / 2099133150 | 58,158 / 3500618456 | Ledge pins: `EnemyCharacter` and `Ragdoll` registered in the place; every registered group except `Carrier` non-collidable with `CarrierLedge`; ledge parts `CanQuery` off. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.WantedService_Test` (ModuleScript) | 24,594 / 1301158880 | 26,085 / 10615261 | 2 cases (a damage death forgets the damage; `markHurt` counts as damage). Attribute appended. |

Studio objects (not scripts): `Workspace.BankVault.CarrierLedge` and `CarrierLedge2`, every part `CanQuery = false` (5 + 5; measured: with `CanCollide` on, `CanQuery` does not stop a `Carrier`-group raycast, so the collision group remains the real filter). Collision groups `EnemyCharacter` and `Ragdoll` (registered lazily by `EnemyRig` and `RagdollController`) registered in the place with their scripts' own self rule (non-collidable with themselves); every group except `Carrier` set non-collidable with `CarrierLedge`. No uploads, nothing quarantined.

The 32 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (32 / 32). City suites 267 / 267 / 0 (265 + 2); heist 733 passed / 0 failed (707 + 26). After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 3 (weapons, blaster and combat, `Batch: open items weapons and combat`). Same columns; old = the place before this task (each equal to its `CityScripts/` copy at 7c0309c).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ServerScriptService.Blaster.Scripts.Blaster.validateFireInterval` (ModuleScript) | 1,147 / 2461960568 | 2,227 / 605611656 | Item 1: a shot must also keep pace on the server receive clock (`ARRIVAL_SLACK = 0.1` s ahead of its due time); takes and returns the weapon's record `{ claimed, due }` (nil = refused). The 0.9 margin is kept on both clocks. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Blaster.Scripts.Blaster.validateShot` (ModuleScript) | 2,902 / 3565084835 | 2,988 / 456326661 | Passes its own `GetServerTimeNow()` as the receive time and stores the returned record per player and weapon name. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.ShotRate_Test` (ModuleScript) | 1,272 / 1910810662 | 4,316 / 3822350991 | Item 2: 0.85-of-an-interval case (fails if the factor becomes 0.5). Item 1: idle burst at 600 and 1200 rpm, honest stream at 600 / 1200 / 90 rpm with +-30 ms, melee press-stamp case; the five old cases on the new signature. 5 -> 11 cases. Attribute set. |
| 2026-11-18 | `ReplicatedStorage.Blaster.Scripts.BlasterController` (ModuleScript) | 18,826 / 1436954061 | 19,146 / 3049823395 | Item 3: the shot timestamp (and spread seed) is taken at the press, before a melee `swingDelay`. Item 8: the dry-fire cue plays for Semi only (no cue on a Burst re-press). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Blaster.Constants` (ModuleScript) | 5,020 / 3796454014 | 5,320 / 2026350663 | Item 6: `RPG_BLAST_RATE = 60`, `RPG_BLAST_EMIT_SECONDS = 0.25`, `RPG_BLAST_LIFETIME = 2` (same values). Attribute set. First export. |
| 2026-11-18 | `ServerScriptService.Blaster.Scripts.ShotResolver` (ModuleScript) | 37,622 / 1129572665 | 37,699 / 3051881499 | Item 6: `explode` reads the three blast numbers from `Blaster.Constants`. Attribute appended. |

Exported unchanged (item 9, first export): `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` 22,998 / 3125689737. The `FPSSystem/` mirrors stay the frozen snapshot.

Studio objects (not scripts):
- `ServerStorage.Weapons.APS` (developer decision 9, Stechkin machine pistol): `Category` AutoRifle -> Pistol, `magazineSize` and `_ammo` 26 -> 20, `damage` 14 -> 18, `range` 750 -> 700, `spread` 3.5 -> 2.2, `recoilMin` (1, 10) -> (-1, 6), `recoilMax` (4, 18) -> (3, 11), `unanchoredImpulseForce` 3 -> 4, `Price` 600 -> 650, `Description` "Full-auto machine pistol, 20 rounds, steadier fire". Kept: `fireMode` Auto, `rateOfFire` 750, `reloadTime` 1.8, the rifle-sized mesh and its rifle hold clips.
- `MuzzleAttachment` (Body-local, Orientation (0, 0, 0) -> (0, -90, 0)) and a `FlashEmitter` cloned from a same-class Tool, on 7 guns: Glock 18 (-1.210, 0.40, 0) -> (-0.90, 0.45, 0); M45A1 (-1.560, 0.40, 0) -> (-1.25, 0.41, 0); SIG M17 (-1.380, 0.40, 0) -> (-1.07, 0.44, 0); USP Compact (-1.080, 0.40, 0) -> (-0.77, 0.48, 0); MP443 (0.726, 0, 0) -> (-0.73, 0.45, 0); PB (1.297, 0, 0) -> (-1.30, 0.41, 0); S&W 29 (1.148, 0, 0) -> (-1.15, 0.25, 0) (donor Mateba 2006M; the six pistols from the Glock 17).
- Not changed (held for a decision, see the Task 3 report): APS, AR-18, HK G3, M14 EBR, Itacha Mag-10 muzzles stay at the stock end with no `FlashEmitter`: at the barrel end their third-person shot origin would sit 5.4 to 7.2 studs from the root part, past `validateShot`'s 5-stud standing limit.

The 7 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (7 / 7). City suites 273 / 273 / 0 (267 + 6); heist 732 passed / 1 failed (only `Zone` "the real occupancy sweep", 5.48 ms and 4.64 ms, the known flake). After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 3 fix round 1 (third-person shot origin, controller ruling option (a), `Batch: open items third-person shot origin`). Same columns; old = the place after Task 3 (851c388).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ReplicatedStorage.Blaster.Utility.thirdPersonAim` (ModuleScript) | new | 1,194 / 1089443442 | Pure: the third-person shot leaves the head toward the point the crosshair ray hits (the ray starts level with the head; the cast is injected). A hit level with the head keeps the camera's direction. Attribute set. |
| 2026-11-18 | `ReplicatedStorage.Blaster.Scripts.BlasterController` (ModuleScript) | 19,146 / 3049823395 | 19,563 / 1338451710 | Third person: origin = `thirdPersonAim(camera, head, range, castRays at CROSSHAIR_RAY_RADIUS)` instead of the muzzle; the tracer and flash still start at the muzzle; no head (character gone during a melee delay) sends nothing. First person unchanged. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Blaster.Constants` (ModuleScript) | 5,320 / 2026350663 | 5,533 / 2818109534 | `CROSSHAIR_RAY_RADIUS = 0.05`. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.ThirdPersonAim_Test` (ModuleScript) | new | 1,928 / 4149179032 | 4 cases (origin at the head aimed at the hit; the crosshair ray starts level with the head; no hit aims at full range; a hit level with the head keeps the camera's direction). Attribute set. |

Studio objects: the five held muzzles applied from the Task 3 table (Orientation (0, -90, 0), `FlashEmitter` from a same-class Tool): APS (3.512, 0, 0) -> (-3.51, 0.27, 0) (Glock 17); AR-18 (3.197, 0, 0) -> (-3.43, 0.23, 0) (AK47); HK G3 (3.519, 0, 0) -> (-3.52, 0.13, 0) (AK47); M14 EBR (3.554, 0, 0) -> (-3.55, 0.20, 0.08) (AK47); Itacha Mag-10 (4.389, 0, 0) -> (-4.42, 0.58, 0.08) (Mossberg 590). `validateShot` unchanged (`POSITION_BUFFER_CONSTANT` 5).

The 4 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (4 / 4). City suites 277 / 277 / 0 (273 + 4); heist 732 passed / 1 failed (only `Zone` "the real occupancy sweep", 4.06 ms, the known flake). After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 4 (UI, shop, quests, saves and the test runner, `Batch: open items UI quests and saves`). Same columns; old = the place before this task (each equal to its `CityScripts/` copy at eab14de where one existed; `SkinsCardController`, `RunUnitTest` and `Stats.Constants`: first export).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.DeathScreen` (LocalScript) | 8,006 / 4022051210 | 8,186 / 3794329941 | Developer decision 7: `DeathScreenGui` is `ZIndexBehavior.Sibling` (one line after `Instance.new`), after the template's `TextContainer` ZIndex 5 -> 2 (below). Global and Sibling lists now equal (0 swapped pairs; 3 before). Attribute set. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.SkinsCardController` (ModuleScript) | 30,950 / 681185616 | 32,372 / 2935679564 | Developer decision 10: the locked chip's first click (preview, already there) now reads "Buy for N?" (icon hidden while asked: icon + text would be 85.5 px on an 84 px chip); a second click within `BUY_CONFIRM_SECONDS` buys; the timeout, a press anywhere else (another chip included), BACK, close or re-target cancel (`disarm`, `confirmToken`, one `InputBegan` connection only while an offer is up). Server unchanged. Attribute set. First export. |
| 2026-11-18 | `ReplicatedStorage.Spraypaint.Constants` (ModuleScript) | 2,338 / 1366304406 | 2,523 / 954033153 | `BUY_CONFIRM_SECONDS = 4`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Quests.Scripts.QuestService` (Script) | 8,992 / 2852790903 | 9,734 / 1723410977 | Turn-in records the claim (completions, state, publish, save) before it pays cash and XP. A refused accept (`too_far`, `low_level`) or turn-in (`too_far`, `not_ready`) is answered on the same remote with `FireClient(player, questId, reason)`. `hydrate` writes `QuestConfig.restore`'s result back to `profile.Data.quests` / `questCompletions` (dropped ids, bad states and clamped progress leave the save; replaces the non-table reset), then restores the session state from the cleaned save. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Quests.QuestConfig` (ModuleScript) | 6,900 / 1331490080 | 7,232 / 3254934921 | `REFUSALS` texts ("Too far away.", "Not ready yet.", "Your level is too low."). Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.QuestFeedbackController` (LocalScript) | 3,847 / 965953225 | 4,416 / 3941142809 | Listens on `AcceptQuestRequest` / `TurnInQuestRequest` `OnClientEvent` and shows the `REFUSALS` text as a `NotificationController` toast titled "QUEST". Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` (ModuleScript) | 19,148 / 3943199417 | 23,699 / 2943384353 | Quest case retitled to what it tests; 3 cases: the quest hydrator wins over pre-restore quest attributes; restoring prunes the saved quest tables (RED first); a Police kill (the real Play player, a throwaway mock profile bound for the kill) is counted, saved, reloaded and hydrated. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.RunUnitTest` (ModuleScript) | 3,992 / 2205425575 | 4,581 / 2561729712 | A filter starting with "=" matches the whole case name; any other filter is the old plain substring. `matches` exposed; the module is a callable table, so `require(RunUnitTest)(filter)` and `pcall(require(RunUnitTest))` work unchanged. Attribute set. First export. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.RunnerFilter_Test` (ModuleScript) | new | 991 / 174873121 | 2 cases for the filter (RED first). Attribute set. |
| 2026-11-18 | `ServerScriptService.Weapons.Scripts.LevelingService` (Script) | 11,110 / 284623911 | 11,188 / 3134004765 | Header comment: level and XP are saved through ProfileGateway (was "Session-only"). Comment only. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Stats.Constants` (ModuleScript) | 1,339 / 2930036738 | 1,304 / 3065299232 | Comment: the kill counters are saved in the profile (was "Session-only ... reset on rejoin by design"). Comment only. Attribute set. First export. |

Studio objects (not scripts): `ReplicatedStorage.GuiTemplates.DeathScreen.TextContainer` (CanvasGroup, `BackgroundTransparency` 1, no stroke) `ZIndex` 5 -> 2, attribute `CityMergeDeviation`. Not changed: `ProfileGateway`'s `KICK_MESSAGE` already ends "... nothing has been changed. Please rejoin in a moment." (one constant, both `Kick` calls); `PromptUiController` (a streamed-in prompt is restyled, measured).

The 11 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (11 / 11). City suites 282 / 282 / 0 (277 + 5); heist 732 passed / 1 failed (only `Zone` "the real occupancy sweep", 3.39 ms, the known flake). After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 3 fix round 2 (rate slack and third-person aim, controller ruling, `Batch: open items rate slack and aim`). Same columns; old = the place after Task 3 fix round 1 (eab14de).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ReplicatedStorage.Blaster.Constants` (ModuleScript) | 5,533 / 2818109534 | 6,318 / 3954372288 | `INTERVAL_TOLERANCE = 0.9` and `ARRIVAL_SLACK = 0.25` (moved from `validateFireInterval`; slack 0.1 -> 0.25, ruling: phones first, a ~250 ms stall costs no honest shot), `CROSSHAIR_FAR_DISTANCE = 1000`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Blaster.Scripts.Blaster.validateFireInterval` (ModuleScript) | 2,227 / 605611656 | 2,077 / 2923609653 | Reads both numbers from `Blaster.Constants`; the rule is unchanged. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.ShotRate_Test` (ModuleScript) | 4,316 / 3822350991 | 5,496 / 1038411814 | Idle burst re-pinned (3 of 12 at 600 rpm, 6 at the MP9; 12 without the arrival clock); a 250 ms stall loses 0 shots; a 600 ms stall costs 4. 11 -> 13 cases. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Blaster.Utility.thirdPersonAim` (ModuleScript) | 1,194 / 1089443442 | 1,703 / 2954774249 | No hit within range (or no range): aim at `CROSSHAIR_FAR_DISTANCE` along the camera look (a melee miss was 25.9 degrees off); no range casts nothing; the camera's up is the roll hint. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.ThirdPersonAim_Test` (ModuleScript) | 1,928 / 4149179032 | 3,577 / 1137805472 | 4 cases: camera ahead of the head, range 0 / nil, straight-up look, melee miss within 1 degree of the camera look. 4 -> 8 cases. Attribute appended. |

The 5 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (5 / 5). City suites 288 / 288 / 0 (282 + 6); heist 732 passed / 1 failed (only `Zone` "the real occupancy sweep", 3.45 ms, the known flake). After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 4 fix round 1 (controller ruling on the chip preview, and a player-text sweep for the no-dash rule, `Batch: open items chip preview and text sweep`). Same columns; old = the place before this round (`SkinsCardController`: its Task 4 row; the other five: their `CityScripts/` copies at 0f34b88, shown equal by undoing this round's edits on the new export).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.SkinsCardController` (ModuleScript) | 32,372 / 2935679564 | 32,967 / 3206786732 | Controller ruling: the timeout and a press elsewhere end only the "Buy for N?" question (`armedPalette`, `arm`, `disarm` repaints the label); the 3D preview stays and ends only as before (another chip, BACK, close, re-target, equip landing). A click on the previewed chip after its question ended asks again instead of buying; the buy click disarms (one fire per question). Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.QuestDialogueController` (LocalScript) | 9,176 / 4006366522 | 9,174 / 4177808622 | "Clean work -- {n} {enemies} gone." -> "Clean work. {n} {enemies} gone." Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Services.LocationServer` (ModuleScript) | 20,877 / 1915285561 | 20,872 / 1291709925 | `cap_exceeded` "Duffel Full — get clear ..." -> "Duffel Full. Get clear ..."; cooldown toast "%s sealed -- %d:%02d remaining." -> "%s sealed. %d:%02d remaining." Attribute appended. |
| 2026-11-18 | `ServerScriptService.HeistServer` (Script) | 53,166 / 1059659372 | 53,153 / 2289833884 | `vault_not_breached`, `already_breached`, `cap_exceeded`, the heartbeat Duffel Full toast and "Vault sealed — %d:%02d remaining." without dash punctuation. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.LocationServerSpec` (ModuleScript) | 25,709 / 2880402448 | 25,707 / 1588753348 | The exact sealed-refusal wording follows the new text (RED before the source change: 732 / 1 on this case). Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.AdminLevelController` (LocalScript) | 7,491 / 3139161519 | 7,490 / 3458649500 | Admin panel title "Admin - Set Level" -> "Admin: Set Level". Attribute appended. |

Studio objects (not scripts): `StarterGUI.DuffelUpgradeGui.DialogFrame.DialogText.Text` "Carry more cash in a single run. Highest tier applies -- these do not stack." -> "... Highest tier applies. These do not stack." (attribute `CityMergeDeviation`). Kept (not punctuation, or the allowed name/tag pattern): the six quest nameplates "OFC. DOYLE - LV 1" ... "CHIEF HARLAN - LV 70", `AdminLevelController` "Level -" (empty value) and "1 - {LEVEL_CAP}" (a range), the shop's "\u{2014}" no-price placeholder; developer-only `warn` / test-runner strings.

The 6 sources exported to `CityScripts/`; on-disk Adler-32 equals the place (6 / 6). City suites 288 / 288 / 0; heist 733 passed / 0 failed. After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 5 (heist test gaps and robbery leftovers, `Batch: open items heist tests and robbery leftovers`). Same columns; old = the place at 668e659 ("new" for new scripts).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ServerScriptService.Heist.Components.Zone` (ModuleScript) | 2,264 / 181732240 | 2,666 / 1921814475 | `deps.overlap` (default `workspace:GetPartsInPart`) so ZoneSpec counts the parts the real sweep walks; the Include filter is unchanged. Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.ZoneSpec` (ModuleScript) | 12,057 / 634819463 | 12,616 / 3747238027 | "the real occupancy sweep" asserts 0 parts walked and 1 call through the seam (was a 3 ms wall-clock limit that failed at 3.05 to 10.19 ms). Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.VaultDoorSpec` (ModuleScript) | 13,881 / 1293824993 | 14,434 / 2035872095 | Cases unparent their fixture instead of destroying it: the 4 s door tween outlives the fake-clock sequence and warned "no PrimaryPart" every frame on a destroyed model (1,680 warnings per RunAll, now 0). Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.CarryGetawaySpec` (ModuleScript) | 4,621 / 1058397731 | 5,064 / 653552930 | Each case destroys its own anchors and characters (`cleanup()`). Attribute appended. |
| 2026-11-18 | `ServerScriptService.PlayerData.CurrencyService` (ModuleScript) | 2,062 / 3995652172 | 2,418 / 383011360 | `Add` refuses amounts above `HeistShared.Config.MaxCashCredit` (1e300 credited 9,223,372,036,854,776,000 before). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.HeistShared.Config` (ModuleScript) | 15,577 / 273243205 | 15,903 / 4102867017 | `MaxCashCredit = 1000000`. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.CurrencyBridge_Test` (ModuleScript) | 4,519 / 1400801589 | 5,801 / 2577280369 | `-math.huge`, `MaxCashCredit + 1`, `1e300` refused, exactly `MaxCashCredit` accepted, the default `_playerFor` (read only). Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.CashClaimVFX` (ModuleScript) | 11,096 / 4226909799 | 12,174 / 2978213759 | The passive listener waits up to 10 s for `leaderstats.Cash` in its own thread; the cash frame is looked up again once it leaves the PlayerGui. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.CashClaimVFXSpec` (ModuleScript) | 11,490 / 3531921895 | 13,365 / 1303330692 | 2 cases: Cash arriving after construction; a rebuilt cash frame. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Weapons.Scripts.CashService` (Script) | 10,845 / 4129585844 | 11,550 / 1501192552 | The Cash it creates at join carries `PreBindBase`; `hydrate` adds any change since to the saved balance (floor 0) and clears it. Attribute set. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` (ModuleScript) | 23,699 / 2943384353 | 25,365 / 461676520 | 2 cases through the real hydrator list: a pre-bind credit kept (1300, was 1000), no marker restores the saved balance. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.CarryState` (ModuleScript) | 6,851 / 3014874475 | 7,341 / 777583984 | `Forget(player, dropCFrame?)` drops a still-held carry as a death does (at the spot, or the object's start). Attribute appended. |
| 2026-11-18 | `ServerScriptService.SuppliesServer` (Script) | 8,169 / 1008868426 | 8,444 / 316963667 | `PlayerRemoving` passes the leaver's drop spot to `Forget`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.CarryStateSpec` (ModuleScript) | 11,542 / 3799212739 | 12,914 / 3073323821 | 2 cases: Forget drops at the spot, or at the start with no spot. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Services.Getaway` (ModuleScript) | 5,734 / 2317195041 | 5,875 / 3624455801 | Distance from `HeistShared.GetawayMath` (same formula). Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 66,908 / 3845503917 | 66,721 / 1138916754 | The getaway widget's distance from `HeistShared.GetawayMath.remaining`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.GetawaySpec` (ModuleScript) | 6,811 / 2190058934 | 8,035 / 636955752 | Server `DistanceRemaining` equals `GetawayMath.remaining` on 7 samples; HeistClient calls it. Attribute set. |
| 2026-11-18 | `ServerScriptService.SlowFoodsServer` (Script) | 15,841 / 1238792724 | 14,166 / 2703310953 | Key, Use Key and storage-safe wiring moved, unchanged, to `Heist.Services.SlowFoodsKey`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.NewsStationServer` (Script) | 22,509 / 2612295366 | 22,317 / 521420143 | Go-live heat, guard alert and payout moved, unchanged, to `Heist.Services.BroadcastHooks`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.Gas2GoRipSpec` (ModuleScript) | 9,617 / 2503303253 | 12,459 / 2042229020 | Two players racing a rip: one carry, banked once through a real CarryGetaway. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 2,949 / 1427489501 | 3,053 / 1910825537 | `SlowFoodsKeySpec`, `BroadcastHooksSpec`. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.HeistShared.GetawayMath` (ModuleScript) | new | 971 / 2194952250 | The getaway distance for server and client. Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Services.SlowFoodsKey` (ModuleScript) | new | 4,738 / 608721198 | SlowFoods' key layer wiring (from SlowFoodsServer). Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Services.BroadcastHooks` (ModuleScript) | new | 1,502 / 2078012852 | NewsStation's broadcast payoff (from NewsStationServer). Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.SlowFoodsKeySpec` (ModuleScript) | new | 12,351 / 1736436723 | 8 cases: key, Use Key, safe pay; Seal mid-chase, after the catch, after the escape; safe gates; death and leave. Attribute set. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.BroadcastHooksSpec` (ModuleScript) | new | 4,816 / 3044356405 | 2 cases: heat floor and guard alert at go-live; one payout each at the desk. Attribute set. |

Studio objects (not scripts): `Workspace.SlowFoods.Cashier` x3 and `Workspace.Bank."Bank Clerk"` x2 tagged `Invulnerable` and `Witness` like their templates (attribute `CityMergeDeviation`); the `StarterGui` service renamed from `StarterGUI` back to `StarterGui` (no script in the place names it `StarterGUI`; 473 scripts scanned).

The 26 sources exported to `CityScripts/`; on-disk bytes equal the place (26 / 26). City suites 295 / 295 / 0 (288 + 7); heist 749 passed / 0 failed (733 + 16), three runs in a row plus a final one, 0 "PrimaryPart" warnings. After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 6 (one gamepass system and one notification style, developer decision 13, `Batch: unify gamepasses and notifications`). Same columns; old = the place at cd6a4a2 ("new" for new scripts; `Monetization.Constants`, `NotificationController` and `WordScrambleClient`: first export).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `ReplicatedStorage.Monetization.Constants` (ModuleScript) | 3,773 / 1587927762 | 4,990 / 784951715 | The heist duffel passes `DuffelCapacityX2`, `DuffelCapacityX4`, `DuffelSpeedBoost` as pass entries (id 0, `shop = false`, no price); `Gamepass.shop`; `CONFIRM_ATTEMPTS` 3, `CONFIRM_RETRY_SECONDS` 2, `FAILED_CHECK_RETRY_SECONDS` 30. Attribute set. |
| 2026-11-18 | `ServerScriptService.Monetization.Scripts.PassOwnership` (ModuleScript) | new | 4,549 / 2906399671 | The one ownership path for every pass: `GamepassOwned_<key>` is the only record, id 0 never owned / asked / matched, a failed check asked again after 30 s, a reported purchase confirmed by `UserOwnsGamePassAsync` (3 tries, 2 s apart, off the event thread, stops when the player left). Attribute set. |
| 2026-11-18 | `ServerScriptService.Monetization.Scripts.MonetizationService` (Script) | 6,260 / 3620959142 | 5,542 / 4031478952 | Join publish and `PromptGamePassPurchaseFinished` through `PassOwnership` (was: event trusted, an id-0 event matched `DoubleCash`). Attribute set. |
| 2026-11-18 | `ReplicatedStorage.SharedSystems.GamepassManager` (ModuleScript) | 6,681 / 754457998 | 2,336 / 3798875103 | Thin adapter: multipliers by pass key, ownership read from the published attribute; no ids, no cache, no `Init`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Heist.Tests.GamepassManagerSpec` (ModuleScript) | 12,231 / 3341640635 | 4,868 / 1383897097 | 20 cases -> 11 (9 kept, 2 new); 9 moved to `PassOwnership_Test`, 2 removed (see the Task 6 report). Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.PassOwnership_Test` (ModuleScript) | new | 9,008 / 325438263 | 16 cases (9 moved from `GamepassManagerSpec`, 7 new). Attribute set. |
| 2026-11-18 | `ServerScriptService.HeistServer` (Script) | 53,153 / 2289833884 | 53,212 / 315566770 | `GamepassManager:Init()` call removed. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 66,721 / 1138916754 | 66,676 / 81948207 | Duffel upgrade prompts by key through `Monetization.Remotes.PromptGamepassPurchase`; upgrade dialog, safe keypad and lockpick register with `UI.Panels` (lockpick closer = its X path); closing the keypad releases its TextBox focus. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.GamepassShopController` (LocalScript) | 4,900 / 2847555 | 5,018 / 2322766475 | Skips `shop = false` passes (panel stays 7 tiles). Attribute set. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.NotificationClient` (LocalScript) | 8,183 / 3481984699 | 3,253 / 3674103393 | Heist cards through `Modules.NotificationController` (titles "ALARM TRIGGERED" / "NOTICE", texts unchanged); bounded 30 s remote waits. Attribute appended. |
| 2026-11-18 | `ReplicatedStorage.Modules.NotificationController` (ModuleScript) | 14,762 / 178485235 | 16,105 / 1201486866 | A wrapped message grows the card by its extra height (measured with RichText); the detail line moves down with it. Attribute set. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.UiButtonEffects` (LocalScript) | 9,933 / 3916961254 | 9,895 / 3536193229 | `HeistNotificationGui` references removed. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.WordScrambleClient` (LocalScript) | 16,275 / 1561117452 | 16,905 / 1480956601 | Word scramble and hack code register with `UI.Panels` (word scramble closer = its X path). Attribute set. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.LevelingHud` (LocalScript) | 12,131 / 4111193995 | 13,316 / 3006033539 | Popup scale follows the heist HUD's `UIScale`; placed again on a viewport resize while shown. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.WantedHud` (LocalScript) | 6,348 / 732449840 | 6,422 / 4281295562 | Header comment only (the heist cards no longer stack up the right edge). Attribute set. |

Studio objects (not scripts): `StarterGui.HeistNotificationGui` moved to `ServerStorage.CityQuarantine.ReplacedByUnifiedNotifications` (attributes `OriginalPath`, `OriginalParent`, `QuarantinedBy`; a ScreenGui has no CFrame).

The 15 sources exported to `CityScripts/`; on-disk bytes and Adler-32 equal the place (15 / 15). City suites 311 / 311 / 0 (295 + 16); heist 740 passed / 0 failed (749 - 20 + 11). After: 1 enabled SpawnLocation in Workspace, no `Tmp*` object, no Workspace attribute.

Studio restarted itself for an update at 19:52:50 (installer log); the place file was written at 19:52:49, partway through this task (after the gamepass scripts, `HeistClient`, `WordScrambleClient`, `UiButtonEffects` and `NotificationController`; before `NotificationClient`, the quarantine move, `LevelingHud`, `WantedHud` and the keypad focus line). Not saved by Claude.

NOT saved / NOT published

Task 6 fix round 1 (review I1, I2, M2, M5, `Batch: unify gamepasses and notifications fixes`). Same columns; old = the place at e8e9c64.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.WordScrambleClient` (LocalScript) | 16,905 / 1480956601 | 17,097 / 1132059424 | I1: `closeWordScrambleGui` and `exitWordScramble` moved above `openRound`; the closer handed to `UI.Panels` was a nil global (B over the scramble left both open, no exit sent). Attribute appended. |
| 2026-11-18 | `ServerScriptService.Monetization.Scripts.PassOwnership` (ModuleScript) | 4,549 / 2906399671 | 6,098 / 1225014576 | I2: a purchase event for an owned pass, or while a confirm for that pass runs, asks nothing; one pending failed-check retry per player and pass; `forget(player)`. Attribute appended. |
| 2026-11-18 | `ServerScriptService.Monetization.Scripts.MonetizationService` (Script) | 5,542 / 4031478952 | 5,648 / 3693060990 | `PlayerRemoving` -> `PassOwnership.forget`. Attribute appended. |
| 2026-11-18 | `ServerStorage.UnitTest.Cases.PassOwnership_Test` (ModuleScript) | 9,008 / 325438263 | 11,231 / 2042603761 | 4 cases: 10 replayed events for an owned pass (0 calls, was 10), 10 events while one confirm runs (3 calls, was 30), join + purchase failure (one retry chain: 5 calls, was 6), `forget` drops the in-flight flag. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.HeistClient` (LocalScript) | 66,676 / 81948207 | 66,782 / 3515715503 | M5: the duffel "+" calls `Panels.opened` only when the dialog is not already the open panel. Attribute appended. |
| 2026-11-18 | `StarterPlayer.StarterPlayerScripts.NotificationClient` (LocalScript) | 3,253 / 3674103393 | 3,576 / 4184920304 | M2: every `WaitForChild` bounded (30 s, warn and stop). Attribute appended. |

The 6 sources exported to `CityScripts/`; bytes and Adler-32 equal (6 / 6). City suites 315 / 315 / 0 (311 + 4); heist 740 passed / 0 failed. After: 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

## Admin, animation and third person 2026-11-20

Task 1, character animations (`Batch: character animations from the group clips`). Place: cloud place "Crimelife Tycoon" (placeId 128488619644399). Same columns; Adler-32 of `Source`.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.Movement` (LocalScript) | new | 23,344 / 953208571 | OBT's `Movement.lua` ported: the Player_ clips (idle, walk / jog / run in four directions, sprint, jump, fall, land, hard land, climb, swim, legs layer at Action4 under a held tool), roll (Q, ButtonB, a CAS touch button) and ledge climb (Space). Walker morphs, flying, avatar packs, emotes, OBT `SFX` / `UIShell` / `Gamepad` / `Locomotion` removed; `blocked()` reads CrimeLife state (dead, seated, PlatformStand, anchored, `IsRagdolled`, `AdminFrozen`, `IsCrouching`, any carry, an open `UI.Panels` panel). Steps aside while crouched. Roblox-default fallback for a clip that does not load. Ledge raycasts respect CanCollide (the night-light slabs over the roads); limbs kept out of collisions during the climb. Attribute set. |
| 2026-11-20 | `ReplicatedStorage.PlayerMovement.Config` (ModuleScript) | new | 3,255 / 3485602432 | OBT's config retuned: `BaseSpeed` Jog 12 / Run 20 / Sprint 38 (each CrimeLife gait at 1x), bands `JogToRun {13, 18}`, `RunToSprint {26, 34}`, `FallbackWait` 3, `Roll` Q / ButtonB / `Stamina` 12.3 (40 / 325 of 100) / touch spot, `Ledge` as OBT. Attribute set. |
| 2026-11-20 | `ReplicatedStorage.PlayerMovement.Fallback` (ModuleScript) | new | 862 / 3968798254 | Pure name -> Roblox default R15 clip map; legs copies, Land, LandHard, Roll, LedgeClimb have none. Attribute set. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.RollAuthority` (ModuleScript) | new | 2,147 / 1854402996 | Server re-check of a roll (alive, `Config.Roll.Cooldown` on the server clock, any carry, stun / ragdoll / anchored / `AdminFrozen`, stamina) and the spend through `SprintAuthority.spend`. Attribute set. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.SprintAuthority` (ModuleScript) | 11,627 / 4057754890 | 12,387 / 1677161428 | `spend(player, amount)`: takes stamina at once if there is that much, restarts the regen delay, locks sprint out at 0, publishes. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.RunningState` (Script) | 1,026 / 1164604505 | 1,506 / 1623531334 | `ReplicatedStorage.PlayerMovement.Roll` -> `RollAuthority.request(player, os.clock())` (no arguments read); `RollAuthority.cleanup` on leave. Attribute set. |
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.Animate2` (LocalScript) | 25,120 / 2723549544 | 25,806 / 3929996936 | Plays no locomotion clip while character attribute `MovementAnimations` is set (sitting stays); stops the destroyed `Animate`'s leftover tracks (its avatar idle kept playing at Core). WalkSpeed ramp, sprint input, landing recovery, sprint FOV and the child Animation ids (read by `locomotionAnimations`) unchanged. Attribute appended. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.Fallback_Test` (ModuleScript) | new | 1,746 / 4038074237 | 3 cases. Attribute set. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.RollAuthority_Test` (ModuleScript) | new | 3,494 / 3836190760 | 4 cases. Attribute set. |

Studio objects (not scripts): `ReplicatedStorage.PlayerMovement` (Folder) with `Animations` (42 Animation objects: the 41 group clips of OBT's handover table without Fly / FlyIdle, plus `Empty`) and the RemoteEvent `Roll`. `StarterPlayer.StarterCharacterScripts.LandAnim` (2,412 / 10044350, unchanged source) disabled and moved to `ServerStorage.CityQuarantine.AnimationsReplaced` (attributes `OriginalPath`, `OriginalParent`, `QuarantinedBy`); Movement's Land / LandHard replace it.

The 9 sources are in `CityScripts/`; bytes and Adler-32 equal the place (9 / 9). The transfer server could not be used (the Studio MCP blocks HTTP to 127.0.0.1 now): each source was written on disk first and pushed into the place, then both sides were hashed. City suites 322 / 322 / 0 (315 + 7); heist 740 passed / 0 failed. After: 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute.

Task 1 review fixes (Sonnet review, 2026-11-20; committed with Task 2).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.Movement` (LocalScript) | 23,344 / 953208571 | 24,542 / 2135516419 | I1: the `CharacterAdded` connection is kept and disconnected in `stop()`. I2: no per-frame tables, closures or name building in the Heartbeat step (cleared `target` / `rate`, a reused direction table, names built once, `syncTo` helper), the tool flag kept by `ChildAdded` / `ChildRemoved`, `AdjustWeight` / `AdjustSpeed` only when the value moves. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.RollAuthority` (ModuleScript) | 2,147 / 1854402996 | 2,348 / 2494576150 | Also refused while crouched, seated or PlatformStand; a request from a Player that has left is refused (no state recreated). Attribute appended. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.SprintAuthority` (ModuleScript) | 12,387 / 1677161428 | 12,414 / 3488120329 | `spend` refuses while sprint is locked out. Attribute appended. |

Task 2, third person over the shoulder (`Batch: shoulder camera third person`), done by the controller.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ReplicatedStorage.Blaster.Scripts.ShoulderCamera` (ModuleScript) | new | 13,115 / 3035454427 | OBT's `GunEngine.Camera` ported: shoulder offset and zoom through CameraAuthority "Shoulder", wall clamp, Z / R3 swap, aim offset, facing (yields to MoveAction), waist / neck pitch reported on `Remotes.AimPitch`, the session's view choice (third by default). No scope, bob or shake (no scoped gun; Bobbing Camera and CameraRecoiler own those). Attribute set. |
| 2026-11-20 | `ReplicatedStorage.Blaster.Utility.shoulderMath` (ModuleScript) | new | 1,637 / 1403335509 | Pure: `clampSide`, `pitchOf`, `acceptPitch`, `due`, `smooth`. Attribute set. |
| 2026-11-20 | `ServerScriptService.Blaster.Scripts.AimPitch` (Script) | new | 1,483 / 2971664214 | Server: a finite pitch, clamped to 70 degrees, at most one per 0.08 s (0 always), into character attribute `AimPitch`. Attribute set. |
| 2026-11-20 | `StarterPlayer.StarterPlayerScripts.AimPitchView` (LocalScript) | new | 2,177 / 2707282781 | Other players' waist / neck eased to their `AimPitch`; idle with nobody tilted. Attribute set. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.ShoulderMath_Test` (ModuleScript) | new | 2,099 / 2390795616 | 5 cases. Attribute set. |
| 2026-11-20 | `ReplicatedStorage.Blaster.Scripts.ViewModelController` (ModuleScript) | 18,904 / 85491774 | 18,800 / 132407314 | Third person = the shoulder camera (the fixed `THIRD_PERSON_OFFSET` camera rewrite and its root turn removed); a fresh equip uses the session's view (third by default), player attribute `ViewMode`; V remembers; aim passed on. First mirror of this script in `CityScripts/`. Attribute set. |
| 2026-11-20 | `ReplicatedStorage.Blaster.Scripts.BlasterController` (ModuleScript) | 19,563 / 1338451710 | 20,422 / 318981244 | DPadUp toggles the view, Z / R3 swap the shoulder (equipped controller only: every Tool's controller hears the key, two swaps cancelled out); the touch Reload button gets its callback (it never had one: a tap did nothing) and VIEW / SWAP theirs. Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.Blaster.Constants` (ModuleScript) | 6,318 / 3954372288 | 7,260 / 1144458660 | `GAMEPAD_TOGGLE_VIEW_KEY_CODE`, the swap keys, `SHOULDER_*`, `AIM_PITCH_*`. Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.Blaster.Scripts.TouchInputController` (ModuleScript) | 4,646 / 2740281819 | 5,739 / 2092945993 | `setViewCallbacks`, VIEW / SWAP wiring, SWAP shown only in third person. First mirror. Attribute set. |
| 2026-11-20 | `ReplicatedStorage.Modules.CameraAuthority` (ModuleScript) | 6,883 / 2682741682 | 7,407 / 551032463 | "Shoulder" source on top of CameraOffset (applied at once, not tweened) and Min / MaxZoomDistance; character-scoped. First mirror. Attribute set. |
| 2026-11-20 | `ReplicatedStorage.Modules.PropertyAuthority` (ModuleScript) | 2,513 / 4223693298 | 2,734 / 4256153360 | `Get(source)`; the applier also receives the winning source. First mirror. Attribute set. |
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.CustomShiftLock.SmoothShiftLock` (ModuleScript) | 6,249 / 1662119896 | 6,623 / 808938512 | Its camera offset and its root turn stand aside while `ShoulderCam` is set; the turn also while `MoveAction` (a roll, a ledge climb) runs. First mirror. Attribute set. |

Studio objects (not scripts): `ReplicatedStorage.Blaster.Remotes.AimPitch` (UnreliableRemoteEvent); `TouchInputController.BlasterTouchGui.Buttons.ViewButton` / `SwapButton` (ReloadButton style, 64 x 64, Montserrat Heavy labels), built by `CityMerge/builds/2026-11-20-shoulder-camera-instances.luau`.

The 16 sources are in `CityScripts/`; bytes and Adler-32 equal the place (16 / 16), written on disk and pushed (or patched by the same pairs on both sides) and hashed on both sides. City suites 327 / 327 / 0 (322 + 5); heist 740 passed / 0 failed; boot: server 1 DataStore "StudioAccessToApisNotAllowed" error (API access off for the new cloud place) and the Assistant plugin warning, client 0. After: 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 3, admin server (`Batch: admin server`). Same columns; old = the place after Task 2 (each "old" equals its `CityScripts/` mirror at 63e51a8).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ServerScriptService.Admin.Config` (ModuleScript) | new | 2,047 / 186285216 | Admin numbers: group 4998611, ranks 255 / 252, cooldown 0.25 s, log 150 rows, ranges, ban lengths, heists, teleport places. Attribute set. |
| 2026-11-20 | `ServerScriptService.Admin.Roles` (ModuleScript) | new | 3,191 / 2652185648 | Pure `roleOf` (Studio, a user place's creator, rank in the creator group and in SolarArc Studios; a lookup error gives no role); live cache per player, `AdminRole` attribute, `onChanged`, `set` (the role seam), retries, cleared on leave. No UserId literal. Attribute set. |
| 2026-11-20 | `ServerScriptService.Admin.Hooks` (ModuleScript) | new | 652 / 1610734242 | Server-only seam table the owning Scripts register into (`setLevel`, `giveWeapon`, `heists`). Attribute set. |
| 2026-11-20 | `ServerScriptService.Admin.Actions` (ModuleScript) | new | 30,386 / 1856953293 | The 31 actions (role, validate, run) and the dispatcher (role, action role, target rules, validation, 0.25 s cooldown, pcall, log of 150); invisible / god / spectate states; `liveContext` (filtering, ban, stats). Attribute set. |
| 2026-11-20 | `ServerScriptService.Admin.AdminService` (Script) | new | 1,845 / 3802433516 | Creates `ReplicatedStorage.AdminRemote` (RemoteFunction) and `AdminAnnounce` (RemoteEvent) at run time, loads roles on join, clears a character's admin states on death. Attribute set. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.AdminRoles_Test` (ModuleScript) | new | 3,060 / 3037126759 | 9 cases. Attribute set. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.Admin_Test` (ModuleScript) | new | 12,056 / 4260826386 | 16 cases (dispatcher order, validation, cooldown, log cap, BankInstance reset). Attribute set. |
| 2026-11-20 | `ServerScriptService.Weapons.Scripts.LevelingService` (Script) | 11,188 / 3134004765 | 11,512 / 36343760 | `setLevel` extracted from the `SetLevelRequest` closure and registered in `Admin.Hooks`; `SetLevelRequest` gated by `Admin.Roles` (owner); the hard-coded account id removed. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Weapons.Scripts.WeaponShopService` (Script) | 19,054 / 1661690566 | 20,374 / 1589322929 | `giveFree`: the buy tail without the charge plus the first free slot (grant, publish, mirror), registered as `Admin.Hooks.giveWeapon`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.BankInstance` (ModuleScript) | 12,888 / 683301957 | 13,346 / 3803117644 | `ResetCooldown()`: Cooldown only, end time = now, `Step()` (the normal rearm). Attribute appended. |
| 2026-11-20 | `ServerScriptService.HeistServer` (Script) | 53,212 / 315566770 | 53,601 / 1635167165 | Bank instance registered in `Admin.Hooks.heists`; the death pit spares an `AdminGod` character. Attribute appended. |
| 2026-11-20 | `ServerScriptService.SlowFoodsServer` (Script) | 14,166 / 2703310953 | 14,259 / 3174915992 | Bank instance registered in `Admin.Hooks.heists`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Gas2GoServer` (Script) | 14,921 / 1747985791 | 15,011 / 3117630225 | Same. Attribute appended. |
| 2026-11-20 | `ServerScriptService.NewsStationServer` (Script) | 22,317 / 521420143 | 22,412 / 352017789 | Same. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Wanted.WantedService` (ModuleScript) | 14,984 / 583930857 | 15,312 / 2822734272 | `setStars(player, n)` = `clear` then `addHeat`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Wanted.PoliceDispatcher` (ModuleScript) | 22,319 / 1938311026 | 22,848 / 2805465261 | `spawnOfficer` takes no owner (no squad) and returns the character; `spawnLoose(template, position)`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.SprintAuthority` (ModuleScript) | 12,414 / 3488120329 | 12,831 / 1042876665 | A character's `AdminWalkSpeed` is written last in the tick, after every clamp. Attribute appended. |
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.Animate2` (LocalScript) | 25,806 / 3929996936 | 26,059 / 2124763850 | `AdminWalkSpeed` on the character is the only speed target while set. Attribute appended. |
| 2026-11-20 | `StarterPlayer.StarterPlayerScripts.PlayerNameplates` (LocalScript) | 9,826 / 2121005472 | 10,497 / 4060274529 | No plate and no View Card prompt while the character is `AdminInvisible`. First mirror. Attribute set. |
| 2026-11-20 | `StarterPlayer.StarterPlayerScripts.NotificationClient` (LocalScript) | 3,576 / 4184920304 | 4,070 / 843413527 | `AdminAnnounce` listener: the filtered text as an "ADMIN" card through `NotificationController.show`. Attribute appended. |

The 20 sources are in `CityScripts/`; bytes and Adler-32 equal the place (20 / 20). City suites 352 / 352 / 0 (327 + 25); heist 740 passed / 0 failed; boot: server 1 DataStore "StudioAccessToApisNotAllowed" error (API access off) and the Assistant plugin warning. After: 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute.

NOT saved / NOT published

Task 4, admin panel (`Batch: admin panel`). Same columns; old = the place after Task 3 (686cb0f).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ServerStorage.AdminPanel.AdminPanelGui.AdminPanelController` (LocalScript) | new | 25,366 / 378580945 | The panel client: F2 and the HUD button, four tabs, every control through `AdminRemote` (one call at a time, 0.3 s apart), status line and `Sounds.denied()`, helper controls hidden by their `Action` attribute, kick / ban on a second click, stats every 2 s only while the Server tab shows; `UI.Panels`, `MenuFovBlur`, `Effects.bindClose`; fit `UIScale` (max 1); fly (`LinearVelocity` + `AlignOrientation`, Space up, LeftControl down at ContextActionService High with Sink so shift lock does not toggle, touch UP / DOWN), noclip, spectate. Attribute set. |
| 2026-11-20 | `ServerStorage.AdminPanel.AdminPanelGui.Config` (ModuleScript) | new | 1,009 / 835663730 | Client numbers (F2, 760 x 480, call spacing 0.3, confirm 3 s, stats 2 s, fly 60, steppers). Attribute set. |
| 2026-11-20 | `ServerScriptService.Admin.AdminService` (Script) | 1,845 / 3802433516 | 2,886 / 335864505 | Clones `ServerStorage.AdminPanel`'s `AdminHudGui` and `AdminPanelGui` into a role holder's PlayerGui on role gain (join included) with `HelperActions` / `EnemyTypes` attributes, removes them on role loss. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Admin.Actions` (ModuleScript) | 30,386 / 1856953293 | 30,993 / 24881071 | `helperActions()`, `enemyTypes()` for the delivered panel. Attribute appended. |
| 2026-11-20 | `ServerStorage.CityQuarantine.AdminReplaced.AdminLevelController` (LocalScript, was `StarterPlayer.StarterPlayerScripts.AdminLevelController`) | 7,490 / 3458649500 | 7,570 / 1308879009 | Retired: disabled, moved to `CityQuarantine.AdminReplaced` (`OriginalPath`, `OriginalParent`, `QuarantinedBy`), its account id replaced by `0` with a one-line comment. Mirror renamed. Attribute appended. |

Studio objects (not scripts): `ServerStorage.AdminPanel` with `AdminPanelGui` (ScreenGui, Sibling, ResetOnSpawn false, DisplayOrder 25, CoreUISafeInsets, `FitScale`, the 760 x 480 `Panel`, `Templates`) and `AdminHudGui` (the 76 x 76 ADMIN button at the Custom Inventory column's next slot, -459, and the touch fly UP / DOWN), built by `CityMerge/builds/2026-11-20-admin-panel-gui.luau` (re-runnable; keeps the scripts inside).

The 5 sources are in `CityScripts/`; bytes and Adler-32 equal the place (5 / 5). City suites 352 / 352 / 0; heist 740 passed / 0 failed; boot: server 1 DataStore "StudioAccessToApisNotAllowed" error and the Assistant plugin warning, client 0. After: 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute, no script holding the old account id.

NOT saved / NOT published

Task 2 review fixes (Sonnet review I1 to I4, 2026-11-20 night), done by the controller. Same columns; old = the place after Task 4 (each "old" equals its `CityScripts/` mirror at 2e128f0).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ReplicatedStorage.Blaster.Scripts.ShoulderCamera` (ModuleScript) | 13,115 / 3035454427 | 13,887 / 2176473364 | I1: module `wantAiming` kept across exit / enter (V, a panel, a seat) so a held aim comes back with its offset. I4: `exit()` turns `AutoRotate` back on only with no `MoveAction`; mid-roll it waits for the move to end (and skips it if the shoulder view is back). Attribute appended. |
| 2026-11-20 | `ServerScriptService.Blaster.Scripts.AimPitch` (Script) | 1,483 / 2971664214 | 1,529 / 1123421684 | I2: header names the reliable RemoteEvent. Attribute appended. |
| 2026-11-20 | `StarterPlayer.StarterPlayerScripts.AimPitchView` (LocalScript) | 2,177 / 2707282781 | 2,468 / 2866494009 | I3 (StreamingEnabled): no per-character connection; each other player's current character read at 10 Hz, joints found when first needed and again if they went away. Attribute appended. |
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.CustomShiftLock.SmoothShiftLock` (ModuleScript) | 6,623 / 808938512 | 6,703 / 4002907870 | I4: the `ShoulderCam` / `MoveAction` early return moved above its `AutoRotate` write, so the shoulder camera (or a move) is the only writer. Attribute appended. |

Studio object: `ReplicatedStorage.Blaster.Remotes.AimPitch` is now a `RemoteEvent` (I2: the closing 0 must arrive); the build script makes it so.

The 4 sources are in `CityScripts/`; bytes and Adler-32 equal the place (4 / 4, checked before the write). Play: Crowbar equips into the shoulder view and two swings took a dummy 100 -> 10; RMB held through V, V: offset back at (1.10, 1.30), FOV 50, released (1.75, 1.40) / 70; strafe 2.5 s: facing within 0.1 deg of the camera, `AutoRotate` never on; V 0.2 s into a roll: `AutoRotate` stays off until the roll ends, then on; Sit and PlatformStand release the view and it returns; `LoadCharacter` mid-shoulder: clean (no tool, offset 0, zoom 0.5..128) and the shoulder view on re-equip; server `AimPitch` -0.26 then 0 after V; touch VIEW / SWAP read back at 1100 x 679 with no overlaps (VIEW 16.8 px clear of Shoot, 30 px of Reload, labels fit). Not exercised: a real NPC dialogue mid-shoulder. City suites 352 / 352 / 0; heist 740 passed / 0 failed.

NOT published

Admin review fixes (Sonnet correctness review and security review of Tasks 3 + 4, 2026-11-20 night), done by the controller. Same columns; old = the place after Task 4 (2e128f0).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ServerScriptService.Admin.Actions` (ModuleScript) | 30,993 / 24881071 | 32,146 / 3929024880 | `text()` refuses more than 4 x max bytes before the trim pattern (security I1: quadratic backtracking on a long run of spaces could stall the server); kick / ban reasons fall back to the fixed text if the filter fails (security M5); a helper announces at most once per `ANNOUNCE_GAP` (security M6; owners not held); a helper target action on a player whose role is still loading is refused with "still loading" (security M2, review M3); `liveContext.roleLoaded`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Admin.Config` (ModuleScript) | 2,047 / 186285216 | 2,141 / 3923287093 | `ANNOUNCE_GAP = 5`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Admin.Roles` (ModuleScript) | 3,191 / 2652185648 | 3,340 / 2672056734 | No `AdminRole` attribute on the Player any more (security I2: it replicated and named the staff to every client); `Roles.loaded(player)`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Admin.AdminService` (Script) | 2,886 / 335864505 | 3,819 / 2179144165 | `AdminRole` rides on the delivered GUIs; a role lost or lowered first clears the character's owner states (review I1), a lost role also ends spectate, and the GUIs are removed 1 s after `AdminRole` goes (the client sees it and stops its tools first); `CharacterAdded` ends the old body's spectate (review I2); `CharacterRemoving` clears a body removed alive (god guard and invisible connection, security M1). Attribute appended. |
| 2026-11-20 | `ServerStorage.AdminPanel.AdminPanelGui.AdminPanelController` (LocalScript) | 25,366 / 378580945 | 26,146 / 208516053 | Role read from its own GUI; on role loss fly, noclip and spectate stop (review I1); a spectate the client cannot start tells the server to stop (review I2); Space typed into a TextBox no longer lifts a flying admin (review M1); arming a second kick / ban button restores the first one's label (review M2); character attribute changes re-sync only for `Admin*` names (review M4). Attribute appended. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.Admin_Test` (ModuleScript) | 12,056 / 4260826386 | 12,925 / 508372867 | New case: the byte bound refuses padded text before the trim, a helper's second announcement inside the gap is refused, a helper target action on a still-loading player is refused and an owner's is not. Attribute appended. |

The 6 sources are in `CityScripts/`; bytes and Adler-32 equal the place (6 / 6). Play: the Player has no `AdminRole`, both GUIs carry it; role removed through the `Roles.set` seam with fly, noclip and the panel open: server `Admin*` attributes cleared, both GUIs gone, PlatformStand false, no movers, root collides again, MenuBlur 0, FOV 70; role back: both GUIs again (`AdminRole` owner). Owner with god demoted to helper: `AdminGod` and its ForceField gone, panel kept with role helper. City suites 353 / 353 / 0 (352 + 1); heist 740 passed / 0 failed; client 0 errors; server: the known DataStore Studio-access error. Not fixed (vault Open Items): refusal rows share the 150-row log (security M4), rank lookups stop after 4 failures and roles are not refreshed mid-session (security M3, review M7), `SetLevelRequest` kept (owner-only now), staff states other than the role still show as character attributes while on, admin loose police count against `POLICE_CAP`, no gamepad fly up / down, invisible restores saved values. An empty stray file `CityScripts/ StarterPlayer.StarterPlayerScripts.AdminLevelController .luau` (untracked, no Studio twin) was deleted.

NOT published

## Heist police 2026-11-20

Batch 2 of the night (brief `.superpowers/sdd/2026-11-20-heist-police/brief.md`, developer decisions 1 to 3 plus the controller's squad hold). Old = the place at 182f552 (each "old" equalled its `CityScripts/` mirror, checked before the first write).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ServerScriptService.Heist.Services.HeistPolice` (ModuleScript) | new | 9,065 / 2622222331 | Police sent into the building while robbers are inside: a bank component (OnSessionStart / Seal / Rearm) with `Update()` on the location heartbeat, one tick a second. Waves from `Config.HeistPolice` (from the session's start) and the Bank's `Config.HeistPoliceVault` (from the vault door's opening, `OnVaultOpened`); a wave due with no robber inside is skipped; officers through `PoliceDispatcher.spawnLoose` with a filter (participants, wanted players inside), at the `HeistPoliceSpawn` markers; idle ones sent to the robber when a path from the first marker leads there; `room()` re-checked per officer; Seal removes them. `holdsSquad` registered with `PoliceDispatcher.addSquadHold` and `WantedService.addActiveRobbery`. Attribute set. |
| 2026-11-20 | `ServerScriptService.Heist.Tests.HeistPoliceSpec` (ModuleScript) | new | 10,900 / 1265614525 | 11 cases: Bank, vault and NewsStation schedules, caps and room, the component's waves, skip, Seal, vault start once, filter, steering, squad hold and its active-robbery side. Attribute set. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.HeistSquadHold_Test` (ModuleScript) | new | 2,833 / 1671478180 | The dispatcher's top-up holds a held player's squad and keeps its alarm ring for the first round after; a throwing hold holds nobody. Attribute set. |
| 2026-11-20 | `ServerScriptService.Heist.Components.GuardPost` (ModuleScript) | 12,455 / 2201465702 | 19,267 / 3904163936 | `templateFor` and a template spawn (EnemyRig build and place, `Witness`, `WitnessRole = "Guard"`, root anchored, idle and weapon hold clips, ragdoll on death); an always-posted guard is counted again (or replaced if dead) at a session start; `Provoke` through one Blaster `Tagged` listener (target for `GuardProvokeSeconds`, also outside a session); the guard faces its target when it fires; an anchored guard skips cover. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Wanted.PoliceDispatcher` (ModuleScript) | 22,848 / 2805465261 | 24,838 / 1578145209 | `spawnLoose(template, position, targetFilter?)` returns the character and its EnemyAI; `room()`; `addSquadHold` / `isHeld`; a held player asks for 0 officers in the top-up and keeps its alarm ring; seams `_players`, `_topUp`, `_alarmAnchor`. Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.Wanted.Constants` (ModuleScript) | 3,575 / 2502907630 | 3,934 / 1396754736 | `HEIST_POLICE_TICK = 1`, `HEIST_POLICE_SCATTER = 1.5`. Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.HeistShared.Config` (ModuleScript) | 15,903 / 4102867017 | 17,128 / 4046351343 | Bank guards `GuardsAlwaysPosted`, `GuardTemplates { "Security", "Police" }`, `GuardSpawnLift 3.2`, `GuardRespawnSeconds 60`, `GuardProvokeSeconds 30`; `HeistPolice` (Police, 120 s, 3, +2 every 90 s, cap 8) and `HeistPoliceVault` (Armed Police, 0 s, 4, +2 every 60 s, cap 8). Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.NewsStationShared.Config` (ModuleScript) | 6,179 / 2656520198 | 6,649 / 710205251 | `GuardProvokeSeconds 30`, `HeistPolice` (Police, 120 s, 2, +1 every 90 s, cap 4); the guard comment says the Bank's guards stand too. Attribute appended. |
| 2026-11-20 | `ServerScriptService.HeistServer` (Script) | 53,601 / 1635167165 | 54,713 / 2002791037 | Builds and registers the Bank's `HeistPolice` (boot assert on its markers); the heartbeat updates the guard posts and the heist police in every state; the vault-door latch calls `OnVaultOpened`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.NewsStationServer` (Script) | 22,412 / 352017789 | 23,008 / 1625959980 | Builds and registers NewsStation's `HeistPolice` (inside = the Newsroom zone); `heartbeatExtras` updates it. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.Tests.GuardSpec` (ModuleScript) | 14,334 / 2029584357 | 20,370 / 199740444 | The five session-only lifecycle cases run on a `sessionOnly` copy of the Bank config; 4 new cases (template choice, real template rigs, re-count / replace at the start, provocation). Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.Tests.RunAll` (ModuleScript) | 3,053 / 1910825537 | 3,116 / 338687384 | Lists `HeistPoliceSpec`. Attribute appended. |

Studio objects (not scripts): `Workspace.HeistMarkers.HeistPoliceSpawn1..3` at (1390, -115, 2265), (1384, -115, 2263.5), (1372, -115, 2264), round the corner from `TeleporterBankB`'s arrival (out of its sight); `Workspace.NewsStationMarkers.HeistPoliceSpawn1..3` at (-640, 5.3, 1000), (-645, 5.3, 1006), (-650, 5.3, 995) in the lobby by the entrance. Each is a 2 x 1 x 2 anchored Part, Transparency 1, CanCollide, CanQuery and CanTouch off, with a `HeistPoliceSpawn` note attribute. `Workspace.HeistMarkers.GuardPost4` moved from y -115.31 to -118.00 (the floor, like posts 1 to 3; its old guard floated 5.7 studs up), attribute `OriginalCFrame` keeps the old one.

The 12 sources are in `CityScripts/`; bytes and Adler-32 equal the place (12 / 12). City suites 355 / 355 / 0; heist 755 passed / 0 failed; boot: server the known DataStore "StudioAccessToApisNotAllowed" error and the Assistant plugin warning, client 0 errors. After: 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute. Measured Play numbers: `.superpowers/sdd/2026-11-20-heist-police/report.md`.

NOT saved / NOT published

Heist police review fixes (Sonnet review of ba555fe, 2026-11-20 night), done by the controller. Same columns; old = the place after ba555fe.

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ServerScriptService.Heist.Services.HeistPolice` (ModuleScript) | 9,065 / 2622222331 | 9,961 / 2268077868 | Review I1: the squad hold (and its active-robbery stars) covers participants and the players inside when the session started, not every wanted player who walks in during the first 2 minutes. Minor 1: a wave with no POLICE_CAP room waits for room instead of being used up. Minor 4: a session counter stops a wave still sending after a clear. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.Tests.HeistPoliceSpec` (ModuleScript) | 10,900 / 1265614525 | 11,515 / 2543879123 | Hold case: a wanted player who walks in after the start is not held; new case: a wave with no room waits. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.BankInstance` (ModuleScript) | 13,346 / 3803117644 | 13,672 / 2972281052 | Review minor 3: `NotifyGuardSpawned` / `NotifyGuardDied` count only while Active, so a guard respawned outside a session cannot fire `GuardsCleared` (GuardRoom gate) on its next death. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.Tests.BankInstanceSpec` (ModuleScript) | (unrecorded) / 2584225683 | 21,875 / 2925417210 | Asserts a guard respawning outside a session is not counted. Attribute appended. |

The 4 sources are in `CityScripts/`; bytes and Adler-32 equal the place (4 / 4, checked before the write). City suites 355 / 355 / 0; heist 756 passed / 0 failed (HeistPolice 12, BankInstance 37); server: only the known DataStore error. Play: walking into the Bank lobby with the Crowbar set off the alarm (3 stars, seen) and `PoliceDispatcher.isHeld` was true for that player (inside at the start). Left as is: review I2 (the vault Armed Police use the B-arrival markers and cannot path past the obby pit: a developer question), minor 2 (one steering path check a second while robbers are inside).

NOT published

## Combat balance 2026-11-20

Batch 3 of the night, "readable gunfights and the level curve" (brief `.superpowers/sdd/2026-11-20-combat-balance/brief.md`, developer decisions in `progress.md` there). Old = the place at 3327d15 (each "old" equalled its `CityScripts/` mirror, checked before the first write; `ReplicatedStorage.Leveling.Constants` had no mirror and its old values were read in the place).

| date | script | old len / Adler-32 | new len / Adler-32 | reason |
|---|---|---|---|---|
| 2026-11-20 | `ReplicatedStorage.Enemy.Combat` (ModuleScript) | new | 7,375 / 1606714197 | Every number of the NPC fire rhythm, NPC damage and the out-of-combat regen (tokens 2, wind-up 0.6 / 0.8 s, reacquire 1.5 s, aim line, focus x2.5 to x1 over 2 s, flinch 0.75 s / 0.3 s, bursts 3 to 5 with a 0.8 to 1.2 s pause, semi 0.45 s, falloff x1 at 25 to x0.5 at 90 studs, armor 0.4 % a level to 25 %, regen 6 % a second after 6 s) and the pure maths: `reactionTime`, `aimError`, `shotInterval`, `burstShots`, `burstPause`, `rangeFalloff`, `armor`, `npcDamage`, `regenStep`, `newTokens` (the token registry). Attribute set. |
| 2026-11-20 | `ServerScriptService.Enemy.Scripts.NpcFire` (ModuleScript) | new | 4,988 / 1700968954 | What every NPC shooter shares: the server's shooter-token registry (cleared on a player's death and leave), `showTell` (a plain red Beam from the muzzle to the target's root, removed at the first shot, 2 s safety), `isRolling` (RollingUntil), `errorDegrees` (AimConfig plus the focus ramp), `aimOrigin`, `muzzlePosition`. Attribute set. |
| 2026-11-20 | `StarterPlayer.StarterCharacterScripts.Health` (Script) | new | 1,211 / 4008615485 | Replaces Roblox's default Health script (1 % of MaxHealth a second, no delay): 6 % a second once 6 s have passed since the last loss, sleeping at full health. Attribute set. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.Combat_Test` (ModuleScript) | new | 4,601 / 446416611 | 9 cases: tokens (cap, hand-over, release, clear, timeout), wind-up, focus and roll, bursts and semi interval, falloff, armor and `npcDamage`, max health 100 / 104 / 376, regen step. Attribute set. |
| 2026-11-20 | `ServerScriptService.Enemy.Scripts.EnemyAI` (ModuleScript) | 42,838 / 3716075725 | 46,010 / 878240490 | Guns fire bursts only with a shooter token (`_gunTick`, `_startBurst`), a wind-up with the aim line per engagement, the focus ramp in `_applyAimError` (through NpcFire), a flinch on a player's hit (`_flinch`); `_noteSight` in Chase and Attack; a new target ends a running burst; `_startAutoFire` removed; melee keeps `_tryFire`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Blaster.Scripts.ShotResolver` (ModuleScript) | 37,699 / 3051881499 | 38,303 / 2940260377 | `applyDamage`: an NPC shooter's hit goes through `Combat.npcDamage` (range falloff, the victim player's level armor). Player shots unchanged. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Weapons.Scripts.LevelingService` (Script) | 11,512 / 36343760 | 11,488 / 2460912467 | `applyMaxHealth` uses `LevelingConstants.maxHealth(level)`; a comment's 238 becomes 376. Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.Leveling.Constants` (ModuleScript) | 2,760 / 3371009100 | 3,131 / 2888890898 | `MAX_HEALTH_PER_LEVEL` 2 -> 4, `BASE_MAX_HEALTH` 100, `maxHealth(level)`. New mirror. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Movement.Scripts.RollAuthority` (ModuleScript) | 2,348 / 2494576150 | 2,661 / 3109396587 | An accepted roll stamps `RollingUntil` (server clock, the longest roll 0.744 s) on the root: NPC aim gives a rolling target its widest cone. Attribute appended. |
| 2026-11-20 | `ServerStorage.UnitTest.Cases.RollAuthority_Test` (ModuleScript) | 3,494 / 3836190760 | 4,175 / 1739621350 | A case for the `RollingUntil` stamp (refused roll: none). Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.Components.GuardPost` (ModuleScript) | 19,267 / 3904163936 | 27,819 / 3524214988 | Guards shoot through ShotResolver from their weapon (tracer and sound for everyone, Shoot clip, Tagged, falloff, armor), aimed in the template's cone with the focus ramp; gun guards use shooter tokens, the wind-up aim line and bursts; a melee guard (Security, Baton) turns to its target and strikes only within its weapon's reach, never at a target staggered within `GuardFireInterval` of its last stun; flinch on a hit; the weapon deals `GuardDamage` and never runs dry. Deps `shoot`, `tokens`, `showTell` replace `damage`. Attribute appended. |
| 2026-11-20 | `ServerScriptService.Heist.Tests.GuardSpec` (ModuleScript) | 20,370 / 199740444 | 25,888 / 3682260325 | `damage` deps become `shoot`; the Alert and provocation cases step over the wind-up; 3 new cases (aim line, burst, token back and pause; waiting while two others fire; melee reach from a muzzle that has to turn, no strike at a staggered target). Attribute appended. |
| 2026-11-20 | `ServerScriptService.HeistServer` (Script) | 54,713 / 2002791037 | 54,540 / 3417567474 | The guards' `damage` closure removed (guards shoot through ShotResolver). Attribute appended. |
| 2026-11-20 | `ServerScriptService.NewsStationServer` (Script) | 23,008 / 1625959980 | 22,796 / 3500664420 | The guards' `damage` closure removed. Attribute appended. |
| 2026-11-20 | `ReplicatedStorage.NewsStationShared.Config` (ModuleScript) | 6,649 / 710205251 | 6,828 / 842734763 | `GuardTemplates { "Police" }`, `GuardSpawnLift` 0 -> 3.2: the three guards are Police rigs with a real Mateba (the grey GuardTemplate held no weapon, so its shots could not be seen). Attribute appended. |

Studio objects (not scripts): `ServerStorage.EnemyTemplates.Police` attribute `DamageOverride` 12 -> 9 and `ServerStorage.EnemyTemplates.Bandits` `DamageOverride` 3 -> 1.5 (per pellet), brief item 7, tuned after measuring items 1 to 6.

The 15 sources are in `CityScripts/`; bytes and Adler-32 equal the place (15 / 15). City suites 365 / 365 / 0; heist 759 passed / 0 failed; boot: server only the known DataStore "StudioAccessToApisNotAllowed" error. After: Edit mode, 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attribute. Measured Play numbers: `.superpowers/sdd/2026-11-20-combat-balance/report.md`.

NOT saved / NOT published

## Combat review fixes 2026-11-20

Review of 86a0073 (`.superpowers/sdd/2026-11-20-combat-balance/review.md`): 0 Critical, 2 Important, 6 Minor. Fixed: I2 and the guard-facing Minor. Guard pay outside a robbery (I1) is left as a question for the developer. The "guards behind walls" Minor was dismissed: `GuardPost.selectTarget` only takes `visible` candidates (a raycast in `_candidates`).

| Script | Before | After | Change |
|---|---|---|---|
| ReplicatedStorage.Enemy.Combat | 7,375 / 1606714197 | 7,513 / 880324628 | `FLINCH_COOLDOWN = 1` |
| ServerScriptService.Enemy.Scripts.EnemyAI | 46,010 / 878240490 | 46,253 / 4086379001 | `_flinch` at most once per `FLINCH_COOLDOWN` (`flinchedAt`, nil-safe for spec stand-ins) |
| ServerScriptService.Heist.Components.GuardPost | 27,819 / 3524214988 | 28,220 / 1048495103 | `Provoke` flinch at most once per cooldown (the provocation still renews); `_face` skips a turn within 2 degrees (`FACE_TOLERANCE`) |
| ServerScriptService.Heist.Tests.GuardSpec | 25,888 / 3682260325 | 27,070 / 3281672243 | case "a flinch delays the next shot at most once per FLINCH_COOLDOWN" |
| ServerStorage.UnitTest.Cases.Combat_Test | 4,601 / 446416611 | 5,344 / 1835643840 | case "an enemy flinches at most once per FLINCH_COOLDOWN" |

`CityMergeDeviation` appended on all 5. City 366 / 366 / 0; heist 760 passed / 0 failed (run from the Server command bar: from a temp Script, the two `Source` specs fail on capability).

NOT published

## Walking Bank guards and Edit rigs 2026-11-20

The developer's morning asks: Edit is the truth (Play spawns shown as rigs in Edit), guards that move, armed police upstairs, police after the obby pit, guards pay only during a robbery. Pickers: "Patrol, then cover", "Split each wave", "Only during a robbery", "Real rigs". Built natively (no subagents).

| Script | Before | After |
|---|---|---|
| ServerScriptService.Heist.EditRig | new | 859 / 2289180871 |
| ServerScriptService.Heist.Components.GuardPost | 28,220 / 1048495103 | 34,661 / 3389669030 |
| ServerScriptService.Heist.Services.HeistPolice | 9,961 / 2268077868 | 12,616 / 2808713664 |
| ReplicatedStorage.HeistShared.Config | 17,128 / 4046351343 | 17,527 / 330888722 |
| ServerScriptService.Enemy.Scripts.EnemyAI | 46,253 / 4086379001 | 46,308 / 3345696100 |
| ServerScriptService.HeistServer | 54,540 / 3417567474 | 55,079 / 3980569753 |
| ServerScriptService.Weapons.Scripts.CashService | 11,550 / 1501192552 | 11,722 / 2069142257 |
| ServerScriptService.Weapons.Scripts.LevelingService | 11,488 / 2460912467 | 11,656 / 305578906 |
| ServerScriptService.Quests.Scripts.QuestService | 9,734 / 1723410977 | 9,886 / 2053135860 |
| ServerScriptService.Spraypaint.Scripts.SpraypaintService | 14,858 / 524183879 | 15,010 / 758029594 |
| ServerScriptService.Heist.Tests.GuardSpec | 27,070 / 3281672243 | 29,699 / 4045192435 |
| ServerScriptService.Heist.Tests.HeistPoliceSpec | 11,515 / 2543879123 | 14,284 / 511578777 |

`CityMergeDeviation` appended on all 12 (the new module carries its own). World (one undo step "Bank Edit rigs and police spawns", plus "Move HeistPoliceInnerSpawn3 in front of the vault corridor"): new markers `HeistMarkers.HeistPoliceInnerSpawn1..3` ((1350, -94.5, 2548), (1382, -94.5, 2548), (1366, -94.5, 2551)) and `HeistPoliceUpperSpawn1..4` ((1255, 13.4, 2340), (1230, 13.3, 2340), (1240, 13.3, 2300), (1210, 13.4, 2320)), copies of `HeistPoliceSpawn1` (invisible, anchored, no collide / query / touch). 20 Edit rigs (clones of `ServerStorage.EnemyTemplates` Security / Police / Armed Police, root anchored, weapon in the right hand) as Model children of the Bank's 4 guard posts, NewsStation's 3 guard posts, the Bank's 10 police spawns and NewsStation's 3.

City 366 / 366 / 0; heist 764 passed / 0 failed. Edit after: no `Tmp*`, 1 enabled SpawnLocation, no Workspace attributes, no cover point claimed, 20 rigs on their markers.

NOT published

## Edit rigs on every spawner 2026-11-20

The developer: "Do all of them now". Picker answers: police squads no fixed spot ("I meant the NPCS like the criminals"), admin-spawned NPCs as is, the real admin panel in StarterGui, civilian spawners get rigs. Built natively.

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.EnemySpawner | 11,091 / 1886183207 | 11,742 / 4169185854 |
| ReplicatedStorage.SharedSystems.NPCSpawnManager (first mirror) | 6,140 / 2309961238 | 6,706 / 2524640644 |
| ServerScriptService.Admin.AdminService | 3,819 / 2179144165 | 4,519 / 1245643989 |
| ServerStorage.UnitTest.Cases.EditRigs_Test | new | 2,344 / 901316888 |

`CityMergeDeviation` appended on the three scripts; the test carries its own. World (three undo steps): 6 criminal rigs on the `EnemySpawnPoint` pads (EnemyTemplates clones, root anchored, weapon in hand; Offender and Disrupters on the terrain surface 1 stud above their pads), 10 civilian rigs on the `NPCSpawner` placeholders (ModelTemplates clones at the placeholder CFrame, root anchored), the 5 pre-placed `Bank Clerk` and SlowFoods `Cashier` models removed (deleted at boot by `_clearPreexisting` anyway), `AdminHudGui` and `AdminPanelGui` moved from `ServerStorage.AdminPanel` to StarterGui with `Enabled` false.

City 369 / 369 / 0 (test player shielded; unshielded, 2 tests that use the real player failed while enemies hurt it and passed alone); heist 764 passed / 0 failed. Edit after: no `Tmp*`, 1 enabled SpawnLocation, no Workspace attributes, 36 rigs on their markers.

NOT published

## Hit registration 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Blaster.Scripts.ShotResolver.validateTag (first mirror) | 2,210 / 2497835930 | 2,248 / 971569902 |
| ServerStorage.UnitTest.Cases.ValidateTag_Test | new | 2,307 / 2623210470 |

`CityMergeDeviation` appended on validateTag; the test carries its own. City 370 / 370 / 0; heist 764 passed / 0 failed. Details: `CrimeLife Vault/70 Batches/2026-11-20 Hit Registration.md`.

NOT published

## Crouch stealth 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Movement.Scripts.Stealth | new | 7,602 / 1517421686 |
| StarterGui.StealthVignette.StealthVignetteController | new | 1,523 / 1815874126 |
| ServerStorage.UnitTest.Cases.Stealth_Test | new | 1,779 / 94783184 |
| ServerScriptService.Movement.Scripts.RunningState | 1623531334 | 1,883 / 4096500649 |
| StarterPlayer.StarterCharacterScripts.Crouching | 2420100717 | 12,383 / 2137990833 |
| ServerScriptService.Enemy.Scripts.EnemyAI | 3345696100 | 46,573 / 3743326890 |
| ServerScriptService.Wanted.PoliceDispatcher | 1578145209 | 25,074 / 3423070207 |
| ServerScriptService.Wanted.Witnesses | 2589221737 | 2,684 / 1945931860 |
| ServerScriptService.Heist.Components.GuardPost | 3389669030 | 34,901 / 416649834 |
| ServerScriptService.Blaster.Scripts.Blaster | 1213314758 | 2,997 / 3941799855 |

(Before column: Adler-32 only.) New instances: `ReplicatedStorage.PlayerMovement.Crouch` (RemoteEvent), `StarterGui.StealthVignette` (ScreenGui, IgnoreGuiInset, ResetOnSpawn false, DisplayOrder -1; `Vignette` Frame with Top / Bottom / Left / Right black frames, UIGradient 0 to 1, BackgroundTransparency 1). `CityMergeDeviation` appended on all scripts. City 373 / 373 / 0; heist 764 passed / 0 failed.

NOT published

## Weapon gacha 2026-11-20

| Script | Before | After |
|---|---|---|
| ReplicatedStorage.Gacha.Config | new | 3,304 / 47981833 |
| ReplicatedStorage.Gacha.Draw | new | 2,335 / 103417734 |
| ServerScriptService.Gacha.GachaService | new | 7,100 / 4103632575 |
| ServerScriptService.Gacha.GachaServer | new | 1,347 / 858709131 |
| StarterGui.CrateGui.CrateController | new | 8,201 / 1218098561 |
| ServerStorage.UnitTest.Cases.Gacha_Test | new | 3,145 / 983743927 |
| ReplicatedStorage.Persistence.Schema | 2680666850 | 3,005 / 3265984381 |
| ServerScriptService.Weapons.Scripts.WeaponShopService | 1589322929 | 20,715 / 3198589140 |
| ServerScriptService.Monetization.Scripts.MonetizationService | 3693060990 | 6,185 / 624582641 |
| StarterPlayer.StarterPlayerScripts.WeaponaryShopController | 3423576501 | 55,376 / 664613598 |

(Before column: Adler-32 only.) New instances: `ReplicatedStorage.Gacha` (Folder: Config, Draw, Remotes { Roll RemoteFunction, BuyKeys RemoteEvent }, OpenCrates BindableEvent), `ServerScriptService.Gacha` (Folder), `StarterGui.CrateGui` (ScreenGui, 61 instances, Panel hidden, CardTemplate). `Rarity` attributes on the 36 crate weapons in `ServerStorage.Weapons`. City 378 / 378 / 0; heist 764 passed / 0 failed.

NOT published

## Combat A, hit feedback 2026-11-20

`ReplicatedStorage.Blaster.Scripts.GuiController` 3610573378 -> 8,430 / 151342320: body hit white, headshot red (higher ding), kill a bigger red X (lower, louder), from the existing DamageIndicator and KillConfirmed remotes. Verified in Play (remotes fired at the player: rotation 45 red after a kill, 0 red after a headshot; no errors).

NOT published

## Combat B, enemy hit reactions 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.HitReaction | new | 3,671 / 4239444562 |
| ServerStorage.UnitTest.Cases.HitReaction_Test | new | 1,794 / 3747304629 |
| ServerScriptService.Blaster.Scripts.ShotResolver | 2940260377 | 38,919 / 2033886659 |

City 380 / 380 / 0; heist 764 passed / 0 failed. Live: a Glock shot flashed and pushed a Thug 0.97 studs.

NOT published

## Combat C, wounded finishers and stealth takedowns 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.Finishers | new | 6,564 / 2624693041 |
| ServerScriptService.Enemy.Scripts.FinishersServer (Script) | new | 115 / 3157862005 |
| ServerStorage.UnitTest.Cases.Finishers_Test | new | 1,201 / 2275184061 |
| StarterPlayer.StarterPlayerScripts.CombatActions (LocalScript) | new | 3,121 / 2575240800 |
| ServerScriptService.Enemy.Scripts.EnemyAI | 46,573 / 3743326890 | 47,159 / 1283614048 |
| ServerScriptService.Movement.Scripts.Stealth | 7,602 / 1517421686 | 7,756 / 395983637 |
| ServerScriptService.Weapons.Scripts.LevelingService | 11,656 / 305578906 | 12,098 / 2658098006 |
| ServerScriptService.Weapons.Scripts.CashService | 11,722 / 2069142257 | 12,269 / 4069217708 |

New instances in Edit: `ReplicatedStorage.Combat.Remotes.Finish` (RemoteEvent); `StarterGui.CombatHint` (ScreenGui) with `Hint` (TextButton 200 x 40, Visible false).

City 382 / 382 / 0 (temporary Script); heist 764 passed / 0 failed. Live: takedown, finish and the wound roll verified. Place version 51.

NOT published

## Combat D, smarter enemies 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.Tactics | new | 3,041 / 3908952226 |
| ServerStorage.UnitTest.Cases.Tactics_Test | new | 2,914 / 4098725894 |
| ServerScriptService.Enemy.Scripts.EnemyAI | 47,159 / 1283614048 | 53,147 / 1126838795 |
| ServerScriptService.Movement.Scripts.Stealth | 7,756 / 395983637 | 7,822 / 3629863366 |

City 387 / 387 / 0 (temporary Script); heist 764 passed / 0 failed. Live: alert, flank, cover (temporary wall, removed) and back off verified; melee unchanged. Place version 53.

NOT published

## Combat E, melee combos and block 2026-11-20

| Script | Before | After |
|---|---|---|
| ReplicatedStorage.Combat.MeleeRules | new | 2,890 / 3927750303 |
| ServerScriptService.Blaster.Scripts.MeleeMoves | new | 5,901 / 1172238321 |
| ReplicatedStorage.Blaster.Scripts.MeleeController | new | 6,756 / 3211335603 |
| ServerStorage.UnitTest.Cases.MeleeMoves_Test | new | 3,352 / 3154458956 |
| ReplicatedStorage.Blaster.Scripts.BlasterController | 20,422 / 318981244 | 20,953 / 224588844 |
| ServerScriptService.Blaster.Scripts.Blaster | 2,997 / 3941799855 | 3,432 / 1576774553 |
| ServerScriptService.Blaster.Scripts.ShotResolver | 38,919 / 2033886659 | 40,515 / 1106162204 |

New instances in Edit: `ReplicatedStorage.Combat.Remotes.MeleeCharge` and `.Block` (RemoteEvents); `ReplicatedStorage.Blaster.Scripts.TouchInputController.BlasterTouchGui.Buttons.BlockButton` (copy of ViewButton, 100 x 100 at the RELOAD spot, label BLOCK, Visible false).

City 391 / 391 / 0 (temporary Script); heist 764 passed / 0 failed. Live: combo 45 / 54 / 67.5, heavy 90 + stagger, block x0.30, parry 0 + attacker stunned 1 s. Place version 55.

NOT published

## Enemy movement and store police 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.EnemyAI | 53,147 / 1126838795 | 56,483 / 2361164006 |
| ServerScriptService.Enemy.Scripts.Finishers | 6,564 / 2624693041 | 6,757 / 3239764355 |
| ReplicatedStorage.Enemy.Constants | 6,732 / 667011660 | 6,855 / 270069932 |
| ReplicatedStorage.Wanted.Constants | 3,934 / 1396754736 | 4,146 / 3727691275 |
| ServerScriptService.Wanted.PoliceDispatcher | 25,074 / 3423070207 | 26,657 / 1417345805 |
| ServerScriptService.Heist.Services.HeistPolice | 12,616 / 2808713664 | 12,854 / 1749409788 |
| ReplicatedStorage.RestaurantShared.Config | 4,029 / 202853836 | 4,725 / 2995205378 |
| ReplicatedStorage.Gas2GoShared.Config | 3,445 / 792494017 | 4,138 / 1172989274 |
| ServerScriptService.SlowFoodsServer | 14,259 / 3174915992 | 14,998 / 4231357228 |
| ServerScriptService.Gas2GoServer | 15,011 / 3117630225 | 15,705 / 1919366720 |

New in Edit: `Workspace.SlowFoodsMarkers.HeistPoliceSpawn1` (93, 4.05, 1784), `HeistPoliceSpawn2` (100.5, 4.05, 1784); `Workspace.Gas2GoMarkers.HeistPoliceSpawn1` (-990.5, 4.05, 1961), `HeistPoliceSpawn2` (-982.5, 4.05, 1961): copies of NewsStation's marker (2 x 1 x 2, invisible, anchored), each with a `Police` Edit rig standing on it facing the store.

City 391 / 391 / 0; heist 764 passed / 0 failed. Live: Thug chase stalls gone; SlowFoods and Gas2Go robberies end with 4 officers fighting inside. Place version 65.

NOT published

## Enemies climb, vault and roll 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.EnemyMoves | new | 10,428 / 3521284780 |
| ServerStorage.UnitTest.Cases.EnemyMoves_Test | new | 2,661 / 2957464572 |
| ServerScriptService.Enemy.Scripts.EnemyAI | 56,483 / 2361164006 | 57,600 / 753662010 |

City 394 / 394 / 0; heist 764 passed / 0 failed. Live: climb onto a 6-stud block, vault a 2.5-stud wall, dodge rolls. Place version 67.

NOT published

## Interaction animations and takedown prompt 2026-11-20

| Script | Before | After |
|---|---|---|
| ReplicatedStorage.Combat.Clips | new | 2,411 / 779754291 |
| StarterPlayer.StarterPlayerScripts.InteractionAnimations (LocalScript) | new | 4,491 / 4136554688 |
| ServerScriptService.Enemy.Scripts.Finishers | 6,757 / 3239764355 | 8,936 / 80850049 |
| StarterPlayer.StarterPlayerScripts.CombatActions | 3,121 / 2575240800 | 4,085 / 248207702 |
| ServerScriptService.Enemy.Scripts.HitReaction | 3,671 / 4239444562 | 4,237 / 429229658 |

City 394 / 394 / 0; heist 764 passed / 0 failed. Live: the takedown prompt and chokehold; the register hold clip. The five new Crime* clips are made in Blender but not uploaded (403 on the group key); `Combat.Clips.ids` has no Crime* ids yet. Place version 68.

NOT published

## Crime clip ids 2026-11-20

| Script | Before | After |
|---|---|---|
| ReplicatedStorage.Combat.Clips | 2,411 / 779754291 | 2,688 / 619078488 |

The five Crime* clips uploaded to group 4998611 and their ids filled in. Live: CrimeRegister, CrimeChoke, CrimeStagger play. Place version 69.

NOT published

## Smooth enemy facing 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Enemy.Scripts.EnemyAI | 57,600 / 753662010 | 59,066 / 566881909 |

Each enemy gets `HumanoidRootPart.FacingAttachment` and an `AlignOrientation` `Facing` (made at runtime). Place version 70.

NOT published

## Level-up popup stuck 2026-11-20

| Script | Before | After |
|---|---|---|
| StarterPlayer.StarterPlayerScripts.LevelingHud | 13,316 / 3006033539 | 13,711 / 2819421582 |

The popup gets `UITransitionIgnore` so UI.Transitions never restores it visible after a respawn.

NOT published

## Death knockback from the hit part 2026-11-20

| Script | Before | After |
|---|---|---|
| ServerScriptService.Blaster.Scripts.ShotResolver | 40,515 / 1106162204 | 43,510 / 245144580 |

Place version 72.

NOT published
