# Persistence Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make full progression — Spraypaint, skins, Cash, level, XP, kills, weapons, upgrades and loadout — survive a player leaving and rejoining, without ever overwriting a profile that failed to load.

**Architecture:** ProfileStore handles the DataStore and session locking. One module of ours, `ProfileGateway`, is the only thing that knows its API; it owns the session lifecycle and the retry-then-kick policy. Each of seven services keeps its current in-memory state as the live source during play, hydrating from the profile on join and mirroring into it on change.

**Tech Stack:** Roblox Luau. Vendored ProfileStore (MadStudioRoblox). Existing in-place test framework at `ServerStorage.UnitTest` (`RunUnitTest(filter, timeout)` returning `{run, passed, failed}`; assertions `expect.equal / truthy / falsy / near / throws / deepEqual`).

**Spec:** `docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md`

## Global Constraints

- **A profile that failed to load is NEVER written.** On failure: retry, then `player:Kick` with an explanatory message. Handing a player a blank profile and later saving it wipes an account while looking like a normal session. This rule outranks every other consideration in this plan.
- **Derived values never persist.** Excluded: `NextLevelXP` (computed by `LevelingConstants.xpToNextLevel`), a Tool's `SkinId` (stamped per grant), a weapon's damage attribute (computed from upgrade level), the catalogue entry attributes, and `SpraypaintService`'s `lastLevel` (a per-session baseline). A stored derivative outlives its source and then disagrees with it.
- **ProfileStore's API appears in exactly one module,** `ProfileGateway`. No service requires ProfileStore directly.
- **Services keep their current shape.** Each gains only a hydrate-on-join and mirror-on-change. No service's behaviour changes.
- **Every mirror site is guarded** so a persistence failure degrades to "this change was not saved" rather than breaking the gameplay path it sits in — the same rule Phases 1 and 2 applied to every cosmetics call site.
- **No trading, no cross-place data, no offline editing, no Robux→Spraypaint product, no leaderboards.**
- **Do not touch the Robbery System place or any `RobberySystem/` directory.**
- **British spelling in prose comments; comments explain WHY, never restate WHAT.**
- **Five of the seven services are `Script`s, not `ModuleScript`s.** `CashService`, `LevelingService`, `WeaponShopService`, `WeaponUpgradeService` and `KillStatsService` return nothing and keep every function `local`, so they **cannot be required and cannot be unit-tested**. Only `SpraypaintService` and `CosmeticsService` are ModuleScripts. Their adoption is therefore verified LIVE — real join, real earn, real rejoin — not by unit test. Do NOT convert them to ModuleScripts: that is a refactor of five working services, and this phase changes where state comes from, not what any service does.
- **The place is UNPUBLISHED.** `PlaceId = 0`; `DataStoreService` is unreachable. ProfileStore detects this and substitutes an in-memory mock, so everything here is buildable and testable. Two rows of the spec's verification table are DEFERRED and must be reported as deferred, never as passing.

## ProfileStore API — exact, verified against the official docs

```
ProfileStore.New(store_name: string, template: table?) --> ProfileStore
ProfileStore.Mock                                       --> a parallel store on a fake DataStore
ProfileStore:StartSessionAsync(profile_key: string, params: { Cancel: (() -> boolean)?, Steal: boolean? }?) --> Profile?
Profile.Data          : table      -- the mutable progress table
Profile.OnSessionEnd  : Signal     -- fires when the session ends, including when stolen
Profile:EndSession()               -- stops auto-saving and performs a final save
Profile:IsActive()    : boolean    -- whether changes will still be saved
Profile:Reconcile()                -- fills fields missing from the template
Profile:AddUserId(user_id: number) -- GDPR association
```

`StartSessionAsync` returns **nil** when another server is contending for the same key. The official
guidance is to kick, which is also this phase's chosen policy.

**Never pass `Steal = true` for normal player loads.** The docs warn it bypasses the session lock that
prevents duplication. It is not used anywhere in this plan.

## The medium — read before touching anything

The code lives inside a running Roblox Studio place, not in this git repo, reached through
`mcp__Roblox_Studio__execute_luau` (`datamodel_type` = "Edit" / "Server" / "Client", capitalised, plus
`code`). `FPSSystem/**/*.luau` files are MIRRORS exported from Studio.

**Seven traps, each of which has already cost real time on this project:**

1. `string.gsub` with `(`, `)`, `.` or `-` in the pattern silently replaces NOTHING and raises no error. After ANY Source edit, read the Source back, assert the byte length moved as expected, and confirm the new text is present with `string.find(src, needle, 1, true)` — the plain-find flag. Also confirm the OLD text is gone.
2. Studio's EDIT-mode module cache serves STALE modules and has produced convincing FALSE test failures here. Run tests in a PLAY session; it is authoritative.
3. `execute_luau`'s `require()` runs in a context isolated from the live game. Do not monkey-patch a module and expect running scripts to see it; do not call a module directly to "test" it — drive verification through genuine engine events. A previous agent silently created a second, never-fed GUI this way.
4. `RunUnitTest` returns a table `{run, passed, failed}` — `tostring()` on it prints an address, not a count. Read the fields.
5. `RunUnitTest` filters by PLAIN SUBSTRING with no anchoring, so a case name that is a superstring of another collides. Check your filter isolates what you think.
6. `screen_capture` returns a magenta placeholder — no visual checks are possible.
7. A search for a symbol will match COMMENTS that document its absence. This has caused two false conclusions here already (`DataStoreService` and `UIListLayout`). When a grep says a thing is present, confirm it is code.

