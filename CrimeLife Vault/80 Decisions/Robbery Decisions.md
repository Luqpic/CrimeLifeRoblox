---
type: decision
tags: [decision, robbery]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Getaway-Distance-Replaces-Claim-Zone.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Dialogue-On-Shared-Billboard-Engine.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Circle-Liquid-And-Glow.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Post-Move-Fixes-And-GUI-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/NewsStation-Hacking-Randomize-Word-Button.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Close-Button-Unified-With-FPS.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Timer-Hourglass-And-Duffel-Upgrade-GUI.md"]
---

# Robbery Decisions

Calls about the **Robbery System** place. The code is in [[Robbery Heists and Getaway]], [[Robbery Puzzles]] and [[Robbery Prompts]]. Never edit that place unless it is named explicitly.

## Newest first

- **2026-11-20 late night: a dead robber's bag drops for 2 minutes and anyone can take it.** The developer: "if a player dies, they drop their duffelbag in which other players or themselves can carry"; pickers "2 minutes" and "Anyone". The picker joins that run of the robbery and banks through the location's normal getaway; the bag also goes when the run ends (Claude). [[2026-11-20 Smooth Enemies Patrols and Dropped Duffels]]
- **2026-11-20 morning: armed police stay upstairs; police also spawn after the obby pit.** The developer: "just stay at teh upper level of teh bank, only teh normal polices come to teh vault ... I don't want it ot be overcrowded in teh vault" and "Polices also spawn right after the obby pit so players can have a gun fight while stayong inside of the money vault". Picker: "Split each wave" (old spawn and after-pit spawn in turn). Claude's placement: the after-pit spawns between the glass wall and the vault corridor; the armed police fight only robbers in the lobby. [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **2026-11-20 morning: the Bank's guards walk.** "The police and security that was replaced as a dummy didn't move at all". Picker: "Patrol, then cover". Claude's ruling: Security (Baton) chases within 20 studs of its post instead of taking cover. [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **2026-11-20 morning: guards pay only during a robbery.** "Pay should start after robbery"; picker "Only during a robbery". [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **2026-11-20: big robberies send police inside after a few minutes.** The developer asked "for Big robberies like bank, spawn in a few police first after a few minutes" and clarified: "I meant when you start the robbery, the police will come after a few minutes". Picker answers: Bank "3 at 2:00, +2 every 90 s" (cap 8); NewsStation 2 at 2:00, +1 every 90 s (cap 4); scope "Bank + NewsStation" (SlowFoods and Gas2Go unchanged). Claude's ruling: the stars and HUD still rise at the alarm, but the star squad is held until the first wave. [[2026-11-20 Heist Police and Bank Guards]]
- **2026-11-20: the Bank's vault dummies become Security and Police guards.** They fight "once the robbery starts" (or when attacked); outside a robbery they stay passive and a dead guard returns after 60 s. [[2026-11-20 Heist Police and Bank Guards]]
- **2026-11-20: opening the rolling vault brings Armed Police.** Picker answer "4 now, +2 every 60 s, cap 8". Claude's ruling: they spawn at the B-arrival markers (a vault-side set is an open question). [[2026-11-20 Heist Police and Bank Guards]]
- **2026-11-20: guards fire real shots and Security strikes only in reach; NewsStation guards are Police rigs.** Claude's rulings in the combat batch: guards use the same tokens, aim line and bursts as every NPC shooter; a Baton guard turns first and strikes within 6 studs only. [[2026-11-20 Readable Gunfights and Level Toughness]]
- **2026-11-18: heavy carries get the getaway distance widget**: the ripped ATM and the gold bar show the same 200-stud widget as the duffel. [[2026-11-18 Open Items Pass]]
- **2026-09-20: cash banks by getting 200 studs away**, not by walking into a claim zone; losing the escape to the timer is the intended failure, decided explicitly. [[Getaway-Distance-Replaces-Claim-Zone]]
- **2026-09-19: one dialogue engine for both places.** The Illegal Supplier moved onto the FPS dialogue engine and copies its behaviour (FOV pull with no blur; the HUD stays up). [[Supplier-Dialogue-On-Shared-Billboard-Engine]]
- **2026-09-19: the prompt shows only the key letter**, as a circle with a liquid fill; the developer confirmed it by eye. Same prompt in both places. [[Prompt-Circle-Liquid-And-Glow]]
- **2026-09-19: Robbery copies the FPS UI modules word for word**, because the two places are meant to merge later. [[Shared-UI-Effects-FOV-Blur-And-Sounds]] [[Close-Button-Unified-With-FPS]]
- **2026-09-13: the developer moved `DuffelBag` into `HeistShared`.** The same prompt drafted replacing the personal "Alarm triggered" toast with an "Alarm Triggered!" panel on the global notification; whether it ran is unconfirmed. [[Post-Move-Fixes-And-GUI-Polish]]
- **2026-09-12: "Randomise Word" gives 3 re-rolls per attempt**, not per round; the user was asked before the prompt was written. [[NewsStation-Hacking-Randomize-Word-Button]]
- **2026-09-12: the Bank stays off the shared `LocationServer`**, against what the prompt asked. [[Performance-Optimization-And-Unification]]
- **2026-09-12: duffel x2 / x4 upgrades are gamepasses** (see [[Cosmetics and Monetisation Decisions]]). [[Timer-Hourglass-And-Duffel-Upgrade-GUI]]
