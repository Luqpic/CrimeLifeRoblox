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

## Sounds, icon and grip (2026-09-21, later)
- `Sounds.Equip` -> `rbxassetid://90559856125293`.
- `Sounds.Hit` is now a **Folder** of two, `124216736896680` and `129240409121774`, so repeated stabs
  do not machine-gun one clip. `impactEffect` was taught to accept either a Sound or a Folder here;
  every other weapon still has a plain Sound and takes the original branch unchanged.
- `Sounds.Shoot` (the swing) -> `rbxassetid://129582509517716`.
- `TextureId` -> `rbxassetid://71861214836431`, the supplied icon, uploaded at 512px. The catalog
  picks it up automatically, so the shop grid shows it instead of falling back to the name.

All five assets preload clean: icon loaded, equip 0.21s, hits 1.36s and 1.54s, swing 0.65s.

### Two things the grip fix had to get right
**The blade was pointing at the player.** Seating it by assumption put the TIP 0.95 studs from the
hand and the BUTT 1.53 -- backwards. The mesh's point is at local **-Y**, not +Y, so the quarter turn
about X had to go the other way. Measured after: butt 0.35 from the grip, tip 1.85.

**The rest pose is not the carry pose.** Seating against the arm joint's rest transform put the
handle 1.13 studs from the hand in play -- the knife hanging below the fist, which is what was
reported. `WeaponViewmodelMotion` poses the arms every frame, so the hand actually sits at
`(-0.295, -0.042, 0.000)` in Body space, not the `(0.250, 0.050, 0.631)` the rest transform implies.
Sampled over 40 frames in play, that position does not move at all (wobble 0.000), so it is a
reliable anchor rather than a snapshot.

Re-seated against the live grip:

| | before | after |
|---|---|---|
| handle butt to hand | 1.13 studs | **0.35** |
| blade tip to hand | 1.34 studs | **1.85** |
| tip is the far end | no | **yes** |

The world model is seated against the Tool's `Handle` instead, which is what Roblox welds into the
character's hand, so third person uses its own correct reference.

## Still not verified -- needs one look
- **Blade roll.** The butt-to-hand and tip-to-hand distances are now measured and correct, which
  fixes how far along the knife the hand sits and which way it points. What those numbers cannot see
  is ROLL -- whether the edge faces the right way round the blade's own axis. If it looks turned,
  the third argument of the `CFrame.Angles(math.pi / 2, 0, 0)` in the seating is the knob.
- **Third person.** Only the first-person grip was measured against a live pose. The world model is
  seated against the Tool's Handle, which is the right reference, but nobody has watched the
  character hold it.
- **Carry distance.** The Knife still uses the Crowbar's motion profile verbatim, so the whole
  weapon may be carried further from the camera than a knife should be. That is the profile's two
  numbers, separate from the grip fixed here.
- **No shop icon.** `TextureId` is empty, so the grid falls back to the name. Every other weapon has
  an uploaded icon.
