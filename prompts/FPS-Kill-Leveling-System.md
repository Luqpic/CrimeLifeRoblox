# Change Log: Kill-Based Leveling System

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added a full kill-based leveling system: XP from kills (both AI and PvP), a level curve with a level cap, a small max-health bonus plus a cash bonus on every level-up, a leaderboard entry, and a HUD bar with a level-up popup and sound.

## Changes
- `ReplicatedStorage.Leveling.Constants` (new) — XP values per kill tier, the level curve, and reward values.
- `ServerScriptService.Weapons.Scripts.LevelingService` (new) — grants XP on kills and handles leveling up and its rewards.
- `StarterPlayer.StarterPlayerScripts.LevelingHud` (new) — XP bar and level-up popup/sound.
- `ServerScriptService.Weapons.Scripts.CashService` — fixed a pre-existing ordering bug where its leaderstats setup could silently skip creating the Cash stat depending on which of two services initialized first for a given player; made robust to either order.

## Notes
- Leveling resets every session, matching how Cash already worked at the time — no persistence layer was added.
