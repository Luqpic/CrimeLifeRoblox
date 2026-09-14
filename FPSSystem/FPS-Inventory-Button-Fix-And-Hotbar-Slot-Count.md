# Change Log: Inventory Button Fix, Hotbar Slot Count Reduction

**Date:** 2026-09-11
**Status:** Applied

## Summary
Fixed the inventory toggle button being completely invisible — a leftover from an earlier UI pass that left it fully transparent with no icon. Reduced the hotbar from 9 slots to 6, resizing the hotbar frame to match so it doesn't look oversized for its new contents.

## Changes
- `StarterGui."Custom Inventory".openButton` — now shows a visible icon on a proper background, replacing the transparent placeholder.
- `StarterGui."Custom Inventory".InventoryController` — hotbar capacity reduced from 9 to 6 slots; hotbar frame width scaled down to match; a hardcoded slot-count loop elsewhere in the same script fixed to follow the same setting instead of a fixed number.

## Notes
- None.
