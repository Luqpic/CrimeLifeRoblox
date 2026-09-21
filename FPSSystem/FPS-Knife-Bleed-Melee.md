# Change Log: The Knife, a Melee Weapon That Bleeds

**Date:** 2026-09-21
**Status:** Applied and confirmed live end to end, including equipping it in first person. The first
build was wrong in two ways -- see Two Faults In The First Build.

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
- `ServerStorage.Weapons.Knife` (new) -- **Crowbar** clone. Its Body is kept but made invisible (it
  is the rig hub: the arm Motor6Ds, the tool weld, MuzzleAttachment and the trail all hang off it),
  the five cosmetic Trim collars are removed, and a clone of `Workspace.Knife` is welded on as
  `Blade`. `damage` 30 (Crowbar and Baton are both 45), `knockbackForce` 20, `viewModel` `Knife`,
  `Category` Melee, `Price` 350.
- `ReplicatedStorage.Blaster.ViewModels.Knife` (new) -- Crowbar viewmodel, same treatment.
- `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` -- a `Knife` profile, the Crowbar's
  melee entry verbatim. Mirrored into `FPSSystem/ViewmodelAnimations/WeaponViewmodelMotion.luau`,
  which is the authoring copy.
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

## Two faults in the first build
The first attempt cloned the **Baton** and gave its `SpecialMesh` the knife's MeshId. Equipping it
produced a knife taller than the character, and no first person at all.

**The giant blade.** `SpecialMesh.Scale` multiplies the mesh's own native units. The scale 0.7 was
carried over from the Baton, whose mesh has completely different native dimensions -- so it meant
nothing for this one. The rebuild welds a CLONE of the prepared MeshPart instead, which carries its
authored size (0.50 x 2.20 x 0.26) and needs no scale at all. Measured on the equipped tool
afterwards: blade 2.20 studs, largest dimension anywhere on the weapon 3.32 (the invisible shaft).

**No first person.** Nothing to do with the mesh. The console named it exactly:

```
ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion:155: No viewmodel animation profile: Knife
  WeaponViewmodelMotion.new <- ViewModelController.new <- BlasterController.new
```

`WeaponViewmodelMotion` asserts on a weapon it has no profile for, and that exception aborts
`BlasterController.new` -- so the viewmodel was never built and the camera never switched. Any new
weapon needs an entry in that table; the Knife now has the Crowbar's.

## Verified after the rebuild
| check | result |
|---|---|
| equipped | `Knife` |
| camera | **`LockFirstPerson`** -- first person engages |
| viewmodel | `Knife` present in Workspace |
| viewmodel blade | 0.50 x 2.20 x 0.26, body transparent, 0 leftover Trim parts |
| world model | blade 2.20 studs, Body and Handle invisible |

## Still not verified -- needs one look
- **Blade angle.** Size is now right and was measured, but which way the blade POINTS was not seen.
  The mesh is long on Y and the body it welds to is long on Z, so the clone is turned a quarter turn
  about X to face down the weapon's forward axis. If it sits sideways or upside down, that single
  rotation in the build is the knob.
- **Carry distance.** The Knife uses the Crowbar's motion profile verbatim, and a knife is shorter
  than a crowbar, so it may be held further out than it should be. The two numbers in the profile
  are carry length and grip.
- **No shop icon.** `TextureId` is empty, so the grid falls back to the name. Every other weapon has
  an uploaded icon.
