# Task 4 — fix round 1: two Important findings from review

Both are TEST-ONLY additions to `game.ServerScriptService.Heist.Tests.LocationServerSpec`.
**Do not change any production code.** `LocationServer`, `Getaway`, the three location scripts and
every Config module are correct and reviewed — the shipped behaviour is right, the tests just fail
to pin two parts of it.

The suite currently reports `LocationServer: 17 passed, 0 failed`. It must still report
`17 passed, 0 failed` when you are done — you are adding assertions to two existing tests, NOT
adding new tests.

---

## Finding 1 (Important) — the exact banked-toast wording is no longer pinned anywhere

The rewritten test `"getting clear banks the floored amount, toasts, then notifies success"`
asserts only the toast's RECIPIENT:

```lua
expect.equal(lastToast[1], player, "toasted the banking player")
```

The test it replaced also pinned the MESSAGE. From the pre-task snapshot
(`.sdd-getaway/snapshots/LocationServerSpec.before.lua` line 231):

```lua
expect.equal(lastToast[2], string.format("Banked %d %s.", 1234, Config.CurrencyName),
    "exact banked-toast wording")
```

`"Banked %d %s."` exists in exactly two places place-wide (`HeistServer` and `LocationServer`) and
NO spec asserts either one. So the payout message can be broken at all three locations and the
suite stays green.

This also breaks the file's own convention: sibling tests in the same spec DO pin their message
text — see the snapshot's line 339 (`exact sealed-refusal wording, with the location's own name`)
and line 352 (`the shared carrying refusal message`), both asserting `lastToast[2]`.

**Fix:** add that `lastToast[2]` assertion back alongside the existing ones in the rewritten test.
Keep every assertion already there — including `expect.equal(remaining, 0, "bag emptied")`, which
is new coverage the rewrite correctly added. The banked amount in that test is 1234 (floored from
1234.7), so the expected string is `string.format("Banked %d %s.", 1234, Config.CurrencyName)`.

## Finding 2 (Important) — `getaway:Forget` is implemented but untested

`LocationServer:ForgetPlayer` calls `self.getaway:Forget(player)`. Delete that line and the suite
stays green — nothing covers it.

It is not cosmetic. `Getaway._fired` is keyed by the player, and `Getaway:Step()` only iterates
`getPlayers()`. A disconnected player is no longer in that list, so Step's "bag gone, re-arm"
branch is never reached for them and the latch entry is never cleared. `Forget` is the only thing
that clears it, so without it `_fired` holds a strong reference to a departed Player forever.

The test `"ForgetPlayer clears every piece of per-player skeleton state"` currently asserts the
roster, zone occupancy, the `_insideBuilding` cache and the trigger debounce — six assertions, none
about the getaway latch (it did not exist when that test was written).

**Fix:** extend that test so it proves the latch is cleared. Make the latch non-empty for the
player FIRST — otherwise you are asserting nil equals nil and the test passes whether or not
`Forget` is called, which would make it vacuous and no better than the gap it closes.

A workable shape: give the player a bag, put them clear of the anchor, `Tick()` so the getaway
fires and sets its latch, assert the latch is set, then `ForgetPlayer` and assert it is cleared.
Read the rig and the existing test before choosing — the rig exposes `setPosition`, `setOccupants`,
`connected`, `bank`, `location` and `teardown`, and existing tests call `rig.teardown()` BEFORE
their assertions. Follow that convention.

Reach the latch however the code actually allows; `rig.location.getaway._fired[player]` is one way,
but verify the field name against the live `Getaway` source rather than trusting this note.

---

## Report contract

Append your fix report to `.sdd-getaway/task-4-report.md` (the file does not exist — the original
implementer was killed by an infrastructure error before writing it, so create it).

It must contain: the before/after of both edited tests, the covering test names, the exact command
you ran, and its full output.

Return ONLY: status, the `LocationServer` suite line, the TOTAL line, the names of any failing
suites, and concerns.
