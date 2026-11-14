# Task 4 — fix round 1 report

Scope honored: only `game.ServerScriptService.Heist.Tests.LocationServerSpec` was edited.
No production code changes were left in place (see the meaningfulness proof below, which
temporarily edited `LocationServer` and then restored it byte-identical).

Pre-edit snapshot: `.sdd-getaway/snapshots/LocationServerSpec.fix1.before.lua` (full source,
read via `.Source` in `execute_luau`, written before any edit).

---

## Finding 1 — exact banked-toast wording

Test: `"getting clear banks the floored amount, toasts, then notifies success"`

### Before
```lua
	suite:test("getting clear banks the floored amount, toasts, then notifies success", function(expect)
		local rig = makeRig()
		local player = { UserId = 42 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 1234.7)

		rig.setPosition(player, Vector3.new(250, 6000, 0))
		rig.location:Tick()

		local added = rig.calls.CurrencyAdd[1]
		local toasts = rig.calls.Toast
		local lastToast = toasts[#toasts]
		local notified = rig.calls.NotifyRobberySuccess[1]
		local remaining = rig.bank:GetDuffel(player)
		rig.teardown()

		expect.equal(added[1], 42, "credited that player's UserId")
		expect.equal(added[2], 1234, "floored, not rounded")
		expect.equal(lastToast[1], player, "toasted the banking player")
		expect.equal(notified, player, "RobberySuccess fired for them")
		expect.equal(remaining, 0, "bag emptied")
	end)
```

### After
```lua
	suite:test("getting clear banks the floored amount, toasts, then notifies success", function(expect)
		local rig = makeRig()
		local player = { UserId = 42 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 1234.7)

		rig.setPosition(player, Vector3.new(250, 6000, 0))
		rig.location:Tick()

		local added = rig.calls.CurrencyAdd[1]
		local toasts = rig.calls.Toast
		local lastToast = toasts[#toasts]
		local notified = rig.calls.NotifyRobberySuccess[1]
		local remaining = rig.bank:GetDuffel(player)
		rig.teardown()

		expect.equal(added[1], 42, "credited that player's UserId")
		expect.equal(added[2], 1234, "floored, not rounded")
		expect.equal(lastToast[1], player, "toasted the banking player")
		expect.equal(lastToast[2], string.format("Banked %d %s.", 1234, Config.CurrencyName),
			"exact banked-toast wording")
		expect.equal(notified, player, "RobberySuccess fired for them")
		expect.equal(remaining, 0, "bag emptied")
	end)
```

One assertion added (`lastToast[2]`), matching the sibling convention (lines 363 and 376 in the
pre-task snapshot) and pinning the exact literal `LocationServer:_bankBag` emits
(`string.format("Banked %d %s.", banked, HeistConfig.CurrencyName)`).

---

## Finding 2 — `getaway:Forget` untested

Test: `"ForgetPlayer clears every piece of per-player skeleton state"`

### Before
```lua
	suite:test("ForgetPlayer clears every piece of per-player skeleton state", function(expect)
		local rig = makeRig()
		rig.connected[1] = "p1"
		rig.bank:TryStart("p1")
		rig.setOccupants(INTERIOR, { "p1" })
		rig.location:Tick()

		local wasParticipant = rig.bank:IsParticipant("p1")
		local wasInside = rig.location.zoneService:IsInside(INTERIOR, "p1")

		rig.setOccupants(INTERIOR, {})
		rig.location:ForgetPlayer("p1")

		local stillParticipant = rig.bank:IsParticipant("p1")
		local stillInside = rig.location.zoneService:IsInside(INTERIOR, "p1")
		local insideCache = rig.location._insideBuilding["p1"]
		local triggerCache = rig.location._recentTriggerAttempt["p1"]
		rig.teardown()

		expect.truthy(wasParticipant, "was a participant beforehand")
		expect.truthy(wasInside, "was tracked inside beforehand")
		expect.falsy(stillParticipant, "roster cleared")
		expect.falsy(stillInside, "zone occupancy cleared")
		expect.falsy(insideCache, "occupancy cache cleared")
		expect.falsy(triggerCache, "trigger debounce cleared")
	end)
```

