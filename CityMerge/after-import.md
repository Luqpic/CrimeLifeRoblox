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
