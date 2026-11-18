---
type: system
tags: [system, monetisation, gamepass, fps]
updated: 2026-11-18
sources: ["CrimeLifeRoblox/docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Monetization-Cosmetics-Spec.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Gamepass-Shop-Scrolling-Grid.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Polish-And-Denied-Feedback.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-6-report.md", ".superpowers/sdd/2026-11-18-open-items-pass/progress.md"]
---

# Gamepasses

**Skills:** `roblox-monetization`, `roblox-ui`, `roblox-security` (load these for work here)

## What it does
Robux sales in the FPS place: game passes shown in the Gamepasses panel, and developer products that sell Cash (the Cash Shop, see [[Economy and Cash]]). The one pass with real in-game wiring recorded in the change logs is **RPG**, which unlocks the RPG launcher in the Weaponary's Gamepass tab ([[Weapon Shop and Upgrades]], [[Weapons and Blaster]]).

## Where it lives
- `ReplicatedStorage.Monetization` (with `Constants`: `Gamepasses` list, `isConfigured`, `ownedAttributeFor`) and `ServerScriptService.Monetization` (MonetizationService). Both predate the cosmetics work (found already present on 2026-09-22).
- Panel: `ReplicatedStorage.GuiTemplates.GamepassShop` (`Grid` is a ScrollingFrame since 2026-09-25), driven by `GamepassShopController`; ScreenGui `GamepassShopGui`.
- A `PromptGamepassPurchase` remote is named in the cosmetics design as the existing prompt route.
- No repo copy of the Monetization scripts exists under `CrimeLifeRoblox/FPSSystem/`.

## How it works
- **Passes** (`Monetization.Constants.Gamepasses`, seven entries): `DoubleCash`, `DoubleXp`, `Vip` ("Exclusive weapon skins"), `ExtraSlot`, `FastReload` ("25% quicker reloads"), `InfiniteSprint`, and `RPG` (R$499, added 2026-09-24). What `DoubleCash`, `DoubleXp`, `ExtraSlot`, `FastReload` and `InfiniteSprint` grant in play is not recorded in any change log.
- **Ids.** Every pass id is a placeholder `0` except RPG, which uses `10904398` — a stand-in pass the developer owns ("MINOR ADMIN"), set so the unlock runs through the real `MarketplaceService` check at join. It must be replaced with the real RPG pass id in production.
- **Unconfigured handling.** `Constants.isConfigured()` is false for id 0: the tile reads COMING SOON, is disabled and never prompts, rather than calling `MarketplaceService` with a bad id.
- **Ownership** is a player attribute `GamepassOwned_<key>` (mirrors `UpgradeConfig.ownedAttributeFor`), set from MarketplaceService at join. Server checks it (e.g. `BuyRequest` for a gamepass weapon costs 0 and needs the attribute). A pass bought mid-session flips the Weaponary panel live.
- **Owned tile:** whole-tile acid 2px stroke and "OWNED". Written 2026-09-18; seen working on the RPG card on 2026-09-25.
- **Vip** no longer grants anything: its skins were moved to Spraypaint ("Vip is on hold", [[Cosmetics and Skins]]). It still advertises "Exclusive weapon skins".
- **Developer products:** six Cash tiers, 5,000 to 1,000,000 Cash, granted straight into `leaderstats.Cash`; `Cash100K` is the best-value tier.

