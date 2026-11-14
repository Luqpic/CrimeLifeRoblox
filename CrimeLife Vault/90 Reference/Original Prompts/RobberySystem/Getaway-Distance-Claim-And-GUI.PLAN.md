# Getaway Distance Claim + Escape GUI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Claim-zone cash-out with a distance-based getaway — cash banks when the player gets 200 studs clear of the location they robbed — and add a HUD widget counting the studs down.

**Architecture:** A new shared `Heist.Services.Getaway` service owns the distance gate and is driven from the heartbeat both `HeistServer` (Bank) and `LocationServer` (the other three) already run, so the payout gate exists once rather than twice. The client renders studs-remaining locally from data it already receives, adding no remote; the server independently computes the same number as the authority.

**Tech Stack:** Roblox Luau, Roblox Studio MCP (`script_read`, `script_grep`, `multi_edit`, `execute_luau`, `start_stop_play`, `screen_capture`), the in-place `TestRunner`/`RunAll` spec suite, Figma MCP + REST `/v1/images` for slice export.

**Spec:** `/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/Getaway-Distance-Claim-And-GUI.md` — read it before starting. This plan argues from it and does not restate its confirmed-context section.

## Global Constraints

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

## Baseline — the suite is NOT green before you start

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

## File Structure

| Path | Responsibility | Task |
|---|---|---|
| `ReplicatedStorage.SharedSystems.UITheme` | **Modify** — pin the two new slice ids + 1x sizes | 1 |
| `ServerScriptService.Heist.Services.Getaway` | **Create** — the distance gate; pure logic, no workspace reads | 2 |
| `ServerScriptService.Heist.Tests.GetawaySpec` | **Create** — unit tests for the above | 2 |
| `ServerScriptService.Heist.Tests.RunAll` | **Modify** — register `GetawaySpec` | 2 |
| `ReplicatedStorage.HeistShared.Config` | **Modify** — `EscapeDistance = 200` | 3 |
| `ReplicatedStorage.RestaurantShared.Config` | **Modify** — `EscapeDistance = 200` | 3 |
| `ReplicatedStorage.Gas2GoShared.Config` | **Modify** — `EscapeDistance = 200` | 3 |
| `ReplicatedStorage.NewsStationShared.Config` | **Modify** — `EscapeDistance = 200` | 3 |
| `ServerScriptService.Heist.Services.LocationServer` | **Modify** — construct+drive Getaway, delete Claim handler | 4 |
| `ServerScriptService.Heist.Tests.LocationServerSpec` | **Modify** — claim tests drive distance, not zone entry | 4 |
| `ServerScriptService.HeistServer` | **Modify** — same wiring for the Bank | 5 |
| `StarterPlayer.StarterPlayerScripts.HeistClient` | **Modify** — getaway widget + timer un-gating | 6 |
| `ServerScriptService.Heist.Tests.WorldSpec` | **Modify** — zone manifest counts | 7 |
| 4× `*ClaimZone` parts in Workspace | **Delete** — with approval | 7 |

---

## Task 1: Figma design, export, and `UITheme` pinning

Done first because it has the external dependencies (OAuth, export, upload) and because Task 6 cannot reference asset ids that do not exist yet.

**Files:**
- Figma: file `Roblox`, page `02 · Redesign`
- Modify: `ReplicatedStorage.SharedSystems.UITheme`

**Interfaces:**
- Produces: `UITheme.Assets.GetawayNormal`, `UITheme.Assets.GetawayNear` (rbxassetid strings) and `UITheme.Size.GetawayNormal`, `UITheme.Size.GetawayNear` (both `Vector2.new(240, 76)`). Task 6 consumes these exact names.

- [ ] **Step 1: Confirm the Figma account**

Call `whoami`. The email must be `muhammadluqmanhayyan@gamuda.tech`. If it is `luqmanhayyandrive@gmail.com`, **stop** — that account has a View seat and returns a hollow file (pages present, `childCount: 0`, no components, no variables) with no error at all. Tell the user to sign out of figma.com in the browser and re-authenticate via `/mcp` → figma.

- [ ] **Step 2: Read the existing timer slice as the reference**

Open file `Roblox`, page `02 · Redesign`, and locate the existing timer frames. The new widget must match their construction so the two read as a pair on screen. Use the library tokens, not new values:

