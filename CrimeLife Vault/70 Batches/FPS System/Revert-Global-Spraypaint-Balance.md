# Revert Spraypaint to a global balance, raise skin prices

**Status:** Implemented and verified live — 145/145 tests in a real server VM (baseline 161/161 before
this revert; the drop is expected, per-weapon tests were removed). Nine dedicated migration cases,
each mutation-tested with a named mutation and a confirmed red. A real kill and a real purchase were
driven through the live game against the one connected player, at attribute level; the chip was
confirmed on screen via screen capture. Two things are explicitly NOT verified and are listed under
Notes.

## Summary

Spraypaint was one balance per weapon (`Per-Weapon-Spraypaint.md`), earned from kills made with that
weapon and spent from that weapon's own balance plus a shared fallback bucket. It is now back to one
balance for the whole player, exactly as it was before that change: a single `Spraypaint` attribute,
earned from any kill or level-up, spent on any palette.

Skin prices are raised: Cobalt 250→500, Verdigris 350→700, Ember 500→900, RoseGold 750→1200. Free and
Vip palettes are unchanged.

`ShotResolver` is deliberately left alone. It still threads a weapon name into the `Eliminated` event
as a fourth argument — `SpraypaintService.onEliminated` no longer reads it, but Lua silently drops an
argument a function doesn't declare, so it is inert rather than broken. Re-editing two fire sites plus
`applyBleed` in the most safety-critical script in the game to delete an unread argument was judged the
riskier choice for zero behavioural gain.

## Cause

Requested revert, not a defect in the per-weapon design itself. The per-weapon balance is reverted
back to one global balance per player.

## Changes

- `ReplicatedStorage.Persistence.Schema` — `VERSION` 2 → **3**. `spraypaint` changes back from a
  per-weapon map to a scalar `0`. `spraypaintShared` is removed from the template outright.
- `ServerScriptService.Persistence.Scripts.ProfileGateway` — a new v2 → v3 migration step. The existing
  v0 → v1 and v1 → v2 steps are untouched, byte for byte. The new step sums every per-weapon balance in
  `spraypaint` plus whatever is in `spraypaintShared` into one scalar, then clears `spraypaintShared`.
  Because the three version checks are sequential `if`s rather than `elseif`, a single `migrate()` call
  chains a profile at any starting version all the way to v3 — a v1 profile's old scalar spends one
  internal moment as a v2 map before folding straight back into a scalar in the same call.
- `ServerScriptService.Spraypaint.Scripts.SpraypaintService` — `balanceOf`, `grant`, `spend`, `hydrate`
  are single-argument, single-balance again. `grantShared`, `sharedBalanceOf`, `spendableBalanceOf` and
  every weapon-scoped overload are removed. `awardForVictim` and `onLevelChanged` no longer take or
  branch on a weapon name. `handleBuyRequest` drops its `weaponName` parameter and charges the single
  balance.
- `ReplicatedStorage.Spraypaint.Constants` — `ATTRIBUTE = "Spraypaint"` is back; `balanceAttributeFor`
  and `SHARED_ATTRIBUTE` are removed.
