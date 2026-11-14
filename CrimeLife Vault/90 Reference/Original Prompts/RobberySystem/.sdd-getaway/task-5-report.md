# Task 5 report — wire `Getaway` into `HeistServer` (the Bank)

**Status:** COMPLETE, with two brief deviations (both forced, both flagged below) and one
environmental caveat on the suite.

- **Studio:** `Robbery System (placeId: 130328863401144)`, `studio_id 009e370d-dae2-402e-88e9-379b254ec753`
- **File modified:** `ServerScriptService.HeistServer` — and nothing else.
- **Before:** 45,249 bytes / 1,008 lines. **After:** 47,214 bytes / 1,048 lines.

---

## STEP ZERO — snapshot

`/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/snapshots/HeistServer.before.lua`

**45,249 bytes, 1,008 lines** — byte-identical to the live pre-edit source.

HTTP is disabled in this place ("HTTP requests are not enabled. Enable via Experience Settings"), so
the source could not be POSTed out, and enabling `HttpService` would have been a place-setting change
outside the scope fence. The snapshot was therefore transcribed in seven whole-line chunks, and each
chunk was verified against Studio's own byte count as it was appended (7509 / 14680 / 21548 / 28795 /
35610 / 41607 / 45249). Equality was then confirmed on content, not just length, with an adler32
computed on both sides:

    Studio (Luau, loop seeded a=0)   len=45249  adler=274627075
    corrected to the standard a=1 seed          -> 3240065540
    local file (python zlib.adler32) len=45249  adler=3240065540   MATCH

---

## Edits

### 1. Require (line 33)

    before:  local Forfeit = require(Heist.Services.Forfeit)
             local AlarmEffects = require(Heist.Services.AlarmEffects)

    after:   local Forfeit = require(Heist.Services.Forfeit)
             local Getaway = require(Heist.Services.Getaway)
             local AlarmEffects = require(Heist.Services.AlarmEffects)

Placed between `Forfeit` and `AlarmEffects`, matching `LocationServer`'s own require order.

### 2. `isInsideBank` + `updateZoneOccupancy` refactor (lines 777-802)

    before:  local insideBuilding = {}
             local function updateZoneOccupancy()
                 for _, player in ipairs(Players:GetPlayers()) do
                     local inside = zoneService:IsInside("Lobby", player)
                         or zoneService:IsInside("Vault", player)
                         or zoneService:IsInside("BankVaultZone", player)
                     if insideBuilding[player] ~= inside then
                     ...

    after:   -- Same union updateZoneOccupancy uses: Lobby OR Vault OR BankVaultZone --
             -- the lobby, the vault, and the whole underground gauntlet between them.
             -- This gate is what makes the Bank correct: its VaultZone is 314 studs
             -- horizontally from its own StatusBillboardAnchor, so without it an
             -- EscapeDistance of 200 would bank the bag the instant it filled, with no
             -- getaway at all.
             --
             -- Declared ahead of updateZoneOccupancy rather than beside the Getaway
             -- construction further down, so that both callers share this one expression:
             -- a local referenced above its own declaration resolves to a nil global.
             local function isInsideBank(player)
                 return zoneService:IsInside("Lobby", player)
                     or zoneService:IsInside("Vault", player)
                     or zoneService:IsInside("BankVaultZone", player)
             end

             local insideBuilding = {}
             local function updateZoneOccupancy()
                 for _, player in ipairs(Players:GetPlayers()) do
                     local inside = isInsideBank(player)
                     if insideBuilding[player] ~= inside then
                     ...

The union body is the brief's verbatim text; only its position moved. See DEVIATION 1.

