# Prompt: Fix Invisible Inventory Button, Reduce Hotbar to 6 Slots

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

---

## Part 1 — Inventory toggle button is completely invisible (regression, not a new bug)

**Confirmed root cause:** the previous pass repositioned `StarterGui."Custom Inventory".openButton` to the top-right and removed its `info` TextLabel (which used to say "(' to open inventory"), intending an icon `Image` to replace it — but no icon asset was available at the time, so `Image` was left as an explicit empty-string placeholder. Current confirmed state: `Image = ""`, `BackgroundTransparency = 1`, no text child. Nothing renders. The button is still there, still clickable, still correctly positioned — it's just 100% invisible, which is exactly "no GUI to open the inventory... despite anything."

**Fix — don't leave another invisible placeholder.** No real icon asset is available yet, so use a Unicode emoji glyph (🎒) as a genuinely visible, recognizably-backpack-shaped stand-in rather than nothing — this can be swapped for a proper `Image` the moment a real icon asset is provided, without touching layout/position again.

**`StarterGui."Custom Inventory".openButton`:**
1. Set `BackgroundTransparency` to `0.15` (was `1`) so the button has a visible dark square behind the glyph — it already has `BackgroundColor3` set to a dark gray, just needs to stop being fully transparent.
2. Add a `UICorner` child (`CornerRadius = UDim.new(0.2, 0)` or similar) so it matches the rounded-corner style already used elsewhere in this UI (the `toolButton` template and `SearchBox` both already have `UICorner`s — match that convention rather than a hard-edged square).
3. Add a `TextLabel` child (name it `icon`, distinct from the deleted `info`) covering the button: `Text = "🎒"`, `BackgroundTransparency = 1`, `Size = UDim2.fromScale(1, 1)`, `TextScaled = true`, `TextColor3 = Color3.new(1, 1, 1)`. Check what `Font` the rest of this UI's text uses (e.g. `toolButton.toolName.Font`) and match it if that font supports emoji glyphs reasonably; if unsure, `Enum.Font.BuilderSans` or the default is a safe bet — verify visually rather than assuming.

**Verify — do not skip this:** enter Play mode and take a `screen_capture` of the top-right corner. Confirm an actual visible button with a backpack-like glyph appears, not an empty region. This step was skipped last time, which is exactly how it shipped invisible — don't repeat that.

---

## Part 2 — Hotbar capacity: 9 → 6, keep it visually tight

Currently `module.slotAmount = 9` (in `StarterGui."Custom Inventory".InventoryController.SETTINGS`) controls how many weapons fit in the quick-access hotbar before additional ones overflow into the scrollable Inventory panel (`module:newTool`'s `length == self.slotAmount and "Inventory" or "HotBar"` check). Change this to `6`.

### Keep the hotbar frame sized to its content, not left oversized

Current measured layout: `hotBar` Frame is `Size = {0.452, 0}, {0.05, 20}` (45.2% of screen width), with `Grid` (`UIGridLayout`): `FillDirection = Horizontal`, `CellPadding = {0.01, 5}, {0, 5}`, cell size dynamically computed at runtime by `updateHudPosition()` as a square matching the frame's own height (`hotBar.AbsoluteSize.Y`) — this 45.2% width was sized to fit 9 cells plus padding. With only 6 cells, centering (`HorizontalAlignment = Center`) will keep it from looking broken, but the frame will be noticeably wider than its actual content, leaving visible dead space on both sides.

Scale `hotBar`'s width proportionally down: change `Size` from `{0.452, 0}, {0.05, 20}` to approximately `{0.3, 0}, {0.05, 20}` (only the X-scale changes, `6/9` of the original width, height/position/anchor untouched). Treat this as a starting estimate, not an exact formula — the padding has both a scale and a fixed-pixel component that doesn't scale perfectly linearly with cell count, so verify visually in Play mode (screen capture with a full hotbar of 6 tools) and nudge the value if there's still a visible gap or if it's now too tight for the cell size.

### Already-consistent, don't re-touch

`updateHudPosition()` already sets `Inventory.Frame.Grid.CellSize` to the exact same value as `hotBar.Grid.CellSize` (both computed from `hotBar.AbsoluteSize.Y` in the same function call) — so the overflow Inventory panel's item size already matches the hotbar's item size automatically. This is the "same format, synchronised" requirement the request asks for, and it already holds by construction; no change needed there, just confirm it still holds after the `slotAmount` change (it will, since neither value depends on `slotAmount`).

### Small consistency fix while in this area

`removeEmptySlots()` in `InventoryController` hardcodes `for index = 1, 9 do`, independent of `slotAmount` — harmless today (it just checks a few nonexistent slots 7-9), but now visibly inconsistent with the new 6-slot cap. Change it to `for index = 1, inventoryHandler.slotAmount do`, matching how `showSlots()` already does it correctly.

### Verify
- Carry 6 weapons: all 6 appear in the hotbar, none overflow to the Inventory panel yet.
- Carry a 7th: the first 6 stay in the hotbar, the 7th appears only in the Inventory panel (open it to confirm), not both places.
- Hotbar with 6 slots filled looks visually tight (no large empty dead zone on either side) — screenshot and check, don't assume the estimated resize is exactly right.
- Number keys 1-6 equip the correct hotbar slot; nothing is bound to 7/8/9 (expected, harmless).
- Inventory panel's overflow item icons/cells are the same size as the hotbar's — should already hold via the existing shared `CellSize` computation.

## Verification checklist

- [ ] Inventory toggle button is visibly present (screenshot-confirmed) at the top-right, not invisible.
- [ ] `slotAmount = 6`; hotbar overflows to the Inventory panel correctly at the 7th weapon.
- [ ] Hotbar frame width visually matches its 6-slot content, not left sized for 9.
- [ ] `removeEmptySlots()` uses `slotAmount` instead of a hardcoded `9`.
- [ ] Inventory panel and hotbar item sizes still match each other.
