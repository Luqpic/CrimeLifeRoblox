# Task 6 report — the getaway widget in `HeistClient`

**Status: COMPLETE.** All 9 steps done. One environment fault found (Play-mode
`screen_capture` returns a blank frame); it blocked the pixel screenshot only, not the
verification.

Scope held: `StarterPlayer.StarterPlayerScripts.HeistClient` was the only script modified.

---

## STEP ZERO — snapshot

`.sdd-getaway/snapshots/HeistClient.before.lua` — **50,280 bytes, 1,083 lines.**

The place has HTTP disabled, and I did **not** toggle `HttpService.HttpEnabled` to get the
source out (a place-setting change outside my fence). The source was pulled in six 9,000-char
`string.sub` chunks instead, whose boundaries join cleanly, and the result was proven
byte-identical rather than assumed: a variant Adler-32 computed in Luau over the live
`.Source` and in Python over the saved file agree exactly.

```
Studio  : bytes=50280 adler=128507425
Snapshot: bytes=50280 adler=128507425
```

The first assembly was 1 byte short. A per-line length diff located it precisely — line 915,
a trailing space after `...halts the render loop immediately ` that the Write tool stripped.
Restored, then re-checksummed to the match above. The snapshot is a true byte-for-byte copy.

## Render-state measurement

Taken before any edit, and again inside Play mode. Both healthy — the viewport is not collapsed:

```
Edit mode : RenderStepped=14.6 fps  Heartbeat=58.2 fps  tween=100.0
Play mode : RenderStepped=14.6 fps  Heartbeat=58.5 fps  tween=100.0  viewport=900,719
```

`RenderStepped` is non-zero and a 0.2s tween reaches Completed, so the fill tween and the
per-frame countdown both advance. Nothing was mis-diagnosed against a frozen viewport.

---

## Edit sites — before / after

Seven edits, each anchored on quoted code (never a line number) and each **read back with
`script_read` afterwards** to confirm the new text is actually present. The `multi_edit`
"N edits applied" count was not treated as evidence. `replace_all` was not used anywhere.

### 1. Step 3 — the derived position chain

Before:
```lua
-- y 64..120. 128 preserves the original 8px gap beneath it. TOAST_CENTER below
-- is derived from this constant, so the cash-burst VFX origin follows it.
local TOAST_POSITION = UDim2.new(0.5, 0, 0, DUFFEL_TOP + 92 + HUD_GUTTER) -- below the 92px duffel
```
After:
```lua
-- y 64..120. 128 preserves the original 8px gap beneath it.
--
-- The getaway widget (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19) claims
-- the slot that used to be the toast's, and the toast moves down below it.
-- Extended through the same derived chain rather than with a literal, exactly
-- as the comment above requires -- and TOAST_CENTER further down is derived
-- from TOAST_POSITION, so the cash-burst VFX origin follows automatically.
local GETAWAY_TOP = DUFFEL_TOP + 92 + HUD_GUTTER      -- below the 92px duffel
local GETAWAY_POSITION = UDim2.new(0.5, 0, 0, GETAWAY_TOP)
local TOAST_POSITION = UDim2.new(0.5, 0, 0, GETAWAY_TOP + 76 + HUD_GUTTER) -- below the 76px getaway
```

Resolves to HUD_TOP 12 -> DUFFEL_TOP 96 -> GETAWAY_TOP 196 -> TOAST 280. `TOAST_CENTER` was
not hand-adjusted; it recomputed itself from `TOAST_POSITION` and the toast was observed live
at y=280 (see read-back below).

### 2. Step 4 — one widget per location, in the existing build loop

Added `local getawayWidgets = {}` beside `timerWidgets`/`duffelWidgets`, and inside the same
`for _, location in ipairs(LOCATIONS)` loop, built via the same `imagePanel` helper:

- root: `imagePanel(location .. "Getaway", "GetawayNormal", GETAWAY_POSITION)` -> 240x76
- `Studs` TextLabel: `UDim2.fromOffset(34, 12)`, size **144 x 32**, `Font.Display`,
  `TextSize` 28, `TextXAlignment = Right`, `ZIndex` 2
