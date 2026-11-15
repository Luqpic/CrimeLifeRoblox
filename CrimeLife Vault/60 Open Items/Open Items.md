---
type: open
tags: [open-items, bugs, watch-list]
updated: 2026-11-15
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/*.md (Status lines and Notes)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/*.md (Status lines and Notes)", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-renown-phase-2-design.md"]
---

# Open Items

Harvested on 2026-11-14 (city items added the same day; 2026-11-15 items from [[2026-11-15 FPS Systems Into City]] added) from every change log whose `Status:` or Notes say not verified, needs a person, follow-up or later. Each item names its source; the date is the source's date. When an item closes, remove it here and say so in the batch note. Systems: [[Systems MOC]]. How to re-check: [[Regression Suite]].

## Needs the developer

### Publish, save and ids
- **Save the place.** The 2026-09-24 and 2026-09-25 changes were made live and the logs say the place was not saved to disk by them. [[FPS-Eight-New-Pistols-And-Shotguns]] [[FPS-RPG-Reload-Hand-Carries-Rocket]]
- **Real gamepass ids.** Every FPS pass id is a placeholder `0` except RPG, which runs on stand-in pass 10904398 and must be swapped for the real RPG pass (2026-09-24). The owned-tile highlight needs real ids too (2026-09-18). [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]] [[FPS-Shop-Polish-And-Denied-Feedback]] -> [[Gamepasses]]
- **Robbery: create the x2 and x4 duffel gamepasses** (ids still `0`, 2026-09-12). [[Timer-Hourglass-And-Duffel-Upgrade-GUI]]
- **Vip pass still advertises "Exclusive weapon skins" but grants nothing** while Vip is on hold: update or disable it before selling (2026-09-24). [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]
- **Publish the 49 viewmodel KeyframeSequences**: the Studio tooling cannot upload animations (2026-09-20). [[FPS-Viewmodel-KeyframeSequence-Export]]
- **Upload icons for the eight new guns** (2026-09-24). [[FPS-Eight-New-Pistols-And-Shotguns]]
- **Share the sound assets that fail "not authorized"** in the Creator Dashboard: about 9 weapon sounds (2026-09-18) and about 10 sounds (2026-09-24); the logs do not say whether these overlap. [[FPS-Figma-1to1-Image-Export-And-Font-Fix]] [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]

### City map (2026-11-14)
- **Set `Workspace.ModelStreamingBehavior` to `Legacy`** in the Properties panel: it is not scriptable, so it is not confirmed (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Agree or change the provisional performance targets** in `CityCleanup/baseline-2026-11-14.md` (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Look at the city under streaming on a real phone** and name any far landmark that must stay visible; with a 512 target radius only 1 of the 6 robbery buildings is loaded at spawn (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Decide lighting and time of day** from `ServerStorage.CityQuarantine.Scripts` (8 scripts, disabled) (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Decide the fate of `CityQuarantine.Duplicates`, `LooseTycoon` and `StagingSlab`.** `StagingSlab` holds `UnderGroundCasino` and `WareHouseP2`, which look like the underground halves of the casino and warehouse robberies (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **`Workspace.Map.Loose` still holds 213 unsorted pieces**, including 138 unnamed Models (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Two spare slab plates (`Plot7`, `Plot8`) and the origin Baseplate are still in the place**; decide whether the slab stays (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Heaviest remaining models**, the candidates for a later simplification pass (2026-11-14). Workspace is 118,679 instances against a target of <= 163,700, so this is not a miss; the six robbery buildings alone are about 83,419 instances and the warehouse about 56,000. From the after-task3 probe, less the models quarantined since ([[2026-11-14 City Baseline and Cleanup]]):
  1. `Map.Robbery.WareHouseRobbery(NotUnderGroundPart)` 56,397
  2. `Map.City` 25,554 (a container)
  3. `Map.City.Buildings` 13,465
  4. `Map.City.nature` 6,935
  5. `Map.Robbery.NewsStation` 6,434
  6. `Map.Robbery.Gas2Go` 6,407
  7. `Map.Robbery.SlowFoods` 6,399
  8. `Gas2Go.BuildingGasStation` 5,468
  9. `NewsStation.Model` 4,950
  10. `Map.Robbery.Bank` 3,891 (tied with `CasinoMain` 3,891)
  The last probe prints only the containers, so these counts are the last per-model figures measured (after Task 3), not a fresh read.

### City and the FPS port (2026-11-15)
- **Re-place the six enemy points and six quest givers by hand.** Their positions are provisional (placed by rules, not by eye; no screenshot could be taken). Old CFrames are in `CityMerge/placement.md`. [[2026-11-15 FPS Systems Into City]] -> [[City Map and Plots]]
- **One Thug is stuck at about (215, 5, 2485)** against `Building_15` at the short east road end: the east arm has valid road only from 180 to 220 studs. Move the Thug point or shorten its reach. [[2026-11-15 FPS Systems Into City]] -> [[Enemies and Spawner]]
- **Decide whether the city's 26 leftover prompts get the FPS prompt style.** `PromptUiController` forces every prompt to `Custom` and would restyle them as they stream in; untouched, and the script is shared with the Robbery place. [[2026-11-15 FPS Systems Into City]]
- **About 79 asset-permission warnings per Play** from MeshIds in `Workspace.TycoonPreview` and `ServerStorage.HQ` (Test30.4 assets on an unpublished local file): share the assets or replace the meshes. [[2026-11-15 FPS Systems Into City]]
- **`ServerStorage.CityQuarantine.LooseTycoon.TycoonSpawn` is an enabled `SpawnLocation`.** Inert in `ServerStorage`; disable it before anything from `LooseTycoon` is moved back into `Workspace`. [[2026-11-15 FPS Systems Into City]]
- **`Documents/Roblox/CLAUDE.md` still names FPS System as the primary place.** It is the developer's file: one line to change (the primary place is now Crimelife City, [[Which Project This Is]]). [[2026-11-15 FPS Systems Into City]]
- **Checks that need a person at the keyboard in the city:** how shooting feels, pressing E on a quest giver, the weapon shop by real clicks, a phone, two players. [[2026-11-15 FPS Systems Into City]]
- **Walk the `TycoonPreview`.** Its fit on `Plot3` was checked by one screenshot and bounding numbers only. [[2026-11-15 FPS Systems Into City]]
- **Phase 2b carries three items listed below**: the remote ownership audit, the eleven `ZIndexBehavior.Global` ScreenGuis, and quest progress not being saved (see "Documentation drift"). Its plan is to be written from `CityMerge/first-run.md`. [[2026-11-15 FPS Systems Into City]]

### Product calls waiting
- **Price curve.** Nebula at 8200 Spraypaint is about 4,100 Criminal kills; re-size it (2026-09-24). Upgrade, cash-drop and Spraypaint rates are all placeholders (2026-09-16, 2026-09-23). [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]] [[FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix]] -> [[Spraypaint]]
- **Bring back a buy confirm step** for locked Spraypaint chips? (2026-09-24) [[FPS-Skins-Card-Detached-And-Palette-Expansion]]
- **A lifetime "cash earned" stat** for the player card was offered and never answered; the pill shows the current balance (2026-09-18). [[FPS-Figma-UI-Bugfix-Pass-4]]
- **Is the APS meant to be the rifle or the machine pistol?** (2026-09-16) [[FPS-AK47-Display-Fix-11-New-Guns-Integration]]
- **Delete `Workspace."UI Animation Pack - by JakeDev"`** (166 instances, replicates to every client)? (2026-09-18) [[FPS-Quest-Overflow-And-Dead-Code-Removal]]
- **Delete leftovers:** the Workspace blood particle, `LevelUpShine`, the unwired `Hiteffect` (2026-09-19, 2026-09-21). [[FPS-Melee-Hit-And-LevelUp-VFX]] [[FPS-Melee-Shop-View-And-Bleed-Effect]]
- **Were the original fall and climb animations custom work** that needs re-uploading? (2026-09-19) [[FPS-Fall-Animation-Dead-Asset]]
- **Kicked-player message** on a failed profile load: the design assumes a specific message; generic vs specific is a product call (2026-09-23). (`docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md`)
- **Three enemy outfit pieces could not be sourced** (a hi-vis vest, a second vest, duty belts) (2026-09-16). [[FPS-Enemy-Marketplace-Outfits]]

### Needs a person in a running game
- **Press E on a quest giver** (automated input could not trigger the prompt) (2026-09-24); **click a reply** in an FPS quest conversation (2026-09-16). [[FPS-Quest-Givers-Law-Enforcement-Outfits]] [[FPS-Dialogue-Responses-Clickable-Fix]]
- **Try `/setlevel` and the F2 admin panel**; move the five newer quest givers off their temporary line (2026-09-16). [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]]
- **Two-player test:** nameplates at distance, the View Card prompt round trip, a possible double name above players, prompts toggling while a panel is open, the overhead plate seen by a second player (2026-09-18, 2026-09-24). [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]] [[FPS-Player-Nameplates-And-LevelUp-Fix]] [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- **Persistence on a published place** (2026-09-23): saves surviving a real server restart, locking across two servers, the 30 s load deadline and the cancel when a player leaves mid-load (never run), the kick on a failed load (half verified), and someone watching the first published session. Proven so far only against the mock store. [[FPS-Persistence-Phase-3]]
- **Feel and look of the new guns**: firing, reload and aim feel, third-person hold, mid-reload look (2026-09-24); how the 2026-09-15 guns look in game. [[FPS-Eight-New-Pistols-And-Shotguns]] [[FPS-New-Guns-Magazines-And-Pump-Forends]] [[FPS-Loadout-Expansion-10-New-Guns]] [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]]
- **Eye checks:** the Knife's blade roll, third-person hold and bleed number (2026-09-21); the melee swing from a real click (2026-09-20); the melee hit effect and the level-up burst in motion, and whether the level-up light reads as a flashbang up close (2026-09-19); the death screen (2026-09-19); the new prompt in the FPS place (2026-09-19); the cash-spend burst animation (2026-09-19); the Acid skin ring (2026-09-23). [[FPS-Knife-Bleed-Melee]] [[FPS-Melee-Viewmodel-Swing]] [[FPS-Melee-Hit-And-LevelUp-VFX]] [[FPS-Death-Screen-You-Died-And-Alignment]] [[Figma-ProximityPrompt-Redesign]] [[Cash-Spend-Burst-Replaces-Price-Label]] [[FPS-Weapon-Skins-Phase-1]]
- **Ear check:** equip-sound volume (2026-09-19). [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]
- **Robbery getaway** (2026-09-20): walk a Bank escape on foot from the vault, look at the getaway widget on screen, test with more than one player, check cash survives a rejoin (every save returned 403 in testing), tune the 200-stud distance. [[Getaway-Distance-Replaces-Claim-Zone]]
- **Robbery: confirm the duffel-move fixes ran** (the log says drafted only, 2026-09-13) and verify Parts 0 and 2 to 4 of the performance pass (only Part 1 confirmed, 2026-09-12). [[Post-Move-Fixes-And-GUI-Polish]] [[Performance-Optimization-And-Unification]]

## Open bugs

- **Lean/Turning is switched off, not fixed** (2026-09-11); the Lean script still errors at line 25 (2026-09-24) in the frozen FPS place. **Fixed in the city on 2026-11-15** (`WaitForChild` on the three lookups, [[2026-11-15 FPS Systems Into City]]), but line 41 `lowerTorso.Root` is still a direct index in both places. [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]] [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- **`Crouching` line 250 references `workspace.FX`**, which does not exist in either place (`dust.Parent = workspace.FX`; not reached in the runs); `ServerScriptService.WeaponAnimationPreview` waits forever on `Workspace.WeaponAnimationPreview`, absent in both places, so every Play logs an infinite-yield warning (2026-11-15). [[2026-11-15 FPS Systems Into City]]
- **Third-person `MuzzleAttachment` sits at the stock end** on the Glock 17, Benelli M4 and Spas 12 (2026-09-24). [[FPS-Eight-New-Pistols-And-Shotguns]]
- **Mossberg 590 and Spas 12 fore-ends do not move** (2026-09-24). [[FPS-New-Guns-Magazines-And-Pump-Forends]]
- **The RPG still plays Roblox's own explosion bang** under its impact sound; the RPG grid card still reads "GAMEPASS" once owned (2026-09-24). [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]]
- **No "shot denied" feedback during a weapon's cooldown** (2026-09-11). [[FPS-Loadout-Bugfixes-Sounds-VFX]]
- **The ammo HUD shows a static "reloading"** through the shotgun's shell-by-shell reload (2026-09-11). [[FPS-Melee-Combo-And-Shotgun-Reload-Refactor]]
- **Eleven ScreenGuis are still `ZIndexBehavior.Global`**, each one per-element `ZIndex` away from a blank card (2026-09-24). [[Notification-Blank-Card-ZIndexBehavior]]
- **`IndicatorClient`'s `OverheadGui` and `PlayerNameplates` may both draw a name** in multiplayer (2026-09-18). [[FPS-Quest-Overflow-And-Dead-Code-Removal]]
- **The weapon `Description` attribute is unset**, so that line renders empty (2026-09-18). [[FPS-Figma-UI-Bugfix-Pass-2]]
- **`SpraypaintHud` can show a spurious toast at join** (2026-09-24). [[Per-Weapon-Spraypaint]]
- **Remote ownership audit:** every client remote needs its ownership check; `UpgradeRequest` shipped without one (2026-09-23). [[FPS-Persistence-Phase-3]]
- **`WalkSpeed` swings between 20 and 25.83 after the landing window**, cause unknown (2026-09-19). [[FPS-Sprint-Landing-Dead-Stop]]
- **Robbery `CashClaimVFX` fails 12 specs** (a lazy require; moving it to module scope fixes it), and `RestaurantConfig` / `Gas2GoConfig` each fail a `CooldownDuration` check (config 60, spec expects 1200 and 600) (2026-09-20). [[Getaway-Distance-Replaces-Claim-Zone]]

## Watch list

- **`PromptUiController` scans `workspace:GetDescendants()` on the client**: 11.69 ms once at start in the city against 4.35 ms in the FPS place; instances that stream in later are handled only if it listens for them (a `DescendantAdded` handler exists; the restyle of a streamed-in prompt was not observed) (2026-11-15). [[2026-11-15 FPS Systems Into City]]
- **8 CoreGui load-timeout errors** (`GraphQL extendSchema`, `StarterScript`, then the player list and top bar) on the client in the Task 5 run: Roblox's own modules, seen once, not in the earlier Plays (2026-11-15). [[2026-11-15 FPS Systems Into City]]
- **The late-sibling rescue in `WeaponaryShopController` is unobserved**: the race did not recur in five Plays, so only the `WaitForChild` contract backs it (2026-11-15). [[2026-11-15 FPS Systems Into City]]
- **City: colour-cycling casino parts and blinking alarm lights are now static**, because their scripts were removed; 43 scripts were disabled in place (`QuarantinedScript = true`) and most travelled into quarantine with their models, 1 remains in Workspace (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Revolvers' left hand drifts 0.55 studs while firing**: seen, not investigated (2026-09-24). [[FPS-New-Guns-Magazines-And-Pump-Forends]]
- **RPG knockback on another player** is untested (2026-09-24). [[FPS-RPG-Gamepass-Launcher]]
- **The shotgun's shop preview may be upside down** (2026-09-15). [[FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab]]
- **Skin buy never driven by a real click**; the purchase strip never captured at the new prices; the not-enough-cash refusal never reached in play (2026-09-18 to 2026-09-24). [[FPS-Spraypaint-Phase-2]] [[Revert-Global-Spraypaint-Balance]] [[FPS-Shop-Polish-And-Denied-Feedback]]
- **Rejoin-bonus fix** (Spraypaint was re-paid per level on rejoin) may drop one legitimate level-up award during a slow load (2026-09-23). [[FPS-Persistence-Phase-3]]
- **The saved Police kill counter has never been exercised**; three live test suites are missing from the repo (2026-09-23). [[FPS-Persistence-Phase-3]]
- **`RunUnitTest` uses an unanchored substring filter**: name a new case so it is not a substring of another (2026-09-23). [[FPS-Spraypaint-Phase-2]]
- **Enemies can fire with an ally in the way**, wasting the shot (2026-09-21). [[FPS-Clustered-Enemies-Stop-Attacking]]
- **Stepping off a kerb costs the full ~0.5 s landing recovery** (2026-09-20); lean while crouched is slightly reduced by the landing fix; the jolt fix is confirmed as an input value, not on screen (2026-09-19). [[FPS-All-Landings-Dead-Stop]] [[FPS-Landing-Jolt-Root-Cause]]
- **The three newest enemies' health, speed and accuracy are placeholders** (2026-09-17); the downloaded outfit folder may still be in `ServerStorage` (2026-09-16). [[FPS-Enemy-Roster-Rework-3-New-Recruits]] [[FPS-Enemy-Marketplace-Outfits]]
- **A long hotbar drag released over empty space** is untested (2026-09-13); the NPC dialogue plate hiding during a real conversation is unseen (2026-09-18). [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]] [[FPS-Figma-UI-Bugfix-Pass-3]]
- **Robbery:** the getaway distance formula exists twice (server and client) with nothing checking they agree (2026-09-20); the Bank and BankVault models are heavy at 572 and 624 parts (2026-09-12). [[Getaway-Distance-Replaces-Claim-Zone]] [[Performance-Optimization-And-Unification]]
- **The Crowbar's swing delay** is 0.25 s in one 2026-09-20 log and 0.2 s in another; which is current is unrecorded. [[Melee]]

## Documentation drift

- **`CLAUDE.md` says progression is session-only.** Stale since 2026-09-23: ProfileStore saves Cash, level and XP, weapons and loadout, upgrades, Spraypaint, skins and kill counts; quest progress is still not saved. The header comment in `LevelingService` is stale too. [[Persistence and Saves]]
- **`CLAUDE.md` still lists `StandardEnemy`** under `ServerStorage.EnemyTemplates`; it was removed on 2026-09-11. [[Enemies and Spawner]]
- **Repo copies lag Studio:** `FPSSystem/Blaster/ShotResolver.luau` and `WeaponViewmodelMotion.luau` have no RPG explosion code and no profiles for the RPG or the eight 2026-09-24 guns. [[Weapons and Blaster]]
