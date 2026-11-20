---
type: tool
tags: [tool, testing, unit-tests]
updated: 2026-11-20
sources: ["docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium; Running tests)", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "70 Batches/FPS System/FPS-Weapon-Skins-Phase-1.md", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", ".superpowers/sdd/skins-card-sticky-fix-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-6-report.md"]
---

# Unit Test Runner

CrimeLife's tests live inside the place, not in a CLI framework.

## The pieces

| Piece | What it is |
|---|---|
| `ServerStorage.UnitTest.RunUnitTest` | ModuleScript: `run(filter, timeout)` returns a table `{run, passed, failed}`. Since 2026-11-18 the module returns a **callable table** (`setmetatable({ matches = matches }, { __call = ... })`), not a function |
| `ServerStorage.UnitTest.Cases.<Name>_Test` | One ModuleScript per suite, returning `function(t)`; uses `t.test(name, fn)` and `t.expect` (`equal`, `truthy`, `falsy`, `near`, `throws`, `deepEqual`) |
| `ServerScriptService.UnitTestRunner` | A runner Script, **`Disabled` on purpose** |
| `ServerStorage.WeaponViewmodelMotionTests`, `ServerStorage.WeaponClassMotionTests` | Spec modules for the viewmodel motion (mirrors `WeaponViewmodelMotion.spec.luau`, `WeaponClassMotion.spec.luau`); "not an automatic production runner" |
| Mirrors in git | `CrimeLifeRoblox/FPSSystem/**/*_Test.luau` (9: Cosmetics 3, Persistence 3, Spraypaint 3) and `**/*.spec.luau` (4, in `ViewmodelAnimations/`) |

Cases are discovered with `Cases:GetDescendants()`, so a name search for a case finds nothing: `PropertyAuthority_Test` looked dead to an audit and is not ([[FPS-Quest-Overflow-And-Dead-Code-Removal]]).

## Run it

In a **fresh Play session, Server datamodel** (start Play with `start_stop_play`, leave Studio in Edit afterwards):

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
local r = run("Profile")
return string.format("run=%d passed=%d failed=%d", r.run, r.passed, r.failed)
```

Recorded totals: city 315 / 315 and heist 740 passed, 0 failed (2026-11-18, closing run after Task 6's fix round, fresh Play, city 13.379 s; the heist total is `Heist.Tests.RunAll`'s return value, 47 specs, [[2026-11-18 Open Items Pass]]; earlier that day city 311 / 311 with heist 740 / 0 at Task 6, 295 / 295 with 749 / 0 at Task 5); 288 / 288 (2026-11-18, city, Task 4 fix round 1, through the context's `pcall(require(RunUnitTest))`; heist suite 733 passed, 0 failed in the same pass, [[2026-11-18 Open Items Pass]]); 193 / 193 in 18 suites (2026-11-16, city, phase 3 closing run, from a server `execute_luau` in Play, no temporary Script; the heist suite `Heist.Tests.RunAll` 615 passed, 1 failed in the same Play: the `Zone` sweep timing case, [[2026-11-16 Robbery Systems Into City]]); 171 / 171 in 16 suites (2026-11-15, city, phase 2b closing run, temporary Script, [[2026-11-15 FPS Hardening In City]]); 146 / 146 tests (2026-09-24, skins card sticky fix, real server VM, temporary Script); the viewmodel motion suite 7,102 assertions over 28 rigs ([[Viewmodels and Weapon Animation]]).

- **Read `Heist.Tests.RunAll`'s result from its return value** (2026-11-18). The console is flooded with asset-permission lines, so the total line is easy to miss (the controller's first closing Play lost it); return the total and read that.

## Traps

- **Never run suites from Edit after editing a module.** The plugin VM's `require` cache goes stale: Edit-mode `execute_luau` reported **127 / 132** with 5 false failures in `ProfileGateway_Test` ("attempt to call a nil value" on `Gateway.migrate`, which existed live); the same suites passed from a Script in a real server VM ([[FPS-Persistence-Phase-3]]). One of the five "passed" for the wrong reason: `expect.throws(Gateway.migrate)` is satisfied by calling `nil`.
- **The filter is a plain, unanchored substring, unless it starts with "=".** `run("Palettes")` also ran `SpraypaintPalettes_Test` (18, not 10; fixed then by renaming it `SpraypaintTier_Test`, [[FPS-Spraypaint-Phase-2]]). Since 2026-11-18 a filter that starts with "=" matches the whole case name: `run("=ProfileAdoptionMutant_Test")` ran 20 cases where a substring match would have run 40. Anything else keeps the old substring rule, and nil runs everything. `matches` is exposed on the table. Spec `RunnerFilter_Test` (2 cases; RED "attempt to index function with 'matches'").
- **`RunUnitTest` is a callable table.** `require(RunUnitTest)(filter)`, `local run = require(...); run("Profile")` and `pcall(require(RunUnitTest))` all work; `task.spawn(require(...))` does not, because `task.spawn` wants a function or thread, not a table. The disabled `UnitTestRunner` Script calls `require(...)()`, which still works.
- **Read the fields.** `tostring(r)` prints a table address, not a count.
- **Keep `UnitTestRunner` Disabled.** If it ran at server start, `ProfileGateway_Test`'s `useMockStore()` would repoint the live store mid-session ([[Safety and Security Rules]]).
- **Script services cannot be adopted by table stand-ins.** `LevelingService`, `CashService`, `WeaponShopService`, `WeaponUpgradeService` and `KillStatsService` are Scripts; their hydrators register at server start and throw on the table stand-in `ProfileAdoption_Test` uses (`FindFirstChild("leaderstats")`). The gateway `pcall`s them, so every run carries a pair of warnings ([[FPS-Persistence-Phase-3]]).
- **A test that cannot fail is not a test.** [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]] speaks of "the tests-that-cannot-fail trap this project has hit eight times". See each new case fail first ([[Measure Before and After]]).
- **Attribute signals are deferred.** A test that writes an attribute and reads a dependent value on the next line sees the old value; `task.wait()` between them ([[Luau and Scripting Traps]]).

Related: [[Tools MOC]] · [[Studio MCP Gotchas]] · [[Persistence and Saves]]

- **Shield the Play player for a full city run** (2026-11-20). `WantedService_Test` and `EnemyTargetFilter_Test` use the real player and fail if an enemy hurts them mid-run (the spawn is near the criminals' area). Parent a `ForceField` (Visible false) to the character for the run, then remove it. [[2026-11-20 Edit Rigs on Every Spawner]]

- **Run the city suite from a Script, not from `execute_luau`** (2026-11-20). From a Server `execute_luau` in Play, `ProfileAdoption_Test` showed 5 false failures (quest, kill-stats and cash hydrators "expected true, got nil", "expected 1300, got 800"): that context's `require` gets its own `ProfileGateway`, whose hydrator list is empty because the Script services registered theirs in the live server's copy. The same run from a temporary Script parented to `ServerScriptService` (write the result to an attribute, read it, destroy the Script): 382 / 382. `Heist.Tests.RunAll` is fine from `execute_luau`. [[2026-11-20 Combat Feel]]

## History
- 2026-11-20: city 382 / 382 from a temporary Script; the `execute_luau` hydrator trap. [[2026-11-20 Combat Feel]]
- 2026-11-18: closing totals city 315 / 315, heist 740 / 0; RunAll's result is its return value. [[2026-11-18 Open Items Pass]]
