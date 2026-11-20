---
type: trap
tags: [trap, physics, character, humanoid, raycast]
updated: 2026-11-20
sources: ["70 Batches/FPS System/FPS-Carried-Weapons-Absorbed-Hits.md", "70 Batches/FPS System/FPS-Clustered-Enemies-Stop-Attacking.md", "70 Batches/FPS System/Enemies-Climbing-Each-Other-And-Nameplate-Gap.md", "70 Batches/FPS System/FPS-Shotgun-Kill-Knockback.md", "70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "70 Batches/FPS System/FPS-Baton-Stun-Becomes-A-Stagger.md", "OBT Vault/50 Engine Traps/Physics and Character Traps.md (generic traps)", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-1-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-2-report.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Physics and Character Traps

Humanoids, raycasts, collision groups, rigs and knockback. Systems: [[Weapons and Blaster]], [[Melee]], [[Enemies and Spawner]], [[Ragdoll]].

## Raycasts and hits

### A hit on a carried weapon finds no Humanoid
- **Symptom:** a baton swing failed to land 20 times in a row; shots on armed enemies did nothing.
- **Cause:** the hit code did `raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid")`. A body part's parent is the character, but a Tool's visible geometry sits in its own Model inside the Tool, so the hop lands on the weapon's Model (`...Enemy.Mossberg 590.Blaster.TrimD`, tagged nil): no damage, no knockback, no stun.
- **Fix:** `ReplicatedStorage.Blaster.Utility.findOwningHumanoid` walks up from the hit part to the owning character, through a carried Tool; `castRays` and `ShotResolver` both use it (one owner). Walls, props and dropped Tools still resolve to nil. **Bit us:** [[FPS-Carried-Weapons-Absorbed-Hits]].

### An occlusion cast blocked by an ally freezes the AI
- **Symptom:** clustered enemies "hit, stop, and stall, and it repeats when I move".
- **Cause:** `castRays` excluded only the shooter's own character. Another enemy (or its weapon) in front stopped the cast; enemies cannot damage enemies, so `taggedHumanoid` came back nil and `ShotResolver.hasLineOfSight` read it as blocked. `_thinkAttack` drops to Chase on lost sight; `_thinkChase` only returns to Attack with sight; an enemy on top of its target has nowhere to path.
- **Fix:** `hasLineOfSight` became a bounded loop: a cast stopped by anything with a humanoid above it steps past that blocker (`LINE_OF_SIGHT_ALLY_STEP` 2.5 studs) and looks again; a wall still returns false. **Bit us:** [[FPS-Clustered-Enemies-Stop-Attacking]].

### A ray starting inside a part never meets it (OBT)
- A muzzle pushed into a body misses that body. Cast the head-to-muzzle stretch first.

### Raycasts obey collision groups (OBT)
- A ray meets only parts whose group collides with its `RaycastParams.CollisionGroup`; a group that collides with nothing is invisible to every ray.

### An NPC semi-auto that fires faster than its recoil decays climbs over the target's head
- **Symptom:** two Offenders at 35 studs hit a standing player 8 times in 42 shots (7.2 damage a second); Police landed 12 of 24. The same guns at a slower cadence hit far more.
- **Cause:** each NPC shot kicked the aim up 18 to 34 degrees and the AI's recoil decay was 69 degrees a second. At a 0.25 s cadence the kick had not decayed before the next shot, so the aim climbed over the target's head. At 0.45 s it settles: 15 of 26 hit.
- **Fix:** cap semi-automatic NPC fire at one shot per 0.45 s (`Combat.shotInterval`). Side effect: the same guns became deadlier (Offender standing 7.2 to 14.0 dps), so retune `DamageOverride` after any cadence change, not before. **Bit us:** [[2026-11-20 Readable Gunfights and Level Toughness]].

### A melee guard that measured its reach before turning never struck
- **Symptom:** a Security guard with a Baton did nothing to a player at 3.5 studs, in Play (the specs passed).
- **Cause:** the reach test measured from the Baton's muzzle while the guard still faced away, so the muzzle was 6.1 studs from the target, just outside the 6-stud reach. The guard only turned when it struck.
- **Fix:** turn to the target first, then measure the reach from the muzzle. A regression case in `GuardSpec` ("4 studs: it strikes") failed first and then passed. **Bit us:** [[2026-11-20 Readable Gunfights and Level Toughness]].

- **An angle tolerance to a body's centre fails up close.** atan(10 / distance) to the pivot refused real hits at 5 to 7 studs while moving (71 to 73 degrees). Measure the sideways distance from the ray instead. [[2026-11-20 Hit Registration]]
- **Bullets pass through a player's accessories** (`RayExclude` from `AccessoryFiltering`): a shot through hair or a coat looks like a hit and deals nothing. [[2026-11-20 Hit Registration]]

## Humanoids

### Interpenetrating Humanoids climb each other
- **Symptom:** enemies stacking on top of each other; closest pair a constant 1.56 to 1.59 studs apart over a 45 s, 60-enemy run.
- **Cause:** two interpenetrating Humanoids each treat the other as ground and step up onto it, indefinitely. They interpenetrated because every enemy type spawned from a single point.
- **Fix:** an `EnemyCharacter` collision group that does not collide with itself (only the self-pairing off), plus spawn scatter. After: peak rise 0.3 studs, all 679 enemy parts in the group. **Bit us:** [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]].

