# Persistence — Phase 3 Design

## Why this document exists

Phases 1 and 2 shipped weapon skins and the Spraypaint currency, both deliberately session-only. Every
owning service carries a comment saying so. That was the right call while the mechanics were being
proven; it is the wrong one now, because a player who earns a skin and loses it at logout learns not to
bother earning the next one.

Phase 3 makes progression survive. It is the first phase in this project whose failure mode is
**permanent data loss** rather than a wrong colour or a number that resets anyway, so it is designed
around that risk rather than around the feature.

---

## What the live place has, measured on 2026-09-23

- **The place is not published.** `PlaceId = 0`, `GameId = 0`, and `DataStoreService:GetDataStore`
  fails with *"You must publish this place to the web to access DataStore."*
- **Zero persistence exists.** No `DataStoreService` call anywhere. Three modules carry comments
  documenting session-only as deliberate.
- **Every state write site is enumerated** in the adoption table below — 52 writes across seven
  services, of which the ones that matter are identified individually.
- The `Vip` game pass id is still unconfigured, for the same reason the DataStore is unreachable.

### The blocker, and why it does not block this phase

ProfileStore probes DataStore access at load with a `pcall` around
`DataStoreService:GetDataStore("____PS"):SetAsync(...)`. On a "must publish" or 403 failure it sets
`DataStoreState = "NoAccess"` and substitutes an in-memory `MockStore`, and it exposes an explicit
`.Mock` API besides. It also registers `game:BindToClose` itself and releases every active profile on
shutdown.

So the whole of this phase — hydration, mirroring, the kick path, migration, session handling — can be
built and tested now against the mock store. Two things genuinely cannot, and are deferred and marked
rather than faked:

1. **Durability across a real restart.** The mock store dies with the Studio session.
2. **True cross-server session locking.** One Studio server cannot contend with another.

---

## Decisions taken

1. **Use ProfileStore rather than write a session-locked store.** Session locking fails in ways that
   are silent and unrecoverable: a crashed server leaving a lock nobody clears, two servers both
   believing they own a profile, a release that misses `BindToClose`'s 30-second budget. ProfileStore
   resolves conflicts through MessagingService force-load with backoff and steals a stale session after
   40 seconds. Inheriting that is better than re-deriving it.
2. **A profile that failed to load is never written.** On failure: retry, then remove the player with
   an explanatory message. Handing a player a blank profile and later saving it is how an account is
   wiped, and it looks like a normal session right up until the save lands.
3. **Services keep their current shape.** Each hydrates on join and mirrors on change. They are
   working, reviewed code, and a rewrite of six services is a larger risk than two added call sites in
   each.
4. **ProfileStore's API lives in exactly one module.** Services never see it.

---

## Architecture

### `ProfileGateway` — the only module that knows ProfileStore exists

| Path | Responsibility |
|---|---|
| `ServerScriptService.Persistence.Scripts.ProfileGateway` (ModuleScript) | Session lifecycle, retry-then-kick, the never-save-unloaded rule |
| `ServerScriptService.Persistence.Scripts.PersistenceRunner` (Script) | Requires the gateway so its player hooks connect |
| `ReplicatedStorage.Persistence.Schema` (ModuleScript) | The profile template and `version`; shared so tests can read it |
| `ServerStorage.ProfileStore` | The vendored third-party module |

Public surface, deliberately small:

```
ProfileGateway.waitFor(player): Profile?     -- yields until loaded; nil if the player left or load failed
ProfileGateway.get(player): Profile?         -- non-yielding; nil if not loaded
ProfileGateway.isLoaded(player): boolean
```

A `Profile` here is ProfileStore's object; services touch only `profile.Data`.

### Adoption — every mirror point, named

Each service gains exactly two responsibilities: **hydrate** on join, **mirror** on change. The live
in-memory value or attribute stays the source of truth during a session, because that is what the rest
of the game already reads.

| Service | Field | Hydrate | Mirror at |
|---|---|---|---|
| `CashService` | `cash` | `leaderstats.Cash.Value` on join | `CashService:54` (init), `:171` (`+=`) |
| `LevelingService` | `level`, `xp` | `Level`/`XP` attributes and `levelValue.Value` | `:43-49` (set level), `:134-155` (grant XP) |
| `KillStatsService` | `kills` | `counts[player]`, then publish | `:70` (increment) |
| `WeaponShopService` | `weaponsOwned`, `loadout` | `ownedWeapons[player]`, `equippedSlots[player]`, then `publishSlots` | `:151-153` (seed), `:208-209` (buy), `:254`, `:265`, `:276` (slot change) |
| `WeaponUpgradeService` | `weaponUpgrades` | per-weapon upgrade attributes | `:71` |
| `SpraypaintService` | `spraypaint`, `skinsOwned` | `Spraypaint` attribute, `SkinOwned_*` | `:48`, `:60`, `:168` (balance), `:131` (purchase) |
| `CosmeticsService` | `equippedSkin` | `EquippedSkin_*` attributes | `:97` |

### What must NOT persist

Derived values, because a persisted derivative outlives the thing it was derived from and then
disagrees with it:

