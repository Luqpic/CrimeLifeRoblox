# Weaponry category tabs and spray badge use icons instead of words

**Status:** Confirmed live by screenshot, through the real input path. The shop was opened by clicking
the HUD weaponry button and a weapon card was clicked to open the detail panel — not force-shown. All
four category icons render in the tab text colour and the spray icon renders beside the balance.
Test suite 146/146 in a real server VM (run after the first id pass; the second pass changed only
client-side ids and tint lines the suite cannot observe, and the shop was then exercised live).

## Summary

The `Melee`, `Pistol`, `AutoRifle` and `Shotgun` category tabs now show icons in place of their words,
and the spray-can badge beside the Spraypaint balance is an icon rather than a shape built from Frames.
`All` and `Owned` keep their words — no icon was supplied for them.

## Cause

Requested change. The icons came from `/Users/luqpic/Downloads/Weaponary/`.

## Changes

- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the `ICON_ASSET_IDS` table (added by the
  sticky-card change as an empty-by-default fallback) now holds real ids, and each icon is tinted to
  match what it replaces.

| Icon | Source | Asset id in use |
|---|---|---|
| Melee | `Weaponary/Melee.png` | `rbxassetid://106906257244958` |
| Pistol | `Weaponary/Pistol.png` | `rbxassetid://94971487013526` |
| AutoRifle | `Weaponary/Autorifle.png` | `rbxassetid://125690668175292` |
| Shotgun | `Weaponary/Shotgun.png` | `rbxassetid://113177593124606` |
| Spray | `Weaponary/Spray.png` | `rbxassetid://76994955461263` |

## Notes

**The supplied icons are black, and that cannot be fixed with a tint.** Every one of the five PNGs is a
pure `(0,0,0)` glyph on transparency. The first upload used them as-is, and every property check passed
— `Visible = true`, `AbsoluteSize` 16.6 square, the right asset id on the right tab. The screenshot
showed black glyphs on a near-black tab plate, all but invisible beside the readable grey `All` and
`Owned`.

`ImageColor3` **multiplies** the image. Black multiplied by any colour is still black, so no tint value
could have made them readable. The fix was in the asset, not the code: each PNG was re-exported with its
RGB forced to white and its alpha left untouched — the opaque pixel count of every icon matches its
original exactly (Spray 142, Melee 119, Pistol 148, Autorifle 54, Shotgun 55), so the shapes are
identical and only the colour changed. White is the correct base for any Roblox icon that is meant to be
tinted. The originals in `~/Downloads` were not modified; the white copies were generated separately.

**Why the icons follow the tab's `TextColor3` instead of a fixed colour.** Each category icon's
`ImageColor3` is copied from its tab's `TextColor3` and kept in step through a property-changed
connection. The tab's word is blanked, but the tab keeps its text colour, and any selected-state styling
that recolours that text now recolours the icon too. So the icon reads exactly as the word it replaced
did, and this code does not have to know the tab styling rules to stay correct if they change. Measured:
tab and icon both `0.541, 0.573, 0.651`. The spray icon is tinted to the balance figure it sits beside.

**Superseded upload, kept on record.** The black versions were uploaded first as
`115015928081222` (Melee), `129971300473620` (Pistol), `97567073822272` (AutoRifle), `138688703503084`
(Shotgun) and `110396136021812` (Spray). Nothing references them now.

**How the images got into Roblox.** `upload_image` accepts only http/https URLs — never a local path,
and it rejects Figma's CDN as untrusted. The files were served from a short-lived localhost HTTP server,
uploaded, and the server stopped immediately. This needed the user's explicit permission, which was
given. It is the route to use for any future local asset, and it is what unblocked the icons.

**The GiSpray icon was uploaded too, and is not used.** `~/Downloads/GiSpray-icon-96px.png` has been
outstanding since the Spraypaint rename, blocked by the same upload limitation. It went up as
`rbxassetid://110676870866600` while the route was open. It is not wired in: the user asked for the
`Weaponary/Spray.png` icon instead, which supersedes it.
