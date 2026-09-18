# Change Log: GUI Audit and Figma Redesign

**Date:** 2026-09-18
**Status:** Applied (Figma only — no Studio changes in this entry)

## Summary
Audited every GUI in the Robbery System place and rebuilt them as a Figma design set. The audit found 15 interactive surfaces plus 38 world-space SurfaceGuis, and a third of the interactive ones did not exist in StarterGui at all — they are created at runtime by `HeistClient`, so a plain Explorer sweep misses them. The redesign adopts the existing FPS design library's neon-ribbon theme rather than inventing a parallel one.

## Changes
- Figma file `Roblox` — new page `01 · Roblox As-Built`: all 15 interactive surfaces captured 1:1 from Studio (exact pixel sizes, colours and text).
- Figma file `Roblox` — page `02 · Redesign`: the same 15 surfaces reskinned to the library's tokens, placed clear of the existing FPS UI.
- The cash widget and notification card were adopted from the FPS library rather than rebuilt, so the two projects share one design after a merge.

## Notes
- The place was described as "an FPS" at the start; it is a heist/robbery game. The FPS UI turned out to live in the linked Figma file, which is what the reference URL pointed at.
- Gotham is not available in Figma, so the as-built capture substitutes Montserrat. This only affects the reference capture, not the shipped game.
- An initial read of the Figma file reported it as empty. That was an authentication problem — the OAuth flow had picked up a personal Google account with a View seat, which returns a hollow document. Re-authenticating as the work account showed 577 nodes.