## Running tests

Cases are ModuleScripts at `ServerStorage.UnitTest.Cases.<Name>_Test` returning `function(t)`, using
`t.test(name, fn)` and `t.expect`. Run in a Play session, Server datamodel:

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
local r = run("Profile")
return string.format("run=%d passed=%d failed=%d", r.run, r.passed, r.failed)
```

Start and stop Play with `mcp__Roblox_Studio__start_stop_play`, leaving Studio in Edit mode.

**Every test in this plan uses `ProfileStore.Mock`**, which operates on a fake DataStore forgotten at
server shutdown. That is what makes this phase testable on an unpublished place.

---

## File Structure

| Path | Responsibility |
|---|---|
| `ServerStorage.ProfileStore` (ModuleScript) | Vendored third party. Never edited. |
| `ReplicatedStorage.Persistence.Schema` (ModuleScript) | The profile template and `VERSION`. Data only. |
| `ServerScriptService.Persistence.Scripts.ProfileGateway` (ModuleScript) | Session lifecycle, retry-then-kick, never-save-unloaded |
| `ServerScriptService.Persistence.Scripts.PersistenceRunner` (Script) | Requires the gateway so its player hooks connect |
| `ServerStorage.UnitTest.Cases.Schema_Test` | Task 1 |
| `ServerStorage.UnitTest.Cases.ProfileGateway_Test` | Tasks 2 and 6 |
| `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` | Tasks 3, 4, 5 |

Modified: `SpraypaintService`, `CosmeticsService`, `CashService`, `LevelingService`, `KillStatsService`,
`WeaponShopService`, `WeaponUpgradeService` — two call sites each.

Mirrors go to `FPSSystem/Persistence/`.

---

## Task 1: The schema, and ProfileStore vendored

**Files:**
- Create: `ServerStorage.ProfileStore` (ModuleScript, vendored)
- Create: `ReplicatedStorage.Persistence.Schema` (ModuleScript)
- Test: `ServerStorage.UnitTest.Cases.Schema_Test`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `Schema.VERSION: number` — currently 1
  - `Schema.template: { [string]: any }` — the profile defaults
  - `Schema.DERIVED: { string }` — field names that must NEVER be persisted

- [ ] **Step 1: Vendor ProfileStore**

Fetch `https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/ProfileStore.luau` and create
`ServerStorage.ProfileStore` as a ModuleScript with that exact source. Record the commit or release you
took it from — an upgrade must be a deliberate act, not a surprise.

Verify it loads and detects the unpublished place:

```lua
local ProfileStore = require(game:GetService("ServerStorage").ProfileStore)
return "loaded, IsClosing=" .. tostring(ProfileStore.IsClosing)
```

Expected: loads without error. On this unpublished place ProfileStore's internal probe will have set
its state to `NoAccess` and it will use a mock store — that is expected and is what makes this phase
testable.

- [ ] **Step 2: Write the failing test**

Create `ServerStorage.UnitTest.Cases.Schema_Test`:

```lua
-- Tests for ReplicatedStorage.Persistence.Schema.
-- The template is the contract every service hydrates from, so these assert its shape and, more
-- importantly, that nothing DERIVED has crept into it.
return function(t)
	local Schema = require(game.ReplicatedStorage.Persistence.Schema)
	local expect = t.expect

	t.test("VERSION is a positive integer", function()
		expect.equal(typeof(Schema.VERSION), "number")
		expect.truthy(Schema.VERSION >= 1)
		expect.equal(Schema.VERSION % 1, 0)
	end)

	t.test("the template carries every field the spec names", function()
		for _, field in { "spraypaint", "skinsOwned", "equippedSkin", "cash", "level", "xp",
		                  "kills", "weaponsOwned", "weaponUpgrades", "loadout" } do
			expect.truthy(Schema.template[field] ~= nil)
		end
	end)

	t.test("scalar defaults are sane for a brand new player", function()
		expect.equal(Schema.template.spraypaint, 0)
		expect.equal(Schema.template.cash, 0)
		expect.equal(Schema.template.level, 1)
		expect.equal(Schema.template.xp, 0)
	end)

	t.test("every table default is empty, not shared", function()
		-- A shared table in a template is how one player's progress leaks into another's: every
		-- profile would reference the same table. ProfileStore deep-copies, but the template itself
		-- must still start empty or a new player inherits whatever was written last.
		for _, field in { "skinsOwned", "equippedSkin", "kills", "weaponsOwned", "weaponUpgrades", "loadout" } do
			expect.equal(typeof(Schema.template[field]), "table")
			expect.equal(next(Schema.template[field]), nil)
		end
	end)

	t.test("no derived field appears in the template", function()
		-- A persisted derivative outlives the thing it was derived from and then disagrees with it.
		for _, derived in Schema.DERIVED do
			expect.equal(Schema.template[derived], nil)
		end
	end)

	t.test("DERIVED names the five values the spec excludes", function()
		local named = {}
		for _, d in Schema.DERIVED do named[d] = true end
		for _, d in { "NextLevelXP", "SkinId", "damage", "catalogue", "lastLevel" } do
			expect.truthy(named[d])
		end
	end)

	t.test("the template holds no functions or instances", function()
		-- DataStores serialise neither, and a template that cannot round-trip fails at save time
		-- rather than here, which is far too late.
		for key, value in Schema.template do
			expect.falsy(typeof(value) == "function" or typeof(value) == "Instance")
		end
	end)
end
```

- [ ] **Step 3: Run it and confirm it fails**

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
local r = run("Schema")
return string.format("run=%d passed=%d failed=%d", r.run, r.passed, r.failed)
```

