# Change Log: Skin Chip and Skin Row — Figma Design (Cosmetics Task 6)

**Date:** 2026-09-22
**Status:** Figma design applied and verified live by screenshot. Lock glyph upload to Roblox did
NOT complete — blocked by an asset-URL trust rejection, not a design or verification failure. No
asset id was invented; a documented fallback is left for Task 7 (see Notes).

## Summary
Designed the `SkinChip` (52x52, four states) and `SkinRow` (290x60) for the weapon detail panel's
skin picker, as a new frame in the existing Figma file `iRetcvpbMMD190DJA9Mwrm`, page
`02 · Redesign`. Exported the 20x20 lock glyph used by the Locked state at 4x; the Roblox-side
upload of that export was rejected by the upload tool's URL trust check.

## Cause
Task 5 finished the server-authoritative skin equip path; Task 6 is the design step that gives
Task 7 (client UI) exact geometry, colours and a lock icon to build the picker row against. The
target is a measured 290x60 gap in the live `DetailPanel` (700x438, x 0-290, y 372-432) — nothing
existing in that panel may move, so the eight palette swatches have no room for name labels and the
row is designed to scroll and crop rather than shrink to fit.

## Changes
- New frame **"Cosmetics · SkinChip & SkinRow — Task 6"** (node `139:67`) added to page
  `02 · Redesign` at canvas position `(200, 4000)`, ~120px clear below the lowest existing frames
  (`In-Game HUD` / `DeathScreen`, which end at y=3880). Nothing pre-existing in the file was moved,
  resized or restyled.
- **SkinRow** (`139:71`): 290x60, fill `#171A22`, 8px corner radius, 4px padding, horizontal
  auto-layout, `clipsContent = true`. Populated with 8 `SkinChip` instances (52x52, 6px gap, 458px
  total content) in the live palette order from `ReplicatedStorage.Cosmetics.Palettes` (values
  cross-checked against `FPSSystem/Cosmetics/Palettes.luau` and match exactly): Stock, Carbon,
  Sandstorm, Crimson — Rest; Acid — Equipped; Gold, Obsidian, Arctic — Locked (the VIP trio, all
  three shown locked rather than just one, since that is the realistic default-unowned state).
  At rest the frame crops to ~4.5 of the 8 chips, which is the intended scroll cue.
- **SkinChip state comparison** (`139:73`): a separate row of four 52x52 chips holding one swatch
  (Crimson) constant across Rest / Hover / Equipped / Locked, each captioned, so the four states can
  be read side by side independent of palette colour.
- **Lock glyph** (`140:4`, grouped as `LockGlyph`): built from two shapes on a 20x20 canvas — a
  9x10 stroked ellipse "shackle" (2.2px stroke, `#8A8F9A`, no fill) sitting above a 14x9 rounded
  rectangle "body" (corner radius 2, fill `#8A8F9A`) that occludes the shackle's lower half. Cloned
  into every Locked chip, centred at (16, 16).
- **Contrast fix applied after screenshot review:** added a 1px `#2A2E38` stroke to every chip in
  the Rest and Locked states (the two states that otherwise carry no stroke at all) across both the
  SkinRow and the comparison row. Hover/Equipped keep only their spec'd 2px `#CBF23C` stroke.

## Notes — screenshot review (Step 4)
- **Lock glyph legibility at 52px:** confirmed legible. Screenshotted the true-size (52x52) Locked
  chips at 4x zoom (`get_screenshot` + local upscale for inspection) — the shackle-over-body
  silhouette reads cleanly as a padlock on Gold, Obsidian and Arctic, no muddiness at that size.
- **Obsidian vs. `#171A22` row background:** on the first build (no edge stroke) this was
  marginal, not a clean pass. Obsidian's Locked fill (`#4E1E60` at 35% opacity over the row) blends
  to roughly `#2A1B38` against a `#171A22` background — about a 5% average-luminance difference,
  carried mostly by hue (purple cast) rather than value. Visible on close zoom, faint at native
  size — judged this as the "disappears into the row" case the brief warned about, and applied the
  offered fallback (1px `#2A2E38` stroke) rather than leave it borderline. Re-screenshotted with
  `clipsContent` temporarily disabled to see all 8 chips at once: every Rest/Locked chip, including
  Obsidian, now shows a clear rounded-corner edge against the panel background. `clipsContent` was
  restored to `true` afterward.
- **Side finding, not fixed:** the Equipped state's `#CBF23C` accent stroke is nearly invisible on
  the **Acid** swatch specifically, because Acid's own fill colour is the accent token itself
  (same hue, same value). This is a spec'd-colour collision, not a build error — left as designed
  since the four state definitions are fixed numbers from the brief, but flagging it for Task 7:
  equipping Acid will show a much weaker selection ring than any other skin.

## Notes — lock glyph export and upload (Step 5)
- Exported `LockGlyph` (`140:4`) via `download_assets`, format png, scale 4x → 80x80 PNG (1334
  bytes), confirmed locally before upload.
- Attempted `mcp__Roblox_Studio__upload_image` against the attached Studio instance (`FPS
  System.rbxl`, id `ea0a6094-7699-4852-be8a-dc37e0a66ab1`) with both the PNG and SVG Figma export
  URLs. Both were rejected immediately: `"Error Upload: Image Url is not trusted"`. This is a clean
  URL-trust rejection before any moderation step — not a moderation hold, not a transient failure
  (retried once). No asset id was invented, and no other write was made to the Roblox place.
- **Fallback for Task 7:** build the lock glyph in Roblox as two plain Frames, matching the Figma
  geometry — a rounded/stroked shackle arc above a rectangular body, colour `#8A8F9A`, proportioned
  as a ~9x10 shackle over a 14x9 body (corner radius 2) on a 20x20 base, scaled to whatever final
  chip size is implemented. If that is also more than Task 7 wants to take on, the locked state can
  fall back to the dimmed swatch alone (already at 35% opacity, still distinguishable per the
  contrast fix above).

## Verified live vs. not
- **Verified live:** SkinRow and SkinChip geometry, fills, corner radii, padding and gap all set and
  read back via the Figma Plugin API in the same scripts that created them; visual result confirmed
  with `get_screenshot` (overview, true-size 8-chip row with clipping on and off, before/after the
  contrast fix). No existing Figma node was touched — confirmed by only ever creating new node IDs
  (`139:*`, `140:*`) and never mutating an ID from the pre-existing tree.
- **Not verified / needs a person:** the lock glyph has not been placed as a live Roblox asset. A
  person with access to Roblox's asset-upload trust list (or a different image host on that list)
  should either get the PNG uploaded and hand Task 7 the resulting `rbxassetid://`, or explicitly
  sign off on the two-Frame fallback described above.
