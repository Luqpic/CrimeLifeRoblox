# Task 2 brief — the Getaway service (TDD)

## Global Constraints (bind every step)

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

## Baseline — the suite is NOT green before you start

— the suite is NOT green before you start

Measured on 2026-09-19 immediately before this plan was written:

```
TOTAL: 579 passed, 16 failed
```

The 16 pre-existing failures, none of which this feature causes:

| Spec | Count | Failure |
|---|---|---|
| `WorldSpec` | 1 | `ClaimZone: no floor found within 6 studs of the zone's own bottom` |
| `RestaurantConfigSpec` | 1 | `CooldownDuration — expected 1200, got 60` |
| `Gas2GoConfigSpec` | 1 | `CooldownDuration — expected 600, got 60` |
| `CashClaimVFXSpec` | 12 | all `CashClaimVFX:176: attempt to index nil with 'WaitForChild'` |
| `SupplyObjectSpec` | 1 | `countdown ... hidden once the countdown reaches 0 — expected truthy, got false` |

**Root cause of the `CashClaimVFX` cluster, already diagnosed — do not re-investigate:** `TestRunner.freshRequire` clones a module, requires it, then `clone:Destroy()`s it. `CashClaimVFX:_buildPersistentGui` does its `require(script.Parent:WaitForChild("UITheme"))` lazily *inside the function*, which the test calls after the clone is destroyed — so `script.Parent` is nil. The live game is unaffected because the real module is never destroyed. **Out of scope. Do not fix it as part of this work; report it instead.**

**The `WorldSpec` ClaimZone failure is expected to disappear in Task 7** when that part is deleted. That is the one baseline number this plan legitimately changes.

**From Task 2 onward the target is `593 passed, 16 failed`** (579 + the 14 new `GetawaySpec` tests). Task 7 changes it to `593 passed, 15 failed`, and that is the only legitimate change to these numbers in the whole plan. Any *new* failure name not in the table above is a regression you introduced.

### How to run the suite

```lua
-- execute_luau, datamodel_type "Edit"
local RunAll = require(game.ServerScriptService.Heist.Tests.RunAll)
local ok, res = pcall(RunAll)
return "ok=" .. tostring(ok) .. "\n" .. tostring(res)
```

Confirmed working: `require` and creating/parenting `ModuleScript`s with `.Source` both succeed from `execute_luau`. (Earlier project notes claiming otherwise are stale.)

---

## Task 2: The `Getaway` service (TDD)

