# Task 1 brief — Figma design, export, and UITheme pinning

## Global Constraints (bind every step)

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

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

---

## Controller resolutions (read these — they override guesses)

**Step 6's "third table" is resolved: it is `UITheme.BodyOffset`.** Confirmed by reading the live
module. It maps slice keys to the point where the panel body starts inside the image, because
ribbon-overhang panels export bigger than their body. Flat panels take `Vector2.zero`; only
overhang panels take `RIBBON_OFFSET = Vector2.new(9, 19)`. The getaway widget is a flat panel, so
add BOTH new keys as `Vector2.zero`, beside the existing `TimerNormal = Vector2.zero` /
`TimerUrgent = Vector2.zero` entries in the "Flat panels have no overhang" group.

So you are adding **three** entries per slice, in three tables:
- `UITheme.Assets.GetawayNormal` / `.GetawayNear` — the `rbxassetid://` strings
- `UITheme.Size.GetawayNormal` / `.GetawayNear` — both `Vector2.new(240, 76)`
- `UITheme.BodyOffset.GetawayNormal` / `.GetawayNear` — both `Vector2.zero`

The key spelling is load-bearing: Task 6 calls `imagePanel(name, "GetawayNormal", position)`, and
that helper indexes `UITheme.Size[key]` and `UITheme.Assets[key]` with the same string.

## Scope fence

The ONLY Studio script you may modify is `ReplicatedStorage.SharedSystems.UITheme`, and only by
ADDING the six entries above. Do not touch `HeistClient`, any Config, or any server script — later
tasks own those. Do not build the widget in Studio; Task 6 does that.

## Reference material already gathered (do not re-derive)

The existing timer slice you are matching, read live from `HeistClient`:
- 240x76 `ImageLabel`, `AnchorPoint` (0.5, 0), `UITheme.Assets.TimerNormal` = `rbxassetid://129938094868701`
- exactly one live child: `TextLabel` "Time" at `UDim2.fromOffset(34, 12)`, size 190x32,
  `UITheme.Font.Display`, `TextSize` 28, `UITheme.Color.accent`, `ZIndex` 2
- the "TIME REMAINING" caption and the accent edge are BAKED INTO THE IMAGE
- the urgent variant swaps the whole slice to `TimerUrgent` and recolours the text to `danger`

Figma file is named `Roblox`, page `02 · Redesign`, file key `iRetcvpbMMD190DJA9Mwrm`. It already
holds 23 exported slices from a previous pass — match their construction and naming conventions.

## Report contract

Write your full report to `/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/task-1-report.md`.
It must contain: the Figma account email you confirmed; node ids/names of the two frames you
created; the export scale used and the resulting pixel dimensions; both uploaded asset ids; the
exact diff you made to UITheme (before/after of each table region); and the output of Step 7's
verification snippet and Step 8's suite run.

Return to me ONLY: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), the two asset ids,
a one-line suite summary, and any concerns. Do not paste the report back.
