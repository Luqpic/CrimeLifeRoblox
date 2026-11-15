---
type: reference
tags: [reference, places, studio, mcp]
updated: 2026-11-15
sources: ["CLAUDE.md", "Roblox Games/ (listing 2026-11-14)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Close-Button-Unified-With-Robbery.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/GUI-Audit-And-Figma-Redesign.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-09-23-persistence-phase-3.md"]
---

# Places and Studio Windows

Which place file holds what, and which Studio window the `Roblox_Studio` MCP must target. Several Studio windows (and other projects) are often open at once. **Run `list_roblox_studios` and pick the window by name before any write; confirm it is the Crimelife City place** (from 2026-11-15; until 2026-11-14 the rule named FPS System). The MCP id changes whenever Studio restarts, so it is never recorded here.

## CrimeLife's places

| Place | File | What it is | Target? |
|---|---|---|---|
| **FPS System** | `Roblox Games/FPS System.rbxl` (local file, last modified 2026-09-25) | The FPS place: weapons, shop, enemies, quests, leveling, cosmetics, persistence. All `70 Batches/FPS System/` work. **Frozen from 2026-11-15** as the reference the port into the city was taken from; read and Play only. | **No** (was the default until 2026-11-14) |
| **Robbery System** | `Roblox Games/Robbery System.rbxl` (last modified 2026-09-20) | A heist game: Bank, SlowFoods, Gas2Go, NewsStation robberies, puzzle prompts, getaway. All `70 Batches/Robbery System/` work. | **Only when named explicitly** |
| **Crimelife City** | `Roblox Games/Crimelife city.rbxl` (local file; saved copy `Crimelife city copy.rbxl` is the pre-cleanup state; `Crimelife city BACKUP pre-cleanup 2026-08-20.rbxl` is the older fallback) | The main map and the merge target. **The primary place from 2026-11-15**: the 2026-11-14 cleanup plus the FPS systems ported in ([[2026-11-15 FPS Systems Into City]]). Saved by Claude at checkpoints on 2026-11-15, never published. | **Yes**, by default (from 2026-11-15); the Robbery work is ported into it later |

### Crimelife City (the primary place from 2026-11-15)
Cleaned on 2026-11-14 ([[2026-11-14 City Baseline and Cleanup]]); the FPS systems were ported in on 2026-11-15, and the place was saved by Claude at checkpoints that night. The layout below is the 2026-11-14 one; the new `Workspace` children (`TycoonPreview`, `Dev`, `EnemySpawns`, `Quests`, `Targets`, `AnimVM`, `Accessory Storage`) are in [[City Map and Plots]]. Layout, `Workspace` as cleaned on 2026-11-14:
- `Map` holds the art: `City`, `Robbery` (the six robbery buildings), `Roads`, `Props`, `Loose`.
- `Plots` holds `Plot1` to `Plot6` (the city's blue plates) and `Plot7`, `Plot8` (`Spare = true`).
- `Ground` holds the origin Baseplate. `SpawnLocation`, `Terrain` and `Camera` stay top level.
- `ServerStorage.CityQuarantine` holds everything moved out (`Scripts`, `Duplicates`, `LooseTycoon`, `StagingSlab`), restorable from the `OriginalParent` and `OriginalCFrame` attributes (models, parts) or `OriginalPath` (the 8 scripts); see [[City Map and Plots]].
- Streaming is on; `ModelStreamingBehavior` still needs `Legacy` set by hand. Details: [[City Map and Plots]], [[Four Places Survey 2026-11-14]].

### The Robbery rule
Robbery System shares UI modules with FPS System but is a **separate project. Never edit it unless the request names it.** Reading it to compare a shared module is fine; writing is not.

### What the two places share
Kept byte-identical on purpose, because the places are to be merged into one combined workspace later (a stated plan, no date recorded):
- `ReplicatedStorage.UI.Effects` (close button, hover and click behaviour), ported from Robbery with matching checksums;
- `ReplicatedStorage.UI.Transitions` (fades);
- the cash widget (Robbery's `SharedSystems.CashClaimVFX`; FPS earns through the same coin slice) and the notification card design;
- the Figma design library ([[Figma and UI Art Pipeline]]).
Robbery keeps its own registry `ReplicatedStorage.SharedSystems.UITheme`; FPS has `ReplicatedStorage.UI.Theme`. A change to a shared module in one place is not live in the other until it is copied, and the copy should be checksummed.

## Saving and publishing
- **Claude never publishes.** The developer decides when a place goes live.
- Both places are local `.rbxl` files: changes are live Studio edits until the developer saves (File > Save to File). Many change logs end with "the place is not saved to disk by this change"; say the same. One exception: on 2026-11-15 the developer allowed Claude to save `Crimelife city.rbxl` at checkpoints for that overnight run ([[Save and Publish Rules]]).
- Stop Play before an Edit change that must persist (Play edits are discarded).
- FPS System and Crimelife City are **unpublished**: persistence tests run on `ProfileStore.Mock`, and gamepass ids were placeholders until a stand-in pass was used ([[Persistence and Saves]], [[Gamepasses]]).
- Asset uploads: images can be uploaded through the MCP (`upload_image`, http/https URLs only); animations, meshes and fonts cannot ([[Animation Pipeline]]).

## Studio MCP notes that bite here
- `execute_luau` in Edit can serve a stale module after an edit; tests are authoritative only in Play ([[Studio MCP Gotchas]]).
- `execute_luau`'s `require` builds a separate module instance from the live game's; verify through real events.
- With the Studio viewport collapsed or minimised, `RenderStepped` reports 0 FPS and tweens do not advance (environment, not code).
- Synthetic mouse input and `screen_capture` have both failed in this environment at times; say what could not be seen.

## Other files with related names (not inspected)
`Roblox Games/Crimelife city with tycoon .rbxl`, `CrimeLife Tycoon Building .rbxl`, `Crimelife Building (last saved 2023).rbxl`, plus `docs/crimelife-hq-blueprint.html`, `docs/crimelife-2023-exterior-reference.jpg`, `docs/figma-svg/`, `docs/flow-refs/`. Whether these belong to this game (a future map?) is **not recorded**. Ask before using or editing any of them.

`Roblox Games/EnemyAI.md` (2026-09-09) is FPS System's own enemy AI design note; see [[Docs Index]].

## Not CrimeLife
Every other file in `Roblox Games/` belongs to another project. Never write to them from CrimeLife work.

Related: [[Docs Index]], [[Tools MOC]].
