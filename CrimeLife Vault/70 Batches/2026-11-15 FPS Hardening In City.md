---
type: batch
tags: [batch, city, hardening, remotes, quests, persistence, ui, phase-2b]
updated: 2026-11-15
sources: [".superpowers/sdd/2026-11-15-fps-hardening-in-city/progress.md", ".superpowers/sdd/2026-11-15-fps-hardening-in-city/task-1-report.md to task-5-report.md", "CrimeLifeRoblox/CityMerge/phase2b/baseline.md", "CrimeLifeRoblox/CityMerge/phase2b/remote-audit.md", "CrimeLifeRoblox/CityMerge/phase2b/zindex-audit.md", "CrimeLifeRoblox/CityMerge/phase2b/final-run.md", "CrimeLifeRoblox/CityMerge/after-import.md", "CrimeLifeRoblox/CityMerge/first-run.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-11-15-fps-hardening-in-city.md"]
---

# 2026-11-15 FPS Hardening In City

Place: `Crimelife city.rbxl` (Edit and Play); `FPS System.rbxl` and `Robbery System.rbxl` untouched. Plan: `docs/superpowers/plans/2026-11-15-fps-hardening-in-city.md` (phase 2b, after [[2026-11-15 FPS Systems Into City]]). Ledger with every ruling: `.superpowers/sdd/2026-11-15-fps-hardening-in-city/progress.md`. Commits `d7600ea..` through `7d6cfdc`, then this note's commit.

## Asked for

Phase 2b: the work [[2026-11-15 FPS Systems Into City]] left open and the first run found: audit every client-to-server remote for ownership, save quest progress, decide which `ZIndexBehavior.Global` ScreenGuis can flip to `Sibling`, and close the first run's leftovers (`Lean` line 41, `workspace.FX`, the preview warning). The developer's one call for the run: "Run, save checkpoints" (save the place after each clean task; never publish).

## What changed

**Task 1: source snapshot and baseline** (`f2c2a68`). 26 script sources exported to `CityScripts/` with `CityMerge/transfer/export-source.luau` (each file's Adler-32 equals the place's). Baseline in `CityMerge/phase2b/baseline.md`: 196 BaseScripts, 121 enabled, 297 source containers, source checksum 215335317, Enabled checksum 336067737; 12 suites 147 / 147 / 0; one Play from `Dev.DevSpawn` with no game-script error.

**Task 2: remote audit** (`d71ecf9`, `7423d90`). `CityMerge/phase2b/remote-audit.md`: 14 `OnServerEvent` handlers (no `RemoteFunction` exists), each rated against the brief's rule (FIX only when a client can act on what it does not own, write a bad value into state or a save, or gain cash, XP, a weapon, a skin or quest credit without doing the thing). Four FIXes:

| Remote | Defect | Fix |
|---|---|---|
| `AcceptQuestRequest`, `TurnInQuestRequest` | quest credit and the 500 cash + 100 XP reward from anywhere on the map | the character must be within `QuestConfig.MAX_INTERACT_DISTANCE` (30 studs) of the giver (`withinReach`, `canReach`) |
| `Shoot` hit keys | `tonumber` folded `"1"`, `"01"`, `"1.0"`, `"0x1"` to one ray, so one ray could be claimed many times | `validateShootArguments` refuses any key that is not `tostring` of its index (`BlasterGuard_Test`) |
| `Shoot` rate of fire | none on the server | new module `validateFireInterval`, judged on claimed timestamps with a 10% margin, state keyed by player and weapon name (`ShotRate_Test`) |
| `SetLevelRequest` | NaN passed the clamp and reached the save | one line refuses NaN |

Rate state was first keyed per Tool instance; review found `SetLoadoutSlotRequest` hands out a fresh Tool each call, which reset it (Crowbar, second swing 0.22 to 0.24 s later: 85, 77.5, 70 before the fix; 130, 122.5, 122.5 after). Rated OK with a note: re-slotting a held weapon leaves a second copy; a skin can be stored for an unowned weapon type; one burst after idle is accepted. A `validateFireInterval` call with a nil or non-number rate-of-fire attribute does not throw and does not refuse: it accepts (all 38 weapons declare one). Tests 160 / 160 / 0.

**Task 3: quest progress is saved** (`7faa1e7`, `8c52cad`). `Schema.template` gained `quests` and `questCompletions`; `QuestConfig.restore` (pure) drops unknown ids and bad entries and clamps progress; `QuestService` mirrors after accept, each counted kill and turn-in and hydrates through the gateway. Review found the hydrator raised `Quest_<id>_Completions` after the client had seeded 0, which replayed the QUEST COMPLETE toast on rejoin (measured). Fix: `QuestService` sets the player attribute `QuestsRestored` last in `hydrate`, and `QuestFeedbackController` treats completions seen before it as a seed. Non-table quest data is reset to `{}` in `hydrate`; `QuestSave_Test` has 10 cases. Tests 167 then 171 / 171 / 0 (16 suites).

