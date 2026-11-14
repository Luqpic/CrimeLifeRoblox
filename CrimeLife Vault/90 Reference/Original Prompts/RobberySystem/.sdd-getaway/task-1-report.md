# Task 1 report — Figma design, export, and `UITheme` pinning

**Status: DONE_WITH_CONCERNS** (one concern, in §7 — the suite baseline in the brief is stale; my change is not the cause.)

---

## Step 1 — Figma account confirmed

`whoami` returned:

```
handle: Luqman Hayyan
email:  muhammadluqmanhayyan@gamuda.tech
plans:  Gamuda Engineering — seat: Full — tier: org — role: member
```

Correct account, **Full** seat. Not the View-seat personal account. The file read back live and
populated (23 existing slices on the export page, real components and geometry), so the hollow-file
failure mode described in the brief did not occur.

Studio id resolved from `list_roblox_studios`, not hardcoded:
`009e370d-dae2-402e-88e9-379b254ec753` — "Robbery System (placeId: 130328863401144)".

---

## Step 2 — The reference slice, read live

File `Roblox`, key `iRetcvpbMMD190DJA9Mwrm`. The 23 existing slices live on page
**`03 · Export Slices`** (`92:189`), not on `02 · Redesign` — `02 · Redesign` holds the composed
mockups, and `03 · Export Slices` holds the isolated frames that are actually exported. I matched
the export page, since that is what the upload pipeline consumes.

`SLICE · Timer · normal (240×76)` (`92:67`), read live:

| Element | Geometry | Paint |
|---|---|---|
| Frame | 240×76, corner radius 18, `clipsContent: false` | fill `#171A22`, stroke `#2A2F3C` 1px INSIDE |
| `AccentEdge` (FRAME) | x14 y14, 6×48, radius 3 | fill `#CBF23C` |
| `TIME REMAINING` (TEXT) | x34 y44, 190×18, LEFT / CENTER, autoResize HEIGHT | fill `#8A92A6`, Barlow Semi Condensed **Medium** 15px |

The urgent variant (`92:71`) is identical except `AccentEdge` → `#FF4B4B`. The caption stays muted.

I also read `SLICE · DuffelBag · filling` (`92:75`) and `· FULL` (`92:82`) to learn the established
**gold** state convention, since the brief requires the near state to mirror the duffel rather than
the timer:

- filling → caption `DUFFELBAG`, fill `#8A92A6`, Barlow Semi Condensed **SemiBold** 15px
- FULL → caption `DUFFEL FULL`, fill `#FFD54A`. **Only the caption changes.**
- `Track` (FRAME) x16 y66, 268×12, radius 6, fill `#12141A` — **identical in both states.**

Two conventions therefore apply to the getaway pair: the Timer family carries state colour on the
`AccentEdge`, the Duffel family carries it on the caption. The getaway widget borrows the accent
edge from the timer, so the edge must change or the state would not read at all. I recolour **both**
the edge and the caption, and leave the track and the `STUDS` unit label alone. Rationale recorded
as a comment in `UITheme.Assets`.

Font styles verified against `listAvailableFontsAsync()` rather than guessed — the family is
`Barlow Semi Condensed` with styles `Medium` and `SemiBold` (**no space**), and `Archivo Black` /
`Regular`.

---

## Steps 3 & 4 — The two frames

Both created on page `03 · Export Slices` (`92:189`), placed on a fresh row at y=2800 using the same
60 / 420 column spacing as the existing Timer row.

| | Node id | Name | Position |
|---|---|---|---|
| Normal | **`128:6`** | `SLICE · Getaway · normal (240×76)` | x60 y2800 |
| Near | **`129:6`** | `SLICE · Getaway · near <25% (240×76)` | x420 y2800 |

`GetawayNear` was produced by **cloning** `GetawayNormal` and recolouring two fills, so "identical
geometry" is guaranteed structurally rather than by re-entering numbers.

### Construction — both frames

Frame: 240×76, fill `#171A22`, stroke `#2A2F3C` 1px INSIDE, corner radius 18, `clipsContent: false`
— byte-for-byte the timer's chrome.

