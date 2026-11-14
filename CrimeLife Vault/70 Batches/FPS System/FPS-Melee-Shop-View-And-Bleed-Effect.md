# Change Log: Melee Stands Up in the Shop, and Bleeding Is Visible

**Date:** 2026-09-21
**Status:** Applied. Shop framing and the bleed effect confirmed live with measurements; two items are
geometric changes nobody has looked at yet -- see Not Seen.

## Summary
Four things: the shop's 3D preview no longer frames invisible geometry, melee weapons stand upright
in it instead of lying flat, a bleeding character now visibly bleeds, and each bleed tick shows its
damage number.

## The knife was off-centre because the preview was framing nothing
`showDetail` centres, orients and frames the display model entirely from its bounding box. The Knife's
`Blaster` contains the Crowbar's rig hub -- an invisible 3.32-stud shaft the blade welds to -- so the
box was mostly empty space. The model was centred on a box the player cannot see, which pushed the
visible blade to one side and shrank it to fit.

Invisible parts are now dropped from the display clone before anything measures it, guarded so a
weapon that is somehow all-transparent keeps its parts rather than vanishing. Measured after: the
Knife's display model is one part (`Blade`), centre offset **0.0000 studs**.

## Melee now stands up
The orientation is derived per weapon from the bounding box -- longest extent across the screen,
thinnest toward the camera. That is right for a gun, which reads along its barrel, and wrong for a
blade or a bar, which lie flat and waste a tall viewport.

For `Category == "Melee"` the longest extent goes to the vertical instead. The basis is rebuilt with
Z negated, because swapping two axes of a right-handed basis flips its handedness and a left-handed
basis mirrors the model.

Measured world extents in the live viewport:

| weapon | across | up | depth | long axis |
|---|---|---|---|---|
| Knife | 0.54 | **2.20** | 0.34 | vertical |
| Crowbar | 0.26 | **4.70** | 0.73 | vertical |
| AK47 | **5.88** | 2.01 | 3.99 | horizontal, unchanged |

Guns take the original branch byte for byte.

## Bleeding is now visible, and counts
- `ReplicatedStorage.VFX.BloodParticle` -- the supplied emitter, kept dormant as a template beside
  the other VFX so the resolver clones it rather than reaching into a loose Workspace part.
- `applyBleed` parents an enabled copy to the target's `UpperTorso` (falling back to `Torso`, then
  the root part). Parented on the SERVER, so every client sees it rather than only the attacker.
  Chest height rather than the root part so it follows the body through a ragdoll.
- `clearBleedEffect` switches it off when the bleed ends, dies, or the target is gone, and hands it
  to `Debris` with the emitter's own particle lifetime so the last drops finish rather than being
  cut mid-flight.
- Each tick now calls `showDamageIndicator`, the same floating number a direct hit shows, so the
  bleed is legible instead of a health bar falling for no visible reason. Never flagged as a
  headshot -- a bleed does not land anywhere in particular.

Measured across one cut: no emitter before, `BleedingEffect on UpperTorso enabled=true` immediately
after and through the bleed, and gone by t+7.5s. Health fell 1000 -> 970 on the swing and -> 950
over the five ticks.

## The viewmodel knife was upside down
Rolled half a turn about the blade's own long axis. Worth recording how the first attempt was wrong:
composing the roll on the LEFT rotates about the Body's origin, and the blade is offset from that
origin, so the whole knife swung across to the other side of the hand -- the butt moved from 0.35 to
0.69 studs off the grip. Composing on the RIGHT keeps the rotation in the blade's own frame and turns
it in place: butt 0.35, tip 1.85, exactly as before the flip.

## Not seen
- **Whether the flip is now the right way up.** The roll is geometrically confirmed -- it turned 180
  degrees about the correct axis without moving the ends -- but which way up that leaves the blade is
  a visual question. If it is still wrong, the same roll applied to the world model is the next thing
  to try; only the viewmodel was flipped, since only the viewmodel was reported.
- **The bleed damage indicator appearing.** The call is wired into the tick beside the damage that
  was verified, but the indicator itself is client HUD and was not watched.
- **The Workspace source part.** `Workspace.Part` still holds the original `Blood Particle`. It is
  now duplicated in `ReplicatedStorage.VFX`, so the Workspace one can go whenever you like.
