---
type: system
tags: [system, persistence, datastore, saves]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Per-Weapon-Spraypaint.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Revert-Global-Spraypaint-Balance.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md", "CrimeLifeRoblox/.superpowers/sdd/2026-09-23-persistence-phase-3/progress.md", "CrimeLifeRoblox/FPSSystem/Persistence/Schema.luau", "CrimeLifeRoblox/FPSSystem/Persistence/ProfileGateway.luau", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-5-report.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Persistence and Saves

**Skills:** `roblox-data-stores`, `roblox-security`, `roblox-testing` (load these for work here)

## What it does
Saves each player's progression across sessions with ProfileStore: Spraypaint, owned and equipped skins, cash, level and XP, owned weapons and loadout slots, upgrade levels, and per-faction kill counts. Built in Phase 3 on 2026-09-23. Before that every one of these reset on rejoin. `CLAUDE.md`'s "progression is session-only, no persistence layer" predates this phase and is stale.

Quest state is saved in the city since 2026-11-15 (`quests` and `questCompletions`, below). Not saved: gamepasses (no schema field; the spec left the `Vip` pass id to a later phase).

## Where it lives
- `ReplicatedStorage.Persistence.Schema`: `VERSION` (3 as of 2026-09-24), `template`, `DERIVED`. Mirror `CrimeLifeRoblox/FPSSystem/Persistence/Schema.luau`.
- `ServerScriptService.Persistence.Scripts.ProfileGateway`: the only module that requires ProfileStore. `mirror`, `registerHydrator` / `registerPostHydrator`, `keyFor`, `migrate`, `loadForKey`, `get`, `start`, `useMockStore` (Studio only). Store name `PlayerProfiles`.
- `ServerScriptService.Persistence.Scripts.PersistenceRunner`: sole caller of `ProfileGateway.start()`.
- `ServerStorage.ProfileStore`: vendored unedited, `MadStudioRoblox/ProfileStore` `main` at commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd`; repo mirror sha256 recorded in [[FPS-Persistence-Phase-3]].
- Tests: `ServerStorage.UnitTest.Cases.Schema_Test`, `ProfileGateway_Test`, `ProfileAdoption_Test` (since 2026-11-18 also: the quest hydrator wins over state published before the restore, restoring prunes what `restore` drops or clamps, and a Police kill is counted, saved and restored), and in the city `QuestSave_Test` (10 cases for `QuestConfig.restore`).
- Adopting services: `SpraypaintService`, `CosmeticsService`, `CashService`, `LevelingService`, `WeaponShopService`, `WeaponUpgradeService`, `KillStatsService`, and in the city `QuestService`.

## How it works
- Template: `spraypaint = 0`, `skinsOwned`, `equippedSkin`, `cash = 500` (`CashService.STARTING_CASH` reads it), `level = 1`, `xp = 0`, `kills` (`CriminalKills` / `PoliceKills`), `weaponsOwned`, `weaponUpgrades` (the LEVEL), `loadout`, and in the city `quests` (`[questId] = { state, progress }`) and `questCompletions` (`[questId] = count`). A new player is seeded with the Crowbar in slot 1.
- `DERIVED = { NextLevelXP, SkinId, damage, catalogue, lastLevel }`: never written; recomputed on load (damage = stock + level x `DAMAGE_PER_LEVEL`).
- Join: `loadForKey` tries 3 times, 2 s apart; `StartSessionAsync` and `migrate` are both pcalled, a throw counts as a failed attempt. A failed load returns `nil` and the player is kicked with `ProfileGateway.KICK_MESSAGE` (one constant, used by both `player:Kick` calls): "Your saved data could not be loaded, so nothing has been changed. Please rejoin in a moment." The developer asked (2026-11-18) to keep the text and add "Please rejoin."; it already ended that way, the vault had quoted it short, so nothing was edited. Exactly "Please rejoin." would be a one-constant change. A profile that failed to load is never written.
- Hydrators run strictly before the profile is bound (`get()` is `nil`, `mirror` no-ops), so a reward earned mid-restore is lost rather than saved from half-restored state. Post-hydrators run after every hydrator (Cosmetics re-dresses held Tools; Spraypaint re-seeds its level baseline). Late registrations run against already-bound players.
- `mirror(player, apply)` passes the **profile**: writes are `profile.Data.field = value`. `CashService` covers every cash writer with one `leaderstats.Cash` change listener.
- `migrate` stamps a missing `version` as 1, steps v1->v2->v3 with sequential `if`s, strips only `DERIVED` names (unknown fields from a newer schema are kept), then asserts `version == Schema.VERSION`: an unmigrated version fails closed and kicks.
- **Cash hydrate merges (2026-11-18).** `CashService.hydrate` keeps a pre-bind credit: Cash becomes saved + (Cash - `PreBindBase`), floored at 0, and the marker is cleared (RED 1000, expected 1300; Play read-back: Cash 500 with `PreBindBase` nil after the bind). Two `ProfileAdoption_Test` cases pin it through the real hydrator list and add 4 stand-in hydrator warnings to each city run. It assumes no other hydrator writes Cash first (`ProfileGateway` is not mirrored).
- Loadout slot keys are written as strings and read through `tonumber`.
- `UpgradeRequest` refuses weapons the player does not own (`WeaponOwned_*`), added because persistence made that exploit permanent.

## Extend it
1. Add the field to `Schema.template` (no version bump: `Reconcile` fills it). A field shaped like quest progress reads back through a pure `restore` (as `QuestConfig.restore` does: drop unknown ids and bad entries, clamp numbers) instead of trusting the saved table.
2. Changing a field's meaning: bump `VERSION` and add a migration step that reads the old shape. Never roll `VERSION` back.
3. In the owning service: `ProfileGateway.registerHydrator` to restore, `ProfileGateway.mirror` on every change. Only `ProfileGateway` may require ProfileStore.
4. Add a case to `ProfileAdoption_Test`; prove it through the game's own remotes, not by writing `profile.Data`.

## Watch out
- **Never revert `Schema.VERSION`.** Players already stamped with the newer version would fail `migrate`'s assert and be kicked on every join, permanently. The per-weapon Spraypaint revert rolled forward to v3 for this reason (2026-09-24).
- JSON has no integer keys: a sparse `{[1]=..,[3]=..}` loses slot 3; the Studio mock does not reproduce it.
- `mirror`'s callback gets the profile, not `profile.Data`; top-level writes are silently never saved (cash, level and XP saved nothing for a stretch of Phase 3).
- On an unpublished place `DataStoreState` is `NoAccess` and everything runs on ProfileStore's in-memory mock. The mock drops `params`, so the 30 s `LOAD_DEADLINE` and the departing-player cancel have never executed.
- `execute_luau` runs in a plugin VM with its own `require` cache: `ProfileGateway.get` reads `nil` there. Read profiles from a temporary server `Script`.
- Kill-count and Level hydration once fired Spraypaint's level-up signal on rejoin (phantom 25 per level). The award is now refused while the profile is unbound.
- Three live test suites (`PropertyAuthority_Test`, `staminaStep_Test`, `validateRunningState_Test`) were not mirrored into the repo as of 2026-09-23.
- Gamepass ownership is not in the profile.
- **Hydration that raises an attribute the client already seeded replays its "changed" effect.** The quest hydrator sets `Quest_<id>_Completions` after the client read 0, which showed a QUEST COMPLETE toast on rejoin; `QuestService.hydrate` now sets the player attribute `QuestsRestored` last and `QuestFeedbackController` treats earlier changes as a seed ([[Streaming and Replication Traps]]).
- A client whose profile never restores never sees `QuestsRestored`, so it never celebrates a turn-in; this cannot happen while a failed load kicks the player.
- The quest save tests ran on the mock store only (2026-11-15).
- **Quest restore prunes the save (2026-11-18).** `QuestService.hydrate` writes `QuestConfig.restore`'s result back to `profile.Data.quests` and `questCompletions`, then builds the session state from a second `restore` of the cleaned save (`restore` is pure, idempotent, returns new tables, so the session never shares a table with the save). `Schema` is untouched. Spec first: RED 20 run, 19 passed, 1 failed (`restoring quests prunes what restore drops or clamps from the saved table`), then green in the full run.
- The Police kill case needs a real player in a Play (it fails fast with a clear message otherwise) and mutates that session: it binds a throwaway mock profile, fires `Blaster.Events.Eliminated` with a Faction = Police victim, then puts the player's own profile back; the kill also reaches the other `Eliminated` listeners (Pistol-tier XP, +5 Spraypaint, a kill toast) and the real in-session `PoliceKills` stays +1 per run. Both new characterization cases were shown to fail with a mutant clone (Police to Criminal, hydrator call removed): 20 run, 18 passed, 2 failed.
- "Rejoin-bonus fix may drop one legitimate level-up award during a slow load" is not real: everything earned before the bind is overwritten by the hydrators right before it, and no level-up can land between the hydrators and the bind (no yield). The real loss is the unbound window's whole progress, by design ([[Spraypaint]]).
- Comments fixed 2026-11-18: the `LevelingService` header and `ReplicatedStorage.Stats.Constants` both said "Session-only"; level and XP are saved through `ProfileGateway`.

## History
- 2026-11-20: the cloud place "Crimelife Tycoon" has Studio API access off, so the server logs `DataStoreService: StudioAccessToApisNotAllowed` at boot (ProfileStore `____PS`, SetAsync) in every Play. A developer setting, not a code fault; see [[Open Items]]. [[2026-11-20 Admin Animations Third Person]]
- 2026-11-18: `CashService.hydrate` merges a pre-bind credit through `PreBindBase`; two `ProfileAdoption_Test` cases. [[2026-11-18 Open Items Pass]]
- 2026-11-18: quest restore prunes the saved tables; a Police kill is pinned as counted, saved and restored; the hydrator pin in `ProfileAdoption_Test`; the real kick text recorded in full (it already asked to rejoin); stale "Session-only" comments corrected. City suite 282 / 282 after Task 4, 288 / 288 after its fix round. [[2026-11-18 Open Items Pass]]
- 2026-11-15 (city): quest progress saved: `quests` and `questCompletions` in the template (no version bump), `QuestConfig.restore`, `QuestService` hydrator and saves after accept, each counted kill and turn-in; 171 / 171 tests on the mock store. [[2026-11-15 FPS Hardening In City]]
- 2026-09-24: Spraypaint back to one balance; `VERSION` 2 -> 3, v2->v3 step sums per-weapon balances and `spraypaintShared`; 145/145 tests. [[Revert-Global-Spraypaint-Balance]]
- 2026-09-24: per-weapon Spraypaint; `VERSION` 1 -> 2, v1->v2 step moves the scalar into `spraypaintShared`; 161/161. [[Per-Weapon-Spraypaint]]
- 2026-09-23: Phase 3, ProfileStore persistence for seven services; 11 of 13 verification rows on the mock, 137/137 tests; real restart durability, cross-server locking and the load-abandonment policy deferred. [[FPS-Persistence-Phase-3]]
- 2026-09-23: Spraypaint Phase 2 shipped session-only with the schema written down for later. [[FPS-Spraypaint-Phase-2]]
- 2026-09-15: weapon ownership tracked server-side and restored on every spawn (still session-only). [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]]
- 2026-09-11: leveling added session-only, matching cash. [[FPS-Kill-Leveling-System]]

See [[Batch Log]].
