# Skins card stops drifting from the shop, and the entrance tween becomes visible

**Status:** Fix implemented and verified live in a real client (Play mode), at two different real
viewport sizes this Studio session happened to present (1120x719, then 812x719 after a later
Play/Edit toggle) — not synthetic numbers. 146/146 tests, real server VM, temporary `Script`, both
before and after the final formula tweak. `screen_capture` worked in this session (the collapsed
`ViewportSize` trap did not apply here) and was used to confirm the category-chip no-op and the
detail view visually. Bug 2 (icon swap) is wiring only, deliberately left a no-op — see Summary.

## Summary

**Bug 1.** The Skins card (`SkinsCardController`) computed its position relative to the shop panel
exactly once, in `open()`, and never again. A viewport resize — or, after this fix, the shop's own
responsive shrink to make room for the card — moves the shop but not the card, so the two drift
apart. Both reported symptoms ("not sticky", "no visible tween") were this one cause: the card ends
up positioned where it does not fit, so its tween plays off-screen and looks like it never tweened at
all.

Fixed by making the card track the shop live (`GetPropertyChangedSignal` on `AbsolutePosition` and
`AbsoluteSize`, connected in `open()`, disconnected in `close()`), and by making
`WeaponaryShopController` take over the shop's own responsive scaling from the generic
`UIScaleController` so it can budget room for the card while it's open. The card gets its own
`ResponsiveScale` `UIScale` too, kept in exact lock-step with the shop's, so the pair always renders
at the same apparent scale, tops aligned, and both the tween's start and end positions stay inside
the viewport at any size — not just the one this session happened to measure.

**Bug 2.** Category chips (Melee/Pistol/AutoRifle/Shotgun) and the Spraypaint balance's spray-can
badge are wired to accept real asset ids, but every id defaults to `""` and every one of the five
falls back to today's rendering (text label / native drawn shapes) until a person fills them in.
Verified as a genuine no-op this session — screenshotted, checksummed, and read back structurally.

## Cause

**The brief's own root-cause note said the shop's responsive scale was upscaling ~1.06x and never
budgeted for the card. Measured against the live `UIScaleController` source, the ~1.06x figure does
not hold — it is disproved, not just unconfirmed.** `UIScaleController.MAX_SCALE = 1`; the shop can
never render above its authored 920x580, only shrink below it. The screen-recording-derived "~921pt
rendered width" that produced the 1.06x estimate was almost certainly ordinary viewport variance
being misread as an upscale, since a scale exceeding 1.0 is not something that code path can ever
produce.

**The real mechanism, confirmed live:** `UIScaleController` measures each `ScreenGui` for its own
single widest panel and sizes its `UIScale` to fit *that panel alone* against the viewport. It has no
way to know that a second, sibling `ScreenGui` (`SkinsCardGui`) needs another 260px reserved beside
the shop's own 920. So on any viewport narrower than roughly 1440pt (920 + 2 x (240 + 20), see
Notes for why doubled), the shop renders at its own full, correct-per-its-own-formula scale while the
card's fixed absolute target lands off the visible area to its right. The "positioning tweak" framing
in the brief undersells this: the shop's own scale was never wrong for the shop; it simply never knew
about the card.

## Changes

