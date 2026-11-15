---
type: tool
tags: [tools, studio, mac, environment]
updated: 2026-11-15
sources: [".superpowers/sdd/skins-card-sticky-fix-report.md", ".superpowers/sdd/per-weapon-spraypaint-report.md", ".superpowers/sdd/2026-09-23-renown-phase-2/task-1-report.md", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "OBT Vault/40 Tools/Studio Host and Instance Id.md (generic Mac parts)"]
---

# Studio Host and Instance Id

Every MCP call targets one Studio instance id, which changes. And the Mac running Studio causes failures that look like game bugs.

## The Studio instance id

- **Last recorded (2026-09-24): `e72599f8-83cc-49ef-a389-c6be7ed27e4d`**, "FPS System Upgraded", PlaceId 87650598860298.
- Before: `ea0a6094-7699-4852-be8a-dc37e0a66ab1` (2026-09-22 and 2026-09-23), recorded as `FPS System.rbxl`.
- It changes when Studio restarts. CrimeLife has **no tool scripts with a hard-coded id**, so nothing needs repointing: each session runs `list_roblox_studios`, picks the Crimelife City window (the FPS System window until 2026-11-14), and reads `game.PlaceId` back before any write ([[Which Project This Is]]).
- Record a new id in the batch note when it changes.
- Several Studio windows can be open at once (OBT and CrimeLife share this Mac and MCP server). The window name and PlaceId are the check, not the order in the list.

## The Mac

| Symptom | Cause | Do this |
|---|---|---|
| `ViewportSize` reads 1, 1; RenderStepped 0 per second; tweens freeze; clicks do not land; captures hang or are magenta | The Studio viewport is collapsed or the window is headless (seen on CrimeLife, [[FPS-Spraypaint-Phase-2]]) | Not a code fault. Verify by properties and say so, or ask the developer to open the viewport |
| RenderStepped fires 0 times while Heartbeat runs at 60; screenshots stale | The screen is locked or the display slept (OBT) | Keep `caffeinate -di` running for long sessions; `caffeinate -u` before screenshots |
| Frame counts too low | An unfocused Studio renders about 9 to 16 FPS (OBT) | Frame-count thresholds must allow it |
| Periodic freezes with no Lua time | The Mac paging a long-running Studio (OBT: 16 GB machine) | Read `game.Stats.PerformanceStats.Memory`; past about 10 GB ask the developer to save and restart |
| MCP calls time out, Studio at 100 % CPU | A hidden modal dialog behind other windows (OBT) | The developer answers it |
| PreloadAsync fails, then succeeds a minute later | Roblox's CDN was flaky (OBT) | Retry before calling an asset broken |
| `User is not authorized to access Asset` for weapon sounds | Asset ownership, not wiring ([[Sound and Asset Traps]]) | Re-upload under the place owner, or accept the warning |

## Related

[[Studio MCP Gotchas]] · [[Screen Captures]] · [[Places and Studio Windows]] · [[Performance Measurement]]
