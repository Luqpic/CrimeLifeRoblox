---
type: decision
tags: [decision, vault, docs, workflow]
updated: 2026-11-20
sources: ["CLAUDE.md (How to work in this project, rule 5)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Batch Log.md", "CrimeLifeRoblox/.claude/skills"]
---

# Vault and Documentation Decisions

## Newest first

- **2026-11-20: the city is the cloud place "Crimelife Tycoon"**, published privately into SolarArc Studios by the developer so group animations load; run mode "Hybrid" (Opus implementers, one merged build task, one Sonnet review per feature); "Yes, save after each task" for that night, never publish. [[Admin, Animation and Camera Decisions]] [[Save and Publish Rules]] [[2026-11-20 Admin Animations Third Person]]
- **2026-11-18: only the vault's Roblox skills, and Opus with Sonnet.** Never an Anthropic or other skill unless the developer names one; Opus for judgement, Studio and code, Sonnet subagents for searches, per-task reviews and drafts. [[Vault Skills Only and Model Routing]] [[Model Assignment]] [[2026-11-18 Open Items Pass]]
- **2026-11-18: by-hand checks come as one ordered checklist** at the end of a batch, run when the developer has time, rather than a live session. [[2026-11-18 Open Items Pass]]
- **2026-11-18: `Documents/Roblox/CLAUDE.md` updated by Claude** at the developer's word: Crimelife City is the primary place, plus the skills and models rule line. [[2026-11-18 Open Items Pass]]
- **2026-11-14: CrimeLife moves to this vault.** The developer moved CrimeLife from per-change change logs plus the `CLAUDE.md` handover to this single Obsidian vault inside the `CrimeLifeRoblox` repo. Decided with it:
  - The 143 change logs moved unchanged into `70 Batches/FPS System/` and `70 Batches/Robbery System/`, indexed by date in [[Batch Log]]. New work gets a batch note and a line at the top of the Batch Log.
  - The duplicate `RobloxSystems/` clone was removed.
  - `PromptFolder/` (the original prompts: what was asked for, as opposed to what happened) moved into `90 Reference/Original Prompts/`.
  - The 23 `roblox-*` skills are available through the `CrimeLifeRoblox/.claude/skills` symlink; every system note carries a `Skills:` line naming the 1 to 3 that match.
- **Before 2026-11-14 (standing rule from `CLAUDE.md`): one change log per change**, Summary / Cause / Changes / Notes, a `Status:` line saying what was verified live and what still needs a person, and one commit per log (`Add change log: <what changed>`). Notes carry the reasoning and the disproved theories. Batch notes keep that honesty.
