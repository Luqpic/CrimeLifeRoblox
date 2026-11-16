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

NOT saved / NOT published
