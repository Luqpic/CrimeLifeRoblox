# Final fix wave — one dispatch, seven items

The feature is verified and shipping. These close the final review's findings. Work through them in
order; items 1 and 2 are the substantive ones.

Snapshot every file before you touch it, into `.sdd-getaway/snapshots/<Name>.final.before.lua`
(dump `.Source` via `execute_luau`, write with the Write tool). Note the `Write` tool silently
strips trailing whitespace, so verify by checksum rather than byte length if you need exactness.

---

## Item 1 — WITHDRAWN by the user, do NOT do it

The shared-`GetawayMath` refactor is deliberately deferred. Do **not** create
`ReplicatedStorage.HeistShared.GetawayMath`, do not touch `Getaway`'s `horizontalDistance`, and do
not change the inline distance expression in `HeistClient` (~1199-1201). It is being recorded as
known debt in the changelog instead, to be done in a fresh session against a saved place.

Rationale, so nobody "helpfully" reinstates it: it restructures the exact arithmetic that
end-to-end testing validated, immediately after unexplained data loss, in a place whose only copy
is an unsaved Studio session.

## Item 2 — a live, player-facing string still names the retired Claim zone

`LocationServer` ~line 75:

```lua
	has_duffel = "You need to claim your duffel first before carrying supplies.",
```

Reachable at SlowFoods/Gas2Go/NewsStation via `SupplyObject`'s `onRefused`. "Claim your duffel" no
longer names any in-world action — exactly the defect the spec called out for the Duffel Full
strings, missed because no task owned this line. Reword so it describes what the player must now
do: get clear of the building to bank the bag before they can carry supplies. Match the file's
existing tone and keep it one sentence.

## Item 3 — the same sentence renders two ways

`LocationServer:73` uses `--` where `HeistServer:344` and `:1023` use an em dash `—`:

```
LocationServer  "Duffel Full -- get clear of the building to bank it."
HeistServer     "Duffel Full — get clear of the building to bank it."
```

Inherited from a pre-existing split, but a player who robs the Bank and then SlowFoods now sees one
sentence rendered two ways. Make both the em dash `—` (U+2014), matching `HeistServer`.

## Item 4 — three comments now describe things that no longer exist

- `HeistClient` ~1136: `-- robbing area to the claim zone, which are different zones.` This is the
  stated JUSTIFICATION for the duffel widget not being zone-gated, and it cites a thing that is
  gone. Rewrite it to give the real reason (the player must see their running total while escaping).
- `LocationServer` ~line 7: the module header still lists `claim-zone cash-out` among the handlers
  it owns. That handler was deleted.
- `HeistServer` ~1013-1014: the comment justifying `getaway:Step()` sitting outside the Active
  branch says "a bag can still be carried clear of the building after the session has sealed."
  `_seal` voids every participant's bag, so that case cannot pay out. The PLACEMENT is right —
  do not move the call — but give the accurate reason.

## Item 5 — one consolidated WorldSpec test (closes two deferred findings at once)

Neither the marker-folder construction path (`markerFolder` → `WaitForChild` →
`StatusBillboardAnchor` → `Getaway.new`) nor NewsStation's boot assert has any coverage. Both are
closed by a single `WorldSpec` test asserting that all four marker folders
(`HeistMarkers`, `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`) exist and each contains
a `StatusBillboardAnchor` BasePart. This is the only path that hard-asserts at boot on the server
AND silently degrades to no-widget on the client, so it is worth pinning. Follow `WorldSpec`'s own
existing style.

## Item 6 — `_bankBag`'s `amount <= 0` bail has no test

Reachable in production with a bag in hand: the session sealed, or the player is not a participant,
so `bank:Claim` returns 0. It is the branch `Getaway`'s latch comment leans on. Add a
`LocationServerSpec` test driving an escape where `Claim` refuses, asserting no `CurrencyAdd`, no
`Toast`, no `NotifyRobberySuccess`, and the bag untouched. The existing rig's
`AddParticipant → TryAddDuffel → RemoveParticipant` trick (already used by the ForgetPlayer test)
produces exactly this state.

## Item 7 — two one-line HeistClient tidies

- Hoist the bare `190` in the fill quantiser to a named constant shared with
  `getawayTrack.Size = UDim2.fromOffset(190, 6)` (~200 lines apart, nothing keeping them in step).
- Move the fill reset from the hide edge to just before `SlideIn` on the show edge, so the bar is
  reset while the widget is parked off-screen and the reset is invisible by construction.

---

## Gate

Suite must be **594 passed / 14 failed** (plus whatever Items 4/5/6 add as PASSING tests), with the
failing set exactly {`RestaurantConfig` 1, `Gas2GoConfig` 1, `CashClaimVFX` 12}. `World`, `Getaway`
and `LocationServer` must be 0 failed. Run via
`TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)`.

If timing-sensitive suites (`Hazard`, `UITransitions`, `CounterBarrier`, `SupplyObject`) fail,
measure `RenderStepped` fps before blaming your code — this Studio runs ~15 fps and tween assertions
flake below ~30.

Also compile-check `HeistServer` and `HeistClient` after editing (`loadstring(<script>.Source)`),
since neither has unit coverage.

## Report contract

Full report to `.sdd-getaway/final-fix-report.md`: before/after per item, the Item 1 equivalence
harness output with its worst delta, and the final suite run.

Return ONLY: status, the Item 1 worst delta, the TOTAL line, failing suite names, and concerns.
