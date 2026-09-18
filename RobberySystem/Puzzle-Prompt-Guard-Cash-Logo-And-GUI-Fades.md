# Change Log: Puzzle Prompt Guard, Cash Logo Burst and GUI Fades

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Summary
Three fixes. A player standing next to the computer could re-trigger its proximity prompt while the word-scramble panel was already open, stacking duplicate panels. The cash pickup burst was drawing plain green circles instead of the cash logo used everywhere else in the UI. And focus mode hid and restored the HUD instantly, which read as a glitch rather than a transition.

## Changes
- `ReplicatedStorage.SharedSystems.LockedDoor` and `ServerScriptService.Heist.Components.MasterComputer` — both now ignore a trigger from a player who already has an attempt in flight.
- `ReplicatedStorage.SharedSystems.CashClaimVFX` — burst particles now use the cash logo, with its size sourced from the shared theme module.
- New `ReplicatedStorage.UI.Transitions` — every GUI entrance and exit now fades. Focus mode fades the HUD out and back in rather than switching it.

## Notes
- The first fade implementation used a "suppress" flag to stop the fade from re-entering when it wrote to the property it was watching. That silently does not work: Roblox runs property-changed callbacks deferred, so the flag was already cleared by the time the callback ran. Symptoms were a reversed fade and a lockpick panel that would not close. The module now counts its own writes instead, which does not depend on callback timing.
- Guarding the prompt on the server rather than hiding it on the client is deliberate — the client panel is not authoritative and a second client could still fire the remote.
