# Change Log: Hover Outline on the Loadout Slots

**Date:** 2026-09-21
**Status:** Applied (confirmed live with real pointer input, in both the empty and the filled slot state)

## Summary
The four loadout slots in the Weaponary Shop's inventory column -- the ones the "Select a slot to
equip" prompt points at -- now take the same accent hover outline the inventory hotbar slots got.

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
Real pointer input against the live panel:

| state | result |
|---|---|
| all four slots at rest | `HoverOutline` present on each, accent green, 3px, **transparency 1.000** |
| pointer on Slot1 | Slot1 **0.000**, Slots 2-4 still **1.000** |
| pointer moved away | Slot1 back to **1.000** |
| Slot1 painted as occupied (accent 2px), then hovered | state stroke accent @2 **and** hover accent @3 at transparency 0.000 -- the edge reads 3px |
| empty slot, not hovered | state stroke grey @1, hover invisible |

Only the slot under the pointer lights, and the state stroke is untouched throughout.

## Notes
- The click sound added to the inventory hotbar slots was deliberately NOT added here. This panel's
  slots are a pick target during an equip flow, not an equip toggle, and they already play the shared
  hover tick; the request was for the hover effect.
- The filled-slot case was exercised by painting the state stroke the way `refreshInventoryColumn`
  paints it and then hovering, because driving a real loadout change needs the shop's own open path
  and this test opened the panel directly. The two strokes are independent instances, so the
  coexistence shown above is the real behaviour.
