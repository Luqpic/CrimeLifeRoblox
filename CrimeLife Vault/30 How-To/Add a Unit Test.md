---
type: howto
tags: [howto, testing]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium; Running tests)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md §8", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "CrimeLifeRoblox/FPSSystem/Cosmetics/Palettes_Test.luau", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/RobberySystem/.sdd-getaway/reconstructed/LocationServerSpec.lua"]
---

# Add a Unit Test

A test case for the in-place framework at `ServerStorage.UnitTest`. Tool: [[Unit Test Runner]].

Skills: `roblox-testing`.

## Steps
1. **Write a case** as a ModuleScript `ServerStorage.UnitTest.Cases.<Name>_Test` returning `function(t)`; use `t.test(name, fn)` and `t.expect` (`equal`, `truthy`, `falsy`, `near`, `throws`, `deepEqual`). Mirror it as `FPSSystem/<area>/<Name>_Test.luau`.
2. **Test data with invariants**, not just shapes (Palettes: ramps run dark to light; swatches at least 52.8 apart).
3. **Persistence tests use `ProfileStore.Mock`** (a fake DataStore forgotten at shutdown), which is what makes them run on an unpublished place.
4. **Run in Play, Server datamodel:**
   ```lua
   local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
   local r = run("Palettes")
   return string.format("run=%d passed=%d failed=%d", r.run, r.passed, r.failed)
   ```
   Read the fields; `tostring(r)` prints an address.
5. **Mutation-test** a new invariant once: break the data, see it go red, revert, see green.

## Traps
- **Edit-mode `execute_luau` serves stale modules.** A run after editing a module reported 127/132 with false failures; the same suites passed from a real server VM. Trust Play.
- **The filter is a plain unanchored substring:** a name that contains another name runs both. Choose names that isolate.
- `RunUnitTest` finds cases by `Cases:GetDescendants()`, so a name search calls a case "dead" wrongly.
- `ServerScriptService.UnitTestRunner` is **Disabled on purpose**. Re-enabling it would run `useMockStore()` mid-session and repoint the live profile store.
- Viewmodel specs are separate modules (`ServerStorage.WeaponViewmodelMotionTests`, `WeaponClassMotionTests`, mirrored as `FPSSystem/ViewmodelAnimations/*.spec.luau`); they are not an automatic runner.
- The **Robbery place** uses its own runner, `ReplicatedStorage.HeistShared.TestRunner`, with `*Spec` modules (`LocationServerSpec`, `WorldSpec`).

## Done before
[[FPS-Weapon-Skins-Phase-1]] (`Palettes_Test`, `SkinApplier_Test`, `CosmeticsOwnership_Test`), [[FPS-Spraypaint-Phase-2]], [[FPS-Persistence-Phase-3]], [[FPS-Skins-Card-Detached-And-Palette-Expansion]], [[FPS-Weaponry-Category-Icons]] (146/146 in a real server VM), [[Getaway-Distance-Replaces-Claim-Zone]].
