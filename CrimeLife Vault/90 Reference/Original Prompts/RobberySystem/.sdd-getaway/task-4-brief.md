# Task 4 brief — wire Getaway into LocationServer (SlowFoods, Gas2Go, NewsStation)

## Global Constraints (bind every step)

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

---

## Task 4: Wire `Getaway` into `LocationServer` (SlowFoods, Gas2Go, NewsStation)

**Files:**
- Modify: `ServerScriptService.Heist.Services.LocationServer`
- Modify: `ServerScriptService.Heist.Tests.LocationServerSpec`

**Interfaces:**
- Consumes: `Getaway.new/:Step/:Forget` (Task 2), `Config.EscapeDistance` (Task 3).
- Produces: `LocationServer.new` accepts `cfg.markerFolder: string` and `cfg.getaway` (test injection point). `cfg.claimRole` is **removed**.

- [ ] **Step 1: Update the spec rig first (the test drives the change)**

`makeRig` currently returns exactly this shape — use these names, they are confirmed:

```lua
		local rig = {
			location = location, bank = location.bank, calls = calls,
			advance = advance, now = now, connected = connectedPlayers,
			setOccupants = function(role, list) occupancy[byRole[role]] = list end,
		}
		function rig.teardown() ... end
```

Every existing test calls `rig.teardown()` **before** its assertions. Keep that idiom in the new tests.

Three changes to `makeRig`:

1. The zone loop builds parts `for _, role in ipairs({ INTERIOR, "Claim" })`. Change it to `{ INTERIOR }`. Note that `setOccupants("Claim", ...)` then silently no-ops (`byRole["Claim"]` is nil, so it assigns `occupancy[nil]`), which is exactly why the old claim tests must be rewritten rather than left to rot.

2. Forward-declare `location` so the injected getaway's callbacks can close over it. This is the pattern `NewsStationServer` already uses and documents ("Forward-declared so the LocationServer hooks below can close over them"). Add above the `cfg` table, and change line `local location = LocationServer.new(cfg)` to `location = LocationServer.new(cfg)` — dropping the `local`:

```lua
	-- Forward-declared: the getaway callbacks below only RUN after new()
	-- returns, so closing over this is safe.
	local location
	local positions = {}
	local ANCHOR = Vector3.new(0, 6136, 0) -- above the fixture zones' own Y=6000

	cfg.getaway = Getaway.new({
		escapeDistance = 200,
		getAnchorPosition = function() return ANCHOR end,
		isInsideBuilding = function(player)
			return location.zoneService:IsInside(INTERIOR, player)
		end,
		getDuffel = function(player) return location.bank:GetDuffel(player) end,
		getPosition = function(player) return positions[player] end,
		getPlayers = function() return connectedPlayers end,
		onEscaped = function(player) location:_bankBag(player) end,
	})
```

Require it at the top of the spec beside the others: `local Getaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Getaway)`.

3. Add a position setter to the returned `rig` table, beside `setOccupants`:

```lua
			setPosition = function(player, position) positions[player] = position end,
```

Now replace the two claim tests. The existing one is `"claim-zone entry banks the floored amount, toasts, then notifies success"` — it does `rig.setOccupants("Claim", { player })` then `rig.location:Tick()`. Keep its floored-amount assertion (1234.7 → 1234), which is real coverage:

```lua
	suite:test("getting clear banks the floored amount, toasts, then notifies success", function(expect)
		local rig = makeRig()
		local player = { UserId = 42 }
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

	-- The Bank's VaultZone is 314 studs from its own anchor, so this gate is
	-- what stops a bag banking the moment it fills. Asserted here too because
	-- LocationServer builds its own getaway wiring independently of HeistServer.
	suite:test("staying inside the building banks nothing, however far from the anchor", function(expect)
		local rig = makeRig()
		local player = { UserId = 42 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 500)

		rig.setOccupants(INTERIOR, { player })
		rig.setPosition(player, Vector3.new(400, 6000, 0))
		rig.location:Tick()

		local notifications = #rig.calls.NotifyRobberySuccess
		local remaining = rig.bank:GetDuffel(player)
		rig.teardown()

		expect.equal(notifications, 0, "no payout from inside")
		expect.equal(remaining, 500, "bag intact")
	end)
```

