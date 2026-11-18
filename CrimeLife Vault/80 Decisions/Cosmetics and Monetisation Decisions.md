---
type: decision
tags: [decision, monetisation, cosmetics, spraypaint, gamepass]
updated: 2026-11-18
sources: ["CrimeLifeRoblox/docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-renown-phase-2-design.md", "CrimeLifeRoblox/.superpowers/sdd/2026-09-23-renown-phase-2/spraypaint-rename-report.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Monetization-Cosmetics-Spec.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Per-Weapon-Spraypaint.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Revert-Global-Spraypaint-Balance.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Shop-Slides-Aside.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Timer-Hourglass-And-Duffel-Upgrade-GUI.md"]
---

# Cosmetics and Monetisation Decisions

Calls about Robux, gamepasses, skins and Spraypaint. The code is in [[Gamepasses]], [[Cosmetics and Skins]] and [[Spraypaint]].

## Newest first

- **2026-11-18: one gamepass system.** The heist duffel x2 / x4 passes fold into the city's `MonetizationService`; `GamepassManager` stops keeping its own cache. [[2026-11-18 Open Items Pass]]
- **2026-11-18: locked Spraypaint chips ask "Buy for N?"** before the second click buys. The two-click preview already existed (since 2026-09-24); the confirm wording and a 4 s timeout were added, and the timeout never ends the 3D preview. [[2026-11-18 Open Items Pass]]
- **2026-11-18: Spraypaint skin prices stay until a playtest** (Nebula 8,200, about 4,100 Criminal kills). [[2026-11-18 Open Items Pass]]
- **2026-11-18: the Vip pass text stays as it is** ("Exclusive weapon skins") while Vip is on hold. [[2026-11-18 Open Items Pass]]
- **2026-09-24: the RPG pass is R$499**, running on stand-in pass id 10904398 (a pass the developer owns) so the unlock goes through the real `MarketplaceService` check; it must be swapped for the real pass. [[FPS-RPG-Gamepass-Launcher]] [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]]
- **2026-09-24: "Vip is on hold."** Its four skins are sold for Spraypaint (5200 to 8200). [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]
- **2026-09-24: the shop slides aside instead of shrinking** when the Skins card opens, after the report "when I click the weapon card, it then suddenly becomes small". [[FPS-Skins-Card-Shop-Slides-Aside]]
- **2026-09-24: the palette catalogue grows from 12 to 20**; a locked Spraypaint chip buys without a confirm step (the log flags this as a judgement call; see [[Open Items]]). [[FPS-Skins-Card-Detached-And-Palette-Expansion]]
- **2026-09-24: Spraypaint went per-weapon, then back to one global balance the same day**, and skin prices rose: Cobalt 500, Verdigris 700, Ember 900, RoseGold 1200. [[Per-Weapon-Spraypaint]] [[Revert-Global-Spraypaint-Balance]]
- **2026-09-23: "Renown" is renamed Spraypaint.** (`.superpowers/sdd/2026-09-23-renown-phase-2/spraypaint-rename-report.md`) Spec: Spraypaint buys a third tier of skins and never unlocks Vip palettes; the spend surface reuses the skins row, no new panel. (`docs/superpowers/specs/2026-09-23-renown-phase-2-design.md`)
- **2026-09-22: keep the existing Robux surfaces, drop the non-pay-to-win guarantee.** The six Robux-for-Cash products and the DoubleXp, FastReload and InfiniteSprint passes stay; the trade "was put to the owner and this is the answer they gave". The `Cosmetics` namespace is still kept out of `ShotResolver` and `WeaponUpgradeService`. (`docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md`, [[FPS-Monetization-Cosmetics-Spec]])
- **2026-09-22: Phase 1 skins are tint only, as universal palettes**, browsed in a skins row in the weapon's detail panel; real pass ids drop in as config (every id was 0 and the place unpublished). (same spec)
- **2026-09-12 (Robbery): the x2 and x4 duffel upgrades are gamepasses** sold through the existing `GamepassManager`, not a second economy. [[Timer-Hourglass-And-Duffel-Upgrade-GUI]]
