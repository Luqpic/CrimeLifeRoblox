---
type: system
tags: [system, melee, combat]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Baton-Stun-Becomes-A-Stagger.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Shop-View-And-Bleed-Effect.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Hit-And-LevelUp-VFX.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Crowbar-*.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weaponary-Melee-Display-Fixes-And-Baton.md", "CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-3-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-3-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md"]
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
- `swingDelay` resolves damage at visual contact, for players and (since 2026-09-11) enemies. Read in Studio on 2026-11-18: Crowbar 0.2 (on `ServerStorage.Weapons.Crowbar` and the enemy copy `ServerStorage.EnemyTemplates.Thug.Crowbar`), Knife 0.2, Baton 0.2; the older 0.25 in the 2026-09-20 easing log is not current.
- **The shot is stamped at the press (2026-11-18).** `BlasterController:shoot` takes `now` (the timestamp and the spread seed) before `resolveHit`, so a `swingDelay` no longer moves the stamp; guns have no delay and are unchanged. Live: Knife pressed at server time 524.387 and 525.220, the Shoot events claimed exactly those and arrived 0.233 and 0.217 s later. With the receive clock a swing tolerates about 0.167 s of hitch plus jitter (0.667 minus 0.5 s) where the contact stamp tolerated 0.067 s ([[Weapons and Blaster]]).
- **Third-person aim.** A third-person swing starts at the head and aims at the crosshair point (`thirdPersonAim`); a miss aims along the camera look (0.30 degrees off with the camera pitched 30 degrees up, 25.92 before). Live: a Knife swing at a dummy about 3.5 studs ahead landed (100,000 to 99,950) from an origin 1.40 studs from the root.
- Tuning as recorded: Crowbar and Baton `damage` 45, `knockbackForce` 90, `range` 6; Knife `damage` 30, `knockbackForce` 20, Price 350, `rateOfFire` 90. Baton Price 500. Security guard's Baton `knockbackForce` 15 (deliberate).
- **Baton stun:** `stunDuration` 1 s stamps `StunnedUntil` on the root part and calls `RagdollController.stagger` for the same duration. Only the Baton (player and Security guard) stuns; the Crowbar does not.
- **Knife bleed:** five ticks of 4 (20 total) over 5 s through the same `TakeDamage` / `Tagged` / `Eliminated` path, so bleed kills pay. `BleedingUntil` on the root part; a new cut refreshes, never stacks. A server-side `BloodParticle` on `UpperTorso`; each tick shows a damage number.
- **Knife backstab:** `backstabMultiplier` 2 replaces the headshot rule: back half of the upper torso, height tight (+0.15), attacker within 60° of straight behind. The label "Backstab!" holds through the 3 s merge window.
- Hit VFX: `MeleeImpact` emits each emitter's `EmitCount`, lives 1.4 s, culled past 250 studs; past 12 concurrent impacts particles drop but part and sound stay.
- Shop preview stands melee upright and spins it at half a gun's rate ([[Weapon Shop and Upgrades]]).

## Combos, heavy, block and parry (2026-11-20)
- **Combo:** a press within the cooldown + 0.6 s of the last swing is the next step, x1, x1.2, x1.5, then over again. The server keys it on the swings' timestamps (`Blaster.Scripts.MeleeMoves.onSwing`, `resolveShot{damageMultiplier}`).
- **Heavy:** hold after a swing; past the cooldown the weapon coils (`Combat.Remotes.MeleeCharge` with that swing's timestamp); let go 0.8 s or more after the swing: x2 and a 0.8 s stagger.
- **Block:** hold F, gamepad L1 or touch BLOCK (replaces RELOAD for melee) with a melee weapon. A melee hit from the front takes 30 % and does not stun or bleed. In the block's first 0.25 s it is a parry: nothing, and the attacker is stunned 1 s. One parry per press; presses must start 1 s apart.
- **Clips:** OBT `PLAYER_SWORD`: Slash1 to 3, Charge, Heavy, and Hold as the guard, Action4 on the character, preloaded on equip.
- **Code:** numbers in `ReplicatedStorage.Combat.MeleeRules`; client `ReplicatedStorage.Blaster.Scripts.MeleeController`.

[[2026-11-20 Melee Combos and Block]]

## Extend it
New melee: clone the Baton / Crowbar Tool and viewmodel, keep `Body` as the invisible rig hub, weld a cloned MeshPart blade (not a `SpecialMesh` scale), add a `profiles` entry, set `Category = Melee` and a `Price`. Stun, bleed, backstab are attributes.

## Watch out
- `SpecialMesh.Scale` is in the mesh's native units: a scale copied from another mesh means nothing (giant Knife, 2026-09-21).
- Seat a blade against the live posed grip, not the arm joint's rest transform.
- `RagdollController.ragdoll` must schedule `onFinished` above its already-ragdolled guard, or a body killed mid-stagger is never cleaned up.
- A stunned enemy must restart its automatic fire loop when the stun lifts (fixed 2026-09-15).
- Stun and the landing slowdown share one release in `SprintAuthority`; a server-only zero speed would freeze a player forever.
- Melee viewmodels ship the gun `Shoot` ids (recoil); the swing is procedural.
- `ServerStorage.EnemyTemplates.Security.Baton` has no `swingDelay` (it hits at once). Not changed.
- Melee acceptance under a real frame hitch was not reproduced live (melee has infinite ammo, so the ammo read-back does not work); the server side is covered by the `ShotRate_Test` Knife case, stamped at the press versus at contact.
- Not verified by eye: Knife blade roll and third-person hold, the bleed damage number, `MeleeImpact` look in motion, the procedural swing from a real click.

## History
- 2026-11-20: combo, heavy, block and parry; OBT sword clips on the character; touch BLOCK. [[2026-11-20 Melee Combos and Block]]
- 2026-11-18: the melee shot is stamped at the press, not at contact; third-person melee aims from the head at the crosshair; Crowbar, Knife and Baton `swingDelay` read as 0.2 in Studio; `Security.Baton` has none. [[2026-11-18 Open Items Pass]]
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
