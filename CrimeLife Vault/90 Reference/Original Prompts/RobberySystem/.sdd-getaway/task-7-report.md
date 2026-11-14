# Task 7 report — retire the Claim zones (untag, do not delete)

**Status: COMPLETE.** Four Claim zones retired by untagging. No part was destroyed, renamed,
reparented or cleared. Suite: **594 passed, 14 failed** (baseline ~594/15 — the count dropped by
exactly one, the predicted `ClaimZone` floor-probe failure). Clean boot confirmed.

Studio instance: `009e370d-dae2-402e-88e9-379b254ec753` — "Robbery System (placeId: 130328863401144)".

---

## Snapshot byte sizes

| Snapshot | Bytes |
|---|---|
| `before-snapshot.txt` | **1003** |
| `after-snapshot.txt` | **781** |

Both in the session scratchpad
(`/private/tmp/claude-501/-Users-luqpic/205c54d4-d137-4b84-aaca-94c33738a3c0/scratchpad/`).

### Before

```
=== TAG COUNTS ===
HeistZone = 6 : BankVaultZone1[role=BankVaultZone], BankVaultZone2[role=BankVaultZone], BankVaultZone3[role=BankVaultZone], BankZone[role=Lobby], ClaimZone[role=Claim], VaultZone[role=Vault]
SlowFoodsZone = 2 : RestaurantClaimZone[role=Claim], RestaurantZone[role=Restaurant]
Gas2GoZone = 2 : Gas2GoClaimZone[role=Claim], Gas2GoZone[role=Station]
NewsStationZone = 2 : NewsStationClaimZone[role=Claim], NewsroomZone[role=Newsroom]
=== THE FOUR CLAIM PARTS ===
EXISTS Workspace.HeistZones.ClaimZone | class=Part | pos=109.6,18.5,-131.4 | tags={HeistZone} | attrs={ZoneRole=Claim}
EXISTS Workspace.SlowFoodsZones.RestaurantClaimZone | class=Part | pos=45.0,7.0,-272.4 | tags={SlowFoodsZone} | attrs={ZoneRole=Claim}
EXISTS Workspace.Gas2GoZones.Gas2GoClaimZone | class=Part | pos=-101.4,11.2,-240.0 | tags={Gas2GoZone} | attrs={ZoneRole=Claim}
EXISTS Workspace.NewsStationZones.NewsStationClaimZone | class=Part | pos=-215.0,7.0,-269.6 | tags={NewsStationZone} | attrs={ZoneRole=Claim}
```

### After

```
=== TAG COUNTS ===
HeistZone = 5 : BankVaultZone1[role=BankVaultZone], BankVaultZone2[role=BankVaultZone], BankVaultZone3[role=BankVaultZone], BankZone[role=Lobby], VaultZone[role=Vault]
SlowFoodsZone = 1 : RestaurantZone[role=Restaurant]
Gas2GoZone = 1 : Gas2GoZone[role=Station]
NewsStationZone = 1 : NewsroomZone[role=Newsroom]
=== THE FOUR CLAIM PARTS ===
EXISTS Workspace.HeistZones.ClaimZone | class=Part | pos=109.6,18.5,-131.4 | tags={} | attrs={}
EXISTS Workspace.SlowFoodsZones.RestaurantClaimZone | class=Part | pos=45.0,7.0,-272.4 | tags={} | attrs={}
EXISTS Workspace.Gas2GoZones.Gas2GoClaimZone | class=Part | pos=-101.4,11.2,-240.0 | tags={} | attrs={}
EXISTS Workspace.NewsStationZones.NewsStationClaimZone | class=Part | pos=-215.0,7.0,-269.6 | tags={} | attrs={}
```

Verification targets from the scope change, all met: **HeistZone 5, SlowFoodsZone 1, Gas2GoZone 1,
NewsStationZone 1**, and all four parts still exist in Workspace. Each part had exactly one tag and
exactly one attribute before the edit, and has zero of each after — nothing else on them was touched.
Positions are byte-identical before and after.

---

## Step 1 — grep sweep, with judgement on each hit

### `ZoneRole == "Claim"` / `role ~= "Claim"` zone-role branches: **ZERO remain.**