```
accent #CBF23C   accentDim #9FC024   panel #171A22   raised #1E222C
inset  #12141A   deep      #0E1016   line  #2A2F3C   muted #8A92A6
gold   #FFD54A   danger    #FF4B4B
Fonts: Archivo Black (display), Barlow Semi Condensed SemiBold/Medium (UI/body)
```

- [ ] **Step 3: Build the `GetawayNormal` frame — 240×76**

Contents, all baked except where noted:
- `GET AWAY` caption, same position/weight as the timer's baked `TIME REMAINING`.
- The accent edge matching the timer's.
- A `STUDS` unit label, right side of the number row. **It is static text, so it is baked.**
- **Empty space** on the number row (the timer's label geometry is offset 34,12, size 190×32) for the live number, which will right-align against `STUDS`.
- A slim empty progress **track** in the ~32px band below the number row. Design the track only — the fill is a live `Frame`.

- [ ] **Step 4: Build the `GetawayNear` frame — 240×76**

Identical geometry, recoloured for the near-complete state. Use `gold #FFD54A`, **not** `danger #FF4B4B` — nearing the threshold is good news for the player, so this mirrors the duffel widget's `DuffelFull` gold state, not the timer's red urgency state.

- [ ] **Step 5: Export both at 4x and upload**

Export through the REST `/v1/images` endpoint at 4x, serve the files over a local `http.server`, and upload with `upload_image`. 240×76 at 4x is 960×304 — under Roblox's 1024px texture cap, so 4x is safe here. Verify each upload returns an asset id before continuing.

- [ ] **Step 6: Pin both in `UITheme`**

Read `ReplicatedStorage.SharedSystems.UITheme` first and match the existing `TimerNormal`/`TimerUrgent` entries' formatting exactly. Add to the `Assets` table and the `Size` table (and the third table that holds `TimerNormal = Vector2.zero` — check what it is and whether a body offset applies; the getaway widget has no overhanging ribbon, so it should be `Vector2.zero` like the timer).

- [ ] **Step 7: Verify the assets resolve in Studio**

```lua
-- execute_luau, datamodel_type "Edit"
local UITheme = require(game.ReplicatedStorage.SharedSystems.UITheme)
return string.format("GetawayNormal=%s size=%s | GetawayNear=%s size=%s",
	tostring(UITheme.Assets.GetawayNormal), tostring(UITheme.Size.GetawayNormal),
	tostring(UITheme.Assets.GetawayNear), tostring(UITheme.Size.GetawayNear))
```

Expected: two `rbxassetid://` strings and two `240, 76` vectors. A `nil` here means Step 6 did not land.

- [ ] **Step 8: Run the suite**

Expected: `579 passed, 16 failed` — unchanged. `UITheme` is data only; if this moved, something else broke.

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

## Task 3: `EscapeDistance = 200` in all four configs

**Files:**
- Modify: `ReplicatedStorage.HeistShared.Config`, `ReplicatedStorage.RestaurantShared.Config`, `ReplicatedStorage.Gas2GoShared.Config`, `ReplicatedStorage.NewsStationShared.Config`

**Interfaces:**
- Produces: `Config.EscapeDistance` (number) on all four modules. Tasks 4, 5 and 6 read it.

- [ ] **Step 1: Read all four configs**

Read each before editing and place `EscapeDistance` beside the other session tunables (`SessionDuration`, `DuffelCap`, `CooldownDuration`), matching each file's own formatting and comment style. They differ — do not paste one shape into all four.

- [ ] **Step 2: Add the field with its reasoning comment**

In each of the four, add:

```lua
	-- Studs the player must get from this location's StatusBillboardAnchor,
	-- measured horizontally and only once clear of the building, before a
	-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
	-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
	-- neighbouring locations 165-205 apart it reads as "about one block over"
	-- without pushing the player through another location's grounds.
	-- A starting value, not a tuned one -- expect to adjust after playtesting.
	-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
	-- from inside the vault if Getaway's inside-the-building gate were ever
	-- removed. See Getaway's own header.
	EscapeDistance = 200,
```

- [ ] **Step 3: Verify all four resolve**

```lua
local RS = game:GetService("ReplicatedStorage")
local out = {}
for _, n in ipairs({"HeistShared","RestaurantShared","Gas2GoShared","NewsStationShared"}) do
	table.insert(out, n .. ".EscapeDistance = " .. tostring(require(RS[n].Config).EscapeDistance))
end
return table.concat(out, "\n")
```

Expected: four lines reading `200`. A `nil` means that file's edit did not land.

- [ ] **Step 4: Run the suite**

Expected: still `593 passed, 16 failed`. **If `ConfigSpec`, `RestaurantConfigSpec`, `Gas2GoConfigSpec` or `NewsStationConfigSpec` gains a failure**, that spec asserts an exact key set — add `EscapeDistance` to its expectations rather than removing the field.

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

## Task 5: Wire `Getaway` into `HeistServer` (the Bank)

**Files:**
- Modify: `ServerScriptService.HeistServer`

**Interfaces:**
- Consumes: `Getaway.new/:Step` (Task 2), `Config.EscapeDistance` (Task 3).

The Bank is deliberately not a `LocationServer` consumer — see that module's header for the four still-valid reasons. This task repeats the wiring rather than migrating the Bank.

- [ ] **Step 1: Extract the Bank's claim body**

`HeistServer` is a flat Script, not a class, so this is a local function rather than a method. Place it immediately above the handler it replaces:

```lua
-- The payout, moved verbatim out of the old claim-zone Entered handler
-- (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
local function bankBag(player)
	local amount = bank:Claim(player)
	if amount <= 0 then return end
	local banked = math.floor(amount)
	currency:Add(player.UserId, banked)
	net:Toast(player, string.format("Banked %d %s.", banked, Config.CurrencyName))
	-- Cash burst + flying-cash-GUI trigger (spec addendum, 2026-09-09) --
	-- fired after currency:Add so leaderstats.Cash.Value has already
	-- replicated the new total by the time the client reacts to this.
	net:NotifyRobberySuccess(player)
end
```

- [ ] **Step 2: Construct the Getaway with the Bank's three-role union**

Place it after `updateZoneOccupancy` is defined, so the union expression can be shared rather than written twice:

```lua
-- Same union updateZoneOccupancy uses: Lobby OR Vault OR BankVaultZone --
-- the lobby, the vault, and the whole underground gauntlet between them.
-- This gate is what makes the Bank correct: its VaultZone is 314 studs
-- horizontally from its own StatusBillboardAnchor, so without it an
-- EscapeDistance of 200 would bank the bag the instant it filled, with no
-- getaway at all.
local function isInsideBank(player)
	return zoneService:IsInside("Lobby", player)
		or zoneService:IsInside("Vault", player)
		or zoneService:IsInside("BankVaultZone", player)
end

local bankAnchor = workspace:WaitForChild("HeistMarkers"):WaitForChild("StatusBillboardAnchor")
local getaway = Getaway.new({
	escapeDistance = Config.EscapeDistance,
	anchor = bankAnchor,
	isInsideBuilding = isInsideBank,
	getDuffel = function(player) return bank:GetDuffel(player) end,
	getPlayers = function() return Players:GetPlayers() end,
	onEscaped = bankBag,
})
```

Refactor `updateZoneOccupancy` to call `isInsideBank(player)` instead of repeating the three `IsInside` calls inline, so the union lives in one place. Add `local Getaway = require(Heist.Services.Getaway)` to the requires at the top.

- [ ] **Step 3: Drive it and delete the Claim handler**

Add `getaway:Step()` to the same heartbeat body that already calls `updateZoneOccupancy()`.

Delete the `zoneService.Entered` handler beginning `if role ~= "Claim" then return end`, together with its `-- Cash-out on crossing into the lobby, per spec 6.4: automatic, no prompt.` comment.

- [ ] **Step 4: Fix the Bank's refusal message**

Change `cap_exceeded = "Duffel Full — head back to claim it."` (note: the Bank's copy uses an em dash where `LocationServer`'s uses `--`) to `"Duffel Full — get clear of the building to bank it."`.

- [ ] **Step 5: Confirm the Bank boots**

```lua
-- execute_luau, datamodel_type "Edit" -- a syntax/require check, not a run
local ok, err = pcall(function()
	return game.ServerScriptService.HeistServer.Source:len()
end)
return "HeistServer readable=" .. tostring(ok)
```

Then enter Play mode via `start_stop_play` and read `get_console_output`. Expected: no `[HeistServer]` assertion and no `Getaway requires ...` error. **The boot asserts still expect the Claim zone at this point — that is Task 7's job, and it must still pass here.**

- [ ] **Step 6: Run the suite**

Expected: `593 passed, 16 failed`, unchanged.

---

## Task 6: The getaway widget in `HeistClient`

**Files:**
- Modify: `StarterPlayer.StarterPlayerScripts.HeistClient`

**Interfaces:**
- Consumes: `UITheme.Assets.GetawayNormal/GetawayNear`, `UITheme.Size.GetawayNormal` (Task 1); `Config.EscapeDistance` (Task 3).

No new remote. The client already receives `zoneOccupancy[location]`, the per-location duffel amount, `sessionStates[location]`, has the anchor Part resolved, and can read `EscapeDistance` from `ReplicatedStorage`. It computes and renders the distance locally every frame while the server independently computes the same number as the authority — the pattern the lockpick needle already uses, for the reason its own comment gives.

- [ ] **Step 1: Keep the anchor Parts when resolving marker folders**

The existing loop walks `folder → StatusBillboardAnchor → StatusBillboard → Badge → StatusImage` and retains only `StatusImage`. Add a parallel `locationAnchors[location] = anchor` so the Part itself survives. Keep the existing bounded `WaitForChild(..., 10)` and the degrade-with-a-`warn` behaviour — its comment explains why an unbounded wait would take the whole HUD down.

- [ ] **Step 2: Read `EscapeDistance` per location on the client**

The four config modules live in `ReplicatedStorage`, so map location name → config module alongside the existing `MARKER_FOLDERS` table and read `.EscapeDistance` from each. Do not hardcode 200 in the client — Task 3 put it in the configs precisely so both sides read one number.

- [ ] **Step 3: Insert the widget's slot into the derived position chain**

The chain's own comment says a size change must move everything below it automatically. Extend it rather than adding a literal:

```lua
local HUD_TOP, HUD_GUTTER = 12, 8
local TIMER_POSITION   = UDim2.new(0.5, 0, 0, HUD_TOP)
local DUFFEL_TOP       = HUD_TOP + 76 + HUD_GUTTER            -- below the 76px timer
local DUFFEL_POSITION  = UDim2.new(0.5, 0, 0, DUFFEL_TOP)
local GETAWAY_TOP      = DUFFEL_TOP + 92 + HUD_GUTTER         -- below the 92px duffel
local GETAWAY_POSITION = UDim2.new(0.5, 0, 0, GETAWAY_TOP)
local TOAST_POSITION   = UDim2.new(0.5, 0, 0, GETAWAY_TOP + 76 + HUD_GUTTER) -- below the 76px getaway
```

`TOAST_CENTER` is derived from `TOAST_POSITION`, so the cash-burst origin follows automatically — verify it still computes, do not hand-adjust it.

- [ ] **Step 4: Build one widget per location**

In the same `for _, location in ipairs(LOCATIONS)` loop that builds `timerWidgets` and `duffelWidgets`, using the same `imagePanel` helper. Two live children: the right-aligned studs `TextLabel` (matching the timer's `Time` geometry — offset 34,12, size 190×32, `UITheme.Font.Display`, `TextSize` 28, `TextXAlignment = Enum.TextXAlignment.Right`, `ZIndex` 2) and the bar's fill `Frame` inside the track band. Store as `getawayWidgets[location] = { root = ..., studs = ..., fill = ... }` so `setFillRatio` works on it unchanged — that helper reads `widget.fill`, `widget._lastRatio` and `widget._fillTween`.

- [ ] **Step 5: Render it in the existing `RenderStepped` loop**

Inside the existing per-location loop, after the duffel block:

```lua
		-- Getaway distance (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
		-- Computed locally every frame from the same inputs the server's own
		-- Getaway service uses, rather than pushed per-tick -- same reasoning
		-- as the lockpick needle's local animation.
		local getawayWidget = getawayWidgets[location]
		local anchor = locationAnchors[location]
		local escapeDistance = escapeDistances[location]
		local character = player.Character
		local root = character and character.PrimaryPart

		local remaining = nil
		if anchor and root and escapeDistance
			and session.state == "Active" and amount > 0 and not zoneOccupancy[location] then
			local here = Vector3.new(root.Position.X, 0, root.Position.Z)
			local there = Vector3.new(anchor.Position.X, 0, anchor.Position.Z)
			remaining = math.max(0, escapeDistance - (here - there).Magnitude)
		end
		getawayRemaining[location] = remaining
```

Then, **after** the location loop closes, pick the single most urgent one and drive only that widget — see Step 6.

- [ ] **Step 6: Show only one getaway widget at a time**

Every location's HUD elements rest at the same on-screen position. That is safe for the timer because it is zone-gated, but escaping is by definition outside all zones, so two simultaneous sessions would stack two getaway widgets on one spot. After the per-location loop, choose the location with the smallest non-nil `getawayRemaining` and slide only that one in; slide every other location's out. Use the same edge-triggered `getawayShown[location]` guard the timer and duffel already use, with `UITransitions.SlideIn`/`SlideOut` against `GETAWAY_POSITION`.

For the chosen location:
- `widget.studs.Text = commas(remaining)` — reuse the existing formatter.
- `setFillRatio(widget, math.clamp(1 - remaining / escapeDistance, 0, 1))` — progress *covered*, so the bar fills as they run. Guard the divide against a zero `escapeDistance`.
- Near-complete swap at `remaining <= escapeDistance * 0.25`, guarded on an actual change because the loop runs every frame and reassigning `.Image` re-triggers a texture fetch:

```lua
			local near = remaining <= escapeDistance * 0.25
			local wantImage = near and UITheme.Assets.GetawayNear or UITheme.Assets.GetawayNormal
			if widget.root.Image ~= wantImage then
				widget.root.Image = wantImage
				widget.studs.TextColor3 = near and UITheme.Color.gold or UITheme.Color.accent
				widget.fill.BackgroundColor3 = near and UITheme.Color.gold or UITheme.Color.accent
			end
```

- [ ] **Step 7: Keep the heist timer on screen during the escape**

`wantTimer` is currently:

```lua
		local wantTimer = (session.state == "Active" and session.endsAt ~= nil and zoneOccupancy[location])
```

Change the last term to `(zoneOccupancy[location] or amount > 0)`. **Do not simply drop `zoneOccupancy`** — the 2026-09-06 addendum deliberately removed "a heist is active somewhere", and un-gating it unconditionally reinstates exactly that. The added term is the escaping player specifically, identified by holding a bag from this location.

Note `amount` is computed in the duffel block *below* the timer block today. Hoist its `extrapolate(...)` call above the timer block, or read `duffelStates[location]` directly — do not duplicate the extrapolation.

- [ ] **Step 8: Verify in Play mode**

`start_stop_play`, then `get_console_output`. Expected: no `HeistClient` errors and no `nil` index on the new tables. Then `screen_capture` the HUD with a bag in hand outside a building and confirm the widget renders with a number, a filling bar, and the timer still visible above it.

- [ ] **Step 9: Run the suite**

Expected: `593 passed, 16 failed`. `HeistClient` is not unit-tested, so this is a no-regression check on everything else.

---

## Task 7: Retire the Claim zones

**Files:**
- Modify: `ServerScriptService.HeistServer` (boot asserts)
- Modify: `ServerScriptService.Heist.Tests.WorldSpec`
- Delete: 4 world parts — **with approval**

- [ ] **Step 1: Confirm nothing still reads the Claim role**

```lua
-- Expect zero hits on ZONE-ROLE uses. BankInstance:Claim, CashClaimVFX and
-- RobberySuccess legitimately keep the name -- the point is to catch any
-- zone-role reference the spec did not enumerate.
```

Run `script_grep` for `Claim` and read every hit. Anything still branching on `ZoneRole == "Claim"` or `role ~= "Claim"` must be gone before deleting the parts.

- [ ] **Step 2: Ask the user before deleting anything**

Present exactly these four parts and get explicit approval. Do not proceed on silence, and do not batch this with any other approval.

| Part | Position |
|---|---|
| `Workspace.HeistZones.ClaimZone` | 109.6, 18.5, -131.4 |
| `Workspace.SlowFoodsZones.RestaurantClaimZone` | 45, 7, -272.4 |
| `Workspace.Gas2GoZones.Gas2GoClaimZone` | -101.4, 11.2, -240 |
| `Workspace.NewsStationZones.NewsStationClaimZone` | -215, 7, -269.6 |

- [ ] **Step 3: Update `HeistServer`'s boot validation**

Change `assert(#zones == 6, ...)` to `5` and update its message from `(Lobby, Vault, Claim, 3x BankVaultZone)` to `(Lobby, Vault, 3x BankVaultZone)`. Drop `roles.Claim` from the role assert and `Claim` from its message. Update the `-- 3 original (Lobby, Vault, Claim) + 3 BankVaultZone volumes` comment above it.

- [ ] **Step 4: Delete the four parts**

Only after Step 2's approval.

- [ ] **Step 5: Update `WorldSpec`**

Read the per-location zone manifest assertions and correct the counts. Do not guess which ones move — run the suite and let it tell you.

- [ ] **Step 6: Run the suite**

Expected: `593 passed, 15 failed`. **The count drops by one**: the pre-existing `WorldSpec` failure `ClaimZone: no floor found within 6 studs` disappears with the part. That is the single legitimate change to the baseline in this whole plan. If any *other* baseline failure vanished or appeared, investigate.

- [ ] **Step 7: Confirm a clean boot**

`start_stop_play` and read `get_console_output`. Expected: no `[HeistServer] expected exactly N HeistZone parts` assertion.

---

## Task 8: Play-mode verification at all four locations

Script-level correctness is not sufficient — this changes the core payout loop.

- [ ] **Step 1: SlowFoods, Gas2Go, NewsStation — full run each**

For each: trigger the robbery, fill a bag, leave the building, and confirm the widget appears, counts down, fills its bar, swaps to the gold near-complete bake in the last 50 studs, and that the cash banks at 0 with the existing toast and cash burst. `screen_capture` each.

- [ ] **Step 2: The Bank — the regression this whole design guards against**

Trigger the Bank robbery, fill the bag in the vault, and confirm **no payout happens** while anywhere in the vault or the underground gauntlet, despite being up to 314 studs horizontally from the anchor. Then return to the lobby, exit, and confirm the run banks normally. **If the Bank pays out underground, `isInsideBank` is wrong — stop and fix it before continuing.**

- [ ] **Step 3: Timer visibility**

Confirm the heist timer stays on screen during the escape run and still slides away when the session ends.

- [ ] **Step 4: Reachability of 200 studs from every location**

The map is only ~490 studs across at its widest. Walk each location's escape in a couple of directions and confirm 200 studs of walkable space genuinely exists. **If any location cannot reach it, report that rather than quietly lowering `EscapeDistance`** — it is the user's call.

- [ ] **Step 5: Failure path**

Let a session expire mid-escape. Confirm the bag is lost with the existing "Run failed"/"died" messaging and **no cash is credited**.

- [ ] **Step 6: Final suite run and honest report**

Run the suite once more and report the actual numbers. Expected `593 passed, 15 failed`, with the 15 being the baseline table minus the `WorldSpec` ClaimZone row. Report any deviation rather than explaining it away.

---

## After the plan: the changelog

Once this is confirmed working in Studio, write one changelog MD into `/Users/luqpic/Documents/Roblox/RobloxFPSsystem/RobberySystem/` in the established format (`# Change Log: <Title>`, **Date**/**Status**, `## Summary`, `## Changes`, `## Notes`), then `git add` + commit + push **that one file by itself**. Never batch it with another.

Be honest in the Status line about what was actually confirmed live versus only drafted. Two findings belong in the `## Notes` section as known, deliberately-unfixed issues:

- The `CashClaimVFX` 12-test failure and its diagnosed cause (`freshRequire` destroys the clone before the lazy in-function `require(script.Parent...)` runs). Live game unaffected; one-line fix is hoisting the require to module scope.
- The duffel widget's pre-existing multi-location overlap: its visibility is deliberately not zone-gated, so two simultaneous sessions already stack two widgets at one HUD position. The getaway widget avoids this by rendering only the most urgent location; the duffel widget was left alone as a separate fix.
