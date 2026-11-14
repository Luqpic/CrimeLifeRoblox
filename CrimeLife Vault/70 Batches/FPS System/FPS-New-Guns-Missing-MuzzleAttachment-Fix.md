# Change Log: Ten New Guns Had No Firing Mechanism

**Date:** 2026-09-15
**Status:** Applied — fix verified structurally; in-game behaviour not yet confirmed

## Summary
All ten weapons added in the previous loadout expansion equipped as plain objects — held in the hand
with no first-person view, no shooting, no reloading, nothing. Every one of them was missing a single
small marker that sits at the barrel tip, and the weapon code refuses to start up without it. Adding
that marker to all ten restores the whole mechanism; nothing else about the weapons needed changing.

## Changes
- `ServerStorage.Weapons` — added the missing barrel-tip marker, with its muzzle flash, to all ten
  new weapons: M14 EBR, AR-18, HK G3, APS, PB, MP443, Glock 17, S&W 29, Itacha Mag-10 and Benelli M4.
- `ReplicatedStorage.Blaster.ViewModels` — the same marker added to each weapon's first-person model,
  which is where the missing one was actually stopping the weapon from starting.

## Notes
- The cause was one strict check at the very top of the weapon setup code: it demands the barrel-tip
  marker and stops everything if it is absent. That check is the first thing that runs when a weapon
  loads, and the code that listens for equipping, firing and reloading comes later in the same
  routine — so the failure meant none of those were ever connected. With no custom behaviour attached
  at all, the game falls back to holding the weapon as an ordinary object, which is exactly what was
  reported. Confirmed by tracing the setup order directly rather than inferring it.
- Checked across the whole roster rather than sampled: every one of the seventeen existing weapons
  carries this marker in both its world and first-person models, and none of the ten new ones did, in
  either. The melee weapons carry an empty one deliberately, which the code expects.
- Before applying, each of the ten was checked for anything else that might be missing — handle,
  sounds, setup script, first-person model link, animations, arm joints, and connections pointing
  outside their own weapon. All ten were complete in every other respect, so this was genuinely the
  only fault rather than the first of several.
- The plan placed each marker by copying the position from one reference weapon per category. Measured
  against the actual weapons, that reasoning did not hold. Twelve of the fifteen existing guns —
  pistols and rifles alike — place the marker at exactly the same proportion of their own body, which
  is the real convention; it is not category-specific. The three that differ are per-weapon
  adjustments for their particular shapes. Two of those three happened to be the chosen references,
  so following the plan would have put the muzzle flash of the three new rifles roughly two studs out
  in mid-air in front of the barrel, and the two new shotguns between half a stud and one and a half
  studs out. The shared convention was used instead, which places every marker just inside its own
  barrel tip. The muzzle flashes themselves are still copied per category, so each new gun keeps the
  look of its category.
- Placement affects appearance only — the muzzle flash, the tracer's starting point and where the
  shot sound plays from. Aim, damage and hit detection do not use it, so no gun can shoot wrongly
  because of this, only look slightly off. If one does, it is a single value to nudge on that weapon.
- Applies a side benefit: the shop's rotating 3D preview uses this same marker to work out which way
  a weapon's barrel points. The ten new guns had nothing to go on before, so they may have been
  displayed facing backwards; they now orient the same way as every other weapon.