Greps run: `Claim`, `ZoneRole`, `"Claim"`, `ClaimZone`, `roles%.Claim`, `interiorRole`,
`NewsStationZone`, `SlowFoodsZone`, `zone count unaffected`.

`ClaimZone` returned **no matches in any script** — no code addresses these parts by name.

`"Claim"` as a string literal returned only 5 hits, none of them a live zone-role read:

| Hit | Judgement |
|---|---|
| `BankInstance:248` `self.DuffelChanged:Fire(player, 0, "claim")` | **Keep.** Lowercase `"claim"` is a DuffelChanged *reason* string, not a zone role. Brief explicitly sanctions it. |
| `DuffelSpec:98` `expect.equal(reasons[2], "claim", "claim")` | **Keep.** Asserts the reason string above. |
| `ZoneSpec:147,153,164` `service({ "Vault", "Claim" })` | **Keep.** Synthetic in-test fixture parts built by the spec itself; `"Claim"` is an arbitrary role label exercising ZoneService's generic role machinery. Reads nothing from Workspace. Passes (Zone: 15/0). |

The remaining `Claim` hits are all the sanctioned name-keepers — `CashClaimVFX` (module name),
`RobberySuccess`, and prose comments ("claim-zone pattern", "on claim", the
`Getaway-Distance-Claim-And-GUI` spec name). None branch on a zone role.

### Live zone-role reads that remain, all legitimate

- `LocationServer:169` — `part:GetAttribute("ZoneRole") == cfg.interiorRole`. `interiorRole` is
  `Restaurant` / `Station` / `Newsroom`, never `Claim`. Unaffected.
- `Zone.lua:43` — asserts each *tagged* part has a `ZoneRole` string. The untagged parts are no
  longer swept, so this never sees them.
- `WorldSpec` role tallies — updated below.

### Finding the brief did not enumerate: three more boot asserts

`roles%.Claim` found the assert in **four** scripts, not the one the brief's Step 3 names:

```
ServerScriptService.HeistServer        assert(roles.Lobby and roles.Vault and roles.Claim and roles.BankVaultZone,
ServerScriptService.SlowFoodsServer    assert(roles.Restaurant and roles.Claim,
ServerScriptService.Gas2GoServer       assert(roles.Station and roles.Claim,
ServerScriptService.NewsStationServer  assert(roles.Newsroom and roles.Claim,
```

Each also carried a matching `#zones == 2` exact-count assert. Leaving the three location servers
untouched would have made SlowFoods, Gas2Go and NewsStation all fail to boot the instant the tags
came off — the exact "broken window" the brief's ordering section warns against. Updating them is
forced by the untagging decision, not a scope expansion. All four were changed together, then the
parts were untagged, back to back.

---

## Before/after of every edit

### 1. `ServerScriptService.HeistServer` (3 edits)

```lua
-- BEFORE
	-- 3 original (Lobby, Vault, Claim) + 3 BankVaultZone volumes (spec
	-- addendum, 2026-09-11) covering the underground gauntlet between them --
-- AFTER
	-- 2 original (Lobby, Vault) + 3 BankVaultZone volumes (spec
	-- addendum, 2026-09-11) covering the underground gauntlet between them --
	-- the Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
```

```lua
-- BEFORE
	assert(#zones == 6,
		string.format("[HeistServer] expected exactly 6 HeistZone parts (Lobby, Vault, Claim, 3x BankVaultZone), found %d", #zones))
-- AFTER
	assert(#zones == 5,
		string.format("[HeistServer] expected exactly 5 HeistZone parts (Lobby, Vault, 3x BankVaultZone), found %d", #zones))
```

```lua
-- BEFORE
	assert(roles.Lobby and roles.Vault and roles.Claim and roles.BankVaultZone,
		"[HeistServer] HeistZone parts must cover roles Lobby, Vault, Claim and BankVaultZone")
-- AFTER
	assert(roles.Lobby and roles.Vault and roles.BankVaultZone,
		"[HeistServer] HeistZone parts must cover roles Lobby, Vault and BankVaultZone")
```

### 2. `ServerScriptService.SlowFoodsServer` (2 edits)

```lua
-- BEFORE
	assert(#zones == 2,
		string.format("[SlowFoodsServer] expected exactly 2 SlowFoodsZone parts (Restaurant, Claim), found %d", #zones))
-- AFTER
	-- The Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	assert(#zones == 1,
		string.format("[SlowFoodsServer] expected exactly 1 SlowFoodsZone part (Restaurant), found %d", #zones))
```

