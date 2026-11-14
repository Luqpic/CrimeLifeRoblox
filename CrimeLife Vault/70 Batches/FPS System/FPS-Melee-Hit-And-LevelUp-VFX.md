# Change Log: Authored Melee Hit VFX and Level-Up Burst

**Date:** 2026-09-19
**Status:** Applied (full lifecycle confirmed live in a playtest; one item needs an eye — see Notes)

## Summary
Two VFX rigs were authored in Workspace and left unwired. They are now the melee hit effect and the
level-up effect. The level-up replaces the single bright shine emitter the player used to light up
with. Neither costs the server anything: both play entirely on each client.

## Where they came from
| Authored rig | Now lives at |
|---|---|
| `Workspace.Folder.Punch` — 8 emitters | `ReplicatedStorage.Blaster.Objects.MeleeImpact` |
| `Workspace.VFX (Used for Level up)` — 4 emitters, 5 beams, 2 lights | `ReplicatedStorage.VFX.LevelUpBurst` |

## Changes
- `ReplicatedStorage.Blaster.Objects.MeleeImpact` — the single `HitEmitter` replaced by the eight
  emitters of the authored `Punch` rig. Each carries an `EmitCount` attribute (Flash 1, Debris 12,
  Shards 12, Crecents 3, Dots 15, Dust 10, Dust2 10, Waves 1) so the burst is tuned in Studio rather
  than in code. All eight are disabled on the template: the authored `Rate` describes a continuous
  effect, and this one is one-shot.
- `ReplicatedStorage.Blaster.Effects.impactEffect` — the melee branch now emits every
  `ParticleEmitter` in the rig at its own `EmitCount` instead of calling one named emitter, and holds
  the part for the longest authored particle lifetime (1.4s) instead of a flat 0.5s. Two bounds
  added, melee-only: nothing is built beyond 250 studs from the camera, and past 12 concurrent melee
  impacts the part and its hit sound are still created while the particles are dropped.
- `ReplicatedStorage.VFX.LevelUpBurst` (new) — a copy of the authored rig, made massless,
  non-colliding, non-querying and shadowless. Carries `EmitSeconds` (1.5) and `MaxParticleLifetime`
  (3.0) as attributes.
- `StarterPlayer.StarterPlayerScripts.LevelUpVFX` — rewritten. The dormant-emitter-per-character
  approach is gone; the rig is cloned on level-up, welded to the root part at ground height, allowed
  to emit for `EmitSeconds`, then every emitter, beam and light is switched off and the clone is
  destroyed once the last particle has expired.

## Why the level-up rig could not stay dormant
The effect it replaces was one `ParticleEmitter` parked on every character at spawn and fired with
`:Emit()`, which costs nothing while idle. This rig is beams and lights as well as particles, and
those render whenever they are enabled — parking one on every character would light the whole round.
Cloning on level-up is the trade: level-ups are rare, and nothing exists between them.

## Verification
Confirmed in a playtest, driven through the real `Level` attribute path:
- Level-up: one `LevelUpBurst` appears, welded to `HumanoidRootPart`, massless and non-colliding, at
  Y = 1.00 — matching the predicted foot height of `root.Y 4.15 - rootSize.Y/2 1.05 - hipHeight 2.10`.
- Its lifecycle: `11/11` emitters, beams and lights enabled at t+0.8s; `0/11` at t+2.0s, after the
  1.5s cutoff; destroyed by t+5.0s, after the 4.5s total.
- Melee: one hit produces one `MeleeImpact` carrying all eight emitters with their `EmitCount`
  attributes intact, and it is gone within 2s.
- Distance cull: a hit 400 studs from the camera creates nothing.
- Concurrency: 20 simultaneous hits produce 20 parts — the cap drops particles, never hit feedback —
  and all 20 are cleaned up within 2s.

## Notes
- The per-swing, per-humanoid deduplication that stops a multi-ray melee swing stacking effects
  already lived in `drawRayResults` and was left untouched. This change inherits it.
- Gun impacts are deliberately unchanged. They are two emitters over 0.5s; the melee rig is eight
  over 1.4s, which is what the two new bounds are sized for.
- The cap deliberately keeps the part and its hit sound when it drops the particles. A crowded fight
  should lose visuals, never the audio confirmation that a swing connected.
- `Workspace.Folder.Hiteffect` (a MeshPart) was **not** used. Its attributes — `EmitDelay`,
  `Duration`, `TimeBeforeReset`, `Size`, `Rotation`, `Transparency`, `CFrame` — are all zero, so it
  is an unconfigured stub from whatever pack it came with. Animating it would have meant inventing
  its timing. Say what it should do and it can be added.
- **Not verified:** how the rigs actually look in motion. The lifecycle, positioning, counts and
  cleanup were all measured, but nobody has watched a crowbar land or a level tick over. The
  level-up rig carries a `PointLight` at brightness 300 over range 6, which is the author's tuning
  and may read as a flashbang up close.
- The authored originals were deleted from Workspace once the templates were confirmed intact:
  `Workspace.Folder` (8 emitters) and `Workspace.VFX (Used for Level up)` (4 emitters, 5 beams,
  2 lights). Every one of those was enabled and running each frame for every player, which is pure
  cost now that both rigs live in ReplicatedStorage and are cloned on demand.
- `Workspace.Folder.Hiteffect` was kept rather than lost with its folder — it is now
  `ReplicatedStorage.VFX.Hiteffect`, still unwired, still awaiting a description of what it should do.
- `ReplicatedStorage.VFX.LevelUpShine` is no longer referenced by anything. Left in place; safe to
  delete once the new burst is signed off.
