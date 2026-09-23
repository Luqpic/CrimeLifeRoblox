# Spraypaint becomes a per-weapon balance

**Status:** Implemented and verified live — 161/161 tests in a real server VM (baseline 137/137), five
mutations executed and each caught by its intended case. Migration and schema verified independently by
reading the source. Three things are explicitly NOT verified and are listed under Notes. Not yet seen in
real combat by a person.

## Summary

Spraypaint was one balance for the whole player, earned from any kill and spent on any skin. It is now
one balance **per weapon**, earned from kills made **with that weapon**, and a skin is paid for by the
weapon it is bought for.

Palette ownership is deliberately unchanged and stays global: buying Cobalt with the AK47's balance
unlocks Cobalt for every weapon. `CosmeticsService` and the whole equip path were not touched.

## Cause

Requested feature, not a defect. The intent: the more kills a weapon has, the more skins it can fund.

## Changes

- `ReplicatedStorage.Persistence.Schema` — `VERSION` 1 → 2. `spraypaint` changes from a number to a map
  keyed by weapon name. New `spraypaintShared`, a single figure any weapon may draw on **after** its own
  balance is exhausted.
- `ServerScriptService.Persistence.Scripts.ProfileGateway` — a v1 → v2 migration step.
- `ServerScriptService.Spraypaint.Scripts.SpraypaintService` — balance, grant and spend are weapon-scoped;
  spend falls back to the shared bucket; the buy handler charges the weapon it was given.
- `ServerScriptService.Blaster.Scripts.ShotResolver` — the weapon name is threaded into the `Eliminated`
  event as a fourth argument, at both fire sites, including through `applyBleed` which did not carry it.
- `StarterPlayer.StarterPlayerScripts.SpraypaintHud` — one connection per catalogued weapon plus one for
  the shared bucket, replacing the single attribute watch. Toasts name the weapon.
- `WeaponaryShopController` / `DetailPanel` — a `SpraypaintChip` showing the selected weapon's balance.
- Tests extended across the service, schema and migration.

## The migration, and the trap it avoids

A profile with **no** version field is stamped to **1**, not straight to `Schema.VERSION`. A pre-tracking
profile has v1's *shape*, including the old scalar `spraypaint`, so stamping it 1 lets the v1 → v2 step
actually run on it. Stamping it straight to 2 would have satisfied the version assert while silently
dropping that player's entire balance — the failure would have looked like a clean migration.

The step moves the old scalar whole into `spraypaintShared`, never split across weapons and never
dropped, and **adds** to whatever `Reconcile` already filled from the template rather than overwriting
it. Running it twice is a no-op, and a version with no step still trips the assert and fails closed.

## Notes

**Why the shared bucket exists.** The alternative was to allocate an existing balance to some weapon on
migration, and every rule for choosing that weapon is arbitrary — the starting weapon punishes anyone who
earned on something else, and splitting evenly invents a distribution the player never chose. The shared
bucket preserves the exact figure, needs no guess, and drains permanently as it is spent. It is
grandfathering, not a second currency: nothing ever adds to it except a level-up earned with nothing
equipped.

**The level-up award is not weapon-specific and had to be given a home.** 25 Spraypaint for a level is
earned by playing, not by a particular gun. It is credited to the weapon equipped at that moment, which
is the least arbitrary reading, and to the shared bucket when nothing is equipped.

**Two economy consequences that are design choices, not defects.** Per-weapon balances mean a player who
rotates between five guns earns five small balances instead of one usable pot, so variety is now mildly
punished and specialising rewarded. And low-kill weapons — the Crowbar every player starts with, most of
all — earn at the same per-kill rate while landing far fewer kills, so their skins are the slowest in the
game to reach. Both follow from the design rather than from the implementation, and both are tuning
questions if they read badly in play.

**Prices were set for the old economy and have not been revisited.** Cobalt 250 through RoseGold 750
assumed every kill in the game fed one pot. Under per-weapon balances a 750 palette needs 375 Criminal
kills *on that one weapon*. The catalogue is about to grow to 20 palettes, so the whole priced curve wants
re-sizing against per-weapon earn rates before any of it is judged.

**Not verified, stated plainly:**

- The skin-purchase click was not confirmed end-to-end on screen. A scrolled skin chip click landed on the
  wrong button through an offscreen-targeting artifact of the input tool, not a code fault. The server
  rule that a buy charges the named weapon is unit- and mutation-tested; the client's affordability
  repaint was read but not clicked.
- The weapon-name threading was proven by reading the code and by firing the real `Eliminated` event by
  hand — correct weapon credited, and the other four listeners tolerate the extra argument. It was not
  proven by an actual aim-and-kill through the live combat path.
- `SpraypaintHud` can show a spurious `+N` toast at join if hydrate's `SetAttribute` lands after the
  LocalScript's first read. This is pre-existing from the single-scalar version, neither introduced nor
  fixed here.

**A latent trap left alone on purpose.** `WeaponaryShopGui` is a `ZIndexBehavior.Global` ScreenGui. The
new chip renders only because its `ZIndex` *ties* with its parent's and falls back to tree order — the
same arrangement that made the notification card draw blank the moment a per-element `ZIndex` was
introduced there. Switching this GUI to `Sibling` was rejected for now: under Global a higher `ZIndex`
wins regardless of tree position, so flipping it on a panel this large could silently re-layer existing
elements, which is a behaviour change outside this task. The upcoming skins-card revamp adds a layered
panel to this exact GUI and must resolve it deliberately.
