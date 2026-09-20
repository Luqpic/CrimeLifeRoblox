# Change Log: Inventory Slots Get a Click Sound and a Hover Outline

**Date:** 2026-09-21
**Status:** Applied (confirmed live through real pointer input -- hover in, hover out, equip, unequip)

## Summary
Clicking an inventory slot to equip or unequip now plays a click, and hovering a slot fades an accent
outline around it. The slot's existing hover was a 0.15 lift in `BackgroundTransparency`, which on a
dark slot is easy to miss.

## Changes
`StarterGui.Custom Inventory.InventoryController.SETTINGS` only:
- `SETTINGS.EQUIP_SOUND_ID` = `rbxassetid://111258886624386`, played on the click that equips or
  unequips.
- `SETTINGS.HOVER_STROKE_COLOR` / `_THICKNESS` / `_TWEEN` -- the outline is the accent green the file
  already defines for the equipped slot (`SETTINGS.EQUIPPED_COLOR`, Theme Accent `#CBF23C`), 2px,
  faded over 0.12s.
- `hoverStroke(frame)` (new, local) -- finds or creates the slot's `HoverOutline` UIStroke. Created
  at `Transparency = 1` and `ApplyStrokeMode.Border`, so it never changes the slot's layout and is
  invisible until hovered.
- The existing `MouseEnter` / `MouseLeave` handlers each tween it, alongside the background lift they
  already did.

## Why the sound is built here rather than through UI.Sounds
This package is capability-sandboxed: a `require` across that boundary fails, which is why the file
already carries its theme colours as literals rather than requiring `ReplicatedStorage.UI.Theme`. The
sound is created with the same find-or-create against `SoundService` that `UI.Sounds` uses, so there
is one Sound instance however many slots ask for it.

## Where the sound is played, and where it is not
On the `wasClick` branch that decides a press was a click rather than a drag -- immediately before
`manageTool()` -- and not inside `manageTool` itself. `manageTool` is also bound to the number keys
and runs on the forced unequip at death; this is click feedback, so the keyboard path and the death
path stay silent.

The outline is attached lazily on first hover rather than built with the slot, because slots are
cloned from a template and reparented on every swap. One code path then covers hotbar slots,
inventory slots, and anything rebuilt by a drag.

## Verification
Driven with real pointer input against the live hotbar slot, not simulated in isolation:

| step | result |
|---|---|
| pointer moved onto slot 1 | `HoverOutline` created, colour `0.796, 0.949, 0.235` = RGB(203,242,60), thickness 2, **transparency 0.000** |
| pointer moved away | **transparency 1.000** |
| click | equipped tool = **Crowbar**; `InventoryEquipSound` created, id `rbxassetid://111258886624386`, volume 0.6, `IsLoaded = true` |
| click again | equipped tool = **none** |
| still hovering after equipping | outline **0.000**, unchanged |

The asset itself preloads clean: `IsLoaded = true`, `TimeLength = 0.051s`.

That last row matters: this file already documents that equipping a slot while the cursor is on it
used to stamp over the hover state, because the background effect caches `RestingTransparency` on
hover-in. The outline is a separate property on a separate instance, so it does not participate in
that hazard.

## Notes
- `UI.Effects` was deliberately not touched. It is kept byte-identical between this place and the
  Robbery System place, and a `bindStrokeHover` already there thickens an EXISTING stroke rather than
  fading one in -- neither the behaviour asked for nor something to change in a shared file for one
  place's inventory.
- The drag system's own `DragGlow` stroke is untouched and does not collide: it is a different
  instance under a different name, created and destroyed per drag.
