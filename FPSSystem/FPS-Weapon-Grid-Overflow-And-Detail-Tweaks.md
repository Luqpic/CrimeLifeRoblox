# Weapon Grid Overflow, Price Row Move, Melee Stats

**Place:** `FPS System.rbxl` · Follows `FPS-Quest-Overflow-And-Dead-Code-Removal.md`

---

## 1 — Weapon grid overflow (same root cause as the quest log)

`WeaponGrid` had the identical configuration fault:

- `ScrollingDirection = XY` on a grid that only ever grows downward → **now `Y`**
- The arithmetic did not fit: 5 cells × 130 + 4 gaps × 12 = **698** in a 700px frame, before the 6px
  scrollbar and each card's 1px stroke. Cell narrowed to **120×148** with 4px padding.
- `ZIndexBehavior` is `Global` on these ScreenGuis, so equal ZIndex renders in tree order. The card
  is now explicitly layered (card 2, children 3).

### Verified live

```
WeaponGrid dir=Y
28 cards, 5 per row
clip region   x = 344..1038
cards+stroke  x = 347..997      -> all inside, 41px spare
```

### A correction to my own test

My acceptance check was `AbsoluteCanvasSize.X <= AbsoluteWindowSize.X`, and it kept reporting FAIL
by exactly 6px. **That criterion is wrong whenever a vertical scrollbar is present**: the canvas is
the full frame width while the window is frame-minus-scrollbar, so the two can never be equal. I
shrank the cells twice chasing a number that could not be reached.

The meaningful conditions are the two that now pass: every card sits inside the visible region, and
`ScrollingDirection = Y` makes horizontal scrolling impossible regardless of canvas width.

Consequence worth knowing: cells ended up at 120×148 rather than the Figma 130×174, and there is
41px of spare width. They could go back up to ~126 wide if you want them closer to the design — the
fit was never as tight as my faulty check implied.

## 2 — Upgrade cost moved under the 3D view

The price icon + "Upgrade to Lv.X" line sat in the right column above the buttons. Now directly
beneath the weapon viewport in the left column.

```
viewport bottom y=496 | icon y=502 | label y=500      -> below the viewport
icon x=344, label x=376, viewport x=344              -> same column
```

## 3 — Melee weapons no longer show Magazine

`refreshDetailStats` hides the `Magazine` row when `Category == "Melee"`. The `UIListLayout` closes
the gap, so the panel reads as three stats rather than four with a hole. Shown reading `0`
previously, it looked like a stat the crowbar was simply bad at.

Verified on the Crowbar: `category=MELEE`, Damage/FireRate/Range visible, **Magazine hidden**.

## Still open

- Two-player test: nameplate at distance, view-card prompt, prompt toggling, and the possible
  `IndicatorClient` OverheadGui / `PlayerNameplates` duplicate name.
- Quest CLAIM/ACTIVE swap unobserved with a genuinely claimable quest.
- Gamepass owned-highlight blocked on real gamepass ids.
- `workspace."UI Animation Pack - by JakeDev"` (166 instances) — inert but replicates; your call.