- `NextLevelXP` — computed from `level` by `LevelingConstants.xpToNextLevel`.
- A Tool's `SkinId` — stamped per grant by `WeaponShopService.grantWeapon`.
- A weapon's damage attribute — computed from its upgrade level at grant time.
- The catalogue entry attributes built at server start.
- `lastLevel` in `SpraypaintService` — a per-session baseline for the join guard, meaningless across
  sessions.

### The schema

```
Profile = {
    version        = 1,
    spraypaint     = 0,
    skinsOwned     = {},   -- [paletteKey] = true
    equippedSkin   = {},   -- [weaponName] = paletteKey
    cash           = 0,
    level          = 1,
    xp             = 0,
    kills          = {},   -- { Criminal = n, Police = n }
    weaponsOwned   = {},   -- [weaponName] = true
    weaponUpgrades = {},   -- [weaponName] = level
    loadout        = {},   -- [slotIndex] = weaponName
}
```

`version` exists so that changing a field's MEANING later is a migration rather than a silent
misreading. A migration runs once on load, bumps the version, and is tested against a fixture of the
old shape.

---

## Failure handling

**Load fails.** Retry with backoff. If it still fails, `player:Kick` with a message saying their data
could not be loaded and to rejoin. Nothing is written. This is the single most important rule in the
phase and it gets its own test.

**Session already held by another server.** ProfileStore's own resolution applies: force-load request,
backoff, steal after 40 seconds. Nothing for this design to add.

**Player leaves.** `Profile:EndSession()`. ProfileStore saves and releases.

**Server shuts down.** ProfileStore's own `BindToClose` releases every active profile. This design adds
no second shutdown path, because two competing shutdown handlers is how a release gets missed.

**A mirror throws.** Each mirror site is guarded so a persistence failure degrades to "this change was
not saved" rather than breaking the gameplay path it sits in — the same rule Phase 1 and 2 applied to
every cosmetics call site, for the same reason.

---

## Testing

**Against the mock store, now:** hydration per service, every mirror point, the retry-then-kick path,
the never-save-unloaded rule, migration from a v0 fixture, and that derived fields are absent from what
is written.

The existing in-place framework at `ServerStorage.UnitTest` is the harness, matching Phases 1 and 2.
`ProfileStore.Mock` gives each test an isolated store.

**Only after publishing:** durability across a genuine restart, and cross-server session contention.
Both are named in the verification table as deferred, not as passing.

---

## Verification

| Claim | Measured how |
|---|---|
| A new player gets the template | Fresh key; every field matches the schema's defaults |
| Earned Spraypaint survives a rejoin | Earn, leave, rejoin; balance matches |
| A bought skin survives a rejoin | Buy, leave, rejoin; `SkinOwned_*` still true and equipped |
| Cash survives a rejoin | Earn, leave, rejoin; `leaderstats.Cash` matches |
| Level and XP survive | Gain XP across a level, rejoin; both match |
| Weapons and loadout survive | Buy, equip into slots, rejoin; slots identical |
| Upgrades survive | Upgrade, rejoin; damage attribute recomputes to the same figure |
| Kills survive | Kill, rejoin; both faction counters match |
| A failed load never saves | Force a load failure; the stored profile is byte-identical afterwards |
| A failed load kicks | Force a failure; the player is removed with the message |
| Derived fields are not stored | Inspect a saved profile; `NextLevelXP`, `SkinId`, damage absent |
| Migration from v0 | Load a v0 fixture; fields map, version becomes 1, nothing lost |
| Phases 1 and 2 still pass | All six existing suites unchanged: 8, 21, 8, 10, 14, 11 |
| **Durability across a restart** | **DEFERRED — needs a published place** |
| **Cross-server session locking** | **DEFERRED — needs two live servers** |

---

## Phase boundaries

- **Phase 1 (shipped).** Weapon skins.
- **Phase 2 (shipped).** Spraypaint currency, earn path, Renown tier, buy strip.
- **Phase 3 (this document).** Persistence for full progression, built and tested against the mock
  store. Stop and report before the deferred rows are attempted.
- **Phase 4.** Whatever the deferred rows demand once the place is published, plus the `Vip` pass id.
- **Phase 5.** Crates. Optional, highest reputational risk, may never be worth it.

## Non-goals for Phase 3

- No trading, no cross-place data, no offline profile editing.
- No Robux→Spraypaint product. It competes with the earn path and should be a deliberate decision, not
  a drift.
- No leaderboards or global stores.
- No change to what any service DOES — only where its state comes from and goes to.
- Robbery System is not touched.

## Open items

- **Every assumption here about real DataStore behaviour is untested**, because the place is
  unpublished. The mock store exercises the logic, not the network. Latency, throttling, partial
  failures and `UpdateAsync` conflicts are unobserved, and the implementation plan must treat the first
  live run as a verification step in its own right.
- ProfileStore is vendored rather than packaged, since this place has no dependency manager. Its
  version should be recorded in the change log so an upgrade is a deliberate act.
- Whether a kicked player should see a generic message or a specific one is a product decision; the
  design assumes specific, on the grounds that "try rejoining" is actionable and "an error occurred" is
  not.