- `BarTrack` Frame: `UDim2.fromOffset(34, 64)`, size **190 x 6**, `ClipsDescendants`, corner r3
- `BarFill` Frame inside it: `UDim2.new(0, 0, 1, 0)`, corner r3, `ZIndex` 3

Stored as `{ root = ..., studs = ..., fill = ... }` so `setFillRatio` drives it unchanged.

I used the brief's **verified Figma geometry** (144 wide, right-aligned), not the plan's Step 4
prose (190 wide, matching the timer). This matters and the screenshot confirms it: the baked
`STUDS` suffix starts at x184, so a 190-wide label from x34 would run to x224 and collide with
it. At 144 the number ends at x178 with the intended 6px gap.

The track is a clipping parent so the fill can be sized in **Scale** — that is exactly what lets
the existing `setFillRatio` work untouched. The fill is top-left anchored with no `AnchorPoint`,
avoiding the documented `AnchorPoint (0, 0.5)` + `Position.Y = 0` trap.

### 3. Steps 1 & 2 — keep the anchor Parts, read `EscapeDistance` per location

`locationAnchors[location] = anchor` added to the existing billboard walk, which already
resolved the anchor on its way down to `StatusImage` and then discarded it. The bounded
`WaitForChild(..., 10)` and degrade-with-a-`warn` behaviour are untouched; a second `warn` was
added for a missing anchor specifically.

Added a `CONFIG_FOLDERS` map beside `MARKER_FOLDERS` and an `escapeDistances` loop that reads
`.EscapeDistance` from each location's own `Config` module in `ReplicatedStorage`. **No 200 is
hardcoded in the client.** Bounded waits plus a pcall'd `require`, same degrade-with-a-warn
discipline, so a bad config costs one location its widget rather than yielding the whole HUD.

### 4. The plan's missing declarations (known gap)

Declared all five new tables. `getawayWidgets` with edit 2, `locationAnchors`/`escapeDistances`
with edit 3, and here `getawayShown` + `getawayRemaining` beside `timerShown`/`duffelShown`,
with `getawayShown[location] = false` added to the existing init loop.

### 5. Step 7 — keep the heist timer up during the escape

`amount` hoisted above the timer block; the duffel block's now-duplicate
`local duffel` / `local amount` pair removed so the extrapolation happens exactly once.

Before:
```lua
local wantTimer = (session.state == "Active" and session.endsAt ~= nil and zoneOccupancy[location])
```
After:
```lua
local wantTimer = (session.state == "Active" and session.endsAt ~= nil
    and (zoneOccupancy[location] or amount > 0))
```

`zoneOccupancy` is retained as instructed — the 2026-09-06 addendum's removal of "a heist is
active somewhere" is not reinstated. The added term identifies the escaping player by their
holding a bag from this location.

### 6. Step 5 — per-location distance, in the existing `RenderStepped` loop

Inserted after the duffel block. Horizontal only (Y zeroed on both vectors), gated on
`anchor and characterRoot and escapeDistance and session.state == "Active" and amount > 0 and
not zoneOccupancy[location]`, writing `getawayRemaining[location]`.

I dropped the plan snippet's `local getawayWidget = getawayWidgets[location]` — Step 6 drives
the widgets after the loop, so that local is genuinely unused and would only be lint noise. The
brief's snippet also named a local `root`; I renamed it `characterRoot` to avoid confusion with
the widget roots used throughout this file.

### 7. Step 6 — only one getaway widget at a time

After the location loop closes: pick the smallest non-nil `getawayRemaining`, `SlideIn` that
one against `GETAWAY_POSITION` ("Left", matching the duffel card directly above it), `SlideOut`
every other, all behind the same edge-triggered `getawayShown` guard the timer and duffel use.
For the chosen one: `commas(remaining)`, `setFillRatio(widget, clamp(1 - remaining/escape))`
with the divide guarded, and the near-complete slice swap at `remaining <= escapeDistance*0.25`
guarded on an actual `Image` change.

---

## Verification — the result, not the arithmetic

### Interfaces confirmed live (not assumed)

