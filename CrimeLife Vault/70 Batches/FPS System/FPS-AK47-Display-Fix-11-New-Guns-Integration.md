# Change Log: Eleven New Weapons Integrated, and the AK47's Upside-Down Preview

**Date:** 2026-09-16
**Status:** Applied

## Summary
Eleven weapon models had been sitting in the world as raw shapes with no mechanism attached to them.
Each is now a fully working, purchasable weapon. Every one was built by taking an existing weapon of
the same class that already worked and swapping only its visible mesh, so handling, sounds,
animations and hand positions are inherited rather than rebuilt. Separately, the AK47's rotating shop
preview had been showing upside down and is corrected.

## Changes
- `ServerStorage.Weapons` — eleven new weapons with their own stats, prices and icons: Glock 17,
  MP443, PB and S&W 29 as pistols; Benelli M4, Itacha Mag-10 and Spas 12 as shotguns; M14 EBR,
  AR-18, HK G3 and APS as rifles.
- `ReplicatedStorage.Blaster.ViewModels` — a first-person model for each of the eleven.
- `ServerStorage.Weapons.AK47` — a display-rotation correction so its shop preview sits upright.
- `Workspace` — the raw source models removed, after confirming every mesh they held is now carried
  by a built weapon.

## Notes
- The first-person models went through two rebuilds before they were right, and both faults were
  found by inspection rather than by playing. The first attempt replaced each weapon's core part
  outright; because the arms and magazine hang off that part, both hands came away unattached. The
  second attempt moved the correct part into place but not the pieces welded to it, leaving the rest
  of each weapon stranded where it had been authored — as much as a hundred and fifty studs away,
  which reads in play as most of the gun simply missing. The approach that worked keeps the donor
  weapon's whole skeleton intact and invisible and hangs the new mesh off it, so no joint is created,
  moved or deleted at all.
- That skeleton matters more than it looks. On the rifles and pistols the left hand is attached to
  the magazine rather than to the weapon body, which is what lets a reload animation carry the hand
  along with the magazine. Collapsing that chain left reloads looking wrong even though the weapon
  was otherwise fine. Each new weapon now has its own magazine piece attached to that same point.
  The shotguns deliberately have none: they reload shell by shell and their donor has no magazine in
  its skeleton at all.
- Stats follow each real weapon's character relative to the seventeen already in the game rather than
  real ballistics, matching how the existing roster is tuned. Fire modes follow the real weapon: the
  M14 EBR is semi-automatic, the AR-18, HK G3 and APS are automatic.
- The APS is ambiguous as a name. It is treated here as the Russian underwater rifle, which is what
  its size and grouping suggest. If it is meant to be the machine pistol of the same name, only its
  stats would need revisiting, not its integration.
- Three weapons were briefly missing a hidden value that governs how many rays a shot casts, because
  it is only listed explicitly for shotguns and the others inherited nothing. Caught and corrected
  before testing.
- Icons were supplied as 2048-pixel images, twice the size the platform stores, and were reduced
  before uploading. Freshly uploaded images can appear blank for a few minutes until they clear
  moderation.
