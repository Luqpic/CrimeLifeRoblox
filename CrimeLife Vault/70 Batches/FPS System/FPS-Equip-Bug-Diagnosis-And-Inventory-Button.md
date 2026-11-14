# Change Log: Equip Bug Diagnosis and Inventory Toggle Redesign

**Date:** 2026-09-11
**Status:** Applied

## Summary
Weapons weren't equipping when clicked or number-keyed in the hotbar. Rather than guess at a fix, temporary diagnostic logging was added at each step of the equip request's client-to-server round trip to find the actual failure point before touching any logic. Separately, the inventory toggle button was redesigned from a text label at the bottom of the screen to an icon button at the top.

## Changes
- `StarterGui."Custom Inventory".InventoryController.SETTINGS` — instrumented `manageTool()`'s equip/unequip request path, then had the instrumentation removed once the real cause was found and fixed.
- `ServerScriptService.Weapons.Scripts.EquipService` — instrumented the server-side request handler and its guard clauses to identify which one (if any) was rejecting valid requests.
- `StarterGui."Custom Inventory".openButton` — removed its old `info` text label, resized to a square icon button, and repositioned to the top-right corner.
- `StarterGui."Custom Inventory".InventoryController` — removed dead code that referenced the deleted text label and the button's old open/close repositioning logic.

## Notes
- No real icon asset was available at the time; the button shipped as a placeholder pending a proper icon (later replaced with an emoji glyph in a subsequent pass).