The stale-`require` trap is real and it bit on the way through: a plain `require` of all four
Config modules returned `EscapeDistance=nil`. Via `TestRunner.freshRequire` they all return
`200`. Same for `UITheme` — `Assets.GetawayNormal` = `rbxassetid://140089160384517`,
`Assets.GetawayNear` = `rbxassetid://132824223302657`, `Size.*` = `240, 76`.

### The client's gate provably mirrors the server's

I checked rather than trusted the brief here, because `Getaway:DistanceRemaining` gates on an
injected `isInsideBuilding`, not on zone occupancy. Reading both servers:

- `HeistServer.updateZoneOccupancy` broadcasts from `isInsideBank(player)` = Lobby OR Vault OR
  BankVaultZone — the *same* function it hands to `Getaway.isInsideBuilding`.
- `LocationServer:_updateZoneOccupancy` broadcasts `zoneService:IsInside(self.interiorRole,...)`
  — identical to the `isInsideBuilding` closure it builds at line 233.

So `not zoneOccupancy[location]` on the client cannot disagree with the gate that actually banks
the bag, including the Bank's three-role union. The anchor is the same
`StatusBillboardAnchor` Part `LocationServer` passes to `Getaway.new`.

### Syntax

The edited source compiles: wrapped in `return function() ... end`, parented as a temp
ModuleScript and `freshRequire`d (compiles the body without executing it) -> **COMPILES OK**.
Temp probe destroyed.

### Read-back off the real instances, in Play mode

Character placed at exactly **120.0 studs** horizontally from the Bank anchor, with a real
`HeistState`/`DuffelState`/`ZoneOccupancy` remote round-trip (see caveat below):

```
BankGetaway  Visible=true  Image=rbxassetid://140089160384517   <- Normal slice, correct at 80 > 50
  AbsolutePosition=330, 138   AbsoluteSize=240, 76
Studs   Text="80"  Align=Right  Color=0.796,0.949,0.235 (accent)
  AbsolutePosition=364, 150   AbsoluteSize=144, 32     <- root +34,+12, exactly as authored
BarTrack
  AbsolutePosition=364, 202   AbsoluteSize=190, 6      <- root +34,+64, exactly as authored
BarFill Size={0.6, 0},{1, 0}
  AbsolutePosition=364, 202   AbsoluteSize=114, 6      <- 190 * 0.6, 1 - 80/200
BankTimer  Visible=true  Text="3:47"  AbsolutePosition=330, -46   <- Step 7: still up, outside the zone
BankDuffel Visible=true  "6,420 / 15,000"              AbsolutePosition=300, 38
```

**The ~36px inset caveat, measured rather than assumed.** Every element reads exactly 58px
above its declared offset (196 -> 138, 12 -> -46, 96 -> 38). `GuiService:GetGuiInset()` is
`0, 58` in this 900x719 viewport and `HeistHUD.IgnoreGuiInset = true`, so the delta is the inset
exactly — the widget sits precisely at its authored y=196 in true screen space. The project note
says "~36px"; here it is 58, so the constant is viewport-dependent and worth not hardcoding.

### Near-complete state

Character moved to 170.0 studs (remaining 30, under the 50 threshold):

```
Image=rbxassetid://132824223302657     <- swapped to GetawayNear
Studs Text="29"  TextColor3=1, 0.835, 0.290   <- UITheme.Color.gold
BarFill Size={0.85, 0},{1, 0}  AbsoluteSize=161.5, 6   BackgroundColor3=gold
```

### Step 6 under two concurrent sessions

Injected a second Active session + bag at SlowFoods (remaining 97.7) alongside the Bank
(remaining 30), player outside both:

```
Bank         Getaway Visible=true   Studs="29"   | Duffel Visible=true   6,420 / 15,000
SlowFoods    Getaway Visible=false  Studs=""     | Duffel Visible=true   900 / 5,000
Gas2Go       Getaway Visible=false               | Duffel Visible=false
NewsStation  Getaway Visible=false               | Duffel Visible=false
```

Exactly one getaway widget driven — the nearer-to-banking one — while both duffel cards stack as
they always have. This is the stacking bug Step 6 exists to prevent, demonstrated as prevented.

