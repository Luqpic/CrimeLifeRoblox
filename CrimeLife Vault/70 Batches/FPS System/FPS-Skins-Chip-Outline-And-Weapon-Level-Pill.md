# Skin chip outlines finally render; weapon level pill added

**Status:** Confirmed live by screenshot through the real input path (HUD weaponry button → AK47 card
→ click Verdigris → hover Crimson): green rings on the equipped and the selected chip, a grey outline
on the hovered one, and the blue level pill under the Spraypaint pill. The red refusal flash lasts
about 0.4s and was not screenshotted. It uses the same now-rendering outline, and last round its
colour change was recorded frame by frame. Only client scripts changed, which the server test suite
cannot reach, so the live run is the verification. Studio and repo copies are checksummed identical.

## Summary

- **Bug 1.** No outline had ever appeared on the skin chips: not the green ring for the selected or
  equipped skin, not a hover outline, not the red "can't afford" flash. Now all three show.
- **Bug 2.** A blue `LEVEL <n>` pill with a bullet icon now sits directly below the Spraypaint pill,
  showing the weapon's upgrade level.

## Cause

Each chip is a **TextButton**. A `UIStroke` created with `Instance.new` defaults to
`ApplyStrokeMode.Contextual`, and on a TextButton that strokes the button's **text** rather than its
border. The chip's text is empty, so the stroke drew nothing at all.

The WeaponCard template sets `ApplyStrokeMode.Border` explicitly, which is why its hover outline has
always worked. The chips never did.

## Changes

- `SkinsCardController`
  - The chip stroke now sets `ApplyStrokeMode = Border`.
  - Outline states are now visible colours:

| State | Colour | Thickness |
|---|---|---|
| Rest | dark `#2A2E38` | 1 |
| Hovered | grey `#8A92A6` (the tab text grey) | 2 |
| Selected (previewed) or equipped | accent green | 3 |
| Can't afford | red `#FF4B4B` flash | 3 |

  - A selected chip stays green while hovered, so hovering never hides which skin is selected.
- `WeaponaryShopController`
  - `LevelChip`: a clone of `SpraypaintChip`, placed 10px below it. The outline and text use the
    RANGE bar's blue (`#3DA5FF`), and the spray-can shapes are swapped for the bullet icon
    (`rbxassetid://118647925274215`).
  - `refreshLevelChip` shows `LEVEL <n>`, read from the weapon's upgrade attribute (0 until the
    first upgrade, and for a weapon not yet owned). It runs when a weapon's detail opens and when that
    weapon's upgrade lands.

## Notes

**Why this survived a round of verification.** Last round every outline state was measured, and
every measurement was true: thickness 3 on hover, accent on the selected chip, and a frame-by-frame
recording of the stroke turning red. None of it reached the screen, because a Contextual stroke on an
empty-text button draws nothing whatever its colour and thickness. The preview screenshot from that
round shows it: Cobalt reads `BUY 500` with no ring around it, and that went unnoticed. This project
has now hit this failure three times (a blank notification card and black-on-dark icons were the
others): a property that reads correctly is not evidence that anything rendered.

**The old hover colour would have been invisible even with Border mode.** It was `#2A2E38`,
near-black on the near-black well, and only 2px heavier than rest. Hover now switches to the grey the
category tabs use, which is readable against the well.

**The level pill is cloned, not templated.** The clone happens before `WeaponaryShopController`
replaces the Spraypaint pill's native badge shapes with the spray-can image, so the clone carries
only those shapes, which it removes in favour of the bullet. Size, corner radius, font and text size
come from the Spraypaint pill itself, so the pair cannot drift apart.

**"Level" is read as the weapon's upgrade level**, not the player's level. The request put a bullet
icon on it, in a panel that is about one weapon, and player level already has its own HUD bar. Using
player level instead is a one-line change in `refreshLevelChip`.

**Icon asset.** `~/Downloads/Bullet.png` is a pure black glyph, like the earlier category icons. Since
`ImageColor3` multiplies, a black image cannot be tinted blue. It was re-exported white (129 opaque
pixels, shape identical) and uploaded through the same short-lived localhost route as before. The
original file is untouched.

**One known visual limit.** A selected **Acid** chip gets a green ring on a lime-green swatch, which is
low-contrast. Every other chip reads clearly. Worth a look if Acid is a common pick.