### 3. Claim handler deleted, replaced by `bankBag` + the Getaway (lines 827-854)

    before:  -- Cash-out on crossing into the lobby, per spec 6.4: automatic, no prompt.
             zoneService.Entered:Connect(function(role, player)
                 if role ~= "Claim" then return end
                 local amount = bank:Claim(player)
                 if amount <= 0 then return end
                 local banked = math.floor(amount)
                 currency:Add(player.UserId, banked)
                 net:Toast(player, string.format("Banked %d %s.", banked, Config.CurrencyName))
                 -- Cash burst + flying-cash-GUI trigger (spec addendum, 2026-09-09) --
                 -- fired after currency:Add so leaderstats.Cash.Value has already
                 -- replicated the new total by the time the client reacts to this.
                 net:NotifyRobberySuccess(player)
             end)

    after:   -- The payout, moved verbatim out of the old claim-zone Entered handler
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

             -- Distance-based payout, replacing the Claim zone (spec:
             -- Getaway-Distance-Claim-And-GUI, 2026-09-19). Constructed here, below both
             -- updateZoneOccupancy and bankBag, because it captures isInsideBank (the
             -- shared three-role union) and bankBag: Getaway.new asserts on a nil
             -- onEscaped, so building it any earlier would fail at boot.
             local bankAnchor = workspace:WaitForChild("HeistMarkers"):WaitForChild("StatusBillboardAnchor")
             local getaway = Getaway.new({
                 escapeDistance = Config.EscapeDistance,
                 anchor = bankAnchor,
                 isInsideBuilding = isInsideBank,
                 getDuffel = function(player) return bank:GetDuffel(player) end,
                 getPlayers = function() return Players:GetPlayers() end,
                 onEscaped = bankBag,
             })

The payout body is byte-for-byte the old handler body. `script_grep "role ~= \"Claim\""` now returns
"No matches found". `BankInstance:Claim`'s `_state ~= ACTIVE` / `IsParticipant` guards were not
touched. See DEVIATION 2 for why the Getaway construction sits here rather than higher up.

### 4. Heartbeat (lines 1001-1010)

    before:      bank:Step()
                 zoneService:Update()
                 alarm:Update()
                 updateZoneOccupancy()

    after:       bank:Step()
                 zoneService:Update()
                 alarm:Update()
                 updateZoneOccupancy()
                 -- Last of the sweep, so the getaway's isInsideBuilding reads the
                 -- occupancy this same tick's zone pass just established rather than the
                 -- previous tick's -- the same ordering LocationServer:Tick uses. Outside
                 -- the Active branch below: a bag can still be carried clear of the
                 -- building after the session has sealed.
                 getaway:Step()

Same position `LocationServer:Tick` uses: after the zone sweep and `_updateZoneOccupancy`, and
outside the `if bank:GetState() == "Active"` branch.

### 5. Refusal message (line 342)

    before:  cap_exceeded = "Duffel Full — head back to claim it.",
    after:   cap_exceeded = "Duffel Full — get clear of the building to bank it.",

Em dash preserved on both sides, as the brief specifies.

### 6. `getaway:Forget` on player removal (lines 955-957) — ADDITION beyond the brief

    before:      forfeit:Forget(player)
                 duffelBagAttachment:Forget(player)

    after:       forfeit:Forget(player)
                 -- Same cleanup LocationServer:ForgetPlayer does: without it Getaway's
                 -- fired-once latch keeps a strong reference to the departed Player.
                 getaway:Forget(player)
                 duffelBagAttachment:Forget(player)

Not in the brief's step list. Added because `LocationServer:ForgetPlayer` calls `self.getaway:Forget`
(line 347) and operational instruction 8 was to mirror that shape; without it `Getaway._fired[player]`
pins a departed `Player` instance forever, which is the exact leak the block's own 2026-09-16
regression comment was added for. Zero behavioural risk (it only nils a table entry). Remove it if
you want the brief followed literally.

---

## Deviations from the brief (both forced by Lua scoping)