Expected: every case fails — `Persistence is not a valid member of ReplicatedStorage`.

- [ ] **Step 4: Write the schema**

Create `ReplicatedStorage.Persistence.Schema`:

```lua
-- The persisted profile's shape. Data only: no behaviour, no ProfileStore, no services.
--
-- Lives in ReplicatedStorage rather than beside the gateway so the tests can read it without pulling
-- in the server's session machinery.
local Schema = {}

-- Bumped when a field's MEANING changes, which makes that change a migration rather than a silent
-- misreading of old data. Adding a field needs no bump: ProfileStore's Reconcile fills it from the
-- template.
Schema.VERSION = 1

Schema.template = {
	spraypaint = 0,
	skinsOwned = {},      -- [paletteKey] = true
	equippedSkin = {},    -- [weaponName] = paletteKey
	cash = 0,
	level = 1,
	xp = 0,
	kills = {},           -- { Criminal = n, Police = n }
	weaponsOwned = {},    -- [weaponName] = true
	weaponUpgrades = {},  -- [weaponName] = level
	loadout = {},         -- [slotIndex] = weaponName
}

-- Values that are COMPUTED from something else and must never be written.
--
-- Each of these already has a single source: NextLevelXP from level, a Tool's SkinId from the player's
-- equipped-skin attribute, a weapon's damage from its upgrade level, the catalogue from ServerStorage
-- at server start, and lastLevel from the level seen at join. Persisting any of them means a stale
-- copy outliving its source and then contradicting it.
Schema.DERIVED = { "NextLevelXP", "SkinId", "damage", "catalogue", "lastLevel" }

return Schema
```

- [ ] **Step 5: Run the tests and confirm they pass**

Expected: 7 passed, 0 failed.

- [ ] **Step 6: Mirror and commit**

Export the **actual Source from Studio** — never retype — to `FPSSystem/Persistence/Schema.luau`,
`FPSSystem/Persistence/Schema_Test.luau`, and `FPSSystem/Persistence/ProfileStore.luau` (the vendored
copy, so the repo records exactly which version is in use).

```bash
mkdir -p FPSSystem/Persistence
git add FPSSystem/Persistence/
git commit -m "Add the persistence schema and vendor ProfileStore"
```

---

## Task 2: ProfileGateway — sessions, and the rule that outranks everything

**Files:**
- Create: `ServerScriptService.Persistence.Scripts.ProfileGateway` (ModuleScript)
- Create: `ServerScriptService.Persistence.Scripts.PersistenceRunner` (Script)
- Test: `ServerStorage.UnitTest.Cases.ProfileGateway_Test`

**Interfaces:**
- Consumes: `Schema.template`, `Schema.VERSION` (Task 1)
- Produces:
  - `ProfileGateway.waitFor(player): Profile?` — yields until loaded; nil if the player left or the load failed
  - `ProfileGateway.get(player): Profile?` — non-yielding
  - `ProfileGateway.isLoaded(player): boolean`
  - `ProfileGateway.start()` — connects the player hooks; called only by the runner
  - `ProfileGateway.useMockStore()` — points the gateway at `ProfileStore.Mock`, for tests
  - `ProfileGateway.loadForKey(key: string, cancel: (() -> boolean)?): Profile?` — one key, retried; nil when it cannot be had
  - `ProfileGateway.keyFor(userId: number): string`

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.ProfileGateway_Test`:

```lua
-- Tests for ProfileGateway against ProfileStore's MOCK store, which operates on a fake DataStore and
-- is forgotten at server shutdown. That is what lets this run on an unpublished place.
--
-- The rule these exist to protect: a profile that failed to load is never written. Everything else in
-- this phase is recoverable; that one is not.
return function(t)
	local Gateway = require(game.ServerScriptService.Persistence.Scripts.ProfileGateway)
	local Schema = require(game.ReplicatedStorage.Persistence.Schema)
	local expect = t.expect

	Gateway.useMockStore()

	t.test("a fresh key loads a profile matching the template", function()
		local profile = Gateway.loadForKey("test-fresh-" .. os.clock())
		expect.truthy(profile ~= nil)
		expect.equal(profile.Data.spraypaint, Schema.template.spraypaint)
		expect.equal(profile.Data.cash, Schema.template.cash)
		expect.equal(profile.Data.level, Schema.template.level)
		profile:EndSession()
	end)

	t.test("a profile round-trips what was written to it", function()
		local key = "test-roundtrip-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.spraypaint = 137
		first.Data.skinsOwned.Cobalt = true
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.spraypaint, 137)
		expect.equal(second.Data.skinsOwned.Cobalt, true)
		second:EndSession()
	end)

	t.test("Reconcile fills a field added to the template since the profile was written", function()
		-- Adding a field must not require a version bump; this is what makes that true.
		local key = "test-reconcile-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.spraypaint = 5
		first.Data.cash = nil -- simulate a profile written before `cash` existed
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.cash, Schema.template.cash)
		expect.equal(second.Data.spraypaint, 5)
		second:EndSession()
	end)

	t.test("a stamped version is preserved across a round trip", function()
		local key = "test-version-" .. os.clock()
		local first = Gateway.loadForKey(key)
		expect.equal(first.Data.version, Schema.VERSION)
		first:EndSession()
	end)

	t.test("get returns nil for a player with no profile", function()
		local stranger = { UserId = -1, Name = "NoSuchPlayer" }
		expect.equal(Gateway.get(stranger), nil)
		expect.falsy(Gateway.isLoaded(stranger))
	end)

	t.test("a failed load yields no profile and writes nothing", function()
		-- THE rule. A load that fails must leave the stored profile untouched; handing out a blank
		-- profile and later saving it is how an account is wiped, and it looks like a normal session
		-- right up until the save lands.
		local key = "test-failure-" .. os.clock()
		local seeded = Gateway.loadForKey(key)
		seeded.Data.spraypaint = 999
		seeded:EndSession()

		Gateway._forceNextLoadFailure(true)
		local failed = Gateway.loadForKey(key)
		Gateway._forceNextLoadFailure(false)
		expect.equal(failed, nil)

		local reread = Gateway.loadForKey(key)
		expect.equal(reread.Data.spraypaint, 999)
		reread:EndSession()
	end)

	t.test("ending a session twice does not throw", function()
		local profile = Gateway.loadForKey("test-double-end-" .. os.clock())
		profile:EndSession()
		expect.truthy(pcall(function() profile:EndSession() end))
	end)