## One ownership path (2026-11-18)
- **`ServerScriptService.Monetization.Scripts.PassOwnership`** is the one ownership path for every pass. The player attribute `GamepassOwned_<key>` is the only record (no table cache; it leaves with the Player, so a leaver leaves nothing). `publish(player)` at join checks a configured pass (pcalled); an id of `0` is "not configured": set false, never prompts, no web call. A failed check reads false and is asked again after 30 s (`FAILED_CHECK_RETRY_SECONDS`), never on a read; a stale false never overwrites a true.
- **One purchase confirm for every pass.** `onPurchaseFinished(player, id, purchased)` sets the attribute only after `UserOwnsGamePassAsync` agrees (`CONFIRM_ATTEMPTS` 3, `CONFIRM_RETRY_SECONDS` 2, off the event thread, stops if the player left). An event for id 0 or for an id outside the pass list matches nothing and makes no call; an owned or in-flight event makes no web call; one pending retry per player and pass; `PassOwnership.forget` on `PlayerRemoving`. Before, the city handler set true on the event alone and matched an id-0 event to `DoubleCash`.
- **The heist duffel passes live here too.** `DuffelCapacityX2`, `DuffelCapacityX4` and `DuffelSpeedBoost` are entries in `Monetization.Constants.Gamepasses` with `shop = false` (id `0`, never shown; `GamepassShopController` skips them, the panel stays 7 tiles). **Paste each real id in `ReplicatedStorage.Monetization.Constants.Gamepasses` and nowhere else** (RPG's stand-in 10904398 is still to swap). `SharedSystems.GamepassManager` is now a thin adapter: multipliers by pass key, `PlayerOwnsGamepass` reads the attribute (x4 first, no stacking); no ids, cache or network.
- The duffel dialog's X2 / X4 buttons fire `Monetization.Remotes.PromptGamepassPurchase` with the pass key; the server prompts only a configured id (an unconfigured one logs "has no id configured yet" and does nothing). Specs: `ServerStorage.UnitTest.Cases.PassOwnership_Test` (city) and the heist suite's `GamepassManager` spec.

## Extend it
- New pass: add an entry to `Monetization.Constants.Gamepasses`; the panel grid scrolls, so more passes just add rows.
- New gamepass weapon: Tool attribute `Gamepass = "<key>"`, no `Price` ([[Weapon Shop and Upgrades]]).
- Real ids drop in as config; no code change is needed for the tile to start prompting.

## Watch out
- **Not pay-to-win-free.** The original spec's "no Robux->Cash ever" guarantee was struck on 2026-09-22: Cash products, `DoubleXp`, `FastReload` and `InfiniteSprint` were kept by the developer's call. Cosmetics data is still kept out of `ShotResolver` and `WeaponUpgradeService`.
- The spec's rules (not verified as implemented): cache pass ownership once per player at join and on `PromptGamePassPurchaseFinished`, never in a hot path; one `ProcessReceipt` handler only, returning `PurchaseGranted` only after the grant is saved.
- A ScreenGui Frame neither clips nor scrolls: the seventh pass drew below the panel until the grid became a ScrollingFrame.
- Server-applied knockback from a gamepass weapon may land softer on another player (client-owned physics); not verified.

## History
- 2026-11-18: one ownership path (`PassOwnership`, one confirm by `UserOwnsGamePassAsync`, id 0 means not configured), duffel x2 / x4 and `DuffelSpeedBoost` as `shop = false` entries, `GamepassManager` a thin adapter; join readings unchanged (RPG OWNED, six COMING SOON, 7 tiles); city 315 / 315 and heist 740 / 0 at the close. [[2026-11-18 Open Items Pass]]
- 2026-09-25: Gamepasses grid scrolls (canvas 662 px vs 438 px window); column padding 12 -> 10. [[FPS-Gamepass-Shop-Scrolling-Grid]]
- 2026-09-24: Vip on hold, its skins sold for Spraypaint. [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]
- 2026-09-24: RPG pass uses stand-in id 10904398 for testing; Gamepass tab logo. [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]]
- 2026-09-24: RPG gamepass (R$499, id 0), Weaponary Gamepass tab, CLAIM · FREE. [[FPS-RPG-Gamepass-Launcher]]
- 2026-09-23: Vip gating for three palettes (Gold, Obsidian, Arctic) shipped in skins Phase 1. [[FPS-Weapon-Skins-Phase-1]]
- 2026-09-22: existing Monetization found; P2W guarantee dropped. [[FPS-Monetization-Cosmetics-Spec]]
- 2026-09-19: banner plate re-centred on the Gamepass Shop. [[FPS-Banner-Title-Centring-And-UI-Fades]]
- 2026-09-18: owned-tile highlight written, blocked on placeholder ids. [[FPS-Shop-Polish-And-Denied-Feedback]]

See [[Batch Log]].