**Files:**
- Create: `ServerScriptService.Heist.Services.Getaway`
- Create: `ServerScriptService.Heist.Tests.GetawaySpec`
- Modify: `ServerScriptService.Heist.Tests.RunAll`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Getaway.new(cfg) -> Getaway`, `Getaway:Step()`, `Getaway:DistanceRemaining(player) -> number?`, `Getaway:Forget(player)`.
  `cfg` fields: `escapeDistance: number`, `anchor: BasePart` **or** `getAnchorPosition: () -> Vector3`, `isInsideBuilding: (player) -> boolean`, `getDuffel: (player) -> number`, `onEscaped: (player) -> ()`, `getPlayers: () -> {player}`, optional `getPosition: (player) -> Vector3?`.
  Tasks 4 and 5 construct this; Task 4 also stubs it in specs.

- [ ] **Step 1: Write the failing spec**

Create `ServerScriptService.Heist.Tests.GetawaySpec` as a `ModuleScript`:

```lua
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local Getaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Getaway)
	local suite = TestRunner.new("Getaway")

	-- The anchor sits 136 studs ABOVE the origin, mirroring the Bank's real
	-- StatusBillboardAnchor (Y=136.4 over a lobby at Y=18.5). Every distance
	-- assertion below is therefore also a regression test that Y is ignored.
	local ANCHOR = Vector3.new(0, 136, 0)

	local function makeRig(overrides)
		overrides = overrides or {}
		local state = {
			duffels = { p1 = 1000 },
			inside = { p1 = false },
			positions = { p1 = Vector3.new(0, 0, 0) },
			escaped = {},
		}
		local cfg = {
			escapeDistance = 200,
			getAnchorPosition = function() return ANCHOR end,
			isInsideBuilding = function(player) return state.inside[player] == true end,
			getDuffel = function(player) return state.duffels[player] or 0 end,
			getPosition = function(player) return state.positions[player] end,
			getPlayers = function() return { "p1" } end,
			onEscaped = function(player)
				table.insert(state.escaped, player)
				-- Mirrors the real consumer: bank:Claim zeroes the bag.
				state.duffels[player] = 0
			end,
		}
		for k, v in pairs(overrides) do cfg[k] = v end
		return Getaway.new(cfg), state
	end

	-- THE Bank test. Its VaultZone is 314 studs horizontally from its own
	-- anchor, so without the inside-the-building gate the Bank would pay out
	-- the instant cash entered the bag, with no getaway at all.
	suite:test("does not fire while still inside the building, however far away", function(expect)
		local getaway, state = makeRig()
		state.inside.p1 = true
		state.positions.p1 = Vector3.new(314, 56, 0)

		getaway:Step()

		expect.equal(#state.escaped, 0, "no payout from inside the vault")
	end)

	suite:test("does not fire without a bag", function(expect)
		local getaway, state = makeRig()
		state.duffels.p1 = 0
		state.positions.p1 = Vector3.new(500, 0, 0)

		getaway:Step()

		expect.equal(#state.escaped, 0, "nothing to bank")
	end)

	suite:test("fires once the player is outside and past the distance", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(200, 0, 0)

		getaway:Step()

		expect.equal(#state.escaped, 1, "banked")
		expect.equal(state.escaped[1], "p1", "the right player")
	end)

	-- 3D distance from this position would be sqrt(199^2 + 136^2) = 241, which
	-- is past the 200 threshold. Horizontal distance is 199, which is not.
	suite:test("measures horizontally: the anchor's height never counts toward the run", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(199, 0, 0)

		getaway:Step()

		expect.equal(#state.escaped, 0, "199 horizontal studs is short of 200")
	end)

	suite:test("fires exactly once per bag, not once per tick", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()
		getaway:Step()
		getaway:Step()

		expect.equal(#state.escaped, 1, "one payout")
	end)

	suite:test("re-arms for a second bag after the first is banked", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()          -- banks bag one, duffel -> 0
		state.duffels.p1 = 500  -- robbed again
		getaway:Step()

		expect.equal(#state.escaped, 2, "both bags banked")
	end)

	-- Guards the case where onEscaped does NOT zero the bag -- bank:Claim
	-- returns 0 when the session is no longer Active. Without the latch this
	-- would re-fire every heartbeat for the rest of the session.
	suite:test("does not re-fire every tick when onEscaped leaves the bag alone", function(expect)
		local fired = 0
		-- Deliberately does NOT clear the duffel, unlike the default rig.
		local getaway, state = makeRig({ onEscaped = function() fired += 1 end })
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()
		getaway:Step()

		expect.equal(fired, 1, "latched after the first fire")
	end)

	suite:test("DistanceRemaining is nil inside, and counts down outside", function(expect)
		local getaway, state = makeRig()

		state.inside.p1 = true
		expect.equal(getaway:DistanceRemaining("p1"), nil, "nil while inside")

		state.inside.p1 = false
		state.positions.p1 = Vector3.new(50, 0, 0)
		expect.equal(getaway:DistanceRemaining("p1"), 150, "150 studs left")

		state.positions.p1 = Vector3.new(500, 0, 0)
		expect.equal(getaway:DistanceRemaining("p1"), 0, "clamped at zero, never negative")
	end)

	suite:test("DistanceRemaining is nil without a bag", function(expect)
		local getaway, state = makeRig()
		state.duffels.p1 = 0

		expect.equal(getaway:DistanceRemaining("p1"), nil, "nothing to escape with")
	end)

	suite:test("a missing character is not an escape and does not error", function(expect)
		local getaway, state = makeRig()
		state.positions.p1 = nil

		getaway:Step()

		expect.equal(#state.escaped, 0, "no position, no payout")
		expect.equal(getaway:DistanceRemaining("p1"), nil, "no position, no number")
	end)

	suite:test("Forget clears the latch", function(expect)
		local fired = 0
		local getaway, state = makeRig({ onEscaped = function() fired += 1 end })
		state.positions.p1 = Vector3.new(250, 0, 0)

		getaway:Step()
		getaway:Forget("p1")
		getaway:Step()

		expect.equal(fired, 2, "latch cleared, fires again")
	end)

	suite:test("accepts an anchor Part instead of a position function", function(expect)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(0, 136, 0)
		part.Parent = workspace

		local escaped = {}
		local getaway = Getaway.new({
			escapeDistance = 200,
			anchor = part,
			isInsideBuilding = function() return false end,
			getDuffel = function() return 1000 end,
			getPosition = function() return Vector3.new(250, 0, 0) end,
			getPlayers = function() return { "p1" } end,
			onEscaped = function(player) table.insert(escaped, player) end,
		})
		getaway:Step()

		expect.equal(#escaped, 1, "anchor Part resolved to its Position")
		part:Destroy()
	end)

	suite:test("rejects a construction missing its required dependencies", function(expect)
		local ok = pcall(function()
			return Getaway.new({ escapeDistance = 200 })
		end)
		expect.falsy(ok, "constructing without callbacks errors")
	end)

	suite:test("rejects a non-positive escapeDistance", function(expect)
		local ok = pcall(function()
			return Getaway.new({
				escapeDistance = 0,
				getAnchorPosition = function() return ANCHOR end,
				isInsideBuilding = function() return false end,
				getDuffel = function() return 0 end,
				getPlayers = function() return {} end,
				onEscaped = function() end,
			})
		end)
		expect.falsy(ok, "zero distance is a configuration error, not a free payout")
	end)

	return suite:run()
end
```

Register it in `RunAll`'s `SPECS` list, appended after `"LocationServerSpec"`.

- [ ] **Step 2: Run it and confirm it fails for the right reason**

```lua
local RunAll = require(game.ServerScriptService.Heist.Tests.RunAll)
return select(2, pcall(RunAll))
```

Expected: `Getaway: 0 passed, 14 failed`, every failure being the module not existing. If you see any *other* error, fix the spec before writing the implementation.

- [ ] **Step 3: Write the implementation**

Create `ServerScriptService.Heist.Services.Getaway`:

```lua
--!strict
-- Distance-based payout gate (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
--
-- Replaces the Claim-zone cash-out at all four locations. A bag banks when its
-- owner is clear of the building AND at least `escapeDistance` studs from the
-- location's anchor.
--
-- Two design points that are load-bearing, not incidental:
--
--   * Distance is HORIZONTAL. Every location's StatusBillboardAnchor floats
--     40-120 studs above its building so the billboard reads from ground
--     level; a 3D distance would credit that height as escape progress.
--
--   * `isInsideBuilding` is INJECTED rather than computed here. The Bank's
--     definition is a three-role union (Lobby OR Vault OR BankVaultZone --
--     the lobby, the vault, and the underground gauntlet between them) while
--     the other three are a single interior role. Both consumers already own
--     that expression; duplicating it here would be a third copy to drift.
--     It is also what keeps the Bank correct: its VaultZone is 314 studs
--     horizontally from its own anchor, so without this gate any
--     escapeDistance below ~314 would bank the bag the moment it filled.
--
-- Deliberately knows nothing about workspace, zones, currency or remotes: it
-- takes plain callbacks so GetawaySpec can drive it without a DataModel.

local Getaway = {}
Getaway.__index = Getaway

local function horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function Getaway.new(cfg)
	assert(type(cfg) == "table", "Getaway requires a config table")
	assert(type(cfg.escapeDistance) == "number" and cfg.escapeDistance > 0,
		"Getaway requires a positive escapeDistance")
	assert(type(cfg.isInsideBuilding) == "function", "Getaway requires isInsideBuilding")
	assert(type(cfg.getDuffel) == "function", "Getaway requires getDuffel")
	assert(type(cfg.onEscaped) == "function", "Getaway requires onEscaped")
	assert(type(cfg.getPlayers) == "function", "Getaway requires getPlayers")

	local getAnchorPosition = cfg.getAnchorPosition
	if not getAnchorPosition then
		local anchor = cfg.anchor
		assert(anchor, "Getaway requires either anchor (a BasePart) or getAnchorPosition")
		getAnchorPosition = function() return anchor.Position end
	end

	return setmetatable({
		escapeDistance = cfg.escapeDistance,
		getAnchorPosition = getAnchorPosition,
		isInsideBuilding = cfg.isInsideBuilding,
		getDuffel = cfg.getDuffel,
		onEscaped = cfg.onEscaped,
		getPlayers = cfg.getPlayers,
		-- A player mid-respawn has no character; treat that as "not escaped
		-- yet" rather than erroring -- this runs on a heartbeat and must not
		-- take the location's loop down mid-session.
		getPosition = cfg.getPosition or function(player)
			local character = player.Character
			local root = character and character.PrimaryPart
			return root and root.Position or nil
		end,
		-- Fired-once latch, same edge-triggered discipline as timerShown /
		-- duffelFullNotified elsewhere in this project. Needed even though
		-- onEscaped normally zeroes the bag, because bank:Claim returns 0 when
		-- the session is no longer Active -- without the latch that case would
		-- re-fire every tick for the rest of the session.
		_fired = {},
	}, Getaway)
end

-- Studs still needed before this player's bag banks, or nil when they are not
-- in a position to bank at all (no bag, still inside, no character). The
-- server does not transmit this -- the client computes the same number from
-- the same inputs. It exists so a spec can assert against what is rendered.
function Getaway:DistanceRemaining(player): number?
	if self.getDuffel(player) <= 0 then return nil end
	if self.isInsideBuilding(player) then return nil end
	local position = self.getPosition(player)
	if not position then return nil end
	local travelled = horizontalDistance(position, self.getAnchorPosition())
	return math.max(0, self.escapeDistance - travelled)
end

function Getaway:Step()
	for _, player in ipairs(self.getPlayers()) do
		if self.getDuffel(player) <= 0 then
			-- Bag gone (banked, voided or never had one): re-arm for the next.
			self._fired[player] = nil
		elseif not self._fired[player] and not self.isInsideBuilding(player) then
			local position = self.getPosition(player)
			if position then
				local travelled = horizontalDistance(position, self.getAnchorPosition())
				if travelled >= self.escapeDistance then
					self._fired[player] = true
					self.onEscaped(player)
				end
			end
		end
	end
end

function Getaway:Forget(player)
	self._fired[player] = nil
end

return Getaway
```

- [ ] **Step 4: Run the suite and confirm green**

Expected: `Getaway: 14 passed, 0 failed`, and `TOTAL: 593 passed, 16 failed`. The 16 must still be exactly the five names in the baseline table.

---

---

## Scope fence

You may create exactly two ModuleScripts and modify exactly one:
- CREATE `ServerScriptService.Heist.Services.Getaway`
- CREATE `ServerScriptService.Heist.Tests.GetawaySpec`
- MODIFY `ServerScriptService.Heist.Tests.RunAll` — append `"GetawaySpec"` to the `SPECS` list, after `"LocationServerSpec"`. Nothing else in that file.

Touch nothing else. `LocationServer`, `HeistServer`, `HeistClient`, the Config modules and the
ClaimZone parts all belong to later tasks. If you believe one of them must change for your tests
to pass, that is a finding to report, not an edit to make.

## The brief's code is complete — transcribe it

Both the spec and the implementation are given in full in the task text above. Use them verbatim.
They were written against the live codebase and the real `TestRunner` API (`TestRunner.new(name)`,
`suite:test(label, fn)`, `expect.equal(actual, expected, label)`, `expect.truthy`, `expect.falsy`,
`suite:run()`, `TestRunner.freshRequire(moduleInstance)`). Do not redesign them.

If you find a genuine bug in the given code while running it, fix it and say so clearly in your
report — but prefer the given code where it merely differs from your taste.

## Report contract

Write your full report to `/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/task-2-report.md`.
It must contain: confirmation both ModuleScripts exist at the right paths with the right ClassName;
the exact RunAll edit; the FULL output of the failing run from Step 2 and the passing run from
Step 4; and an explicit line comparing the final totals against the 579/16 baseline.

Return to me ONLY: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), the Getaway spec
line (e.g. "Getaway: 14 passed, 0 failed"), the TOTAL line, the NAMES of any failing suites, and any
concerns. Do not paste the report back.

## CORRECTION to the baseline section above — read this, it overrides the numbers

The integer counts in the Baseline section are NOT a reliable tripwire and you must not treat them
as one. Measured twice with no relevant change in between, the suite reported 579 passed / 16 failed
and then 580 passed / 15 failed. The test that flips is `SupplyObject`'s "the countdown ticks down
over real time and auto-hides/re-anchors when it reaches 0" — a wall-clock timing test whose result
depends on Studio's render state (this project's CLAUDE.md documents that RenderStepped reports 0
FPS with the viewport collapsed, so time-based tests are genuinely non-deterministic here).

**Judge your work by the SET OF FAILING SUITE NAMES, not the total.** The permitted set is:

    World x1 (the "ClaimZone: no floor found" case)
    RestaurantConfig x1 (CooldownDuration 1200 vs 60)
    Gas2GoConfig x1 (CooldownDuration 600 vs 60)
    CashClaimVFX x12 (all "attempt to index nil with 'WaitForChild'")
    SupplyObject x0 or x1 (the flaky timing test — either result is fine)

Plus, after your task, `Getaway` must be 14 passed / 0 failed. A failure in ANY OTHER suite is a
regression you caused, regardless of what the total says. Report the failing names explicitly.
