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

NOT saved / NOT published
