# Renown Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Renown — a currency earned by killing NPCs and levelling up, spent on a third tier of weapon skins — so a player who never spends Robux has a path to cosmetics, without weakening the `Vip` pass.

**Architecture:** Renown is a server-authoritative number replicated as a player attribute, matching how `Level`, `XP` and the kill counters already work. Its earn path is two listeners on things the game already broadcasts, so no existing file is modified. Four new palettes carry `source = "Renown"` and a price; buying one is a server-validated remote, and the buy surface reuses the skins row's exact 290x60 footprint.

**Tech Stack:** Roblox Luau. Existing in-place unit framework at `ServerStorage.UnitTest` (`RunUnitTest(filter, timeout)`, assertions `expect.equal / truthy / falsy / near / throws / deepEqual`). Existing `ReplicatedStorage.Cosmetics.*` from Phase 1. Existing `ReplicatedStorage.Modules.NotificationController`.

**Spec:** `docs/superpowers/specs/2026-09-23-renown-phase-2-design.md`

## Global Constraints

- **No `DataStoreService`. Nothing persists this phase.** The profile schema in the spec is a contract for a later phase, not something to build.
- **The earn path modifies no existing file.** `ShotResolver`, `KillStatsService`, `LevelingService`, `CashService`, `WeaponShopService` and `WeaponUpgradeService` are not touched. Renown listens to what they already broadcast.
- **PvP kills award no Renown.** A player's character carries no `Faction` attribute, so player kills fall out of the faction check. This is deliberate anti-farming that `KillStatsService` and `CashService` already share — without it two players trade kills and print currency at will.
- **Renown never unlocks a `Vip` palette.** `handleBuyRequest` refuses any key whose `source` is not `"Renown"`.
- **Every Renown mutation is server-side.** The client displays a balance it is told and asks for purchases it cannot grant itself.
- **A failed skin costs a colour, never a weapon.** Every cosmetics call site in Phase 1 is `pcall`-wrapped; anything added here matches.
- **Do not touch the Robbery System place or any `RobberySystem/` directory.**
- **British spelling in prose comments; comments explain WHY, never restate WHAT.**
- **Design tokens:** panel `#171A22`, raised `#1E222C`, accent `#CBF23C`, danger `#FF4B4B`, muted `#8A8F9A`.
- **Measured panel geometry (do not re-derive):** `DetailPanel` 700x438, no layout, content occupies to y=432. The only free region is x 0-290, y 372-432 — 290x60 — and `SkinRow` already occupies it. Chips are 52x52 with a 46x46 inset `Swatch`; the row's canvas is 466 wide today and becomes 698 with four more chips, in the same 290 window.
- **Measured seams:** kills broadcast on `ServerScriptService.Blaster.Events.Eliminated` as `Fire(shooter, victimHumanoid, damage)`; the victim's faction is `victimCharacter:GetAttribute("Faction")` returning `"Police"` or `"Criminal"`; levels publish as the player attribute `Level`, which `LevelingService.onPlayerAdded` also sets; `safePlayerAdded(callback)` covers already-present players plus `PlayerAdded`; `NotificationController.show(message, title?)` is CLIENT-side.

## The medium — read before touching anything

The code does NOT live in this git repo. It lives inside a running Roblox Studio place, reached through `mcp__Roblox_Studio__execute_luau`, which takes `datamodel_type` ("Edit" / "Server" / "Client", capitalised) and `code`. The `FPSSystem/**/*.luau` files are MIRRORS exported from Studio so the work is reviewable in git.

**Five traps that have already cost time in this project. Do not rediscover them:**

1. `string.gsub` with a pattern containing `(`, `)`, `.` or `-` silently replaces NOTHING and raises no error — those are Lua pattern metacharacters. After ANY Source edit, read the Source back, assert the byte length moved as expected, and confirm the new text is present with `string.find(src, needle, 1, true)` — the `true` makes it a plain find.
2. `execute_luau`'s command context runs in a Lua state whose `require()` cache is NOT shared with running scripts. Do not monkey-patch a module and expect live scripts to see it. Edit Source and restart Play.
3. Studio's EDIT-mode module cache serves a STALE module after an edit — this produced false test failures in Phase 1. Run unit tests in a Play session. If you must require in Edit mode after editing, clone the ModuleScript and require the clone.
4. `screen_capture` returns a magenta placeholder in Play mode. You cannot take a screenshot; do not claim a visual check.
5. A chip scrolled outside `SkinRow`'s clipped window silently swallows clicks, producing a convincing false "nothing happened". Scroll a chip into view and verify its `AbsolutePosition` lies within the row's visible bounds before clicking.

Also: `AbsolutePosition` differs BETWEEN Play sessions, because `WeaponaryShopGui` carries a `ResponsiveScale` UIScale that reacts to viewport size. Only compare within one session, using a visible/hidden A/B.

## Running tests

