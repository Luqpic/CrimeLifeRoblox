# Change Log: The Knife, a Melee Weapon That Bleeds

**Date:** 2026-09-21
**Status:** Applied. Mechanics confirmed live (damage, bleed total, refresh-not-stack, catalog entry).
**Appearance and in-hand equip were NOT verified** -- see Not Verified.

## Summary
A new melee weapon built from the Baton, dealing moderate damage and leaving the target bleeding for
five seconds. It reaches the Weaponary shop on its own, with no shop code touched.

## Built from the Baton, not the Crowbar
The Baton is already a single-body melee derived from the Crowbar, so its rig, joints, sound set and
animation set are exactly the shape a new melee wants. Cloning it means the Knife inherits the
crowbar animation set the request asked for, on both the character and the viewmodel, with no
retargeting:

```
tool  Idle rbxassetid://6170792878   Shoot 6783943440   Shoot2 6783954162   Shoot3 6783965485
view  Idle rbxassetid://17650466245  Shoot 6783943440   Shoot2 6783954162   Shoot3 6783965485
```

The shape comes from a `SpecialMesh` on `Blaster.Body`, which is how the Baton was made. That part
is the rig hub -- the arms Motor6D to it and it Motor6Ds to Root -- so swapping the MESH rather than
the PART keeps every joint, attachment and trail exactly where the donor had them. This is the
"add a mesh rather than replace the core part" rule the weapon archive already records.

## Changes
- `ServerStorage.Weapons.Knife` (new) -- Baton clone. `SpecialMesh.MeshId` set to the prepared mesh
  `rbxassetid://3499835987`, scale 0.7. `damage` 30 (Crowbar and Baton are both 45),
  `knockbackForce` 20, `stunDuration` cleared (stunning is the Baton's identity), `viewModel` set to
  `Knife`, `Category` Melee, `Price` 350.
- `ReplicatedStorage.Blaster.ViewModels.Knife` (new) -- Baton viewmodel clone, same mesh swap at
  scale 0.85.
- `ReplicatedStorage.Blaster.Constants` -- `BLEED_DURATION_ATTRIBUTE` and `BLEED_DAMAGE_ATTRIBUTE`,
  opt-in like every other weapon extension here. Every other weapon leaves them unset.
- `ServerScriptService.Blaster.Scripts.ShotResolver` -- `applyBleed`, and a call from the hit path.

## How the bleed works
Ticks go through the same `TakeDamage` + `Tagged` / `Eliminated` path a direct hit uses, so a kill by
bleeding still pays cash, grants XP and counts toward a quest. All three listen to `Eliminated`, and
none of them had to learn that bleeding exists.

`BleedingUntil` is stamped on the target's root part, mirroring `StunnedUntil` -- a plain replicated
signal, so anything that wants to SHOW bleeding can read it without the resolver knowing.

A second cut refreshes the clock rather than starting a second loop. A melee swing resolves several
rays against one target, so without that guard a single swing would start six loops and tick six
times a second.

## The tick count bug, caught by measuring
The first version compared `os.clock()` against an expiry. `task.wait` overshoots slightly, so after
five one-second waits the clock is already past a five-second deadline and the fifth tick is
rejected -- a 5s bleed at 4/s dealt **16**, not 20. It now counts ticks, which says what was
intended: five seconds of bleeding is five ticks.

## Verification
| check | result |
|---|---|
| swing damage | **30**, as configured |
| bleed, second by second | 966 / 962 / 958 / 954 / 950 -- five ticks of 4 |
| bleed total | **20** |
| `BleedingUntil` | set on hit, true through t+5, cleared by t+6 |
| three rapid cuts | total still **20**, not 60 -- refreshes, does not stack |
| shop catalog entry | present: `Category=Melee Price=350 damage=30 range=6 rateOfFire=90 magazineSize=1` |
| shop 3D display body | cloned into the catalog entry |
| viewmodel | `ReplicatedStorage.Blaster.ViewModels.Knife` present |

The shop needed no code change: `WeaponShopService` builds the catalog from every Tool in
`ServerStorage.Weapons` carrying a `Category`, so the Knife appears in the Melee tab by existing.

## Not verified -- needs one look
- **How it looks.** The mesh is swapped but its orientation and scale were never seen. The prepared
  mesh is 0.50 x 2.20 x 0.26, long on **Y**, while the donor body part is long on **Z** -- so the
  blade may well sit rotated ninety degrees in hand and in the viewmodel. `SpecialMesh` has no
  rotation, so if it is wrong the fix is either an offset on the mesh or rebuilding `Blaster.Body` as
  a MeshPart and re-seating the three Motor6Ds. Scales (0.7 tool, 0.85 viewmodel) were derived from
  the donor's proportions, not judged by eye.
- **Equipping it in game.** Granting the weapon in test never put it in the Backpack: the shop
  service owns that, and setting the ownership attribute plus a loadout slot was not enough to make
  it hand the tool over. Buying it through the shop is the real path and was not exercised, so the
  `viewModel` wiring is verified by the viewmodel existing and being named correctly, not by holding
  it.
- **No shop icon.** `TextureId` is empty, so the grid falls back to the name. Every other weapon has
  an uploaded icon.
