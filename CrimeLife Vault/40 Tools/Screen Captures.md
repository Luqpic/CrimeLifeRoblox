---
type: tool
tags: [tools, mcp, screenshots]
updated: 2026-11-14
sources: ["docs/superpowers/plans/2026-09-23-persistence-phase-3.md (trap 6)", "70 Batches/FPS System/FPS-Weapon-Skins-Phase-1.md", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/FPS System/FPS-Death-Screen-You-Died-And-Alignment.md", "70 Batches/Robbery System/Getaway-Distance-Replaces-Claim-Zone.md", "70 Batches/FPS System/Prompt-Circle-Liquid-And-Glow.md", "70 Batches/FPS System/FPS-Quest-Givers-Law-Enforcement-Outfits.md", "OBT Vault/40 Tools/Screen Captures.md (generic parts)"]
---

# Screen Captures

Screenshots are evidence only when they agree with a property read. In CrimeLife sessions the capture has often been unusable, so most verification is structural or numeric.

## The tool

MCP `screen_capture` (Edit or Client), with optional `camera_position` / `look_at_position`.

## When it works and when it does not

| Session state | What `screen_capture` gave | Seen in |
|---|---|---|
| Viewport collapsed or headless (`ViewportSize` 1, 1; RenderStepped 0 / s) | A uniform **magenta** placeholder, a blank frame, or a hang | [[FPS-Weapon-Skins-Phase-1]], [[FPS-Spraypaint-Phase-2]], [[FPS-Death-Screen-You-Died-And-Alignment]], [[Getaway-Distance-Replaces-Claim-Zone]] |
| A running game's view in some sessions | A blank frame ("cannot photograph a running GUI") | [[Prompt-Circle-Liquid-And-Glow]] (the developer confirmed the final look by eye) |
| Viewport open (for example 1120 x 719) | Real shots, Edit and Play | [[FPS-Quest-Givers-Law-Enforcement-Outfits]] (before / after of all six quest givers), [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]] |

**First, read `workspace.CurrentCamera.ViewportSize`.** If it is 1, 1, do not try captures or clicks: verify by properties and list the visual check under Not verified ([[Reporting Rules]]).

## When a capture lies (generic, from OBT)

| Symptom | Cause | Do this |
|---|---|---|
| First shot after a change looks unchanged | The first capture can be stale; new text renders a frame late | Take two |
| A billboard is missing | Client capture skips AlwaysOnTop BillboardGuis and BillboardGuis held in PlayerGui | Read properties ([[Billboard and World GUI Traps]]) |
| CoreGui dialogs are missing | `screen_capture` does not show CoreGui | A fake purchase prompt can be eating clicks unseen |
| SurfaceGui text missing from a far camera | `SurfaceGui.MaxDistance` culls by the real editor camera | Move the editor camera or read properties |
| An effect is missing with `camera_position` set | A camera override renders a separate view | Compare with a plain capture |
| Character moved but the view did not | `execute_luau` resets the camera after each call | Pass a camera, or set and capture in one call |
| A short effect is never in the shot | A capture lands about a second after the call | Slow the effect for the photo; keep real timing for checks |

Related: [[Studio MCP Gotchas]] · [[Verify in Edit and by Screenshot]] · [[Tools MOC]]
