---
type: decision
tags: [decision, vault, docs, workflow]
updated: 2026-11-14
sources: ["CLAUDE.md (How to work in this project, rule 5)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Batch Log.md", "CrimeLifeRoblox/.claude/skills"]
---

# Vault and Documentation Decisions

## Newest first

- **2026-11-14: CrimeLife moves to this vault.** The developer moved CrimeLife from per-change change logs plus the `CLAUDE.md` handover to this single Obsidian vault inside the `CrimeLifeRoblox` repo. Decided with it:
  - The 143 change logs moved unchanged into `70 Batches/FPS System/` and `70 Batches/Robbery System/`, indexed by date in [[Batch Log]]. New work gets a batch note and a line at the top of the Batch Log.
  - The duplicate `RobloxSystems/` clone was removed.
  - `PromptFolder/` (the original prompts: what was asked for, as opposed to what happened) moved into `90 Reference/Original Prompts/`.
  - The 23 `roblox-*` skills are available through the `CrimeLifeRoblox/.claude/skills` symlink; every system note carries a `Skills:` line naming the 1 to 3 that match.
- **Before 2026-11-14 (standing rule from `CLAUDE.md`): one change log per change**, Summary / Cause / Changes / Notes, a `Status:` line saying what was verified live and what still needs a person, and one commit per log (`Add change log: <what changed>`). Notes carry the reasoning and the disproved theories. Batch notes keep that honesty.