end
```

- [ ] **Step 2: Run it and confirm it fails**

Expected: every case fails — `Persistence is not a valid member of ServerScriptService`.

- [ ] **Step 3: Write the gateway**

Create `ServerScriptService.Persistence.Scripts.ProfileGateway`:

```lua
-- The only module in this place that knows ProfileStore exists.
--
-- Services call waitFor/get and receive a plain table. That keeps ProfileStore swappable and keeps its
-- API out of the seven services that hold progression state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ProfileStore)
local Schema = require(ReplicatedStorage.Persistence.Schema)

local STORE_NAME = "PlayerProfiles"
local LOAD_ATTEMPTS = 3
local RETRY_DELAY = 2

local KICK_MESSAGE =
	"Your saved data could not be loaded, so nothing has been changed. Please rejoin in a moment."

local ProfileGateway = {}

local store = ProfileStore.New(STORE_NAME, Schema.template)
local profiles: { [any]: any } = {}
local forcedFailure = false

-- Tests point the gateway at ProfileStore's fake DataStore, which is forgotten at shutdown. Without
-- this every test run would write to the same live keys as players.
function ProfileGateway.useMockStore()
	store = ProfileStore.New(STORE_NAME, Schema.template).Mock
end

-- Test seam only: makes the next load behave as a contended session would.
function ProfileGateway._forceNextLoadFailure(active: boolean)
	forcedFailure = active
end

function ProfileGateway.keyFor(userId: number): string
	return "player_" .. userId
end

-- Loads one key, retrying a contended session a few times. Returns nil when it cannot be had.
--
-- `cancel` lets a load abandon itself when the player it was for has already left, so a departing
-- player does not hold a session open while the server retries on their behalf.
function ProfileGateway.loadForKey(key: string, cancel: (() -> boolean)?): any?
	for attempt = 1, LOAD_ATTEMPTS do
		if cancel and cancel() then
			return nil
		end
		local profile = if forcedFailure then nil else store:StartSessionAsync(key, { Cancel = cancel })
		if profile then
			profile:Reconcile()
			if profile.Data.version == nil then
				profile.Data.version = Schema.VERSION
			end
			return profile
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end
	return nil
end

function ProfileGateway.get(player: any): any?
	return profiles[player]
end

function ProfileGateway.isLoaded(player: any): boolean
	return profiles[player] ~= nil
end

-- Yields until the player's profile is available. Returns nil if they left or the load failed, and
-- callers must treat nil as "do not persist anything for this player" rather than as "start fresh".
function ProfileGateway.waitFor(player: Player): any?
	while player.Parent == Players and profiles[player] == nil do
		task.wait(0.1)
	end
	return profiles[player]
end

local function onPlayerAdded(player: Player)
	local profile = ProfileGateway.loadForKey(
		ProfileGateway.keyFor(player.UserId),
		function()
			return player.Parent ~= Players
		end
	)

	if profile == nil then
		-- Nothing was written and nothing will be. Kicking is the honest outcome: a session that
		-- cannot save looks identical to one that can until the moment the player logs off.
		if player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
		return
	end

	profile:AddUserId(player.UserId)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		-- The session can end without the player leaving -- another server stealing it, or a
		-- shutdown. Continuing to play against a profile that no longer saves is the same silent
		-- data loss this phase exists to prevent.
		if player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
end

function ProfileGateway.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return ProfileGateway
```

Create `ServerScriptService.Persistence.Scripts.PersistenceRunner` (a **Script**):

```lua
-- A ModuleScript's hooks connect only when something requires it, and nothing else does.
require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway).start()
```

- [ ] **Step 4: Run the tests and confirm they pass**

Expected: 7 passed, 0 failed.

- [ ] **Step 5: Prove the kick path live**

In a Play session, Server datamodel. Force a failure, rejoin, and confirm nothing was written:

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
Gateway.useMockStore()
local key = "live-kick-probe"

local seeded = Gateway.loadForKey(key)
seeded.Data.spraypaint = 4242
seeded:EndSession()

Gateway._forceNextLoadFailure(true)
local failed = Gateway.loadForKey(key)
Gateway._forceNextLoadFailure(false)

local reread = Gateway.loadForKey(key)
local value = reread.Data.spraypaint
reread:EndSession()
return string.format("failed load returned %s; stored value still %s (expect nil and 4242)",
	tostring(failed), tostring(value))
```

Expected: `failed load returned nil; stored value still 4242`.

- [ ] **Step 6: Mirror and commit**

