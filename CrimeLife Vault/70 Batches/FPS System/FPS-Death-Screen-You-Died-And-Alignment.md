# Change Log: Death Screen Reads "You Died", Centred, and the Fade Measured

**Date:** 2026-09-19
**Status:** Applied (geometry, asset load and fade confirmed live; appearance not eyeballed -- see Notes)

## Summary
The death screen banner now reads "YOU DIED" instead of "YOU WERE ELIMINATED", and the banner,
phrase and countdown sit as one block centred on the screen instead of at three hand-dragged
fractions. The fade-in that was asked for already existed; it was measured rather than rebuilt.

## The text was never in a script
`grep` for "eliminated" across the whole place returns only the `Eliminated` BindableEvent that
ShotResolver fires. The words were pixels inside `rbxassetid://130775797143022`, exactly as the
banner titles on the five panels are -- so changing them is a Figma export, not a property edit.

## Changes
### Figma (`Roblox`, file `iRetcvpbMMD190DJA9Mwrm`, page `02 · Redesign`)
- `DeathScreen · 1920x1080` > text `15:44` -- characters "YOU WERE ELIMINATED" -> "YOU DIED", layer
  renamed to match.
- Same node -- `textAlignHorizontal` `LEFT` -> `CENTER`, and the text box resized from 600x72 at
  (666, 402) to 640x92 at (640, 390), which is the banner plate's own rectangle. The box and the
  plate now share one frame, so CENTER/CENTER is centred on the banner rather than on a box that
  sat 6px right of it.
- Same node -- font size 42 -> 82. "YOU DIED" is 8 characters where "YOU WERE ELIMINATED" was 19;
  at 42px it measured 230px inside a 640px plate. 82px was derived to fill 70% of the plate width,
  not chosen by eye.
- New group `BannerPlate · Export` (`133:67`) holding the plate and its title, so the pair exports
  as one slice instead of two siblings that have to be selected together.

### Studio
- `GuiTemplates.DeathScreen.TextContainer.BannerPlate` -- `Image` swapped to
  `rbxassetid://131786443590898`, the 4x export of that group. `Size` unchanged: the export is
  2565x392, which is 641x98 at 1x, matching the ImageLabel exactly.
- `GuiTemplates.DeathScreen.TextContainer` -- the three children restacked. Positions were the
  fractions `0.4037 / 0.4991 / 0.5723`; they are now offsets `-71 / +19 / +90` from a shared
  `0.5` centre, derived from each element's own height plus one 24px gap rather than typed in.
- `Phrase.Text` -- the placeholder `"effe"` replaced. The script overwrites it at runtime, so this
  is tidiness, not behaviour.

## The fade-in already existed
`DeathScreen` tweens `TextContainer.GroupTransparency` from 1 to 0 over `FADE_IN_TIME` (0.5s), and
the banner, phrase and countdown are all inside that CanvasGroup, so they fade as one. Measured
across a real death: 1.00 at rest, then 0.750 / 0.361 / 0.111 / 0.005 / 0.000 at t+0.05 / 0.18 /
0.32 / 0.45 / 0.58s -- a Quad-Out curve settling at ~0.5s. Nothing was added.

## Verification
- Horizontal: all three elements measure `centreX = 450.0` against a viewport centre of 450.0.
  Spread between them: **0.00px**.
- Vertical: block centre `301.5` against a true screen centre of `301.5`; block height 240px.
- The `301.5` needs the inset trap to read correctly: this ScreenGui sets `IgnoreGuiInset = true`,
  so its `AbsolutePosition` origin is 58px above the inset origin. Measured naively the block looks
  58px high; measured against `viewport.Y / 2 - GuiService:GetGuiInset().Y` it is exact. The first
  measurement taken here made that mistake.
- New asset: `ContentProvider:PreloadAsync` reports `IsLoaded = true`, so the upload cleared.
- Fade: `GroupTransparency` reaches 0.000 on the real death path.

## Notes
- The export is 4x through the same pipeline as the other banner plates, so it matches them.
- The plate is an angled parallelogram. The title is centred on its bounding box, which leaves
  marginally more red to the right of the text where the right edge slants in. Centring on the
  visual centroid instead would need the slant measured; the Figma render reads correctly as-is.
- **Not verified:** how it looks in the running game. `screen_capture` returned a blank magenta
  frame, the same environmental failure recorded in the cash-burst entry -- the Studio viewport is
  not rendering for capture. Everything above is measured, not seen. The Figma render of the frame
  was inspected and is correct, but that is the design, not the game.
- Not touched, deliberately: the `by THUG` line and the respawn pill exist in the Figma frame but
  not in the Studio template, and the countdown keeps its own solid plate. Scope was the banner
  text and alignment.