**DEVIATION 1 — `isInsideBank` is declared above `updateZoneOccupancy`, not with the Getaway block.**
Step 2 asks for both "place it after `updateZoneOccupancy` is defined" and "refactor
`updateZoneOccupancy` to call `isInsideBank(player)`". Those are mutually exclusive: a `local`
referenced above its own declaration compiles to a *global* read, so the literal ordering would make
`updateZoneOccupancy` call `nil` on the first heartbeat tick. The function is therefore declared
immediately above `updateZoneOccupancy`, which still satisfies the stated rationale ("so the union
lives in one place" / "shared rather than written twice"). Body and comment are the brief's verbatim
text; a short note explaining the placement was appended to the comment.

**DEVIATION 2 — the Getaway is constructed after `bankBag`, not immediately after `updateZoneOccupancy`.**
Same class of problem: Step 1 places `bankBag` where the old Claim handler was, which is ~30 lines
*below* `updateZoneOccupancy`, while Step 2 places `onEscaped = bankBag` immediately after
`updateZoneOccupancy`. Built there, `bankBag` would be nil and `Getaway.new` would throw its own
`"Getaway requires onEscaped"` assert at boot. The construction is therefore placed directly after
`bankBag`, which is still "after `updateZoneOccupancy` is defined" and satisfies operational
instruction 7 (declared before first use, able to see `bank` / `currency` / `net` / `Config`).

Net effect: declaration order is `isInsideBank` (787) -> `updateZoneOccupancy` (794) -> `bankBag`
(829) -> `bankAnchor`/`getaway` (846-854) -> `getaway:Forget` (957) -> `getaway:Step` (1010). Every
use follows its declaration.

---

## Step 5 — the Bank boots

    -- execute_luau, datamodel_type "Edit"
    HeistServer readable=true bytes=47214

Play-mode console (`start_stop_play` true, then `get_console_output`):

    [SlowFoodsServer] SlowFoods booted: SlowFoodsAccessBarrier=3 CashRegister=4, zones=2
    [HeistServer] Bank booted: CounterBarrier=4 HeistAccessBarrier=1 HeistC4Point=1
      HeistDeathVolume=1 HeistGate=5 HeistGuardPost=4 HeistLaser=16 HeistTeleporter=2
      HeistTerminal=2 ATM=2 BankRegister=3 Safe=2, zones=6, alarmLights=0, templights=12
    [Gas2GoServer] Gas2Go booted: Gas2GoAccessBarrier=27 Gas2GoRegister=2 Gas2GoATM=1
      pulseLights=7, zones=2
    [NewsStationServer] NewsStation booted: ... zones=2
    Failed to load sound rbxassetid://90: Request asset was not found
    DataStoreService: StudioAccessToApisNotAllowed: ... Data Store: HeistCurrency_v1
    [DataStoreBackend] Load attempt 1..4/5 failed: 403: ...
    Part Bolt / BoltBack / Flash / shell / Handle / Mag / gun is not parented to the
      Workspace or a WorldModel. GetConnectedParts will not include any other parts.

No `[HeistServer]` assertion. No `Getaway requires ...` error. The sound-404, DataStore-403 and
GetConnectedParts lines are all pre-existing boot noise unrelated to this task (API access is off in
Studio). Boot asserts still expect and find 6 HeistZone parts including Claim:

    HeistZone parts=6 roles=BankVaultZone,BankVaultZone,BankVaultZone,Claim,Lobby,Vault

Note the `[HeistServer] Bank booted:` print sits at line 622, *above* the new code, so it alone does
not prove the getaway was constructed. That was proven separately, below.

---

## Live verification of the three-role union (the point of the task)

Measured horizontal distances from `Workspace.HeistMarkers.StatusBillboardAnchor`
(176.2, 136.4, -131.45):

    BankZone        role=Lobby           0.0
    ClaimZone       role=Claim          66.6
    BankVaultZone1  role=BankVaultZone 154.3
    BankVaultZone2  role=BankVaultZone 223.5
    BankVaultZone3  role=BankVaultZone 264.0
    VaultZone       role=Vault         314.0    <-- the 314 the brief warns about, confirmed

`Config.EscapeDistance` is 200 in all four configs (confirmed via `TestRunner.freshRequire`; note a
plain `require` returned `nil` from the stale session cache — gotcha 5 is live in this session).

Because `HeistServer` has no unit-test coverage, the union was exercised against the running server.
A client-side probe was attached to the `ZoneOccupancy` RemoteEvent — the direct readout of
`updateZoneOccupancy`, which now calls `isInsideBank` and sits one line above `getaway:Step()` in the
same heartbeat body — and the character was teleported (anchored, so gravity could not drag it out of
a volume mid-sample) between each zone and a point outside all of them.

Run A, entering each gauntlet volume from outside, produced the full alternation
(true/false x4) — every `BankVaultZone` volume reads as inside.

Run B was aimed specifically at the Vault, since run A entered it from the Lobby and so could not
distinguish "Vault is inside" from "state unchanged". Path
`outside -> VaultZone -> outside -> ClaimZone -> outside` produced exactly two events:

    Bank inside=true      <- VaultZone, at 314.0 studs horizontally
    Bank inside=false     <- back outside
    (no event for ClaimZone: it stays false)

So:

- **Lobby, all three BankVaultZone volumes, and the Vault all report inside=true.** At 314 studs the
  Vault reads as inside the building, so `Getaway:Step` skips the player entirely and cannot bank the
  bag underground. This is the failure the task exists to prevent, and it does not occur.
- **ClaimZone reports false**, correctly — it is outside the building, and at 66.6 studs it is also
  far short of the 200 needed, so the old claim zone now pays out nothing. That matches the design.
- The broadcast firing at all proves the heartbeat body is running, which in turn proves execution
  passed `workspace:WaitForChild("HeistMarkers"):WaitForChild("StatusBillboardAnchor")` and
  `Getaway.new(...)` — both sit above the `task.spawn` that owns the loop. The anchor is present in
  the server datamodel, so the un-timed `WaitForChild` (the brief's verbatim form) returns
  immediately and cannot stall.

---

## Step 6 — suite

**TOTAL: 581 passed, 28 failed.**

Baseline before any edit, same session: **TOTAL: 594 passed, 15 failed** — World x1,
RestaurantConfig x1, Gas2GoConfig x1, CashClaimVFX x12. Getaway 0, LocationServer 0.

Failing suites now:

    World x1              (ClaimZone floor)          PERMITTED
    RestaurantConfig x1   (CooldownDuration)         PERMITTED
    Gas2GoConfig x1       (CooldownDuration)         PERMITTED
    CashClaimVFX x12      (WaitForChild on nil)      PERMITTED
    SupplyObject x5       (permitted x0-or-1)        OVER — see below
    Hazard x1                                        NOT in the permitted set
    UITransitions x3                                 NOT in the permitted set
    CounterBarrier x4                                NOT in the permitted set

    Getaway:        14 passed, 0 failed   REQUIRED, met
    LocationServer: 17 passed, 0 failed   REQUIRED, met

### The four extra suites are the render-freeze, not a regression

Every one of the newly-failing assertions is a TweenService or wall-clock timer assertion
("settled at resting Y scale", "fully invisible once the tween completes", "red after fading in",
"countdown ticks down over real time"). Studio's render loop has stopped:

    RenderStepped=0.0 fps   Heartbeat=57.9 fps   (wall 0.50s)

and a direct probe confirms tweens are frozen rather than slow — a 0.25s linear tween is still at
0.000 after 0.82s of wall clock, stuck in `PlaybackState.Playing`:

    wallClockElapsed=0.82s  tweenValue=0.000  playbackState=Enum.PlaybackState.Playing

This is the documented trap in `Roblox/CLAUDE.md`: "TweenService is render-driven. With the Studio
viewport collapsed, RenderStepped reports 0 FPS and tweens do not advance — an environmental failure,
not a code fault." It is also the same root cause the brief already anticipated for SupplyObject's
flaky wall-clock test; the freeze simply made that test fail totally and pulled in its three sibling
tween suites. `RenderStepped` reads 0.0 in Play mode too, and `screen_capture` timed out, so the
Studio window itself is not drawing — I could not restore it from here, and did not try to force it
with synthetic mouse or keyboard input (that risks disturbing the world, which the scope fence
forbids).

Independent of the timing evidence: **no spec requires `HeistServer`.** `script_grep "HeistServer"`
returns only comment references from WorldSpec, BankInstanceSpec, GateSpec, LaserSpec, ZoneSpec,
HighlightSequencerSpec and LocationServerSpec. It is a bootstrapping `Script`, never loaded by
`RunAll`, so an edit confined to it cannot change any suite's result. The four suites are also
unrelated to the Bank's payout path by subject matter.

The stable, non-render-dependent failure set is exactly the baseline: World x1, RestaurantConfig x1,
Gas2GoConfig x1, CashClaimVFX x12.

**Recommended check before sign-off:** re-run the suite with the Studio window visible and the
viewport uncollapsed; the expectation is a return to the baseline 15-failure set.

---

## What I could NOT verify

1. **A real end-to-end Bank payout.** I did not run a full robbery (trigger -> accrue a duffel ->
   carry it 200 studs clear) and watch cash actually land. What is proven is the gate that decides
   whether a payout is even considered (`isInsideBank`, live, in all four zones), that the heartbeat
   calls `getaway:Step()`, and that `Getaway` itself banks correctly (its own 14 tests pass). The
   join between them — `onEscaped = bankBag` firing and crediting currency — is verified by reading
   and by the unchanged `Getaway` contract, not by observation.
2. **The near-complete GUI threshold** (remaining <= 25% of N). That is `HeistClient`, Task 6.
3. **The suite in a rendering Studio**, per above.
4. **Multi-player behaviour.** One player in the test session.

---

## Concerns for review

1. **The heartbeat's own Duffel Full toast still says "head back to claim it"** — `HeistServer` line
   1018, inside the accrual loop:

       net:Toast(player, "Duffel Full — head back to claim it.")

   Step 4 named only `REFUSAL_MESSAGES.cap_exceeded`, so I changed only that and left this one alone.
   Two consequences: (a) a player who fills their bag is still told to go back to a claim zone that no
   longer pays out — wrong in-game advice under the new design; and (b) the comment above
   `cap_exceeded` ("same wording already used by the heartbeat's own Duffel Full toast below, not a
   new message") is now false. `LocationServer` has no equivalent, as those locations have no
   continuous accrual, so there is no shared copy to follow. **Your call:** leave both as-is, or
   align the toast to "Duffel Full — get clear of the building to bank it." and drop the stale
   sentence from the comment. I did not pick silently.
2. **`getaway:Forget` was added** beyond the brief's steps — see edit 6.
3. **Both scoping deviations** — see DEVIATION 1 and 2. If the reviewer intended a forward-declared
   `local isInsideBank` / `local bankBag` instead, that is a mechanical change from here.
4. **The ClaimZone parts, the Claim role and all six boot asserts are untouched**, as required. Task 7
   still has its work intact. The `World` suite's ClaimZone-floor failure is the pre-existing
   baseline one, unchanged.
5. **`HttpService` is disabled** in this place. It was left disabled.

---

# Fix round 1 — three review items

**Status:** COMPLETE. All three items applied; final compile check passes; one count discrepancy vs.
the brief's own prediction is flagged below (not a defect in the edits — see Item 2 concern).

- **Studio:** `Robbery System (placeId: 130328863401144)`, `studio_id 009e370d-dae2-402e-88e9-379b254ec753`
- **File modified:** `ServerScriptService.HeistServer` only, per the fix brief's scope fence.
- **Snapshot:** `.sdd-getaway/snapshots/HeistServer.fix1.before.lua`, 47,213 bytes (Studio `.Source` read
  via `execute_luau` reported len=47214; the 1-byte difference is trailing-newline handling, not a
  content mismatch — every edit below was anchored on quoted code and verified by read-back, not on
  this byte count).
- **After:** 47,365 bytes / 1,051 lines (compiles).

## Item 1 — stale Duffel Full toast + false comment

**Before (line 1019, confirmed live before editing — matches the brief exactly):**

    net:Toast(player, "Duffel Full — head back to claim it.")

**After:**

    net:Toast(player, "Duffel Full — get clear of the building to bank it.")

Compile check after this edit: **COMPILES OK**.

**Before (lines 339-341, confirmed live — matches the brief exactly):**

    -- Shared with the ATM machines' RobbableObject onRefused (spec addendum,
    -- 2026-09-14) -- same wording already used by the heartbeat's own
    -- Duffel Full toast below, not a new message.

**After:**

    -- Shared with the ATM machines' RobbableObject onRefused (spec addendum,
    -- 2026-09-14) -- same wording as the heartbeat's own Duffel Full toast
    -- below; both were updated together when the claim zone was replaced by
    -- the getaway (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).

Compile check after this edit: **COMPILES OK**.

Verified live afterward: both strings are now byte-identical, each containing U+2014 (confirmed via
`utf8.codepoint` against the literal UTF-8 bytes `\xE2\x80\x94`), not a hyphen.

## Item 2 — the three-role union, collapsed to one place

**Safety check performed first, per the brief's instruction to verify before committing to the
change:** grepped every call site of `onForfeit` and of `_seal` across the whole game. `BankInstance`
stores `onForfeit` as `self.onForfeit` (set once in `BankInstance.new`) and calls it from exactly one
place, `BankInstance:_seal` (line 129 of that module: `pcall(self.onForfeit, player, cause)`). `_seal`
itself has exactly one caller, `BankInstance:Step` (timer-expiry branch), which is only ever invoked
from `HeistServer`'s heartbeat `task.spawn` loop — the very last thing the script wires up, long after
line 788 executes during linear boot. `bank:TryStart` (the only path to `ACTIVE`, a precondition for
`_seal`'s `Step`-driven timer branch) is likewise only reachable from a zone-entry/RemoteEvent
callback, never synchronously during boot. **No boot-time path calls `onForfeit`** — proceeded with
the change as instructed.

**Step 1 — forward-declare (before/after, lines 142-144):**

    before:  local bank
             local zoneService
    after:   local bank
             local zoneService
             local isInsideBank

Compile check: **COMPILES OK**.

**Step 2 — line 788, assign instead of shadow:**

    before:  local function isInsideBank(player)
    after:   function isInsideBank(player)

Compile check: **COMPILES OK**.

**Step 3 — collapse the duplicate copy in the `onForfeit` closure (before/after, lines 183-186):**

    before:  local isInside = zoneService:IsInside("Lobby", player)
                 or zoneService:IsInside("Vault", player)
                 or zoneService:IsInside("BankVaultZone", player)
             forfeit:Eject(bank, player, cause, isInside)

    after:   local isInside = isInsideBank(player)
             forfeit:Eject(bank, player, cause, isInside)

Compile check: **COMPILES OK**.

**Post-fix count of `zoneService:IsInside("Lobby"` in the file: 2, not 1.**

Concern (not a defect — flagging per the fix brief's own "ask rather than guess" instruction): the
brief predicted exactly one remaining occurrence. There were three before this fix, not two:

1. Line 183 (old) — the `onForfeit` closure's duplicate copy of the three-role union. **Removed.**
2. Line 789 (old) — inside `isInsideBank`'s own body. This is the canonical, single-sourced copy the
   brief's fix is about. **Kept, unchanged.**
3. Line 926 (old, in `watchCharacter`'s "Entry point B" handler) —
   `if not zoneService:IsInside("Lobby", player) then return end`. This is a **different, narrower
   check** for the weapon-triggers-robbery logic ("Trigger: a weapon equipped inside the lobby zone",
   per the comment a few lines above it) — it deliberately tests Lobby alone, not the three-role
   "on-premises" union. Routing it through `isInsideBank(player)` would be a functional regression: it
   would also fire the robbery trigger for a weapon equipped while deep in the Vault or a
   BankVaultZone gauntlet volume, which contradicts the stated intent of that trigger. I left it
   untouched. The brief's "exactly ONCE" prediction looks like an oversight that didn't account for
   this pre-existing, unrelated call site — the actual duplication the brief describes (the union
   reimplemented a second time) is fully resolved; the count is 2 for a legitimate reason.

## Item 3 — bounded, asserted anchor lookup

**Before (line 847, confirmed live — matches the brief exactly):**

    local bankAnchor = workspace:WaitForChild("HeistMarkers"):WaitForChild("StatusBillboardAnchor")

**After:**

    local heistMarkers = workspace:WaitForChild("HeistMarkers", 10)
    local bankAnchor = heistMarkers and heistMarkers:WaitForChild("StatusBillboardAnchor", 10)
    assert(bankAnchor, "[HeistServer] HeistMarkers has no StatusBillboardAnchor")

Compile check: **COMPILES OK**. Matches the `LocationServer` (lines 226-229) bounded-`WaitForChild`
convention the brief cites, confirmed by reading that reference live before writing this edit.

## Final verification

Full-file compile check after all six edits: **COMPILES OK** (47,365 bytes, 1,051 lines). Every edit
site was read back individually via `script_read` against the quoted before/after text above and
matches exactly. No spec suite run — per the brief, the Studio viewport is not drawing
(`RenderStepped` 0 fps), so tween/wall-clock specs are not a usable gate here; the compile check is the
evidence.