### Play-mode console output

No `HeistClient` errors and no `nil` index on any new table. All four locations booted. Notably
**none of my four new warnings fired**, which is positive confirmation that all four
`StatusBillboardAnchor` Parts and all four `EscapeDistance` configs resolved on the client:

```
[NewsStationServer] NewsStation booted: ... zones=1
[Gas2GoServer] Gas2Go booted: ... zones=1
[HeistServer] Bank booted: ... zones=5, alarmLights=0, templights=12
[SlowFoodsServer] SlowFoods booted: ... zones=1
Failed to load sound rbxassetid://90: Request asset was not found      (pre-existing)
Part Bolt is not parented to the Workspace or a WorldModel ...          (pre-existing)
DataStoreService: StudioAccessToApisNotAllowed ...                      (pre-existing, no API access in Studio)
[DataStoreBackend] could not acquire 58662576 — starting from 0 without persistence
```

### Screenshot

**`screen_capture` is broken in Play mode in this environment.** Three attempts (default camera,
retry, and explicit camera/look-at) all returned a uniform magenta frame. This is not a collapsed
viewport — `RenderStepped` measured 14.6 fps *inside Play mode* and the widget's own tween
completed (BarFill reached its target AbsoluteSize). The same `screen_capture` call works
perfectly the moment Play stops, which isolates the fault to the capture path under Play.

So the pixel image below is **a static reconstruction built in Edit mode, NOT the live widget.**
I built a temporary `ScreenGui` in `StarterGui` with the three cards at their real derived
offsets (12 / 96 / 196), using the real `UITheme` slices and the same child geometry, captured
it, and destroyed it (`StarterGui` verified clean afterwards). It confirms the artwork, the
right-aligned number clearing the baked `STUDS`, and that the three cards stack with no overlap.
It does **not** prove the live data path — that is what the property read-backs above do.

Captures are returned inline by the MCP tool and are not written to disk, so there is no file
path; they are `ScreenCapture_1..3` (blank, Play) and `ScreenCapture_5` (Edit reconstruction).

**Task 8 still owes a genuine end-to-end run.** What I drove was the real client code, the real
remotes, the real anchor Part and a real character position — but the session and duffel payloads
were injected with the exact shapes `Net:BroadcastState` / `Net:SendDuffel` emit, rather than
produced by actually robbing the Bank.

## Step 9 — the suite

```
TOTAL: 594 passed, 14 failed
```

Failing suite names: **RestaurantConfig x1** (CooldownDuration), **Gas2GoConfig x1**
(CooldownDuration), **CashClaimVFX x12** (WaitForChild on nil). All three are on the permitted
list. No other suite failed.

Required-clean suites: **World 50/0**, **Getaway 14/0**, **LocationServer 17/0** — all zero
failed. `SupplyObject` 25/0 did not flake.

The count differs from the brief's expected `593 passed, 16 failed` because `World`'s ClaimZone
floor test now passes (Task 7 retired the zones) and `SupplyObject` did not flake this run. The
*set* of failing names is within the permitted set, which is the tripwire that matters.

---

## Concerns

1. **Play-mode `screen_capture` returns a blank magenta frame** in this Studio instance. Works in
   Edit mode. Task 8 needs a working capture or a different evidence route.
2. **The inset is 58px here, not the ~36px in the project notes** — it is viewport-dependent.
   Anything that hardcodes 36 to convert `AbsolutePosition` will be 22px wrong in this viewport.
3. **The plan's Step 4 prose geometry would have been a real bug.** "Matching the timer's Time
   geometry ... size 190x32" collides with the baked `STUDS` suffix at x184. The brief's verified
   144-wide right-aligned figure is correct and is what shipped.
4. **`session.state == "Active"` in the widget gate is stricter than the server's Getaway**,
   which does not check session state. In practice the bag is voided at `_seal` so `amount`
   drops to 0 and the widget hides anyway — but if a bag could ever outlive its session, the
   widget would hide while the server still banked it. Following the brief here; flagging it.