| Child | Node (normal / near) | Geometry | Normal paint | Near paint |
|---|---|---|---|---|
| `AccentEdge` | `128:7` / `129:7` | x14 y14, 6×48, radius 3 | `#CBF23C` | **`#FFD54A`** |
| `STUDS` | `128:8` / `129:8` | x184 y24, 40×18, hug | `#8A92A6` SemiBold 15px | `#8A92A6` (unchanged) |
| `GET AWAY` | `128:9` / `129:9` | x34 y44, 190×18 | `#8A92A6` Medium 15px | **`#FFD54A`** |
| `Track` | `128:10` / `129:10` | x34 y64, 190×6, radius 3 | `#12141A` | `#12141A` (unchanged) |

Design decisions worth recording:

- **`GET AWAY` sits at exactly x34 y44, 190×18, Barlow Semi Condensed Medium 15px, `#8A92A6`** —
  the timer caption's exact position, size, weight and colour, as the brief requires, so the two
  widgets read as a pair.
- **The number row is left empty**, occupying x34 y12, 190×32 — the same geometry as the timer's
  live `TextLabel`. Nothing is baked there.
- **`STUDS` is baked**, right-aligned with its right edge at x=224 (the content column's right
  edge, mirroring the 34/224 column the timer uses). Its **left edge is x=184**. Task 6 must
  right-align the live number against that: the number's box should be **x34 y12, 144×32**, leaving
  a 6px gap before `STUDS`. Those numbers are the load-bearing output of this step.
- `STUDS` y was set to 24, not a naive vertical centre, so its baseline matches a 28px display
  number centred in the y12–44 row. I verified this by temporarily drawing a real `148` in Archivo
  Black 28 into the frame, screenshotting, nudging by 1px, then **deleting the temporary node**. A
  `findAll(/TEMP/i)` sweep after deletion returned `[]` — confirmed clean before export.
- **The track is empty by design** — 190×6 at x34 y64, in the 32px band below the number row, the
  slim inset rail the brief asked for. The fill is a live `Frame` that Task 6 adds; nothing about
  the fill is baked. Colour `#12141A` and the fully-rounded radius (3 = half of 6) match the
  duffel's track convention.
- Height 6 and radius 3 deliberately echo the `AccentEdge`'s 6px width and radius 3.

---

## Step 5 — Export and upload

**Export scale: 4x. Resulting pixel dimensions: 960×304** for both files (240×76 × 4), under
Roblox's 1024px texture cap as the brief predicted.

I could not use the REST `/v1/images` endpoint: locating the project's Figma token required a
credential search, which this environment's sandbox blocked (`[Credential Exploration]`). Rather
than work around that, I used the Figma MCP's own `download_assets` at `defaultScale: 4,
defaultFormat: png`, which produces the identical artifact — a 4x PNG render of the node — without
touching a credential. The files were then served from a local `python3 -m http.server` on
127.0.0.1:8765 and uploaded with `upload_image`, exactly as the brief's pipeline specifies. The
server was stopped after the upload.

**I verified the exports before uploading**, because `UITheme`'s own header documents that the v1
batch shipped silently broken — every slice came back with Figma's `#F5F5F5` page background baked
in as *opaque*, which a `hasAlpha` check does not catch because the alpha channel exists and is
simply 255 everywhere. I decoded the actual pixel alpha:

```
getaway_normal.png  960 x 304  bitdepth 8  colortype 6 (RGBA)
   corner TL (0,0,0,0)  TR (0,0,0,0)  BL (0,0,0,0)  BR (0,0,0,0)
   centre (23,26,34,255)
   corner alphas: {0} -> TRANSPARENT OK

getaway_near.png    960 x 304  bitdepth 8  colortype 6 (RGBA)
   corner TL (0,0,0,0)  TR (0,0,0,0)  BL (0,0,0,0)  BR (0,0,0,0)
   centre (23,26,34,255)
   corner alphas: {0} -> TRANSPARENT OK
```

True corner alpha 0 on both, and the centre pixel is `(23,26,34)` = `#171A22`, the panel colour.
The v1 trap is not present. (The export page's `backgrounds` were already set to opacity 0 from the
previous pass; I confirmed rather than assumed.)

