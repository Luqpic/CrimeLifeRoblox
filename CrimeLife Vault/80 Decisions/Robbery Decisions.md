---
type: decision
tags: [decision, robbery]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Getaway-Distance-Replaces-Claim-Zone.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Dialogue-On-Shared-Billboard-Engine.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Circle-Liquid-And-Glow.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Post-Move-Fixes-And-GUI-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/NewsStation-Hacking-Randomize-Word-Button.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Close-Button-Unified-With-FPS.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Timer-Hourglass-And-Duffel-Upgrade-GUI.md"]
---

# Robbery Decisions

Calls about the **Robbery System** place. The code is in [[Robbery Heists and Getaway]], [[Robbery Puzzles]] and [[Robbery Prompts]]. Never edit that place unless it is named explicitly.

## Newest first

- **2026-09-20: cash banks by getting 200 studs away**, not by walking into a claim zone; losing the escape to the timer is the intended failure, decided explicitly. [[Getaway-Distance-Replaces-Claim-Zone]]
- **2026-09-19: one dialogue engine for both places.** The Illegal Supplier moved onto the FPS dialogue engine and copies its behaviour (FOV pull with no blur; the HUD stays up). [[Supplier-Dialogue-On-Shared-Billboard-Engine]]
- **2026-09-19: the prompt shows only the key letter**, as a circle with a liquid fill; the developer confirmed it by eye. Same prompt in both places. [[Prompt-Circle-Liquid-And-Glow]]
- **2026-09-19: Robbery copies the FPS UI modules word for word**, because the two places are meant to merge later. [[Shared-UI-Effects-FOV-Blur-And-Sounds]] [[Close-Button-Unified-With-FPS]]
- **2026-09-13: the developer moved `DuffelBag` into `HeistShared`.** The same prompt drafted replacing the personal "Alarm triggered" toast with an "Alarm Triggered!" panel on the global notification; whether it ran is unconfirmed. [[Post-Move-Fixes-And-GUI-Polish]]
- **2026-09-12: "Randomise Word" gives 3 re-rolls per attempt**, not per round; the user was asked before the prompt was written. [[NewsStation-Hacking-Randomize-Word-Button]]
- **2026-09-12: the Bank stays off the shared `LocationServer`**, against what the prompt asked. [[Performance-Optimization-And-Unification]]
- **2026-09-12: duffel x2 / x4 upgrades are gamepasses** (see [[Cosmetics and Monetisation Decisions]]). [[Timer-Hourglass-And-Duffel-Upgrade-GUI]]
