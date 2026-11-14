# Figma UI — Bug Fix Pass 2

**Place:** `FPS System.rbxl` · Follows `FPS-Figma-UI-Bugfix-Pass.md`

Five reported. One was a regression I introduced in the previous pass, and one was a fix from that
pass that did not actually work — both called out below rather than buried.

---

## 1 — NPC dialog billboard: oversized caret, and a long rectangle

Two separate faults.

**The caret.** Last pass I added a `Caret` ImageLabel and set the old `arrow` TextLabel to
`Visible = false`. That was wrong on both counts: `DialogModule` sets `arrow.Visible = true` again
(line 327) and tweens its `TextTransparency`/`UIStroke` in ~10 places, so the arrow came back — and
my Caret was unmanaged, so it was simply always on screen at full size.

Caret destroyed. The `arrow` instance is **kept** (deleting it would throw at all ten call sites)
but emptied: `Text = ""`, `Size = 0,0`. It now renders nothing regardless of what the module does to
its transparency or visibility.

**The long rectangle.** `dialog` was authored at `Size = {2.5, 0}, {1, 0}` — two and a half times
the billboard width, on a single line. Now `{1.35, 0}, {1.15, 0}` with `TextWrapped = true`, so long
quest lines wrap into a box instead of stretching across the screen.

## 2 — Cash icon over the text, and "50" under the BUY label

**Why last pass's fix failed:** I gave `PriceLabel` a `UIPadding` of 32px to clear its icon. But
`UIPadding` offsets a GuiObject's **children** as well as its text — and the icon was a child. Both
moved 32px together, so they stayed exactly on top of each other. The verification I ran only
checked `padLeft >= icon width`, which was true and meaningless.

The icon is now a **sibling** (`DetailPanel.PriceIcon` at x=320..344, label at x=352). Nothing can
shift them together again.

**The pill collision:** `UPGRADE Lv.2` was rendering underneath the price pill. `ActionButton` is
now 200×54 with `PaddingLeft 18` / `PaddingRight 88`, reserving the pill's whole footprint.
Measured: label area ends at x=112, pill starts at x=120. The level moved to the line above
(`Upgrade to Lv.2`) so the button reads just `UPGRADE`, which measures 81px in 94px of room.

## 3 — Cash shop balance pill empty

`CashShopController.bindBalance()` was populating it correctly (`leaderstats.Cash` = 10,000), but
the icon still carried the pre-Figma MoneyStack and neither child had an explicit `ZIndex`. Icon
repointed to the Figma export, both children given `ZIndex 3` over the frame's 2, and laid out as
icon-then-amount per your request. Verified live: `amount = "10,000"`, icon loads.

Also caught: `CashShop.TierTemplate.Plate.icon` was still on the old asset, which is why the tier
rows showed a different money glyph from the header. Fixed at the template, so all six runtime
clones inherit it.

## 4 — Respawn text not centred

`Countdown.TextXAlignment` was `Left`. Set to `Center`/`Center` and its stray `UIPadding` removed.

## 5 — Dark overlay covering the screen at spawn *(regression I introduced)*

Last pass I set `DeathScreen.BlackOverlay.BackgroundTransparency = 0.15` on the **template** to match
the Figma scrim. That value is the clone's **resting state**, and the death controller only ever
clears the overlay *after* a death — so from spawn until your first death the scrim sat over the
whole screen.

Template restored to `1`. The scrim is now applied where it belongs: a tween to
`SCRIM_TRANSPARENCY = 0.15` at the start of `runDeathSequence`, alongside the text fade-in. The
existing black-curtain tween (to 0) and the cleanup tween (back to 1) are untouched.

---

## Verification (live, Play mode)

```
BUG5 BlackOverlay transparency=1 at spawn                       PASS
BUG4 Countdown XAlign=Center YAlign=Center                      PASS
BUG3 amount="10,000", leaderstats.Cash=10000, icon zi=3         PASS
BUG2 PriceIcon parent=DetailPanel; icon 320..344, label 352     PASS
     button label ends 112, pill starts 120                     PASS
     PriceLabel has UIPadding? false                            PASS
BUG1 Caret removed; arrow Text="" Size=0,0; dialog wrapped      PASS
```

**Asset-load check.** An initial sweep showed 13 of 18 images `IsLoaded = false`, which looked
alarming. Forcing a hidden GUI to render resolved it: Roblox lazy-loads images only when displayed,
and both the balance icon and the CASH banner reported `IsLoaded = true` once on screen. No bad
asset ids.

## Still open

- **`StarterGui.ScreenGui.MultiExport`** — every `rbxassetid://0` in the game is this scaffold. It
  is 1,155 instances replicating to every client on join, wired to nothing, referenced by no script.
  Approved for deletion two passes ago and itemized twice; still awaiting the final go-ahead.
- `ReplicatedStorage.UI.Theme` remains dead code — all of the above sets properties on instances
  directly. Wiring it up is what stops this class of drift.
- The weapon `Description` attribute is still unset on catalogue entries, so that line renders empty.
