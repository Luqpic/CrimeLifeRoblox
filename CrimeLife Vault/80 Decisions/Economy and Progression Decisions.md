---
type: decision
tags: [decision, economy, progression, persistence, quests]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Leveling-System.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponary-Shop-Refactor.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Feedback-NPC-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Revert-Global-Spraypaint-Balance.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-renown-phase-2-design.md"]
---

# Economy and Progression Decisions

Calls about Cash, XP, levels, quests and saving. The code is in [[Economy and Cash]], [[Weapon Shop and Upgrades]], [[Leveling and Renown]], [[Quests and Dialogue]] and [[Persistence and Saves]]. Spraypaint and skin prices are in [[Cosmetics and Monetisation Decisions]].

## Newest first

- **2026-11-20 morning: no free starter gun; weapons go gacha.** The developer: "NO free gun, actually I want to revamp the weaponary. Instead of buying, we are doing gacha." A future batch. [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **2026-11-20: levels add health and a little armor.** Picker answer "Health + armor by level". Claude's numbers: max health 100 + 4 a level (376 at 70, was +2), armor 0.4 % a level up to 25 % against NPC damage, regen 6 % a second after 6 s without a loss. No free starter gun was added: a new player owns only the Crowbar and the Glock 17 costs 400 of the 500 starting cash, so the target was measured with the Glock and a Crowbar rush. The free starter gun is left to the developer (see [[Open Items]]). [[2026-11-20 Readable Gunfights and Level Toughness]]
- **2026-11-18: no lifetime "cash earned" stat** on the player card for now; the pill keeps the current balance. [[2026-11-18 Open Items Pass]]
- **2026-09-24: seven criminal ranks of ten levels each**; a player never sees their own overhead plate. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- **2026-09-24: a fresh buy goes straight to the slot picker.** [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- **2026-09-24: the save schema only moves forward.** When per-weapon Spraypaint was reverted, the schema went to version 3, not back to 1, so profiles already on version 2 are not locked out. Never roll the version back. [[Revert-Global-Spraypaint-Balance]]
- **2026-09-23: progression is saved with ProfileStore.** Spec decisions: ProfileStore rather than a hand-written session lock; a profile that failed to load is never written (retry, then remove the player with a specific message); services keep their shape; ProfileStore's API lives in exactly one module. Non-goals: no Robux-to-Spraypaint product, no leaderboards. Quest progress is not saved. (`docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md`, [[FPS-Persistence-Phase-3]]) This supersedes the older line in `CLAUDE.md` that progression is session-only.
- **2026-09-23: Spraypaint is earned by kills and level-ups**, not survival time, which would reward idling. (`docs/superpowers/specs/2026-09-23-renown-phase-2-design.md`)
- **2026-09-17: the police-side enemies leave the quest ladder** (they are moving to the Robbery place); levels 10, 35 and 70 ask for Smuggler, Bandits and Saboteur. Shotgun enemies paying at the pistol rate is accepted. [[FPS-Enemy-Roster-Rework-3-New-Recruits]]
- **2026-09-16: level cap 70**, quest givers at levels 10, 20, 35, 50 and 70; admin `/setlevel` and an F2 panel limited to the developer's UserId. [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]]
- **2026-09-16: quests are repeatable**; hand-in shows one bottom-left toast (a centre banner was built, then removed). [[FPS-Quest-Feedback-NPC-Polish]]
- **2026-09-16: upgrades add +5 damage per level** (the log calls it a placeholder); upgrades key on (player, weapon type). [[FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix]]
- **2026-09-16: ownership is permanent and uncapped, with 4 carry slots; buying no longer equips.** The log states this "so it can be reversed if unwanted"; the equip part was superseded on 2026-09-24 by buy-to-slot-pick. [[FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots]]
- **2026-09-15: the Weaponary shop replaces the 16 world pickups**, archived (`ServerStorage.ArchivedWeaponPickups`), not deleted. [[FPS-Weaponary-Shop-Refactor]]
- **2026-09-11: PvP kills give XP; Cash stays enemy-only.** [[FPS-Kill-Leveling-System]]