5. **Two locations' timers can now both be on screen** if a player somehow holds bags from two
   locations at once, since `wantTimer` is no longer strictly zone-exclusive. The getaway widget
   is de-duplicated (Step 6) but the timer is not. Not in scope for this task; worth a decision.
6. `HttpService.HttpEnabled` is `false` on this place. I did not change it.

---
---

# Task 6 — fix round 1

**Status: COMPLETE.** All four items applied. Scope held: `HeistClient` was the only script
touched.

## STEP ZERO — snapshot

`.sdd-getaway/snapshots/HeistClient.fix1.before.lua` — **61,572 bytes, 1,300 newlines
(1,300 lines, file ends with `end)\n`).**

- SHA-256: `9b9cca63b654e698696566bc272f603217a8d139850ff1791de11fe0504a1a05`
- Rolling hash (`v = (v*31 + byte) % 1000000007`), computed in Luau over the live `.Source` and
  in Python over the saved file: **819500536 both sides.** Byte-identical, proven rather than
  assumed.

Pulled in eight 8,000-byte `string.sub` chunks. Two things worth recording:

1. I first tried to transfer the source byte-exactly by POSTing it from Studio to a throwaway
   local HTTP sink, to remove transcription risk entirely. Port 8731 was already held by a
   leftover `http.server` from an earlier session serving `.sdd-getaway/snapshots/`, and the
   retry on another port was refused by the sandbox. Fell back to the brief's transcribe-and-
   checksum method. **The stale server on 8731 is still running** — someone should kill it.
2. **The `Write` tool silently strips trailing whitespace.** The first write came out 61,571
   bytes: line 1034 (`-- bail-out. Hides the GUI and halts the render loop immediately `) ends
   with a space in Studio, and `Write` dropped it. Caught by per-chunk hashes, localised to a
   500-byte block by bisection, and repaired with a byte-level rewrite. Worth knowing for every
   future snapshot in this plan — a `Write`-produced snapshot of a file with trailing whitespace
   is **not** a faithful snapshot unless it is checksummed.

## Item 1 (Important) — `setFillRatio`'s edge guard was structurally defeated

**Before** (getaway drive loop): the raw continuous ratio went straight into `setFillRatio`, so
`widget._lastRatio == ratio` was false on essentially every frame the player moved, and every
frame minted a closure, a goals table and a Tween Instance.

**After**: quantised to the bar's own pixel resolution immediately before the call, plus a
comment explaining why this input differs from the duffel's.

```lua
ratio = math.floor(ratio * 190) / 190
```

**Measured, live.** Sampling the real widget: `BarFill.Size.X.Scale` read back
`0.700000` = exactly `133/190`, and during a driven run the successive values were
`134/190, 135/190, 136/190, 137/190, 138/190, 139/190` — every value an exact multiple of
`1/190`. `BarTrack.AbsoluteSize` read back `190, 6`, confirming 190 is the real pixel width and
not a guess.

Stepping the same arithmetic over the position sequence a client actually produces during a full
200-stud run at WalkSpeed 16:

| fps | frames in run | tweens BEFORE | tweens AFTER | avoided |
|---|---|---|---|---|
| 240 | 3001 | 3000 | 190 | 2810 |
| 144 | 1800 | 1799 | 190 | 1609 |
| 60 | 750 | 749 | **190** | 559 |
| 30 | 376 | 375 | 190 | 185 |
| 15 | 188 | 187 | 187 | 0 |

The count after the fix is **190 at every frame rate above 30**, which is the point: it is
bounded by the bar's pixel count, not by the frame rate. The 15 fps row is not a failure — at
15 fps the player covers 1.07 studs per frame and the bar is 1.05 studs per pixel, so nearly
every frame legitimately moves a pixel and there is nothing to deduplicate. I measured this
regime first by accident (this Studio window renders at ~14.8 fps in the background) and it
briefly looked like the fix did nothing; recording it so the next person does not repeat that.

The neighbouring comment was also corrected — it now says the shown/hidden edge guard is the one
the timer and duffel share **for their slide transitions**, and points at the fill bar's separate
guard inside `setFillRatio` and at the quantisation that is what makes it fire.

## Item 2 (Important) — timer exclusivity restored

