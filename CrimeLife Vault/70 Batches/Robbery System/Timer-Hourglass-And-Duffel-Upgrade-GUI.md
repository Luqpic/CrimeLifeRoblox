# Change Log: Timer Hourglass Icon + Duffel Bar/Upgrade GUI

**Date:** 2026-09-12
**Status:** Applied (confirmed live), with one external prerequisite still outstanding

## Summary
Restyled two ambient HUD elements (timer, duffel) to match reference imagery, and added a "+" button upgrade dialog on the duffel widget. The duffel-upgrade request ("pay for x2/x4 duffel size") turned out to already be fully implemented server-side — `GamepassManager.lua` already resolves real Roblox Gamepass ownership into 2x/4x duffel-cap multipliers, including a `PromptGamePassPurchaseFinished` listener — but nothing had ever actually called `MarketplaceService:PromptGamePassPurchase` to show the purchase dialog. This prompt wired the missing front-end onto that existing backend rather than building a second economy.

## Changes requested
- Timer: drop the "HEIST" label text, keep just the countdown + a placeholder hourglass emoji, unchanged urgency coloring.
- Duffel: rebuilt from a plain text label into a composite widget (header, proportional fill bar, overlaid amount text, "+" button) — kept in `HeistClient.lua`'s older runtime-`Instance.new()` style, matching its immediate HUD siblings (timer/toast), rather than migrating to the newer Studio-authored-dialog convention used for triggered puzzles.
- New `DuffelUpgradeGui` (Studio-authored): a slide-in dialog offering x2/x4 capacity, wired to call `MarketplaceService:PromptGamePassPurchase` with the Ids already defined in `GamepassManager.GamepassConfig`.

## Confirmed outcome (as of this log)
`StarterGui.DuffelUpgradeGui`, the duffel widget's header/bar/fill/amount/`+` structure, and the timer's simplified text were all confirmed live during a later prompt's research pass.

## Outstanding — not something Studio work can resolve
`GamepassManager.GamepassConfig`'s `DuffelCapacityX2`/`DuffelCapacityX4` `Id`s are still placeholder `0`s (an existing `TODO(project owner)` predating this prompt) — the two real Gamepasses still need creating in the Creator Dashboard before a purchase can be tested end-to-end. Flagged in the original prompt and repeated here since it's still true.

## Notes
- Reference images for this prompt also showed a "Jewelry Store" cash counter with a "+" button — read as a style reference only (button look, hourglass detail), not a request to build a cash-counter "+" purchase flow; no such flow was specified or built.