Export from Studio to `FPSSystem/Persistence/ProfileGateway.luau`,
`FPSSystem/Persistence/PersistenceRunner.luau`, `FPSSystem/Persistence/ProfileGateway_Test.luau`.

```bash
git add FPSSystem/Persistence/
git commit -m "Add ProfileGateway: session lifecycle, retry-then-kick, never-save-unloaded"
```

---

## Task 3: Adopt the cosmetics services

**Files:**
- Modify: `ServerScriptService.Spraypaint.Scripts.SpraypaintService` — hydrate + mirror
- Modify: `ServerScriptService.Cosmetics.Scripts.CosmeticsService` — hydrate + mirror
- Test: `ServerStorage.UnitTest.Cases.ProfileAdoption_Test`

**Interfaces:**
- Consumes: `ProfileGateway.waitFor`, `ProfileGateway.get` (Task 2)
- Produces: `spraypaint`, `skinsOwned` and `equippedSkin` persisted

Cosmetics first because they are the lowest-stakes fields in the schema: a lost skin is an annoyance,
a lost Cash balance after a Robux purchase is a refund request. If the hydrate-and-mirror pattern is
wrong, it is better discovered here.

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.ProfileAdoption_Test`:

```lua
-- Tests that each service's mirror points actually write into the profile.
--
-- These use a stand-in player table, because a real Player cannot be constructed. The services read
-- and write attributes, so the stand-in implements GetAttribute/SetAttribute and nothing else.
return function(t)
	local Gateway = require(game.ServerScriptService.Persistence.Scripts.ProfileGateway)
	local SpraypaintService = require(game.ServerScriptService.Spraypaint.Scripts.SpraypaintService)
	local SpraypaintConstants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local expect = t.expect

	Gateway.useMockStore()

	local function standIn()
		local attributes = {}
		return {
			UserId = -math.random(1000, 999999),
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			_attributes = attributes,
		}
	end

	t.test("granting Spraypaint mirrors the new balance into the profile", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-grant-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 12, "test")
		expect.equal(profile.Data.spraypaint, 12)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("spending Spraypaint mirrors the deduction", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-spend-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 100, "test")
		SpraypaintService.spend(player, 40)
		expect.equal(profile.Data.spraypaint, 60)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("buying a skin mirrors ownership", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-buy-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 1000, "test")
		expect.truthy(SpraypaintService.handleBuyRequest(player, "Cobalt"))
		expect.equal(profile.Data.skinsOwned.Cobalt, true)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("a player with no profile still works and mirrors nothing", function()
		-- A mirror must never be the reason a gameplay path throws. The player simply plays a session
		-- that is not saved, which is what the kick path exists to prevent from happening silently.
		local player = standIn()
		expect.truthy(pcall(function() SpraypaintService.grant(player, 5, "test") end))
		expect.equal(SpraypaintService.balanceOf(player), 5)
	end)

	t.test("hydrating restores a balance and owned skins onto the attributes", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-hydrate-" .. os.clock())
		profile.Data.spraypaint = 321
		profile.Data.skinsOwned.Ember = true
		Gateway._bind(player, profile)

		SpraypaintService.hydrate(player)
		expect.equal(player:GetAttribute(SpraypaintConstants.ATTRIBUTE), 321)
		expect.equal(player:GetAttribute(SpraypaintConstants.ownedAttributeFor("Ember")), true)

		Gateway._unbind(player)
		profile:EndSession()
	end)
end
```

- [ ] **Step 2: Run it and confirm it fails**

Expected: fails on `Gateway._bind` and `SpraypaintService.hydrate` being nil.

- [ ] **Step 3: Add the test seam to the gateway**

In `ProfileGateway`, beside `_forceNextLoadFailure`:

```lua
-- Test seams only. Production binding happens in onPlayerAdded; these let a test attach a stand-in
-- player to a profile without a real Player instance, which cannot be constructed.
function ProfileGateway._bind(player: any, profile: any)
	profiles[player] = profile
end

function ProfileGateway._unbind(player: any)
	profiles[player] = nil
end
```

- [ ] **Step 4: Add hydrate and mirror to SpraypaintService**

Add a require for the gateway, then a hydrate function:

```lua
-- Restores the persisted balance and owned skins onto the attributes the rest of the game reads.
-- Attributes stay the live source during a session; the profile is the copy that outlives it.
function SpraypaintService.hydrate(player: any)
	local profile = ProfileGateway.get(player)
	if not profile then
		return
	end
	player:SetAttribute(Constants.ATTRIBUTE, profile.Data.spraypaint or 0)
	for paletteKey in profile.Data.skinsOwned do
		player:SetAttribute(Constants.ownedAttributeFor(paletteKey), true)
	end
end
```

And a mirror helper used at each write site:

```lua
-- Guarded because a persistence failure must cost a save, never a gameplay path -- the same rule
-- every cosmetics call site in Phases 1 and 2 follows.
local function mirror(player: any, apply: (any) -> ())
	local profile = ProfileGateway.get(player)
	if not profile then
		return
	end
	local ok, err = pcall(apply, profile)
	if not ok then
		warn("[Persistence] failed to mirror for " .. tostring(player) .. ": " .. tostring(err))
	end
