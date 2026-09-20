# Change Log: Getaway Distance Replaces the Claim Zone

**Date:** 2026-09-20
**Status:** Applied and confirmed live, including genuine end-to-end robberies at all four locations. Four items listed under Notes were NOT verified and still need a person.

## Summary

Cash no longer banks by walking into a Claim zone. It banks when the player gets at least
`EscapeDistance` studs (200) clear of the location they robbed, measured horizontally from that
location's `StatusBillboardAnchor`, and only once they are outside the building entirely. A new HUD
widget counts the studs down, and the heist timer — previously hidden the moment you left the zone —
now stays on screen during the escape, because the clock is what the player is racing.

The distance gate is one shared service, `Heist.Services.Getaway`, consumed by both `LocationServer`
(SlowFoods, Gas2Go, NewsStation) and `HeistServer` (the Bank). No new remote was added: the client
already receives everything it needs and recomputes the same number the server computes, the same
pattern the lockpick needle uses.

## Cause

The Claim zones sat 55-83 studs from their own anchors — close enough that banking was a formality
rather than an escape. Replacing them with a distance requirement makes the getaway the risky part
of the run, since the session timer keeps running and the bag is still voided on death or expiry.

## Changes

- **New `ServerScriptService.Heist.Services.Getaway`** — owns the payout decision. Takes injected
  callbacks (`isInsideBuilding`, `getDuffel`, `onEscaped`, `getPlayers`, an anchor or position
  function) so it is unit-testable without a DataModel, and knows nothing about zones, currency or
  remotes. Distance is horizontal: the anchors float 40-120 studs above their buildings, so a 3D
  measurement would credit that height as escape progress. New `GetawaySpec`, 14 tests.
- **`EscapeDistance = 200`** added to all four Config modules, beside the other session tunables.
  A starting value chosen against measured map geometry, not a tuned one.
- **`LocationServer`** — constructs and drives a `Getaway` from its existing heartbeat, the old
  claim-zone `Entered` handler replaced by a `_bankBag` method holding the same payout body
  verbatim. `claimRole` removed; `getaway:Forget` added to `ForgetPlayer`; new `markerFolder`
  argument passed by the three location scripts (the Bank's folder is `HeistMarkers`, so these
  cannot be derived from the location name).
- **`HeistServer`** — the same wiring for the Bank, which is deliberately not a `LocationServer`
  consumer. Its three-role interior union (`Lobby OR Vault OR BankVaultZone`) was extracted into a
  single `isInsideBank` helper now shared by the payout gate, the zone-occupancy broadcast and the
  forfeit closure, which previously carried its own verbatim copy.
- **`HeistClient`** — new 240x76 getaway widget per location, built from exported Figma slices, with
  a live right-aligned studs figure and a fill bar; slotted into the derived HUD position chain so
  the toast and the cash-burst origin follow automatically. Only one getaway widget and only one
  heist timer are ever rendered, since every location's HUD elements rest at the same screen
  position and escaping is by definition outside all zones.
- **`UITheme`** — `GetawayNormal` / `GetawayNear` pinned in `Assets`, `Size` and `BodyOffset`.
  The near-complete state is gold, matching `DuffelFull`, not the timer's red: being close to the
  threshold is good news for the player, not a warning.
- **Figma** — two 240x76 frames on page `03 · Export Slices` of the `Roblox` file (`128:6`, `129:6`),
  matching the timer's construction so the two read as a pair. Caption, accent edge and the `STUDS`
  unit label are baked; only the number and the bar fill are live.
- **The four `*ClaimZone` parts were UNTAGGED, not deleted** — tag and `ZoneRole` attribute removed,
  geometry left in place. Reversible by re-adding one tag, which matters because this place has no
  version control. Boot asserts in all four location scripts and the `WorldSpec` manifest updated to
  match.
- **Duffel Full wording** — both copies ("head back to claim it") now read "get clear of the building
  to bank it", which is the advice that is actually true.

## Verified live

Genuine end-to-end robberies, no injected payloads: real weapon-equip triggers, real ProximityPrompt
holds, and the Bank's full gauntlet played through (Terminal 1 → Terminal 2 → C4 → vault), since that
is the only path that enrols a Bank participant.

- SlowFoods banked 4,000 at 206.0 studs, nothing at 199.0. Gas2Go 4,000, walked out, banked at 204.0.
  NewsStation 7,000, walked out, banked at 203.9. Bank 15,000 by real vault accrual, banked at 204.0.
- **The Bank's underground case, which this whole design exists to protect:** the vault sits 314 studs
  horizontally from the Bank's anchor, so a naive distance check would pay out the instant the bag
  filled. A full 15,000 bag sat in `VaultZone` at 313.4 studs for ~96 seconds — roughly 960
  consecutive `Getaway:Step` calls — and cash never moved. Dense samples at 313.4 / 296.3 / 290.6 /
  229.6 studs all read `inside=true` with cash unchanged; 229.6 is the decisive one, well past the
  threshold and unambiguously inside.
- Expiry path: bag forfeited, cash unchanged, widget and timer both slid away. Death path confirmed
  too, by falling into the underground `DeathVolume` with a full bag.