```lua
-- BEFORE
	assert(roles.Restaurant and roles.Claim,
		"[SlowFoodsServer] SlowFoodsZone parts must cover roles Restaurant and Claim")
-- AFTER
	assert(roles.Restaurant,
		"[SlowFoodsServer] SlowFoodsZone parts must cover role Restaurant")
```

### 3. `ServerScriptService.Gas2GoServer` (2 edits)

Same shape, `2 -> 1`, role `Station`:

```lua
-- BEFORE
	assert(#zones == 2,
		string.format("[Gas2GoServer] expected exactly 2 Gas2GoZone parts (Station, Claim), found %d", #zones))
	...
	assert(roles.Station and roles.Claim,
		"[Gas2GoServer] Gas2GoZone parts must cover roles Station and Claim")
-- AFTER
	-- The Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	assert(#zones == 1,
		string.format("[Gas2GoServer] expected exactly 1 Gas2GoZone part (Station), found %d", #zones))
	...
	assert(roles.Station,
		"[Gas2GoServer] Gas2GoZone parts must cover role Station")
```

### 4. `ServerScriptService.NewsStationServer` (2 edits)

Same shape, `2 -> 1`, role `Newsroom`:

```lua
-- BEFORE
	assert(#zones == 2,
		string.format("[NewsStationServer] expected exactly 2 NewsStationZone parts (Newsroom, Claim), found %d", #zones))
	...
	assert(roles.Newsroom and roles.Claim,
		"[NewsStationServer] NewsStationZone parts must cover roles Newsroom and Claim")
-- AFTER
	-- The Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	assert(#zones == 1,
		string.format("[NewsStationServer] expected exactly 1 NewsStationZone part (Newsroom), found %d", #zones))
	...
	assert(roles.Newsroom,
		"[NewsStationServer] NewsStationZone parts must cover role Newsroom")
```

### 5. `ServerScriptService.Heist.Tests.WorldSpec` (14 edits across two passes)

**How it counts — the decision point.** `WorldSpec` counts zones purely by tag:

```lua
	local function tagged(tag)
		return CollectionService:GetTagged(tag)
	end
```

Every zone assertion goes through `tagged(...)`. Nothing walks the `*Zones` folders' children. So
untagging satisfies `WorldSpec` exactly as a deletion would — the condition the brief set for
proceeding without coming back to you. No assert was weakened to get green.

| Assertion | Before | After |
|---|---|---|
| Bank manifest | `#tagged("HeistZone"), 6, "zones"` | `5` |
| SlowFoods manifest | `#tagged("SlowFoodsZone"), 2, "restaurant zones (Restaurant, Claim)"` | `1, "restaurant zone (Restaurant)"` |
| SlowFoods manifest regression guard | `#tagged("HeistZone"), 6, "Bank's zone count unaffected"` | `5` |
| Gas2Go manifest | `#tagged("Gas2GoZone"), 2, "Gas2Go zones (Station, Claim)"` | `1, "Gas2Go zone (Station)"` |
| Gas2Go manifest regression guard | `#tagged("HeistZone"), 6, "Bank's zone count unaffected"` | `5` |
| Gas2Go manifest regression guard | `#tagged("SlowFoodsZone"), 2, "SlowFoods' zone count unaffected"` | `1` |

Test names and role tallies:

```lua
-- BEFORE  suite:test("SlowFoodsZone parts cover roles Restaurant and Claim, exactly one each", ...)
-- AFTER   suite:test("SlowFoodsZone parts cover role Restaurant, exactly one", ...)
		expect.equal(roles.Restaurant, 1, "one Restaurant zone")
-		expect.equal(roles.Claim, 1, "one Claim zone")

-- BEFORE  suite:test("Gas2GoZone parts cover roles Station and Claim, exactly one each", ...)
-- AFTER   suite:test("Gas2GoZone parts cover role Station, exactly one", ...)
		expect.equal(roles.Station, 1, "one Station zone")
-		expect.equal(roles.Claim, 1, "one Claim zone")

-- BEFORE  suite:test("Lobby, Vault and Claim roles are each unique", ...)
-- AFTER   suite:test("Lobby and Vault roles are each unique", ...)
-		expect.truthy(seen.Lobby and seen.Vault and seen.Claim, "Lobby, Vault and Claim all present")
+		expect.truthy(seen.Lobby and seen.Vault, "Lobby and Vault both present")
```

