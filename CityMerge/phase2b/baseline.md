# Phase 2b baseline (city place `Crimelife city.rbxl`, 2026-11-15)

Measured in this run, in Edit, before and after one Play. Nothing was changed in the place.

## Whole-place checksums (definitions: `CityMerge/first-run.md` Step 6)

Enabled checksum: Adler-32 over the sorted list of `<full name>=<Enabled>` for every BaseScript, joined with `\n` (this form reproduces the earlier 336067737). Source checksum: Adler-32 over the sorted list of `<full name>=<Source>` for every LuaSourceContainer, joined with `\n` (the exact separator of the earlier 4045279041 is not recorded, so the new source value is not comparable with it; it is the reference for later tasks).

| | BaseScripts | enabled | Enabled checksum | source containers | source checksum |
|---|---|---|---|---|---|
| before Play | 196 | 121 | 336067737 | 297 | 215335317 |
| after Play (temporary objects removed, spawns restored) | 196 | 121 | 336067737 | 297 | 215335317 |

## One Play from `Workspace.Dev.DevSpawn`

Spawns: DevSpawn enabled, city `SpawnLocation` disabled for the Play (1 enabled SpawnLocation); restored afterwards (DevSpawn false, city true, 1 enabled).

Unit tests (temporary server Script, 60 s timeout per call):

| suite | run / passed / failed |
|---|---|
| PropertyAuthority_Test | 8 / 8 / 0 |
| validateRunningState_Test | 8 / 8 / 0 |
| staminaStep_Test | 10 / 10 / 0 |
| Palettes_Test | 11 / 11 / 0 |
| SkinApplier_Test | 14 / 14 / 0 |
| CosmeticsOwnership_Test | 12 / 12 / 0 |
| SpraypaintConstants_Test | 8 / 8 / 0 |
| SpraypaintService_Test | 21 / 21 / 0 |
| SpraypaintTier_Test | 8 / 8 / 0 |
| Schema_Test | 9 / 9 / 0 |
| ProfileGateway_Test | 22 / 22 / 0 |
| ProfileAdoption_Test | 16 / 16 / 0 |
| **sum of suites** | **147 / 147 / 0** |
| filter `""` (all) | 147 / 147 / 0 |

Console (`LogService:GetLogHistory()`, read at about 25 s of `DistributedGameTime`, after the tests had run):

| | messages | warnings | errors | distinct warn/error lines | asset lines (ContentId / failed animation / failed sound) | other |
|---|---|---|---|---|---|---|
| Server | 512 | 99 | 51 | 45 | 11 | 34 |
| Client | 291 | 79 | 211 | 33 | 33 | 0 |

- Client: every distinct line is an asset line (permission or approval failures for ids, plus the empty-id and `rbxassetid://0` ContentId warnings). No script error.
- Server "other" 34 lines, all unit-test noise already known from `first-run.md`: `StartSessionAsync failed ... already loaded` (3 attempts per run), `migrate failed ... stored version -1`, `hydrator failed ... FindFirstChild of table` (`CashService:94`, `LevelingService:113`), `late post-hydrator failed`. The server "Infinite yield" line seen in the first run and the `MonetizationService` ownership line did not appear.
- No `[FAIL]` line was captured (every suite reports failed=0).

## Source snapshot

26 script sources exported to `CityScripts/<FullName>.luau` with `CityMerge/transfer/export-source.luau`; each file's byte length and Adler-32 equals what the snippet returned (26 of 26).
