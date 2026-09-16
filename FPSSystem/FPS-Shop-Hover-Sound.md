# Change Log: The Shop's Buttons Tick on Hover

**Date:** 2026-09-16
**Status:** Applied

## Summary
Moving the cursor over a control in the weaponry shop now plays the same short tick the dialogue
replies already use. It covers the close and back buttons, every category tab, all four inventory
slots, the buy/upgrade button, the equip/dequip button, and every weapon card in the grid. The three
buttons outside the shop that open it — weaponry, player card and quests — are deliberately left
alone; they already have their own click reaction.

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — hover sound on the close button, the
  back button, each category tab, and each of the four inventory slots.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.ActionButton.HoverAndClick` —
  plays the tick alongside the existing grow.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton.StrokeHover` and
  `ReplicatedStorage.GuiTemplates.WeaponCard.StrokeHover` — the same, alongside their existing
  outline growth.

## Notes
- The sound is the one already used by the dialogue replies, reused exactly rather than a new one
  chosen. Hover feedback now sounds the same everywhere in the game instead of differing by which
  system happens to own the button.
- There is one sound for all of it, not one per button. The buy, equip and weapon-card effects are
  each self-contained scripts — and the weapon card's is copied onto every card in the grid — so
  giving each its own sound would have left dozens of identical copies competing. Each instead checks
  for the shared one and creates it only if nobody has yet, so whichever runs first owns it.
- Only hover was added. No existing click behaviour, visual effect, purchase sound or upgrade sound
  was touched.
- Sweeping the cursor quickly across several weapon cards restarts the same sound rather than layering
  copies of it, so a fast sweep clips each tick short. For a sound this brief that reads as intended
  rather than as a fault, but it is a deliberate trade for keeping a single sound rather than an
  oversight.
