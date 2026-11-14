# Figma UI — 9-Bug Fix Pass

**Place:** `FPS System.rbxl` · Follows `FPS-Figma-1to1-Image-Export-And-Font-Fix.md`

All nine reproduced, traced to a mechanism, fixed at the layer that owned the fault, and verified in
Play mode. No new console errors.

---

## 1 + 4 — Banner title clipped (WeaponaryShop, QuestLog)

**Not a missing asset.** The title is already baked into the banner image; it was being *cut off*.
The banner deliberately overhangs the panel's top-left corner (Figma places it at −19,−21), and
those two panels were the only ones with `ClipsDescendants = true` — so the overhang, which is
exactly where the title sits, was clipped away. `PlayerCard`, `CashShop`, `GamepassShop` and
`WeaponStatPanel` already had clipping off, which is why only these two showed it.

`ClipsDescendants = false` on both. Their scrolling regions are `ScrollingFrame`s, which clip
themselves, so panel-level clipping was doing no useful work.

> This is why I did **not** export a separate title image as suggested — a second asset would have
> been clipped in exactly the same way. The clip was the bug.

## 2 + 3 — Two cash visuals, and text over the icon

`WeaponaryShopController` wrote a 💵 (`\u{1F4B5}`) into four different labels **on top of** the
existing `MoneyStack` ImageLabel. Two glyphs saying the same thing, and the emoji's advance width
was what pushed the text across the icon.

- Emoji removed from all four sites (lines ~385, 397, 422, 494).
- Price now renders as a **dark pill inside the BUY button**, matching the Figma detail state and
  your reference shot — `ActionButton.Price.Label`.
- The separate price row is hidden in the buy state (the pill says it) and used only for
  "Upgrade cost" / "Not for sale".
- Where the icon does still show, it is 24px at the left with the text inset 32px, so they cannot
  overlap. Verified: `padLeft=32 >= icon 24px`.

## 5 — Weapon stat UI

Rebuilt `DetailPanel` to the Figma detail state: viewport enlarged to 290×290, right column at
x=320, and each stat row is now label + right-aligned value over a **coloured track**, per Figma —
Damage `#7C4DFF`, Fire Rate `#FFC53D`, Magazine `#4ADE80`, Range `#3DA5FF` on a `#12141A` track.
Added `CategoryChip` and `Description`. `EQUIP` is now the outlined acid pill.

Bars are driven by a new `setStatBar()` against catalogue-wide ceilings
(`Damage 100 · FireRate 1200 · Magazine 100 · Range 1000`) so bars stay comparable *between*
weapons — which is the point of showing them at all. Verified 4/4 tracks with fills.

## 6 — Stamina outline visible when idle

`setVisible` tweened `GroupTransparency` on the `CanvasGroup`. A CanvasGroup composites its
**children** through that property, but a `UIStroke` on the group itself is drawn on the group's own
border and is not part of the composite — so the outline never faded. Now tweened explicitly in
step, plus an initial `Transparency = 1` (the template ships the group hidden but the stroke at 0,
so it was visible from spawn until the first sprint). Verified: group 1, stroke 1.

## 7 — Quest billboards

- **Nameplates** (6 NPCs): name → acid-outlined pill, dark fill, acid uppercase text; dialog → dark
  rounded plate with hairline; the `^` text arrow replaced with the exported `Caret` vector
  (`rbxassetid://124968067078234`), which Roblox has no glyph for.
- **Responses**: `DialogModule:186` baked the number *and* doubled quotes into the label, producing
  `1.) [''Accept'']` on screen. The number now lives in its own circular `Num` badge per Figma and
  the label carries just the response text. Verified 9/9 rows have the badge.

## 8 — Notification text outside the bar

The template positioned its two labels with a `UIListLayout` + `UIPadding` while both labels were on
`TextScaled` with `TextSize = 8`, and `QuestFeedbackController` pushed a whole sentence with
`<font>` markup into a single-line message label that did not have `RichText` enabled.

Rebuilt to Figma's absolute layout: `AccentEdge` 6×72, title 19px acid at (34,18), message 17px
white at (34,52), `RichText` on, `TextScaled` off, and `ClipsDescendants` on the plate as a
backstop. `NotificationController.show(message, title?)` now takes an optional title (default
`"NOTICE"`, existing one-arg calls unaffected); quest completion passes `"QUEST COMPLETE"` with just
the quest name as the message.

Verified: longest real quest name measures 114px in a 330px line; message occupies y 52–76 inside a
100px plate.

## 9 — Death screen

Rebuilt to Figma: the red `YOU WERE ELIMINATED` plate is the baked image
(`rbxassetid://130775797143022`, real Archivo Black), overlay at `#0E1016` 0.15 transparency, the
ragebait phrase takes the slot and styling Figma gives `by THUG` (muted, 26px), and the countdown
became the acid respawn pill (300×60, r=30, dark display type). `TextContainer` stays the
`CanvasGroup` the controller fades, so the existing sequence is untouched.

---

## Verification

```
BUG6 StaminaBar GroupTransparency=1  UIStroke.Transparency=1  PASS
BUG1 WeaponaryShop ClipsDescendants=false                     PASS
BUG4 QuestLog ClipsDescendants=false                          PASS
BUG2 ActionButton.Price pill=present                          PASS
BUG3 PriceLabel padLeft=32 >= icon 24px                       PASS
BUG5 stat tracks with fills: 4/4                              PASS
BUG7 response rows=9  with Num badge=9                        PASS
BUG8 msg 52..76 inside 100px plate; longest name 114/330px    PASS
BUG9 banner + phrase + acid pill in place                     PASS
```

Console after the pass contains only the two pre-existing faults:
`Workspace.UI.OverheadGui.InformationLabel.Script:2` (`Head is not a valid member of Part`) and the
weapon-sound `User is not authorized to access Asset` batch. Neither is touched by this work.

## Still open

- `StarterGui.ScreenGui.MultiExport` — still awaiting the go-ahead to delete.
- `ReplicatedStorage.UI.Theme` remains dead code; these fixes set properties on instances directly
  because nothing requires the module. Wiring it up is still the real refactor.
- `Description` is read from a `Description` attribute on catalogue entries; weapons without one
  show an empty line.
