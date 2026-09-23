# Change Log: Persistence, Phase 3

**Date:** 2026-09-23
**Place:** `FPS System.rbxl` · Follows `FPS-Spraypaint-Phase-2.md`

**Status:** Eleven of the thirteen verification rows confirmed live in `FPS System.rbxl` with real
before/after numbers, and **every one of them against ProfileStore's Studio mock store, not a real
DataStore** — this place is unpublished, so `ProfileStore.DataStoreState` settles to `"NoAccess"` and
the whole phase has been proven against an in-memory fake. Three rows are **DEFERRED** and cannot be
measured here at all: durability across a real server restart, cross-server session locking, and the
entire load-abandonment policy — the 30s `LOAD_DEADLINE` and the departing-player cancel — which the
mock's own proxy makes unreachable (Note 12). One row (a failed load kicks) is confirmed only in half.
Row-by-row detail, and a defect this pass found and closed in `loadForKey`, are below. The mock
exercises the logic, not the network: latency, throttling and `UpdateAsync` conflicts remain entirely
unobserved.

**Amended after a whole-branch review.** Per-task review passed all seven tasks; reading the branch as
one diff afterwards found one Critical and three Majors that no single task's diff could have shown.
All four are fixed and mutation-tested (Notes 9-12) and the suite is now **135/135 across 12 suites**
in a real server VM. The most instructive of the four: **row 2's own measurement was the Critical, and
this document wrote it down as the feature.** Corrected in place below.

## Summary

Phase 3 makes progression durable. A single gateway — `ServerScriptService.Persistence.Scripts.ProfileGateway`,
the only module in the place that knows ProfileStore exists — owns the session lifecycle, and seven
services mirror their state into a profile through it: Spraypaint balance and owned skins
(`SpraypaintService`), equipped skins (`CosmeticsService`), cash (`CashService`), level and XP
(`LevelingService`), weapon ownership and the four loadout slots (`WeaponShopService`), upgrade levels
(`WeaponUpgradeService`) and per-faction kill counts (`KillStatsService`). The stored shape is declared
once in `ReplicatedStorage.Persistence.Schema`, which also names the five values that are DERIVED and
must never be written. A `migrate` step runs between `Reconcile` and the bind, and fails closed.

This log is the phase close-out: no new feature code, only measurement — plus the one guard that
measurement turned up (Notes 7), which is a hole closed rather than behaviour added.

The headline numbers, all from one continuous Play session, all changes driven through the game's own
entry points:

```
cash        500 -> 300 -> 250 -> 150     BuyRequest(AK47 200), UpgradeRequest x2 (50 + 100)
spraypaint  0 -> 2 -> 277 -> 27 -> 29    1 real kill, SetLevelRequest(12), BuySkinRequest(Cobalt 250), 1 kill
                                         the 2 -> 277 step is the Critical, not a feature -- row 2, Note 9
level/xp    1/0 -> 12/15                 SetLevelRequest(12) + a real kill (15 XP)
loadout     {"1"="Crowbar","3"="AK47"}   BuyRequest + SetLoadoutSlotRequest(AK47, slot 3)
upgrades    {Crowbar=2}                  UpgradeRequest x2, held damage 45 -> 55
kills       {CriminalKills=2}            1 real kill + 1 harness-fired Eliminated

end session, load the key again:         226 chars in, 226 chars out, byte-identical
```

## Cause

