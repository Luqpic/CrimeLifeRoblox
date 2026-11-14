---
type: system
tags: [system, shop, weapons, upgrades, fps]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponary-Shop-Refactor.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/FPSSystem/Weapons/WeaponUpgradeService.luau", "CrimeLifeRoblox/FPSSystem/Cosmetics/WeaponShopService.luau", "CrimeLifeRoblox/FPSSystem/Cosmetics/WeaponaryShopController.luau", "CLAUDE.md (Systems: Shop and upgrades)"]
---

# Weapon Shop and Upgrades

**Skills:** `roblox-game-systems`, `roblox-ui`, `roblox-security` (load these for work here)

## What it does
The Weaponary shop is the only way to get a weapon. Players browse a catalogue by category, see stats and a spinning 3D preview, buy with Cash, pick which of four loadout slots carries it, and buy damage upgrades per weapon type. Ownership is permanent and uncapped; only the four carry slots are limited. Gamepass weapons (the RPG) are claimed free here once the pass is owned.

## Where it lives
- Server: `ServerScriptService.Weapons.Scripts.WeaponShopService` (catalogue, ownership, slots, `grantWeapon`), `ServerScriptService.Weapons.Scripts.WeaponUpgradeService`.
- Remotes: `ReplicatedStorage.Weapons.Remotes.BuyRequest`, `.UpgradeRequest`, plus a set/clear loadout-slot request (`SetLoadoutSlotRequest` in the persistence log).
- Data: `ReplicatedStorage.Weapons.UpgradeConfig` (`COST_PER_LEVEL`, `DAMAGE_PER_LEVEL`, `ownedAttributeFor`), weapon Tools in `ServerStorage.Weapons.*` (attributes `Category`, `Price`, `Gamepass`, `ShopViewRotation`).
- Client: `StarterPlayer.StarterPlayerScripts.WeaponaryShopController`; templates `ReplicatedStorage.GuiTemplates.WeaponaryShop` (`ShopArea.DetailPanel`, `WeaponGrid`, `TitleBar.CashChip`) and `.WeaponCard`.
- Repo copies: `CrimeLifeRoblox/FPSSystem/Cosmetics/WeaponShopService.luau`, `WeaponaryShopController.luau`, `FPSSystem/Weapons/WeaponUpgradeService.luau`.

