---
type: reference
tags: [reference, index, prompts]
updated: 2026-11-17
sources: ["CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/ (listing and first headings, 2026-11-14)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/ (listing)", "CLAUDE.md (How to work, rule 5)"]
---

# Original Prompts

An index of every file in `90 Reference/Original Prompts/` (moved there from `Documents/Roblox/PromptFolder/`), one line each.

**These are what was ASKED for. `70 Batches` is what HAPPENED.** Read a prompt when you need the original intent behind a system, the full specification, or a requirement the change log does not repeat; read the change log for what was actually built and verified.

## Rules
- **Never delete, never overwrite, never "dedupe" this folder**, and never put change logs into it. The vault notes do not edit its contents.
- **The same file name can mean two different documents.** `FPS-Kill-Leveling-System.md` is a 20,374-byte specification here and a 1,062-byte change log in `70 Batches`. Compare sizes before assuming a duplicate.
- Eleven FPS files are byte-identical copies of their change logs (marked below); the rest are distinct prompts.
- **Seven files exist nowhere else** (marked **prompt only**): five FPS prompts and the two Robbery getaway documents.
- The `.sdd-getaway/` ledger names its plan by the old `PromptFolder/` path; the plan now lives beside it here.

## FPS System (`FPSSystem/`, 67 files)