### Movement locks do not change the pose
- A stun that only zeroes `WalkSpeed` leaves the rig idling on the spot; a stagger needs an animation or ragdoll state. [[FPS-Baton-Stun-Becomes-A-Stagger]].

### A client's partial `Humanoid.Health` changes never reach the server, only the death does
- Measured 2026-11-18 ([[2026-11-18 Open Items Pass]]): the client set `Health = 50` and called `TakeDamage(20)`, the server stayed at 100 with no `HealthChanged`. A client `Health = 0` (what the reset button does) reached the server as `HealthChanged 0` at +4.875 s and `Died` at +4.876 s (`Died` fired three times). A server `TakeDamage(500)` gave `HC -400` in the same frame, then `HC 0` and `Died` on the next. So the server cannot tell a self-reset from a lethal blow that came with no other record; keep a server-side damage record ([[Police and Wanted]]).

### `CanQuery = false` does nothing while `CanCollide` is true
- Measured 2026-11-18 in Edit on a probe part in collision group `CarrierLedge`: a ray in group `Carrier` hit it before and after setting `CanQuery = false`; the Default-group ray and `GetPartBoundsInBox` already missed it, because of the collision group. Only the group keeps queries off. `Mouse.Target` was not measured. The Bank's carrier ledges carry both settings for that reason ([[Robbery Heists and Getaway]], [[2026-11-18 Open Items Pass]]).

### A Humanoid restores its limbs' CanCollide (OBT)
- To stop a body colliding, move its parts to a collision group, not `CanCollide = false`.

### CharacterRemoving is not a death; lowering MaxHealth fires HealthChanged (OBT)
- End things on `Died` or a health check; ignore a Health drop caused by a MaxHealth clamp.

### `CFrame.lookAt(p, p)` is NaN (OBT)
- A part set to it lands at (0, -1,000,000, 0) with no error. Guard the look point.

## Knockback and ownership

### A velocity on the frame of a shot proves an impulse, not a fling
- An earlier claim that the shotgun kill fling worked was wrong. Measure the settled distance; it also varies with terrain (16.5 vs 41 studs in two batches). [[FPS-Shotgun-Kill-Knockback]].

### A server push on a player lands softer
- A player's character is physics-owned by their own client, so a server-applied knockback may be overridden. Not verified for the RPG ([[FPS-RPG-Gamepass-Launcher]]); needs a [[Two-Player Test]].

### The client owns its character (OBT)
- A server `PivotTo` of a player does not stick. Move it from the Client.

## Rigs

### The character's joints are AnimationConstraints: tilt them by moving `Attachment0.CFrame`
- **Symptom:** code written for Motor6Ds (`Motor6D.C0`, `Transform`) does nothing, or errors, on the current R15 rig; `Lean` and `Turning` returned early for this reason since 2026-09-11.
- **Cause:** the rig's joints (`Waist`, `Neck`, hips, `Root`) are `AnimationConstraint`s, and their `C0` can be read but not assigned.
- **Fix:** move the joint's `Attachment0.CFrame` (cache the rest value per attachment and put it back exactly). The shoulder camera tilts the waist and the neck this way (neck 18 degrees for a 45-degree look up). [[Ragdoll]], [[Weapons and Blaster]]
- **Bit us:** [[2026-11-20 Admin Animations Third Person]]

### Anchoring a Motor6D-driven part freezes it
- Anchor only a rig's root part. [[FPS-Viewmodel-KeyframeSequence-Export]].

### Replace the mesh, never the core part
- The weapon rig's core part is the hub: arm Motor6Ds, the tool weld, `MuzzleAttachment` and the trail hang off it. Swapping the part breaks all of them; swapping the mesh breaks none. [[FPS-Knife-Bleed-Melee]], [[Building Rules]].

### A clip played before it has loaded shows the rest pose (OBT)
- Preload animations when the character spawns.

### AutomaticScalingEnabled writes values onto the rig (OBT)
- Deleted `OriginalSize` values come back while scaling is on.

Related: [[Engine Traps MOC]] · [[Camera and Input Traps]] · [[Streaming and Replication Traps]]
