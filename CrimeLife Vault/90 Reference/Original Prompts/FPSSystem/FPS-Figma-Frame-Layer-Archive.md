# Figma Frame → Layer Archive

Captured from `StarterGui.ScreenGui.MultiExport` before deleting that scaffold (1,155 descendants,
every `Image` set to `rbxassetid://0`, referenced by 0 scripts). This is the layer inventory of
Figma file `iRetcvpbMMD190DJA9Mwrm` and serves as the **export checklist**: every layer below must
end up either as an uploaded slice or as a native element at the exact Figma coordinate.

Legend: `IMG` = ships as uploaded image · `NATIVE` = stays a live Roblox element.

| Frame | Layers | Notes |
|---|---|---|
| **Design Tokens** | 38 | Swatches + `BannerPlate` + `Button / Primary` + `Button / Ghost` + `Chip / Value` + `Close`. Already mirrored in `UI.Theme`. Button/chip skins are the IMG slices to pull. |
| **WeaponaryShop · 920×580** | 12 | `BannerPlate`, `WEAPONARY`, `CashChip`, `Close`, `InventoryColumn`, tabs (`ALL`/`MELEE`/`PISTOL`/`AUTO-RIFLES`/`SHOTGUNS`/`OWNED`), `WeaponGrid` |
| **WeaponaryShop · Detail state** | 23 | Adds `BackButton`, `DetailViewport`, `CategoryChip`, stat rows (`DAMAGE`/`FIRE RATE`/`MAGAZINE`/`RANGE` each + `Track`), `ActionButton`, `EquipButton` |
| **WeaponStatPanel · 360×420** | 15 | `Icon`, `PISTOL · OWNED`, `UPGRADE LV. 2`, stat rows + `Track`, `UpgradeButton` |
| **WeaponCard · 130×174** | 3 | `Icon`, name, `Price` |
| **PlayerCard · 320×560** | 19 | `Thumbnail`, `LevelChip`, `HEALTH`/`XP`/`CASH` rows each with a `Track`, `COMBAT RECORD`, `Divider`, `CRIMINALSKills`, `POLICEKills` |
| **QuestLog · 420×460** | 6 | `BannerPlate`, `Close`, 3× `QuestEntry` |
| **Notification · 420×100** | 3 | `AccentEdge`, title, body |
| **LevelUpPopup · 360×90** | 2 | `LEVEL UP`, `LEVEL 12` |
| **HUD Bars** | 4 | `STAMINA · 240×10` + `Track`, `XP · 260×14` + `Track` |
| **In-Game HUD · 1920×1080** | 11 | `StaminaTrack`, `XPTrack`, `Reticle`, `AmmoHUD`, `Hotbar`, `WEAPONARY`, `PROFILE`, `QUESTS`, `CashHUD`, `CASH SHOP`, `GAMEPASS` |
| **DeathScreen · 1920×1080** | 4 | `BannerPlate`, `YOU WERE ELIMINATED`, `by THUG`, `RespawnPill` |
| **CashShop · 760×560** | 11 | `Balance`, subtitle, 6× `CashTier` (5,000 / 25,000 / 100,000 / 250,000 / 500,000 / 1,000,000 — each carries a `productId` placeholder of `000000000`) |
| **GamepassShop · 760×560** | 10 | 6× `Gamepass` (2X CASH / 2X XP / VIP / EXTRA SLOT / FAST RELOAD / INFINITE SPRINT — each with a `gamepassId` placeholder of `000000000`) |
| **Reticle** | 5 | 4× `Arm` + `Dot` |
| **Hitmarker** | 4 | 4× `Arm` |
| **BlasterTouchGui · mobile** | 2 | `ShootButton`, `ReloadButton` |
| **EnemyGUI · Billboard** | 3 | `THUG`, `HealthTrack`, `70` |
| **Quest NPC Nameplate** | 3 | `Plate`, `Dialog`, `Caret` |
| **QuestResponses · Billboard** | 3 | 3× `Response` |
| **OverheadGui · Billboard** | 1 | `Plate` |
| **Icon Set** | 32 | Pistol Gun, ID Card, Ribbon Shield, Shopping Cart, Money Stack (game-icons.net) + Ticket, X, Crosshair (lucide). First five already uploaded — see `Theme.Icon`. **Ticket and Crosshair are new and still need uploading.** |

## Live findings worth carrying forward

- **Two icons are missing from `Theme.Icon`:** the set contains `Ticket` and `Crosshair`, but
  `Theme.Icon` only holds `PistolGun`, `IdCard`, `RibbonShield`, `MoneyStack`, `ShoppingCart`,
  `Close`. Export and upload those two.
- **`Track` recurs on every bar** (stamina, XP, health, cash, all four weapon stats, enemy health).
  That is one 9-sliced `Track` image reused everywhere, not nine separate exports.
- **Monetisation ids are placeholders.** Every `CashTier` and `Gamepass` layer carries
  `productId: 000000000` / `gamepassId: 000000000`. Real ids live in
  `ReplicatedStorage.Monetization.Constants` — wire from there, never from the Figma labels.
- **`Billboards, world` has 0 layers** — it is a section header in Figma, not a frame to export.