| File | Bytes | What was asked for | What happened (`70 Batches`) |
|---|---|---|---|
| `FPSSystem/FPS-AK47-Display-Fix-11-New-Guns-Integration.md` | 19,721 | AK47 Shop-Display Upside-Down Fix + Integrate 11 New Guns | [[FPS-AK47-Display-Fix-11-New-Guns-Integration]] (3,337 B) |
| `FPSSystem/FPS-Baton-Rig-Weld-Fixes-Applied.md` | 6,554 | Baton Viewmodel Hands + Third-Person Gear Appearance Fix | **prompt only** |
| `FPSSystem/FPS-Baton-Viewmodel-Real-Mesh-Fix.md` | 7,405 | Give Baton Its Own First-Person Viewmodel (Real Mesh, Not Crowbar's) | [[FPS-Baton-Viewmodel-Real-Mesh-Fix]] (1,988 B) |
| `FPSSystem/FPS-Billboard-Scale-And-Cash-Drop-System.md` | 7,317 | Scale Up Stat Billboard, Replace Direct Cash Reward with Tiered Drops | [[FPS-Billboard-Scale-And-Cash-Drop-System]] (1,121 B) |
| `FPSSystem/FPS-Crowbar-Hitbox-And-Shotgun-Cooldown-Fix.md` | 7,439 | Fix Crowbar Hit Reliability, Speed Up Shotgun Fire Rate | [[FPS-Crowbar-Hitbox-And-Shotgun-Cooldown-Fix]] (1,381 B) |
| `FPSSystem/FPS-Crowbar-Knockback-Tune.md` | 3,799 | Crowbar Knockback Is Undertuned, Not Missing | [[FPS-Crowbar-Knockback-Tune]] (623 B) |
| `FPSSystem/FPS-Damage-Direction-Indicator-And-Prompt-Range.md` | 8,773 | Damage Directional Indicator, Match Weapon Prompt Range to Billboard | [[FPS-Damage-Direction-Indicator-And-Prompt-Range]] (1,235 B) |
| `FPSSystem/FPS-Death-Screen-Leveling-Tween-LevelUp-VFX.md` | 17,211 | Death Screen, Tweened Leveling Bar, Level-Up Shine VFX | [[FPS-Death-Screen-Leveling-Tween-LevelUp-VFX]] (1,215 B) |
| `FPSSystem/FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors.md` | 15,835 | Death Screen Stuck / Button Z-Order, Stale Enemy Crowbar, Enemy Melee Timing, Lean+Turning Error Spam | [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]] (1,665 B) |
| `FPSSystem/FPS-Death-Screen-Text-Stuck-Fix-V2.md` | 10,796 | Death Screen Text Stuck After Respawn — Real Root Cause | [[FPS-Death-Screen-Text-Stuck-Fix-V2]] (994 B) |
| `FPSSystem/FPS-Dialogue-Responses-Billboard-Refactor.md` | 12,649 | Refactor Dialogue Responses from Screen GUI to a Per-NPC BillboardGui | [[FPS-Dialogue-Responses-Billboard-Refactor]] (1,916 B) |
| `FPSSystem/FPS-Dialogue-Responses-Clickable-Fix.md` | 12,872 | Fix Unclickable Dialogue Response Billboard (Move to PlayerGui + Adornee) | [[FPS-Dialogue-Responses-Clickable-Fix]] (2,842 B) |
| `FPSSystem/FPS-Enemy-AI-6-Types.md` | 14,062 | Six Enemy Types with Dedicated Debug Spawners | [[FPS-Enemy-AI-6-Types]] (1,891 B) |
| `FPSSystem/FPS-Enemy-Marketplace-Outfits.md` | 19,514 | Dress the 6 Enemy Templates Using Scouted Marketplace Accessories + BodyColors | [[FPS-Enemy-Marketplace-Outfits]] (3,146 B) |
| `FPSSystem/FPS-Enemy-Overhead-GUI-Integration.md` | 12,362 | Wire the Prebuilt "EnemyGUI" Billboard onto All 6 Enemies, Replacing the Default Nameplate | [[FPS-Enemy-Overhead-GUI-Integration]] (2,806 B) |
| `FPSSystem/FPS-Enemy-Roster-Rework-3-New-Recruits.md` | 23,025 | Enemy Roster Rework — Retire Enforcement From Quests, 3 New Recruits, Per-Type Spawn Cap | [[FPS-Enemy-Roster-Rework-3-New-Recruits]] (3,357 B) |
| `FPSSystem/FPS-Enemy-Search-State-Spin-Fix.md` | 8,838 | Fix Enemy Search-State Behavior — Stop Spinning, Stop Chasing a Dead Target | [[FPS-Enemy-Search-State-Spin-Fix]] (2,607 B) |
| `FPSSystem/FPS-Equip-Bug-Diagnosis-And-Inventory-Button.md` | 8,667 | Diagnose Equip-Does-Nothing Bug, Redesign the Inventory Toggle Button | [[FPS-Equip-Bug-Diagnosis-And-Inventory-Button]] (1,412 B) |
| `FPSSystem/FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync.md` | 11,815 | Fix Missing Equip Sounds, Sync Crowbar Animation/Sound/Damage | [[FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync]] (1,323 B) |
| `FPSSystem/FPS-Figma-1to1-Image-Export-And-Font-Fix.md` | 7,051 | Figma → Roblox 1:1 Export + The Font Bug That Caused the Mismatch | [[FPS-Figma-1to1-Image-Export-And-Font-Fix]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Figma-Frame-Layer-Archive.md` | 3,825 | Figma Frame → Layer Archive | **prompt only** |
| `FPSSystem/FPS-Figma-Image-Export-Pipeline.md` | 11,121 | Figma → Roblox Studio: Image-Asset Export & Wiring Pipeline | **prompt only** |
| `FPSSystem/FPS-Figma-UI-Bugfix-Pass-2.md` | 4,998 | Figma UI — Bug Fix Pass 2 | [[FPS-Figma-UI-Bugfix-Pass-2]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Figma-UI-Bugfix-Pass-3.md` | 5,811 | Figma UI — Bug Fix Pass 3 | [[FPS-Figma-UI-Bugfix-Pass-3]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Figma-UI-Bugfix-Pass-4.md` | 4,092 | Figma UI — Bug Fix Pass 4 | [[FPS-Figma-UI-Bugfix-Pass-4]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Figma-UI-Bugfix-Pass-5.md` | 4,979 | Figma UI — Bug Fix Pass 5 | [[FPS-Figma-UI-Bugfix-Pass-5]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Figma-UI-Bugfix-Pass.md` | 6,242 | Figma UI — 9-Bug Fix Pass | [[FPS-Figma-UI-Bugfix-Pass]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar.md` | 31,681 | GUI Templates (Clone, Not Instance.new), Cash Pickup Sound, Static Leveling Bar | [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]] (1,089 B) |
| `FPSSystem/FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel.md` | 11,921 | Hotbar Icon/Text Clash Fix, Drag-and-Drop Feel (Glow, Drop Feedback, Mouse-Follow Fix) | [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]] (2,565 B) |
| `FPSSystem/FPS-Inventory-Button-Fix-And-Hotbar-Slot-Count.md` | 6,273 | Fix Invisible Inventory Button, Reduce Hotbar to 6 Slots | [[FPS-Inventory-Button-Fix-And-Hotbar-Slot-Count]] (813 B) |
| `FPSSystem/FPS-Kill-Leveling-System.md` | 20,374 | Kill-Based Leveling System (XP, Level-Up Rewards, HUD) | [[FPS-Kill-Leveling-System]] (1,062 B) |
| `FPSSystem/FPS-Loadout-Bugfixes-Sounds-VFX.md` | 15,002 | Sniper Fire-Rate Fix, Weapon Sounds, Crowbar VFX Rework | [[FPS-Loadout-Bugfixes-Sounds-VFX]] (1,666 B) |
| `FPSSystem/FPS-Loadout-Expansion-10-New-Guns.md` | 21,680 | Loadout Expansion — 10 New Weapons | [[FPS-Loadout-Expansion-10-New-Guns]] (3,090 B) |
| `FPSSystem/FPS-Loadout-Expansion.md` | 14,073 | Expand FPS Loadout with 6 New Weapons | [[FPS-Loadout-Expansion]] (1,330 B) |
| `FPSSystem/FPS-Loadout-Melee-Shotgun-Sniper.md` | 17,576 | Add Melee, Shotgun, and Sniper Weapon Types + Name-Only Inventory Icons | [[FPS-Loadout-Melee-Shotgun-Sniper]] (2,036 B) |
| `FPSSystem/FPS-Loadout-Orientation-Fix.md` | 5,822 | Fix Backwards Gun Orientation (AKM, Scar L, Kriss Vector) | [[FPS-Loadout-Orientation-Fix]] (780 B) |
| `FPSSystem/FPS-Loadout-Rename-Burst-Expansion.md` | 15,709 | Rename Starter Weapons, Add Burst-Fire, Expand Loadout with 6 More Weapons | [[FPS-Loadout-Rename-Burst-Expansion]] (1,671 B) |
| `FPSSystem/FPS-Melee-Combo-And-Shotgun-Reload-Refactor.md` | 15,976 | Melee Combo Animation System + Shell-by-Shell Shotgun Reload | [[FPS-Melee-Combo-And-Shotgun-Reload-Refactor]] (1,861 B) |
| `FPSSystem/FPS-Nameplate-Scaling-And-Death-Hud-Hide.md` | 3,178 | Nameplate Scaling, Own-Plate Hiding, Death HUD Hide | [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-New-Guns-Missing-MuzzleAttachment-Fix.md` | 11,545 | Fix the 10 New Guns — Missing `MuzzleAttachment` Crashes the Controller | [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]] (3,709 B) |
| `FPSSystem/FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots.md` | 33,686 | Pistol 3D Display Rotation Fix + Persistent Ownership with Explicit Loadout Slots | [[FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots]] (3,050 B) |
| `FPSSystem/FPS-Player-Card-System.md` | 17,372 | Player Card (Button, Card GUI, /view Chat Command) | [[FPS-Player-Card-System]] (865 B) |
| `FPSSystem/FPS-Player-Nameplates-And-LevelUp-Fix.md` | 4,429 | Player Nameplates, Level-Up Fix, MultiExport | [[FPS-Player-Nameplates-And-LevelUp-Fix]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Player-Overhead-GUI-Integration.md` | 10,425 | Reuse the Enemy Name/Health Billboard on Players Too, Suppress Their Built-In Nameplate | **prompt only** |
| `FPSSystem/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md` | 17,444 | 5 More Quest NPCs (Levels 10/20/35/50/70) + Raise Level Cap + Admin `/setlevel` | [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]] (2,152 B) |
| `FPSSystem/FPS-Quest-Feedback-NPC-Polish.md` | 16,519 | Quest Completion Feedback (Toast + Banner + VFX + Sound) and NPC Polish | [[FPS-Quest-Feedback-NPC-Polish]] (3,041 B) |
| `FPSSystem/FPS-Quest-Overflow-And-Dead-Code-Removal.md` | 4,688 | Quest Bar Overflow (real cause) + Dead Code Removal | [[FPS-Quest-Overflow-And-Dead-Code-Removal]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Quest-System-Level1-KillThugs.md` | 33,954 | Quest System (Level 1 — Defeat 10 Thugs), Built on Your Dialogue Template | [[FPS-Quest-System-Level1-KillThugs]] (4,248 B) |
| `FPSSystem/FPS-Remove-Sniper.md` | 3,433 | Fully Remove the Sniper (Snipex Alligator) | [[FPS-Remove-Sniper]] (888 B) |
| `FPSSystem/FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md` | 9,012 | Rifle Enemy Accuracy/Damage Rebalance, Death Camera Fix, Remove Old Templates | [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]] (1,148 B) |
| `FPSSystem/FPS-Shop-Hover-Sound.md` | 8,751 | Reuse the Dialogue Hover Tick Sound on the Shop and Weapon Card Buttons | [[FPS-Shop-Hover-Sound]] (3,108 B) |
| `FPSSystem/FPS-Shop-Overflow-Fixes.md` | 10,846 | Fix Three Shop GUI Overflow Bugs (Baton 3D View, Weapon Grid, Upgrade/Equip Buttons) | [[FPS-Shop-Overflow-Fixes]] (2,195 B) |
| `FPSSystem/FPS-Shop-Polish-And-Denied-Feedback.md` | 4,670 | Shop Polish, Slot/Card Outlines, Denied Feedback | [[FPS-Shop-Polish-And-Denied-Feedback]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Spawner-Rework-Enemy-Nerf-Death-Inventory.md` | 13,593 | Spawner Directory Rework, Deeper Enemy Nerf + Recoil, Lock Inventory on Death | [[FPS-Spawner-Rework-Enemy-Nerf-Death-Inventory]] (2,327 B) |
| `FPSSystem/FPS-UltimateUIPack-Effects-Integration.md` | 16,004 | Wire Up UltimateUIPack Effects on the Shop, Player Card, and Weapon Buttons | [[FPS-UltimateUIPack-Effects-Integration]] (2,664 B) |
| `FPSSystem/FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing.md` | 18,480 | Upgrade Button Style, Pickup/Equip/Cash Sound Tuning, Enemy Recoil, Respawn Timing, Hotbar Restyle, Player Card PFP Fix, Landing Slowdown | [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]] (2,015 B) |
| `FPSSystem/FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix.md` | 19,402 | +5 Damage Per Upgrade Level, Cash Burst FX, Slot Equip Animation, Baton Sound Fix, Stop the Shop's 3D Preview Resetting | [[FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix]] (2,562 B) |
| `FPSSystem/FPS-Weapon-Grid-Overflow-And-Detail-Tweaks.md` | 2,835 | Weapon Grid Overflow, Price Row Move, Melee Stats | [[FPS-Weapon-Grid-Overflow-And-Detail-Tweaks]] (byte-identical copy of the change log) |
| `FPSSystem/FPS-Weapon-Icon-Decals.md` | 8,437 | Weapon Icon Decals — Upload and Wire Into Hotbar + Billboard | [[FPS-Weapon-Icon-Decals]] (2,118 B) |
| `FPSSystem/FPS-Weapon-Pickups-And-Inventory-Integration.md` | 11,997 | Weapon Pickup System + Custom Inventory Integration | [[FPS-Weapon-Pickups-And-Inventory-Integration]] (1,886 B) |
| `FPSSystem/FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System.md` | 17,941 | Weapon Stat Billboard + Cash Currency + Damage Upgrades | [[FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System]] (1,983 B) |
| `FPSSystem/FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab.md` | 13,412 | 3D Display Orientation/Framing Fixes, Baton Rebuilt as a True Crowbar Duplicate, "Owned" Shop Tab | [[FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab]] (3,373 B) |
| `FPSSystem/FPS-Weaponary-Catchup-Owned-Tab-Baton-Viewmodel-Tab-Layout-Stun-Recovery.md` | 18,133 | Catch-Up Pass — Owned Tab, Baton Viewmodel, Tab Width, Empty Label, Icon Guards, Stun Recovery | **prompt only** |
| `FPSSystem/FPS-Weaponary-Melee-Display-Fixes-And-Baton.md` | 14,024 | Shop Melee Visibility, Detail-View Tabs, 3D Display Orientation, Stun Mechanic + Baton | [[FPS-Weaponary-Melee-Display-Fixes-And-Baton]] (3,757 B) |
| `FPSSystem/FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md` | 20,352 | Weapon Ownership Persistence, Price-Sorted Shop, Purchase/Upgrade Sounds, 3D Rotating Weapon Display | [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]] (3,189 B) |
| `FPSSystem/FPS-Weaponary-Shop-Refactor.md` | 45,460 | Weaponary Shop — Replace World Pickups with a Purchase/Upgrade Shop, 4-Weapon Ownership Cap | [[FPS-Weaponary-Shop-Refactor]] (3,660 B) |
| `FPSSystem/FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes.md` | 15,457 | Weaponary Shop Overflow, Empty-Slot Text, Baton Icon, and Enemy Stun Enforcement | [[FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes]] (3,298 B) |