### Uploaded asset ids

```
GetawayNormal = rbxassetid://140089160384517
GetawayNear   = rbxassetid://132824223302657
```

Both returned by `upload_image` before continuing, as required.

---

## Step 6 — `UITheme` diff

Three tables, two entries each — six entries total, additive only. No existing line was modified,
reordered or deleted. Anchored on quoted code, never on line numbers.

### `UITheme.Assets`

```diff
   TimerNormal   = "rbxassetid://129938094868701",
   TimerUrgent   = "rbxassetid://85883069158107",
+  -- Getaway distance widget. The NEAR state is GOLD, not danger red: closing on
+  -- the escape radius is good news for the player, so this pair mirrors
+  -- DuffelPanel -> DuffelFull, not TimerNormal -> TimerUrgent.
+  GetawayNormal = "rbxassetid://140089160384517",
+  GetawayNear   = "rbxassetid://132824223302657",
   DuffelPanel   = "rbxassetid://127604001805279",
```

### `UITheme.Size`

```diff
   TimerNormal   = Vector2.new(240, 76),
   TimerUrgent   = Vector2.new(240, 76),
+  GetawayNormal = Vector2.new(240, 76),
+  GetawayNear   = Vector2.new(240, 76),
   DuffelPanel   = Vector2.new(300, 92),
```

### `UITheme.BodyOffset`

Placed in the "Flat panels have no overhang" group beside the timer entries, per the controller
resolution. The getaway widget is a flat panel with no ribbon overhang, so both are `Vector2.zero`.

```diff
   -- Flat panels have no overhang; the body IS the image.
   TimerNormal  = Vector2.zero,
   TimerUrgent  = Vector2.zero,
+  GetawayNormal = Vector2.zero,
+  GetawayNear   = Vector2.zero,
   DuffelPanel  = Vector2.zero,
```

Cosmetic note: the `Assets` and `Size` tables align `=` at column 14, so `GetawayNormal` (13 chars)
fits exactly. The `BodyOffset` flat group aligns at column 13, which `GetawayNormal` cannot fit —
so the two new lines there sit one space wider than their neighbours. Reflowing the whole group
would have meant editing lines outside the scope fence, so I left them. Purely visual.

**Scope fence respected:** `ReplicatedStorage.SharedSystems.UITheme` is the only Studio script
touched, and only by adding the six entries plus the three explanatory comment lines. `HeistClient`,
the Configs and the server scripts were not modified. No widget was built in Studio — that is
Task 6's job.

---

## Step 7 — Live verification in Studio

The brief's snippet initially returned **all `nil`**:

```
GetawayNormal=nil size=nil | GetawayNear=nil size=nil | bodyOffsetNormal=nil bodyOffsetNear=nil
```

**This was not a failed edit — it is Studio's `require` cache.** `UITheme` had already been required
earlier in this Studio session, so `require` handed back the pre-edit table. Confirmed two ways:

1. Reading the script source back shows all six entries present (lines 31–35, 116–117, 164–165).
2. Requiring a **fresh clone** of the module (a distinct `Instance`, so it gets its own cache entry)
   resolves every value:

```
GetawayNormal=rbxassetid://140089160384517 size=240, 76 bodyOffset=0, 0 |
GetawayNear=rbxassetid://132824223302657   size=240, 76 bodyOffset=0, 0 |
TimerNormal(control)=rbxassetid://129938094868701
```

Two `rbxassetid://` strings, two `240, 76` vectors, two `0, 0` offsets, and the `TimerNormal`
control is unchanged. The probe clone was destroyed afterwards.

> **Carry-forward for Task 6:** a plain `require(UITheme)` in this *already-running* Studio session
> will still return the stale cached table without the Getaway keys. Task 6 must restart Studio, or
> use `TestRunner.freshRequire`, before concluding the keys are missing. This will look exactly like
> "Task 1 did not land" and is not.

---

## Step 8 — Suite

```
TOTAL: 580 passed, 15 failed
```

