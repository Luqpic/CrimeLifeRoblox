# Figma UI — Bug Fix Pass 4

**Place:** `FPS System.rbxl` · Follows `FPS-Figma-UI-Bugfix-Pass-3.md`

---

## 1 — Death scrim removed

The `blackOverlay` → 0.15 tween I added in pass 2 is gone. `blackOverlay` now does only the one job
it did originally: the black curtain that covers the respawn instant. The Figma DeathScreen frame
does specify a scrim, but in game it dimmed the entire HUD — cash readout, hotbar, button column —
for the whole death sequence, which read as a fault rather than atmosphere.

## 2 — Response container transparent

`dialogResponses` background transparency 1, stroke removed. The pills keep their own fills, so the
rows still read as a list without a plate behind them.

## 3 — Equipped hotbar slot: semi-transparent green gradient

Two parts, and the first attempt failed for an instructive reason.

A `UIGradient` (white → 59% grey, rotation 90) on the `toolButton` template turns the slot fill into
a vertical ramp. Because a gradient *multiplies* `BackgroundColor3`, the one gradient serves both
states — acid becomes a green ramp, the unequipped dark fill just gains a subtle falloff.

For the transparency I first wrote `BackgroundTransparency = 0.35` in the equip path. **Measured: it
came back 0.** The hover effect in `SETTINGS` caches `BackgroundTransparency` into a
`RestingTransparency` attribute on `MouseEnter` and tweens from it, so a write landing during a hover
is overwritten mid-interaction — and equipping necessarily happens while the cursor is on the slot.

The transparency is therefore applied to **`UIGradient.Transparency`**, which that effect never
touches. Verified equipped-while-hovered: gradient transparency holds at 0.35.

## 4 — PlayerCard level text and cash pill

`LevelLabel` is now white (it was dark on a dark track — effectively invisible). A `CashRow` is
cloned from `HealthRow`, so it matches the existing pill exactly rather than being re-derived, and
carries the cash glyph.

> **"Total earned" is not what this shows.** `leaderstats.Cash` is the only cash figure this game
> keeps. Nothing tracks lifetime earnings — `CashService`, `QuestService` and `MonetizationService`
> all add to that one IntValue and spending subtracts from it. The pill therefore shows the
> **current balance**. A true lifetime total needs a second stat incremented at every grant site and
> persisted; say the word and I'll add it.

## 5 — Cash readout in the Weaponary title bar

`CashChip` (icon + amount, acid outline) added to `WeaponaryShop.TitleBar`, bound to the same
`leaderstats.Cash` the HUD and cash shop read, so the three can never disagree. Verified live
showing `10,000`.

## 6 — Upgrade button rotates instead of growing

`HoverAndClick` went to 1.1× on hover and 0.9× on click — on a 200px button that is a 20px swing,
enough to visibly shove the EQUIP button beside it. Now 1.02× with a 4° tilt on hover and −4° on
click, following UltimateUIPack's "Rotate Hover".

---

## Verification (live, Play mode, real clicks)

```
BUG4 LevelLabel colour=1,1,1  text="Lv. 1"                          PASS
BUG4 CashRow label="Cash" value="10,000" icon=yes                   PASS
BUG5 CashChip amount="10,000" icon loaded                           PASS
BUG2 container transparency=1, stroke removed                       PASS
BUG3 equipped + hovered -> UIGradient.Transparency=0.35, rot 90     PASS
BUG1 BlackOverlay stays at 1 until the respawn curtain              PASS
BUG6 ActionButton rotation effect in place, rest rotation 0         PASS
```

## Process note

`multi_edit` reported **"3 edits applied"** for a `replace_all` pass on `SETTINGS` that in fact
changed only one line — a grep for the new text found nothing at the two call sites. The success
message is not proof. Every edit in this pass was confirmed by grepping for the inserted text
afterwards.

## Still open

- **`StarterGui.ScreenGui.MultiExport`** — 1,155 instances, no script references, still replicating.
- `ReplicatedStorage.UI.Theme` still dead code.
- Lifetime cash-earned stat does not exist (see bug 4).
