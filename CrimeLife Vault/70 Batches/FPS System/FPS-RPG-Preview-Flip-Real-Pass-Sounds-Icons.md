# Change Log: RPG Preview Upright, Real Gamepass, RPG Sounds, Gamepass Tab Logo, RPG Icon

**Date:** 2026-09-24
**Status:** Applied. Verified live in play by screenshots and a readback of every sound that played. The
place has not been saved to disk by this change.

## Summary
- **The RPG's 3D shop preview is no longer upside down.**
- **Real gamepass for testing:** the RPG pass uses id 10904398, a pass the developer owns, so the unlock
  now runs through the real MarketplaceService check at join.
- **RPG sounds:** its own shoot, reload, equip and impact sounds.
- **Shop art:** the Gamepass tab shows the supplied logo instead of the word, and the RPG has its card
  and hotbar icon.

## Cause (preview)
- The shop builds the 3D preview from the Blaster's bounding box. A bounding box is symmetric, so it
  cannot tell which way is up.
- That residual flip is what `ShopViewRotation` exists for. The AK47 carries `180, 0, 0`, and the RPG
  shares the AK47's body frame, so it needed the same value.
- The previous change cleared that attribute on the assumption that it was specific to the AK's mesh.
  That change's own shop screenshot showed the grips pointing up, and it was misread as upright.
- The attribute is restored on the RPG and kept in the build.

## Changes
- `ServerStorage.Weapons.RPG`:
  - `ShopViewRotation = 180, 0, 0` restored.
  - `TextureId = rbxassetid://123274987878588`: `~/Downloads/RPG.png`, cropped to its content and
    centred on a square 1024 canvas so it does not stretch like a 2752×1536 source would.
- `ServerStorage.Weapons.RPG.Sounds`:
  - `Shoot1-3`: 112670894256968. `Equip`: 127644583196232.
  - `MagOut`: 5278373892, the reload. It is one 2.17 s sound on the reload's first cue, about 0.5 s
    into the 3 s reload, so `MagIn` and `Charger` are silenced rather than replaying it.
  - New `Impact`: 130495957969380 (volume 1, inverse-tapered roll-off out to 400 studs).
- `ShotResolver.explode`: a weapon with `Sounds.Impact` plays it at the blast point, from an Attachment in
  Terrain so every nearby player hears it in 3D.
- `Monetization.Constants`: RPG `gamepassId = 10904398`. It is a stand-in ("MINOR ADMIN", owned by the
  developer) and must be replaced with the real RPG pass id in production.
- `WeaponaryShopController`: `ICON_ASSET_IDS.Gamepass = rbxassetid://138640924680599`, the supplied glyph
  re-exported white and upscaled 4x. The existing `applyCategoryIcon` replaces the tab's text with the
  icon and tints it with the tab's text colour, as it already does for the other tabs.
- `Blaster/BuildNewPistolsShotguns.luau`: records the icon, the kept flip, and a new `soundIds` table
  of per-slot overrides.

## Verification (play mode)
- `GamepassOwned_RPG = true` at join, set by MarketplaceService with nothing set by hand. The panel
  showed CLAIM · FREE, the claim went into slot 2, and Cash was unchanged.
- Screenshots: the preview is upright (grips down); the Gamepass tab shows the logo; the RPG card shows
  its picture.
- Sounds heard on the client, from equip through fire to reload:

  | Time | Sound |
  |---|---|
  | 0.1 s | EQUIP |
  | 2.2 s | SHOOT |
  | 2.4 s | IMPACT |
  | 4.7 s | RELOAD |

  IMPACT arrived 0.2 s after the shot, which is a 40-stud flight at 250 studs/s. On the server, Impact
  played at `Workspace.Terrain.Attachment`. Ammo was back to 1 after the reload.
- 0 client and 0 server errors or warnings.

## Notes
- The engine `Explosion` used for the flash still plays Roblox's own small bang under the new impact
  sound. An Explosion has no property to mute it. If that is unwanted, the flash can be rebuilt from
  particles instead.
- The grid card still reads "GAMEPASS" once the pass is owned; the detail panel shows CLAIM · FREE.