Nothing persisted before this phase. Cash, level, XP, kill counts, weapon ownership, loadout slots,
upgrade levels, Spraypaint and skins were all session-only by design, and every one of them reset on
rejoin. Phase 1 and Phase 2 both shipped with that stated plainly in their own logs ("Session-only,
matching Cash, Leveling and the kill counters"). The economy had grown past the point where that was
tenable: a player could spend an hour earning a 750-Spraypaint palette and lose it by closing the
window.

The design constraint that shaped everything: **a profile that failed to load must never be written.**
Everything else in this phase is recoverable; that one is not. Handing a player a blank profile after a
failed load and later saving it looks exactly like a normal session right up to the moment the save
lands and wipes the account. So `loadForKey` returns `nil` rather than a default, `mirror` is a no-op
for any player with no bound profile, and `onPlayerAdded` kicks on `nil` with a message that says
nothing has been changed.

The second constraint is ordering, and it had to become its own phase rather than a convention.
Hydrators run **strictly before** the profile is bound, so `get()` stays `nil` for the
whole restore loop and a reward earned in that window is dropped rather than written from half-restored
state. Losing one kill's reward is recoverable; overwriting a real balance with a partial one is not.
Post-hydrators then run after *every* hydrator, because re-dressing a restored Tool needs both the
equipped skin and the ownership attributes that decide whether that skin is allowed — a dependency
across two services that hand-ordering would have kept correct only until the next `require` was added.

## Changes

All fourteen files below were re-read live from Studio this pass and compared against this repo's
mirrors under `FPSSystem/` — **all fourteen are byte-exact**, so the mirror is not stale relative to
the shipped Studio state at the moment this log was written. The final fix round changed four of them
(`ProfileGateway`, `SpraypaintService`, `ProfileGateway_Test`, `ProfileAdoption_Test`) and each was
re-verified byte-exact against Studio afterwards, by length and by a rolling hash of the full source,
not by trusting the edit report. The byte sizes below are the post-fix sizes.

New:

- `ReplicatedStorage.Persistence.Schema` (ModuleScript, 2292 bytes) — `VERSION = 1`, the ten-field
  `template` (`spraypaint`, `skinsOwned`, `equippedSkin`, `cash = 500`, `level = 1`, `xp`, `kills`,
  `weaponsOwned`, `weaponUpgrades`, `loadout`) and
  `DERIVED = { "NextLevelXP", "SkinId", "damage", "catalogue", "lastLevel" }`. `CashService.STARTING_CASH`
  reads `Schema.template.cash` directly rather than holding its own copy, so the two cannot drift.
- `ServerScriptService.Persistence.Scripts.ProfileGateway` (ModuleScript, 13422 bytes) — `useMockStore`,
  `mirror`, `registerHydrator` / `registerPostHydrator`, `keyFor`, `migrate`, `loadForKey`, `get`,
  `start`. Three load attempts, 2s between them, a kick on failure, and a 30s deadline on the join path
  that **has never executed** (Note 12). `isLoaded` and `waitFor` were published in the design and are
  **gone**: `waitFor` had zero callers repo-wide and `isLoaded` had exactly one, inside a test, so the
  module was advertising a yielding API nothing consumed. `registerHydrator` and `registerPostHydrator`
  now also run the newly-registered function for every already-bound player, which closes the
  late-registration hole at the class rather than per service (Note 10). `loadForKey`'s
  `StartSessionAsync` call is wrapped in a `pcall`: it makes the
  only network round trip in that function and it *throws* on a key already loaded in this server, which
  unguarded escaped both `loadForKey` and `onPlayerAdded` and skipped the kick (Notes 7). A throw is now
  a failed attempt, so the existing retry loop owns it and an exhausted retry returns `nil` into the kick
  path.
- `ServerScriptService.Persistence.Scripts.PersistenceRunner` (Script, 181 bytes) — the sole caller of
  `ProfileGateway.start()`; requiring the module alone connects nothing.
- `ServerStorage.ProfileStore` (ModuleScript, 64654 bytes) — vendored unedited from
  `MadStudioRoblox/ProfileStore`, `main` at commit **`45c9847cbcf1fc260369c50eb335aba7c35aecdd`**
  ("Merge pull request #14 … fix incorrect type from player to Player", 2025-07-31), fetched 2026-09-23.
  The file carries no version string of its own, so the commit is the version. Repo mirror sha256
  `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`.
- `ServerStorage.UnitTest.Cases.Schema_Test` (3280 bytes, 8 cases),
  `ProfileGateway_Test` (9677 bytes, 15 cases), `ProfileAdoption_Test` (14478 bytes, 14 cases).

Modified — the seven adopting services:

- `SpraypaintService` (12244 bytes) — hydrator **and**, since the fix round, a post-hydrator that
  re-seeds the level baseline from the restored `Level` (Note 9); mirrors on grant, spend, buy and
  buy-with-auto-equip. Its `safePlayerAdded` fallback no longer mirrors its own default (Note 10).
- `CosmeticsService` (7185 bytes) — hydrator **and** the phase's only post-hydrator (re-dresses held Tools).
- `CashService` (10845 bytes) — hydrator; one `GetPropertyChangedSignal("Value")` listener on
  `leaderstats.Cash` covers every writer of that shared IntValue (pickup, level-up bonus, shop, upgrades,
  quest rewards, monetization) without touching five other files.
- `LevelingService` (10100 bytes) — hydrator; mirrors from `grantXp` and from the admin `SetLevelRequest`.
  Recomputes `NextLevelXP` from the restored level; never reads it from the profile.
- `WeaponShopService` (17259 bytes) — hydrator (not a post-hydrator: the Tools must exist before
  `CosmeticsService`'s post-hydrator re-dresses them); mirrors ownership and the whole slot table on
  every purchase and every slot change.
- `WeaponUpgradeService` (5822 bytes) — hydrator; mirrors the upgrade LEVEL only, and re-applies the
  implied damage to weapons already in hand so hydrator order cannot matter. Also gained an ownership
  guard on `UpgradeRequest` (see Notes 6).
- `KillStatsService` (4130 bytes) — hydrator; mirrors the kill table after the live credit.

## Verification

Method. Every round-trip row **originated its change through the game's own path** — a remote fired
from the Client datamodel, or a real kill — and was then read back by ending the session and loading
the key again. Reads are through a temporary `Script` in `ServerScriptService` (deleted afterwards;
confirmed gone), because `execute_luau` runs in a plugin VM with its own `require` cache and can never
observe the real server's bound profile, even with `datamodel_type: "Server"` during Play.

A direct `profile.Data.cash = 500` would have proven only that ProfileStore saves a table. It would
have passed cleanly through the entire period when `CashService`'s mirror was writing to a field that
is never serialised (Notes 1), because it never exercises the mirror at all.

| # | Row | Result | Measured |
|---|---|---|---|
| 1 | A new player gets the template | **PASS** (mock) | Bound profile at join: `cash=500 level=1 xp=0 spraypaint=0 kills={} skinsOwned={} equippedSkin={} weaponUpgrades={}`, plus the two deliberate deltas from the raw template — `weaponsOwned={Crowbar=true}`, `loadout={"1"="Crowbar"}` (the starting-weapon seed, recorded by `hydrate` straight into `profile.Data`) and `version=1` (stamped by `migrate`). Live: `cash 500, level 1, XP 0, NextLevelXP 30, Spraypaint 0, LoadoutSlot1=Crowbar, CriminalKills 0, PoliceKills 0`. |
| 2 | Earned Spraypaint survives a rejoin | **PASS** (mock) for the STORED value only — **corrected**, see below | `0 → 2` from **one real kill** (client `Blaster.Remotes.Shoot` → `ShotResolver` → Crowbar 55 dmg → Criminal rig 20.8 → 0.0 HP → `Eliminated`, Criminal rate +2); `2 → 277` from `SetLevelRequest(12)`, 11 levels × 25; `277 → 27` buying Cobalt (250); `27 → 29` from one further kill. Round trip `29 → 29` in `profile.Data`. **The `2 → 277` step was written down here as an intended pass. It is the Critical.** In that one session the jump was legitimate — the admin call really did cross eleven levels — but the identical `(12 − 1) × 25` fires again on every **rejoin**, because `lastLevel` is seeded before the gateway's yielding load resolves and hydration's `SetAttribute("Level", 12)` then reads as an eleven-level level-up. A real rejoin of this player would have restored 29 and immediately paid 275 on top of it, landing on 304 live while `profile.Data` still read 29 — and the next grant or spend would have mirrored 304 back. Fixed and mutation-tested in Note 9. |
| 3 | A bought skin survives a rejoin | **PASS** (mock) | `BuySkinRequest("Cobalt","Crowbar")` fired from the client → `skinsOwned={Cobalt=true}`, `equippedSkin={Crowbar="Cobalt"}`. Identical after reload. Deployed hydrators re-run against the reloaded profile set `SkinOwned_Cobalt=true`, `EquippedSkin_Crowbar=Cobalt`, and the restored Crowbar Tool came back carrying `SkinId=Cobalt`. |
| 4 | Cash survives a rejoin | **PASS** (mock) | `500 → 300` (`BuyRequest` AK47, price 200) `→ 250` (`UpgradeRequest` L1, 50) `→ 150` (L2, 100). Round trip `150 → 150`; hydration replay put `leaderstats.Cash = 150`. |
| 5 | Level and XP survive | **PASS** (mock) | `level 1 → 12` via `SetLevelRequest` (server-gated on UserId 58662576); `xp 0 → 15` from the real kill. Round trip `12/15 → 12/15`; hydration replay restored `Level=12, XP=15` and recomputed `NextLevelXP=195` rather than reading it. |
| 6 | Weapons and loadout survive | **PASS** (mock) | `weaponsOwned={AK47=true,Crowbar=true}`, `loadout={"1"="Crowbar","3"="AK47"}` — deliberately non-contiguous, with slot 2 empty, which is the exact shape that dies in JSON when the keys are integers (Notes 2). Reload identical; key types read back as `1:string, 3:string`. Hydration replay: `LoadoutSlot1=Crowbar, LoadoutSlot2=(empty), LoadoutSlot3=AK47, LoadoutSlot4=(empty)`, Backpack rebuilt with both Tools. |
| 7 | Upgrades survive, damage recomputes to the same figure | **PASS** (mock) | `weaponUpgrades={Crowbar=2}`; live held Crowbar `damage=55` before the round trip. After reload plus the deployed hydrators, the restored Crowbar Tool carried `damage=55` — recomputed as stock 45 + 2 × `DAMAGE_PER_LEVEL` 5, not read from storage. The AK47, never upgraded, came back at stock `damage=10`. |
| 8 | Kills survive | **PASS** (mock), one faction only | `kills={CriminalKills=2}` — one real kill plus one harness-fired `Eliminated`. Round trip identical; hydration replay `CriminalKills=2`. **`PoliceKills` stayed 0 the whole session**: no live Police rig was reachable when the harness fired, so the Police bucket is unexercised. |
| 9 | A failed load never saves — the stored profile is byte-identical afterwards | **PASS** (mock) | Scratch key seeded with `spraypaint=999, cash=4242, loadout={"1"="Crowbar","3"="AK47"}`, ended, reloaded, canonicalised: 153 chars. `_forceNextLoadFailure(true)` → `loadForKey` returned `nil` after **4.02s** (3 attempts × 2s). Reload afterwards canonicalised to the same 153 chars, string-equal. **Narrower than it reads:** `_forceNextLoadFailure` short-circuits *before* `StartSessionAsync`, so this row proves the retry-and-give-up loop and the never-write rule and never reaches ProfileStore at all. The 4.02s is `LOAD_ATTEMPTS × RETRY_DELAY` and nothing else. See Note 12. |
| 10 | A failed load kicks | **HALF** | The `nil` half is measured (row 9). The kick half is **not** provoked by a failed load: `PlayerAdded` fires once and Studio Play Solo admits no second join, so there is no way to force a join to fail. What *was* observed live on a real `Player`: `profile:EndSession()` fired `OnSessionEnd`, whose handler kicked the player, and the Play Solo session terminated on its own. So the `Kick` path on a real Player is exercised; the failed-**load** kick is read, not run. |
| 11 | Derived fields are not stored | **PASS** (mock) | None of `NextLevelXP`, `SkinId`, `damage`, `catalogue`, `lastLevel` present in `profile.Data`, before or after the round trip, while all of them were live at that moment: `NextLevelXP=195`, Crowbar `damage=55`, Crowbar `SkinId=Cobalt`, catalogue 29 entries in `ReplicatedStorage.Weapons.Catalog`. |
| 12 | Migration from a v0 fixture | **PASS** (mock) | Fixture written to a scratch key: `version=nil`, `spraypaint=77`, `cash=123`, `NextLevelXP=999` (a leaked derived value), `fieldFromANewerSchema="keep me"`. After a real store round trip: `version=1`, `NextLevelXP` gone, `spraypaint=77`, `cash=123`, `fieldFromANewerSchema="keep me"` untouched. Console: `[Persistence] migrated profile <key> to version 1`. |
| 13 | Phases 1 and 2 still pass | **PASS** | **135/135 across 12 suites**, run in a real server VM (133/133 before the fix round below added two cases). Table below. |
| — | Durability across a real server restart | **DEFERRED** | Unmeasurable on an unpublished place. `DataStoreState = "NoAccess"`, so the "store" is an in-memory table inside the server VM and it is destroyed with the playtest. There is no restart that a profile can survive here, by construction. |
| — | Cross-server session locking | **DEFERRED** | Unmeasurable on an unpublished place. Needs two live servers holding one key. The same-server case is observable (see Notes 7) and is a different mechanism. |
| — | The load-abandonment policy — the 30s `LOAD_DEADLINE` and the departing-player cancel | **DEFERRED** | **Never executed, not once.** ProfileStore's `Mock` proxy is `StartSessionAsync = function(_, profile_key) MockFlag = true; return self:StartSessionAsync(profile_key) end` — it **drops the `params` argument**, so the `{ Cancel = cancel }` the gateway passes never arrives, `params.Cancel` is `nil` inside ProfileStore for every mock run, and ProfileStore's own `START_SESSION_TIMEOUT` is back in charge. Every measurement this place has ever taken is a mock run, so the gateway's whole abandonment policy is unexercised code. Row 9 does not reach it either: `_forceNextLoadFailure` never calls `StartSessionAsync`. **Deliberately not worked around** — the vendored file is pinned to an upstream commit with a recorded sha256, and that guarantee is worth more than reaching this branch. See Note 12. |

### The twelve suites

| Suite | Cases | Phase |
|---|---|---|
| `PropertyAuthority_Test` | 8/8 | pre-existing (movement/authority) |
| `validateRunningState_Test` | 8/8 | pre-existing (movement/authority) |
| `staminaStep_Test` | 10/10 | pre-existing (movement/authority) |
| `Palettes_Test` | 10/10 | Phase 1 |
| `SkinApplier_Test` | 14/14 | Phase 1 |
| `CosmeticsOwnership_Test` | 11/11 | Phase 1 |
| `SpraypaintConstants_Test` | 8/8 | Phase 2 |
| `SpraypaintService_Test` | 21/21 | Phase 2 |
| `SpraypaintTier_Test` | 8/8 | Phase 2 |
| `Schema_Test` | 8/8 | Phase 3 |
| `ProfileGateway_Test` | 15/15 | Phase 3 |
| `ProfileAdoption_Test` | 14/14 | Phase 3 |
| **Total** | **135/135** | |

The six Phase 1 and Phase 2 suites are unchanged at 8, 21, 8, 10, 14, 11 = **72**; Phase 3 adds
8 + 15 + 14 = **37**; the three pre-existing movement/authority suites contribute 8 + 8 + 10 = **26**.
Phase 3 took the total from 98 to 135 and `ProfileGateway_Test` from 7 cases to 15. The final fix round
added the two `ProfileAdoption_Test` cases (12 → 14) and rewrote one `ProfileGateway_Test` case rather
than adding one, so that suite's count is unchanged at 15 while one of its cases can now fail.

### The damage path is still clean

```
ShotResolver, WeaponUpgradeService source searched for "ProfileStore" -> clean
WeaponUpgradeService references ProfileGateway -> true   (legitimate: it persists the upgrade level)
ShotResolver references ProfileGateway         -> false  (it must not, and does not)
```

### ProfileStore is required in exactly one place

184 `LuaSourceContainer`s scanned across `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer`
and `ServerStorage`. Exactly one real `require` of it:

```
ServerScriptService.Persistence.Scripts.ProfileGateway -> require(ServerStorage.ProfileStore)
```

The spec's literal grep ("source contains `require` AND contains `ProfileStore`") reports six files,
because it matches the word in **comments** — `CashService`, `WeaponShopService` and the three test
suites all discuss ProfileStore in prose. Matching inside `require%s*%b()` instead, and separately
stripping comment lines before searching, both give the same single answer. Recorded here so the next
reader does not re-investigate the same false positive.

## Notes

**1. The `mirror` contract was specified backwards, and two services shipped on it.**
`ProfileGateway.mirror(player, apply)` calls `pcall(apply, profile)` — the callback receives the
**profile**, so a write must be `profile.Data.field = value`. The Task 4 brief described it as
`apply(data)` mutating `profile.Data`. `CashService` and `LevelingService` followed that literally and
wrote `data.cash`, `data.level`, `data.xp` onto stray top-level fields of the ProfileStore profile
object, which is never serialised. The writes succeeded and were silently discarded: **cash, level and
XP persisted nothing at all from Task 4 until it was caught during Task 5.** Measured live at the time:
`profile.Data.cash = 500` while the player held 9525, and `rawget(profile, "cash") = 9525`.

It passed a clean review because the reviewer was handed the same wrong contract and validated the code
against the specification rather than against the source. That is the failure worth remembering — not
the typo, but that a review can only catch what its own premise allows. Task 3's implementer read the
source instead of the brief and was correct throughout.

Three things changed because of it. `mirror`'s signature is now annotated `apply: (profile: any) -> ()`
with the trap spelt out in the comment above it; all twelve call sites use `function(profile)` and
`profile.Data.*`; and `ProfileAdoption_Test` now pins the contract directly — the callback's argument
is asserted to be the profile, a `profile.Data.cash` write is asserted to land, and a top-level write
on the same argument is asserted **not** to. That test should have existed the day the gateway was
written. It is the only assertion in this phase that can reach `CashService` and `LevelingService`'s
behaviour at all, since both are `Script`s and cannot be required.

**2. JSON has no integer keys, and the Studio mock hides it.**
A DataStore serialises through JSON. Measured with `HttpService`, the same encoder:

```
{ [1] = "Crowbar", [3] = "Glock 17" }     -> ["Crowbar"]            slot 3 destroyed outright
{ [2] = "Glock 17" }                       -> {"2":"Glock 17"}       key returns as a string
{ ["1"] = "Crowbar", ["3"] = "Glock 17" }  -> round-trips exactly
```

Two separate failures: a sparse integer-keyed table loses every entry after the first gap, and one that
does not start at 1 comes back string-keyed. A player with weapons in slots 1 and 3 would lose slot 3
permanently on their next join. ProfileStore's Studio mock keeps the table in memory and reproduces
**neither**, so the integer version passes every Studio test and fails only in production.

Fixed by writing slot indices as strings and reading them back through `tonumber`, which accepts both
forms so nothing already saved is stranded. `Schema.template.loadout`'s declared shape
(`[slotIndex] = weaponName`) is unchanged — the index is simply spelt as a string — so this is not a
migration. This pass re-confirmed it end to end: a loadout deliberately left non-contiguous (slot 1 and
slot 3, slot 2 empty) round-tripped with both keys still present and both reading back as `string`.

This is the second live-only failure the mock has hidden. The first was Note 1's never-serialised
field. Both should be read as a warning about every PASS in the table above.

**3. Hydrate before bind, and why ordering needed its own phase.**
Hydrators run inside `onPlayerAdded` strictly before `profiles[player] = profile`. For the whole of
that loop `get()` returns `nil`, so `mirror` is a no-op and a reward earned mid-restore is **lost**
rather than written from un-hydrated state. That asymmetry is deliberate: losing one kill's reward is
recoverable, overwriting a real balance with a partial one is not. `ProfileAdoption_Test` pins it with a
probe hydrator that registers into the same list the real services use and fires mid-loop — the exact
window the bug lived in.

Post-hydrators exist because one dependency crosses services: `CosmeticsService` re-dresses every Tool
the player is carrying, which needs both `EquippedSkin_*` (its own) and `SkinOwned_*` (Spraypaint's),
and needs the Tools themselves to exist (`WeaponShopService`'s). Ordering the hydrators by hand would
have worked until someone added a `require` and silently changed registration order, so the dependency
got its own phase instead of a convention. The same reasoning is why `WeaponShopService` registers as a
plain hydrator and not a post-hydrator: restoring Tools in the hydrator phase means the persisted skin
lands on them for free.

The gateway also yields on a DataStore round trip and therefore usually lands **last**, so every
service's `PlayerAdded` default is guarded on its state not already existing, and every hydrator
creates that state itself if the handler has not run. Both orderings land on restored state because
whichever runs first creates, and `hydrate` always wins by overwriting rather than merging.

**4. The migration fails closed.**
`migrate` stamps `version` when it is absent and strips anything named in `Schema.DERIVED`, then
asserts `data.version == Schema.VERSION`. A future `VERSION` bump with no migration step for the stored
version therefore **throws**; `loadForKey` pcalls it, warns, calls `profile:EndSession()` and returns
`nil` into the kick path `onPlayerAdded` already trusts. Everyone is kicked, loudly, instead of quietly
reading v-old data under a new meaning and saving it back.

Without the assert, `migrate` silently no-opped on exactly the case its own comment says it exists for.
Without the pcall, the throw escaped `loadForKey`, skipped the `profile == nil` kick entirely, and left
the player playing fully unbound with a leaked session lock that would push their next join onto the
contended-retry path. A developer who bumps `VERSION` now finds out on their first Studio test.

That fix was right and incomplete, and the incompleteness is the more useful lesson. It wrapped
`migrate` — pure table logic, which throws only if someone writes an assert into it — and left
`StartSessionAsync`, the one call in `loadForKey` that makes a network round trip, bare. The reasoning
had been "this throw is reachable, so guard it" rather than "an uncaught throw anywhere between
`StartSessionAsync` and the bind bypasses the kick, so guard the whole stretch". We hardened the
instance and not the class, and the dangerous line stayed open for another task. Both calls are wrapped
now.

That last clause originally read "the remaining statements in that window are table reads", and that
was wrong in exactly the way this note is about. `profile:Reconcile()` and `profile:AddUserId(player.UserId)`
are **unwrapped calls into vendored code** in that same window — one in `loadForKey`, one in
`onPlayerAdded` — and calling them table reads is the same "hardened the instance, not the class"
shortcut, committed a second time inside the note warning against it. The conclusion survives, but only
because the vendored source was read: `Reconcile` is one line into `ReconcileTable`, plain recursive
table copying with no `error` anywhere in it, and `AddUserId` `warn`s and returns on a bad argument
rather than throwing. Both verified in `ServerStorage.ProfileStore` at the pinned commit. If that file
is ever re-vendored, this is the sentence to re-check.

`migrate` never destroys a field it does not recognise. An unknown key is likelier to come from a
**newer** schema than to be garbage, so only the five names in `DERIVED` are stripped. Row 12 proves
it: `fieldFromANewerSchema` survived the round trip untouched while `NextLevelXP` was removed.

**5. Three test suites exist live but are absent from this repo.**
`PropertyAuthority_Test` (2974 bytes), `staminaStep_Test` (5305) and `validateRunningState_Test` (4479)
are pre-existing movement/authority suites that run in the place and have never been mirrored into
`FPSSystem/`. The running total was always right; the per-suite tables quoted during this phase summed
to 72 because they silently omitted these three, and the phase repeatedly said "9 suites" when the real
number is 12.

CLAUDE.md designates this repo the source of truth. Three live suites it has no copy of is a real gap
in the archive, not a counting quibble: a rebuild from this repo would come back with 26 fewer cases
and nobody would know. Someone should mirror the three files. **Not done here** — this task ships no
code, and copying three untouched suites into the repo is a change, not a measurement.

**6. Recommended follow-up: audit the other client-facing remotes.**
`UpgradeRequest` shipped with **no ownership check** — a client could fire it for a weapon it did not
own and buy damage levels on it. That gap predates persistence, but this phase escalated it: what used
to evaporate at logout now survives forever, turning a session-scoped exploit into a permanent one. It
was closed during Task 5 with a one-line guard on the replicated `WeaponOwned_*` attribute, which is
already set on all four paths that can grant a weapon. Measured both directions: an owned Crowbar
upgraded twice (cash 5000 → 4950 → 4850, level nil → 1 → 2, held damage 45 → 55); an unowned Deagle
fired at four times with zero cash change and zero level change. The client never sees a refused
control, because `WeaponaryShopController` renders the upgrade button only inside `if isOwned(...)`,
reading the same attribute.

That a remote could ship without its ownership check suggests **the other client-facing remotes deserve
the same audit** — `BuyRequest`, `SetLoadoutSlotRequest`, `EquipRequest`, `BuySkinRequest`,
`EquipSkinRequest`, `AcceptQuestRequest`, `TurnInQuestRequest`, the movement and monetization remotes.
Persistence raises the stakes on every one of them the same way. Recommended, deliberately **not done
here**: it is an audit, not a persistence task.

**7. Found and fixed during this pass: `loadForKey` threw on a same-server rejoin.**
Loading a key that is already loaded **in this server** does not return `nil` — ProfileStore raises:

```
ServerStorage.ProfileStore:1391: [ProfileStore]: Profile (STORE:PlayerProfiles; KEY:player_58662576)
  is already loaded in this session
  Script 'ServerStorage.ProfileStore', Line 1391 - function StartSessionAsync
  Script 'ServerScriptService.Persistence.Scripts.ProfileGateway', Line 169 - function loadForKey
```

`loadForKey` did not guard that call, and `onPlayerAdded` does not pcall `loadForKey`. The throw
therefore propagated out of the `PlayerAdded` handler: the `profile == nil` kick never ran, the bind
never ran, and the player spent a full session unbound with `mirror` silently no-opping — the exact
silent-loss outcome this phase exists to prevent. Same shape as the `migrate` throw Task 6 closed
(Note 4), and worse, because this is the call that actually talks to the network.

Reachability: a player rejoining the **same** server inside the window between `PlayerRemoving` calling
`EndSession` and the session actually ending. Rare, not impossible. It surfaced here because a probe
deliberately loaded the live player's key while their session was bound.

**Fixed**, by wrapping `StartSessionAsync` the way `migrate` is wrapped, and by treating a throw as a
failed **attempt** rather than an immediate `nil` — a contended or transient failure is what
`LOAD_ATTEMPTS` exists for, and the rejoin window is short enough that the next attempt usually
succeeds. If all three throw, the `nil` return hands the player to the kick path that already exists.
The outcome is now either "loads on retry" or "kicked with the message that says nothing has been
changed", never "plays on, unbound, silently".

`ProfileGateway_Test` gained a regression case that proves the **outcome**, not just the return value:
it holds a session open, loads the same key again, and asserts that `loadForKey` returns `nil`, that
the first session is still `IsActive()` — the failed attempt neither ended it nor stole it — and that a
write made *after* the failed attempt still saves and reads back (`spraypaint = 5150`). Mutation-tested
by deleting the `pcall`: exactly one case goes red, this one, carrying ProfileStore's own error as its
message (14/15, 1 failed). Two harmless details checked while looking: ProfileStore's error fires
*before* `ActiveProfileLoadJobs` is incremented, so no shutdown counter leaks, and the earlier session's
lock is untouched.

**A second test was tightened at the same time.** `expect.throws(function() Gateway.migrate(data) end)`
passes when `Gateway.migrate` is **nil**, because calling nil throws — so it could not tell "migrate
asserts correctly on an unmigratable version" from "migrate does not exist". It reported a clean pass
under the stale module cache described in Note 8, while four of its neighbours failed with "attempt to
call a nil value". It now asserts `typeof(Gateway.migrate) == "function"` first and then that the error
text actually names the version mismatch. Mutation-tested both ways: with `migrate` absent it goes red
on the type assertion (`expected "function", got "nil"`), and with the version assert deleted from
`migrate` it goes red on the throw itself (`expected the function to throw, but it returned normally`),
taking the pre-existing "a migrate failure ends the session and returns nil" case down with it — both
failures legitimate, since that mutation genuinely breaks both assertions.

**8. Two harness traps, recorded so the next task does not pay for them again.**
*The plugin VM's `require` cache goes stale.* Running the 12 suites through `execute_luau` in Edit mode
reported **127/132 with 5 failures**, all in `ProfileGateway_Test`, all "attempt to call a nil value" on
`Gateway.migrate`. The live source has `migrate`; the plugin VM was holding a copy of `ProfileGateway`
required before Task 6 added it. Running the same suites from a `Script` in a real server VM gives a
full pass. **Suite counts from Edit-mode `execute_luau` cannot be trusted after a module is edited.** One
of those five even passed for the wrong reason — `expect.throws(Gateway.migrate)` is satisfied by
calling `nil`.

*`ServerScriptService.UnitTestRunner` is `Disabled` on purpose* (already recorded in
`FPS-Quest-Overflow-And-Dead-Code-Removal.md`), so the suites do not auto-run at server start and the
`useMockStore()` call inside `ProfileGateway_Test` never fires during a normal playtest. That is what
made this pass's round trip unambiguous: the gateway kept one store for the whole session. If the runner
is ever re-enabled, a test run mid-session repoints the live `store` and any round trip measured
afterwards is measuring a different backing table.

**9. THE CRITICAL: hydration paid a level-up award that never happened.**
`SpraypaintService.start`'s `safePlayerAdded` seeded `lastLevel[player] = player:GetAttribute("Level")`
and then connected `GetAttributeChangedSignal("Level")`. The gateway yields on `StartSessionAsync`, so
`LevelingService.hydrate`'s `SetAttribute("Level", 12)` **always** lands afterwards and fires that
signal. With `LevelingService`'s own `PlayerAdded` handler having run first, the seed is its default
`1`, and `onLevelChanged` computed `(12 − 1) × 25 = 275` spraypaint for a level-up that never happened.

The code was **correct only by ordering luck.** Both handlers are yield-free `PlayerAdded` handlers, so
which one wins is pure require order: if `SpraypaintRunner` required first the seed was `nil` and the
`previous == nil` guard returned early, and the file's own comment cited that as proof of correctness.
The other order pays. `lastLevel` is correctly listed in `Schema.DERIVED` and is therefore never
persisted — and nothing re-seeded it after the restore.

The award was **durable** even though nothing was written. `mirror` no-ops before the bind, so
`profile.Data.spraypaint` stayed at the real value; what survived was the inflated live **attribute**,
and that attribute is the base the next `grant` or `spend` mirrors back. One rejoin, one kill, and 275
phantom spraypaint is in the saved profile.

**Fixed** with a post-hydrator in `SpraypaintService` that re-seeds `lastLevel[player]` from the
restored `Level`. It has to be a post-hydrator and not a hydrator: it reads *another* service's
restored attribute, and hydrator order is registration order, which is require order — exactly the
thing that made the bug order-dependent in the first place.

Two measurements underwrite it. `GetAttributeChangedSignal` is **deferred** in this place (probed
directly: the handler had not run immediately after `SetAttribute` and had run after one `task.wait()`),
so the signal cannot fire *between* `LevelingService`'s restore and the post-hydrator unless something
in the hydrator loop yields; and nothing does — none of the seven hydrators nor either post-hydrator
contains `WaitForChild`, `task.wait` or `task.spawn`. **That is an assumption, not a guarantee**: a
future hydrator that yields, registered between `LevelingService`'s and this one's, would flush the
deferred queue mid-loop and reopen the window. Recorded here rather than guarded, because the guard
that would close it structurally — refusing to pay while `get(player)` is `nil` — also silences the
award for any player who is legitimately unbound, and that is a behaviour change this round did not ask
for.

Regression case: `ProfileAdoption_Test > "a restored level is not paid out as a level-up"`, which drives
the **real** registered hydrator and post-hydrator lists through `_runHydrators` / `_runPostHydrators`.
Note that `LevelingService` is a `Script`: its hydrator *is* registered at server start, but it throws
on a stand-in player (`FindFirstChild` is not a method on a table), so the case registers a probe
hydrator that writes the same attribute from the same field, and asserts `Level == 12` so it cannot
pass blind. **Mutation: delete the post-hydrator from `SpraypaintService`.** Exactly one case goes red —
this one — with `expected 40, got 315`, which is 40 + 275: the phantom award, measured.

**10. THE MAJOR: the ordering hole was closed at the instance, not the class.**
`_runHydrators` runs whatever is registered at that instant and then binds unconditionally, so a service
that registers **after** a bind never hydrates that player at all. Its own guarded `PlayerAdded` default
then fires via `safePlayerAdded` / `GetPlayers()`, and the next ordinary action mirrors that default
straight over real saved data: `level = 1` over a saved level 12 on the first kill, `{Crowbar}` over
real ownership on the first purchase, a fresh kills table over a real count. No per-task diff could show
this, because no single service is wrong — the class is.

**Fixed at the class.** `registerHydrator` and `registerPostHydrator` now immediately run the
newly-registered function for every player whose profile is already bound, guarded the same way the
loops are (`pcall` + `warn`) so a throwing late hydrator cannot take registration down with it. A
late-registering service always hydrates, and the window closes structurally instead of seven services
each having to remember.

Regression case: `ProfileAdoption_Test > "a hydrator registered after a player is already bound still
hydrates them"`, which binds first and registers second, for both phases, and includes a deliberately
throwing late post-hydrator to prove registration survives it. **Mutation: delete both `runForBound`
calls.** Exactly one case goes red — this one — with `expected 808, got nil`.

**Also closed here: the one adoption that mirrored its own default.** `SpraypaintService`'s
`safePlayerAdded` fallback wrote `player:SetAttribute(ATTRIBUTE, 0)` *and* mirrored `spraypaint = 0`
into the profile. Its comment justified the mirror as a fallback for a failed load — but `mirror`
no-ops without a bound profile, so on a failed load it did nothing at all. The only state in which that
line was live was the state in which it wrote `0` over a real saved balance. **The mirror call is
deleted; the attribute set stays**, which is the part that actually serves the about-to-be-kicked
player.

**11. THE MAJOR: the eighth test this project has caught that could not fail.**
`ProfileGateway_Test > "a migrate failure ends the session and returns nil"` asserted `failed == nil`
and then `reread == nil`. Delete `profile:EndSession()` from `ProfileGateway.loadForKey` and it **still
passed**: the second `loadForKey` hits ProfileStore's already-loaded throw, that throw is swallowed by
the `pcall` Note 7 added, the attempts are exhausted and `nil` comes back for entirely the wrong reason.
Our own guard is what made the test blind — the fix in Note 7 broke the assertion in a neighbouring
case and nobody noticed, because both the right and the wrong behaviour return the same value.

Its comment conceded this outright: it asked a human to "contrast this case's reported duration against
'a failed load yields no profile and writes nothing' above". A timing a person is asked to eyeball is
not an assertion.

**Fixed** by asserting the duration the comment described. A freed lock means `StartSessionAsync`
succeeds on attempt 1 and `migrate` throws again, so `nil` comes back in milliseconds; a leaked lock
means three throwing attempts with `RETRY_DELAY` between them. The threshold is 1s, four times below
the failure and far above the success. **Mutation: delete `profile:EndSession()` from the migrate-failure
branch.** Exactly one case goes red — this one — with `reload took 4.03s, so it went down the
contended-retry path: the failed attempt did not end the session`. The console for that run shows the
three `already loaded` warnings the old assertion was silently passing through.

**12. THE MAJOR: the mock drops `params`, so the abandonment policy has never run.**
`ProfileStore.Mock`'s proxy is:

```lua
StartSessionAsync = function(_, profile_key)
    MockFlag = true
    return self:StartSessionAsync(profile_key)   -- params is dropped
end,
```

The gateway calls `store:StartSessionAsync(key, { Cancel = cancel })`. Under `useMockStore` that second
argument never arrives, so inside ProfileStore `params.Cancel` is `nil`, which re-enables its own
`START_SESSION_TIMEOUT` (`if params.Cancel == nil then default_timeout = ... end`). Every measurement in
this document is a mock run. **The gateway's entire abandonment policy — the 30s `LOAD_DEADLINE` and the
departing-player cancel — has therefore never executed, not once.** Row 9 does not reach it either:
`_forceNextLoadFailure` short-circuits before `StartSessionAsync` is called at all, so that row measures
`LOAD_ATTEMPTS × RETRY_DELAY` and the never-write rule, and nothing about cancellation.

**Not patched, deliberately.** The vendored `ServerStorage.ProfileStore` is pinned to an upstream commit
with a recorded sha256 (`ad4373…0c95f`), and this log's `Changes` section asserts that match. That
guarantee is worth more than exercising the branch: a local edit to vendored code is the kind of thing
that survives one re-vendor and not the second. Recorded as DEFERRED beside restart durability and
cross-server locking, and marked `NEVER EXERCISED` in the gateway's own comment where the next reader
will find it. Closing it needs either a published place or an upstream fix.

## Status

- **Confirmed live this pass, against ProfileStore's Studio mock:** verification rows 1-9, 11, 12 and
  13, each with the numbers quoted above; the damage-path-clean check; the single-`require` check; and
  all 12 unit suites at 135/135 in a real server VM. Every change was driven through the game's own
  entry points — `BuyRequest`, `SetLoadoutSlotRequest`, `UpgradeRequest`, `SetLevelRequest`,
  `BuySkinRequest` fired from the Client datamodel, and one genuine kill through `Blaster.Remotes.Shoot`
  → `ShotResolver` → `Eliminated` — not by writing to `profile.Data` directly.
- **Carve-outs inside those passes.** Row 8's `PoliceKills` counter was never exercised (0 throughout);
  only the Criminal counter is proven. Of the two kills in the session, one was genuinely earned
  through `Shoot` → `ShotResolver` and one was fired onto `Blaster.Events.Eliminated` by the harness —
  the same signal and payload `ShotResolver` emits, so every listener downstream ran unmodified, but
  the ballistics above that event were exercised exactly once. Rows 9 and 12 drive the gateway API directly on scratch keys, because a
  join-time load failure and a stored v0 profile cannot be produced through a player join in this
  harness. Row 7's recompute and rows 3-6's restores were read back by re-running the **deployed**
  hydrators against the reloaded profile, not by an actual rejoin — see the next point for why no
  rejoin is possible. **That carve-out is how the Critical survived verification:** the hydrator replay
  restores state without ever touching the `GetAttributeChangedSignal` the phantom award lived on, so
  the one check that would have shown it is the one this harness cannot run (Note 9).
- **DEFERRED — cannot be verified until the place is published.** Durability across a real server
  restart, and cross-server session locking. Neither is simulated and neither should be read as passing.
  The mock store lives in the server VM's memory and dies with the playtest, so there is no restart for
  a profile to survive and no second server to contend with.
- **DEFERRED — the load-abandonment policy has never executed.** The 30s `LOAD_DEADLINE` and the
  departing-player cancel. ProfileStore's `Mock` proxy drops the `params` argument, so `params.Cancel`
  is `nil` in every mock run and ProfileStore's own `START_SESSION_TIMEOUT` takes over; row 9 does not
  reach `StartSessionAsync` at all. Not worked around, because the vendored file's sha256 match is worth
  more than the branch (Note 12). Nothing in this document should be read as evidence that the deadline
  or the cancel works.
- **Needs a person — row 10's other half.** A failed *load* has never kicked anyone. The `nil` return is
  measured and the `OnSessionEnd` kick was observed on a real Player, but the failed-load branch of
  `onPlayerAdded` has only ever been read. Two clients on a published place, one holding the session
  lock, would close it.
- **Needs a person — the mock is not a DataStore.** Everything above proves the *logic*. The mock does
  not model latency, throttling, request budgets, `UpdateAsync` conflicts, partial failures or the 4MB
  key limit, and it has already hidden two live-only failures from this phase (Notes 1 and 2). The first
  session on a published place should be watched: profile load times, the retry path under real
  contention, and `ProfileStore.OnError` / `OnCriticalToggle`, none of which have ever fired here.
- **Closed this pass:** the `loadForKey` same-server-rejoin throw (Note 7) — guarded, with a regression
  case that proves the outcome, and mutation-tested. Suite total 132 -> 133.
- **Closed in the final fix round, after a whole-branch review:** the phantom level-up award on every
  rejoin (Note 9, Critical), the late-registration hydration hole (Note 10), the mirror of a default
  over a real balance (Note 10), and a test that could not fail (Note 11). Three mutations run, each
  naming exactly one red case: `expected 40, got 315` (the 275 award), `expected 808, got nil` (the
  un-hydrated late registration), and `reload took 4.03s` (the leaked session lock). Two API functions
  with no callers, `waitFor` and `isLoaded`, deleted. Suite total 133 -> 135.
- **Open, recorded, not done here:** the three live test suites missing from this repo (Note 5), and the
  client-facing remote audit (Note 6).
- **Open, recorded, not guarded.** Note 9's fix depends on no hydrator yielding between
  `LevelingService`'s restore and `SpraypaintService`'s re-seed; today none does, and that was measured,
  not assumed. A hydrator that yields would flush the deferred attribute signal mid-loop and reopen the
  window. The structural guard (refuse a level award while `get(player)` is `nil`) also silences the
  award for a legitimately unbound player, so it is named here rather than shipped unasked. Similarly,
  Note 10's late-registration re-run does not itself re-seed the level baseline: a service registering
  `LevelingService`'s hydrator after a bind would restore `Level` without `SpraypaintService`'s
  post-hydrator following it. No service registers late today; this is the shape the next one must not
  take.