## Robbery System (`RobberySystem/`, 7 files)

| File | Bytes | What was asked for | What happened (`70 Batches`) |
|---|---|---|---|
| `RobberySystem/Getaway-Distance-Claim-And-GUI.PLAN.md` | 49,961 | Getaway Distance Claim + Escape GUI — Implementation Plan | **prompt only**; outcome in [[Getaway-Distance-Replaces-Claim-Zone]] |
| `RobberySystem/Getaway-Distance-Claim-And-GUI.md` | 22,017 | Replace the Claim Zone With a Getaway Distance + Escape GUI | **prompt only**; outcome in [[Getaway-Distance-Replaces-Claim-Zone]] |
| `RobberySystem/Global-Notifications-And-Location-Status-Billboards.md` | 14,897 | Global Robbery Notifications + Per-Location Status Billboards | [[Global-Notifications-And-Location-Status-Billboards]] (2,668 B) |
| `RobberySystem/NewsStation-Hacking-Randomize-Word-Button.md` | 8,335 | Add a "Randomise Word" Button to the NewsStation Hacking Puzzle (3 chances per attempt) | [[NewsStation-Hacking-Randomize-Word-Button]] (1,980 B) |
| `RobberySystem/Performance-Optimization-And-Unification.md` | 12,688 | Optimize, Unify, and Clean Up the Robbery System (Bank / SlowFoods / Gas2Go / NewsStation) | [[Performance-Optimization-And-Unification]] (2,450 B) |
| `RobberySystem/Post-Move-Fixes-And-GUI-Polish.md` | 12,555 | Fix Stale DuffelBag Path + Duffel/Cash/Notification GUI Polish | [[Post-Move-Fixes-And-GUI-Polish]] (2,806 B) |
| `RobberySystem/Timer-Hourglass-And-Duffel-Upgrade-GUI.md` | 11,093 | Timer Hourglass Icon + Duffel Bar Redesign with Gamepass Upgrade Button | [[Timer-Hourglass-And-Duffel-Upgrade-GUI]] (2,422 B) |

