# Task 5 — fix round 1: three items, all in `ServerScriptService.HeistServer`

Scope: `ServerScriptService.HeistServer` ONLY. No other file, no world part, no boot assert.
Snapshot first to `.sdd-getaway/snapshots/HeistServer.fix1.before.lua` (read `.Source` via
`execute_luau`, write with the Write tool, confirm non-empty ~47 KB) before any edit.

The Bank has no unit-test coverage — `RunAll` loads only ModuleScripts under `Heist.Tests` and
`HeistServer` is a bootstrapping Script. Also, the Studio viewport is currently NOT drawing
(`RenderStepped` 0 fps), so tween/wall-clock specs fail for environmental reasons and the suite is
NOT a usable gate. Your evidence is: careful reading, and a compile check:

```lua
-- execute_luau, datamodel_type "Edit" -- builds the chunk without running it
local fn, err = loadstring(game.ServerScriptService.HeistServer.Source)
return fn and "COMPILES OK" or ("COMPILE FAILED: " .. tostring(err))
```

Run that after every edit. A compile failure here means the Bank is dead on next Play.

---

## Item 1 — the stale Duffel Full toast (and the comment that describes it)

**Line 1019** (confirmed by `script_read`; `script_grep` reports 943 and an earlier report said
1018 — trust `script_read`). Indentation is 6 tabs, em dash is U+2014:

```lua
					net:Toast(player, "Duffel Full — head back to claim it.")
```

Change the message to exactly: `Duffel Full — get clear of the building to bank it.`
(em dash U+2014, identical to the `cap_exceeded` string). This is the only remaining occurrence
game-wide — "head back" is now wrong advice, since that zone no longer pays out.

Then fix the now-false comment at **lines 339-341**, above `cap_exceeded`:

```lua
	-- Shared with the ATM machines' RobbableObject onRefused (spec addendum,
	-- 2026-09-14) -- same wording already used by the heartbeat's own
	-- Duffel Full toast below, not a new message.
```

Once Item 1 lands the two wordings match again, so the clause becomes true — but "not a new
message" is still false, since both changed. Reword it so it describes reality: the wording is
shared with the heartbeat's Duffel Full toast, and both were updated when the claim zone was
replaced by the getaway. Keep the ATM/RobbableObject sentence, which is still accurate.

## Item 2 (Important) — the three-role union exists in two places

`isInsideBank` (line 788) was introduced so the union lives in ONE place, and
`updateZoneOccupancy` now calls it. But a verbatim second copy survives in the `onForfeit`
closure at **lines 182-187**:

```lua
	onForfeit = function(player, cause)
		local isInside = zoneService:IsInside("Lobby", player)
			or zoneService:IsInside("Vault", player)
			or zoneService:IsInside("BankVaultZone", player)
		forfeit:Eject(bank, player, cause, isInside)
	end,
```

Its own comment (lines 178-181) says it is "reusing the exact same ZoneService occupancy already
driving the heist-timer GUI below" — so it is MEANT to be the same expression, not an independent
one. Leaving two copies reintroduces exactly the drift the helper was extracted to prevent: add a
fourth interior volume later, update `isInsideBank`, miss this one, and a forfeited player standing
in the new volume is judged "not on the premises" and never teleported to ExitSpawn.

**Fix (this is the file's own established pattern — lines 136-143 already forward-declare `bank`
and `zoneService` for precisely this reason):**

1. Add `local isInsideBank` to the forward-declaration block at lines 142-143.
2. Change line 788 from `local function isInsideBank(player)` to `function isInsideBank(player)`
   (it now assigns the forward-declared local rather than making a new one).
3. Replace lines 183-185 with `local isInside = isInsideBank(player)`.

Safety: the `onForfeit` closure is only invoked from `BankInstance:_seal`, which has exactly one
call site (timer expiry), long after line 788 has executed. Verify that for yourself before
committing to the change — if you find a path where `onForfeit` could fire during boot, STOP and
report it instead of shipping a nil call.

Afterwards, confirm `zoneService:IsInside("Lobby"` appears exactly ONCE in the file.

## Item 3 (Important) — the anchor lookup can hang the Bank silently

**Line 847:**

```lua
local bankAnchor = workspace:WaitForChild("HeistMarkers"):WaitForChild("StatusBillboardAnchor")
```

Two untimed `WaitForChild` calls at the top level of a Script, with no assert. If `HeistMarkers` or
`StatusBillboardAnchor` is ever renamed, moved or deleted, this blocks FOREVER with no error and no
warning. Everything below never wires up — the robbery trigger, `PlayerAdded`/`PlayerRemoving`, and
the whole heartbeat `task.spawn`. The Bank goes completely inert while the console stays clean, and
the `[HeistServer] Bank booted:` print sits ABOVE this line so it still prints and looks healthy.

That is the exact failure mode this file's own boot-validation block was written against — see its
comment at lines 48-50: "a misconfigured tag must surface the moment you press Play, not forty
minutes into a session."

**Fix — match the already-reviewed reference**, `LocationServer` lines 226-229:

```lua
		local markers = workspace:WaitForChild(cfg.markerFolder, 10)
		local anchor = markers and markers:WaitForChild("StatusBillboardAnchor", 10)
		assert(anchor, string.format("[%sServer] %s has no StatusBillboardAnchor",
			cfg.name, cfg.markerFolder))
```

Use the bounded 10-second form for both lookups and assert the result, with a message naming
`[HeistServer]` and `HeistMarkers` in this file's own assert style. `HeistClient:344` uses the same
10-second form — this is the house convention and line 847 is the outlier.

This is my defect, not the previous implementer's: line 847 is my brief's verbatim text.

---

## Report contract

Append to `.sdd-getaway/task-5-report.md`: before/after for all three items, the compile-check
output after each, and the post-fix count of `zoneService:IsInside("Lobby"` occurrences.

Return ONLY: status, compile-check result, the `IsInside("Lobby"` occurrence count, and concerns.
