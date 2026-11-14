# Change Log: Spray-Can Badge Beside the Spraypaint Price

**Date:** 2026-09-23
**Status:** Confirmed live in one continuous Play session — see Verification. One item needs a person
(no visual check was possible in this environment) — see Status.

## Summary
Added a small spray-can badge (`BuyStrip.SprayIcon`) immediately left of the buy strip's `PriceLabel`,
drawn from four Frames (`Body`, `Cap`, `Dot1`, `Dot2`) in the same construction style as the row's
existing `Lock`/`Coin` glyphs on each skin chip. Drawn rather than uploaded because the intended Figma
icon (GiSpray) could not reach Studio from this environment: `upload_image` rejects local paths outright
and refused the Figma CDN export as untrusted, and no free equivalent turned up in the Creator Store.
The badge follows `PriceLabel`'s existing accent/danger colour switch exactly, and is built so a future
real asset swap is one line.

## Cause
No existing bug; a UI request. `PriceLabel` gave up 20px of its left inset (16px badge + 4px gap) to
make room: `Position (10,30) Size (148,20)` became `Position (30,30) Size (128,20)`. The new 128px
column still clears the widest real price text with margin — `RoseGold` ("750 SPRAYPAINT") measures
96.5px at this font/size, and a synthetic 4-digit "9999 SPRAYPAINT" measures 103px, both well under 128.

## Changes
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.BuyStrip.PriceLabel` — `Position`
  and `Size` only (see Cause); no other property touched.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.BuyStrip.SprayIcon` (new Frame,
  16x16, `BackgroundTransparency = 1` container, `AnchorPoint (0, 0.5)`) with four children: `Body`
  (6x7 rounded rect, `Rotation = 12`), `Cap` (4x4 rounded rect, `Rotation = 12`, flush on `Body`'s top
  edge), `Dot1`/`Dot2` (2x2 and 1.5x1.5 circles trailing diagonally up-right from the cap) —
  reproduces the GiSpray silhouette (tall body, nozzle cap, spray dots) at badge scale, no strokes.
- `StarterPlayer.StarterPlayerScripts.SkinRowController` (13,751 bytes) — added `paintSprayIcon(icon,
  color)`, a small helper that sets `BackgroundColor3` on every `GuiObject` child of the icon (or
  `ImageColor3` directly, if the icon is ever swapped for an `ImageLabel`), and one call to it inside
  `refreshAffordability`, sharing the same `priceColor` local that already feeds `PriceLabel.TextColor3`.

## Verification
Measured live in one continuous Play session (Client datamodel): shop opened via
`Custom Inventory.weaponaryButton`, `AK47` selected in the weapon grid, the `RoseGold` skin chip
(750 Spraypaint) clicked to open the buy strip — scrolled into the row's clipped view first
(`SkinRow.CanvasPosition` written directly; see Notes) and its `AbsolutePosition` confirmed inside the
row's bounds before the click, per the trap on record.