Bank manifest comment:

```lua
-- BEFORE
		-- Lobby, Vault, Claim + 3 BankVaultZone volumes (spec addendum,
		-- 2026-09-11) covering the underground gauntlet between them.
-- AFTER
		-- Lobby, Vault + 3 BankVaultZone volumes (spec addendum, 2026-09-11)
		-- covering the underground gauntlet between them. The Claim zone was
		-- retired when the distance-based getaway replaced the claim-zone
		-- cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19) -- the
		-- part still exists in Workspace, untagged, so the change is reversible.
```

**One whole test removed** — `"the Claim and Lobby zones do not overlap"`. It resolved the Claim zone
by role (`byRole.Claim`) and then indexed it, so after untagging it died with
`WorldSpec:514: attempt to index nil with 'Position'`. Its stated purpose was to prove "banking has
to require crossing the door" — an invariant of the Claim *zone*, which no longer exists as a tagged
zone. That guarantee is now `EscapeDistance = 200` and is covered by `GetawaySpec` (14/0). Replaced
in place by a comment recording the removal and why, so the archive keeps the reasoning:

```lua
	-- The "Claim and Lobby zones do not overlap" test was removed here when the
	-- distance-based getaway replaced the claim-zone cash-out (spec:
	-- Getaway-Distance-Claim-And-GUI, 2026-09-19). It existed to prove banking
	-- required physically crossing the door -- an invariant of the Claim ZONE,
	-- which no longer exists as a tagged zone. The equivalent guarantee is now
	-- EscapeDistance (200 studs) and is covered by GetawaySpec, not by geometry
	-- here. The ClaimZone part itself is still in Workspace, untagged.
```

`WorldSpec` has **no NewsStation zone assertions at all** (confirmed by grep) — nothing to change
there.

### 6. World edit — the untagging

```lua
CS:RemoveTag(part, tag)
part:SetAttribute("ZoneRole", nil)
```

applied to the four parts. No `:Destroy()`, no `:ClearAllChildren()`, no reparent, no rename.
Per-part confirmation:

```
Workspace.HeistZones.ClaimZone | removed tag HeistZone (had=true) | cleared ZoneRole (was=Claim) | still exists=true | tags now={} | attrs now={}
Workspace.SlowFoodsZones.RestaurantClaimZone | removed tag SlowFoodsZone (had=true) | cleared ZoneRole (was=Claim) | still exists=true | tags now={} | attrs now={}
Workspace.Gas2GoZones.Gas2GoClaimZone | removed tag Gas2GoZone (had=true) | cleared ZoneRole (was=Claim) | still exists=true | tags now={} | attrs now={}
Workspace.NewsStationZones.NewsStationClaimZone | removed tag NewsStationZone (had=true) | cleared ZoneRole (was=Claim) | still exists=true | tags now={} | attrs now={}
```

**To reverse:** re-add the one tag and re-set `ZoneRole = "Claim"` on each of the four, and revert the
five scripts. The geometry never moved.

---

## Compile check

All five edited scripts, via `loadstring(...Source)`:

```
HeistServer: COMPILES OK
SlowFoodsServer: COMPILES OK
Gas2GoServer: COMPILES OK
NewsStationServer: COMPILES OK
WorldSpec: COMPILES OK
```

---

## Suite result — 594 passed, 14 failed

Run via `TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)()`.

**`World: 50 passed, 0 failed`.** The success signal landed: the pre-existing
`ClaimZone: no floor found within 6 studs of the zone's own bottom` failure is **gone**, because the
probe iterates tagged zones and `ClaimZone` is no longer tagged. No new `World` failure replaced it.

**`Getaway: 14 passed, 0 failed`. `LocationServer: 17 passed, 0 failed`.** Both at zero, as required.

### Exact failing assertions, all 14 — none mine

`RestaurantConfig: 3 passed, 1 failed`
- `carries the spec's tunables :: CooldownDuration (20 minutes) — expected 1200, got 60`

