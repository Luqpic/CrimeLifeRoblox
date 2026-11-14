---
type: reference
tags: [vault, conventions]
updated: 2026-11-14
sources: ["OBT Vault/Vault Conventions.md (adapted)", "CLAUDE.md (How to work in this project, item 5)", "git log of Luqpic/CrimeLifeRoblox"]
---

# Vault Conventions

This vault is the **source of truth** for CrimeLife development (FPS System and Robbery System places). When the vault and an older document disagree, the vault wins. The project section of `Documents/Roblox/CLAUDE.md` is kept as a short pointer here; its long-form content is frozen in [[Handover Snapshot 2026-11-14]].

Core Obsidian only. No community plugins, so nothing here depends on Dataview, Templater or similar. Everything is plain Markdown with wikilinks.

## Where the vault lives

`Documents/Roblox/CrimeLifeRoblox/CrimeLife Vault/`, inside the CrimeLifeRoblox git repo (remote `Luqpic/CrimeLifeRoblox`, branch `main`). The vault is versioned with the code mirrors in `CrimeLifeRoblox/FPSSystem/`. `.gitignore` leaves out `.obsidian/workspace*.json`, `.DS_Store` and `graphify-out/`.

## Folders

| Folder | Holds | One note per |
|---|---|---|
| `00 Start` | Where to begin, the batch workflow | topic |
| `10 Rules` | How the developer wants work done (standing rules) | rule or rule group |
| `20 Systems` | What exists in the game and where it lives | system |
| `30 How-To` | Recipes for adding or changing things along the data path | recipe |
| `40 Tools` | Studio MCP mechanics, the unit test runner, test methods | tool or mechanic |
| `50 Engine Traps` | Roblox engine behaviour that cost a debugging session | trap group |
| `60 Open Items` | What is still open, unverified, or waiting on the developer | list |
| `70 Batches` | One note per batch of work, plus the historical change logs | batch |
| `80 Decisions` | Product decisions the developer made | decision area |
| `90 Reference` | Places, pipelines, original prompts, an index of outside docs | topic |
| `99 Archive` | Frozen snapshots kept so nothing is lost; never edited | snapshot |
| `Templates` | Note templates for the core Templates plugin | template |

Each folder has a map-of-content note (for example `Systems MOC`, `Rules MOC`). Every note is linked from its MOC.

## Notes

- **Names are unique across the vault** and short, in Title Case: `Weapons and Blaster`, `Unit Test Runner`. Batch notes start with their date: `2026-11-20 Shotgun Spread Fix`. The historical change logs keep their old file names (`FPS-Persistence-Phase-3`) and are linked as `[[FPS-Persistence-Phase-3]]`.
- **Frontmatter** on every note:
  ```yaml
  ---
  type: system | rule | howto | tool | trap | open | batch | decision | reference | moc | archive
  tags: [ ... ]
  updated: YYYY-MM-DD
  sources: [ "CLAUDE.md (Known traps)", "70 Batches/FPS System/<change log>.md" ]
  ---
  ```
  `sources` names where the content came from, as paths relative to `Documents/Roblox` (or vault paths).
- **Links:** `[[Note Name]]` for vault notes. Files outside the vault are written as code paths (`CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau`), because Obsidian cannot open them.
- **Instance paths** are code: `ReplicatedStorage.UI.Theme`, `ServerScriptService.Blaster.Scripts.ShotResolver`.
- **Dates** are absolute (`2026-11-14`), never "yesterday".
- **Numbers are measured or marked "not recorded".** Never invent a figure.
- **People:** the developer and Claude. Use they/them for anyone whose pronouns were not stated.
- **Never** write secrets into the vault: no Open Cloud key, no Figma token, no API tokens, no cookies, no webhook URLs.

## The change-log routine it replaces (until 2026-11-13)

Every change used to get one markdown change log in `CrimeLifeRoblox/FPSSystem/` (or `RobberySystem/`) with Summary / Cause / Changes / Notes sections and a `Status:` line, and one commit `Add change log: <what changed>`. Those 143 logs moved to `70 Batches/FPS System/` (121) and `70 Batches/Robbery System/` (22) unchanged on 2026-11-14 and stay readable history.

## Keeping it true (from 2026-11-14)

Every batch ends by updating the vault (see [[Batch Workflow]]):

1. Add a batch note in `70 Batches/` from [[Batch Note Template]], named `YYYY-MM-DD Topic`, and a line at the **top** of the table in [[Batch Log]].
2. Update the `20 Systems` notes the batch touched (`updated:` date too).
3. Move closed items out of [[Open Items]]; add new ones.
4. Add any new developer decision to its `80 Decisions` note, quoting the developer.
5. Add a new engine trap to `50 Engine Traps` when one cost time ([[Engine Traps MOC]]).
6. One git commit in the CrimeLifeRoblox repo: `Batch: <topic>`. Do not push unless the developer asks.

The old change logs' spirit carries into the batch template: **Asked for** and **What changed** replace Summary and Changes; the root cause goes in **What changed**; the **reasoning and the disproved theories**, the most valuable part of the archive, go in **Decisions** and **Verified / Not verified** (add a "Disproved" list when there was one). The old `Status:` line becomes the Verified / Not verified split.
