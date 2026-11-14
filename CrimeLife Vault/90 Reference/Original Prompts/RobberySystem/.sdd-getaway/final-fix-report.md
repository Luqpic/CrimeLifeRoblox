# Final fix wave — report

Studio: `Robbery System (placeId: 130328863401144)`, id `009e370d-dae2-402e-88e9-379b254ec753`.
Place still UNSAVED — everything below lives in the open Edit session only.

**Status: Items 2–7 all applied and verified. Item 1 not done (withdrawn). Gate NOT cleanly
demonstrable — the Studio viewport is not drawing at all (RenderStepped 0.0 fps), which fails 13
tween/wall-clock assertions environmentally. See "Gate" below; the residual reconciles exactly.**

---

## Snapshots

All five touched files snapshotted to `.sdd-getaway/snapshots/<Name>.final.before.lua` BEFORE any
edit, and each verified **byte-exact** against the live `.Source` by Adler-32 + length (computed in
Luau and again with Python `zlib.adler32`), not by eyeball or byte count alone:

| File | bytes | adler32 |
|---|---|---|
| `LocationServer.final.before.lua` | 18450 | 989837578 |
| `LocationServerSpec.final.before.lua` | 20539 | 1197782701 |
| `WorldSpec.final.before.lua` | 47531 | 2322545156 |
| `HeistServer.final.before.lua` | 47480 | 3899686341 |
| `HeistClient.final.before.lua` | 64796 | 643298646 |

`LocationServer` and `LocationServerSpec` were byte-identical to the already-on-disk
`.sdd-getaway/reconstructed/*.lua`, confirmed by checksum, so those were copied rather than
re-dumped. The other three were dumped in newline-aligned chunks and written with `cat` heredocs
(not the `Write` tool) so trailing whitespace survived — `HeistClient` has exactly one
trailing-whitespace line (1034) and it is preserved.

Note: I did NOT enable `HttpService.HttpEnabled` (it is off in this place, and a direct POST path
would have been faster). Changing a place-level setting on an unsaved, just-reconstructed place
was not mine to do unasked, so I used the brief's prescribed dump-and-write path instead.

---

## Item 1 — WITHDRAWN, not done

No `ReplicatedStorage.HeistShared.GetawayMath` was created. `Getaway.horizontalDistance` is
untouched (still lines 29–31 of `Getaway`). The inline distance expression in `HeistClient` is
untouched:

```lua
local here = Vector3.new(characterRoot.Position.X, 0, characterRoot.Position.Z)
local there = Vector3.new(anchor.Position.X, 0, anchor.Position.Z)
remaining = math.max(0, escapeDistance - (here - there).Magnitude)
```

**Equivalence harness: not run. Worst delta: N/A — there is nothing to compare.** The harness only
existed to prove a refactor preserved the arithmetic; with the refactor withdrawn the arithmetic is
bit-for-bit the code that end-to-end testing already validated.

---

## Item 2 — player-facing string naming the retired Claim zone

`LocationServer` (now line 77). Reachable at SlowFoods/Gas2Go/NewsStation via `SupplyObject`'s
`onRefused(player, "has_duffel")` (`SupplyObject:320`).

- Before: `has_duffel = "You need to claim your duffel first before carrying supplies.",`
- After:  `has_duffel = "You need to get clear of the building to bank your duffel first before carrying supplies.",`

Tone matched against the file's sibling literal, `Config.SupplyCarryingRefusalMessage` =
`"You need to drop the Supplies first before robbing."` — same `You need to X first before Y.`
skeleton, one sentence, and it now names an action that exists in the world.

## Item 3 — the same sentence rendered two ways

`LocationServer` (now line 75).

- Before: `cap_exceeded = "Duffel Full -- get clear of the building to bank it.",`
- After:  `cap_exceeded = "Duffel Full — get clear of the building to bank it.",`

Verified with `utf8.codepoint`, not by eye:

```
LocationServer | [—] | U+2014
HeistServer    | [—] | U+2014     (cap_exceeded, :319)
HeistServer    | [—] | U+2014     (heartbeat toast, :1023)
IDENTICAL LocationServer.cap_exceeded == HeistServer.cap_exceeded:        true
IDENTICAL LocationServer.cap_exceeded == HeistServer heartbeat toast:     true
```

All three copies of the sentence are now byte-identical.

## Item 4 — three comments describing things that no longer exist

**(a) `HeistClient` (was ~1136, now ~1140).** The stated justification for the duffel widget not
being zone-gated cited the claim zone.

- Before: `a player must be able to see their running total while walking from the robbing area to the claim zone, which are different zones.`
- After: the bag now banks a fixed distance clear of the building, so the whole escape that decides
  whether it pays out is spent OUTSIDE every zone; a zone-gated duffel would blank out for exactly
  that stretch, hiding the running total at the moment it matters most.

