---
type: rule
tags: [rule, testing, verification, studio]
updated: 2026-11-20
sources: ["CLAUDE.md (How to work in this project, item 3)", "OBT Vault/10 Rules/Verify in Edit and by Screenshot.md (adapted)", "70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-3.md", "70 Batches/FPS System/FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget.md", "70 Batches/FPS System/FPS-Weapon-Skins-Phase-1.md"]
---

# Verify in Edit and by Screenshot

## Rule

- **Verify the result, not the arithmetic.** A successful edit report is not proof. Read the resulting property back. For layout, `AbsolutePosition`, `AbsoluteSize` and `AbsoluteCanvasSize` are the only honest witnesses.
- **Edit is the last source of truth (developer, 2026-11-20 morning; OBT's rule reused).** Everything that shows up in Play also exists in Edit, where the developer can see it. An NPC that stands up at run time (a guard, a heist officer, an enemy) is a rig in Edit on its marker (`Heist.EditRig`): the game builds from that rig or removes it at Play, and the marker follows the rig, so moving the rig in Edit moves the spawn. A GUI built at run time exists as instances in Edit too. [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **Edit is where changes persist.** Every lasting world, GUI or script change goes into Studio's Edit DataModel. Re-read it in Edit (a property or `Source` read) before calling it done. A change made only in Play is gone when Play stops.
- **Tests run in Play, reads run in Edit.** Run unit suites from a fresh Play session's Server datamodel; use Edit `execute_luau` only for read-only property, attribute and `Source` checks, never `require` ([[Unit Test Runner]]).
- **Take a screenshot when the viewport allows it**, and say when it does not (a collapsed viewport gives `ViewportSize` 1, 1 and a magenta or blank capture). See [[Screen Captures]].
- **Studio's own toolbar is the developer's.** The MCP sends mouse and keys only into the running game; a device emulator toggle or a multiplayer Start needs the developer ([[Phone Testing]], [[Two-Player Test]]).
- **Mirror check.** After an edit, the Studio script and its `.luau` mirror in `CrimeLifeRoblox/FPSSystem/` must match byte for byte (several change logs compare checksums).

## Why

- The developer, 2026-11-20 morning: "Reuse teh OBT rule whereby everything happening in edit mode is the last source of truth. Every changes must also happen in edit mode, for example if you added enemies during the gameplay, I also need to see teh enemies in edit mode so I am aware of their location. Likewise for GUIs too."

- `CLAUDE.md`: "A successful edit report is not proof. Read the resulting property back — especially `AbsolutePosition`, `AbsoluteSize` and `AbsoluteCanvasSize`."
- [[FPS-Figma-UI-Bugfix-Pass-3]]: a pass-2 fix gave `ActionButton` a `UIPadding` to make room for a price pill; the check measured the padding arithmetic and reported PASS while the pill had moved 88 px left onto the label.
- [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]]: a careless comparison flagged a ~58 px (one inset) misalignment that did not exist; the real delta was 0.28 px.
- [[FPS-Weapon-Skins-Phase-1]]: suites run from Edit after a module edit gave false failures (stale module cache).

## How to apply

- Run a read-back query right before the report and say in the report what was read and where.
- When a check is impossible in this session (no render, no second player), list it under Not verified with the reason.
- Capture and harness limits: [[Studio MCP Gotchas]], [[Screen Captures]].