### After
```lua
	suite:test("ForgetPlayer clears every piece of per-player skeleton state", function(expect)
		local rig = makeRig()
		rig.connected[1] = "p1"
		rig.bank:TryStart("p1")
		rig.setOccupants(INTERIOR, { "p1" })
		rig.location:Tick()

		local wasParticipant = rig.bank:IsParticipant("p1")
		local wasInside = rig.location.zoneService:IsInside(INTERIOR, "p1")

		-- Also drive the getaway latch non-empty, for a second player, so
		-- that ForgetPlayer clearing it below is a meaningful assertion --
		-- otherwise this is asserting nil equals nil and passes whether or
		-- not Forget is called. A second player (rather than reusing "p1")
		-- so this setup cannot taint the roster/zone/cache assertions above:
		-- "p2" is never added as a bank participant when the escape fires,
		-- so bank:Claim refuses to pay out (Claim requires IsParticipant)
		-- and the bag stays nonzero -- exactly the case Getaway:Step's own
		-- re-arm comment describes as needing Forget, since the "bag gone,
		-- re-arm" branch is never reached for a departed, unlisted player.
		rig.connected[2] = "p2"
		rig.bank:AddParticipant("p2")
		rig.bank:TryAddDuffel("p2", 50)
		rig.bank:RemoveParticipant("p2")
		rig.setPosition("p2", Vector3.new(250, 6136, 0))
		rig.location:Tick()
		local latchSetAfterEscape = rig.location.getaway._fired["p2"] == true

		rig.setOccupants(INTERIOR, {})
		rig.location:ForgetPlayer("p1")
		rig.location:ForgetPlayer("p2")

		local stillParticipant = rig.bank:IsParticipant("p1")
		local stillInside = rig.location.zoneService:IsInside(INTERIOR, "p1")
		local insideCache = rig.location._insideBuilding["p1"]
		local triggerCache = rig.location._recentTriggerAttempt["p1"]
		local latchAfterForget = rig.location.getaway._fired["p2"]
		rig.teardown()

		expect.truthy(wasParticipant, "was a participant beforehand")
		expect.truthy(wasInside, "was tracked inside beforehand")
		expect.truthy(latchSetAfterEscape, "getaway latch set once a player got clear with an unclaimed bag")
		expect.falsy(stillParticipant, "roster cleared")
		expect.falsy(stillInside, "zone occupancy cleared")
		expect.falsy(insideCache, "occupancy cache cleared")
		expect.falsy(triggerCache, "trigger debounce cleared")
		expect.falsy(latchAfterForget, "getaway latch cleared")
	end)
```

Two assertions added (`latchSetAfterEscape`, `latchAfterForget`); still exactly one `suite:test(...)`
call, so the suite's test count is unchanged.

### Design note (why a second player, "p2")

`Getaway:Step()` has a same-tick re-arm: after `onEscaped` fires, if `getDuffel(player) <= 0` it
immediately clears `_fired[player]` back to nil (this is the documented "bag gone, re-arm" branch).
`LocationServer:_bankBag` calls `bank:Claim`, which zeroes the duffel on a normal successful claim
— so a naive "give p1 a bag, walk them clear, Tick()" scenario fires the latch and un-fires it in
the same `Step()` call, and the latch would read `nil` immediately after, never demonstrating a
"stuck" latch to clear.

To get an observable non-empty latch, the escape must hit `bank:Claim`'s refusal path
(`BankInstance:Claim` returns 0, leaving the duffel untouched, when the player is not currently a
participant) — the exact real case Finding 2 is about: a departed player whose bag was never
actually paid out. `"p2"` is added as a participant only long enough to legally add a duffel
(`TryAddDuffel` requires participancy), then removed as a participant before the escape Tick, so
`Claim` refuses and the bag — and therefore the latch — survives the tick. Using a distinct player
(rather than manipulating `"p1"`'s participant/session state) keeps the original six assertions on
`"p1"` exactly as meaningful as they were before this edit.

---

## Meaningfulness proof (Finding 2, requirement 8)

Three suite runs, all via:
```lua
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)
local RunAll = TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)
local ok, res = pcall(RunAll)
return "ok=" .. tostring(ok) .. "\n" .. tostring(res)
```

**Run 1 — after both fixes, production code untouched (green):**
```
LocationServer: 17 passed, 0 failed
Getaway: 14 passed, 0 failed
TOTAL: 594 passed, 15 failed
```
(Failing suites: World x1 ClaimZone floor, RestaurantConfig x1 CooldownDuration, Gas2GoConfig x1
CooldownDuration, CashClaimVFX x12 WaitForChild-on-nil, SupplyObject x0 — all within the permitted
set.)

**Run 2 — `self.getaway:Forget(player)` temporarily commented out in
`LocationServer:ForgetPlayer` (red proof):**
```
LocationServer: 16 passed, 1 failed
    FAIL ForgetPlayer clears every piece of per-player skeleton state :: getaway latch cleared — expected falsy, got true
Getaway: 14 passed, 0 failed
TOTAL: 593 passed, 16 failed
```
Exactly the new assertion failed (`"getaway latch cleared"`); every other suite/test was unchanged
from Run 1 (World/RestaurantConfig/Gas2GoConfig/CashClaimVFX/SupplyObject identical). This confirms
the new assertion is load-bearing — it fails specifically and only when the production line under
test is removed.

**Run 3 — production line restored (`self.getaway:Forget(player)` back in place, byte-identical to
before; verified with a fresh `script_read` of lines 342-352), suite re-run (green again):**
```
LocationServer: 17 passed, 0 failed
Getaway: 14 passed, 0 failed
TOTAL: 594 passed, 15 failed
```
Identical to Run 1.

---

## Covering test names

- `"getting clear banks the floored amount, toasts, then notifies success"` — now also pins the
  exact `"Banked %d %s."` toast wording (Finding 1).
- `"ForgetPlayer clears every piece of per-player skeleton state"` — now also proves
  `getaway:Forget` clears `Getaway._fired` for a departed player (Finding 2).