Check whether a second existing test also asserts against the claim path (the baseline run showed `LocationServer: 17 passed`, and there is a `local notified = #rig.calls.NotifyRobberySuccess` count assertion further down). Read the whole spec and rewrite every claim-zone-driven test, not only the first.

- [ ] **Step 2: Run and confirm the new tests fail**

Expected: `LocationServer` reports failures on the two rewritten tests (no `_bankBag`, no `cfg.getaway` handling). Other `LocationServer` tests must still pass — if the zone-loop change broke unrelated ones, fix that now.

- [ ] **Step 3: Extract the claim body into a named method**

In `LocationServer`, add — placing it next to `_pushDuffel`, the other `_`-prefixed per-player helper:

```lua
-- The payout, moved verbatim out of the old claim-zone Entered handler
-- (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19). Now called by Getaway
-- when the player gets clear; the body itself is unchanged.
function LocationServer:_bankBag(player)
	local amount = self.bank:Claim(player)
	if amount <= 0 then return end
	local banked = math.floor(amount)
	self.currency:Add(player.UserId, banked)
	self.net:Toast(player, string.format("Banked %d %s.", banked, HeistConfig.CurrencyName))
	-- Fired after currency:Add so leaderstats.Cash.Value has already
	-- replicated the new total by the time the client reacts to this.
	self.net:NotifyRobberySuccess(player)
end
```

- [ ] **Step 4: Construct the Getaway in `new()`**

After `self.zoneService` is assigned (it is needed by `isInsideBuilding`) and before `return self`:

```lua
	self.getaway = cfg.getaway
	if not self.getaway then
		assert(type(cfg.markerFolder) == "string",
			"LocationServer requires markerFolder (or a prebuilt getaway)")
		local markers = workspace:WaitForChild(cfg.markerFolder, 10)
		local anchor = markers and markers:WaitForChild("StatusBillboardAnchor", 10)
		assert(anchor, string.format("[%sServer] %s has no StatusBillboardAnchor",
			cfg.name, cfg.markerFolder))
		self.getaway = Getaway.new({
			escapeDistance = cfg.config.EscapeDistance,
			anchor = anchor,
			isInsideBuilding = function(player)
				return self.zoneService:IsInside(self.interiorRole, player)
			end,
			getDuffel = function(player) return self.bank:GetDuffel(player) end,
			getPlayers = self.getPlayers,
			onEscaped = function(player) self:_bankBag(player) end,
		})
	end
```

Add `local Getaway = require(Heist.Services.Getaway)` to the requires at the top, beside `Forfeit`.

- [ ] **Step 5: Drive it from the heartbeat and delete the Claim handler**

In `Tick()`, add `self.getaway:Step()` after `self:_updateZoneOccupancy()`. Do not add a second loop — the existing heartbeat already runs at `1 / self.config.HeartbeatRate`.

Delete the whole `zoneService.Entered` handler beginning `if role ~= self.claimRole then return end`, together with its `-- Cash-out on crossing into the claim zone -- automatic, no prompt.` comment. Delete the `claimRole = cfg.claimRole or "Claim",` field.

In `ForgetPlayer`, add `self.getaway:Forget(player)` beside the other per-player forgets.

- [ ] **Step 6: Fix the now-wrong refusal message**

`REFUSAL_MESSAGES.cap_exceeded` is `"Duffel Full -- head back to claim it."`. "Head back" is now exactly the wrong advice. Change it to `"Duffel Full -- get clear of the building to bank it."`.

- [ ] **Step 7: Pass `markerFolder` from the three location scripts**

Read each of `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer` and add to its `LocationServer.new({...})` call: `markerFolder = "SlowFoodsMarkers"` / `"Gas2GoMarkers"` / `"NewsStationMarkers"` respectively. Their call shapes are not identical — read each before editing.

- [ ] **Step 8: Run the suite**

Expected: `LocationServer` green again, `TOTAL: 593 passed, 16 failed` (the two rewritten tests replace two old ones, so the count holds).

