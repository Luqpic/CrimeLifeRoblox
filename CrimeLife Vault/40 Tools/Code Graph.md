---
type: tool
tags: [tool, graphify, code]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/graphify-out/GRAPH_REPORT.md", "CrimeLifeRoblox/graphify-out/manifest.json", "CrimeLifeRoblox/.gitignore", "~/.claude/skills/graphify/SKILL.md", "OBT Vault/40 Tools/Code Graph.md (shape)"]
---

# Code Graph

How to find CrimeLife code and history without reading whole files.

## What exists today

- **`CrimeLifeRoblox/graphify-out/`** (`graph.json`, `graph.html`, `GRAPH_REPORT.md`, `manifest.json`), built **2026-09-19**. It is git-ignored ("Generated knowledge-graph output. Rebuilt on demand, not source.").
- **It is a graph of the change logs, not of the code.** Its manifest lists 67 Markdown files: 62 under `FPSSystem/` and 5 under `RobberySystem/`. 287 nodes, 264 edges, 42 communities (28 shown). Hubs include "Cash Economy and UI Theming", "Enemy Spawning and Roster", "Weapon Shop and Upgrades", "Robbery Panels and Gamepasses"; god nodes include `ServerStorage.EnemyTemplates`, `LevelingService` and `WeaponShopService` (7 edges each).
- **It is stale.** It covers 67 of the 143 change logs, and on 2026-11-14 the change logs moved from `FPSSystem/*.md` and `RobberySystem/*.md` into `CrimeLife Vault/70 Batches/`, so its file paths no longer exist.
- Its own report says the corpus "fits in a single context window. You may not need a graph."

## Use it (or don't)

| Question | Cheapest tool |
|---|---|
| Where a literal string is used (an attribute, a remote, a module name) in the mirrors | `grep -rn --include='*.luau' '<name>' CrimeLifeRoblox/FPSSystem` |
| Where it is used in the **live place** (the source of truth; the mirrors are a subset) | Studio MCP `script_grep` / `script_search`, then `script_read` |
| Which instances exist and where | Studio MCP `search_game_tree`, `inspect_instance` |
| Why something was built a way, what was tried before | grep `70 Batches/` (Notes sections), or the graph after a rebuild |
| What the developer originally asked for | [[Original Prompts]] |

The 40 code mirrors are small enough that grep is the right tool. A graphify graph of them has not been built (not recorded).

## Rebuild

If a graph of the history is wanted, rebuild it with the graphify skill (`/graphify`) over `CrimeLife Vault/70 Batches/`, with the output kept in `CrimeLifeRoblox/graphify-out/`. **Never write graphify's Obsidian export into this vault**: it writes one note per node and would bury the curated notes.

## Limits

- Instances, attributes set in Edit and GUI trees are not code: read them in Studio.
- A grep hit can be a **comment documenting the absence** of a thing; confirm it is code. This caused two false conclusions (`DataStoreService` and `UIListLayout`) per the persistence phase 3 plan ([[Luau and Scripting Traps]]).

## Related

[[Tools MOC]] · [[Studio MCP Gotchas]] · [[Docs Index]]
