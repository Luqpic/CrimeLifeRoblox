# Task 5 brief — wire Getaway into HeistServer (the Bank)

## Global Constraints

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

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

## The suite tripwire is NAMES, not counts

Totals here are not deterministic: `SupplyObject`'s "countdown ticks down over real time" test is a
wall-clock test that flips pass/fail with Studio's render state. Judge by the SET of failing suite
names. Permitted:

    World x1 (ClaimZone floor)          RestaurantConfig x1 (CooldownDuration)
    Gas2GoConfig x1 (CooldownDuration)  CashClaimVFX x12 (WaitForChild on nil)
    SupplyObject x0 or x1 (flaky)       Getaway 0 failed, LocationServer 0 failed

A failure in any other suite is a regression you caused. Report failing names explicitly.

## Studio gotchas that will waste your time if you do not know them

- `execute_luau` needs `datamodel_type` exactly `Edit`. `require()` and creating/parenting
  ModuleScripts both work from it.
- `script_read` needs `target_file` (dot-notation WITH a `game.` prefix), `should_read_entire_file`,
  `start_line_one_indexed`, `end_line_one_indexed_inclusive`. Using `path`/`start_line` silently
  returns the whole file.
- `script_grep` and `script_read` report DIFFERENT line numbers. Trust `script_read`; anchor every
  `multi_edit` on quoted code, never a line number.
- Studio caches `require` for the whole session. After editing a module, a plain `require()` returns
  the STALE pre-edit copy. Use `TestRunner.freshRequire(module)` or you will conclude your edit did
  not land when it did.

## Interface produced by Task 2 (built, reviewed, passing — do not re-create)

    Getaway.new{ escapeDistance, anchor|getAnchorPosition, isInsideBuilding,
                 getDuffel, onEscaped, getPlayers, getPosition? }
    Getaway:Step()  Getaway:DistanceRemaining(player) -> number?  Getaway:Forget(player)

Distance is horizontal. Fires `onEscaped` once per bag, re-arms when the duffel returns to 0.

## STEP ZERO — snapshot before you touch anything

There is no version control for this game code. Before your first edit, save the current source of
the one file you may touch:

```lua
-- execute_luau, datamodel_type "Edit"
return game.ServerScriptService.HeistServer.Source
```

Write it with the Write tool to
`/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/snapshots/HeistServer.before.lua`
and confirm it is non-empty (it should be roughly 50 KB) BEFORE making any edit. Report its byte
size. If the snapshot fails to write, stop and report BLOCKED — do not proceed unprotected.

## Scope fence

`ServerScriptService.HeistServer` ONLY. Do not touch `LocationServer` (Task 4 owns it and is done),
`HeistClient` (Task 6), any Config, `WorldSpec`, or any world part. **Do not delete the ClaimZone
parts and do not change the boot asserts** — Task 7 does that after the user approves it. The boot
asserts must still pass at the end of your task, still expecting 6 HeistZone parts including Claim.

## This is the task the whole design exists to protect

The Bank's `VaultZone` is 314 studs horizontally from the Bank's own `StatusBillboardAnchor`. If
`isInsideBank` is wrong, the bag banks the instant it fills, underground, with no getaway at all.
Get the three-role union right: `Lobby OR Vault OR BankVaultZone`.

## Report contract

Full report to `.sdd-getaway/task-5-report.md`: before/after of every edit site, the Play-mode
console output from Step 5, and the full suite output. Return ONLY: status, TOTAL line, failing
suite names, whether the Bank booted clean, and concerns.