- **Badge and label rectangles, not-enough-funds state:** `SprayIcon` pos `(220.108688, 547.517395)`
  size `(14.7130432, 14.7130432)`; `PriceLabel` pos `(238.5, 545.678284)` size `(117.704346,
  18.391304)`. Badge sits left of the label (badge right edge 234.82 vs label left edge 238.5, a
  3.68px gap — the 4px design gap scaled by this session's ~0.9196 UI scale factor). Centre-line:
  badge centre Y = 547.517 + 14.713/2 = **554.874**; label centre Y = 545.678 + 18.391/2 = **554.874**
  — exact match, vertically centred.
- **Text fit:** `PriceLabel.TextBounds = (81.5, 11)` against `AbsoluteSize.X = 117.7` — 36.2px of
  headroom for the real "750 SPRAYPAINT" string, no truncation.
- **Colour, not-enough-funds state:** balance 0 < 750. `PriceLabel.TextColor3` and all four `SprayIcon`
  children read `(1, 0.294118, 0.294118)` = `#FF4B4B`. `BuyButton.Text = "NOT ENOUGH"`,
  `BuyButton.Active = false`.
- **Colour, affordable state:** set `Spraypaint` to 1000 via `player:SetAttribute` — a real attribute
  write on the live Instance, the same signal `refreshAffordability` listens on via
  `GetAttributeChangedSignal`. `PriceLabel.TextColor3` and all four `SprayIcon` children flipped to
  `(0.796078, 0.94902, 0.235294)` = `#CBF23C`. `BuyButton.Text = "BUY"`, `BuyButton.Active = true`.
- **Five panel witnesses unmoved, same-session A/B:** `DetailViewport`, `PriceLabel` (the panel-level
  weapon-price label, not the strip's), `ActionButton`, `EquipButton`, `StatsContainer` read
  byte-identical with `BuyStrip.Visible` true (open, RoseGold selected) and false (closed via
  `CancelButton`):
  ```
  DetailViewport: 210.91304,  216.473877 | 266.67392,  266.67392
  PriceLabel:     240.339142, 486.826111 | 237.247818, 25.7478256
  ActionButton:   505.17392,  523.608704 | 183.91304,  49.6565208
  EquipButton:    698.282593, 523.608704 | 156.32608,  49.6565208
  StatsContainer: 505.173889, 332.339111 | 349.434784, 174.717392
  ```
- Console output showed only pre-existing, unrelated sound-asset authorisation warnings across this
  session; no new errors traced to this change.
- `SkinRowController.Source` re-read after both edits: 13,751 bytes; `string.find(src, needle, 1,
  true)` (plain find, per the `string.gsub`-pattern trap) confirmed all three touched snippets present
  byte-exact — the function definition, the `refreshAffordability` call site, and the `ImageLabel`
  branch.

## Notes

**Click-driven paths are reachable this session — an update to the prior Phase 2 log's carve-out.**
`FPS-Spraypaint-Phase-2.md` recorded the buy-strip click paths as unexercised because `ViewportSize`
read `1,1` and `RenderStepped` fired 0/s in that session, collapsing every click-simulation route tried.
This session's viewport was live throughout: `user_mouse_input` against `weaponaryButton`, `AK47`,
`RoseGold`, and `CancelButton` each landed and produced the expected panel state. Not a fixed
limitation of this tooling — worth recording as a correction rather than an assumption carried forward.

**Chip scrolled outside the row's clipped window.** `RoseGold`'s `AbsolutePosition.X` initially read
`801.27` against the row's visible span `[210.91, 477.58]` — the exact "chip scrolled outside the
clipped window swallows clicks" trap on record. Scrolled into view by writing `SkinRow.CanvasPosition`
directly (a plain property, not a `require()`-mediated read) until `RoseGold` read `426.27`, confirmed
inside bounds, then clicked successfully.

**Rotation does not propagate to children in Roblox's 2D UI — confirmed empirically before building.**
A test parent `Frame.Rotation = 30` left a child's `AbsoluteRotation` at `0`. `Body` and `Cap` therefore
each carry their own `Rotation = 12` rather than relying on a rotated wrapper — each piece pivots around
its own centre rather than a shared one, an approximation of a single rigid tilt rather than an exact
one, acceptable at 16px and not distinguishable from an exact rotation at this scale without a
screenshot (unavailable — see Status).

**Both Studio Play/Edit toggles fired without this session's own input, more than once, mid-task** —
consistent with the other agent noted as concurrently active on `NotificationController`/
`GuiController` also driving Play/Edit transitions on the same shared Studio instance. Every
`execute_luau`/`multi_edit` call that hit "datamodel not available in \<mode\>" was retried after
re-confirming `get_studio_state` and re-issuing `start_stop_play`; no edit applied while in the wrong
mode — each such call errored cleanly rather than silently no-op'ing.

## Status
- **Confirmed live, this pass:** badge/label rectangles and centre-line match, text-fit headroom, both
  colour states (via a real attribute write, not a `require()`-mediated fake), all five panel witnesses
  unmoved (same-session A/B), and the click-driven path itself (chip click → strip open → Cancel →
  strip closed) — reachable this session, unlike the prior phase log's carve-out.
- **Needs a person — no visual check was possible.** `screen_capture` returns a magenta placeholder in
  this environment (documented trap). The badge's rectangles, colours and text-fit are proven
  numerically, but nobody has looked at the rendered spray-can silhouette itself — the tilt direction
  and dot placement were chosen by geometry, not confirmed by eye. A person with eyes on a live client
  should confirm it reads as a spray can before calling this done end to end.