- Reachability: the baseplate is 2048x2048 flat, so the ~490-stud built extent is not the constraint.
  Walked Bank ExitSpawn → 206.6 studs in 8.2s, SlowFoods → 207.0 in 9.9s.
- Spec suite 594 passed / 14 failed, the 14 being pre-existing and unrelated (see Notes).

## Notes

**Not verified — these still need a person.**

1. **A Bank escape walked on foot from the vault out.** The Bank interior is not on the navmesh
   (`ComputeAsync` from the lobby returns `NoPath`), so in-building movement during testing was
   `PivotTo`. The exterior leg is proven walkable; the vault → lobby → street route is not.
2. **Nothing visual beyond property read-backs.** `screen_capture` returns a uniform magenta frame in
   Play mode on this place — reproducible, and it works the instant Play stops. The widget's geometry
   and state were confirmed by reading `AbsolutePosition`/`AbsoluteSize` and the live image ids off
   the real instances, and the gold bake was observed swapping at exactly 50 studs remaining, but
   nobody has seen a screenshot of it during a real robbery. At the ~15 fps this Studio was running,
   tween smoothness is also unverified.
3. **Multiplayer.** One player only, though three sessions were Active simultaneously with no HUD
   conflict.
4. **Persistence.** Studio API access is off and every DataStore save returned 403, so payouts are
   verified in-session only. Nothing here proves the cash survives a rejoin.

**Tuning is an open question, deliberately left alone.** 200 studs is roughly triple the old
claim-zone distance. Measured anchor-to-anchor: SlowFoods↔Gas2Go 205, Gas2Go↔NewsStation 166,
SlowFoods↔Bank 165, NewsStation↔Bank 487. So a Gas2Go job cannot be banked while standing at
NewsStation, and the SlowFoods→Gas2Go run clears the bar by only 5 studs. From an ExitSpawn it is an
8-10 second run; from deep inside, 13-16. The value lives in the four Configs precisely so this is a
one-line change per location after playtesting.

**Pre-existing failures, none caused by this work and none fixed by it.** `CashClaimVFX` fails all 12
of its tests with `attempt to index nil with 'WaitForChild'` at line 176 — diagnosed but deliberately
left alone: `TestRunner.freshRequire` clones a module, requires it, then destroys the clone, and
`_buildPersistentGui` does its `require(script.Parent:WaitForChild("UITheme"))` lazily inside the
function, by which time `script.Parent` is nil. The live game is unaffected because the real module is
never destroyed; the fix is hoisting that require to module scope. `RestaurantConfig` and
`Gas2GoConfig` each fail one `CooldownDuration` assertion (config says 60, spec expects 1200/600).

**Known debt, deliberately not paid here: the distance formula exists twice.** `Getaway` computes
it in the service; `HeistClient` recomputes it inline to render the widget. A review harness proved
they agree to zero difference across 104 samples per location — every distance band, ±300 stud Y
offsets, every tagged zone centre — but nothing *guards* that agreement. `HeistClient` is a
LocalScript, so no spec can require it and `RunAll` only loads ModuleScripts under `Heist.Tests`;
the client half has no coverage. A one-line edit to either copy makes the HUD lie to the player
while the suite stays green.

The fix is to hoist the arithmetic into a shared `HeistShared.GetawayMath` that both sides require
and the spec asserts on — less code than what is there now, and what rule 6 of the project's own
operating notes prescribes. It was deferred deliberately rather than overlooked: it restructures the
exact arithmetic the end-to-end testing above validated, and the moment to do it is a fresh session
against a saved place, not immediately after the incident described below. **If you edit either
copy of that formula before this is done, change both.**

**An unexplained deletion during this work, and what it cost.** Partway through the final review
pass, `Heist.Services.LocationServer` and `Heist.Tests.LocationServerSpec` both vanished from the
live Studio session, leaving three of the four locations unable to boot. Cause never established:
the whole-feature review had read `LocationServer` live and quoted its line numbers minutes
earlier. Studio's undo stack did not contain the deletion (verified by fingerprinting every touched
script, undoing once, detecting zero change, and redoing), the only autosave for this place was two
weeks stale, and the place file on disk predated the work. Both modules were reconstructed from a
pre-feature snapshot plus the original per-task briefs, then verified back to the same gate that
existed before the loss: 17/0 on the spec, 594/14 overall, clean four-location boot. Six lines of
comment prose could not be recovered from any record and were deliberately left absent rather than
invented — the shortfall sits immediately above the `Getaway` construction block in `new()` and
above `self.getaway:Step()` in `Tick()`. Every executable line is the original text.

**Two environment traps worth recording.** `multi_edit` with `replace_all: true` reported "11 edits
applied" while changing nothing at two sites — only the spec suite caught it, so the returned edit
count is not evidence. And a minimised Studio window stops the render loop entirely: `RenderStepped`
drops to 0 fps while `Heartbeat` stays at ~59, TweenService freezes mid-playback, and every
tween-based or wall-clock spec fails for purely environmental reasons. That swung the suite
594/15 → 581/28 and back with no code change, and it is why the failure *set* rather than the failure
*count* was used as the gate throughout this work.
