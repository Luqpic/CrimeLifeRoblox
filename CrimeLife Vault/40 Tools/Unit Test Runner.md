---
type: tool
tags: [tool, testing, unit-tests]
updated: 2026-11-14
sources: ["docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium; Running tests)", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "70 Batches/FPS System/FPS-Weapon-Skins-Phase-1.md", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", ".superpowers/sdd/skins-card-sticky-fix-report.md"]
---

# Unit Test Runner

CrimeLife's tests live inside the place, not in a CLI framework.

## The pieces

| Piece | What it is |
|---|---|
| `ServerStorage.UnitTest.RunUnitTest` | ModuleScript: `run(filter, timeout)` returns a table `{run, passed, failed}` |
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

Recorded totals: 146 / 146 tests (2026-09-24, skins card sticky fix, real server VM, temporary Script); the viewmodel motion suite 7,102 assertions over 28 rigs ([[Viewmodels and Weapon Animation]]).

## Traps

- **Never run suites from Edit after editing a module.** The plugin VM's `require` cache goes stale: Edit-mode `execute_luau` reported **127 / 132** with 5 false failures in `ProfileGateway_Test` ("attempt to call a nil value" on `Gateway.migrate`, which existed live); the same suites passed from a Script in a real server VM ([[FPS-Persistence-Phase-3]]). One of the five "passed" for the wrong reason: `expect.throws(Gateway.migrate)` is satisfied by calling `nil`.
- **The filter is a plain, unanchored substring.** `run("Palettes")` also ran `SpraypaintPalettes_Test` (18, not 10). Fixed by renaming it `SpraypaintTier_Test`; the runner is unchanged, so any new case whose name contains an existing one collides again ([[FPS-Spraypaint-Phase-2]]).
- **Read the fields.** `tostring(r)` prints a table address, not a count.
- **Keep `UnitTestRunner` Disabled.** If it ran at server start, `ProfileGateway_Test`'s `useMockStore()` would repoint the live store mid-session ([[Safety and Security Rules]]).
- **Script services cannot be adopted by table stand-ins.** `LevelingService`, `CashService`, `WeaponShopService`, `WeaponUpgradeService` and `KillStatsService` are Scripts; their hydrators register at server start and throw on the table stand-in `ProfileAdoption_Test` uses (`FindFirstChild("leaderstats")`). The gateway `pcall`s them, so every run carries a pair of warnings ([[FPS-Persistence-Phase-3]]).
- **A test that cannot fail is not a test.** [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]] speaks of "the tests-that-cannot-fail trap this project has hit eight times". See each new case fail first ([[Measure Before and After]]).
- **Attribute signals are deferred.** A test that writes an attribute and reads a dependent value on the next line sees the old value; `task.wait()` between them ([[Luau and Scripting Traps]]).

Related: [[Tools MOC]] · [[Studio MCP Gotchas]] · [[Persistence and Saves]]
