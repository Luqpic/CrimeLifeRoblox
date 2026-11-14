---
type: system
tags: [system, persistence, datastore, saves]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Per-Weapon-Spraypaint.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Revert-Global-Spraypaint-Balance.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md", "CrimeLifeRoblox/.superpowers/sdd/2026-09-23-persistence-phase-3/progress.md", "CrimeLifeRoblox/FPSSystem/Persistence/Schema.luau", "CrimeLifeRoblox/FPSSystem/Persistence/ProfileGateway.luau"]
---

# Persistence and Saves

**Skills:** `roblox-data-stores`, `roblox-security`, `roblox-testing` (load these for work here)

## What it does
Saves each player's progression across sessions with ProfileStore: Spraypaint, owned and equipped skins, cash, level and XP, owned weapons and loadout slots, upgrade levels, and per-faction kill counts. Built in Phase 3 on 2026-09-23. Before that every one of these reset on rejoin. `CLAUDE.md`'s "progression is session-only, no persistence layer" predates this phase and is stale.

Not saved: quest state (per-quest completions such as `Quest_Level1Thugs_Completions` have no schema field) and gamepasses (no schema field; the spec left the `Vip` pass id to a later phase).

## Where it lives
- `ReplicatedStorage.Persistence.Schema`: `VERSION` (3 as of 2026-09-24), `template`, `DERIVED`. Mirror `CrimeLifeRoblox/FPSSystem/Persistence/Schema.luau`.
- `ServerScriptService.Persistence.Scripts.ProfileGateway`: the only module that requires ProfileStore. `mirror`, `registerHydrator` / `registerPostHydrator`, `keyFor`, `migrate`, `loadForKey`, `get`, `start`, `useMockStore` (Studio only). Store name `PlayerProfiles`.
- `ServerScriptService.Persistence.Scripts.PersistenceRunner`: sole caller of `ProfileGateway.start()`.
- `ServerStorage.ProfileStore`: vendored unedited, `MadStudioRoblox/ProfileStore` `main` at commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd`; repo mirror sha256 recorded in [[FPS-Persistence-Phase-3]].
- Tests: `ServerStorage.UnitTest.Cases.Schema_Test`, `ProfileGateway_Test`, `ProfileAdoption_Test`.
- Adopting services: `SpraypaintService`, `CosmeticsService`, `CashService`, `LevelingService`, `WeaponShopService`, `WeaponUpgradeService`, `KillStatsService`.

## How it works
- Template: `spraypaint = 0`, `skinsOwned`, `equippedSkin`, `cash = 500` (`CashService.STARTING_CASH` reads it), `level = 1`, `xp = 0`, `kills` (`CriminalKills` / `PoliceKills`), `weaponsOwned`, `weaponUpgrades` (the LEVEL), `loadout`. A new player is seeded with the Crowbar in slot 1.
- `DERIVED = { NextLevelXP, SkinId, damage, catalogue, lastLevel }`: never written; recomputed on load (damage = stock + level x `DAMAGE_PER_LEVEL`).
- Join: `loadForKey` tries 3 times, 2 s apart; `StartSessionAsync` and `migrate` are both pcalled, a throw counts as a failed attempt. A failed load returns `nil` and the player is kicked ("Your saved data could not be loaded, so nothing has been changed."). A profile that failed to load is never written.
- Hydrators run strictly before the profile is bound (`get()` is `nil`, `mirror` no-ops), so a reward earned mid-restore is lost rather than saved from half-restored state. Post-hydrators run after every hydrator (Cosmetics re-dresses held Tools; Spraypaint re-seeds its level baseline). Late registrations run against already-bound players.
- `mirror(player, apply)` passes the **profile**: writes are `profile.Data.field = value`. `CashService` covers every cash writer with one `leaderstats.Cash` change listener.
- `migrate` stamps a missing `version` as 1, steps v1->v2->v3 with sequential `if`s, strips only `DERIVED` names (unknown fields from a newer schema are kept), then asserts `version == Schema.VERSION`: an unmigrated version fails closed and kicks.
- Loadout slot keys are written as strings and read through `tonumber`.
- `UpgradeRequest` refuses weapons the player does not own (`WeaponOwned_*`), added because persistence made that exploit permanent.

## Extend it
1. Add the field to `Schema.template` (no version bump: `Reconcile` fills it).
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
- Gamepass ownership and quest progress are not in the profile.

## History
- 2026-09-24: Spraypaint back to one balance; `VERSION` 2 -> 3, v2->v3 step sums per-weapon balances and `spraypaintShared`; 145/145 tests. [[Revert-Global-Spraypaint-Balance]]
- 2026-09-24: per-weapon Spraypaint; `VERSION` 1 -> 2, v1->v2 step moves the scalar into `spraypaintShared`; 161/161. [[Per-Weapon-Spraypaint]]
- 2026-09-23: Phase 3, ProfileStore persistence for seven services; 11 of 13 verification rows on the mock, 137/137 tests; real restart durability, cross-server locking and the load-abandonment policy deferred. [[FPS-Persistence-Phase-3]]
- 2026-09-23: Spraypaint Phase 2 shipped session-only with the schema written down for later. [[FPS-Spraypaint-Phase-2]]
- 2026-09-15: weapon ownership tracked server-side and restored on every spawn (still session-only). [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]]
- 2026-09-11: leveling added session-only, matching cash. [[FPS-Kill-Leveling-System]]

See [[Batch Log]].