- `StarterPlayer.StarterPlayerScripts.SkinsCardController` (repo: `FPSSystem/Cosmetics/
  SkinsCardController.luau`):
  - Added `RESERVED_WIDTH = 2 * (CARD_SIZE.X.Offset + GAP + SLIDE_OFFSET)`, exported as
    `SkinsCardController.RESERVED_WIDTH`, for `WeaponaryShopController` to read when it computes its
    own scale. See Notes for why it is doubled and why `SLIDE_OFFSET` is folded in.
  - Added `cardScale`, a `UIScale` on `SkinsCardGui` (mirrors the exact pattern
    `WeaponaryShopController`'s own `ResponsiveScale` uses), kept at the same `Scale` the shop's own
    `ResponsiveScale` currently reports.
  - `targetPosition(shopFrame, scaleRatio)` — now takes the current scale ratio, scales `GAP` by it,
    and divides its computed absolute pixel target back down by `scaleRatio` before returning it (see
    Notes for why the division is required, not optional).
  - Added `currentScaleRatio(shopFrame)` — recovers the shop's live scale factor by *measurement*
    (`shopFrame.AbsoluteSize.Y / CARD_SIZE.Y.Offset`) rather than by reaching into
    `WeaponaryShopController`'s `UIScale` instance, so the two modules stay decoupled.
  - Added `reseat(shopFrame)` — re-runs `targetPosition`/`currentScaleRatio` and applies both to
    `cardScale.Scale` and `card.Position`.
  - `open()` now connects `shopFrame:GetPropertyChangedSignal("AbsolutePosition")` and
    `("AbsoluteSize")` to `reseat`, kept alive for as long as the card stays open; `close()`
    disconnects both. This is the actual sticky fix — `open()`/`close()` were already called from the
    right places (line ~570/back-button/`closeShop()`); nothing needed a new call site.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` (repo: `FPSSystem/Cosmetics/
  WeaponaryShopController.luau`):
  - Added `SHOP_CLOSED_SIZE`/`SHOP_OPEN_SIZE` constants (870x545 / 920x580), replacing the four
    matching magic-number literals in `openShop`/`closeShop` — no behaviour change, just a single
    source of truth the new scale formula also reads.
  - The shop's `WeaponaryShopGui` now creates (or adopts, if `UIScaleController` somehow beat it
    there) its own `UIScale` immediately after `shop.Parent = gui`. This is the same opt-out
    `UIScaleController`'s own header comment already documents for `BlasterGui`/`BlasterTouchGui`
    ("a GUI that already ships its own UIScale owns its own scaling policy") — `UIScaleController`
    itself is **not modified**; it already skips any `ScreenGui` that ships its own `UIScale`.
  - `refreshShopScale()` reproduces `UIScaleController`'s own `computeScale` (`MAX_SCALE=1`,
    `MIN_SCALE=0.4`, `MARGIN=0.94` — same constants, duplicated with a comment citing the source,
    since `UIScaleController` is a `LocalScript`, not a module, and cannot be required) but adds
    `reservedWidth` to the shop's own authored width before computing the fit.
  - `reservedWidth` is set to `SkinsCardController.RESERVED_WIDTH` immediately before
    `SkinsCardController.open(...)` is called in `showDetail()`, and reset to `0` (with
    `refreshShopScale()` re-run) in both the back-button handler and `closeShop()`.
  - Added `ICON_ASSET_IDS` (Bug 2): one constants table, `Melee`/`Pistol`/`AutoRifle`/`Shotgun`/
    `Spray`, each `""` by default with a comment naming its exact source PNG under
    `/Users/luqpic/Downloads/Weaponary/`. `applyCategoryIcon()` renders an `ImageLabel` over a
    category tab (and blanks its `Text`) only when its id is non-empty; the Spraypaint badge fallback
    likewise only touches `DetailPanel.SpraypaintChip.Icon`'s native `Body`/`Cap`/`Dot1`/`Dot2` shapes
    when `ICON_ASSET_IDS.Spray` is non-empty. Both are no-ops today.

## Notes

**Why `RESERVED_WIDTH` is doubled.** The shop is centre-anchored (`AnchorPoint (0.5, 0.5)`), so a
"does this WIDTH fit inside the VIEWPORT" formula that assumes symmetric centring only ever counts
*half* the shop's width against each side of the viewport. The card, though, hangs entirely off the
shop's right edge — the true one-sided budget on that side is `halfShopWidth + GAP + CARD width`.
Verified algebraically and then live: at viewport width `V`, the card's true right edge is
`V/2 + halfShopWidth*scale + (GAP + CARD)*scale`; solving for the scale that keeps that edge at the
viewport edge gives `scale = V * MARGIN / (shopWidth + 2*(GAP+CARD))` — i.e. the "reserved" term has
to be the *doubled* one-sided overhang, not the raw `GAP+CARD` figure, or the formula would let the
pair overflow on any viewport between roughly 1180/MARGIN and 1440/MARGIN points wide (a large slice
of ordinary desktop widths, not an edge case).

**Why `SLIDE_OFFSET` is folded into `RESERVED_WIDTH` too — caught by live measurement, not by
inspection.** The first version of this fix reserved only `2 * (CARD + GAP)` (520px). Live at
1120x719 that produced a genuinely correct *resting* position (verified: top-alignment delta 0.28px,
gap 13.9px against an expected 14.6px, both sub-pixel `UDim2` offset rounding, not a real
misalignment) — but the entrance tween's *start* position, `SLIDE_OFFSET` (40px, pre-scale) further
right, left only ~5px of margin before running off the 1120-wide viewport. Five pixels of margin at
one specific measured width is a coincidence, not the guarantee the brief asked for ("the card's start
and end positions must both be inside the viewport" — at any size, not just this one). Widening the
reserved budget to `2 * (CARD + GAP + SLIDE_OFFSET)` (600px) and re-measuring at a second, genuinely
different live viewport (812x719, which this Studio session presented after a later Play/Edit toggle)
gave the start position 24.6px of margin instead of ~5px — confirming the wider budget, not the
original one, is what makes the guarantee hold generally rather than by luck.

**The inset-and-`IgnoreGuiInset` interaction was re-derived and empirically verified live, not
assumed.** The existing code already added `GuiService:GetGuiInset()` onto the shop's
`AbsolutePosition` before computing the card's target — correct, and unchanged here. What's new is
dividing that target by `scaleRatio` before storing it in `card.Position` (since `cardGui`'s own new
`UIScale` will multiply it back on render). Before trusting that division, a clean four-point
experiment (`Instance.new` scratch `ScreenGui`s with a known raw offset, a known `UIScale`, both
`IgnoreGuiInset` states, read back live in a real Client datamodel) established the exact relationship
Roblox uses: `reported AbsolutePosition.Y = offsetY * scale - (insetY if IgnoreGuiInset else 0)`,
and — confirmed with a second `screen_capture`-verified test — the render-time rule adds `insetY`
back **uniformly for both settings**, so `trueScreenY = reportedAbsoluteY + insetY` regardless of
`IgnoreGuiInset`. An initial, less careful check (comparing `card.AbsolutePosition.Y` directly against
`shop.AbsolutePosition.Y + inset.Y` with no correction on the card's side) wrongly flagged a ~58px
(exactly one inset) misalignment; redoing the comparison with the uniform rule applied to both sides
showed the true delta was 0.28px — sub-pixel, from `UDim2.fromOffset`'s integer truncation, not a real
bug. Recorded here specifically so a future reader does not re-discover the same false alarm.

**A wrapper-frame design was tried and discarded before this one.** The first design considered
putting the card's own `UIScale` on a `Content` sub-frame (sized `Scale(1,1)` to fill the card) so the
outer `card` Frame's `Size`/`Position` could stay untouched by any scale. A clean, isolated
Edit-mode experiment showed this breaks: a `UIScale` parented directly to an object scales *that
object's own* effective size too, even when its `Size` is 100% `Scale`-relative — so `Content` ended
up smaller than `card` by the scale factor, and everything inside it computed its own percentages
against that shrunk canvas instead of the card's true bounds. The design that shipped instead —
`UIScale` on `cardGui` itself, `card.Size` left at its authored `CARD_SIZE` always, `card.Position`
pre-divided by the scale — mirrors exactly how the shop's own long-standing pattern already works, so
it carries no new risk the codebase hasn't already tested in production.

**`multi_edit` timed out repeatedly against Studio this session** (both in Edit mode and, once,
correctly rejected while in Play mode) for reasons unrelated to the edits themselves — get_studio_state
and execute_luau stayed responsive throughout. Every edit was instead applied by reading the target
script's `Source`, doing a `string.find(..., true)` (plain, not pattern) substring locate-and-replace
or a full-source reassignment, and confirming the result byte-for-byte against the repo file with an
Adler-32 checksum (computed identically in Python locally and in Luau live) rather than trusting
`#Source` length alone — an earlier FNV-1a attempt at the same cross-check silently produced different
hashes for identical content, traced to floating-point precision loss in Luau's `bit32` arithmetic on
products exceeding 2^53, not a real content difference. Both scripts are confirmed byte-identical
between the live Studio instances and this repo as of this change.

**Environment trap did not apply this session.** `ViewportSize` was never `1,1` — it read `1120,719`
initially and `812,719` after a later Play/Edit toggle (the Studio window/panel layout evidently
changed between sessions, outside this agent's control). Both are reported here as genuinely
different live measurements, not one measurement asserted twice.

## Status

- **Confirmed live, this pass:** the sticky-tracking fix (directly forced the shop's `ResponsiveScale`
  to a different value mid-session with the card already open, with no call to `open()` again, and
  confirmed the card re-seated to the exact matching scale, gap and alignment automatically); the
  scale-budget fit and top-alignment/gap math at two different real viewports (1120x719, 812x719); the
  entrance tween's start-position margin at both budget versions (proving the `SLIDE_OFFSET` fold-in
  was necessary, not decorative); the close path (`SkinsCardController.close()` disconnects tracking
  and the card actually disables); Bug 2's no-op both structurally (all five ids empty, `ImageLabel`s
  never created) and visually (`screen_capture` of the category tabs showing unchanged text labels);
  146/146 tests via a temporary `Script` in a real server VM, both before and after the final
  `RESERVED_WIDTH` tweak; byte-identical Studio/repo scripts via Adler-32 checksum.
- **Not independently confirmed by a second person:** nobody but this agent has looked at the
  rendered result with human eyes beyond the `screen_capture` frames already included in this session's
  tool history; a person should still eyeball the live game at a genuinely narrow desktop width (this
  session's two real viewports were both already narrow enough to exercise the shrink path, but neither
  was tested down at the `MIN_SCALE` floor of 0.4).
