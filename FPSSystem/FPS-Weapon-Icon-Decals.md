# Change Log: Weapon Icon Decals

**Date:** 2026-09-13
**Status:** Applied

## Summary
Uploaded artwork for all sixteen weapons and wired it into the two places weapons are shown visually: the custom inventory hotbar and the floating stat panel above each world pickup. The hotbar needed no code at all — its slot builder already read each Tool's `TextureId` and had a live changed-connection for it, and that property had simply been left empty since no art existed. The billboard did need wiring, because `ServerStorage` never replicates to clients, so the icon id has to be mirrored onto the pickup Model the same way the damage, ammo and fire-rate numbers already are.

## Changes
- `ServerStorage.Weapons.*` — every one of the sixteen Tools now has a real `TextureId` pointing at its own uploaded icon decal.
- `ServerScriptService.Weapons.Scripts.WeaponPickup` — the stat-mirroring step now also copies the weapon's icon id onto the pickup Model as an `iconId` attribute; it needs its own line because `TextureId` is a property rather than an attribute, so it doesn't fit the existing generic attribute loop.
- `StarterPlayer.StarterPlayerScripts.WeaponStatBillboard` — the stat panel's icon square now reads that mirrored `iconId` when a panel is built, replacing the gray placeholder. It is a one-time read, matching how the weapon name is handled, since a pickup's icon never changes after it is built.

## Notes
- Two source filenames did not match their Tool names (`FN-P90` versus `FN P-90`, and `Scar-L` versus `Scar L`). Both pairings were checked individually after upload to confirm the right image landed on the right weapon.
- All sixteen decals were confirmed to actually fetch successfully in play mode, so none are stuck behind moderation.
- The source art is square with transparency, so the icons are not distorted by the panel's stretch fit. The stat panel's icon square still has its opaque dark placeholder background behind the artwork; that was left as-is since it reads as a backing tile rather than a defect, but it is a one-property change if a fully transparent icon is wanted.
