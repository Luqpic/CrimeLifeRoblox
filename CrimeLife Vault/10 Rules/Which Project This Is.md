---
type: rule
tags: [rule, project, places, studio]
updated: 2026-11-14
sources: ["CLAUDE.md (Roblox Development, Operating Context; Outbreak Tycoon section)", ".superpowers/sdd/skins-card-sticky-fix-report.md", ".superpowers/sdd/2026-09-23-renown-phase-2/task-1-report.md"]
---

# Which Project This Is

## Rule

- **This vault is CrimeLife.** The primary place is **FPS System** (`Roblox Games/FPS System.rbxl`). Work targets it unless the developer names another place.
- **Robbery System** (`Roblox Games/Robbery System.rbxl`) shares UI modules with FPS System but is a **separate project: never edit it unless it is named explicitly.** Its 22 historical change logs are in `70 Batches/Robbery System/`.
- **Outbreak Tycoon (OBT)** ("Outbreak Tycoon: New Generation", PlaceId 6354227383, mirror `studio-mirror/`, vault `OBT Vault/`) is a different game with its own rules. Never edit it from a CrimeLife session, and never apply OBT's tooling (`push.py`, `drift.py`, `_tools/`, `_build/`) here.
- **Confirm the attached Studio instance is the FPS System place before any write.** `list_roblox_studios`, then `get_studio_state` / a read of `game.PlaceId` and the window name.
- **Studio is the source of truth.** The `.luau` files in `CrimeLifeRoblox/FPSSystem/` are exported mirrors; changing a local file alone does not update Studio.

## Places (do not edit unless named)

| Place | What it is |
|---|---|
| `Roblox Games/FPS System.rbxl` | CrimeLife's FPS place. **The target.** Seen in Studio as "FPS System Upgraded", PlaceId 87650598860298 (2026-09-24). |
| `Roblox Games/Robbery System.rbxl` | Robbery prompts, heists, getaway. Shares `UI.*` modules. Named-only. |
| `Roblox Games/Crimelife city*.rbxl`, `CrimeLife Tycoon Building .rbxl`, `Crimelife Building (last saved 2023).rbxl` | Older CrimeLife places on disk. What they hold is not recorded; read-only unless named. |
| OBT places (`Outbreak Tycoon*.rbxl`, `OBT*.rbxl`, `Walker Animation*.rbxl`) | Another project. Never. |

More: [[Places and Studio Windows]].

## Why

- `CLAUDE.md`: "A second place, Robbery System, shares UI modules with it but is a separate project — never edit it unless it is named explicitly." and "Confirm the attached instance is the FPS System place before any write."
- The Studio instance id changes when Studio restarts, so a stale id can point at the wrong window.
- Both CrimeLife and OBT run on the same Mac and the same MCP server; a session that mixes them writes to the wrong game.

## How to apply

- At session start: `list_roblox_studios`, pick the FPS System window, read its PlaceId back, then work. Record the id in the batch note if it changed ([[Studio Host and Instance Id]]).
- A shared UI module copied between places (for example `PromptUI`, `Transitions`) is changed in Robbery System only when the developer names it; say in the report which place you changed.