end
```

Call `mirror` at the three balance writes (`grant`, `spend`, the join initialiser) and at the ownership
write in `handleBuyRequest`, each setting the corresponding `profile.Data` field. Call
`SpraypaintService.hydrate(player)` from its `safePlayerAdded` handler, after `ProfileGateway.waitFor`.

- [ ] **Step 5: Add hydrate and mirror to CosmeticsService**

Same shape. `hydrate` restores each `EquippedSkin_<weapon>` attribute from `profile.Data.equippedSkin`,
and the write at `CosmeticsService:97` mirrors into it.

- [ ] **Step 6: Run every suite**

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
local lines = {}
for _, name in { "Schema", "ProfileGateway", "ProfileAdoption", "SpraypaintConstants",
                 "SpraypaintService", "SpraypaintTier", "Palettes", "SkinApplier", "CosmeticsOwnership" } do
	local r = run(name)
	table.insert(lines, string.format("%-22s run=%d passed=%d failed=%d", name, r.run, r.passed, r.failed))
end
return table.concat(lines, "\n")
```

Expected: ProfileAdoption 5 passed, and **every Phase 1 and 2 suite unchanged** — SpraypaintConstants 8,
SpraypaintService 21, SpraypaintTier 8, Palettes 10, SkinApplier 14, CosmeticsOwnership 11. A drop means
adoption changed behaviour, which it must not; stop and report rather than adjusting those suites.

- [ ] **Step 7: Mirror and commit**

```bash
git add FPSSystem/
git commit -m "Persist Spraypaint balance, owned skins and equipped skins"
```

---

## Task 4: Adopt the economy services

**Files:**
- Modify: `ServerScriptService.Weapons.Scripts.CashService` — hydrate + mirror at `:54`, `:171`
- Modify: `ServerScriptService.Weapons.Scripts.LevelingService` — hydrate + mirror at `:43-49`, `:134-155`
- Test: `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` — extend

**Interfaces:**
- Consumes: `ProfileGateway.get`, the `mirror` pattern from Task 3
- Produces: `cash`, `level` and `xp` persisted

**These services cannot be unit-tested.** `CashService` and `LevelingService` are `Script`s that return
nothing, so there is no module to require and no function to call. Their adoption is proven by playing
the game and reading the profile, which is a weaker harness but an honest one.

- [ ] **Step 1: Record the before-state live**

In a Play session, Server datamodel, with the gateway on the mock store:

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
local player = game:GetService("Players"):GetPlayers()[1]
local profile = Gateway.get(player)
return string.format("cash=%s level=%s xp=%s | profile cash=%s level=%s xp=%s",
	tostring(player.leaderstats.Cash.Value), tostring(player:GetAttribute("Level")),
	tostring(player:GetAttribute("XP")),
	tostring(profile and profile.Data.cash), tostring(profile and profile.Data.level),
	tostring(profile and profile.Data.xp))
```

Expected before the change: the live values move but the profile fields stay at their template
defaults, because nothing mirrors yet. Record both.

- [ ] **Step 2: Add hydrate and mirror to CashService**

Hydrate sets `leaderstats.Cash.Value` from `profile.Data.cash` instead of `STARTING_CASH` when a
profile exists — a returning player must not be handed the starting amount again. Mirror at both write
sites (`:54` and `:171`) so the profile follows `cash.Value`.

Use the same guarded `mirror` helper shape as Task 3, so a persistence failure costs a save and never
the cash award itself.

- [ ] **Step 3: Add hydrate and mirror to LevelingService**

Hydrate restores `level`, `xp`, `levelValue.Value` and `playerLevels[player]`, then **recomputes**
`NextLevelXP` from the restored level via `LevelingConstants.xpToNextLevel`. Never read `NextLevelXP`
from the profile — it is a derived value and is not stored.

Mirror `level` and `xp` at the set-level site (`:43-49`) and the grant-XP site (`:134-155`).

- [ ] **Step 4: Prove it live — earn, then read the profile**

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
local player = game:GetService("Players"):GetPlayers()[1]
local profile = Gateway.get(player)

local cashBefore = profile.Data.cash
player.leaderstats.Cash.Value += 500
task.wait(0.3)
local levelBefore = profile.Data.level

return string.format("cash %s -> %s (live %s) | level profile=%s live=%s | NextLevelXP stored=%s (expect nil)",
	tostring(cashBefore), tostring(profile.Data.cash), tostring(player.leaderstats.Cash.Value),
	tostring(levelBefore), tostring(player:GetAttribute("Level")),
	tostring(profile.Data.NextLevelXP))
```

Expected: the profile's `cash` follows the live value, and `NextLevelXP` is nil in the profile.

Note that setting `Cash.Value` directly only proves the mirror if the mirror watches the value rather
than the award function. If you mirrored inside the award path instead, drive it through that path and
say which you did.

- [ ] **Step 5: Prove a round trip**

End the session, reload the key, and confirm the values come back:

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
local player = game:GetService("Players"):GetPlayers()[1]
local key = Gateway.keyFor(player.UserId)
local profile = Gateway.get(player)
local cash, level, xp = profile.Data.cash, profile.Data.level, profile.Data.xp
profile:EndSession()
task.wait(1)

local reloaded = Gateway.loadForKey(key)
local result = string.format("cash %s->%s  level %s->%s  xp %s->%s",
	tostring(cash), tostring(reloaded.Data.cash),
	tostring(level), tostring(reloaded.Data.level),
	tostring(xp), tostring(reloaded.Data.xp))
reloaded:EndSession()
return result
```

Expected: all three identical across the round trip.

- [ ] **Step 6: Run every suite**

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
local lines = {}
for _, name in { "Schema", "ProfileGateway", "ProfileAdoption", "SpraypaintConstants",
                 "SpraypaintService", "SpraypaintTier", "Palettes", "SkinApplier", "CosmeticsOwnership" } do
	local r = run(name)
	table.insert(lines, string.format("%-22s run=%d passed=%d failed=%d", name, r.run, r.passed, r.failed))
end
return table.concat(lines, "\n")
```