- `StarterPlayer.StarterPlayerScripts.SpraypaintHud` — back to one attribute watch. Toasts read
  `"+N Spraypaint"` again, with no weapon name.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` / `SkinRowController` — the
  `SpraypaintChip` and the skin-row affordability check both read the single `Spraypaint` attribute.
  The chip itself is unchanged UI; only its data source changed.
- `ReplicatedStorage.Cosmetics.Palettes` — Cobalt 250→500, Verdigris 350→700, Ember 500→900, RoseGold
  750→1200.
- Tests updated across `Schema_Test`, `ProfileGateway_Test` (+9 migration cases covering v0 through v4),
  `SpraypaintConstants_Test`, `SpraypaintService_Test`, `ProfileAdoption_Test`. Suite count 161 → 145.

## Notes

**Why this rolled forward to v3 rather than reverting straight to v1 — the most important decision in
this change.** Per-weapon Spraypaint is already published, so every player who has logged in since that
change now carries a profile stamped `Schema.VERSION = 2`. `ProfileGateway.migrate`'s entire purpose is
to fail loudly — via its own `assert` — on a stored version it has no migration step for, exactly the
behaviour `"migrate refuses to silently accept a version with no migration step"` already tests and
already passes. Simply setting `Schema.VERSION` back to `1` does not remove that assert; it makes every
already-migrated player's stored `version = 2` trip it on their very next load. `loadForKey` `pcall`s
`migrate`, catches the throw, ends the session, and returns `nil`; `onPlayerAdded`'s `profile == nil`
branch then kicks the player with "Your saved data could not be loaded, so nothing has been changed."
Their stored version never changes on a failed load, so this repeats on every future join — a
permanent lockout of every player who ever saw the per-weapon version, which is presumably everyone who
has played recently. The fix that reads as the obvious revert is the one that breaks the game
permanently for real players. Rolling forward to a new v3 whose migration step reads the v2 shape and
folds it back into a scalar is the only path that restores the one-balance design without locking
anyone out — nobody's currency changes, only its shape, and the change is one-way and idempotent.

**The `spraypaintShared` bucket is retired, not merely emptied.** It existed only to grandfather the
v1 scalar and to hold a no-weapon-equipped level-up award under the per-weapon design. Both of those
land in the single `spraypaint` scalar again under v3, so the field itself is removed from the
template — a lingering `spraypaintShared = 0` on every profile forever would be a dead value with no
reader, which is exactly the kind of stale field `Schema.DERIVED` exists to prevent for computed
values, even though this one is stored rather than derived.

**`ShotResolver`'s unread fourth argument is a deliberate no-op, not an oversight.** See Summary. Both
`eliminatedEvent:Fire(...)` sites (the direct-hit path and the bleed-tick path through `applyBleed`)
still pass the weapon name. `onEliminated` declares two parameters; Lua drops the rest. Confirmed inert
by pinning it directly: `SpraypaintService_Test`'s `"onEliminated rejects an attacker that is not a
Player"` case now also calls `onEliminated` with the real 4-argument shape and asserts it doesn't throw.

**A test bug in my own first draft, worth recording.** My first attempt at proving the 4-argument call
shape pays out normally called `onEliminated` with a plain Lua table stand-in as the attacker and
asserted a payout. It failed — `expected 5, got 0` — not because production was wrong, but because a
plain table can never satisfy `typeof(attacker) == "Instance"`, `onEliminated`'s own first guard. This
is the exact limitation the file's pre-existing comment already names: no test stand-in can ever
construct a real `Player`, so a payout can only be proven through `awardForVictim` directly, never
through `onEliminated`. Fixed by folding the 4-argument proof into the existing guard-rejection case
instead of asserting a payout the harness cannot honestly demonstrate.

**Repo and Studio drifted after the first push, and were re-synced.** After getting a clean 145/145,
every touched live script was re-read and diffed against its repo mirror. Two real mismatches turned
up in files that were freehand-composed for the repo rather than copied from verified source text —
`SpraypaintService.luau` had a doc-comment sitting inside a function body instead of above it, plus a
longer, different-era comment above the buy-and-equip step; `SpraypaintHud.luau` had a stale
per-weapon-era preamble sentence left in place above the new revert note. Neither changed behaviour,
but neither matched what was actually tested. Both are fixed and every one of the 13 touched files was
re-verified line-for-line against Studio afterward, not just the two that were wrong.

**Not verified, stated plainly:**

- The priced skin-buy strip (the price label on the BuyStrip control) was not captured on screen at the
  new prices — the skin row's `ScrollingFrame` did not respond to mouse-wheel or drag-scroll input from
  the tools available, a limitation `Per-Weapon-Spraypaint.md` already recorded against the same
  control. The new prices are instead proven by a real server-side purchase clearing at the exact new
  figure (Verdigris, 700 charged) and by the catalogue tests, which read the live prices rather than a
  hardcoded expectation.
- The kill and purchase proof against the real connected player was done through `execute_luau`, which
  runs in a Studio plugin VM with its own `require()` cache — confirmed directly, since
  `ProfileGateway.get(player)` returned `nil` from that context even though the player's profile is
  genuinely bound in the real server VM. The attribute-level result (balance, ownership flag, the chip)
  is real and shared DataModel state, so it is valid proof of the earn/spend/display path. It is not
  proof that this specific interactive session's `profile.Data` mirror fired correctly — that is proven
  separately by `ProfileAdoption_Test`, which runs inside a real `Script` in the true server VM.