## How it works
- **Catalogue.** Any Tool in `ServerStorage.Weapons` with a `Category` is listed; a Tool with a `Price` is cash-buyable. No price and not owned reads "not for sale". The server publishes a read-only catalogue (with a visual model copy) for clients to browse. Grid sorted cheapest first in every category.
- **Tabs.** Category tabs (Melee, Pistol, AutoRifle, Shotgun as icons; Owned as a word) then a Gamepass tab last; the shop opens on Melee. Tab widths are computed to fill the row exactly. The old "All" tab became the Gamepass tab on 2026-09-24.
- **Buying.** `BuyRequest` checks ownership, funds (or `GamepassOwned_<key>` for a gamepass weapon, cost 0) on the server. Buying only grants ownership (`WeaponOwned_<name>` player attribute); it never puts the gun in hand. Since 2026-09-24 a fresh buy drops the panel straight into the slot picker ("Select a slot to equip").
- **Slots.** Four carry slots published as `LoadoutSlot1..4` player values; these are what is restored on respawn. `grantWeapon` is the single choke point for a fresh equip and a respawn restore, and also applies the equipped skin ([[Cosmetics and Skins]]).
- **Upgrades.** Keyed on (player, weapon type), not the Tool. Damage is always recomputed as stock damage + level x `DAMAGE_PER_LEVEL` (5 since 2026-09-16), never stacked. Cost is `COST_PER_LEVEL` x next level (the persistence test recorded 50 then 100 for two upgrades). The panel repaints when the new level attribute arrives, not on a timer. Called "a placeholder rather than tuned balance" in the log.
- **Preview.** The detail viewport clones the weapon, drops invisible parts, orients it from its own bounding box (muzzle forward, magazine down; melee long axis vertical, spinning at half a gun's rate), and spins about the centred origin. `ShopViewRotation` fixes the residual up/down flip a bounding box cannot decide (AK47 and RPG carry `180, 0, 0`). Only switching weapon rebuilds the model.
- **Feedback.** Client pre-checks affordability and flashes the button red with a denied tone (server still validates). Spending throws a coin burst from the button (`UI.CashBurst`, see [[Economy and Cash]]). Hover tick on cards and buttons; slots and tabs deliberately silent. Filled slots get an acid 2px stroke. Melee hides the Magazine stat row. A blue `LEVEL <n>` pill under the Spraypaint pill shows the weapon's upgrade level.
- **Skins card.** Opening a weapon's detail slides the shop left and the detached Skins card in beside it ([[Cosmetics and Skins]]).
- **Persistence.** Ownership, slots and upgrade levels are saved through `ProfileGateway` since 2026-09-23 ([[Persistence and Saves]]).

## Extend it
- New weapon: give the Tool a `Category` and a `Price`; the shop picks it up with no shop code (this is how the Knife reached the shop). Reclassifying a category is a data change.
- Gamepass weapon: `Gamepass = "<key>"`, no `Price`, and a pass entry in `Monetization.Constants` ([[Gamepasses]]).
- A preview that shows upside down: set `ShopViewRotation` on the Tool rather than changing the shop's orientation code.

## Watch out
- A donor weapon's leftover `Price` makes a gamepass weapon cash-buyable; clear it.
- A weapon body built as a plain Part with a mesh child (not a MeshPart) mis-measures and frames wrong (the Baton, 2026-09-16).
- A single fixed preview rotation framed 12 of 17 weapons; orientation must stay per-weapon (the 2026-09-15 fixed-rotation entry is superseded).
- `WeaponaryShopGui` is `ZIndexBehavior.Global`; the Skins card lives in its own Sibling ScreenGui rather than flipping this one.
- `WeaponaryShopController` owns the shop's `UIScale` (opts out of `UIScaleController`) so it can budget room for the Skins card.
- Rounded corners do not clip; the panel clips its own contents.
- Hover growth needs gap room (the action button needed 18px, had 10).
- Respawn restore goes through the same path as a buy: the purchase sound is armed by the click, so a respawn handing back four weapons is silent.
- Aiming head-on at an enemy at chest height can hit the gun it holds (zero damage) — matters for tests.

## History
- 2026-09-25: the Gamepass panel's grid scrolls ([[Gamepasses]]). [[FPS-Gamepass-Shop-Scrolling-Grid]]
- 2026-09-24: buy goes straight to the slot picker; upgrades and re-views never do. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- 2026-09-24: Gamepass tab replaces All (last), shop opens on Melee, CLAIM · FREE flow; Gamepass tab logo. [[FPS-RPG-Gamepass-Launcher]] [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]]
- 2026-09-24: category tabs and spray badge become icons (white PNGs tinted to tab text colour). [[FPS-Weaponry-Category-Icons]]
- 2026-09-24: shop slides aside for the Skins card instead of shrinking; weapon level pill. [[FPS-Skins-Card-Shop-Slides-Aside]] [[FPS-Skins-Chip-Outline-And-Weapon-Level-Pill]] [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]]
- 2026-09-23: ownership, loadout slots and upgrade levels persist; `UpgradeRequest` gained an ownership guard. [[FPS-Persistence-Phase-3]]
- 2026-09-21: preview drops invisible geometry; melee stands upright. [[FPS-Melee-Shop-View-And-Bleed-Effect]]
- 2026-09-19: coin burst on spend replaces the red price label. [[Cash-Spend-Burst-Replaces-Price-Label]]
- 2026-09-18: grid overflow fixed (cells 120x148), upgrade cost under the viewport, melee hides Magazine; denied feedback, slot outlines; Cash chip in the title bar. [[FPS-Weapon-Grid-Overflow-And-Detail-Tweaks]] [[FPS-Shop-Polish-And-Denied-Feedback]] [[FPS-Figma-UI-Bugfix-Pass-4]]
- 2026-09-16: upgrade repaint race fixed, banknote symbol; +5 damage per level, slot pop, preview no longer resets; hover/click sounds; panel clips, Baton mesh rebuilt; permanent uncapped ownership with four loadout slots and an Equip button; eleven new guns. [[FPS-Upgrade-Realtime-Refresh-And-Cash-Emoji]] [[FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix]] [[FPS-Shop-Hover-Sound]] [[FPS-Shop-Overflow-Fixes]] [[FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots]] [[FPS-AK47-Display-Fix-11-New-Guns-Integration]]
- 2026-09-15: Weaponary shop replaces the 16 world pickups (archived to `ServerStorage.ArchivedWeaponPickups`); server-side ownership record, sorted grid, 3D preview, Owned tab, unsellable weapons listed, tab overflow fixed. [[FPS-Weaponary-Shop-Refactor]] [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]] [[FPS-Weaponary-Melee-Display-Fixes-And-Baton]] [[FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab]] [[FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes]]
- 2026-09-12: upgrade button red and taller. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: first damage upgrade (on world pickups' stat billboards). [[FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System]] [[FPS-Weapon-Pickups-And-Inventory-Integration]]

See [[Batch Log]].