Deliberately says "a fixed distance" rather than "200 studs" — the number lives in the four configs
(`Config.EscapeDistance`) and a literal here would be a fifth copy to drift.

**(b) `LocationServer` header (was line 7).** The handler list still advertised `claim-zone
cash-out`.

- Before: `-- late joiner, claim-zone cash-out, duffel push, weapon-equip trigger,` / `-- character watch, player cleanup) and the same heartbeat body. Only tags,`
- After: the entry is dropped from the handler list, and the header now says the heartbeat body
  also steps the Getaway that banks the bag, the claim-zone cash-out handler having gone with the
  Claim zone itself (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).

Accurate against the live code: `LocationServer:Tick()` calls `self.getaway:Step()`, and
`_bankBag` is wired as Getaway's `onEscaped`. No `Start()` handler does the cash-out any more.

**(c) `HeistServer` (1012–1018).** The reason given for `getaway:Step()` sitting outside the Active
branch was wrong — `_seal` voids every participant's bag, so the cited case cannot pay out.

- Before: `Outside the Active branch below: a bag can still be carried clear of the building after the session has sealed.`
- After: outside the Active branch because it needs no state check of its own — every branch in
  `Getaway:Step` is gated on the player still holding a bag, and `_seal` voids every participant's
  bag, so once a session ends this steps to a no-op on its own; keeping it out here is what holds
  it adjacent to the zone pass it reads, and keeps its fired-once latch re-arming every tick rather
  than only while Active.

**The call was NOT moved.** Verified structurally: `getaway:Step()\n\n\t\tif bank:GetState() ==
"Active" then` still matches, i.e. the call is still the last of the unconditional sweep and still
precedes the Active branch.

## Item 5 — one consolidated `WorldSpec` test

Added immediately before `return suite:run()`, in `WorldSpec`'s own style (leading rationale
comment, `expect.truthy` with per-instance messages):

`"every location's marker folder exists and holds a StatusBillboardAnchor BasePart"` — iterates
`HeistMarkers`, `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`, asserting each folder
exists, has a `StatusBillboardAnchor`, and that it is a `BasePart`.

Closes both deferred findings at once: the marker-folder construction path and NewsStation's boot
assert. The comment records why it is worth pinning — the two sides fail differently
(servers `WaitForChild` then hard-assert at boot; `HeistClient` bounded-waits and only warns,
silently losing that location's getaway widget).

Live state confirmed before writing the test, so it is a genuine pass and not a vacuous one:

```
HeistMarkers:       folder=Folder anchor=Part isBasePart=true
SlowFoodsMarkers:   folder=Folder anchor=Part isBasePart=true
Gas2GoMarkers:      folder=Folder anchor=Part isBasePart=true
NewsStationMarkers: folder=Folder anchor=Part isBasePart=true
```

`World`: **51 passed, 0 failed** (was 50).

## Item 6 — `_bankBag`'s `amount <= 0` bail

Added to `LocationServerSpec` directly after the "staying inside the building banks nothing" test:

`"getting clear with a bag Claim refuses credits nothing and leaves the bag alone"` — uses the
rig's existing `AddParticipant → TryAddDuffel → RemoveParticipant` trick (the same one the
ForgetPlayer test uses) to reach "bag in hand, `Claim` returns 0", drives a real escape via
`setPosition` + `Tick()`, and asserts:

- `#calls.CurrencyAdd` unchanged — nothing credited
- `#calls.Toast` unchanged — no banked toast
- `#calls.NotifyRobberySuccess` unchanged — no success notification
- `bank:GetDuffel(player) == 500` — bag untouched

Counts are captured immediately before the tick and compared after, so setup traffic cannot mask a
regression. `LocationServer`: **18 passed, 0 failed** (was 17).

## Item 7 — two `HeistClient` tidies

**(a) The bare `190`.** Added next to the other derived HUD constants:

```lua
local GETAWAY_BAR_WIDTH = 190
```

