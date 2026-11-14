---
type: reference
tags: [regression, testing, checks]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/*.md (Verification sections)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/*.md", "CLAUDE.md (How to work in this project, rules 2 to 4; Known traps)"]
---

# Regression Suite

The checks to re-run after a change, by area, each one taken from a change log that verified it. The expected values are the ones the log measured. Open items are in [[Open Items]].

## How to check

- **Measure, don't trust the edit.** Reproduce with a number before the change and re-measure after; read back the property (`AbsolutePosition`, `AbsoluteSize`, `AbsoluteCanvasSize` for layout). (`CLAUDE.md`, rules 2 and 3)
- **Unit suites:** `ServerStorage.UnitTest.Cases.*`, run through `RunUnitTest` in a server VM during Play. `ServerScriptService.UnitTestRunner` is `Disabled` on purpose. Running in Edit gave "a false 127/132" once; calling a module's cached closure from `execute_luau` is not reliable. The filter is an unanchored substring match. Latest recorded totals: 145/145 ([[Revert-Global-Spraypaint-Balance]]) and 147/147 ([[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]), both 2026-09-24; their order that day is not recorded.
- **Real input path where it matters:** several fixes were only proven once driven by real clicks (HUD weaponry button -> card -> chip). Screen capture of a running game can come back blank; a viewport collapsed to 0 FPS stops tweens (an environment fault, not a code fault).
- **Robbery place** has its own spec suite: 594 passed, 14 known failures on 2026-09-20; a change should leave the same failure set. [[Getaway-Distance-Replaces-Claim-Zone]]

## Weapons and combat ([[Weapons and Blaster]], [[Melee]], [[Viewmodels and Weapon Animation]])
- [ ] Viewmodel hands on the weapon across all 28 viewmodels: worst gap 0.25 studs, mean 0.041. [[FPS-Viewmodel-Hands-Off-Weapon]]
- [ ] Linear easing: equal steps between keyframes; 28-rig smoke test with 0 errors. [[FPS-Viewmodel-Animation-Linear-Easing]]
- [ ] Exported clips match live motion within 0.00028 studs. [[FPS-Viewmodel-KeyframeSequence-Export]]
- [ ] Shotgun kill throws the body about 20 studs; a survivor does not move. [[FPS-Shotgun-Kill-Knockback]]
- [ ] Shot at a carried weapon damages the holder, both directions; a Baton swing lands first try for 45. [[FPS-Carried-Weapons-Absorbed-Hits]]
- [ ] Baton stagger: animation constraints 15/15 -> 0/15, back to 15/15 by about 1.3-1.4 s; an enemy killed mid-stagger stays down and is cleaned up. [[FPS-Baton-Stun-Becomes-A-Stagger]]
- [ ] Knife: swing 30, bleed 20, three quick cuts still total 20 bleed. Backstab from five angles against all 9 enemy types. [[FPS-Knife-Bleed-Melee]] [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- [ ] Missed shot tracer 150 studs, 0.75 s; hit tracers unchanged. [[FPS-Miss-Tracers-And-Spawn-Cap]]
- [ ] RPG: damage falls off correctly at 0, 6 and 12 studs; the killed are flung 800-827 studs; a crafted `BuyRequest` is refused; reload seats the rocket at 1.87 s with no hand gap. [[FPS-RPG-Gamepass-Launcher]] [[FPS-RPG-Reload-Hand-Carries-Rocket]]
- [ ] Pump fore-ends travel 0.55 studs per shot; pistol magazines drop 0.94-0.95 studs on reload. [[FPS-New-Guns-Magazines-And-Pump-Forends]]
- [ ] Melee hit effect skipped 400 studs from the camera; 20 simultaneous hits all cleaned up. [[FPS-Melee-Hit-And-LevelUp-VFX]]

## Shop, cash and cosmetics ([[Weapon Shop and Upgrades]], [[Economy and Cash]], [[Cosmetics and Skins]], [[Spraypaint]], [[Gamepasses]])
- [ ] Real clicks: BUY -> slot picker -> `LoadoutSlot2` set; UPGRADE opens no picker. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- [ ] An upgrade raises damage 45 -> 50, live. [[FPS-Upgrade-Realtime-Refresh-And-Cash-Emoji]]
- [ ] Grid stays inside its clip region (absolute positions); gamepass grid canvas 662 against a 438 window, scrolls. [[FPS-Weapon-Grid-Overflow-And-Detail-Tweaks]] [[FPS-Gamepass-Shop-Scrolling-Grid]]
- [ ] Preview framing by measured extents (Knife centre offset 0.0000). [[FPS-Melee-Shop-View-And-Bleed-Effect]]
- [ ] Purchase sound silent on a respawn that hands back 4 weapons. [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]]
- [ ] A 1500 spend throws 11 coins. [[Cash-Spend-Burst-Replaces-Price-Label]]
- [ ] Skins: the 8-row verification table, suites 10/10, 14/14, 11/11 in a fresh Play. [[FPS-Weapon-Skins-Phase-1]]
- [ ] Spraypaint: the 13-row table; a real Verdigris buy charges 700; minimum swatch distance test (52.8). [[FPS-Spraypaint-Phase-2]] [[Revert-Global-Spraypaint-Balance]] [[FPS-Skins-Card-Detached-And-Palette-Expansion]]
- [ ] `GamepassOwned_RPG` true at join via MarketplaceService; claiming leaves Cash unchanged. [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]]

## Progression and saves ([[Leveling and Renown]], [[Persistence and Saves]], [[Player Card]], [[Quests and Dialogue]])
- [ ] Every rank boundary (1/10/11/30/31/41/50/51/61/70) maps to the right rank; rank updates live on a level change. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- [ ] Level-up popup transparencies: rest 1, shown 0.2/0/0/0, hidden 1. Level-up effect: 11 emitters on at 0.8 s, off at 2.0 s, gone by 5.0 s. [[FPS-Player-Nameplates-And-LevelUp-Fix]] [[FPS-Melee-Hit-And-LevelUp-VFX]]
- [ ] Persistence: the 13-row round-trip table through the game's own remotes; a failed load leaves the stored profile byte-identical; computed values (`NextLevelXP`, `SkinId`, damage, catalogue, `lastLevel`) never stored; migration from an unversioned profile; non-contiguous loadout slots survive; ProfileStore required in one place only. [[FPS-Persistence-Phase-3]]
- [ ] Player card readback `HEALTH 100/100`, `XP 0/30`, `CASH 10,000`; rank CAPO at level 51. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- [ ] Quest log does not scroll sideways (canvas 380 in a 380 window); all nine reply rows have number badges. [[FPS-Quest-Overflow-And-Dead-Code-Removal]]
- [ ] Quest givers' outfits stay attached (2.0-3.1 studs from the head), 0 errors. [[FPS-Quest-Givers-Law-Enforcement-Outfits]]

## UI shell ([[HUD and UI Shell]], [[Notifications]], [[Death Screen]], [[Inventory and Hotbar]], [[Nameplates and Billboards]], [[Camera Authority]])
- [ ] `weaponaryButton` opens only that panel and hides `Custom Inventory`, `LevelingGui`, `StaminaGui`; X restores them. [[FPS-Figma-UI-Bugfix-Pass-3]]
- [ ] Close X grows 36 -> 39.6 on hover, one sound each for hover and click (both places). [[Close-Button-Unified-With-Robbery]] [[Close-Button-Unified-With-FPS]]
- [ ] Death: only `DeathScreenGui` enabled; after respawn the HUD is back and `AdminLevelGui`, `BlasterGui`, `BlasterTouchGui`, `ReticleGui` stay disabled; banner, phrase and countdown share the viewport centre (0.00 px spread); `GroupTransparency` reaches 0 in about 0.5 s. [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]] [[FPS-Death-Screen-You-Died-And-Alignment]]
- [ ] Notifications: card 280x64 at `UIScale` 1 (280x84 with the detail line, 14x14 icons); 3-card stack dims 0/0.3/0.6; four rapid gains leave exactly 3 cards; 12 gains with the shop open give 0 cards, then 8 flush in order about 0.12 s apart on close; the card's text is visible on a screen capture. [[Notification-Card-Fix-And-Weapon-HUD-Move]] [[Notification-Queue-While-Panel-Open]] [[Notification-Blank-Card-ZIndexBehavior]] [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]]
- [ ] Inventory with real pointer input: `HoverOutline` 0 on hover, 1 on leave; a click equips and plays its sound. Loadout slots: no highlight outside pick mode, only the hovered slot inside it, cleared after a pick. [[FPS-Inventory-Slot-Click-Sound-And-Hover-Outline]] [[FPS-Loadout-Slot-Hover-Outline]]
- [ ] Nameplates: 15 spawned enemies all show their real type; own plate absent. [[FPS-Figma-UI-Bugfix-Pass-5]] [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]]
- [ ] Camera: sprint-jump-land roll at most 0.1 deg on touchdown and 0 after; `PropertyAuthority_Test` 8/8. [[FPS-Landing-Jolt-Root-Cause]] [[FPS-Persistence-Phase-3]]

## World and NPCs ([[Enemies and Spawner]], [[Movement and Stamina]])
- [ ] After about 60 s: 30 enemies alive, 5 per spawn point. [[FPS-Miss-Tracers-And-Spawn-Cap]]
- [ ] 18 rigs: nearest neighbours average about 43 studs, closest pair 11.58. [[Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip]]
- [ ] 60 rigs: no enemy rises more than 0.3 studs. [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]
- [ ] 7 thugs around a standing player: 7 of 7 attack; a wall blocks, an ally does not. [[FPS-Clustered-Enemies-Stop-Attacking]]
- [ ] A stunned enemy resumes automatic fire within 3 s. [[FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes]]
- [ ] Landing: `WalkSpeed` held at 0 for about 0.12 s, back to 20 by about 0.5 s. [[FPS-All-Landings-Dead-Stop]]
- [ ] Fall and climb tracks have real lengths and play in their states. [[FPS-Fall-Animation-Dead-Asset]]
- [ ] Stamina bar and its outline fully transparent when idle. [[FPS-Figma-UI-Bugfix-Pass]]

## Robbery place ([[Robbery Prompts]], [[Robbery Heists and Getaway]], [[Robbery Puzzles]])
- [ ] Prompt fill rises linearly 0 / 9.8 / 19.7 / 29.5 / 39.4 px at progress 0 / .25 / .5 / .75 / 1; hover grows it to 1.07; disabling a shown prompt closes its face. FPS and Robbery `PromptUI` checksums match. [[Prompt-Liquid-Fill-And-Animations]] [[Prompt-Liquid-Shape-And-Hover-Lift]] [[Prompt-Closes-When-Disabled]]
- [ ] Getaway at all four locations: no payout at 199 studs, payout at about 204; a full Bank bag in the vault 313 studs out is not paid; death and the timer both lose the bag. [[Getaway-Distance-Replaces-Claim-Zone]]
- [ ] Supplier with real mouse clicks: the sell answer returns in 0.1 s, the toast stays about 2.98 s. [[Supplier-Billboard-Input-And-Toast-Duration]]
