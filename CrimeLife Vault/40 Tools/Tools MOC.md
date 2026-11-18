---
type: moc
tags: [tools, moc, studio, mcp]
updated: 2026-11-14
sources: ["CLAUDE.md (Operating Context)", "docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium)"]
---

# Tools MOC

Everything Claude uses to read, change and test CrimeLife. All of it runs through the `Roblox_Studio` MCP server (`execute_luau`, `script_read` / `script_grep`, `search_game_tree`, `start_stop_play`, `user_mouse_input`, `user_keyboard_input`, `screen_capture`, `upload_image`). There is no wrapper toolkit like OBT's `_tools/`: Studio is the source of truth and the `.luau` files in `CrimeLifeRoblox/FPSSystem/` are exported mirrors.

## Knowing what to load and where code is

- [[Roblox Skills]]: which of the 24 Roblox skills to load for a task, and where CrimeLife's way differs from them.
- [[Code Graph]]: the (stale) graphify graph of the change logs, and the cheaper ways to find code.

## Testing

- [[Unit Test Runner]]: `ServerStorage.UnitTest`, how to run suites in Play, and its traps.
- [[Two-Player Test]]: only the developer can start one; what is still waiting on one.
- [[Phone Testing]]: the device emulator Claude cannot press, and what to check.
- [[Performance Measurement]]: what CrimeLife has measured, and what to measure instead of Studio FPS.

## Mechanics that cost time

- [[Studio MCP Gotchas]]: the separate VM and `require` cache, single-call timing, collapsed viewports, drags, `upload_image`.
- [[Screen Captures]]: when `screen_capture` returns magenta or blank, and what to read instead.
- [[Studio Host and Instance Id]]: the last recorded Studio ids and the Mac side.

- [[Model Assignment]]: which Claude model (Opus 5.5 or Sonnet 5.5, from 2026-11-18) does which CrimeLife work.

## Related

- [[Engine Traps MOC]]: Roblox engine behaviour (not harness behaviour) that cost a debugging session.
- [[Safety and Security Rules]]: review free models, never send anything outward from a check, never print keys.