with a comment explaining the two are the same number by definition (the quantiser exists to round
to this bar's own pixel resolution) and that as two literals a track resize would silently restore
the ~60-tweens-a-second the quantiser was added to prevent.

- `getawayTrack.Size = UDim2.fromOffset(190, 6)` → `UDim2.fromOffset(GETAWAY_BAR_WIDTH, 6)`
- `ratio = math.floor(ratio * 190) / 190` → `math.floor(ratio * GETAWAY_BAR_WIDTH) / GETAWAY_BAR_WIDTH`

Done as two uniquely-anchored single edits, never `replace_all` — the other two `190`s in the file
are deliberately left alone and were checked afterwards: `timerText.Size = UDim2.fromOffset(190, 32)`
(the timer's clock width, unrelated) and the `(34,64) 190x6, r3` comment (documents the baked Figma
slice, not the code constant).

**(b) Fill reset moved from the hide edge to the show edge.** The cancel-tween + `_lastRatio = 0` +
`fill.Size = UDim2.new(0, 0, 1, 0)` block now runs immediately *before*
`UITransitions.SlideIn(...)`, and the hide edge is now just `SlideOut`. Comment rewritten to say
why: on the show edge the widget is still parked off-screen, so the reset is invisible by
construction, where on the hide edge it was mid-slide-out and still on screen.

Behaviour is preserved: at the moment of `SlideIn` the widget is in exactly the same state as
before (`_lastRatio = 0`, empty fill), and the `if wantGetaway then` block that follows in the same
frame calls `setFillRatio` with a ratio near 0 at the start of an escape, which the edge guard
absorbs.

---

## Verification

Structural re-check of all 18 assertions after the last Play-mode cycle — every one OK
(old strings absent, new strings present, `getaway:Step()` still outside the Active branch, reset
still before `SlideIn`, hide edge reduced to `SlideOut`).

Compile checks via `loadstring(<script>.Source)`:

```
compile HeistClient:    OK
compile HeistServer:    OK
compile LocationServer: OK
compile WorldSpec:      OK
compile LocationSpec:   OK
```

Four-location boot is clean (Play mode, console): Gas2Go, NewsStation, SlowFoods and Bank all
print their boot manifests with no errors. The only console noise is pre-existing and unrelated —
`rbxassetid://90` sound 404s, DataStore 403s (Studio API access off), and `GetConnectedParts`
warnings from an unparented weapon model.

## Gate

```
TOTAL: 583 passed, 27 failed
FAILING SUITES: Hazard=1, UITransitions=3, CounterBarrier=4, RestaurantConfig=1,
                CashClaimVFX=12, Gas2GoConfig=1, SupplyObject=5
```

**This does not meet the gate literally, and the reason is the viewport, not the code.** Measured
before blaming anything, exactly as the brief requires:

```
RenderStepped 0.0 fps | Heartbeat 59.6 fps
```

Zero, not merely low. `screen_capture` also times out, which is the same fact from the other side —
Studio is not drawing a frame at all (window minimised, occluded, or on another macOS Space).
Remediation attempted and failed: two full enter/leave Play-mode cycles, a camera nudge, and a
re-measure inside the Play (Client) datamodel, which also reported `RenderStepped 0.0 fps`. I did
not resort to synthetic mouse input to click the viewport — blind clicks into an unsaved,
just-reconstructed place are not worth the risk.

The 13 excess failures are exactly the four suites the brief names as viewport-sensitive, and every
one of them is a tween or wall-clock assertion:

- `Hazard` 1 — templight red fade reached 0.784 of 1
- `UITransitions` 3 — SlideIn/SlideOut never settle (`expected 0, got -1`)
- `CounterBarrier` 4 — fade-to-invisible / fade-to-solid never complete
- `SupplyObject` 5 — countdown, despawn and implosion timers never fire

None touch anything I edited, and no suite I edited fails.

The arithmetic reconciles exactly:

```
583 passed + 13 viewport-blocked = 596 passed
 27 failed  - 13 viewport-blocked =  14 failed
```

596 = 594 baseline + 2, which is precisely Item 5's test and Item 6's test, both passing.
The residual 14 is exactly `{RestaurantConfig 1, Gas2GoConfig 1, CashClaimVFX 12}` — the sanctioned
failing set. And the three suites the gate names as must-be-zero are zero right now, viewport or
not, because none of them depend on rendering:

```
World:          51 passed, 0 failed
Getaway:        14 passed, 0 failed
LocationServer: 18 passed, 0 failed
```

**What is needed to close the gate:** bring the Studio window forward so the 3D viewport draws,
then re-run `TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)()`. Expected:
`TOTAL: 596 passed, 14 failed`.

## Concerns

1. **The gate is unproven, not met.** The reconciliation above is arithmetic plus a measured
   root cause, not an observed green run. It should be re-run with a live viewport before this is
   called done.
2. **The place is still unsaved.** Five byte-verified snapshots are on disk, but they are source
   text only — they do not carry the Workspace instances, and `LocationServer`/`LocationServerSpec`
   were lost once already from this session by an unknown cause.
3. Item 1 remains open debt and needs recording in the changelog, per the withdrawal note: to be
   done in a fresh session against a saved place.
4. Item 2's new string is long (94 chars). It matches the file's tone and is one sentence as asked,
   but if the toast widget clips it in-world it should be shortened — I could not check rendering,
   for the same reason the gate is blocked.
