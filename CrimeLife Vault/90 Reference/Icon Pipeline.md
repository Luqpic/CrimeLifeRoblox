---
type: reference
tags: [reference, pipeline, icons, ui]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weapon-Icon-Decals.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponry-Category-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-1to1-Image-Export-And-Font-Fix.md", "CrimeLifeRoblox/.superpowers/sdd/uploaded-asset-ids.md", "CrimeLifeRoblox/FPSSystem/Blaster/BuildNewPistolsShotguns.luau", "ArsenalIcons/README.md"]
---

# Icon Pipeline

How an icon gets from a picture to the game. CrimeLife has no generated house-style icon set; icons come from the Figma file or from PNGs the developer supplies. Systems: [[HUD and UI Shell]], [[Inventory and Hotbar]], [[Weapon Shop and Upgrades]].

## Where icons are used
| Icon | Where the id lives |
|---|---|
| Weapon (hotbar, shop card) | the Tool's `TextureId` in `ServerStorage.Weapons`; the build script's `SPECS` row keeps it for rebuilds |
| Weapon on a world pickup billboard | mirrored by `WeaponPickup` as the pickup Model's `iconId` attribute (`ServerStorage` does not replicate) |
| Shop category tabs, Gamepass tab, spray badge | `ICON_ASSET_IDS` in `WeaponaryShopController`; `applyCategoryIcon` swaps the tab text for the icon and tints it with the tab's text colour |
| HUD icons, banners | `ReplicatedStorage.UI.Theme` ([[Figma and UI Art Pipeline]]) |
| XP and Health icons | `ReplicatedStorage.Leveling.Constants` (`XP_ICON_ID`, `HEALTH_ICON_ID`), the single owner |

## Steps
1. **Get the picture:** a Figma export (white, 4x) or a PNG the developer supplies (the category icons came from `~/Downloads/Weaponary/`, the RPG from `~/Downloads/RPG.png`). If no picture is supplied, ship text only and list it as open; never invent art.
2. **Prepare:** crop to content and centre on a square canvas (the RPG's 2752x1536 source would stretch otherwise); force glyphs to **white** with alpha untouched (the black category glyphs rendered near-invisible because `ImageColor3` multiplies); keep at or under 1024 px.
3. **Upload** with the Studio MCP `upload_image` (http/https URLs only: serve local files from a temporary localhost server and stop it straight after). Record each id against its source file.
4. **Wire** the id into the one owner listed above; tint with `ImageColor3`.
5. **Check** each id fetches in Play (none stuck in moderation), match source file names to Tool names one by one (`FN-P90` vs `FN P-90` happened), and screenshot the hotbar, card and tab.

## Not this project
`Documents/Roblox/ArsenalIcons/` (2026-10-18) is another project's gun-icon set (Studio side shots run through an image model). The method could be reused for CrimeLife, but none of its files or ids are CrimeLife's.

Related: [[GFX and Thumbnails]].
