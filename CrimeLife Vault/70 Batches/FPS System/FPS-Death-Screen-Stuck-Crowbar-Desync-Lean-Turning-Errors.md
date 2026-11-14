# Change Log: Death Screen Stuck-State Fix, Enemy Crowbar Desync, Lean/Turning Error Spam

**Date:** 2026-09-11
**Status:** Applied

## Summary
Fixed the death screen occasionally leaving its overlay stuck on screen — which turned out to also be the cause of a separately-reported "inventory button hidden behind a black box" bug, same root cause. Synced the AI Thug enemy's crowbar to match the player's current crowbar (it had drifted out of date). Ported the melee hit-timing fix to enemies, since it had only ever been applied on the player's side. Also fixed an unrelated, pre-existing bug found while investigating: two character scripts were throwing an error every single frame.

## Changes
- `StarterPlayer.StarterPlayerScripts.DeathScreen` — cleanup after the death sequence is now unconditional, so it always resets regardless of what happens mid-sequence.
- `ServerStorage.EnemyTemplates.Thug.Crowbar` — attributes and sound ids synced to the current player Crowbar (hand/grip positioning was left untouched, since it's specific to that enemy rig).
- `ServerScriptService.Enemy.Scripts.EnemyAI` — melee hit resolution now respects the same swing-delay timing already used on the player's side, instead of resolving damage before the swing animation visually reaches the target.
- `StarterPlayer.StarterCharacterScripts.Lean`, `.Turning` — stopped a continuous per-frame error caused by assumptions about an older character rig type. The lean/turn visual effect is disabled for now as a result.

## Notes
- A proper rewrite of the lean/turn effect for the current character rig is still outstanding — it's off, not fixed, for the time being.