Run via `require(game.ServerScriptService.Heist.Tests.RunAll)()` in `Edit`. Failing suites:

| Suite | Failed | Failure |
|---|---|---|
| World | 1 | `each single-room zone has real floor immediately beneath its own bottom` :: **ClaimZone**: no floor within 6 studs of the zone's own bottom (probed from Y=9.00) |
| RestaurantConfig | 1 | `CooldownDuration (20 minutes)` — expected 1200, got 60 |
| Gas2GoConfig | 1 | `CooldownDuration (10 minutes)` — expected 600, got 60 |
| CashClaimVFX | 12 | all: `SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'` |

**The brief expected `579 passed, 16 failed`.** See the concern below.

---

## Concern — the suite baseline in the brief is stale, and my change is not the cause

Observed 580/15 against an expected 579/16. The **total is identical at 595** in both, so no test was
added or removed — exactly one test that previously failed now passes.

My change cannot be responsible, on four independent grounds:

1. **No spec reads `UITheme` at all.** A `script_grep` for `UITheme` returns matches only in
   `HeistClient`, `WordScrambleClient` and `UiButtonEffects` — all client scripts. Nothing under
   `ServerScriptService.Heist.Tests` references it.
2. The change is **pure additive data** — six new keys under three new names. It mutates no existing
   value and introduces no behaviour.
3. **The result is stable at 580/15 across two consecutive runs**, with the same four failing suites
   both times, so this is not run-to-run flapping.
4. `UITheme` is not required by `RunAll` or by the runner.

The likeliest explanation is that the baseline was measured against a different Workspace state.
`RunAll`'s own header warns the specs are **not side-effect free** — "many build fixture models
parented straight into Workspace, and several only tear them down AFTER asserting, so a failing
suite leaks them". The `World` spec probes live Workspace geometry (floor raycasts under each zone),
so its count moves when world parts move or when a previous failing run leaks fixtures. `World`
currently reports exactly 1 failure; a baseline of 2 there would reconcile 579/16 to 580/15 exactly.

I did not chase it — diagnosing world geometry is outside this task's scope fence, and adjusting a
test to match a number would be the wrong instinct anyway.

**One detail worth the reviewer's attention:** the single remaining `World` failure is specifically
about **`ClaimZone`** — the Claim-zone cash-out that this entire feature exists to replace, and that
Task 7 may delete. A pre-existing failure against a zone that is on its way out is probably not
worth fixing, but the reviewer should decide that deliberately rather than inherit it by accident.

---

## Interfaces produced (for Task 6)

```
UITheme.Assets.GetawayNormal      = "rbxassetid://140089160384517"
UITheme.Assets.GetawayNear        = "rbxassetid://132824223302657"
UITheme.Size.GetawayNormal        = Vector2.new(240, 76)
UITheme.Size.GetawayNear          = Vector2.new(240, 76)
UITheme.BodyOffset.GetawayNormal  = Vector2.zero
UITheme.BodyOffset.GetawayNear    = Vector2.zero
```

Key spelling matches the brief exactly, so `imagePanel(name, "GetawayNormal", position)` will index
`UITheme.Size[key]` and `UITheme.Assets[key]` correctly.

Geometry Task 6 needs, in panel-body coordinates (`BodyOffset` is zero, so image coords == body coords):

| Live element | Geometry | Notes |
|---|---|---|
| Distance number (`TextLabel`) | `UDim2.fromOffset(34, 12)`, size **144×32** | `TextXAlignment.Right`, `UITheme.Font.Display`, `TextSize` 28, `ZIndex` 2. Right edge lands 6px left of the baked `STUDS`. |
| Progress fill (`Frame`) | origin `UDim2.fromOffset(34, 64)`, max size **190×6**, radius 3 | Grows left→right inside the baked track. `UITheme.Color.accent` normal, `UITheme.Color.gold` near. |

Colour swap for the near state, mirroring how `HeistClient` already handles the duffel at line 971:
swap the whole slice to `Assets.GetawayNear` and recolour the number and the fill to
`UITheme.Color.gold`. The `STUDS` label and the track are baked and need no runtime handling.
