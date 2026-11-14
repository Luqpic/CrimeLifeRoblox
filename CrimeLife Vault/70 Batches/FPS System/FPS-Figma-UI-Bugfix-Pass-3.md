# Figma UI — Bug Fix Pass 3

**Place:** `FPS System.rbxl` · Follows `FPS-Figma-UI-Bugfix-Pass-2.md`

Six reported. Two were regressions from my own earlier passes; both are called out as such.

---

## 1 — NPC dialogue plate never disappears *(regression I introduced)*

`DialogModule` hides the plate with `animDialogText` / `animDialogStroke`, which tween
`TextTransparency` and the stroke — and nothing else. That was fine while `dialog` had no background.
In pass 1 I gave it `BackgroundColor3` + `BackgroundTransparency = 0` to make it the Figma plate, so
from then on the text faded out and **the box stayed on screen forever.**

`BackgroundTransparency` is now part of the same tween, and set back to 0 in both places that reveal
the plate (`showGui`, and the exit-quip branch of `hideGui`). Verified by running the module's exact
hide tween against the live plate: background and text both reach 1.0.

## 2 — Two level bars

The second bar was the `LevelingGui` HUD showing behind the PlayerCard, not a duplicate inside it.
Fixed by bug 5: the HUD is hidden for as long as any panel is open, so nothing shows behind a panel.

## 3 — Price pill on top of the BUY/UPGRADE label *(my pass-2 fix did not work)*

I had given `ActionButton` a `UIPadding` with `PaddingRight = 88` to reserve room for the pill. But
**`UIPadding` offsets a GuiObject's children as well as its text** — the same trap that caused the
original icon overlap — so the right-anchored pill was moved 88px *left*, straight onto the label.
My verification measured the padding arithmetic rather than the pill's resulting position, so it
reported PASS on a broken layout.

A TextLabel cannot be inset without padding, so the caption is now its own child
(`ActionButton.Label`) and the button carries **no padding at all**. Label occupies x=18..112, pill
x=120..188 — measured, not inferred. The controller writes to `actionLabel.Text`.

## 4 — Inconsistent button effects

The five HUD buttons had drifted into three behaviours: weaponary and quests had `BounceOnClick`,
three had `ClickSound`, cashShop and gamepass had neither. They could not be levelled up by adding
scripts, because `Custom Inventory` carries a restricted `Capabilities` property and a script cannot
be parented into it.

All five per-button scripts removed; one `StarterPlayerScripts.HudButtonEffects` now binds the
identical effect to all five — the original UltimateUIPack motion reproduced exactly (hover 1.1,
click bounce), plus `UI.Sounds.bind` for hover/click audio. Base size and position are captured once
at bind time so a click landing mid-hover cannot bake the enlarged size in as the new resting size.

## 5 — All five panels could be open at once

New `ReplicatedStorage.UI.Panels`. The panels cannot be coordinated from outside — PlayerCard
**creates** its card on open and **destroys** it on close, while the shops toggle a frame, so there
is no single property to force. Each panel instead hands the module its own close function, and the
module calls it: the panel still closes through its own code path with its own state consistent.

Opening any panel also hides `Custom Inventory`, `StaminaGui`, `LevelingGui`, `BlasterGui`,
`ReticleGui` and `BlasterTouchGui`, restoring each to the value it had before (the blaster GUIs are
enabled/disabled per equip, so restoring them blindly to `true` would be wrong). Exit is the X
button, as asked.

`WeaponaryShopController` and `QuestLogController` define `close` *after* `open`, so both needed a
forward declaration for the close function to be in scope at the open site.

## 6 — Response billboard

`dialogResponses` is now the single container frame from the reference (panel fill, radius 14,
hairline, padding). Rows are fixed-size pills with the number in its own circular badge, and hover is
a **colour** change only — pill to acid, text to deep, badge inverted — replacing the size tween that
grew the row out from under the cursor. Text strokes removed.

Two latent faults fixed along the way: the script set `option.text.Position` to `0.02` on every open
(which is what put the badge on top of the first letter, overriding the layout), and it re-derived
`option.Size` from its own current value each time, so rows crept larger every conversation.

---

## Verification (live, Play mode, real clicks)

```
click weaponaryButton -> panels open: [WeaponaryShopGui]
                         hud: Custom Inventory=false LevelingGui=false StaminaGui=false
click X               -> panels open: [none]
                         hud: all three restored to true                     PASS
BUG4 leftover per-button effect scripts across all 5: 0                      PASS
BUG3 button.Text="" padding=false | label 18..112, pill 120..188             PASS
BUG6 container bg=0, row corners, no text stroke, text x=0.17 clear of badge PASS
BUG1 module's hide tween -> bg=1.00 text=1.00                                PASS
```

Bug 1 was verified by running the module's exact hide tween against the live plate, not by walking
to an NPC and holding a full conversation — worth a manual pass next time you are in game.

`ReplicatedStorage.UI.Panels` reports identical `Capabilities`/`Sandboxed` to `UI.Sounds` and
`UI.Theme`, which the controllers already require successfully; the `require` failure seen during
testing was the MCP command thread's own sandbox, and the real controllers loaded fine (proved by
the click test above working end to end).

## Still open

- **`StarterGui.ScreenGui.MultiExport`** — 1,155 instances, every `Image` = `rbxassetid://0`, no
  script references, replicating to every client. Approved for deletion three passes ago.
- `ReplicatedStorage.UI.Theme` is still dead code.
- Weapon `Description` attribute still unset, so that line renders empty.
