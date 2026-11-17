---
type: batch
tags: [batch, tycoon, building, floor-plan]
updated: 2026-11-17
sources: ["CrimeLife Vault/90 Reference/Original Prompts/Tycoon/2026-11-17 Compound Floor Plan.md", "CrimeLifeRoblox/docs/crimelife-compound-plan.html"]
---

# 2026-11-17 Compound Floor Plan

## Asked for

The developer is hiring a builder for the tycoon place and asked for a new floor plan and an artifact to show them. It should take inspiration from a reference screenshot (rooms around a central yard) without copying it, keep the rooms from `docs/crimelife-hq-blueprint.html`, and fit a 361 × 300 plot. Later: a 3D view. Prompt and answers: `90 Reference/Original Prompts/Tycoon/2026-11-17 Compound Floor Plan.md`.

## What changed

- New drawing set `CrimeLifeRoblox/docs/crimelife-compound-plan.html`, published as the private artifact https://claude.ai/artifact/Q9v2zXssGBmYU81wWsfmQ3 (version 3). It has five plan sheets with room schedules, a section, the 0–8 unlock order and a three.js block model. The model is built from the same room data as the 2D sheets, so the two cannot drift apart.
- New reference note [[Compound Floor Plan]]. Decisions added to [[CrimeLife Tycoon Decisions]]. Prompt filed under [[Original Prompts]].
- Follow-up (version 4): room labels no longer overlap. The size line had sat on the room name on every sheet, and 8 names sat on fixture labels. Labels now get more line spacing and move to a clear spot inside their room. Fixtures were moved in the Chop Shop, Meeting Office and Cells. Button pads, temporary roof caps and the early fence were removed from the page in favour of OBT's BUILD menu and a build-in-order rule.
- No Studio or game change.

## Decisions

The developer's answers are in [[CrimeLife Tycoon Decisions]] (2026-11-17, compound floor plan). Claude's layout calls (moved rooms, the spare slot, three corner towers plus the Watchtower) are listed there as rulings.

## Verified

- The page script passes `node --check`.
- Served locally in the built-in browser: the block model renders with no console errors, and Explode and Fixtures (see-through blocks) work. The local server showed `×` as mojibake because it sent no charset. The published page carries UTF-8.

- Version 4: an in-browser check of every text's on-screen box across the five plan sheets found 0 overlapping pairs (before: about 60).

## Not verified

- The published artifact was not opened, because the built-in browser is not signed in to claude.ai.
- The layout has not been tested in Studio for walking scale, sight lines or streaming cost.

## Left open

- Share the artifact with the builder (Share menu).
- Decide what goes in the F2 spare slot.
- Price the unlock stages.

## Links

[[Compound Floor Plan]] · [[CrimeLife Tycoon Decisions]] · [[Batch Log]] · [[Open Items]]