`Gas2GoConfig: 3 passed, 1 failed`
- `carries the spec's tunables :: CooldownDuration (10 minutes) — expected 600, got 60`

`CashClaimVFX: 0 passed, 12 failed` — every one
`ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'`:
- `construction builds a persistent Cash display showing the initial value`
- `PlaySequence animates the display up to the exact new value, no drift`
- `the displayed value never exceeds the true new value mid-animation`
- `burst count is fixed regardless of the claimed amount -- not scaled to the amount`
- `burst icons are ImageLabels using the real cash decal, not procedural shapes`
- `burst icons spawn at the configured burstOrigin, not screen center, when one is supplied`
- `burstOrigin defaults to screen center when none is supplied (e.g. in tests)`
- `cleans up every burst icon and the burst ScreenGui once the sequence completes`
- `calling PlaySequence when the value hasn't changed is a no-op`
- `a second claim animates from the previous displayed value, not from zero`
- `the passive leaderstats listener updates the display when no claim animation is in progress`
- `a same-claim passive Value-change racing a PlaySequence call does not swallow the animation`

1 + 1 + 12 = 14, exactly the pre-existing set named in the task instructions. Nothing else failed.

### Baseline reconciliation

The viewport **recovered during this task** — `Hazard` (22/0), `UITransitions` (7/0),
`CounterBarrier` (7/0) and `SupplyObject` (25/0) are all green now, where they were failing for
environmental reasons at hand-off. That accounts for the difference between the ~581/28 reading in
the task instructions and the 594/14 here. Measured against the true ~594/15 baseline, the count
dropped by exactly one — the `ClaimZone` floor probe. No other baseline failure vanished or appeared.

---

## Step 7 — clean boot

`start_stop_play(true)`, then `get_console_output`:

```
[SlowFoodsServer] SlowFoods booted: SlowFoodsAccessBarrier=3 CashRegister=4, zones=1
[NewsStationServer] NewsStation booted: ... Safe=3, zones=1
[Gas2GoServer] Gas2Go booted: ... pulseLights=7, zones=1
[HeistServer] Bank booted: ... zones=5, alarmLights=0, templights=12
```

All four locations boot. **No `[HeistServer] expected exactly N HeistZone parts` assertion**, and none
from the three location servers either. Play stopped afterwards; the place is back in Edit mode.

Remaining console noise is pre-existing and unrelated: `DataStoreService:
StudioAccessToApisNotAllowed` (Studio API access is off, and `DataStoreBackend` degrades to its
in-memory backend by design) and `Failed to load sound rbxassetid://90`.

---

## Concerns

1. **Scope: three extra scripts edited.** `SlowFoodsServer`, `Gas2GoServer` and `NewsStationServer`
   each carried their own `#zones == 2` + `roles.Claim` boot assert that the brief's Step 3 did not
   mention. They had to change or those three locations would not boot. Flagging because it is more
   files than the brief listed.
2. **A whole test was deleted, not just a count.** `"the Claim and Lobby zones do not overlap"` is
   gone. I judged it obsolete rather than weakenable — it dereferences a zone that no longer exists,
   and its invariant is now `GetawaySpec`'s. If you would rather it were kept in some skipped form,
   this is the one edit to revisit.
3. **`multi_edit`'s `replace_all: true` silently did nothing.** It reported "11 edits applied" while
   leaving both `#tagged("HeistZone"), 6, "Bank's zone count unaffected"` lines at `6`. Caught by the
   suite, then fixed with two uniquely-anchored edits. Worth distrusting `replace_all` on this MCP
   going forward — the applied-count in the response is not trustworthy evidence.
4. **Line-number skew confirmed again.** `script_grep` and `script_read` disagreed in `WorldSpec` by
   roughly +10 near the top and +60 further down — not a constant offset. Every edit was anchored on
   quoted code, never a line number.
5. **Not covered by any test:** `NewsStationServer`'s boot assert. `WorldSpec` has no NewsStation
   zone assertions, so the only proof it is correct is the clean-boot line `zones=1` above, plus the
   compile check.
6. **Reversibility is intact but undocumented in-place.** The four parts keep their original names
   and positions and are now tag-free and attribute-free. Nothing in the world marks them as
   deliberately retired — only the script comments do. If you want a breadcrumb on the parts
   themselves, say so and I will add a descriptive attribute.
