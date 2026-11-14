# Change Log: Post-Move Fixes + Duffel/Cash/Notification GUI Polish

**Date:** 2026-09-13
**Status:** Drafted — not yet confirmed executed

## Summary
Follow-up prompt written after the user relocated the `DuffelBag` accessory model from `Workspace.DuffelBag` to `ReplicatedStorage.HeistShared.DuffelBag` directly in Studio. That move broke several hardcoded references that were never updated (a real boot-time regression, not a style issue), which became this prompt's top priority ahead of the requested cosmetic changes. Research for this prompt also confirmed that a persistent cash display already existed (`CashClaimVFX.lua`'s `CashDisplay`/`CashFrame`/`CashLabel`, currently plain `"Cash: %d"` text) — "revamp the money GUI" therefore targets restyling that existing element, not building a new one.

## Changes requested
- Part 0 (priority): fix every stale `workspace.DuffelBag` reference — found in `HeistServer.lua`, `SlowFoodsServer.lua`, `Gas2GoServer.lua`, `LocationServer.lua`'s own default fallback, and two spec files (`WorldSpec`, `DuffelBagAttachmentSpec`).
- Part A: rename the duffel widget's "Robbing..." header to "DuffelBag"; make the fill bar tween on a lump-sum grant instead of snapping, edge-triggered the same way this file already guards `timerShown`/`duffelShown`.
- Part B: restyle `CashClaimVFX.lua`'s existing persistent cash card (add an icon, drop the "Cash:" prefix, bolder numeral) without touching its burst/fly/passive-listener logic.
- Part C: add an "Alarm Triggered!" inset sub-panel to the robbery-triggered notification variant only, which also required fixing `NotificationClient.lua`'s stacking math (it assumed one constant card height for every card, which breaks once one variant is taller than the other).
- Part D: remove the now-redundant personal "Alarm triggered. You have N minutes." toast — traced to two separate places (the shared `LocationServer.triggerMessage` path used by 3 locations, and the Bank's own separate hand-written copy in `HeistServer.lua`, since the Bank deliberately doesn't consume `LocationServer`) — including cleaning up the now-fully-unused `triggerMessage` config plumbing rather than leaving it dead, and updating `LocationServerSpec`'s assertion on the old toast text.

## Confirmed outcome (as of this log)
Not yet re-checked in Studio — this prompt was written most recently in this series, and this changelog entry reflects the prompt as drafted, not a verified post-execution state.

## Notes
- This was the first prompt in the series prompted by the user describing a change they had already made directly in Studio (the DuffelBag relocation) rather than a new feature request — required verifying current game state fresh rather than trusting the previous prompts' descriptions of what should exist.
