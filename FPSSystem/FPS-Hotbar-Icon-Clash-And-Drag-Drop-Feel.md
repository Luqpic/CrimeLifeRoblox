# Change Log: Hotbar Icon Clash Fix and Drag-and-Drop Feel

**Date:** 2026-09-13
**Status:** Applied

## Summary
Cleaned up the inventory slots now that every weapon has real icon art, and gave dragging items around the inventory some actual feedback. Slots were drawing the weapon's icon and its name on top of each other, because a setting that forces the name to always show had been harmless back when no weapon had an icon at all. Dragging an item also placed it well below the cursor rather than under it, and gave no indication that anything was being held or had been dropped.

## Changes
- `StarterGui.Custom Inventory.InventoryController.SETTINGS` — the always-show-name setting is now off, so a slot shows its icon instead of both; a weapon with no icon still falls back to showing its name.
- `StarterGui.Custom Inventory.InventoryController.SETTINGS` — removed a hardcoded vertical offset from the dragged item's position so it now sits centred on the cursor.
- `StarterGui.Custom Inventory.InventoryController.SETTINGS` — a held item now carries a soft white pulsing outline for as long as it is being dragged, cleared unconditionally when the drag ends by any route.
- `StarterGui.Custom Inventory.InventoryController.SETTINGS` — a completed drag-drop now plays a brief pop and white flash on the item that settled, covering swaps, moves between the hotbar and inventory, and snapping back after a failed drop.
- `StarterGui.Custom Inventory.InventoryController.SETTINGS` — slots brighten slightly on hover and return exactly to their previous state, so equipped and disabled slots each go back to their own look rather than a fixed default.

## Notes
- The drop pop is driven by a scale modifier rather than the slot's size. Both the hotbar and the inventory grid rewrite every slot's size on each layout pass, so animating size directly is silently discarded; this was measured on a live slot before choosing the approach.
- The original plan gated the "snap back after a failed drop" feedback on whether a drag had started, but that flag is set by a single stray mouse-move event even when the cursor has not actually moved, so an ordinary click to equip was triggering the feedback too. It now reuses the same movement-distance threshold the inventory already uses to tell a click apart from a drag.
- The drag visuals were confirmed working in play mode, but simulated mouse input drives drags unreliably, so the specific case of "a long drag released over empty space" could not be re-confirmed on demand and is worth a manual check.
