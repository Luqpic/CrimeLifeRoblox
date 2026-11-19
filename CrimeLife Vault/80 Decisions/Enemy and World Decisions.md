---
type: decision
tags: [decision, enemies, npc, movement]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Sprint-Landing-Dead-Stop.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-All-Landings-Dead-Stop.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Givers-Law-Enforcement-Outfits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Miss-Tracers-And-Spawn-Cap.md"]
---

# Enemy and World Decisions

Calls about enemies, NPCs and how the player moves. The code is in [[Enemies and Spawner]], [[Movement and Stamina]] and [[Quests and Dialogue]].

## Newest first

- **2026-11-20: an enemy shooter is limited to a readable rhythm.** At most 2 shooters fire at one player; the first shot waits behind a visible red aim line; aim tightens over 2 s; guns fire in bursts; shots lose damage with distance (x1 to 25 studs, x0.5 from 90). Melee enemies are exempt from tokens, the line and bursts. Developer's words and picker answers: see [[Weapon and Combat Decisions]]. [[2026-11-20 Readable Gunfights and Level Toughness]]
- **2026-11-20: heist police share `POLICE_CAP` 24 with the star squads** and never remove a squad officer; a wave with no room waits. The star squad waits for the first heist wave (2:00) when its player is in the robbery. [[2026-11-20 Heist Police and Bank Guards]]
- **2026-11-18: a character reset keeps the wanted stars.** A death with no damage in the last 5 s carries the stars into the new life; a death after real damage still clears them and forfeits the haul. [[2026-11-18 Open Items Pass]]
- **2026-11-18: police search the last-seen spot** in the 20 s search window instead of following the robber's live position; they re-engage only on sight. [[2026-11-18 Open Items Pass]]
- **2026-11-18: kept in the place:** the old VFX leftovers (Workspace blood particle, `LevelUpShine`, the unwired `Hiteffect`), `Workspace.Dev.UI.OverheadGui` and its Script, and the spare `Plot7` / `Plot8` plates with the origin Baseplate. The JakeDev UI Animation Pack was the one pick for quarantine; it is not in the city (it was in the FPS place only). [[2026-11-18 Open Items Pass]]
- **2026-09-24: quest givers wear Security, Police or SWAT uniforms by tier.** [[FPS-Quest-Givers-Law-Enforcement-Outfits]]
- **2026-09-20: every landing is a dead stop**, not only sprint landings (sprint-only came first, 2026-09-19). [[FPS-All-Landings-Dead-Stop]] [[FPS-Sprint-Landing-Dead-Stop]]
- **2026-09-17: the roster rework.** Security, Police and Armed Police stop spawning in the FPS place (they are going to the Robbery place); Criminal becomes Offender and Armed Criminal becomes Disrupters; Smuggler, Bandits and Saboteur are added; the spawn cap applies per type. [[FPS-Enemy-Roster-Rework-3-New-Recruits]] The crowd was later halved. [[FPS-Miss-Tracers-And-Spawn-Cap]]
