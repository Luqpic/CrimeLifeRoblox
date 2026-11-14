---
type: system
tags: [system, economy, cash, fps, robbery]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/Weapons/CashService.luau", "CrimeLifeRoblox/FPSSystem/UI/CashBurst.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Billboard-Scale-And-Cash-Drop-System.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Cash-Spend-Burst-Replaces-Price-Label.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-4.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Cash-Burst-Emitter-Icon.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md", "CLAUDE.md (Systems: Economy)"]
---

# Economy and Cash

**Skills:** `roblox-game-systems`, `roblox-data-stores`, `roblox-security` (load these for work here)

## What it does
Cash is the combat currency in the FPS place: earned from enemy cash drops, level-ups, quest rewards and Robux products, spent on weapons and damage upgrades ([[Weapon Shop and Upgrades]]). It shows on the leaderboard. Earning and spending have matching coin animations. In the Robbery place cash is banked by robberies ([[Robbery Heists and Getaway]]) and shares the same coin art. Cosmetics use a separate currency, [[Spraypaint]].

## Where it lives
- `ServerScriptService.Weapons.Scripts.CashService` (leaderstats, starting cash, drops, pickup, persistence mirror). Repo: `CrimeLifeRoblox/FPSSystem/Weapons/CashService.luau`.
- `leaderstats.Cash` (IntValue) — the one cash figure.
- `ServerStorage.Cash` — drop clone source (PrimaryPart + WeldConstraint); live drops parent to `Workspace.CashDrops`.
- `ReplicatedStorage.UI.CashBurst` — `burstFrom(origin, amount, style?)`. Repo: `CrimeLifeRoblox/FPSSystem/UI/CashBurst.luau`.
- Cash readouts: HUD, Cash Shop balance pill (`CashShopController.bindBalance`), Weaponary `TitleBar.CashChip`, Player Card `CashRow` ([[Player Card]]).
- Cash Shop: `CashShop` panel, `CashShopController`, products in `ReplicatedStorage.Monetization` ([[Gamepasses]]).
- Robbery place: `SharedSystems.CashClaimVFX` (screen-space inbound coins), `SharedSystems.RobbableObject:_playCashBurst` (world-space `CashBurstEmitter` per robbable object), coin art `UITheme.Assets.Coin`.

## How it works
- **Start.** New players get `STARTING_CASH`, read from `Schema.template.cash` (500), so the two cannot drift. A returning player is restored from the profile instead (persisted since 2026-09-23, [[Persistence and Saves]]).
- **Drops.** On an NPC kill, 30% chance (`DROP_CHANCE = 0.3`) to drop a physical cash pickup. Value by the dead enemy's weapon class: Melee 20, Pistol 35, AutoRifle 50. Collected through a prompt (8 studs), plays a collect sound, despawns after 10 s with a shrink/fade. PvP kills pay no cash. Drop chance and values were set as placeholders "to be tuned by playtesting".
- **Other grants.** Level-up bonus (`LevelingConstants.CASH_PER_LEVEL_UP`; the value lives in `ReplicatedStorage.Leveling.Constants`, not mirrored to the repo), quest hand-in rewards ([[Quests and Dialogue]]), Cash Shop products (six tiers, 5,000 to 1,000,000 Cash for Robux; `Cash100K` is outlined as best value).
- **Spending.** Weapon prices and `UpgradeConfig.COST_PER_LEVEL` x next level, validated on the server; the client pre-checks and flashes "denied" ([[Weapon Shop and Upgrades]]).
- **Persistence.** One `GetPropertyChangedSignal("Value")` listener on `leaderstats.Cash` mirrors every writer (pickup, level-up, shop, upgrades, quests, monetisation) into the profile.
- **Spend feedback.** `CashBurst` throws 8-20 coins (scaled by amount; 11 for a 1500 spend) from the clicked button's centre, scattering and fading. Each call owns and destroys its own overlay. Optional style (image, colour, size) is used for the spray-can burst.
- **Earn feedback.** Robbery's `CashClaimVFX` flies coins into the cash HUD as the counter ticks — the deliberate mirror of the FPS spend burst, same coin slice.
- No lifetime-earnings figure exists; every "cash" display is the current balance.

## Extend it
- New cash source: write to `leaderstats.Cash` on the server; persistence picks it up automatically through the Value listener.
- Retune drops: `DROP_CHANCE` / `CASH_VALUES` / `DESPAWN_TIME` at the top of `CashService`.
- A lifetime total would need a second stat incremented at every grant site and persisted (offered on 2026-09-18, not built).

## Watch out
- Robux buys Cash (and Cash buys damage): the original non-pay-to-win guarantee was dropped on 2026-09-22 by the developer's call. There is no Cash <-> Spraypaint exchange.
- `AbsolutePosition` sits below the top-bar inset while the burst overlay ignores it; `CashBurst` adds the inset back (otherwise ~36 px high).
- TweenService is render-driven; with the Studio viewport collapsed the burst does not animate (environmental, not a bug).
- Robbery had two independent cash bursts; updating the module did not update the 19 pre-placed `CashBurstEmitter` textures. Anything authored per object needs its own sweep.
- Robbery's `CashClaimVFX` unit tests fail (a lazy `require` inside `_buildPersistentGui` after the test runner destroys its clone); the live game is unaffected. Recorded on 2026-09-20, not fixed.
- Leaderstats setup once depended on service init order; `CashService` is now robust to either order.

## History
- 2026-09-24: `CashBurst` takes an optional style (spray-can burst for skins). [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]
- 2026-09-23: cash persists through `ProfileGateway`; starting cash read from the schema (500). [[FPS-Persistence-Phase-3]]
- 2026-09-22: existing Cash-for-Robux products found and kept. [[FPS-Monetization-Cosmetics-Spec]]
- 2026-09-20 (Robbery): cash banks by getaway distance; `CashClaimVFX` test failures recorded. [[Getaway-Distance-Replaces-Claim-Zone]]
- 2026-09-19: spending throws a coin burst (`UI.CashBurst`), replacing the red "-1500" label. [[Cash-Spend-Burst-Replaces-Price-Label]]
- 2026-09-19 (Robbery): robbable objects' world bursts use the real coin icon. [[Cash-Burst-Emitter-Icon]]
- 2026-09-18: Cash chip in the Weaponary title bar; Player Card cash pill shows current balance. [[FPS-Figma-UI-Bugfix-Pass-4]]
- 2026-09-18: Cash Shop balance pill and tier icons fixed. [[FPS-Figma-UI-Bugfix-Pass-2]]
- 2026-09-18: best-value Cash tier outlined. [[FPS-Shop-Polish-And-Denied-Feedback]]
- 2026-09-16: shop money symbol becomes a banknote. [[FPS-Upgrade-Realtime-Refresh-And-Cash-Emoji]]
- 2026-09-13 (Robbery): persistent cash card restyle drafted. [[Post-Move-Fixes-And-GUI-Polish]]
- 2026-09-12: cash pickup sound volume raised. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: cash pickups play a sound. [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]]
- 2026-09-11: flat +50 per kill replaced by tiered 30% cash drops. [[FPS-Billboard-Scale-And-Cash-Drop-System]]
- 2026-09-11: Cash introduced (`CashService`, leaderstats); level-up cash bonus; init-order fix. [[FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System]] [[FPS-Kill-Leveling-System]]

See [[Batch Log]].