This is the defect the previous report raised as its own **Concern 5**.

**Before**: `wantTimer` was computed per location inside the main loop, gated on
`zoneOccupancy[location] or amount > 0`. Two Active locations with a bag from each rendered two
timers on identical pixels.

**After**: the per-location `wantTimer` computation and its slide block were removed from the
main loop. A single `timerLocation` is resolved in the post-loop pass, immediately after
`urgentLocation` and driven by its own small loop before the getaway loop:

- inside some location's zone with `Active` + `endsAt` -> that location (physics makes it unique);
- otherwise `urgentLocation`, re-checked for `endsAt` because the getaway pass does not look at it;
- otherwise nothing.

`session.state == "Active" and session.endsAt ~= nil` and the edge-guarded `timerShown`
SlideIn/SlideOut are unchanged — only the which-location decision moved. The clock-face update
(`formatClock`, the urgent slice swap) stayed in the main loop; it writes text to hidden widgets
too, which costs a string format and nothing else.

Two adjacent comments that my change made false were rewritten: the `amount` hoist no longer
claims `wantTimer` depends on it, and the getaway single-selection comment no longer claims the
timer is zone-gated.

### Demonstration — two concurrent sessions

**Payloads were injected**, exactly as in the original task: `HeistState`, `DuffelState` and
`ZoneOccupancy` were fired from the Server datamodel to the real player with the shapes the real
remotes emit, rather than staging two real robberies. The character, its `PrimaryPart`, the
`StatusBillboardAnchor` Parts, the four `Config.EscapeDistance` values and the whole render loop
were all real.

Setup: SlowFoods and Gas2Go both `Active` with `endsAt`; bags of 4,000 and 2,500 held from both;
player at a spot 140.3 studs from the SlowFoods anchor and 105.7 from the Gas2Go anchor
(EscapeDistance 200 each, so remaining 59.7 and 94.3).

| scenario | visible timers | visible getaway widgets |
|---|---|---|
| A — outside both zones | **1** — `SlowFoods`, `"3:11"` | **1** — `SlowFoods`, `"60"`, fill `0.700000` |
| B — inside Gas2Go's zone | **1** — `Gas2Go`, `"4:52"` | **1** — `SlowFoods`, `"60"`, fill `0.700000` |

Scenario B is the interesting one: the two widgets deliberately point at different locations
(zone presence wins for the clock, nearest-to-banking wins for the studs) and there is still
exactly one of each.

That exclusivity matters because all four timers rest on the same pixels and all four getaway
widgets do too — read back live:

```
Timer   Bank/SlowFoods/Gas2Go/NewsStation  Position = {0.5, 0}, {0, 12}
Getaway Bank/SlowFoods/Gas2Go/NewsStation  Position = {0.5, 0}, {0, 196}
```

And the old gate really did fail here: evaluated against the identical Scenario A payloads,
`state == "Active" and endsAt ~= nil and (inside or amount > 0)` is **true for 2 locations**
(Gas2Go and SlowFoods) — two timers stacked at `{0, 12}`. The new code produced one.

## Item 3 (Minor, user-visible) — HUD no longer reads "0" before anything banks

**Before**: `commas(urgentRemaining)`, and `commas` floors.
**After**: `commas(math.ceil(urgentRemaining))`. `commas` still does the grouping.

Live: at a true remaining of **59.7 studs** the widget read **`"60"`**. The old code would have
shown `"59"`. At a true remaining of 0.0 (player 230.3 studs out, past the 200-stud line) it
read `"0"` — correct, because that is the state in which the server does bank.

## Item 4 (Minor) — stale bar on re-show

**Before**: nothing called `setFillRatio` for a non-urgent widget, so `_lastRatio` and the fill's
`Size` kept their last value.

**After**: on the hide edge, any in-flight fill tween is cancelled (same cancel-before-replace
discipline `setFillRatio` itself uses — without it the tween would keep running and overwrite the
reset), then `_lastRatio = 0` and `fill.Size = UDim2.new(0, 0, 1, 0)` are written directly. Direct
write, not `setFillRatio`, so it does not tween.

Verified as a full cycle:

