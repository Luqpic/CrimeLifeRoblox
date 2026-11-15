---
type: howto
tags: [start, workflow]
updated: 2026-11-15
sources: ["OBT Vault/00 Start/Batch Workflow.md (adapted)", "CLAUDE.md (How to work in this project)", "docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium)"]
---

# Batch Workflow

One batch = one request from the developer (one or several items). Run every batch through these steps. From 2026-11-14 the batch note replaces the old "one change log per change" routine.

## 1. Ask first, read first

- Read the request, [[Open Items]] and the `20 Systems` notes it touches. For the original intent behind a system, read its prompt in [[Original Prompts]].
- Put every question the developer has to answer in one round of pickers, recommended option first, then build to the end. [[Ask First Then Build]]
- Confirm the attached Studio instance is the Crimelife City place before any write (FPS System is frozen from 2026-11-15). [[Which Project This Is]]
- Load the 1 to 3 Roblox skills the task touches (the system note's `Skills:` line, or [[Roblox Skills]]). CrimeLife's way wins over a skill's generic advice.

## 2. Reproduce and measure

- **Read before you edit.** Confirm the real instance path in Studio (`search_game_tree`, `inspect_instance`, `script_read`): the instance tree in older notes came from the change-log archive, not a live read.
- Reproduce each bug with numbers before changing code (distances, climb rate, loudness peaks, absolute positions, counts). [[Measure Before and After]]
- Name the root cause, and fix it in the shared module every caller routes through. Grep every caller first. [[Shared Code Extended by Attributes]]
- Write down each theory you disprove. It goes in the batch note.

## 3. Build

- Edit the script in Studio (the source of truth), then update its mirror in `CrimeLifeRoblox/FPSSystem/<area>/` so the repo matches. A local `.luau` edit alone does not change Studio.
- After any `Source` edit, read `Source` back: check the length moved as expected, the new text is present (`string.find(src, needle, 1, true)`) and the old text is gone. `string.gsub` with magic characters silently replaces nothing ([[Luau and Scripting Traps]]).
- Weapon behaviour goes in as an opt-in Tool attribute that the shared blaster code reads. [[Shared Code Extended by Attributes]]
- Edit-time instance builds (viewmodels, new guns) go through a re-runnable build script. [[Building Rules]]
- Keep it cheap on phones. [[Phones First and Keep Optimised]]

## 4. Verify

- Run the relevant suites in a **fresh Play session, Server datamodel**, never from Edit. [[Unit Test Runner]]
- Read the result back (`AbsolutePosition`, `AbsoluteSize`, `AbsoluteCanvasSize`, attributes) and take a screenshot when the viewport allows it. [[Verify in Edit and by Screenshot]], [[Screen Captures]]
- Fire and poll timing-sensitive checks inside a single `execute_luau` call. [[Studio MCP Gotchas]]
- Re-measure the numbers from step 2.

## 5. Update the vault

1. New batch note from [[Batch Note Template]] in `70 Batches/`, named `YYYY-MM-DD Topic`, and a line at the **top** of the table in [[Batch Log]] (Date, Place, Batch, What).
2. Update touched `20 Systems` notes and their `updated:` date.
3. Close and add items in [[Open Items]].
4. New decisions into `80 Decisions` ([[Decisions MOC]]); new traps into `50 Engine Traps` ([[Engine Traps MOC]]).
5. Keep the change logs' best part: the reasoning and the disproved theories, in the batch note.

## 6. Commit

- One commit in `Documents/Roblox/CrimeLifeRoblox` for the batch: `Batch: <topic>`. It carries the batch note, the vault updates and the touched `.luau` mirrors.
- Do not push unless the developer asks.

## 7. Report

- What changed, what was verified (with the before and after numbers), what was not, what needs the developer.
- End with **NOT saved / NOT published**. [[Reporting Rules]]
