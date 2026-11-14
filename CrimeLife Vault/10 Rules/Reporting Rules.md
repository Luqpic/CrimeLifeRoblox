---
type: rule
tags: [rule, reporting, vault]
updated: 2026-11-14
sources: ["CLAUDE.md (How to work in this project, items 4-5)", "OBT Vault/10 Rules/Reporting Rules.md (adapted)", "git log of Luqpic/CrimeLifeRoblox"]
---

# Reporting Rules

## Rule

- **Separate what was verified from what was not.** Say plainly which parts were confirmed live and which still need a person (a click by a real mouse, a look at the screen, a second player, a published place). This was the old change logs' `Status:` line; it is now the batch note's **Verified** and **Not verified** sections.
- **Cite the numbers**, before and after ([[Measure Before and After]]). A change that cannot cite a before and after number is not finished.
- **Keep the reasoning and the disproved theories.** They are the most valuable part of the archive (for example [[FPS-Dialogue-Responses-Clickable-Fix]] records two wrong explanations so they are not tried again; [[Prompt-Circle-Liquid-And-Glow]] records four).
- **Say when a check could not be done and why** (a collapsed viewport, a magenta capture, no second player). "Not verified" is honest; a silent gap is not.
- **End every report with the save state**, normally **"NOT saved / NOT published"** ([[Save and Publish Rules]]).
- **Write it down every batch** (from 2026-11-14): a batch note, the touched system notes, [[Open Items]], decisions and traps, then one commit `Batch: <topic>` ([[Batch Workflow]]).

## Why

- `CLAUDE.md`: "Every change log carries a `Status:` line and says plainly which parts were confirmed live and which still need a person. Keep that honesty." and "Notes carry the reasoning and the disproved theories — those are the most valuable part of the archive."
- Until 2026-11-13 the record was one markdown change log per change (Summary / Cause / Changes / Notes) and one commit `Add change log: <what changed>`. On 2026-11-14 the developer moved to this vault and batch notes.

## How to apply

- Report shape: what changed, what was measured (before / after), verified, not verified, needs you, then "NOT saved / NOT published".
- A test that passed "for the wrong reason" is called out as such: [[FPS-Persistence-Phase-3]] found `expect.throws(Gateway.migrate)` satisfied by calling `nil`.
