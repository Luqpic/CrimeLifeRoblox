# Change Log: Hover Outline on the Loadout Slots

**Date:** 2026-09-21 (gated to the equip picker, and an equip sound added, same day)
**Status:** Applied (confirmed live end to end: outside pick mode, inside pick mode, and the click)

## Summary
The four loadout slots in the Weaponary Shop's inventory column take an accent hover outline **while
the equip picker is waiting for a choice**, and clicking one to equip now plays the equip sound.
Outside that flow the slots are plain.

## Changes
`StarterPlayer.StarterPlayerScripts.WeaponaryShopController` only:
- Each of the four slots gets a `HoverOutline` UIStroke, built once when its click handler is bound.
  Accent green (`SLOT_FILLED_COLOR`, `#CBF23C` -- the colour the file already uses for an occupied
  slot), `ApplyStrokeMode.Border`, created at `Transparency = 1` and faded over 0.12s on
  `MouseEnter` / `MouseLeave`. The shared hover tick plays with it, matching every other hoverable
  control in this panel.
- `refreshInventoryColumn` now finds the state stroke with `FindFirstChild("UIStroke")` rather than
  `FindFirstChildOfClass("UIStroke")`.

## Why a second stroke rather than animating the existing one
These slots already carry a UIStroke, and it is not decoration: `refreshInventoryColumn` paints it
accent at 2px for an occupied slot and dark grey at 1px for an empty one. A hover that borrowed it
would have to restore a value that `refreshInventoryColumn` can change underneath it -- the panel
repaints whenever the loadout does, including while a slot is being hovered.

It is **3px**, deliberately thicker than the filled state's 2px. On an occupied slot both strokes are
the same green on the same edge, so a same-thickness hover would have been invisible; at 3px the
outline visibly thickens. On an empty slot it brings a green edge in from nothing.

## About the lookup change
This is defensive, not a repair. Both lookups resolve to the same instance today -- the state stroke
is earlier in child order than the one added here -- and that was confirmed rather than assumed:

```
FindFirstChild('UIStroke')        -> UIStroke
FindFirstChildOfClass('UIStroke') -> UIStroke
```

By class, the answer depends on child order, and the slots now hold two UIStrokes. By name it cannot
drift onto the hover outline if that order ever changes.

## Verification
Real pointer input, driven through the shop's own open path and its own equip flow:

| state | result |
|---|---|
| shop open, **not** in pick mode, pointer on Slot1 | `HoverOutline` **1.000** -- no highlight |
| EQUIP pressed, picker open (`SwapPrompt` visible, "Select a slot to equip") | all four **1.000** |
| in pick mode, pointer on Slot2 | Slot2 **0.000**, Slots 1, 3, 4 **1.000** |
| click Slot2, pointer left on it | `LoadoutSlot2 = "Crowbar"`, picker closed, Slot2 outline back to **1.000** |
| the same click | `InventoryEquipSound` present, id `rbxassetid://111258886624386`, `IsLoaded = true` |

The fourth row is the one that matters: the outline clears with the pointer still sitting on the
slot, which only happens because `setSlotPickMode(false)` clears it rather than waiting for a
`MouseLeave` that never comes.

Earlier, before the gate, the coexistence of the two strokes was measured on an occupied slot: state
stroke accent @2 and hover accent @3 at transparency 0.000, so the edge reads 3px. That still holds
-- the gate changes when the outline shows, not how it looks.

## Correction: the first version highlighted on a general basis
The first version of this change hovered on every pointer pass, whether or not an equip was pending.
That was wrong, and the reason is worth recording: outside pick mode the click handler returns
immediately, so a highlight was advertising a choice that clicking does not make. The outline is now
gated on `pendingEquipWeapon`, and the equip sound -- deliberately left out of the first version --
is in.

Gating the hover-in alone would not have been enough. Picking a slot ends pick mode with the pointer
still on that slot, so `MouseLeave` never fires for it and the outline would stay lit on a panel that
has stopped asking for anything. `setSlotPickMode(false)` clears all four directly, and `MouseLeave`
is deliberately NOT gated so it can still put an outline away after the mode has closed.

That fix also required moving `HOVER_STROKE_TWEEN` and `HOVER_STROKE_THICKNESS` to the top of the
file. `setSlotPickMode` is defined above the loop that builds the strokes, and a local declared after
a function is simply not in that function's scope -- leaving them where they were would have thrown
on the first pick. Caught by checking declaration order against first use in the real source
(declared line 64, first used line 700) rather than by reading it back.

## Notes
- The filled-slot case was exercised by painting the state stroke the way `refreshInventoryColumn`
  paints it and then hovering, because driving a real loadout change needs the shop's own open path
  and this test opened the panel directly. The two strokes are independent instances, so the
  coexistence shown above is the real behaviour.
