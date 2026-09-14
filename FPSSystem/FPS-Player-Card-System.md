# Change Log: Player Card System

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added a player card: a button next to the inventory toggle that opens a card showing the player's name, Roblox profile photo, health, and level progress. Other players' cards can be viewed via a `/view <username>` chat command, reusing data that already replicates to every client rather than adding new networking.

## Changes
- `StarterGui."Custom Inventory".playerCardButton` (new) — a static button matching the inventory button's own style.
- `ReplicatedStorage.GuiTemplates.PlayerCard` (new template).
- `StarterPlayer.StarterPlayerScripts.PlayerCardController` (new) — opens and populates the card, and registers the `/view` chat command.

## Notes
- The profile photo didn't load correctly at first, due to a typo in a Roblox API enum name. Fixed in a later change.
