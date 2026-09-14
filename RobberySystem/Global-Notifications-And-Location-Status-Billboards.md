# Change Log: Global Notifications + Location Status Billboards

**Date:** 2026-09-12
**Status:** Applied (confirmed live)

## Summary
Two features requested together: (1) a global, stacking toast-style notification shown to every player when a location reopens or someone triggers a robbery, and (2) a persistent world-space badge above each of the 4 locations showing an emoji "logo" with a colored outline (green/yellow/red for Idle/Active/Cooldown). Both turned out to need almost no new infrastructure: the existing `HeistState` broadcast (already `FireAllClients` per location) covers the billboard coloring entirely, and the existing generic `UITransitions.SlideIn`/`SlideOut` module (already used for the Toast/timer/duffel labels) turned out to be directly reusable for a stacking notification queue with zero changes, once confirmed by reading it.

## Changes requested
- `Net.lua`: two new remotes/methods, `NotifyLocationOpened`/`NotifyRobberyTriggered`, following the established one-method-per-event style.
- Hook points: each location's `bank.StateChanged` handler (on a genuine `Idle` transition — confirmed `BankInstance` never fires that signal at boot, only on a real rearm) and each location's `TryStart` success path.
- New `NotificationGui` (Studio-authored) + `NotificationClient.lua`, its own dedicated LocalScript file per the recent one-script-per-feature precedent (`WordScrambleClient`).
- New per-location `StatusBillboardAnchor` parts placed in each location's existing `*Markers` folder (reusing an established convention rather than inventing a new one), each carrying a circular badge with a `UIStroke` outline colored the same way `LockpickGui`'s own ring stroke already swaps between idle/hit/miss colors.
- `HeistClient.lua`'s existing per-frame `LOCATIONS` loop extended to drive the billboard color, rather than adding a second `HeistState` listener.
- Addendum: confirmed a `BillboardGui.Size` set purely in Offset already renders at a constant on-screen size regardless of distance — no extra code needed, just a note not to add distance-based scaling.

## Confirmed outcome (as of this log)
`StarterGui.NotificationGui.NotificationTemplate` (`Header`/`Body` `TextLabel`s), `NotificationClient.lua`, the `LocationOpened`/`RobberyTriggered` remotes, and the billboard stroke-color swap inside `HeistClient.lua`'s render loop were all confirmed live during later prompts' research passes.

## Notes
- The reference screenshots for this prompt (showing a "Gas Station" and a "Jewelry Store") were from a different game, used only as a style reference — this game has no Jewelry Store; "Gas Station" was mapped onto `Gas2Go`.
