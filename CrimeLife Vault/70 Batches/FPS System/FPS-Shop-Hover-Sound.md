# Change Log: Hover and Click Sounds on the Shop and Menu Buttons

**Date:** 2026-09-16
**Status:** Applied

## Summary
Moving the cursor over a control in the weaponry shop now plays the same short tick the dialogue
replies already use: the close and back buttons, the buy/upgrade button, the equip/dequip button, and
every weapon card in the grid. The inventory slots and the category tabs deliberately stay silent.
Separately, the three buttons that open the menus — weaponry, player card and quests — now play a
click sound when pressed.

## Changes
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — hover sound on the close and back
  buttons.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.ActionButton.HoverAndClick` —
  plays the tick alongside the existing grow.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton.StrokeHover` and
  `ReplicatedStorage.GuiTemplates.WeaponCard.StrokeHover` — the same, alongside their existing
  outline growth.
- `StarterGui."Custom Inventory".weaponaryButton.ClickSound`, `.playerCardButton.ClickSound` and
  `.questsButton.ClickSound` (all new) — the click sound on the three menu buttons.

## Notes
- The hover sound is the one already used by the dialogue replies, reused exactly rather than a new
  one chosen. Hover feedback now sounds the same everywhere instead of differing by which system
  happens to own the button.
- The inventory slots and the category tabs were given the hover sound at first and then had it taken
  back off. Four slots and a row of tabs sitting close together meant crossing the panel chimed
  several times on the way to wherever the cursor was actually going.
- There is one hover sound shared by all of it, and one click sound shared by the three menu buttons,
  rather than one of each per button. The buy, equip and weapon-card effects are each self-contained
  scripts — and the weapon card's is copied onto every card in the grid — so a sound per script would
  have left dozens of identical copies competing. Each checks for the shared one and creates it only
  if nobody has yet.
- The click sound is a separate script on each of the three menu buttons rather than an addition to
  their existing bounce effect, because the player card button turns out not to have that effect at
  all — only the weaponry and quests buttons do. All three now sound identical regardless. Worth
  noting on its own: the player card button is missing the bounce its two neighbours have, which
  looks like an oversight from when that effect was added rather than a decision. It was left alone
  here since only a sound was asked for.
- Only hover and click feedback was added. No existing click behaviour, visual effect, purchase sound
  or upgrade sound was touched.
- Sweeping the cursor quickly across several weapon cards restarts the same sound rather than layering
  copies of it, so a fast sweep clips each tick short. For a sound this brief that reads as intended,
  but it is a deliberate trade for keeping a single sound rather than an oversight.
