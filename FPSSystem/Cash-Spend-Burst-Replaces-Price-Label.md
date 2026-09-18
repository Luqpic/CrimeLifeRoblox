# Change Log: Cash Burst On Spend, Replacing The Red Price Label

**Date:** 2026-09-19
**Status:** Applied (wiring verified; animation not observed -- see Notes)

## Summary
Buying and upgrading a weapon confirmed the spend with a short-lived red "-1500" label that rose and faded over the price. The figure was already on the price pill the player had just clicked, so the label restated it; what it did not convey was that cash had physically left. Spending now throws a burst of coins out of the button, which fade where they land.

## Changes
- New `ReplicatedStorage.UI.CashBurst` -- `burstFrom(origin, amount)` spawns coins at a GuiObject's centre, scatters them outward, then fades them out on a stagger. Each call owns its overlay and destroys it when the last coin is gone, so repeated spends cannot leak overlays.
- `WeaponaryShopController` -- `showCashBurst` now delegates to it; the red label and its three constants are gone. Both call sites (buy and upgrade) are unchanged.

## Notes
- Deliberately the mirror of the Robbery System place's `SharedSystems.CashClaimVFX`, which plays the inbound half: coins scatter from the claim toast and then fly INTO the cash HUD as the counter ticks up. Money leaving has nothing to fly toward, so these scatter and fade instead. Same coin slice, so spending and earning read as one currency.
- The burst originates from the action button rather than the price label: the button is what was clicked, and the price pill sits inside it, so the burst still covers the figure it confirms.
- Coin count scales with the amount, clamped 8..20, so a cheap upgrade still reads as a burst and an expensive one cannot carpet the screen.
- `AbsolutePosition` is measured below the top bar while the overlay ignores the inset, so the inset is added back -- otherwise every burst sits about 36px high.
- **Verified:** the module loads, spawns the correct coin count (11 for a 1500 spend), positions them at the button's centre, and guards against a zero-size origin. Wiring, call sites and declaration order checked.
- **Not verified live:** the scatter and fade themselves. The Studio viewport was collapsed to 1x1 with `RenderStepped` firing zero frames per second, and TweenService is render-driven -- a plain control tween on a throwaway object did not advance either. This is environmental, not a property of the module; it needs one look with the Studio window focused.