Expected: every suite unchanged from Task 3. These services have no unit tests, so the suites prove
only that nothing else broke — which is exactly what they are for here.

- [ ] **Step 7: Mirror and commit**

```bash
git add FPSSystem/
git commit -m "Persist cash, level and XP"
```

---

## Task 5: Adopt the weapon and stat services

**Files:**
- Modify: `ServerScriptService.Weapons.Scripts.WeaponShopService` — `:151-153`, `:208-209`, `:254`, `:265`, `:276`
- Modify: `ServerScriptService.Weapons.Scripts.WeaponUpgradeService` — `:71`
- Modify: `ServerScriptService.Stats.Scripts.KillStatsService` — `:70`
- Test: `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` — extend

**Interfaces:**
- Consumes: `ProfileGateway.get`, the `mirror` pattern
- Produces: `weaponsOwned`, `loadout`, `weaponUpgrades` and `kills` persisted

`WeaponShopService` is the largest adoption in this plan: ownership, the four loadout slots, and the
seeded starting weapon all persist, and its slot logic has three separate write sites.

**None of these three can be unit-tested** — all are `Script`s that return nothing. Adoption is proven
live, by playing the paths and reading the profile.

`WeaponShopService` is the largest adoption here: ownership, the four loadout slots and the seeded
starting weapon, with three separate slot write sites.

- [ ] **Step 1: Adopt WeaponShopService**

Hydrate `ownedWeapons[player]` and `equippedSlots[player]` from `profile.Data.weaponsOwned` and
`profile.Data.loadout`, then `publishSlots`.

**Seed the starting weapon ONLY when the profile holds no weapons at all.** A returning player who sold
or re-slotted their Crowbar must not have it handed back every join — that is the difference between
restoring a profile and overwriting one.

Mirror the WHOLE `weaponsOwned` and `loadout` tables at each of the five write sites (`:151-153`,
`:208-209`, `:254`, `:265`, `:276`). Mirror the whole table rather than the one changed slot: a slot
change moves a weapon out of one slot and into another, so writing only the destination leaves the
source stale.

- [ ] **Step 2: Adopt WeaponUpgradeService**

Hydrate each weapon's upgrade attribute from `profile.Data.weaponUpgrades`. Mirror at `:71`.

The damage attribute is NOT persisted — `grantWeapon` recomputes it from the upgrade level at grant
time. Storing it would let a stale damage figure outlive the upgrade it came from.

- [ ] **Step 3: Adopt KillStatsService**

Hydrate `counts[player]` from `profile.Data.kills`, then `publish`. Mirror at the increment (`:70`).

- [ ] **Step 4: Prove weapons and loadout live**

In a Play session, buy a weapon and move it between slots, then read the profile:

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
local player = game:GetService("Players"):GetPlayers()[1]
local profile = Gateway.get(player)
local function slots()
	local out = {}
	for i = 1, 4 do out[i] = tostring(player:GetAttribute("LoadoutSlot" .. i)) end
	return table.concat(out, ",")
end
return string.format("live slots=%s\nprofile loadout=%s\nprofile weapons=%s",
	slots(),
	game:GetService("HttpService"):JSONEncode(profile.Data.loadout),
	game:GetService("HttpService"):JSONEncode(profile.Data.weaponsOwned))
```

Expected: the profile's loadout matches the live `LoadoutSlot*` attributes exactly, and every owned
weapon appears. Run it again after moving a weapon from one slot to another and confirm the OLD slot is
cleared in the profile, not just the new one set.

- [ ] **Step 5: Prove upgrades and kills live**

Upgrade a weapon and take a kill, then confirm both appear in the profile and that the damage attribute
is absent from it:

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
local HttpService = game:GetService("HttpService")
local player = game:GetService("Players"):GetPlayers()[1]
local profile = Gateway.get(player)
return string.format("upgrades=%s\nkills=%s\ndamage stored=%s (expect nil)",
	HttpService:JSONEncode(profile.Data.weaponUpgrades),
	HttpService:JSONEncode(profile.Data.kills),
	tostring(profile.Data.damage))
```

- [ ] **Step 6: Prove the returning-player seed rule**

The rule most likely to be got wrong. Give a profile a loadout that does NOT include the starting
weapon, reload it, and confirm the starting weapon is not re-seeded:

```lua
local Gateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)
local key = "seed-rule-probe"
local first = Gateway.loadForKey(key)
first.Data.weaponsOwned = { ["Glock 17"] = true }
first.Data.loadout = { [1] = "Glock 17" }
first:EndSession()
task.wait(1)

local second = Gateway.loadForKey(key)
local result = game:GetService("HttpService"):JSONEncode(second.Data.weaponsOwned)
second:EndSession()
return "weapons after reload: " .. result .. "  (Crowbar must NOT have reappeared)"
```

- [ ] **Step 7: Run every suite**

Expected: every suite unchanged. These three have no unit tests, so the suites prove only that nothing
else broke.

- [ ] **Step 8: Mirror and commit**

```bash
git add FPSSystem/
git commit -m "Persist weapons, loadout, upgrades and kill stats"
```

---

## Task 6: Migration and the derived-field guard

**Files:**
- Modify: `ServerScriptService.Persistence.Scripts.ProfileGateway` — add `migrate`
- Test: `ServerStorage.UnitTest.Cases.ProfileGateway_Test` — extend

