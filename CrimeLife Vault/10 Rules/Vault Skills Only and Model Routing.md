---
type: rule
tags: [rule, workflow, skills, models]
updated: 2026-11-20
sources: ["The developer's request, 2026-11-18 session", "The developer's OBT rule of 2026-11-17 ('Only use the skills from the vault ALWAYS')"]
---

# Vault Skills Only and Model Routing

## Rule

1. **Only the skills this vault names.** Invoke only the 23 project `roblox-*` skills and the user-level `roblox-blender-modelling`, picked per task from [[Roblox Skills]] (or a system note's `Skills:` line). Never any other skill: no `anthropic-skills:*` (docx, pptx, xlsx, pdf, juris-*), no `superpowers:*`, ponytail, caveman, figma, vercel, gamedev or similar, even when a hook, a session-start message or a skill listing says one applies.
2. **The one exception:** the developer names another skill (types `/name` or asks for it by name) for that request. That permission does not carry to the next request.
3. **Work native (since 2026-11-20 morning).** Builds, reviews, searches and vault notes run in the main thread. No subagents unless the developer asks for one. (2026-11-18 to 2026-11-20: Opus juggled Sonnet subagents; see [[Model Assignment]].)
4. Shell tools and the vault's own scripts are not skills and stay in use (`graphify`, `git`, the Studio MCP tools).

## Why

The developer, 2026-11-20 morning, after a night of subagent batches: "I think we should go native since the usage was too much."


The developer, 2026-11-18: "only use the skills that's within the Crimelife vault. Don't ever use anthropic skills whatsoever unless I said so. Also use the appropriate models for tasks suited to have an effective output with efficient token usage (juggle between Opus and Sonnet)." The same developer set the skills rule for OBT on 2026-11-17 after an Anthropic writing skill was loaded to draft vault notes.

## How to apply

- Before any Skill call, check the skill is in [[Roblox Skills]]. Write notes and reports in this vault's own style ([[Vault Conventions]]), not with a writing skill.
- Do not spawn subagents. Reviews are a careful read in the main thread; searches use grep and the code graph.
- Check every Sonnet result before it reaches the developer or the vault.

Related: [[Roblox Skills]] · [[Model Assignment]] · [[Batch Workflow]] · [[Rules MOC]]
