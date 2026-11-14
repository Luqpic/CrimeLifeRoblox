---
type: system
tags: [system, melee, combat]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Baton-Stun-Becomes-A-Stagger.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Shop-View-And-Bleed-Effect.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Hit-And-LevelUp-VFX.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Crowbar-*.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponary-Melee-Display-Fixes-And-Baton.md", "CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau"]
---

# Melee

**Skills:** `roblox-game-systems`, `roblox-physics`, `roblox-characters-animation` (load these for work here)

## What it does
Crowbar, Baton and Knife swing on the shared blaster ([[Weapons and Blaster]]) as weapons flagged melee: no ammo, a forgiving multi-ray cone, damage at the moment of visual contact, knockback on every swing, plus per-weapon stun (Baton), bleed and backstab (Knife).

## Where it lives
- Tools: `ServerStorage.Weapons.Crowbar`, `.Baton`, `.Knife`; enemy copies `ServerStorage.EnemyTemplates.Thug.Crowbar`, `.Security.Baton`.
- Viewmodels: `ReplicatedStorage.Blaster.ViewModels.Crowbar`, `.Baton`, `.Knife` ([[Viewmodels and Weapon Animation]]).
- `ServerScriptService.Blaster.Scripts.ShotResolver` (stun stamp, `applyBleed`, `clearBleedEffect`, `isBackstab`).
- VFX: `ReplicatedStorage.Blaster.Objects.MeleeImpact` (8 emitters, `EmitCount` attributes), `ReplicatedStorage.VFX.BloodParticle`; unwired stub `ReplicatedStorage.VFX.Hiteffect`.
- Stun readers: `ServerScriptService.Movement.Scripts.SprintAuthority` ([[Movement and Stamina]]), `ServerScriptService.Enemy.Scripts.EnemyAI` ([[Enemies and Spawner]]); stagger in `ReplicatedStorage.Modules.RagdollController` ([[Ragdoll]]).

## How it works
- Melee = `infiniteAmmo` + `meleeHitEffect`; an empty `MuzzleAttachment` is expected.
- Swing is a multi-ray cone; damage is capped at the configured value however many rays connect. On-hit sound / VFX once per target per swing.
- `swingDelay` resolves damage at visual contact, for players and (since 2026-09-11) enemies. Recorded values: 0.25 for the Crowbar (2026-09-20 easing log) and 0.2 in the export log the same day; unresolved which is current.
- Tuning as recorded: Crowbar and Baton `damage` 45, `knockbackForce` 90, `range` 6; Knife `damage` 30, `knockbackForce` 20, Price 350, `rateOfFire` 90. Baton Price 500. Security guard's Baton `knockbackForce` 15 (deliberate).
- **Baton stun:** `stunDuration` 1 s stamps `StunnedUntil` on the root part and calls `RagdollController.stagger` for the same duration. Only the Baton (player and Security guard) stuns; the Crowbar does not.
- **Knife bleed:** five ticks of 4 (20 total) over 5 s through the same `TakeDamage` / `Tagged` / `Eliminated` path, so bleed kills pay. `BleedingUntil` on the root part; a new cut refreshes, never stacks. A server-side `BloodParticle` on `UpperTorso`; each tick shows a damage number.
- **Knife backstab:** `backstabMultiplier` 2 replaces the headshot rule: back half of the upper torso, height tight (+0.15), attacker within 60° of straight behind. The label "Backstab!" holds through the 3 s merge window.
- Hit VFX: `MeleeImpact` emits each emitter's `EmitCount`, lives 1.4 s, culled past 250 studs; past 12 concurrent impacts particles drop but part and sound stay.
- Shop preview stands melee upright and spins it at half a gun's rate ([[Weapon Shop and Upgrades]]).

## Extend it
New melee: clone the Baton / Crowbar Tool and viewmodel, keep `Body` as the invisible rig hub, weld a cloned MeshPart blade (not a `SpecialMesh` scale), add a `profiles` entry, set `Category = Melee` and a `Price`. Stun, bleed, backstab are attributes.

## Watch out
- `SpecialMesh.Scale` is in the mesh's native units: a scale copied from another mesh means nothing (giant Knife, 2026-09-21).
- Seat a blade against the live posed grip, not the arm joint's rest transform.
- `RagdollController.ragdoll` must schedule `onFinished` above its already-ragdolled guard, or a body killed mid-stagger is never cleaned up.
- A stunned enemy must restart its automatic fire loop when the stun lifts (fixed 2026-09-15).
- Stun and the landing slowdown share one release in `SprintAuthority`; a server-only zero speed would freeze a player forever.
- Melee viewmodels ship the gun `Shoot` ids (recoil); the swing is procedural.
- Not verified by eye: Knife blade roll and third-person hold, the bleed damage number, `MeleeImpact` look in motion, the procedural swing from a real click.

## History
- 2026-09-24: Knife backstab ×2. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- 2026-09-21: Knife upright in the shop, visible bleed, tick numbers. [[FPS-Melee-Shop-View-And-Bleed-Effect]]
- 2026-09-21: the Knife, with bleed. [[FPS-Knife-Bleed-Melee]]
- 2026-09-21: Baton stun becomes a stagger. [[FPS-Baton-Stun-Becomes-A-Stagger]]
- 2026-09-21: swings stop hitting the target's carried gun. [[FPS-Carried-Weapons-Absorbed-Hits]]
- 2026-09-20: procedural viewmodel swing. [[FPS-Melee-Viewmodel-Swing]]
- 2026-09-19: authored `MeleeImpact` VFX. [[FPS-Melee-Hit-And-LevelUp-VFX]]
- 2026-09-19: melee keeps per-swing knockback when shotguns move theirs to the kill. [[FPS-Shotgun-Kill-Knockback]]
- 2026-09-16: Baton viewmodel real mesh. [[FPS-Baton-Viewmodel-Real-Mesh-Fix]]
- 2026-09-15: Baton icon cleared; enemy stun recovery. [[FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes]]
- 2026-09-15: Baton rebuilt as a Crowbar duplicate. [[FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab]]
- 2026-09-15: stun attribute and the Baton. [[FPS-Weaponary-Melee-Display-Fixes-And-Baton]]
- 2026-09-11: enemy melee respects `swingDelay`. [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]]
- 2026-09-11: `swingDelay`, explicit swing sound. [[FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync]]
- 2026-09-11: swing variants and trail. [[FPS-Melee-Combo-And-Shotgun-Reload-Refactor]]
- 2026-09-11: Crowbar knockback 15 -> 90. [[FPS-Crowbar-Knockback-Tune]]
- 2026-09-11: multi-ray cone. [[FPS-Crowbar-Hitbox-And-Shotgun-Cooldown-Fix]]
- 2026-09-11: Crowbar sounds and impact, flash removed. [[FPS-Loadout-Bugfixes-Sounds-VFX]]
- 2026-09-11: Crowbar added. [[FPS-Loadout-Melee-Shotgun-Sniper]]

See [[Batch Log]].