## Robbery getaway ledger (`RobberySystem/.sdd-getaway/`, 41 files)

The working ledger of the getaway change: briefs, reports, fix rounds, pre-change source snapshots of the Robbery scripts, and a reconstruction of `LocationServer` / `LocationServerSpec`. Outcome: [[Getaway-Distance-Replaces-Claim-Zone]]. The `.lua` files are snapshots for rollback and review, not live code.

| File | Bytes | What was asked for | What happened (`70 Batches`) |
|---|---|---|---|
| `RobberySystem/.sdd-getaway/deferred-minors.txt` | 1,451 | Minor review findings deferred during the getaway work | ledger |
| `RobberySystem/.sdd-getaway/final-fix-report.md` | 14,051 | Final fix wave — report | ledger |
| `RobberySystem/.sdd-getaway/final-fix.md` | 5,661 | Final fix wave — one dispatch, seven items | ledger |
| `RobberySystem/.sdd-getaway/progress.md` | 59,551 | SDD ledger — plan: /Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/Getaway-Distance-Claim-And-GUI.PLAN.md | ledger |
| `RobberySystem/.sdd-getaway/reconstructed/LocationServer.lua` | 18,450 | Reconstructed `LocationServer` source | ledger |
| `RobberySystem/.sdd-getaway/reconstructed/LocationServerSpec.lua` | 20,539 | Reconstructed `LocationServerSpec` source | ledger |
| `RobberySystem/.sdd-getaway/reconstruction-report.md` | 11,920 | Reconstruction report — `LocationServer` + `LocationServerSpec` | ledger |
| `RobberySystem/.sdd-getaway/snapshots/Gas2GoServer.before.lua` | 12,560 | Snapshot of `Gas2GoServer` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/HeistClient.before.lua` | 50,280 | Snapshot of `HeistClient` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/HeistClient.final.before.lua` | 64,796 | Snapshot of `HeistClient` source before the final fix wave | ledger |
| `RobberySystem/.sdd-getaway/snapshots/HeistClient.fix1.before.lua` | 61,572 | Snapshot of `HeistClient` source before fix round 1 | ledger |
| `RobberySystem/.sdd-getaway/snapshots/HeistServer.before.lua` | 45,249 | Snapshot of `HeistServer` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/HeistServer.final.before.lua` | 47,480 | Snapshot of `HeistServer` source before the final fix wave | ledger |
| `RobberySystem/.sdd-getaway/snapshots/HeistServer.fix1.before.lua` | 47,213 | Snapshot of `HeistServer` source before fix round 1 | ledger |
| `RobberySystem/.sdd-getaway/snapshots/LocationServer.before.lua` | 17,507 | Snapshot of `LocationServer` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/LocationServer.final.before.lua` | 18,450 | Snapshot of `LocationServer` source before the final fix wave | ledger |
| `RobberySystem/.sdd-getaway/snapshots/LocationServerSpec.before.lua` | 18,065 | Snapshot of `LocationServerSpec` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/LocationServerSpec.final.before.lua` | 20,539 | Snapshot of `LocationServerSpec` source before the final fix wave | ledger |
| `RobberySystem/.sdd-getaway/snapshots/LocationServerSpec.fix1.before.lua` | 19,188 | Snapshot of `LocationServerSpec` source before fix round 1 | ledger |
| `RobberySystem/.sdd-getaway/snapshots/NewsStationServer.before.lua` | 19,013 | Snapshot of `NewsStationServer` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/SlowFoodsServer.before.lua` | 10,020 | Snapshot of `SlowFoodsServer` source before the first change | ledger |
| `RobberySystem/.sdd-getaway/snapshots/WorldSpec.final.before.lua` | 47,531 | Snapshot of `WorldSpec` source before the final fix wave | ledger |
| `RobberySystem/.sdd-getaway/task-1-brief.md` | 8,058 | Task 1 brief — Figma design, export, and UITheme pinning | ledger |
| `RobberySystem/.sdd-getaway/task-1-report.md` | 15,260 | Task 1 report — Figma design, export, and `UITheme` pinning | ledger |
| `RobberySystem/.sdd-getaway/task-2-brief.md` | 19,721 | Task 2 brief — the Getaway service (TDD) | ledger |
| `RobberySystem/.sdd-getaway/task-2-report.md` | 13,693 | Task 2 report — the `Getaway` service (TDD) | ledger |
| `RobberySystem/.sdd-getaway/task-3-brief.md` | 5,086 | Task 3 brief — EscapeDistance = 200 in all four configs | ledger |
| `RobberySystem/.sdd-getaway/task-3-report.md` | 15,236 | Task 3 Report — `EscapeDistance = 200` in all four configs | ledger |
| `RobberySystem/.sdd-getaway/task-4-brief.md` | 14,184 | Task 4 brief — wire Getaway into LocationServer (SlowFoods, Gas2Go, NewsStation) | ledger |
| `RobberySystem/.sdd-getaway/task-4-fix-1.md` | 4,268 | Task 4 — fix round 1: two Important findings from review | ledger |
| `RobberySystem/.sdd-getaway/task-4-report.md` | 9,726 | Task 4 — fix round 1 report | ledger |
| `RobberySystem/.sdd-getaway/task-5-brief.md` | 8,636 | Task 5 brief — wire Getaway into HeistServer (the Bank) | ledger |
| `RobberySystem/.sdd-getaway/task-5-fix-1.md` | 6,111 | Task 5 — fix round 1: three items, all in `ServerScriptService.HeistServer` | ledger |
| `RobberySystem/.sdd-getaway/task-5-report.md` | 26,662 | Task 5 report — wire `Getaway` into `HeistServer` (the Bank) | ledger |
| `RobberySystem/.sdd-getaway/task-6-brief.md` | 15,625 | Task 6 brief — the getaway widget in HeistClient | ledger |
| `RobberySystem/.sdd-getaway/task-6-fix-1.md` | 6,657 | Task 6 — fix round 1: four items, all in `StarterPlayer.StarterPlayerScripts.HeistClient` | ledger |
| `RobberySystem/.sdd-getaway/task-6-report.md` | 28,213 | Task 6 report — the getaway widget in `HeistClient` | ledger |
| `RobberySystem/.sdd-getaway/task-7-brief.md` | 6,634 | Task 7 brief — retire the Claim zones (SCRIPT-SIDE ONLY) | ledger |
| `RobberySystem/.sdd-getaway/task-7-report.md` | 19,401 | Task 7 report — retire the Claim zones (untag, do not delete) | ledger |
| `RobberySystem/.sdd-getaway/task-8-brief.md` | 5,431 | Task 8 brief — play-mode verification | ledger |
| `RobberySystem/.sdd-getaway/task-8-report.md` | 20,133 | Task 8 report — play-mode verification | ledger |

## Tycoon (added 2026-11-14)

| File | Bytes | What it asks for | Kind |
|---|---|---|---|
| `Tycoon/2026-11-14 CrimeLife Tycoon Kickoff.md` | not recorded | The kickoff for CrimeLife Tycoon: research tycoon retention, plan the merge into Crimelife City, build new systems | prompt only |
| `Tycoon/2026-11-17 Compound Floor Plan.md` | not recorded | A new tycoon floor plan and builder artifact on a 361 × 300 plot, inspired by a yard-compound screenshot, keeping the HQ blueprint's rooms; then a 3D view | [[2026-11-17 Compound Floor Plan]] |

Related: [[Docs Index]], [[Batch Log]], [[Reference MOC]].
