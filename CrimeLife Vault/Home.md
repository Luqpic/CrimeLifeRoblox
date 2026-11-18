---
type: moc
tags: [home]
updated: 2026-11-15
sources: ["CLAUDE.md (Roblox Development, Operating Context)", "git log of Luqpic/CrimeLifeRoblox"]
---

# CrimeLife: Development Vault

The source of truth for **CrimeLife**, a Roblox crime and shooter game. Three places: **Crimelife City** (`Roblox Games/Crimelife city.rbxl`, the primary place from 2026-11-15, with the FPS systems ported in), **FPS System** (`Roblox Games/FPS System.rbxl`, frozen from 2026-11-15 as the reference the port was taken from; it was the primary place until 2026-11-14) and the sister **Robbery System** (`Roblox Games/Robbery System.rbxl`), which shares UI modules with it. Worked live in Roblox Studio through the `Roblox_Studio` MCP server. Read [[Start Here]] on a fresh session; run every batch by [[Batch Workflow]].

From 2026-11-14 this vault replaces the old routine of one change log per change plus an `Add change log: <what>` commit. The 143 change logs written before that date live unchanged in `70 Batches/` and are listed in [[Batch Log]].

## Right now

- **Open work:** [[Open Items MOC]].
- **Latest batch:** see the top of [[Batch Log]].
- **Before you test:** [[Studio MCP Gotchas]], [[Unit Test Runner]], [[Screen Captures]].

## Maps

| Area | Start at | What you find |
|---|---|---|
| Start | [[Start Here]] | Which project, which window, read order, people |
| Rules | [[Rules MOC]] | How the developer wants the work done |
| Systems | [[Systems MOC]] | Every game system: what, where, how, watch out |
| How-To | [[How-To MOC]] | Recipes for adding weapons, enemies, quests, panels |
| Tools | [[Tools MOC]] | Studio MCP mechanics, the unit test runner, the code graph |
| Skills | [[Roblox Skills]] | Which Roblox skill to load for a task; where CrimeLife differs |
| Engine traps | [[Engine Traps MOC]] | Roblox behaviour that cost a debugging session |
| Open items | [[Open Items MOC]] | Open bugs, unverified work, what needs the developer |
| Batches | [[Batch Log]] | One note per batch, plus the 143 historical change logs |
| Decisions | [[Decisions MOC]] | The developer's product calls |
| Reference | [[Reference MOC]] | Places, pipelines, original prompts, index of outside docs |

## The six rules that matter most

1. Reproduce with numbers first, then fix, then measure again. [[Measure Before and After]]
2. Verify the result, not the arithmetic: read `AbsolutePosition` and friends back. [[Verify in Edit and by Screenshot]]
3. Say plainly what was verified and what was not; end with "NOT saved / NOT published". [[Reporting Rules]]
4. Prefer the shared module; extend weapons by attribute, never by fork. [[Shared Code Extended by Attributes]]
5. Crimelife City is the target (from 2026-11-15; FPS System is frozen); never edit Robbery System or OBT unless named. [[Which Project This Is]]
6. Only the vault's Roblox skills, never an Anthropic or other skill unless the developer names it; juggle Opus and Sonnet. [[Vault Skills Only and Model Routing]]

## Keeping the vault true

Conventions: [[Vault Conventions]]. Templates: [[Batch Note Template]], [[System Note Template]]. Frozen history: [[Handover Snapshot 2026-11-14]].