1. Drove the widget to full — `fillScaleX = 1.000000`, root Image swapped to the `GetawayNear`
   bake. This is the exact state a widget is in when a real bank fires.
2. Banked the bag (`DuffelState base = 0`). Widget hid.
3. Read back: `Visible = false`, `fillScaleX = 0.000000`, `BarFill.AbsoluteSize = 0, 6` against a
   `BarTrack.AbsoluteSize = 190, 6`. Reset confirmed on the real instance.
4. Moved back inside the line (target ratio 0.70), re-granted a bag, and sampled `BarFill` every
   frame across the re-show. It went
   `hidden 0.000000 -> shown 0.321790 -> 0.543703 -> 0.666972 -> 0.700000` and then held.
   **Peak fill observed across all 198 sampled frames: 0.700000.** It fills up from empty; it
   never shows the full bar the pre-fix code would have slid in with.

On "does the reset itself animate visibly": it does not animate — it is a single assignment, no
tween, confirmed by the sampler never recording an intermediate value on the hide edge. It is
however *instantaneous rather than invisible*: `SlideOut` is 0.4s and keeps the frame `Visible`
for all of it, so the bar is empty for the whole flight off-screen rather than emptying after the
widget has gone. See Concern 3.

## Suite

```
TOTAL: 594 passed, 14 failed
```

Failing suite names: **RestaurantConfig x1** (CooldownDuration), **Gas2GoConfig x1**
(CooldownDuration), **CashClaimVFX x12** (WaitForChild on nil) — exactly the permitted set,
nothing else. **World 50/0, Getaway 14/0, LocationServer 17/0.** The render-timing-sensitive
suites (`SupplyObject` 25/0, `Hazard` 22/0, `UITransitions` 7/0, `CounterBarrier` 7/0) all passed.
Run twice — before Play mode and again after stopping it — identical both times.

Play-mode console: no `[HeistClient]` warns (so all four locations resolved their anchors and
`EscapeDistance` values) and no errors from any Heist script. The log is noisy with pre-existing
environmental failures only — DataStore API access disabled in Studio, offline animation/mesh/
sound asset fetches, and CoreGui promise rejections.

## Concerns

1. **The timer now depends on the getaway distance computation succeeding.** When the player is
   outside every zone, `timerLocation` falls back to `urgentLocation`, which is `nil` whenever
   `getawayRemaining` could not be computed — no `PrimaryPart` (the whole ~5s respawn window), a
   missing `StatusBillboardAnchor`, or a config whose `EscapeDistance` failed to resolve. In those
   states the clock hides mid-escape, where the `or amount > 0` gate would have kept it up. This
   follows the brief's two-tier rule exactly and I did not add a third tier, but if you want the
   clock to survive a config failure or a respawn, a final fallback to the first `Active` +
   `endsAt` + `amount > 0` + outside-zone location in `LOCATIONS` order would close it in three
   lines and still guarantee exactly one.
2. **Timer and getaway can legitimately point at different locations** (Scenario B above). That is
   what the brief specifies and I think it is right — the clock should follow where you physically
   are. But two adjacent HUD elements naming different robberies with nothing on screen saying
   which is which could read as a bug to a player. Neither slice carries a location label.
3. **Item 4's reset is instant but not invisible.** The bar snaps to empty at the *start* of the
   0.4s slide-out, so it flies off screen empty. Strictly better than the bug it fixes, and the
   brief asked for the hide edge. If you want it fully unseen, doing the same reset on the *show*
   edge instead — just before `SlideIn`, while the widget is still parked off-screen — is
   invisible by construction. One-line move; say the word.
4. **190 is a bare literal in the quantiser**, matching the brief's code. It must stay in lockstep
   with `getawayTrack.Size = UDim2.fromOffset(190, 6)` roughly 200 lines above, and nothing
   enforces that. A shared `GETAWAY_BAR_WIDTH` constant would, but that means editing the widget
   construction too, which is outside these four items.
5. **A leftover `python3 -m http.server` is holding port 8731** on this machine, serving
   `.sdd-getaway/snapshots/` from an earlier session. Harmless but unintended; worth killing.
