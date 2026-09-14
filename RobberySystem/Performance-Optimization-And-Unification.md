# Change Log: Performance Optimization And Unification

**Date:** 2026-09-12
**Status:** Partially applied (Part 1 confirmed; Parts 0/2-4 not independently verified)

## Summary
First prompt in the Robbery System series, written after the user flagged the game as heavy/laggy across its four robbery locations (Bank, SlowFoods, Gas2Go, NewsStation). A structural read-through (not a live profiler pass) surfaced the ~85%-duplicated per-location orchestration scripts and an order-of-magnitude part-count disparity between the Bank/BankVault models (572/624 descendants) and the other three locations (18-51 descendants each), among other leads. The prompt was split into five parts — profile first, unify duplicated orchestration, audit for unused GUI/sound/scripts, audit component lifecycle/leak behavior, and reorganize the Explorer hierarchy — each gated by "grep before delete" and "run the existing spec suite before/after" rules, given this is a live, TDD-covered system.

## Changes requested
- Part 0: profile all 4 locations live before acting on any structural assumption.
- Part 1: extract the ~85%-duplicated SlowFoods/Gas2Go/NewsStation (and possibly Bank) orchestration into one shared factory module.
- Part 2: audit StarterGui/SoundService/PlayerData/test-runner reachability for genuinely dead code.
- Part 3: audit NPC-respawn and alarm-sound-clone lifecycles for leaks across repeated session cycles.
- Part 4: reorganize the Workspace/ServerScriptService/ReplicatedStorage hierarchy without breaking any hardcoded path reference.

## Confirmed outcome (as of this log)
- `ServerScriptService.Heist.Services.LocationServer` now exists and is consumed by `SlowFoodsServer`/`Gas2GoServer` (Part 1). Its own header comment explains a deliberate decision to keep `HeistServer` (the Bank) off this shared module, since the Bank's participant-enrollment model differs enough that unifying it would buy the smallest win for the largest blast radius — a considered deviation from the original prompt, not an oversight.
- Parts 0, 2, 3, and 4 were not independently re-verified during this pass; this log only speaks to what was directly observed in Studio.

## Notes
- The `LocationServer` unification surfaced a real, unrelated regression later — see `Post-Move-Fixes-And-GUI-Polish.md` in this same folder — once the `DuffelBag` model was relocated to `ReplicatedStorage.HeistShared` and its default template path went stale.