**Interfaces:**
- Consumes: `Schema.VERSION`, `Schema.DERIVED`
- Produces: `ProfileGateway.migrate(data): boolean` — returns whether anything changed

- [ ] **Step 1: Write the failing tests**

Append inside `ProfileGateway_Test`'s `return function(t)`:

```lua
	t.test("a v0 profile migrates to the current version without losing fields", function()
		-- v0 is any profile written before the version field existed. It must gain the version and
		-- keep everything it already had.
		local key = "migrate-v0-" .. os.clock()
		local first = Gateway.loadForKey(key)
		first.Data.version = nil
		first.Data.spraypaint = 77
		first.Data.cash = 123
		first:EndSession()

		local second = Gateway.loadForKey(key)
		expect.equal(second.Data.version, Schema.VERSION)
		expect.equal(second.Data.spraypaint, 77)
		expect.equal(second.Data.cash, 123)
		second:EndSession()
	end)

	t.test("migration is idempotent", function()
		local data = { version = Schema.VERSION, spraypaint = 5 }
		expect.falsy(Gateway.migrate(data))
		expect.equal(data.spraypaint, 5)
	end)

	t.test("a derived field found in stored data is stripped", function()
		-- Older profiles, or a mirror bug, could have written one. Leaving it would let a stale value
		-- outlive and then contradict the thing it was derived from.
		local data = { version = Schema.VERSION, level = 3, NextLevelXP = 999 }
		Gateway.migrate(data)
		expect.equal(data.NextLevelXP, nil)
		expect.equal(data.level, 3)
	end)
```

- [ ] **Step 2: Run and confirm the new cases fail**

- [ ] **Step 3: Write migrate and call it on load**

```lua
-- Brings stored data up to the current shape. Returns whether anything changed, so a caller can tell
-- a migration from a no-op.
--
-- Adding a FIELD needs no migration -- Reconcile fills it from the template. This exists for the case
-- Reconcile cannot handle: a field whose MEANING changed, and stale derived values that should never
-- have been stored.
function ProfileGateway.migrate(data: { [string]: any }): boolean
	local changed = false

	if data.version == nil then
		data.version = Schema.VERSION
		changed = true
	end

	for _, derived in Schema.DERIVED do
		if data[derived] ~= nil then
			data[derived] = nil
			changed = true
		end
	end

	return changed
end
```

Call it in `loadForKey` immediately after `profile:Reconcile()`, replacing the inline version stamp.

- [ ] **Step 4: Run every suite**

Expected: ProfileGateway 10, everything else unchanged.

- [ ] **Step 5: Mirror and commit**

```bash
git add FPSSystem/
git commit -m "Add profile migration and strip stored derived fields"
```

---

## Task 7: Verification pass and change log

No new feature code. This task produces the numbers the change log cites.

- [ ] **Step 1: Work the spec's verification table**

Measure each and record ACTUAL numbers. For each round-trip row, use the mock store: write, end the
session, load again, compare.

1. A new player gets the template
2. Earned Spraypaint survives a rejoin
3. A bought skin survives a rejoin
4. Cash survives a rejoin
5. Level and XP survive
6. Weapons and loadout survive
7. Upgrades survive, and the damage attribute recomputes to the same figure
8. Kills survive
9. A failed load never saves — the stored profile is byte-identical afterwards
10. A failed load kicks
11. Derived fields are not stored
12. Migration from a v0 fixture
13. Phases 1 and 2 still pass: 8, 21, 8, 10, 14, 11

- [ ] **Step 2: Report the two DEFERRED rows as deferred**

**Durability across a real restart** and **cross-server session locking** CANNOT be verified on an
unpublished place. Report them as DEFERRED with the reason. Do not simulate them and do not describe
them as passing — a verification table that overstates is worse than one with honest gaps.

- [ ] **Step 3: Confirm the damage path is still clean**

```lua
local SSS = game:GetService("ServerScriptService")
local leaks = {}
for _, s in { SSS.Blaster.Scripts.ShotResolver, SSS.Weapons.Scripts.WeaponUpgradeService } do
	if s.Source:find("ProfileStore", 1, true) then table.insert(leaks, s.Name) end
end
return #leaks == 0 and "clean" or ("LEAK: " .. table.concat(leaks, ", "))
```

`WeaponUpgradeService` legitimately references `ProfileGateway`; it must not reference `ProfileStore`.

- [ ] **Step 4: Confirm ProfileStore is required in exactly one place**

```lua
local hits = {}
for _, svc in { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"),
                game:GetService("StarterPlayer"), game:GetService("ServerStorage") } do
	for _, d in svc:GetDescendants() do
		if d:IsA("LuaSourceContainer") and d.Name ~= "ProfileStore" then
			local ok, src = pcall(function() return d.Source end)
			if ok and src:find("require", 1, true) and src:find("ProfileStore", 1, true) then
				table.insert(hits, d:GetFullName())
			end
		end
	end
end
return "modules requiring ProfileStore: " .. table.concat(hits, ", ")
```

Expected: only `ProfileGateway`.

- [ ] **Step 5: Write the change log and commit**

Write `FPSSystem/FPS-Persistence-Phase-3.md` in the project's Summary / Cause / Changes / Verification /
Notes shape, matching the existing logs. Cite every number. Record the vendored ProfileStore version.
End with a `Status:` line separating what was confirmed against the mock store from what is deferred
until the place is published — and say plainly that the mock exercises the logic, not the network, so
latency, throttling and `UpdateAsync` conflicts remain unobserved.

```bash
git add FPSSystem/
git commit -m "Add change log: persistence, Phase 3"
```
