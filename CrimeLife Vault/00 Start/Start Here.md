---
type: reference
tags: [start]
updated: 2026-11-14
sources: ["CLAUDE.md (Roblox Development, Operating Context)", ".superpowers/sdd/skins-card-sticky-fix-report.md", ".superpowers/sdd/2026-09-23-renown-phase-2/task-1-report.md", "git log of Luqpic/CrimeLifeRoblox"]
---

# Start Here

## Which project this is

- **This vault:** CrimeLife, a Roblox crime game built from two places that share UI modules. See [[Which Project This Is]].
  - **FPS System** (`Documents/Roblox/Roblox Games/FPS System.rbxl`): the primary place. Guns and melee, enemies, quests, shop, cosmetics, leveling, persistence.
  - **Robbery System** (`Documents/Roblox/Roblox Games/Robbery System.rbxl`): the sister place (robbery prompts, heists, getaway). A separate project: **never edit it unless the developer names it**.
- Live Studio access runs through the `Roblox_Studio` MCP server (`Documents/Roblox/.mcp.json`). Run `list_roblox_studios` and **confirm the attached instance is the FPS System place before any write**.
- Last recorded Studio instance: `e72599f8-83cc-49ef-a389-c6be7ed27e4d`, "FPS System Upgraded", PlaceId 87650598860298 (2026-09-24). Earlier: `ea0a6094-7699-4852-be8a-dc37e0a66ab1` ("FPS System.rbxl", 2026-09-22 and 2026-09-23). The id changes when Studio restarts. See [[Studio Host and Instance Id]] and [[Places and Studio Windows]].
- **Outbreak Tycoon (OBT)** is a third, unrelated project with its own vault (`Documents/Roblox/OBT Vault/`). Nothing from OBT is edited from here.

## Where things live

| What | Where |
|---|---|
| Live game | Studio (source of truth for code and instances) |
| Code mirrors (exported copies of Studio scripts) | `CrimeLifeRoblox/FPSSystem/<area>/*.luau` (40 files on 2026-11-14, plus 2 in `ViewmodelAnimations/baseline/`). A local edit alone does not change Studio. |
| Unit tests | `ServerStorage.UnitTest.Cases.*` in Studio; mirrors as `*_Test.luau` and `*.spec.luau`. See [[Unit Test Runner]] |
| Project knowledge | this vault |
| Batch history | `70 Batches/` ([[Batch Log]]); before 2026-11-14 the 143 change logs |
| Original prompts (what was asked for) | `90 Reference/Original Prompts/` ([[Original Prompts]]): specifications, not records of the work |
| Plans and specs from earlier phases | `CrimeLifeRoblox/docs/superpowers/plans/`, `.../specs/` |
| Per-task working reports | `CrimeLifeRoblox/.superpowers/sdd/` |
| Code graph output | `CrimeLifeRoblox/graphify-out/` (git-ignored). See [[Code Graph]] |
| Git | `CrimeLifeRoblox/` (remote `Luqpic/CrimeLifeRoblox`, branch `main`). `RobloxFPSsystem/` is a second clone of the same repo, safe to ignore |

## Read order for a fresh session

1. [[Home]], then this note.
2. [[Rules MOC]]: the standing rules, especially [[Which Project This Is]], [[Safety and Security Rules]] and [[Save and Publish Rules]].
3. [[Open Items]]: what is open, unverified, and what only the developer can do.
4. The newest entries in [[Batch Log]].
5. The [[Systems MOC]] entries for whatever the new request touches, then [[Engine Traps MOC]] for that area.
6. [[Batch Workflow]] before building.

## How a batch ends (from 2026-11-14)

A batch note in `70 Batches/` named `YYYY-MM-DD Topic`, a line at the top of [[Batch Log]], the touched `20 Systems` notes, [[Open Items]], new decisions in `80 Decisions`, new traps in `50 Engine Traps`, then one commit `Batch: <topic>` in the CrimeLifeRoblox repo. This replaces the old one-change-log-per-change routine and its `Add change log: <what>` commits. Reports end with **"NOT saved / NOT published"**. Details: [[Batch Workflow]], [[Vault Conventions]].

## People

- **The developer** owns the game, makes the product calls, saves Studio, publishes, and does the checks that need a person (looking at the screen, multiplayer starts).
- **Claude** builds and tests through the Studio MCP, keeps this vault true, never publishes, and never prints a key or token.
