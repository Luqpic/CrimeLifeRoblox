---
type: reference
tags: [reference, index, docs]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/ (listing 2026-11-14)", "CrimeLifeRoblox/docs/superpowers/ (listing)", "CrimeLifeRoblox/.superpowers/sdd/ (listing)", "CrimeLifeRoblox/FPSSystem/ (listing)", "CrimeLifeRoblox/graphify-out/GRAPH_REPORT.md", "Documents/Roblox top level (listing 2026-11-14)", "CLAUDE.md"]
---

# Docs Index

Every CrimeLife document and code folder outside the vault, with what it is and whether to trust it. **The vault wins** over any document here.

Status key: **current** = still the best source for its subject. **historical** = a record of past work; the game or the vault has moved on. **superseded by X** = read X instead. **other project** = not CrimeLife.

## The repo: `CrimeLifeRoblox/` (git, remote `Luqpic/CrimeLifeRoblox`, branch `main`)

| Path | What it is | Status |
|---|---|---|
| `CrimeLife Vault/` | This vault | **current** (source of truth) |
| `CrimeLife Vault/70 Batches/FPS System/`, `Robbery System/` | Every change log written before 2026-11-14, moved here unchanged from `FPSSystem/*.md` and `RobberySystem/*.md` | current as records; see [[Batch Log]] |
| `CrimeLife Vault/90 Reference/Original Prompts/` | The original prompts (what was asked for), moved from `Documents/Roblox/PromptFolder/` | **keep, never delete**; see [[Original Prompts]] |
| `FPSSystem/Blaster/` | `ShotResolver.luau` (server hit authority), `BuildNewPistolsShotguns.luau` (the re-runnable weapon build) | current mirrors; Studio is the truth |
| `FPSSystem/ViewmodelAnimations/` | `WeaponViewmodelMotion.luau`, `BlasterController.luau`, `ViewModelController.luau`, `ExportKeyframeSequences.luau`, four `*.spec.luau`, `baseline/` (original controllers for rollback), `README.md` | **current**; README summarised in [[Animation Pipeline]] |
| `FPSSystem/Cosmetics/` | `Palettes`, `SkinApplier`, `CosmeticsService`, `SkinsCardController`, `WeaponShopService`, `WeaponaryShopController`, `GuiController`, `NotificationController` and three `_Test` cases | current mirrors |
| `FPSSystem/Spraypaint/` | `SpraypaintService`, `SpraypaintRunner`, `SpraypaintHud`, `Constants` and three `_Test` cases | current mirrors |
| `FPSSystem/Persistence/` | `Schema`, `ProfileGateway`, `ProfileStore` (vendored), `PersistenceRunner` and three `_Test` cases | current mirrors |
| `FPSSystem/Weapons/` | `CashService`, `LevelingService`, `WeaponUpgradeService` | current mirrors |
| `FPSSystem/Stats/` | `KillStatsService` (per-faction kill counters) | current mirror |
| `FPSSystem/UI/` | `CashBurst` | current mirror |
| `docs/superpowers/specs/` | 3 design specs: `2026-09-22-cosmetics-monetisation-design.md`, `2026-09-23-renown-phase-2-design.md` (titled Spraypaint Phase 2), `2026-09-23-persistence-phase-3-design.md` | historical design records; [[Cosmetics and Skins]], [[Spraypaint]], [[Persistence and Saves]] |
| `docs/superpowers/plans/` | 3 implementation plans matching the specs | historical; the plans' "medium" and test sections are still the best statement of the test harness ([[Unit Test Runner]]) |
| `.superpowers/sdd/2026-09-22-cosmetics-phase-1/` | Ledger: `progress.md`, 8 task briefs and reports, 13 review diffs | historical |
| `.superpowers/sdd/2026-09-23-renown-phase-2/` | Ledger: `progress.md`, 6 task briefs and reports, 5 side reports (HUD fixes, notification queue and restack, spraypaint badge and rename), 11 review diffs | historical |
| `.superpowers/sdd/2026-09-23-persistence-phase-3/` | Ledger: `progress.md`, 7 task briefs and reports, `final-fix-report.md`, review diffs | historical |
| `.superpowers/sdd/*-report.md` | Reports: per-weapon spraypaint, revert to global spraypaint, skins card revamp, skins card sticky fix | historical; each matches a change log in `70 Batches` |
| `.superpowers/sdd/uploaded-asset-ids.md` | Image ids uploaded 2026-09-24 with their source files (category icons, spray icon, white re-exports) | current as an id record; see [[Icon Pipeline]] |
| `graphify-out/` | Code graph (`graph.json`, `graph.html`, `GRAPH_REPORT.md`, 287 nodes, built 2026-09-19). Git-ignored, rebuilt on demand | stale until rebuilt; see [[Code Graph]] |
| `.claude/skills/` | The `roblox-*` skills for this repo | current; see [[Roblox Skills]] |

## `Documents/Roblox/` top level

| Path | What it is | Status |
|---|---|---|
| `CLAUDE.md` | Operating context for the FPS place (and a separate section for another project) | frozen CrimeLife copy in [[Handover Snapshot 2026-11-14]]; the vault replaces it |
| `Roblox-Claude-Workflow.md` | A general guide to the Claude + Studio + vault working setup (batch loop, MCP gotchas, skills table, Blender sections) | current as a method guide; written from another project's experience |
| `docs/GUIDE-Walker-Animation-Pipeline.md` | Another project's Blender animation guide | **other project**; its generic method is in [[Animation Pipeline]] Route B |
| `Roblox Games/FPS System.rbxl`, `Robbery System.rbxl` | The two CrimeLife places | see [[Places and Studio Windows]] |
| `Roblox Games/EnemyAI.md` | FPS System's AI enemy design note (2026-09-09): patrol, detection, chase, shots through the player's resolver, rig templates | historical (the roster changed since); see [[Enemies and Spawner]] |
| `VFX-Wiring-Plan.md` | A task note: wire two prepared VFX models (melee hit, level-up), "blocked on live Studio access" | likely **superseded by** [[FPS-Melee-Hit-And-LevelUp-VFX]] (2026-09-19, applied); confirm before deleting |
| `.mcp.json` | Studio MCP server config | current |
| `.claude/skills/` | The same `roblox-*` skill set at the top level | current |
| `Roblox Games/Crimelife city*.rbxl`, `CrimeLife Tycoon Building .rbxl`, `Crimelife Building (last saved 2023).rbxl`, `docs/crimelife-*`, `docs/figma-svg/`, `docs/flow-refs/` | Files named Crimelife | relationship to this game **not recorded**; ask |
| `PromptFolder/`, `RobloxFPSsystem/`, `RobloxSystems/` | Old locations named in `CLAUDE.md` and other notes | no longer present (2026-11-14); the prompts live in `90 Reference/Original Prompts/` |

Everything else at the top level (`studio-mirror/`, `Blender/`, `GFX/`, `BadgeGFX/`, `ArsenalIcons/`, `_assets/`, `Place1Vehicles/`, the rest of `docs/`) is **other project**.
