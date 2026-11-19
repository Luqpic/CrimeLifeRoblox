---
type: moc
tags: [batch, moc]
updated: 2026-11-20
sources: ["git log of Luqpic/CrimeLifeRoblox"]
---

# Batch Log

Newest first. One line per batch. New batches: a note from [[Batch Note Template]] in `70 Batches/`, named `YYYY-MM-DD Topic`, and a line at the top of this table.

Before 2026-11-14 every change was a change log (`FPSSystem/*.md`, `RobberySystem/*.md`); those notes now live in `70 Batches/FPS System/` and `70 Batches/Robbery System/` unchanged.

| Date | Place | Batch | What |
|---|---|---|---|
| 2026-11-20 | City (cloud place "Crimelife Tycoon") | [[2026-11-20 Admin Animations Third Person]] | Group animations unblocked by the developer's private publish into SolarArc Studios; OBT clip set (41 clips), roll Q (12.3 stamina) and ledge climb, Roblox-default fallback; OBT shoulder camera in the blaster (V toggles, Z swaps, shoulder zoom, `AimPitch`); admin panel on F2 (31 actions, owner and group helpers, no account ids) with reviews and fixes; city 353 / 353, heist 740 / 0; saved as place versions 10, 15, 21 and 23, not published |
| 2026-11-18 | City | [[2026-11-18 Open Items Pass]] | Rules (vault skills only, Opus + Sonnet); heist-layers final review (C1 deposit-box lockpick from anywhere) and its fixes; police reset keeps stars, last-seen search; burst after idle 12 -> 3, third-person long-gun shots fixed, 12 muzzle flashes, APS machine pistol; DeathScreen Sibling, chip confirm, text sweep; heist test gaps, Zone flake and 1,680 warnings gone; one gamepass system and one notification style; city 315 / 315, heist 740 / 0; not saved |
| 2026-11-17 | City | [[2026-11-17 Heist Layers]] | One optional signature layer in each robbery: SlowFoods fleeing Manager and key (safe 3000), Gas2Go ATM rip-out (9000 heavy carry), NewsStation broadcast takeover (6000 each), Bank deposit boxes (1500 cash, gold bar 8000 heavy carry); shared bonus loot over the cap and a speed-12 carry banked at 200 studs; carrier-only obby ledges; city 262 / 262, heist 707 / 0; not saved |
| 2026-11-17 | Tycoon | [[2026-11-17 Compound Floor Plan]] | New builder drawing set for the tycoon base on a 361 × 300 plot: rooms ring an open yard (spawn + fight pit), G + F2 + roof terrace + bunker, east drive lane, skybridge to a Watchtower; every room from the HQ blueprint kept; 3D block model; OBT BUILD menu (no buttons), build in order with no temporary caps; labels clear (0 overlaps); artifact published privately; no Studio change |
| 2026-11-17 | City | [[2026-11-17 Known Issues Pass]] | Open Items closed: `Workspace.HQ` quarantined, four prompts `Custom`, NewsWorker `Invulnerable`, removal toast, re-slot copy, unowned skins, Spraypaint join toast, 38 weapon descriptions, shotgun reload readout, dry-fire cue, RPG blast as a particle burst, three muzzles at the barrel end, `WalkSpeed` swing (backward clamp keyed on input), level-up popup placed clear of the heist HUD; stuck Thug did not reproduce; pump fore-ends need a mesh upload; five clean Plays, city 262 / 262, heist 620 / 1 (`Zone` timing); fix wave `Batch: known issues pass fixes`; Tasks 1-2 on disk (saved mid-run, file written 15:04), Tasks 3-4 and the fix wave not saved |
| 2026-11-17 | City | [[2026-11-17 Police Slow Fill]] | Police fill fixed where spawn points are scarce: cheap checks unbudgeted (up to 2,000 samples per search), path checks capped at 20 per player per round; city spawn plaza 1 officer in 60 s became 10 in 5 s; city 258 / 258; not saved |
| 2026-11-17 | City | [[2026-11-17 Police and Wanted]] | Wanted level 0 to 5 stars (heist alarms, hits on police, witnessed crimes), police squads by stars on the enemy AI (cap 24, Armed from 3 stars), break sight to drain 8 s per star after a 20 s search window, death clears and forfeits the haul, banking keeps the stars; 3 NewsStation guards, guards 6 per shot at robbers and wanted players; the star meter; quest givers become crooked cops; loop proven in Play, 10 police held 125 s, five clean Plays, city 251 / 251, heist 620 / 1 (`Zone` timing); final review fixes (top-up starvation, victim witness, police crossfire on guards, squads shrink with stars, departed players), city 257 / 257; not saved |
| 2026-11-16 | City | [[2026-11-16 Robbery Systems Into City]] | The four heists (Bank, SlowFoods, Gas2Go, NewsStation) imported and placed at the city's buildings (Bank vault 147.75 studs underground, art quarantined), Robbery cash bridged onto `leaderstats.Cash`, load-order and remote audits (supplier reach, removed character forfeits the bag, purchase confirmed with retries, safe pacing), cooldowns 1200 / 600; city 193 / 193 tests, heist 615 / 1 (`Zone` timing), five clean Plays, SlowFoods banked once; final review fixes (heist NPCs `Invulnerable`, `safePlayerAdded` in four scripts, no stale false over a confirmed gamepass), heist 616 / 1 |
| 2026-11-15 | City | [[2026-11-15 FPS Hardening In City]] | Remote ownership audit (14 handlers, 4 fixes: quest reach, canonical hit keys, server rate of fire, NaN level), quest progress saved, 4 ScreenGuis to Sibling and 6 left Global, `Lean` line 41, `workspace.FX`, preview script off; 171 / 171 tests, five clean Plays |
| 2026-11-15 | City | [[2026-11-15 FPS Systems Into City]] | FPS systems ported into the city as an exact copy (199 script hashes equal, 147 / 147 tests in both places), two deviations, enemies and quest givers placed; tycoon building brought forward as a static preview on Plot3; Crimelife City becomes the primary place |
| 2026-11-14 | City | [[2026-11-14 City Baseline and Cleanup]] | City cleanup: backdoor scripts and duplicate buildings removed, slab quarantined, plots named, streaming on (264,072 to 118,679 Workspace instances) |
| 2026-09-25 | FPS | [[FPS-RPG-Reload-Hand-Carries-Rocket]] | RPG Reload — The Hand Carries the Rocket Into the Tube |
| 2026-09-25 | FPS | [[FPS-Gamepass-Shop-Scrolling-Grid]] | Gamepass Shop Grid Scrolls Instead of Overflowing |
| 2026-09-24 | FPS | [[Revert-Global-Spraypaint-Balance]] | Revert Spraypaint to a global balance, raise skin prices |
| 2026-09-24 | FPS | [[Per-Weapon-Spraypaint]] | Spraypaint becomes a per-weapon balance |
| 2026-09-24 | FPS | [[Notification-Blank-Card-ZIndexBehavior]] | Notification card rendered blank — ZIndexBehavior, not transparency |
| 2026-09-24 | FPS | [[FPS-Weaponry-Category-Icons]] | Weaponry category tabs and spray badge use icons instead of words |
| 2026-09-24 | FPS | [[FPS-Skins-Chip-Outline-And-Weapon-Level-Pill]] | Skin chip outlines finally render; weapon level pill added |
| 2026-09-24 | FPS | [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]] | Skins card stops drifting from the shop, and the entrance tween becomes visible |
| 2026-09-24 | FPS | [[FPS-Skins-Card-Shop-Slides-Aside]] | Opening the Skins card slides the shop aside instead of shrinking it |
| 2026-09-24 | FPS | [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]] | Skins card: preview before buying, hover and click feedback, spray burst, Vip on hold |
| 2026-09-24 | FPS | [[FPS-Skins-Card-Detached-And-Palette-Expansion]] | Skins card detaches from the shop panel, palette catalogue grows 12 -> 20 |
| 2026-09-24 | FPS | [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]] | RPG Preview Upright, Real Gamepass, RPG Sounds, Gamepass Tab Logo, RPG Icon |
| 2026-09-24 | FPS | [[FPS-RPG-Gamepass-Launcher]] | RPG — Gamepass Rocket Launcher, Explosive Rounds, Gamepass Tab |
| 2026-09-24 | FPS | [[FPS-Quest-Givers-Law-Enforcement-Outfits]] | Quest Givers Dressed as Law Enforcement |
| 2026-09-24 | FPS | [[FPS-New-Guns-Magazines-And-Pump-Forends]] | Magazines and Pump Fore-Ends on the New Guns |
| 2026-09-24 | FPS | [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]] | XP on the Kill Toast, New Gun Icons, Experience and Health Icons |
| 2026-09-24 | FPS | [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]] | "Killed <Name>" Kill Toast, Buy Goes Straight to Slot Pick, Knife Backstab |
| 2026-09-24 | FPS | [[FPS-Eight-New-Pistols-And-Shotguns]] | Eight New Pistols and Shotguns |
| 2026-09-24 | FPS | [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]] | Criminal Ranks, Health Icons on Overheads, Icons on Both Toast Lines |
| 2026-09-23 | FPS | [[Notification-Queue-While-Panel-Open]] | Notification Queue While A Panel Is Open |
| 2026-09-23 | FPS | [[Notification-Card-Fix-And-Weapon-HUD-Move]] | Notification Card Fixed And Resized, Weapon HUD Moved To Middle-Right |
| 2026-09-23 | FPS | [[FPS-Weapon-Skins-Phase-1]] | Weapon Skins, Phase 1 |
| 2026-09-23 | FPS | [[FPS-Spraypaint-Phase-2]] | Spraypaint, Phase 2 |
| 2026-09-23 | FPS | [[FPS-Spraypaint-Badge-Beside-Price-Label]] | Spray-Can Badge Beside the Spraypaint Price |
| 2026-09-23 | FPS | [[FPS-Persistence-Phase-3]] | Persistence, Phase 3 |
| 2026-09-22 | FPS | [[FPS-Weapon-Skins-Chip-Design]] | Skin Chip and Skin Row — Figma Design (Cosmetics Task 6) |
| 2026-09-22 | FPS | [[FPS-Monetization-Cosmetics-Spec]] | Spec: Cosmetics Monetisation — Skins, Spraypaint, and the Booster Pass |
| 2026-09-22 | FPS | [[FPS-Miss-Tracers-And-Spawn-Cap]] | Missed Shots Stop Painting the Sky, and Half the Crowd |
| 2026-09-21 | FPS | [[FPS-Melee-Shop-View-And-Bleed-Effect]] | Melee Stands Up in the Shop, and Bleeding Is Visible |
| 2026-09-21 | FPS | [[FPS-Loadout-Slot-Hover-Outline]] | Hover Outline on the Loadout Slots |
| 2026-09-21 | FPS | [[FPS-Knife-Bleed-Melee]] | The Knife, a Melee Weapon That Bleeds |
| 2026-09-21 | FPS | [[FPS-Inventory-Slot-Click-Sound-And-Hover-Outline]] | Inventory Slots Get a Click Sound and a Hover Outline |
| 2026-09-21 | FPS | [[FPS-Clustered-Enemies-Stop-Attacking]] | Clustered Enemies Stopped Attacking |
| 2026-09-21 | FPS | [[FPS-Carried-Weapons-Absorbed-Hits]] | A Carried Weapon Absorbed Hits Aimed at Its Holder |
| 2026-09-21 | FPS | [[FPS-Baton-Stun-Becomes-A-Stagger]] | The Baton Stun Drops the Target Instead of Freezing It |
| 2026-09-20 | Robbery | [[Getaway-Distance-Replaces-Claim-Zone]] | Getaway Distance Replaces the Claim Zone |
| 2026-09-20 | FPS | [[FPS-Viewmodel-KeyframeSequence-Export]] | Viewmodel animations exported as linear KeyframeSequences |
| 2026-09-20 | FPS | [[FPS-Viewmodel-Hands-Off-Weapon]] | Viewmodel hands did not touch the weapon |
| 2026-09-20 | FPS | [[FPS-Viewmodel-Animation-Linear-Easing]] | Viewmodel animations switched to linear easing |
| 2026-09-20 | FPS | [[FPS-Melee-Viewmodel-Swing]] | A Real Swing for Melee Viewmodels |
| 2026-09-20 | FPS | [[FPS-All-Landings-Dead-Stop]] | Every Landing Stops the Player Dead |
| 2026-09-19 | Robbery | [[Supplier-Dialogue-On-Shared-Billboard-Engine]] | Illegal Supplier Moved Onto The Shared Dialogue Engine |
| 2026-09-19 | Robbery | [[Supplier-Billboard-Input-And-Toast-Duration]] | Supplier Billboard Input, Toast Duration, Dead Code Removed |
| 2026-09-19 | Robbery | [[Shared-UI-Effects-FOV-Blur-And-Sounds]] | Shared UI Effects, Camera FOV/Blur and Button Sounds |
| 2026-09-19 | Robbery | [[Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades]] | Puzzle Prompt Guard, Cash Logo Burst and GUI Fades |
| 2026-09-19 | FPS | [[Prompt-Size-And-Ring-Starts-Empty]] | Proximity Prompt Sized Down, Ring Starts Empty |
| 2026-09-19 | Robbery | [[Prompt-Size-And-Ring-Starts-Empty]] | Proximity Prompt Sized Down, Ring Starts Empty |
| 2026-09-19 | FPS | [[Prompt-Liquid-Shape-And-Hover-Lift]] | Liquid Takes the Plate's Shape, Plus Hover and Hold Lift |
| 2026-09-19 | Robbery | [[Prompt-Liquid-Shape-And-Hover-Lift]] | Liquid Takes the Plate's Shape, Plus Hover and Hold Lift |
| 2026-09-19 | FPS | [[Prompt-Liquid-Fill-And-Animations]] | Prompt Progress Becomes a Liquid Fill, With Entrance and Exit |
| 2026-09-19 | Robbery | [[Prompt-Liquid-Fill-And-Animations]] | Prompt Progress Becomes a Liquid Fill, With Entrance and Exit |
| 2026-09-19 | Robbery | [[Prompt-Closes-When-Disabled]] | Prompt Face Closes When Its Prompt Is Disabled |
| 2026-09-19 | FPS | [[Prompt-Circle-Liquid-And-Glow]] | Prompt Becomes a Circle With a Liquid Fill and Halo |
| 2026-09-19 | Robbery | [[Prompt-Circle-Liquid-And-Glow]] | Prompt Becomes a Circle With a Liquid Fill and Halo |
| 2026-09-19 | FPS | [[Player-Card-XP-Bar]] | Player Card XP Bar Alignment and Colour |
| 2026-09-19 | FPS | [[Figma-ProximityPrompt-Redesign]] | Figma Proximity Prompt Design |
| 2026-09-19 | Robbery | [[Figma-ProximityPrompt-Redesign]] | Figma Proximity Prompt Design |
| 2026-09-19 | FPS | [[FPS-Sprint-Landing-Dead-Stop]] | A Sprint Landing Now Costs All Momentum |
| 2026-09-19 | FPS | [[FPS-Shotgun-Kill-Knockback]] | Shotgun Knockback Moved to the Killing Blow |
| 2026-09-19 | FPS | [[FPS-Melee-Hit-And-LevelUp-VFX]] | Authored Melee Hit VFX and Level-Up Burst |
| 2026-09-19 | FPS | [[FPS-Landing-Jolt-Root-Cause]] | The Landing Camera Jolt, Actual Cause |
| 2026-09-19 | FPS | [[FPS-Landing-Camera-Jolt]] | The Camera Jolt on Landing |
| 2026-09-19 | FPS | [[FPS-Fall-Animation-Dead-Asset]] | Falling and Climbing Animations Restored (Dead Animation Assets) |
| 2026-09-19 | FPS | [[FPS-Death-Screen-You-Died-And-Alignment]] | Death Screen Reads "You Died", Centred, and the Fade Measured |
| 2026-09-19 | FPS | [[FPS-Banner-Title-Centring-And-UI-Fades]] | Banner Title Centring and UI Fades |
| 2026-09-19 | FPS | [[Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip]] | Enemy Spread, Spawn Rate, and Clicking a Hotbar Slot |
| 2026-09-19 | FPS | [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]] | Enemies Flying Upward, Equip Sound Audibility, Nameplate Gap |
| 2026-09-19 | FPS | [[Close-Button-Unified-With-Robbery]] | Close Buttons Unified With Robbery System |
| 2026-09-19 | Robbery | [[Close-Button-Unified-With-FPS]] | Close Buttons Unified With FPS System |
| 2026-09-19 | FPS | [[Cash-Spend-Burst-Replaces-Price-Label]] | Cash Burst On Spend, Replacing The Red Price Label |
| 2026-09-19 | Robbery | [[Cash-Burst-Emitter-Icon]] | Robbable Objects Burst the Real Cash Icon |
| 2026-09-18 | Robbery | [[UI-Bug-Fixes-Notification-HUD-Lockpick-Titles]] | Notification, HUD Stacking, Lockpick and Title Fixes |
| 2026-09-18 | Robbery | [[Slice-Transparency-And-Anchor-Fixes]] | Slice Transparency and Anchor Point Fixes |
| 2026-09-18 | Robbery | [[GUI-Audit-And-Figma-Redesign]] | GUI Audit and Figma Redesign |
| 2026-09-18 | Robbery | [[Figma-Slices-Imported-To-Studio]] | Figma Slices Imported Into Studio |
| 2026-09-18 | FPS | [[FPS-Weapon-Grid-Overflow-And-Detail-Tweaks]] | Weapon Grid Overflow, Price Row Move, Melee Stats |
| 2026-09-18 | FPS | [[FPS-Shop-Polish-And-Denied-Feedback]] | Shop Polish, Slot/Card Outlines, Denied Feedback |
| 2026-09-18 | FPS | [[FPS-Quest-Overflow-And-Dead-Code-Removal]] | Quest Bar Overflow (real cause) + Dead Code Removal |
| 2026-09-18 | FPS | [[FPS-Player-Nameplates-And-LevelUp-Fix]] | Player Nameplates, Level-Up Fix, MultiExport |
| 2026-09-18 | FPS | [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]] | Nameplate Scaling, Own-Plate Hiding, Death HUD Hide |
| 2026-09-18 | FPS | [[FPS-Figma-UI-Bugfix-Pass-5]] | Figma UI — Bug Fix Pass 5 |
| 2026-09-18 | FPS | [[FPS-Figma-UI-Bugfix-Pass-4]] | Figma UI — Bug Fix Pass 4 |
| 2026-09-18 | FPS | [[FPS-Figma-UI-Bugfix-Pass-3]] | Figma UI — Bug Fix Pass 3 |
| 2026-09-18 | FPS | [[FPS-Figma-UI-Bugfix-Pass-2]] | Figma UI — Bug Fix Pass 2 |
| 2026-09-18 | FPS | [[FPS-Figma-UI-Bugfix-Pass]] | Figma UI — 9-Bug Fix Pass |
| 2026-09-18 | FPS | [[FPS-Figma-1to1-Image-Export-And-Font-Fix]] | Figma → Roblox 1:1 Export + The Font Bug That Caused the Mismatch |
| 2026-09-17 | FPS | [[FPS-Enemy-Search-State-Spin-Fix]] | Enemies No Longer Spin in Place, or Run at Your Corpse |
| 2026-09-17 | FPS | [[FPS-Enemy-Roster-Rework-3-New-Recruits]] | Enemy Roster Rework — Three New Recruits, Enforcement Retired |
| 2026-09-16 | FPS | [[FPS-Upgrade-Realtime-Refresh-And-Cash-Emoji]] | Upgrades Appeared Not to Apply, and the Cash Symbol |
| 2026-09-16 | FPS | [[FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix]] | Upgrades Worth Taking, Spend Feedback, Slot Animation, and Baton Sounds |
| 2026-09-16 | FPS | [[FPS-UltimateUIPack-Effects-Integration]] | Menu Blur, and Buttons That React to the Cursor |
| 2026-09-16 | FPS | [[FPS-Shop-Overflow-Fixes]] | Baton's Shop Preview, Grid Bleeding Past the Panel, and Overlapping Buttons |
| 2026-09-16 | FPS | [[FPS-Shop-Hover-Sound]] | Hover and Click Sounds on the Shop and Menu Buttons |
| 2026-09-16 | FPS | [[FPS-Quest-System-Level1-KillThugs]] | Quest System — a Quest Giver, a Quest Log, and the First Quest |
| 2026-09-16 | FPS | [[FPS-Quest-Feedback-NPC-Polish]] | Quest Completion Feedback, Repeatable Quests, and NPC Polish |
| 2026-09-16 | FPS | [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]] | Five More Quests, a Higher Level Cap, and an Admin Level Tool |
| 2026-09-16 | FPS | [[FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots]] | Pistol Shop Display, and Permanent Ownership with Loadout Slots |
| 2026-09-16 | FPS | [[FPS-Enemy-Overhead-GUI-Integration]] | Enemies Get the Custom Name and Health Display |
| 2026-09-16 | FPS | [[FPS-Enemy-Marketplace-Outfits]] | The Six Enemy Types Are Dressed |
| 2026-09-16 | FPS | [[FPS-Dialogue-Responses-Clickable-Fix]] | Dialogue Replies Made Clickable |
| 2026-09-16 | FPS | [[FPS-Dialogue-Responses-Billboard-Refactor]] | Dialogue Replies Moved Off the Screen and Beside the Quest Giver |
| 2026-09-16 | FPS | [[FPS-Baton-Viewmodel-Real-Mesh-Fix]] | The Baton Looked Right to Everyone Except the Person Holding It |
| 2026-09-16 | FPS | [[FPS-AK47-Display-Fix-11-New-Guns-Integration]] | Eleven New Weapons Integrated, and the AK47's Upside-Down Preview |
| 2026-09-15 | FPS | [[FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes]] | Shop Tab Overflow, Empty-Slot Text, Baton Icon, Enemy Stun Recovery |
| 2026-09-15 | FPS | [[FPS-Weaponary-Shop-Refactor]] | Weaponary Shop Replaces World Pickups |
| 2026-09-15 | FPS | [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]] | Weapon Ownership Persistence, Sorted Shop, Purchase Sounds, 3D Weapon Display |
| 2026-09-15 | FPS | [[FPS-Weaponary-Melee-Display-Fixes-And-Baton]] | Shop Melee Visibility, Detail Tabs, 3D Orientation, Stun and the Baton |
| 2026-09-15 | FPS | [[FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab]] | 3D Display Orientation, Baton Rebuild, Owned Shop Tab |
| 2026-09-15 | FPS | [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]] | Ten New Guns Had No Firing Mechanism |
| 2026-09-15 | FPS | [[FPS-Loadout-Expansion-10-New-Guns]] | Loadout Expansion — Ten New Weapons |
| 2026-09-13 | Robbery | [[Post-Move-Fixes-And-GUI-Polish]] | Post-Move Fixes + Duffel/Cash/Notification GUI Polish |
| 2026-09-13 | FPS | [[FPS-Weapon-Icon-Decals]] | Weapon Icon Decals |
| 2026-09-13 | FPS | [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]] | Hotbar Icon Clash Fix and Drag-and-Drop Feel |
| 2026-09-12 | Robbery | [[Timer-Hourglass-And-Duffel-Upgrade-GUI]] | Timer Hourglass Icon + Duffel Bar/Upgrade GUI |
| 2026-09-12 | Robbery | [[Performance-Optimization-And-Unification]] | Performance Optimization And Unification |
| 2026-09-12 | Robbery | [[NewsStation-Hacking-Randomize-Word-Button]] | NewsStation Hacking — Randomise Word Button |
| 2026-09-12 | Robbery | [[Global-Notifications-And-Location-Status-Billboards]] | Global Notifications + Location Status Billboards |
| 2026-09-12 | FPS | [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]] | Upgrade Button Style, Sound Volume Pass, Enemy Recoil, Respawn Timing, Hotbar Restyle, Player Card Photo Fix, Landing Slowdown |
| 2026-09-12 | FPS | [[FPS-Death-Screen-Text-Stuck-Fix-V2]] | Death Screen Text-Stuck Bug — Real Root Cause Fix |
| 2026-09-11 | FPS | [[FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System]] | Weapon Stat Billboard, Cash Currency, Damage Upgrade System |
| 2026-09-11 | FPS | [[FPS-Weapon-Pickups-And-Inventory-Integration]] | Weapon Pickup System and Custom Inventory Integration |
| 2026-09-11 | FPS | [[FPS-Spawner-Rework-Enemy-Nerf-Death-Inventory]] | Spawner Directory Rework, Enemy Damage/Accuracy/Recoil Nerf, Inventory Lock on Death |
| 2026-09-11 | FPS | [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]] | Rifle Enemy Rebalance, Death Camera Fix, Old Template Cleanup |
| 2026-09-11 | FPS | [[FPS-Remove-Sniper]] | Remove the Sniper (Snipex Alligator) |
| 2026-09-11 | FPS | [[FPS-Player-Card-System]] | Player Card System |
| 2026-09-11 | FPS | [[FPS-Melee-Combo-And-Shotgun-Reload-Refactor]] | Melee Swing Variation System, Shotgun Shell-by-Shell Reload |
| 2026-09-11 | FPS | [[FPS-Loadout-Rename-Burst-Expansion]] | Weapon Renames, Burst-Fire Mode, Six New Weapons |
| 2026-09-11 | FPS | [[FPS-Loadout-Orientation-Fix]] | Backwards Weapon Orientation Fix |
| 2026-09-11 | FPS | [[FPS-Loadout-Melee-Shotgun-Sniper]] | Melee, Shotgun, and Sniper Weapon Types |
| 2026-09-11 | FPS | [[FPS-Loadout-Expansion]] | Loadout Expansion (6 New Weapons) |
| 2026-09-11 | FPS | [[FPS-Loadout-Bugfixes-Sounds-VFX]] | Sniper Fire-Rate Fix, Orientation Audit, Shotgun/Crowbar Sound and VFX |
| 2026-09-11 | FPS | [[FPS-Kill-Leveling-System]] | Kill-Based Leveling System |
| 2026-09-11 | FPS | [[FPS-Inventory-Button-Fix-And-Hotbar-Slot-Count]] | Inventory Button Fix, Hotbar Slot Count Reduction |
| 2026-09-11 | FPS | [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]] | GUI Template Conversion, Cash Pickup Sound, Static Leveling Bar |
| 2026-09-11 | FPS | [[FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync]] | Equip Sound Fix and Crowbar Hit Sync |
| 2026-09-11 | FPS | [[FPS-Equip-Bug-Diagnosis-And-Inventory-Button]] | Equip Bug Diagnosis and Inventory Toggle Redesign |
| 2026-09-11 | FPS | [[FPS-Enemy-AI-6-Types]] | Six Enemy Types with Dedicated Debug Spawners |
| 2026-09-11 | FPS | [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]] | Death Screen Stuck-State Fix, Enemy Crowbar Desync, Lean/Turning Error Spam |
| 2026-09-11 | FPS | [[FPS-Death-Screen-Leveling-Tween-LevelUp-VFX]] | Death Screen, Tweened Leveling Bar, Level-Up Shine VFX |
| 2026-09-11 | FPS | [[FPS-Damage-Direction-Indicator-And-Prompt-Range]] | Damage Directional Indicator, Weapon Prompt Range Fix |
| 2026-09-11 | FPS | [[FPS-Crowbar-Knockback-Tune]] | Crowbar Knockback Tune |
| 2026-09-11 | FPS | [[FPS-Crowbar-Hitbox-And-Shotgun-Cooldown-Fix]] | Crowbar Hit Reliability, Shotgun Fire-Rate Increase |
| 2026-09-11 | FPS | [[FPS-Billboard-Scale-And-Cash-Drop-System]] | Billboard Scale-Up and Tiered Cash Drops |
