# Baselines before the import (Task 1, Leg 1)

Measured 2026-11-16. Both windows resolved by name. Nothing saved, published or edited; no import. Temporary objects (`_HeistSuiteResult`, `_HeistSuiteRunner`, `_HeistSuiteRunner2` in the Robbery Play; `_T1UnitResult`, `_T1UnitRunner` in the city Play) were removed before each Play stopped and none was found in Edit afterwards.

## A. Robbery heist suite (`Robbery System.rbxl`, one Play, 20 s after start)

Method: one Play; a temporary server `Script` created in the Play server datamodel (`ServerScriptService._HeistSuiteRunner`) ran `require(ServerScriptService.Heist.Tests.RunAll)()` and wrote the returned report into a `StringValue` in `ServerStorage`; read back from a server `execute_luau`. `RunAll` returns `TestRunner.report` (per spec: passed / failed, and `FAIL <label> :: <message>`). Studio was not minimised. The run was repeated once in the same Play (`_HeistSuiteRunner2`); each run took about 10 s.

| | passed | failed |
|---|---|---|
| Run 1 | 594 | 16 |
| Run 2 | 595 | 15 |
| Vault expectation | 594 | 14 |

Failure set by spec and case:

| Spec | Case | Run 1 | Run 2 | Message / classification |
|---|---|---|---|---|
| CashClaimVFX | all 12 cases (construction builds a persistent Cash display...; PlaySequence animates...; never exceeds the true new value...; burst count is fixed...; burst icons are ImageLabels...; burst icons spawn at the configured burstOrigin...; burstOrigin defaults to screen center...; cleans up every burst icon...; no-op when unchanged; second claim animates from the previous value; passive leaderstats listener...; same-claim race...) | fail | fail | `ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'` (`script.Parent` is nil in the cloned module: the known failure in the vault). Expected. |
| RestaurantConfig | carries the spec's tunables | fail | fail | `CooldownDuration (20 minutes) - expected 1200, got 60`. Expected. |
| Gas2GoConfig | carries the spec's tunables | fail | fail | `CooldownDuration (10 minutes) - expected 600, got 60`. Expected. |
| TestRunner | freshRequire returns a distinct result each call | fail | fail | `The current thread cannot write 'Source' (lacking capability PluginOrOpenCloud)`. **Not in the vault's 14; a method effect:** the temporary `Script` has no plugin capability. The same spec run through server `execute_luau` (plugin context) passes 5 / 5. Counted as environmental to the temporary-Script method. |
| Zone | the real occupancy sweep ignores non-character geometry | fail | pass | `sweep must not walk the 1200 parts sharing its volume (took 4.86ms)`: a timing assertion. Run 1 only; **environmental**. A single-spec check afterwards (server `execute_luau`) also failed it (took 3.41 ms), so it is timing-sensitive, not a pass in a fixed run. |

Failure set that is stable in both runs: the 14 the vault expects (12 `CashClaimVFX`, one `CooldownDuration` case each in `RestaurantConfig` and `Gas2GoConfig`) plus `TestRunner` / freshRequire (method). No other failure appeared. Per-spec totals other than the above all passed in both runs (World 51, BankInstance 34, Duffel 20, Currency 11, Gate 19, LocationServer 18, Getaway 14, SupplyObject 25, LockedDoor 24, and so on).

**Baseline to hold after the import:** the 14 expected failures; `TestRunner` / freshRequire fails only when run from a temporary `Script` (use `execute_luau` for the capability); `Zone` / sweep is timing-sensitive.

## B. City (`Crimelife city.rbxl`)

### Whole-place checksums (Edit, definitions of `CityMerge/phase2b/baseline.md`)

LuaSourceContainers in `ReplicatedStorage`, `ReplicatedFirst`, `ServerScriptService`, `ServerStorage`, `StarterGui`, `StarterPack`, `StarterPlayer`, `SoundService`, `Lighting`, `Teams`, `Workspace`; full names from `GetFullName()`; Adler-32 over the sorted `<full name>=<Enabled>` (BaseScripts) and `<full name>=<Source>` (all containers), joined with `\n`.

| | source containers | BaseScripts | enabled | Enabled checksum | source checksum |
|---|---|---|---|---|---|
| before Play | 326 | 220 | 144 | 4126413690 | 3149783013 |
| after Play (temporary objects removed, 1 enabled SpawnLocation) | 326 | 220 | 144 | 4126413690 | 3149783013 |

Both equal the values recorded after Play 5 of phase 2b (`phase2b/final-run.md`, 326 containers including `Workspace.HQ`), so no script changed since.

### Counts

| Reading | Value |
|---|---|
| `#workspace:GetDescendants()` in Edit (whole place), before and after Play | 226,903 / 226,903 |
| Client `#workspace:GetDescendants()` at 25.4 s of `DistributedGameTime`, character at (-9.6, 5.1, 2498.1) (city spawn) | 93,272 |
| Client `PlayerGui` children / `PlayerScripts` children at 25.4 s | 21 / 28 |

(`StreamingEnabled` is on; the client count is whatever has streamed in at the spawn.)

### Unit tests (one Play from the city spawn, temporary server `Script`, 60 s per case)

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
| ProfileAdoption_Test | 17 / 17 / 0 |
| QuestReach_Test | 4 / 4 / 0 |
| BlasterGuard_Test | 4 / 4 / 0 |
| ShotRate_Test | 5 / 5 / 0 |
| QuestSave_Test | 10 / 10 / 0 |
| **sum of 16 suites** | **171 / 171 / 0** |
| filter `""` (all) | 171 / 171 / 0 |

0 `[FAIL]` or `[TIMEOUT]` lines through `LogService.MessageOut` during the runs.

## C. Robbery place counts (Edit, for later comparison)

`#workspace:GetDescendants()` = 32,643; 133 LuaSourceContainers in the 56 roots of `robbery-manifest.md`. Whole-place checksums of the Robbery place: not recorded (nothing is compared against them).
