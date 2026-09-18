# Change Log: Close Buttons Unified With Robbery System

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Summary
The X buttons in this place were inconsistent with the Robbery System place and, more to the point, with each other. Five panels carried five close buttons across three sizes, two shapes and four different behaviours. They now use one shared slice at one size, driven by one shared module.

## What was actually different
| Panel | Size | Corner | Behaviour |
|---|---|---|---|
| PlayerCard | 28px | circle | nothing at all |
| QuestLog | 28px | circle | nothing at all |
| WeaponaryShop | 34px | circle | hover sound only, no click sound |
| CashShop | 38px | rounded square | sound, no motion |
| GamepassShop | 38px | rounded square | sound, no motion |

The cause was structural. This place rebuilt the button natively every time -- a dark chip plus `UICorner`, `UIStroke` and a tinted icon -- so each panel picked its own numbers. And `UI.Effects`, which the Robbery place drives every button through, had been written there and never brought back here, so each controller wired its own close button by hand.

## Changes
- `ReplicatedStorage.UI.Effects` -- ported in, byte-identical to the Robbery copy (9006 bytes, matching checksums).
- `Effects.CLOSE_IMAGE`, `Effects.CLOSE_SIZE` and `Effects.bindClose()` added to that shared module, so a panel now asks for a close button instead of choosing its own.
- All five `GuiTemplates` close buttons rebuilt as 36x36 `ImageButton`s on the shared Figma slice.
- Six call sites routed through `bindClose`: PlayerCard, QuestLog, CashShop, GamepassShop, WeaponaryShop and AdminLevel.
- Removed the bespoke handler in `WeaponaryShopController` that played a hover sound and nothing on click.

## Notes
- Robbery's X is the Figma-exported slice; this place was reconstructing the same design by hand. Both were rendered and compared before picking a direction.
- 36px fits everywhere: the smallest title bar is 46px tall.
- Verified on the real open/close path -- the panel opened, the X grew 36 to 39.6 on hover with one hover sound, clicked with one click sound, bounced back to rest, and the panel closed.
