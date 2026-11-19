---
type: rule
tags: [rule, project, places, studio]
updated: 2026-11-20
sources: ["CLAUDE.md (Roblox Development, Operating Context; Outbreak Tycoon section)", ".superpowers/sdd/skins-card-sticky-fix-report.md", ".superpowers/sdd/2026-09-23-renown-phase-2/task-1-report.md"]
---

# Which Project This Is

## Rule

- **This vault is CrimeLife.** From 2026-11-15 the primary place is **Crimelife City**; since 2026-11-20 it is the cloud place **"Crimelife Tycoon"** (placeId 128488619644399, universe 10777869898, owned by the SolarArc Studios group 4998611). The developer published the city into the group privately on 2026-11-20 so the group animation clips load. In Studio, save makes a place version and is never a publish. The local file `Roblox Games/Crimelife city.rbxl` is no longer the working copy. Work targets it unless the developer names another place. **FPS System** (`Roblox Games/FPS System.rbxl`) is **frozen** as the reference the port was taken from: it is not edited. Until 2026-11-14 it was the primary place.
- **Robbery System** (`Roblox Games/Robbery System.rbxl`) shares UI modules with FPS System but is a **separate project: never edit it unless it is named explicitly.** Its 22 historical change logs are in `70 Batches/Robbery System/`.
- **Outbreak Tycoon (OBT)** ("Outbreak Tycoon: New Generation", PlaceId 6354227383, mirror `studio-mirror/`, vault `OBT Vault/`) is a different game with its own rules. Never edit it from a CrimeLife session, and never apply OBT's tooling (`push.py`, `drift.py`, `_tools/`, `_build/`) here.
- **Confirm the attached Studio instance is the Crimelife City place before any write** (from 2026-11-15; before that it named FPS System). `list_roblox_studios`, then `get_studio_state` / a read of `game.PlaceId` (128488619644399 for the cloud city) and the window name.
- **Studio is the source of truth.** The `.luau` files in `CrimeLifeRoblox/FPSSystem/` are exported mirrors of the FPS place as it was exported; changing a local file alone does not update Studio. Two scripts in the city now deviate from the FPS place (`StarterPlayer.StarterCharacterScripts.Lean`, which has no mirror, and `StarterPlayer.StarterPlayerScripts.WeaponaryShopController`), and `FPSSystem/Cosmetics/WeaponaryShopController.luau` is an out-of-date mirror ([[2026-11-15 FPS Systems Into City]]).

## Places (do not edit unless named)

| Place | What it is |
|---|---|
| Cloud place "Crimelife Tycoon" (placeId 128488619644399, universe 10777869898, SolarArc Studios group 4998611) | The city map with the FPS systems and the four heists. **The target (primary place) since 2026-11-20.** Studio save makes a place version, never a publish. |
| `Roblox Games/Crimelife city.rbxl` | The city's local file: the working copy from 2026-11-15 to 2026-11-20, **no longer the working copy**; a snapshot. |
| `Roblox Games/FPS System.rbxl` | CrimeLife's FPS place. **Frozen from 2026-11-15** as the reference the port was taken from; not edited. Until 2026-11-14 it was the target. Seen in Studio as "FPS System Upgraded", PlaceId 87650598860298 (2026-09-24). |
| `Roblox Games/Robbery System.rbxl` | Robbery prompts, heists, getaway. Shares `UI.*` modules. Named-only. |
| `Roblox Games/Crimelife city copy.rbxl`, `Crimelife city BACKUP pre-cleanup 2026-08-20.rbxl`, `CrimeLife Tycoon Building .rbxl`, `Crimelife Building (last saved 2023).rbxl` | Older CrimeLife places on disk. What they hold is not recorded; read-only unless named. |
| OBT places (`Outbreak Tycoon*.rbxl`, `OBT*.rbxl`, `Walker Animation*.rbxl`) | Another project. Never. |

More: [[Places and Studio Windows]].

## Why

- (As written before 2026-11-15; `Documents/Roblox/CLAUDE.md` still names FPS System, an open item for the developer.) `CLAUDE.md`: "A second place, Robbery System, shares UI modules with it but is a separate project — never edit it unless it is named explicitly." and "Confirm the attached instance is the FPS System place before any write."
- 2026-11-15 (Claude's call, following the approved design; the developer chose the city as the merge target on 2026-11-14): the FPS systems now live in the city as an exact copy ([[2026-11-15 FPS Systems Into City]]), so new work goes there and the FPS place stays as the unedited reference to compare against ([[CrimeLife Tycoon Decisions]]).
- The Studio instance id changes when Studio restarts, so a stale id can point at the wrong window.
- Both CrimeLife and OBT run on the same Mac and the same MCP server; a session that mixes them writes to the wrong game.

## How to apply

- At session start: `list_roblox_studios`, pick the Crimelife City window, read its PlaceId back, then work. Record the id in the batch note if it changed ([[Studio Host and Instance Id]]).
- A shared UI module copied between places (for example `PromptUI`, `Transitions`) is changed in Robbery System only when the developer names it; say in the report which place you changed.
