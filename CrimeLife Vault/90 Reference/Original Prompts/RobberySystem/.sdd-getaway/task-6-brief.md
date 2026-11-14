# Task 6 brief — the getaway widget in HeistClient

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

## VERIFIED slice geometry — use these numbers, they are read from the Figma node

Task 1 built the artwork. I read the real node, and the task-1 report's prose contradicts itself in
one place (it says the track is "268x12", impossible in a 240-wide frame). These are authoritative:

    frame          240 x 76
    AccentEdge     x14  y14   6 x 48     (baked)
    STUDS          x184 y24   40 x 18    (baked)
    GET AWAY       x34  y44   190 x 18   (baked)
    Track          x34  y64   190 x 6    (baked, EMPTY — you add the live fill inside it)

So the two live children you create are:
- studs number: `UDim2.fromOffset(34, 12)`, size **144 x 32**, `TextXAlignment = Enum.TextXAlignment.Right`,
  `UITheme.Font.Display`, `TextSize` 28, `ZIndex` 2. (34+144 = 178; baked STUDS starts at 184, a 6px gap.)
- progress fill `Frame`: origin `UDim2.fromOffset(34, 64)`, max size **190 x 6**, corner radius 3.

Assets, already pinned and verified live in `UITheme`:
`Assets.GetawayNormal` = `rbxassetid://140089160384517`, `Assets.GetawayNear` = `rbxassetid://132824223302657`,
`Size.GetawayNormal` = `Size.GetawayNear` = `Vector2.new(240, 76)`, `BodyOffset` both `Vector2.zero`.

**Studio's require cache will hand you a stale `UITheme` without these keys.** Use
`TestRunner.freshRequire` or restart Studio before concluding they are missing.

## The plan's Step 5/6 omit a declaration — this is a known gap, not your mistake

Step 5 writes `getawayRemaining[location]` and Step 6 reads it after the loop, but no step declares
it. You must declare all five new tables yourself, beside the existing `timerWidgets`/`duffelWidgets`:
`getawayWidgets`, `getawayShown`, `getawayRemaining`, `locationAnchors`, `escapeDistances`.

## Traps from this project's own CLAUDE.md that bear directly on this task

- **TweenService is render-driven. With the Studio viewport collapsed, `RenderStepped` reports 0 FPS
  and tweens do not advance.** Your fill bar and the studs countdown both ride `RenderStepped`. If
  you test with the viewport collapsed you will see a frozen widget and mis-diagnose working code.
  Keep the viewport visible when verifying.
- **`AnchorPoint` and `Position` must agree.** `AnchorPoint (0, 0.5)` with `Position.Y = 0` puts a
  bar's centre on its track's top edge — exactly the fill-bar shape you are building.
- **`AbsolutePosition` is measured below the top-bar inset, but `HeistHUD` sets
  `IgnoreGuiInset = true`** — so an absolute check on the new widget must account for ~36px.
- `UIPadding` offsets children rather than insetting the frame. `ZIndexBehavior` is a ScreenGui global.
- **"Verify the result, not the arithmetic."** A successful edit is not proof. Read
  `AbsolutePosition` / `AbsoluteSize` back off the real instances before claiming the layout is right.

## Scope fence

`StarterPlayer.StarterPlayerScripts.HeistClient` ONLY. Everything else is done or belongs to Task 7.

## Report contract

Full report to `.sdd-getaway/task-6-report.md`: every edit site before/after, the read-back
`AbsolutePosition`/`AbsoluteSize` of both live children, Play-mode console output, and a screenshot
path. Return ONLY: status, TOTAL line, failing suite names, whether the widget rendered, and concerns.

---

## STEP ZERO — snapshot before you touch anything

No version control exists for this code. Before your first edit, save the current source:

```lua
-- execute_luau, datamodel_type "Edit"
return game.StarterPlayer.StarterPlayerScripts.HeistClient.Source
```

Write it with the Write tool to
`.sdd-getaway/snapshots/HeistClient.before.lua`, confirm it is non-empty, and report its byte size.
If the snapshot fails, stop and report BLOCKED — do not proceed unprotected.

## Render state — read this before you debug anything that "doesn't animate"

The Studio viewport froze earlier in this plan and has since recovered. I measured it just now:
`RenderStepped` 14.6 fps, `Heartbeat` 58.5 fps, a 0.2s tween reaching Completed. It is working —
but it froze once already, so if your widget appears dead, MEASURE before you start editing code:

```lua
local RunService, TweenService = game:GetService("RunService"), game:GetService("TweenService")
local rs, hb, t0 = 0, 0, os.clock()
local c1 = RunService.RenderStepped:Connect(function() rs += 1 end)
local c2 = RunService.Heartbeat:Connect(function() hb += 1 end)
local v = Instance.new("NumberValue"); v.Parent = workspace
TweenService:Create(v, TweenInfo.new(0.2, Enum.EasingStyle.Linear), { Value = 100 }):Play()
local d = os.clock() + 0.6 ; while os.clock() < d do RunService.Heartbeat:Wait() end
local el = os.clock() - t0 ; c1:Disconnect(); c2:Disconnect()
local out = string.format("RenderStepped=%.1f fps Heartbeat=%.1f fps tween=%.1f", rs/el, hb/el, v.Value)
v:Destroy() ; return out
```

`RenderStepped` at 0 means the window is minimised/collapsed and NOTHING render-driven advances —
your fill tween and the per-frame countdown both ride `RenderStepped`. That is an environment
fault, not your code. Report it to me rather than rewriting working logic around it.

## Tooling trap discovered during this plan — it will bite you

`multi_edit` with `replace_all: true` reported **"11 edits applied" while changing nothing** at two
target sites. The returned edit count is NOT evidence. Prefer several single-occurrence edits, each
anchored on enough surrounding quoted text to be unique, and **read the region back** with
`script_read` after every edit to confirm the new text is actually present.

## Report contract

Full report to `.sdd-getaway/task-6-report.md`: snapshot byte size, every edit site before/after,
the read-back `AbsolutePosition`/`AbsoluteSize` of both live children, the render-state measurement,
Play-mode console output, and the screenshot path.

Return ONLY: status, TOTAL line, failing suite names, whether the widget actually rendered with a
live number and a filling bar, and concerns.