Cases are ModuleScripts at `ServerStorage.UnitTest.Cases.<Name>_Test` returning `function(t)`, using `t.test(name, fn)` and `t.expect`. Run in a Play session, Server datamodel:

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("Renown")
```

Start and stop Play with `mcp__Roblox_Studio__start_stop_play`, and leave Studio in Edit mode when done.

---

## File Structure

Roblox instances, not files. Created:

| Path | Responsibility |
|---|---|
| `ReplicatedStorage.Renown.Constants` (ModuleScript) | Earn rates, prices, `ownedAttributeFor`. Data only. |
| `ReplicatedStorage.Renown.Remotes.BuySkinRequest` (RemoteEvent) | Client asks, server decides |
| `ServerScriptService.Renown.Scripts.RenownService` (ModuleScript) | Balance authority: grant, earn listeners, purchase |
| `ServerScriptService.Renown.Scripts.RenownRunner` (Script) | Requires the service so its listeners connect |
| `StarterPlayer.StarterPlayerScripts.RenownHud` (LocalScript) | Announces gains through `NotificationController` |
| `ServerStorage.UnitTest.Cases.RenownConstants_Test` | Task 1 |
| `ServerStorage.UnitTest.Cases.RenownService_Test` | Tasks 2 and 4 |
| `ServerStorage.UnitTest.Cases.RenownTier_Test` | Task 3 (named so the `Palettes` filter still isolates Phase 1's suite) |

Modified:

| Path | Change |
|---|---|
| `ReplicatedStorage.Cosmetics.Palettes` | Four Renown entries; `priceOf`; `source` type widened |
| `ServerScriptService.Cosmetics.Scripts.CosmeticsService` | `ownsPalette` gains a Renown branch |
| `StarterPlayer.StarterPlayerScripts.SkinRowController` | Coin badge, buy strip, purchase click path |
| `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel` | `BuyStrip` frame + `Coin` badge on the chip template |

Mirrors go to `FPSSystem/Renown/*.luau`, except modified Phase 1 files which overwrite their existing mirrors in `FPSSystem/Cosmetics/`.

---

## Task 1: Renown constants

**Files:**
- Create: `ReplicatedStorage.Renown.Constants` (ModuleScript)
- Test: `ServerStorage.UnitTest.Cases.RenownConstants_Test` (ModuleScript)

**Interfaces:**
- Consumes: nothing
- Produces:
  - `Constants.KILL_RENOWN: { [string]: number }` — keyed by faction string
  - `Constants.LEVEL_RENOWN: number`
  - `Constants.ATTRIBUTE: string` — `"Renown"`
  - `Constants.ownedAttributeFor(paletteKey: string): string`
  - `Constants.renownForFaction(faction: unknown): number` — 0 for anything unrecognised

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.RenownConstants_Test`:

```lua
-- Tests for ReplicatedStorage.Renown.Constants.
-- The faction lookup carries the anti-farming rule, so it is tested harder than a data table usually
-- would be: anything that is not a recognised NPC faction must be worth zero.
return function(t)
	local Constants = require(game.ReplicatedStorage.Renown.Constants)
	local expect = t.expect

	t.test("the balance attribute is named Renown", function()
		expect.equal(Constants.ATTRIBUTE, "Renown")
	end)

	t.test("both NPC factions are worth something, and Police more than Criminal", function()
		expect.truthy(Constants.renownForFaction("Criminal") > 0)
		expect.truthy(Constants.renownForFaction("Police") > Constants.renownForFaction("Criminal"))
	end)

	t.test("a level-up is worth more than a single kill", function()
		expect.truthy(Constants.LEVEL_RENOWN > Constants.renownForFaction("Police"))
	end)

	t.test("PvP earns nothing -- nil faction is worth zero", function()
		-- A player's own character carries no Faction attribute, which is what excludes PvP. If this
		-- ever returns non-zero, two players can trade kills and print currency at will.
		expect.equal(Constants.renownForFaction(nil), 0)
	end)

	t.test("an unrecognised faction is worth zero", function()
		expect.equal(Constants.renownForFaction("Civilian"), 0)
		expect.equal(Constants.renownForFaction(""), 0)
	end)

	t.test("a non-string faction is worth zero and does not throw", function()
		expect.equal(Constants.renownForFaction(42), 0)
		expect.equal(Constants.renownForFaction({}), 0)
		expect.equal(Constants.renownForFaction(true), 0)
	end)

	t.test("ownedAttributeFor is stable and legal", function()
		expect.equal(Constants.ownedAttributeFor("Cobalt"), "SkinOwned_Cobalt")
	end)

	t.test("ownedAttributeFor sanitises characters Roblox rejects in an attribute name", function()
		-- Phase 1 measured that 16 of the 29 weapon names contain such characters. A palette key added
		-- later could too, and SetAttribute throws on them rather than failing quietly.
		local probe = Instance.new("Part")
		for _, key in { "Neon Blue", "Half-Life", "S&W", "a/b" } do
			local name = Constants.ownedAttributeFor(key)
			expect.truthy(pcall(function() probe:SetAttribute(name, true) end))
		end
	end)
end
```

- [ ] **Step 2: Run it and confirm it fails**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("RenownConstants")
```

Expected: fails — `Renown is not a valid member of ReplicatedStorage`.

- [ ] **Step 3: Write the constants**

Create `ReplicatedStorage.Renown.Constants`:

```lua
-- Renown earn rates and the names Renown state is stored under.
--
-- Data only. Rates live here rather than inline so they can be tuned from one place without touching
-- the service that awards them -- these figures are a play-testing starting point, not a balance claim.
local Constants = {}

-- The balance replicates as a player attribute, matching Level, XP and the kill counters. No
-- leaderstats column: Cash is public because it is the combat economy, and a second column for a
-- cosmetic currency clutters the player list for everyone in the server.
Constants.ATTRIBUTE = "Renown"

-- Keyed by the Faction attribute the enemy rigs already carry. Police are worth more because EnemyAI
-- gives them per-type accuracy and damage overrides that make them the harder target.
Constants.KILL_RENOWN = {
	Criminal = 2,
	Police = 5,
}

Constants.LEVEL_RENOWN = 25

-- Anything that is not a recognised NPC faction is worth nothing, and that includes nil.
--
-- This is the anti-farming rule, not a defensive nicety: a player's own character carries no Faction
-- attribute, so PvP kills arrive here as nil and must stay worthless. KillStatsService and CashService
-- both already exclude PvP for the same reason.
function Constants.renownForFaction(faction: unknown): number
	if typeof(faction) ~= "string" then
		return 0
	end
	return Constants.KILL_RENOWN[faction] or 0
end

-- Ownership of a bought palette, mirroring the WeaponOwned_* convention already in the place.
-- Sanitised because SetAttribute throws on a name containing anything outside [A-Za-z0-9_].
function Constants.ownedAttributeFor(paletteKey: string): string
	return "SkinOwned_" .. (string.gsub(paletteKey, "[^%w_]", "_"))
end

return Constants
```

- [ ] **Step 4: Run the tests and confirm they pass**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("RenownConstants")
```

Expected: 8 passed, 0 failed.

- [ ] **Step 5: Mirror and commit**

Export the module's **actual Source from Studio** — never retype — to `FPSSystem/Renown/Constants.luau`, and the test to `FPSSystem/Renown/RenownConstants_Test.luau`.

```bash
mkdir -p FPSSystem/Renown
git add FPSSystem/Renown/
git commit -m "Add the Renown constants"
```

---

## Task 2: The balance and the earn path

**Files:**
- Create: `ServerScriptService.Renown.Scripts.RenownService` (ModuleScript)
- Create: `ServerScriptService.Renown.Scripts.RenownRunner` (Script)
- Test: `ServerStorage.UnitTest.Cases.RenownService_Test` (ModuleScript)

**Interfaces:**
- Consumes: `Renown.Constants` from Task 1
- Produces:
  - `RenownService.balanceOf(player): number`
  - `RenownService.grant(player, amount: number, reason: string): number` — returns the new balance
  - `RenownService.spend(player, amount: number): boolean` — false when short, balance untouched
  - `RenownService.onEliminated(attacker: unknown, victimHumanoid: unknown)` — production kill handler; validates the attacker is a Player
  - `RenownService.awardForVictim(player, victimHumanoid: unknown)` — the award rule, testable without a real Player
  - `RenownService.onLevelChanged(player)` — the level handler, exposed for test

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.RenownService_Test`:

```lua
-- Tests for ServerScriptService.Renown.Scripts.RenownService.
-- The handlers are exposed as named functions specifically so the earn rules can be tested rather than
-- proven once by hand -- Phase 1 learned that lesson on its equip remote.
return function(t)
	local RenownService = require(game.ServerScriptService.Renown.Scripts.RenownService)
	local Constants = require(game.ReplicatedStorage.Renown.Constants)
	local expect = t.expect

	-- A stand-in player: the service only ever calls GetAttribute and SetAttribute on it.
	local function fakePlayer(startingRenown: number?)
		local attributes = { [Constants.ATTRIBUTE] = startingRenown or 0 }
		return {
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			_attributes = attributes,
		}
	end

	-- A stand-in victim: a Humanoid whose Parent carries a Faction attribute, which is exactly what
	-- KillStatsService reads.
	local function fakeVictim(faction: string?)
		local character = Instance.new("Model")
		if faction then
			character:SetAttribute("Faction", faction)
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		return humanoid
	end

	t.test("a fresh player starts at zero", function()
		expect.equal(RenownService.balanceOf(fakePlayer()), 0)
	end)

	t.test("granting adds and returns the new balance", function()
		local player = fakePlayer(10)
		expect.equal(RenownService.grant(player, 15, "test"), 25)
		expect.equal(RenownService.balanceOf(player), 25)
	end)

	t.test("granting zero or a negative amount changes nothing", function()
		local player = fakePlayer(10)
		RenownService.grant(player, 0, "test")
		RenownService.grant(player, -50, "test")
		expect.equal(RenownService.balanceOf(player), 10)
	end)

	t.test("spending deducts and reports success", function()
		local player = fakePlayer(300)
		expect.truthy(RenownService.spend(player, 250))
		expect.equal(RenownService.balanceOf(player), 50)
	end)

	t.test("spending more than the balance is refused and deducts nothing", function()
		local player = fakePlayer(100)
		expect.falsy(RenownService.spend(player, 250))
		expect.equal(RenownService.balanceOf(player), 100)
	end)

	t.test("spending exactly the balance is allowed", function()
		local player = fakePlayer(250)
		expect.truthy(RenownService.spend(player, 250))
		expect.equal(RenownService.balanceOf(player), 0)
	end)

	t.test("killing a Thug awards the Criminal rate", function()
		local player = fakePlayer()
		RenownService.awardForVictim(player, fakeVictim("Criminal"))
		expect.equal(RenownService.balanceOf(player), Constants.KILL_RENOWN.Criminal)
	end)

	t.test("killing Police awards the higher rate", function()
		local player = fakePlayer()
		RenownService.awardForVictim(player, fakeVictim("Police"))
		expect.equal(RenownService.balanceOf(player), Constants.KILL_RENOWN.Police)
	end)

	t.test("a PvP kill awards nothing", function()
		-- The victim has no Faction attribute, exactly as a player character does not. If this ever
		-- pays out, two players can farm Renown off each other indefinitely.
		local player = fakePlayer()
		RenownService.awardForVictim(player, fakeVictim(nil))
		expect.equal(RenownService.balanceOf(player), 0)
	end)

	t.test("onEliminated rejects an attacker that is not a Player", function()
		-- The victim here WOULD pay 5 through awardForVictim, so this proves the guard is doing work
		-- rather than the victim simply being worthless. An NPC killing an NPC must earn nobody
		-- anything.
		expect.truthy(pcall(RenownService.onEliminated, Instance.new("Model"), fakeVictim("Police")))
		expect.truthy(pcall(RenownService.onEliminated, nil, fakeVictim("Police")))
	end)

	t.test("a victim with no character awards nothing and does not throw", function()
		local orphan = Instance.new("Humanoid")
		expect.truthy(pcall(RenownService.awardForVictim, fakePlayer(), orphan))
	end)
end
```

- [ ] **Step 2: Run it and confirm it fails**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("RenownService")
```

Expected: fails — `Renown is not a valid member of ServerScriptService`.

- [ ] **Step 3: Write the service**

Create `ServerScriptService.Renown.Scripts.RenownService`:

```lua
-- Renown: a currency earned by killing NPCs and levelling up, spent on skins.
--
-- The earn path is two LISTENERS on signals the game already broadcasts, so no existing file is
-- modified. ShotResolver, KillStatsService and LevelingService are working code in the damage and
-- progression paths, and Phase 1's hardest lesson was that economy and appearance code must not be
-- able to break them. Not touching them at all is stronger than guarding them.
--
-- Session-only. Nothing here persists, matching Cash, Leveling and the kill counters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Renown.Constants)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local RenownService = {}

-- The level each player was last seen at. A baseline, not a cache: LevelingService sets Level inside
-- onPlayerAdded, so without this every player would collect a level-up award simply for joining.
local lastLevel: { [Player]: number } = {}

function RenownService.balanceOf(player: any): number
	local value = player:GetAttribute(Constants.ATTRIBUTE)
	return if typeof(value) == "number" then value else 0
end

function RenownService.grant(player: any, amount: number, reason: string): number
	local balance = RenownService.balanceOf(player)
	-- Guarded rather than trusted: a negative grant would be a silent deduction, and the callers are
	-- rate tables that a later edit could get wrong.
	if typeof(amount) ~= "number" or amount <= 0 then
		return balance
	end
	local updated = balance + math.floor(amount)
	player:SetAttribute(Constants.ATTRIBUTE, updated)
	return updated
end

function RenownService.spend(player: any, amount: number): boolean
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	local balance = RenownService.balanceOf(player)
	if balance < amount then
		return false
	end
	player:SetAttribute(Constants.ATTRIBUTE, balance - amount)
	return true
end

-- Production entry point for the Eliminated BindableEvent. Validates the signal's shape strictly,
-- because this receives whatever ShotResolver passes, then delegates the award rule.
function RenownService.onEliminated(attacker: unknown, victimHumanoid: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return
	end
	RenownService.awardForVictim(attacker, victimHumanoid)
end

-- The award rule, split from the guard above so it can be tested. A Player cannot be constructed with
-- Instance.new, so no test stand-in can ever satisfy `typeof(attacker) == "Instance"`; splitting keeps
-- that check STRICT in production instead of loosening real validation for test convenience.
--
-- Reads the victim's faction exactly as KillStatsService does, which is what makes PvP worthless here:
-- a player's own character carries no Faction attribute, so it resolves to nil and pays zero.
function RenownService.awardForVictim(player: any, victimHumanoid: unknown)
	if typeof(victimHumanoid) ~= "Instance" then
		return
	end
	local character = victimHumanoid.Parent
	if not character then
		return
	end
	local amount = Constants.renownForFaction(character:GetAttribute("Faction"))
	if amount > 0 then
		RenownService.grant(player, amount, "kill")
	end
end

-- Level handler. Awards per level GAINED, so a multi-level jump pays for each one rather than once,
-- and never awards on the join-time set.
function RenownService.onLevelChanged(player: any)
	local level = player:GetAttribute("Level")
	if typeof(level) ~= "number" then
		return
	end
	local previous = lastLevel[player]
	lastLevel[player] = level
	if previous == nil or level <= previous then
		return
	end
	RenownService.grant(player, (level - previous) * Constants.LEVEL_RENOWN, "level")
end

function RenownService.start()
	ServerScriptService.Blaster.Events.Eliminated.Event:Connect(RenownService.onEliminated)

	safePlayerAdded(function(player: Player)
		if player:GetAttribute(Constants.ATTRIBUTE) == nil then
			player:SetAttribute(Constants.ATTRIBUTE, 0)
		end
		-- Recorded BEFORE connecting, so the join-time Level set cannot be read as a level-up.
		lastLevel[player] = player:GetAttribute("Level")
		player:GetAttributeChangedSignal("Level"):Connect(function()
			RenownService.onLevelChanged(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastLevel[player] = nil
	end)
end

return RenownService
```

Create `ServerScriptService.Renown.Scripts.RenownRunner` (a **Script**, not a ModuleScript):

```lua
-- A ModuleScript's listeners connect only when something requires it, and nothing else does.
require(game:GetService("ServerScriptService").Renown.Scripts.RenownService).start()
```

- [ ] **Step 4: Run the tests and confirm they pass**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("RenownService")
```

Expected: 11 passed, 0 failed.

- [ ] **Step 5: Prove the join guard live**

The unit tests cannot cover the join path, because it needs a real Player. In a Play session, Server datamodel, immediately after joining:

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
return string.format("Level=%s Renown=%s", tostring(player:GetAttribute("Level")), tostring(player:GetAttribute("Renown")))
```

Expected: `Renown=0`. A non-zero balance here means the join-time `Level` set was read as a level-up — the exact bug the baseline exists to prevent.

- [ ] **Step 6: Prove the earn path live**

Still in Play, Server datamodel. Award XP to force a level, and confirm a kill pays:

```lua
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
local before = player:GetAttribute("Renown")
local level = player:GetAttribute("Level")

-- Fire the same BindableEvent ShotResolver fires, with a stand-in Police victim.
local character = Instance.new("Model")
character:SetAttribute("Faction", "Police")
local humanoid = Instance.new("Humanoid")
humanoid.Parent = character
game:GetService("ServerScriptService").Blaster.Events.Eliminated:Fire(player, humanoid, 100)
task.wait(0.2)
local afterKill = player:GetAttribute("Renown")

-- And a PvP-shaped victim, which must pay nothing.
local pvp = Instance.new("Model")
local pvpHumanoid = Instance.new("Humanoid")
pvpHumanoid.Parent = pvp
game:GetService("ServerScriptService").Blaster.Events.Eliminated:Fire(player, pvpHumanoid, 100)
task.wait(0.2)

return string.format("before=%d afterPoliceKill=%d afterPvP=%d (police should be +5, pvp +0)",
	before, afterKill, player:GetAttribute("Renown"))
```

Expected: `before=0 afterPoliceKill=5 afterPvP=5`.

- [ ] **Step 7: Mirror and commit**

Export the actual Source from Studio to `FPSSystem/Renown/RenownService.luau`, `FPSSystem/Renown/RenownRunner.luau` and `FPSSystem/Renown/RenownService_Test.luau`.

```bash
git add FPSSystem/Renown/
git commit -m "Add Renown, earned from NPC kills and level-ups"
```

---

## Task 3: The Renown palette tier

**Files:**
- Modify: `ReplicatedStorage.Cosmetics.Palettes`
- Test: `ServerStorage.UnitTest.Cases.RenownTier_Test` (ModuleScript)

**Interfaces:**
- Consumes: `Palettes.list`, `Palettes.byKey` from Phase 1
- Produces:
  - `Palettes.priceOf(key: string): number?`
  - Four entries with `source = "Renown"` and a `price`
  - `Palette.source` widened to `"Free" | "Vip" | "Renown"`, `price: number?` added

- [ ] **Step 1: Write the failing test**

Create `ServerStorage.UnitTest.Cases.RenownTier_Test`:

```lua
-- Tests for the Renown tier added to ReplicatedStorage.Cosmetics.Palettes.
-- Phase 1's Palettes_Test still guards the shared invariants (ramps ascend, swatches exist, keys are
-- unique); this case covers only what the new tier adds.
return function(t)
	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)
	local expect = t.expect

	local function renownPalettes()
		local found = {}
		for _, palette in Palettes.list do
			if palette.source == "Renown" then
				table.insert(found, palette)
			end
		end
		return found
	end

	t.test("there are four Renown palettes", function()
		expect.equal(#renownPalettes(), 4)
	end)

	t.test("every Renown palette has a positive integer price", function()
		for _, palette in renownPalettes() do
			expect.equal(typeof(palette.price), "number")
			expect.truthy(palette.price > 0)
			expect.equal(palette.price % 1, 0)
		end
	end)

	t.test("no Free or Vip palette carries a price", function()
		-- A priced Vip palette would imply it is buyable with Renown, which must never be true.
		for _, palette in Palettes.list do
			if palette.source ~= "Renown" then
				expect.equal(palette.price, nil)
			end
		end
	end)

	t.test("priceOf returns the price for a Renown key and nil otherwise", function()
		local first = renownPalettes()[1]
		expect.equal(Palettes.priceOf(first.key), first.price)
		expect.equal(Palettes.priceOf("Stock"), nil)
		expect.equal(Palettes.priceOf("Gold"), nil)
		expect.equal(Palettes.priceOf("NoSuchPalette"), nil)
	end)

	t.test("isVipOnly stays false for Renown palettes", function()
		-- Renown must not route through the Vip gate, or buying it would demand the pass as well.
		for _, palette in renownPalettes() do
			expect.falsy(Palettes.isVipOnly(palette.key))
		end
	end)

	t.test("the catalogue now holds twelve palettes", function()
		expect.equal(#Palettes.list, 12)
	end)

	t.test("every palette key maps to a unique, legal attribute name", function()
		-- Not decorative. ownedAttributeFor sanitises with gsub, so two distinct keys can collapse onto
		-- one attribute -- "S&W" and "S W" both become SkinOwned_S_W -- and two palettes would then
		-- share one ownership flag: buy either and you silently own both. Every current key is
		-- alphanumeric so nothing collides today, which is exactly why this needs locking before
		-- someone adds a key with a space in it. Phase 1 proved the same invariant for the 29 weapon
		-- names.
		local RenownConstants = require(game.ReplicatedStorage.Renown.Constants)
		local probe = Instance.new("Part")
		local seen = {}
		for _, palette in Palettes.list do
			local name = RenownConstants.ownedAttributeFor(palette.key)
			expect.falsy(seen[name])
			seen[name] = palette.key
			expect.truthy(pcall(function() probe:SetAttribute(name, true) end))
		end
	end)

	t.test("every Renown ramp still runs dark to light", function()
		local function luminance(c)
			return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
		end
		for _, palette in renownPalettes() do
			expect.truthy(#palette.ramp >= 2)
			for index = 2, #palette.ramp do
				expect.truthy(luminance(palette.ramp[index]) >= luminance(palette.ramp[index - 1]))
			end
		end
	end)
end
```

- [ ] **Step 2: Run it and confirm it fails**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("RenownTier")
```

Expected: the four-palette and twelve-palette cases fail; `priceOf` errors as nil.

- [ ] **Step 3: Extend the catalogue**

In `ReplicatedStorage.Cosmetics.Palettes`, widen the type:

```lua
export type Palette = {
	key: string,
	name: string,
	source: "Free" | "Vip" | "Renown",
	swatch: Color3,
	ramp: { Color3 },
	-- Present only on Renown entries. A Free or Vip palette carrying a price would imply it is
	-- buyable with Renown, which must never be true of the pass tier.
	price: number?,
}
```

Append these four entries to `Palettes.list`, after `Arctic`:

```lua
	{
		key = "Cobalt", name = "COBALT", source = "Renown", price = 250,
		swatch = rgb(30, 58, 138),
		ramp = { rgb(12, 22, 54), rgb(30, 58, 138), rgb(96, 140, 224) },
	},
	{
		key = "Verdigris", name = "VERDIGRIS", source = "Renown", price = 350,
		swatch = rgb(47, 122, 107),
		ramp = { rgb(16, 46, 40), rgb(47, 122, 107), rgb(120, 200, 180) },
	},
	{
		key = "Ember", name = "EMBER", source = "Renown", price = 500,
		swatch = rgb(194, 65, 12),
		ramp = { rgb(60, 18, 6), rgb(194, 65, 12), rgb(250, 160, 80) },
	},
	{
		-- Not the ivory this slot originally held. Measured: that swatch sat 37.4 from Arctic in RGB
		-- space, the closest pair in the whole catalogue against a prior floor of 52.8, and both were
		-- pale and near-identical in brightness -- a difference that may not survive a 52px chip or
		-- colour-vision deficiency. This one sits 68.0 from its nearest neighbour.
		key = "RoseGold", name = "ROSE GOLD", source = "Renown", price = 750,
		swatch = rgb(183, 110, 121),
		ramp = { rgb(74, 38, 44), rgb(183, 110, 121), rgb(232, 176, 182) },
	},
```

Add the lookup beside `isVipOnly`:

```lua
function Palettes.priceOf(key: string): number?
	local palette = byKeyIndex[key]
	return palette and palette.price or nil
end
```

- [ ] **Step 4: Run both suites and confirm they pass**

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
return tostring(run("RenownTier")) .. " | " .. tostring(run("Palettes"))
```

Expected: `RenownTier` 8 passed, and Phase 1's `Palettes` still 10 passed — the shared invariants must not have regressed.

- [ ] **Step 5: Confirm the row still fits**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local P = require(ReplicatedStorage.Cosmetics.Palettes:Clone())
local chips = #P.list
return string.format("chips=%d expected canvas=%d (window is 290)", chips, chips * 52 + (chips - 1) * 6 + 8)
```

Expected: `chips=12 expected canvas=698`. The row already scrolls, so nothing in the panel moves.

- [ ] **Step 6: Mirror and commit**

Export `ReplicatedStorage.Cosmetics.Palettes` to `FPSSystem/Cosmetics/Palettes.luau` (overwriting the Phase 1 mirror) and the new test to `FPSSystem/Renown/RenownTier_Test.luau`.

```bash
git add FPSSystem/
git commit -m "Add the four Renown palettes"
```

---

## Task 4: Server-authoritative purchase

**Files:**
- Create: `ReplicatedStorage.Renown.Remotes.BuySkinRequest` (RemoteEvent)
- Modify: `ServerScriptService.Renown.Scripts.RenownService` — add `handleBuyRequest`
- Modify: `ServerScriptService.Cosmetics.Scripts.CosmeticsService` — `ownsPalette` gains a Renown branch
- Test: `ServerStorage.UnitTest.Cases.RenownService_Test` — extend

**Interfaces:**
- Consumes: `Palettes.priceOf` (Task 3), `RenownService.spend` (Task 2), `Renown.Constants.ownedAttributeFor` (Task 1)
- Produces: `RenownService.handleBuyRequest(player, paletteKey: unknown): boolean`

- [ ] **Step 1: Write the failing tests**

Append to `ServerStorage.UnitTest.Cases.RenownService_Test`, inside the existing `return function(t)`:

```lua
	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)

	local function ownedName(key)
		return Constants.ownedAttributeFor(key)
	end

	t.test("buying a Renown palette deducts the price and records ownership", function()
		local player = fakePlayer(1000)
		expect.truthy(RenownService.handleBuyRequest(player, "Cobalt"))
		expect.equal(RenownService.balanceOf(player), 1000 - Palettes.priceOf("Cobalt"))
		expect.equal(player._attributes[ownedName("Cobalt")], true)
	end)

	t.test("buying without enough Renown is refused and changes nothing", function()
		local player = fakePlayer(10)
		expect.falsy(RenownService.handleBuyRequest(player, "Cobalt"))
		expect.equal(RenownService.balanceOf(player), 10)
		expect.equal(player._attributes[ownedName("Cobalt")], nil)
	end)

	t.test("buying the same palette twice deducts once", function()
		local player = fakePlayer(1000)
		RenownService.handleBuyRequest(player, "Cobalt")
		local afterFirst = RenownService.balanceOf(player)
		expect.falsy(RenownService.handleBuyRequest(player, "Cobalt"))
		expect.equal(RenownService.balanceOf(player), afterFirst)
	end)

	t.test("a Vip palette cannot be bought with Renown", function()
		-- The whole point of the source check: this path must never be a way around the pass.
		local player = fakePlayer(100000)
		expect.falsy(RenownService.handleBuyRequest(player, "Gold"))
		expect.equal(RenownService.balanceOf(player), 100000)
		expect.equal(player._attributes[ownedName("Gold")], nil)
	end)

	t.test("a free palette cannot be bought", function()
		local player = fakePlayer(100000)
		expect.falsy(RenownService.handleBuyRequest(player, "Carbon"))
		expect.equal(RenownService.balanceOf(player), 100000)
	end)

	t.test("an unknown palette key is refused and does not throw", function()
		local player = fakePlayer(100000)
		expect.falsy(RenownService.handleBuyRequest(player, "NoSuchPalette"))
		expect.equal(RenownService.balanceOf(player), 100000)
	end)

	t.test("a non-string palette key is refused and does not throw", function()
		local player = fakePlayer(100000)
		expect.falsy(RenownService.handleBuyRequest(player, 42))
		expect.falsy(RenownService.handleBuyRequest(player, nil))
		expect.equal(RenownService.balanceOf(player), 100000)
	end)
```

- [ ] **Step 2: Run and confirm the new cases fail**

```lua
return require(game:GetService("ServerStorage").UnitTest.RunUnitTest)("RenownService")
```

Expected: the 14 existing cases pass; the 7 new ones fail on `handleBuyRequest` being nil.
(14, not 11: Task 2's fix round added a fractional-spend case and split the `balanceOf` fallback tests.)

- [ ] **Step 3: Create the remote**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local folder = ReplicatedStorage.Renown:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage.Renown
end
local remote = Instance.new("RemoteEvent")
remote.Name = "BuySkinRequest"
remote.Parent = folder
return remote:GetFullName()
```

- [ ] **Step 4: Add the handler**

In `RenownService`, add above `start()`:

```lua
-- The client asks; the server decides. Every condition is re-checked here rather than trusted, so a
-- forged request cannot buy a palette the player cannot afford, nor reach the Vip tier at all.
function RenownService.handleBuyRequest(player: any, paletteKey: unknown): boolean
	if typeof(paletteKey) ~= "string" then
		return false
	end
	local palette = Palettes.byKey(paletteKey)
	if not palette or palette.source ~= "Renown" then
		return false
	end
	if player:GetAttribute(Constants.ownedAttributeFor(paletteKey)) == true then
		return false
	end
	local price = Palettes.priceOf(paletteKey)
	if not price or not RenownService.spend(player, price) then
		return false
	end
	player:SetAttribute(Constants.ownedAttributeFor(paletteKey), true)
	return true
end
```

Add `local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)` beside the other requires.

In `start()`, connect the remote and equip on success:

```lua
	ReplicatedStorage.Renown.Remotes.BuySkinRequest.OnServerEvent:Connect(
		function(player: Player, paletteKey: unknown, weaponName: unknown)
			if not RenownService.handleBuyRequest(player, paletteKey) then
				return
			end
			-- Equipped by the SERVER in the same call rather than by a second client remote, so a
			-- purchase cannot half-complete into "owned but not worn". Phase 1's machinery does the
			-- rest: the attribute change drives the row's repaint and CosmeticsService.refresh
			-- re-dresses the held weapon, whose SkinId listener catches first person.
			--
			-- weaponName arrives from the client and is validated here like any other client string.
			-- Phase 1 measured why: an unvalidated weapon name let a crafted client create unbounded
			-- player attributes, and one long enough made SetAttribute throw outright.
			if typeof(weaponName) ~= "string" then
				return
			end
			local template = ServerStorage.Weapons:FindFirstChild(weaponName)
			if not (template and template:IsA("Tool")) then
				return
			end
			player:SetAttribute(CosmeticsService.attributeFor(weaponName), paletteKey)
			CosmeticsService.refresh(player, weaponName)
		end
	)
```

Add `local ServerStorage = game:GetService("ServerStorage")` and
`local CosmeticsService = require(ServerScriptService.Cosmetics.Scripts.CosmeticsService)` beside the
other requires.

`handleBuyRequest` deliberately does NOT take the weapon: buying and wearing are separate concerns, and
keeping the purchase function pure is what lets the seven purchase tests run without a weapon at all.

- [ ] **Step 5: Extend ownsPalette**

In `ServerScriptService.Cosmetics.Scripts.CosmeticsService`, `ownsPalette` currently returns true for any non-Vip palette. Change the branch so a Renown palette requires ownership:

```lua
	if Palettes.isVipOnly(key) then
		return player:GetAttribute(MonetizationConstants.ownedAttributeFor(VIP_KEY)) == true
	end
	-- A Renown palette is earned, not granted: it is owned only once bought. Free palettes still fall
	-- through to true.
	if Palettes.priceOf(key) then
		return player:GetAttribute(RenownConstants.ownedAttributeFor(key)) == true
	end
	return true
```

Add `local RenownConstants = require(ReplicatedStorage.Renown.Constants)` beside the other requires.

- [ ] **Step 6: Run every suite**

```lua
-- RunUnitTest returns a RESULT TABLE {run, passed, failed}, not a number, so tostring() on it yields
-- a table address rather than a count. Read the fields.
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
local lines = {}
for _, name in { "RenownService", "RenownTier", "RenownConstants", "Palettes", "SkinApplier", "CosmeticsOwnership" } do
	local r = run(name)
	table.insert(lines, string.format("%-20s run=%d passed=%d failed=%d", name, r.run, r.passed, r.failed))
end
return table.concat(lines, "\n")
```

Expected: RenownService 21, RenownTier 8, RenownConstants 8, Palettes 10, SkinApplier 14, CosmeticsOwnership 11 — all passing. **Phase 1's eleven ownership tests passing unchanged is the check that matters**: it proves the Renown branch did not alter Free or Vip behaviour.

- [ ] **Step 7: Prove a forged purchase is refused, live**

Client datamodel, with a zero balance:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
ReplicatedStorage.Renown.Remotes.BuySkinRequest:FireServer("Cobalt")
ReplicatedStorage.Renown.Remotes.BuySkinRequest:FireServer("Gold")
task.wait(1)
return string.format("Renown=%s SkinOwned_Cobalt=%s SkinOwned_Gold=%s",
	tostring(player:GetAttribute("Renown")),
	tostring(player:GetAttribute("SkinOwned_Cobalt")),
	tostring(player:GetAttribute("SkinOwned_Gold")))
```

Expected: `Renown=0 SkinOwned_Cobalt=nil SkinOwned_Gold=nil` — both refused.

- [ ] **Step 8: Mirror and commit**

Export `RenownService` and `CosmeticsService` from Studio to `FPSSystem/Renown/RenownService.luau` and `FPSSystem/Cosmetics/CosmeticsService.luau`, plus the updated test.

```bash
git add FPSSystem/
git commit -m "Add the server-authoritative Renown skin purchase"
```

---

## Task 5: The buy strip and the gain notification

**Files:**
- Modify: `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel` — add `BuyStrip`, add `Coin` to the chip template
- Modify: `StarterPlayer.StarterPlayerScripts.SkinRowController`
- Create: `StarterPlayer.StarterPlayerScripts.RenownHud` (LocalScript)

**Interfaces:**
- Consumes: `Palettes.priceOf` (Task 3), `BuySkinRequest` (Task 4), `Renown.Constants.ATTRIBUTE` (Task 1)
- Produces: a working buy flow

- [ ] **Step 1: Build the strip and the coin badge**

Run once in the Edit datamodel. The strip is a SIBLING of `SkinRow` at the same position, not a mutation of the row's contents — swapping visibility avoids destroying chips and losing scroll position.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local detail = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel

local existing = detail:FindFirstChild("BuyStrip")
if existing then existing:Destroy() end

-- Same 290x60 footprint as SkinRow, at the same position. The panel has exactly one free region and
-- this must not exceed it; occupying the identical rectangle makes that impossible to get wrong.
local strip = Instance.new("Frame")
strip.Name = "BuyStrip"
strip.Position = UDim2.fromOffset(0, 372)
strip.Size = UDim2.fromOffset(290, 60)
strip.BackgroundColor3 = Color3.fromHex("171A22")
strip.BorderSizePixel = 0
strip.Visible = false
strip.Parent = detail

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = strip

local function label(name, pos, size, colour, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = colour
	l.TextSize = textSize
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = strip
	return l
end

label("PaletteName", UDim2.fromOffset(10, 8), UDim2.fromOffset(148, 20), Color3.fromHex("E8E8E8"), 14)
label("PriceLabel", UDim2.fromOffset(10, 30), UDim2.fromOffset(148, 20), Color3.fromHex("CBF23C"), 13)

local buy = Instance.new("TextButton")
buy.Name = "BuyButton"
buy.Position = UDim2.fromOffset(168, 8)
buy.Size = UDim2.fromOffset(112, 26)
buy.BackgroundColor3 = Color3.fromHex("CBF23C")
buy.TextColor3 = Color3.fromHex("171A22")
buy.Font = Enum.Font.GothamBold
buy.TextSize = 13
buy.Text = "BUY"
buy.AutoButtonColor = false
buy.BorderSizePixel = 0
buy.Parent = strip

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 6)
buyCorner.Parent = buy

local cancel = Instance.new("TextButton")
cancel.Name = "CancelButton"
cancel.Position = UDim2.fromOffset(168, 36)
cancel.Size = UDim2.fromOffset(112, 18)
cancel.BackgroundTransparency = 1
cancel.TextColor3 = Color3.fromHex("8A8F9A")
cancel.Font = Enum.Font.Gotham
cancel.TextSize = 11
cancel.Text = "CANCEL"
cancel.AutoButtonColor = false
cancel.Parent = strip

-- The coin badge marks an unowned Renown chip, distinct from the grey lock on a Vip chip. Built from
-- a Frame for the same reason the lock was: upload_image refused the Figma export as an untrusted URL.
local chip = detail.SkinRow.SkinChip
local oldCoin = chip:FindFirstChild("Coin")
if oldCoin then oldCoin:Destroy() end

local coin = Instance.new("Frame")
coin.Name = "Coin"
coin.Size = UDim2.fromOffset(16, 16)
coin.AnchorPoint = Vector2.new(0.5, 0.5)
coin.Position = UDim2.fromScale(0.5, 0.5)
coin.BackgroundColor3 = Color3.fromHex("CBF23C")
coin.BorderSizePixel = 0
coin.Visible = false
coin.Parent = chip

local coinCorner = Instance.new("UICorner")
coinCorner.CornerRadius = UDim.new(0.5, 0)
coinCorner.Parent = coin

local coinStroke = Instance.new("UIStroke")
coinStroke.Thickness = 2
coinStroke.Color = Color3.fromHex("171A22")
coinStroke.Parent = coin

return strip:GetFullName() .. " | " .. coin:GetFullName()
```

- [ ] **Step 2: Wire the buy flow into SkinRowController**

Read the live script first — it is the Phase 1 controller and these edits build on its existing shape.

**2a. Add the requires and the remote**, beside the existing ones:

```lua
local RenownConstants = require(ReplicatedStorage.Renown.Constants)
local buyRemote = ReplicatedStorage.Renown.Remotes.BuySkinRequest
```

**2b. Replace `ownsVip`-only ownership with one helper that mirrors the server.** Add below `ownsVip`:

```lua
-- Mirrors CosmeticsService.ownsPalette on the server, branch for branch. The client duplicates it
-- because ServerScriptService is unreachable from here, so the two must be kept in step deliberately:
-- if they drift, the row rings a chip the weapon is not actually wearing.
local function ownsPalette(palette): boolean
	if palette.source == "Vip" then
		return ownsVip()
	end
	if palette.price then
		return player:GetAttribute(RenownConstants.ownedAttributeFor(palette.key)) == true
	end
	return true
end
```

**2c. Extend `repaint`'s validation.** Replace the existing fallback line:

```lua
		if not Palettes.byKey(current) or (Palettes.isVipOnly(current) and not ownsVip()) then
			current = Palettes.DEFAULT_KEY
		end
```

with:

```lua
		local currentPalette = Palettes.byKey(current)
		-- Unowned now covers a Renown skin as well as a Vip one, matching equippedKeyFor on the
		-- server. Without this the row would ring a Cobalt chip the server had already degraded to
		-- Stock -- the same disagreement the Vip branch was added to prevent.
		if not currentPalette or not ownsPalette(currentPalette) then
			current = Palettes.DEFAULT_KEY
		end
```

**2d. Extend `refreshLocks`** so it paints all three unowned states:

```lua
	local function refreshLocks()
		for _, palette in Palettes.list do
			local chip = chips[palette.key]
			if not chip then
				continue
			end
			local owned = ownsPalette(palette)
			chip.Swatch.BackgroundTransparency = owned and 0 or 0.65
			-- A Vip chip shows a lock, a Renown chip a coin: one says "pay", the other says "play".
			chip.Lock.Visible = not owned and palette.source == "Vip"
			chip.Coin.Visible = not owned and palette.price ~= nil
		end
	end
```

**2e. The buy strip.** Add inside `build`, after `refreshLocks`:

```lua
	local buyStrip = row.Parent:WaitForChild("BuyStrip")
	local buyConnections: { RBXScriptConnection } = {}

	local function hideBuyStrip()
		buyStrip.Visible = false
		row.Visible = true
		for _, connection in buyConnections do
			connection:Disconnect()
		end
		table.clear(buyConnections)
	end

	local function showBuyStrip(palette)
		-- Clears the previous palette's button connections before wiring this one, so opening the
		-- strip on three chips in a row does not leave three live BUY handlers on the same button.
		hideBuyStrip()

		local price = palette.price or 0
		local affordable = (player:GetAttribute(RenownConstants.ATTRIBUTE) or 0) >= price

		buyStrip.PaletteName.Text = palette.name
		buyStrip.PriceLabel.Text = price .. " RENOWN"
		buyStrip.PriceLabel.TextColor3 = if affordable then Color3.fromHex("CBF23C") else Color3.fromHex("FF4B4B")
		buyStrip.BuyButton.BackgroundColor3 = if affordable then Color3.fromHex("CBF23C") else Color3.fromHex("2A2E38")
		buyStrip.BuyButton.TextColor3 = if affordable then Color3.fromHex("171A22") else Color3.fromHex("8A8F9A")
		buyStrip.BuyButton.Text = if affordable then "BUY" else "NOT ENOUGH"

		table.insert(buyConnections, buyStrip.BuyButton.MouseButton1Click:Connect(function()
			-- Re-read the balance at click time rather than trusting what it was when the strip
			-- opened: Renown can arrive from a kill while the strip is on screen, and the server
			-- re-checks anyway, so this only avoids firing a request that is certain to be refused.
			if (player:GetAttribute(RenownConstants.ATTRIBUTE) or 0) < price then
				return
			end
			buyRemote:FireServer(palette.key, weaponName)
			hideBuyStrip()
		end))
		table.insert(buyConnections, buyStrip.CancelButton.MouseButton1Click:Connect(hideBuyStrip))

		row.Visible = false
		buyStrip.Visible = true
	end

	-- A row being rebuilt means a different weapon is on screen, so a strip left open from the last
	-- one must not survive into it.
	hideBuyStrip()
```

**2f. Extend the click handler.** Replace its first branch:

```lua
		chip.MouseButton1Click:Connect(function()
			-- Read ownership fresh rather than capturing it at build time: a chip bought or unlocked
			-- while this same panel is open must act on what is true now, not what was true then.
			if not ownsPalette(palette) then
				if palette.source == "Vip" then
					-- MonetizationService already disables the prompt for an unconfigured pass id, so
					-- this is safe to fire before the place is published.
					promptGamepass:FireServer("Vip")
				else
					showBuyStrip(palette)
				end
				return
			end
			equipRemote:FireServer(weaponName, palette.key)
```

(the `previewModel` application below it is unchanged)

**2g. Widen the ownership connection.** Replace it:

```lua
	-- One connection covering every ownership signal, rather than one per palette: AttributeChanged
	-- fires with the name, so a Renown skin added later needs no new wiring here.
	local ownershipConnection = player.AttributeChanged:Connect(function(name: string)
		if name == MonetizationConstants.ownedAttributeFor("Vip") or name:sub(1, 10) == "SkinOwned_" then
			refreshLocks()
			repaint()
		end
	end)
```

`showDetail` already disconnects this connection before building the next weapon's row, so nothing extra is needed on the caller's side.

- [ ] **Step 3: Announce gains client-side**

Create `StarterPlayer.StarterPlayerScripts.RenownHud` (LocalScript):

```lua
-- Announces Renown gains through the shared notification module.
--
-- Client-side and driven by the replicated attribute, so no remote is needed: the balance already
-- reaches every client as a player attribute, and NotificationController is a client module.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Renown.Constants)
local NotificationController = require(ReplicatedStorage.Modules.NotificationController)

local player = Players.LocalPlayer
local previous = player:GetAttribute(Constants.ATTRIBUTE) or 0

player:GetAttributeChangedSignal(Constants.ATTRIBUTE):Connect(function()
	local current = player:GetAttribute(Constants.ATTRIBUTE) or 0
	local gained = current - previous
	previous = current
	-- Only gains are announced. A purchase is a deduction the player just chose, and telling them
	-- they spent it is noise at the moment they are looking at what they bought.
	if gained > 0 then
		NotificationController.show("+" .. gained .. " Renown", "RENOWN")
	end
end)
```

- [ ] **Step 4: Verify the panel is undisturbed**

In one Play session, read `AbsolutePosition` for `DetailViewport`, `PriceLabel`, `ActionButton`, `EquipButton` and `StatsContainer` with `BuyStrip.Visible = false`, then `true`, then `false`. Compare within the session only — `ResponsiveScale` makes cross-session figures differ.

Expected: byte-identical in all three states.

- [ ] **Step 5: Verify the buy flow end to end**

In a Play session: grant yourself 1000 Renown server-side, open a weapon, scroll a Renown chip into view (confirm its `AbsolutePosition` is inside the row's bounds before clicking — clipped chips swallow clicks silently), click it, confirm the strip shows the right name and price, click BUY, and confirm the balance falls by the price, the chip loses its coin badge, the skin equips, and the preview dresses itself.

Then repeat with a balance below the price and confirm BUY is inert and nothing changes.

- [ ] **Step 6: Mirror and commit**

Export `SkinRowController` and `RenownHud` from Studio to `FPSSystem/Cosmetics/SkinRowController.luau` and `FPSSystem/Renown/RenownHud.luau`.

```bash
git add FPSSystem/
git commit -m "Add the Renown buy strip and gain notifications"
```

---

## Task 6: Verification pass and change log

No new feature code. This task produces the numbers the change log cites.

- [ ] **Step 1: Work the spec's verification table**

Measure each row and record actual numbers, in one Play session:

1. Kills award Renown — Thug +2, Police +5
2. Level-ups award Renown — +25 on crossing a level
3. Joining awards nothing — `Renown` is 0 after `Level` is published
4. A multi-level jump pays per level — force a two-level gain, expect +50
5. PvP kills award nothing — balance unchanged
6. Purchase deducts and grants — Cobalt at 250; balance −250 and `SkinOwned_Cobalt` true
7. Insufficient funds refused — balance and ownership unchanged
8. Double purchase refused — balance falls once
9. A Vip key cannot be bought with Renown — `BuySkinRequest("Gold")` refused
10. Forged request refused — zero balance, both refused
11. Phase 1 still passes — Palettes 10, SkinApplier 14, CosmeticsOwnership 11
12. The panel is undisturbed — five witnesses unchanged, same-session A/B
13. Nothing persists — rejoin starts at 0 Renown with no skins owned

- [ ] **Step 2: Run every suite and record counts**

```lua
local run = require(game:GetService("ServerStorage").UnitTest.RunUnitTest)
return table.concat({
	tostring(run("RenownConstants")), tostring(run("RenownService")), tostring(run("RenownTier")),
	tostring(run("Palettes")), tostring(run("SkinApplier")), tostring(run("CosmeticsOwnership")),
}, "\n")
```

- [ ] **Step 3: Confirm the damage path is still clean**

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local leaks = {}
for _, s in { ServerScriptService.Blaster.Scripts.ShotResolver, ServerScriptService.Weapons.Scripts.WeaponUpgradeService } do
	if s.Source:find("Renown", 1, true) or s.Source:find("Cosmetics", 1, true) then
		table.insert(leaks, s.Name)
	end
end
return #leaks == 0 and "clean" or ("LEAK: " .. table.concat(leaks, ", "))
```

Expected: `clean`.

- [ ] **Step 4: Confirm no existing file was modified by the earn path**

```bash
git diff --stat 96e40fd..HEAD -- FPSSystem/ | grep -E "ShotResolver|KillStats|Leveling|CashService|WeaponShopService|WeaponUpgradeService" || echo "no earn-path file modified"
```

Expected: `no earn-path file modified`. `WeaponShopService.luau` will appear in the overall diff from Phase 1, so scope the check to this phase's range if needed.

- [ ] **Step 5: Write the change log and commit**

Write `FPSSystem/FPS-Renown-Phase-2.md` in the project's Summary / Cause / Changes / Verification / Notes shape, matching the existing logs. Cite every number above. Record the traps encountered. End with a `Status:` line stating plainly what was confirmed live and what still needs a person.

```bash
git add FPSSystem/
git commit -m "Add change log: Renown, Phase 2"
```