**Task 4: ScreenGuis** (`7d6cfdc`). `ZIndexBehavior` flipped to `Sibling` only where paint order was measured equal under both modes: `PromptUiGui`, `AdminLevelGui`, `DamageDirectionIndicator`, `CashSpendBurst` (one line each, via `PromptUiController`, `AdminLevelController`, `DamageDirectionIndicator` and `CashBurst`). Six stay `Global` because Sibling would change the paint order:

| ScreenGui | swapped pairs | overlapping pairs |
|---|---|---|
| `CashShopGui` | 233 | 0 |
| `GamepassShopGui` | 51 | 0 |
| `WeaponaryShopGui` | 609 | 0 |
| `QuestLogGui` | 2 | 0 |
| `DeathScreenGui` | 3 | 3 (hidden) |
| `Custom Inventory` | 123 | 0 |

**Task 5: leftovers, closing run, this note.**
- `Lean`: `lowerTorso.Root` and `humanoidRootPart.RootJoint` now `WaitForChild(name, 10)` with a quiet `return` on nil (5,970 / 3351089419 to 6,038 / 2152900123).
- `Workspace.FX`: empty `Folder` (`PlacedBy = "phase 2b"`), so `Crouching` line 250 finds its parent; the script is unchanged.
- `ServerScriptService.WeaponAnimationPreview`: `Enabled = false` (`CityMergeDeviation = "preview rig folder is not in the city"`).
- `remote-audit.md` corrected: after idle one swing of a 30 rpm weapon passes the burst window, not two.
- Every edit is in `CityMerge/after-import.md` with its Adler-32; every edited source was re-exported to `CityScripts/` and matches the place.

## Decisions

Claude's calls (controller rulings from the ledger) are in [[CrimeLife Tycoon Decisions]] under 2026-11-15, phase 2b. The developer's one call: "Run, save checkpoints".

## Verified

- Closing run (`CityMerge/phase2b/final-run.md`), five Plays from the city spawn, each read at 25 s: PlayerGui 21, PlayerScripts 28, `WalkSpeed` 20, `workspace.FX` present on the client, 0 client script errors, 0 `Infinite yield`, 0 lines about `WeaponAnimationPreview`.
- Play 5: AK47 bought through `BuyRequest` (cash 500 to 300, saved to the profile); one Thug kill (XP 0 to 10); quest accepted at 5.7 studs, 10 Thug kills to `ReadyToTurnIn`, a far (45.0 studs) turn-in refused, a near (4.6 studs) turn-in paid (cash 350 to 875: 500 reward plus the 25 level-up bonus the quest's 100 XP triggered; completions 1; profile `questCompletions` 1, `quests` empty).
- Unit tests: 16 suites, 171 / 171 / 0, 0 `[FAIL]` lines; the 147 cases that existed before the plan all pass.
- Whole-place source checksum against Task 1's baseline: with the 14 edited scripts put back and the 5 new modules left out the checksum is 215335317, the baseline value. The 19 scripts that differ are exactly the ones this plan edited or created, and nothing else.
- Task 2 to 4 were each reviewed against the live place and approved after their fix rounds (Task 2: one Important, the rate state key; Task 3: one Important, the replayed toast; Task 4 clean).
- Final state: exactly one enabled `SpawnLocation` (`Workspace.SpawnLocation`), no temporary object.

## Not verified

- **Any of it on a published place.** All save tests ran on the mock store (`ProfileStore.Mock`); the saved-profile values above are in-session profile reads.
- **The fire-rate margin with real mouse fire.** The 10% under the interval was not tried by a person; only synthetic claimed timestamps.
- **A person at the keyboard:** pressing E on a quest giver, the quest dialogue by click, a phone, two players.
- **Whether the four flipped ScreenGuis look the same on screen.** Equality is of modelled paint order (tree order for ties), not proven against the renderer; the counts include hidden objects.
- **That `Crouching`'s dust reaches `Workspace.FX`:** the folder exists, the dust path was not exercised.
- **The 3 server errors per Play from `Workspace.HQ`** (below) were not traced to who added that folder.

## Left open

All in [[Open Items]]. New this batch: the six ScreenGuis left `Global` with their counts; the re-slot second copy; a skin stored for an unowned weapon; one burst accepted after idle; the untried fire-rate margin; a client whose profile never restores never shows a quest completion; all save tests on the mock only; and `Workspace.HQ` in the city (a copy of `ServerStorage.HQ` that was not there at the start of this task's run, with 3 script errors on every Play: a door script reading a missing `opendoor` and a barista script reading a missing `ServerStorage.Bar`).

## Links

[[Persistence and Saves]] · [[Quests and Dialogue]] · [[HUD and UI Shell]] · [[Streaming and Replication Traps]] · [[Luau and Scripting Traps]] · [[UI Layout Traps]] · [[Unit Test Runner]] · [[CrimeLife Tycoon Decisions]] · [[2026-11-15 FPS Systems Into City]] · [[Open Items]] · [[Batch Log]]

**Saved to `Crimelife city.rbxl` at checkpoints after Tasks 1 to 4; the controller saves once more after this task. NOT published.**
