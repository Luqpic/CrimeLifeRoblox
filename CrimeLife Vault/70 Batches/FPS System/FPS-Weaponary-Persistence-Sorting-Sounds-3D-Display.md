# Change Log: Weapon Ownership Persistence, Sorted Shop, Purchase Sounds, 3D Weapon Display

**Date:** 2026-09-15
**Status:** Applied

## Summary
Fixed weapons vanishing on death, and polished the shop. This place's respawn wipes a player's carried items, so anything bought was lost the first time they died. Ownership is now tracked as data on the server and handed back on every spawn, with the free crowbar folded into that same system instead of being granted by a separate mechanism. Alongside that: the shop grid is sorted cheapest first, buying and upgrading each play a sound, and the detail panel shows a real rotating 3D model of the weapon instead of a flat icon.

## Changes
- `StarterPack` — the crowbar grant added in the previous pass was removed; it is now handled by the same ownership system as everything else, so there is only one path by which a player ends up holding a weapon.
- `ServerScriptService.Weapons.Scripts.WeaponShopService` — rewritten. It now keeps a per-player record of which weapons are owned, seeds every new player with the crowbar, and rebuilds the player's carried weapons from that record on every spawn. Purchases, swaps and the four-weapon cap all read from that record rather than from whatever happens to be carried at the time, so swapping a weapon away genuinely gives it up rather than only clearing it until the next death. The catalog each client browses also now carries a copy of each weapon's visual model.
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` — the detail panel's static icon box was replaced with a viewport that can render a live 3D model.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — grid sorted by price ascending in every category; purchase and upgrade sounds added; the detail panel now clones the selected weapon's model, frames it from its own bounding box, and spins it, tearing the spin down whenever the panel is left or the shop closes.

## Notes
- The original plan only restored weapons on the spawn-after-death signal, which never fires for the character a player already has when they join. That would have left a fresh player holding nothing at all until their first death, so the restore also runs for an already-present character, and was made safe to run twice so the two paths cannot hand out duplicates.
- The rotating model was specified to spin around the weapon's own pivot point, but a weapon's authored pivot is not its centre, so it orbited rather than turning in place. Measured on the largest rifle, its centre swung a noticeable fraction of the model's own length per revolution; spinning about the centred origin instead holds it exactly still. Pistols were unaffected either way, which is why this only shows on the larger guns.
- Restoring weapons on respawn adds them to the player's carried items exactly the way a purchase does, so the purchase sound had to be told the difference. It only plays for a sound armed by an actual buy click; this was confirmed silent across a respawn that handed back four weapons at once.
- Ownership is session-only, matching how cash and levels already work in this place. Nothing survives a player leaving and rejoining.
