# Change Log: Eight New Pistols and Shotguns

**Date:** 2026-09-24
**Status:** Applied — shop, catalog, skins and first-person equip verified live in play; firing,
reload feel and third-person hold not yet played by a person. Place not saved to disk by this change.

## Summary
The raw models in `Workspace.Pistols` and `Workspace.Shotguns` are now eight working weapons,
buyable in the Weaponary shop under their category tab, with a first-person viewmodel and skins.
Each is a same-class donor with only its visible mesh swapped. Handling, sounds, animations and
hand rigs are inherited.

| Weapon | Source model | Donor rig | Cat. | Price | Dmg | RPM | Mag | Range | Spread | Mode |
|---|---|---|---|---|---|---|---|---|---|---|
| Glock 18 | GLOCK 17 | Glock 17 | Pistol | 850 | 18 | 1000 | 33 | 700 | 2.6 | Auto |
| SIG M17 | SIG SAUER M17 / P320 | Glock 17 | Pistol | 500 | 23 | 600 | 17 | 900 | 1.5 | Semi |
| M45A1 | M45A1 | Glock 17 (M1911 sounds) | Pistol | 700 | 40 | 420 | 7 | 950 | 2.0 | Semi |
| USP Compact | H&K USP COMPACT | Glock 17 | Pistol | 525 | 27 | 520 | 12 | 800 | 1.9 | Semi |
| Remington 870 | REMINGTON 870, PICATINNY RAIL | Mossberg 590 | Shotgun | 800 | 16 | 85 | 7 | 560 | 8.5 | Semi |
| Sawed-Off 870 | REMINGTON 870, SAWED OFF | Mossberg 590 | Shotgun | 650 | 14 | 95 | 4 | 380 | 13 | Semi |
| MP-153 | BAIKAL MP-153 | Mossberg 590 (Benelli sounds) | Shotgun | 1050 | 14 | 170 | 5 | 560 | 9 | Semi |
| SPAS-13 | FRANCHI SPAS-12, EXTENDED STOCK | Mossberg 590 (Spas 12 sounds) | Shotgun | 1150 | 16 | 120 | 8 | 600 | 8 | Semi |

Shotguns keep the donor's 8 pellets, knockback and `isShotgun`.

## Changes
- `ServerStorage.Weapons` — eight new Tools. The donor's `Body` is kept as a hidden 0.2-stud anchor
  (it holds the Handle weld and `MuzzleAttachment`). The donor trims are removed. The new meshes
  are welded to `Body` as `Mesh1..N`, and `viewModel` points at the new viewmodel.
- `ReplicatedStorage.Blaster.ViewModels` — eight new viewmodels. The donor skeleton (Body, Trims,
  Magazine, Root, arms, Motor6Ds, animations) is kept whole and hidden. The donor's own visible
  `Mesh*` parts are removed, and the new mesh hangs off `Body`.
- `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` — `profiles` entries for all eight.
  Without them `Motion.new` asserts and first person never starts.
- No shop, skin or upgrade code changed. The catalog picks up any Tool with `Category`, and
  `SkinApplier` recolours any visible BasePart under `Blaster`.

## Verification (play mode)
- `ReplicatedStorage.Weapons.Catalog`: all 8 entries present with the correct Category and Price,
  plus a `Blaster` clone for the 3D preview.
- `SkinApplier.apply` on each Tool recoloured 5 / 8 / 6 / 8 / 5 / 5 / 7 / 14 parts (every
  visible part; before: weapons did not exist).
- Equipped all 8 in play: 0 client and 0 server errors, excluding the pre-existing unauthorized-sound
  noise. First-person screenshots checked for Glock 18, M45A1, Sawed-Off 870 and SPAS-13:
  gun upright, muzzle forward, sitting in the hand.
- Shop: the Pistol tab lists the four new pistols in price order, and the SIG M17 detail panel shows
  its stats, Buy 500 and the Skins card.

## Notes
- Two sources clashed with existing weapons (GLOCK 17 → `Glock 17`, SPAS-12 → `Spas 12`). At the
  user's direction they ship as Glock 18 and SPAS-13, so the Glock 18 got the real gun's full-auto
  character and a 33-round magazine.
- The sources are `Part`+`SpecialMesh`, not MeshParts. `Part.Size` is close to the rendered size
  (the AssetService MeshSize × Scale check was within about 0.1 stud on most parts, worse on tiny
  pins), so the extents were measured from `Part.Size`. Scaling multiplies both `Size` and
  `SpecialMesh.Scale`/`Offset`. Skins work because untextured FileMeshes render the part's Color.
- All eight sources lie on their side with the muzzle along world −X and gun-up along world −Z.
  That was found from geometry (the grip is the low part at the rear) and confirmed by screenshot.
- Lengths are the real gun's length at the donor's scale: pistols ≈ 9.7 studs/m (Glock 17 donor);
  shotguns ≈ 7 studs/m, capped at 7.6 for the MP-153 so it does not dwarf the roster.
  Each mesh is aligned to the donor's rear-top edge, so the grip sits in the donor's hand.
  The Sawed-Off is pushed 1.4 studs forward because it has no stock.
- The muzzle keeps the donor viewmodel's bore height and inset (the ADS offset is derived from it
  in `WeaponViewmodelMotion`), moved to the new barrel tip.
- No separate magazine piece on the pistols. In every source the magazine is fused into the whole
  grip part (checked by highlighting it), so moving it would carry the grip away. The donor's
  magazine joint is kept (the left hand still follows the reload) but it is hidden, so reloads show
  hand motion with no magazine leaving the gun. The shotguns have no magazine, matching their
  shell-by-shell donor.
- Found, not fixed (out of scope): the **Tool** `MuzzleAttachment` on existing Glock 17, Benelli M4
  and Spas 12 sits at the stock end, not the barrel. Their viewmodels are correct, so only the
  third-person flash and tracer start for other players are affected. Measured by placing each
  Blaster in a fixed frame and screenshotting it. The new weapons do not inherit this; their Tool
  muzzle is recomputed at the barrel tip.
- Stats sit inside the existing band for each category: pistols 19–40 damage outside the
  magnums, shotguns 14–20 per pellet × 8.

## Still needs a person
- **Save the place** (File → Save). These are live Studio edits.
- **Icons:** all eight have an empty `TextureId`, so the grid card and hotbar show text only. They
  need uploaded art like the other weapons (see FPS-Weapon-Icon-Decals).
- Play-feel: fire, reload and ADS each weapon. SIG M17 / USP / Remington 870 / MP-153 were verified by
  equip and console only, not by eye.
- Third-person hold uses the donor's `Grip` unchanged. Glance at it.
- The source models are still in `Workspace.Pistols` / `Workspace.Shotguns`. Delete them once
  approved.
