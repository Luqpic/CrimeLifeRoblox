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