---


---

## STEP ZERO — snapshot before you touch anything (do this first, no exceptions)

There is no version control for this game code. Before your first edit, write the current source of
every file you are permitted to touch to disk, so a bad edit can be reverted exactly:

```lua
-- execute_luau, datamodel_type "Edit". Run once per file, and SAVE each returned
-- string to .sdd-getaway/snapshots/<Name>.before.lua using the Write tool.
return game.ServerScriptService.Heist.Services.LocationServer.Source
```

Snapshot all five, each to its own file under
`/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/snapshots/`:

    LocationServer.before.lua      <- game.ServerScriptService.Heist.Services.LocationServer
    LocationServerSpec.before.lua  <- game.ServerScriptService.Heist.Tests.LocationServerSpec
    SlowFoodsServer.before.lua     <- game.ServerScriptService.SlowFoodsServer
    Gas2GoServer.before.lua        <- game.ServerScriptService.Gas2GoServer
    NewsStationServer.before.lua   <- game.ServerScriptService.NewsStationServer

Confirm all five files exist and are non-empty BEFORE making any edit. Report their byte sizes in
your report. If a snapshot fails to write, stop and report BLOCKED — do not proceed unprotected.

## Scope fence

You may modify exactly these files:
- `ServerScriptService.Heist.Services.LocationServer`
- `ServerScriptService.Heist.Tests.LocationServerSpec`
- `ServerScriptService.SlowFoodsServer`, `.Gas2GoServer`, `.NewsStationServer` (ONLY to add `markerFolder` to their existing `LocationServer.new({...})` call)

Do NOT touch: `HeistServer` (Task 5 owns the Bank), `HeistClient` (Task 6), any Config module
(Task 3 already set `EscapeDistance`), `WorldSpec`, or any world part. In particular **do not delete
the four `*ClaimZone` parts** — Task 7 does that, and only after the user approves it.

## Interface produced by Task 2 (already built and passing — do not re-create it)

`ServerScriptService.Heist.Services.Getaway` exists and its 14 unit tests pass. Its contract:

    Getaway.new(cfg) -> Getaway
      cfg.escapeDistance   : number, > 0  (asserted)
      cfg.anchor           : BasePart     -- OR --
      cfg.getAnchorPosition: () -> Vector3
      cfg.isInsideBuilding : (player) -> boolean   (asserted)
      cfg.getDuffel        : (player) -> number    (asserted)
      cfg.onEscaped        : (player) -> ()        (asserted)
      cfg.getPlayers       : () -> {player}        (asserted)
      cfg.getPosition      : (player) -> Vector3?  (optional; defaults to character PrimaryPart)
    Getaway:Step()                          -- call once per heartbeat tick
    Getaway:DistanceRemaining(player) -> number?   -- nil when not armed
    Getaway:Forget(player)

Distance is HORIZONTAL (Y zeroed on both vectors). The service fires `onEscaped` once per bag and
re-arms when the duffel returns to 0.

## The suite tripwire is NAMES, not counts

The totals are not deterministic here: `SupplyObject`'s "countdown ticks down over real time" test is
a wall-clock test that flips between pass and fail depending on Studio's render state. Judge your
work by the SET of failing suite names. Permitted after your task:

    World x1 (ClaimZone floor)         RestaurantConfig x1 (CooldownDuration)
    Gas2GoConfig x1 (CooldownDuration) CashClaimVFX x12 (WaitForChild on nil)
    SupplyObject x0 or x1 (flaky)      Getaway 0 failed
    LocationServer 0 failed  <-- yours, must be green

A failure in any other suite is a regression you caused. Report failing names explicitly.

## Report contract

Full report to `/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/task-4-report.md`:
the before/after of every edit site; the exact shape `makeRig` returns after your change; the full
failing run from Step 2 and the full passing run from Step 8; and a list of EVERY test you rewrote
with its old and new driving mechanism.

Return to me ONLY: status, the `LocationServer` suite line, the TOTAL line, the names of any failing
suites, and concerns. Do not paste the report back.
