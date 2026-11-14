# Change Log: Death Screen Text-Stuck Bug — Real Root Cause Fix

**Date:** 2026-09-12
**Status:** Applied

## Summary
The death screen's stuck-text bug persisted after the first fix. Diagnosed from a screen recording: a fast manual respawn (via the in-game menu) could race ahead of the moment the death sequence captured its own baseline state, permanently deferring the reset to the *next* death instead of the current one.

## Changes
- `StarterPlayer.StarterPlayerScripts.DeathScreen` — the respawn counter is now captured synchronously at the instant of death rather than inside a separately-scheduled task, closing the race. The wait for respawn is now a bounded, polled wait instead of a one-shot event wait, so it can no longer hang indefinitely under any circumstance. The death text is now also fully hidden (not just faded) between deaths, as an extra safety layer.

## Notes
- Diagnosed by extracting and reviewing frames from a user-provided screen recording, not by guessing.
