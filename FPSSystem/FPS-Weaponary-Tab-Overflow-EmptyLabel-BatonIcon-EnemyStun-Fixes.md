# Change Log: Shop Tab Overflow, Empty-Slot Text, Baton Icon, Enemy Stun Recovery

**Date:** 2026-09-15
**Status:** Applied

## Summary
Four corrective fixes to the Weaponary shop and the baton. The category tabs ran past the panel's right edge, the placeholder text in empty inventory slots rendered enormous, and the baton was still wearing the crowbar's icon everywhere a player looks — which is what "the baton came out as a crowbar" actually was, since its model, viewmodel, stats and stun were all already correct. Separately, an enemy stunned while firing an automatic weapon would stop shooting and never start again.

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — category tab widths are now computed to fill the available row exactly, recalculated whenever the row resizes, so any number of categories fits at any panel width instead of six fixed-width tabs overflowing it.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` — the "Empty" placeholder in each of the four inventory slots now has a text size cap, so it reads at a normal size instead of scaling to fill the whole slot.
- `ServerStorage.Weapons.Baton` — cleared the icon it inherited when it was duplicated from the crowbar. It now shows as a named weapon with no icon everywhere, rather than silently wearing the crowbar's.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — the shop's grid cards and inventory slots now hide the icon when a weapon has none, matching what the hotbar already did, so an icon-less weapon looks deliberate rather than blank.
- `ServerScriptService.Enemy.Scripts.EnemyAI` — a stunned enemy now cancels its movement and fire loop once on being stunned rather than every tick, and restarts an automatic weapon's fire loop when the stun lifts.

## Notes
- The baton icon was the whole of the "came out as a crowbar" report. That one property feeds three separate displays — the hotbar, the shop's weapon cards, and the shop's inventory column — so every prominent place a player looks was showing the wrong image while the weapon itself was correct. Cleared rather than replaced with a guessed image; dropping in a real icon later needs no code change, since all three displays read it from the weapon at load.
- The plan reported that the enemy half of the stun had never been applied. It had, and it worked; adding it again would have produced two stun blocks. What was genuinely wrong is subtler: stunning an enemy permanently invalidates its automatic fire loop, and the attack logic deliberately leaves automatic weapons to that loop rather than firing directly, so a stunned enemy stayed silent indefinitely instead of for the stun's one second. Measured before the fix's logic was added: sixteen shots in two seconds before a stun, one during, and none would have followed. After: firing resumes within three seconds of the stun ending.
- An enemy holding its ground in attack range legitimately sits at zero movement speed, which looks identical to being stunned. Confirmed separately that a recovered enemy moved normally again once pushed out of range, so the stun is genuinely releasing.
- Tab widths came out at 110 pixels each for the current six categories, filling the row exactly with the rightmost edge inside the panel.
