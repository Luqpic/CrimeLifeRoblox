---
type: system
tags: [system, combat, physics, ragdoll]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Baton-Stun-Becomes-A-Stagger.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shotgun-Kill-Knockback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors.md", "CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau"]
---

# Ragdoll

**Skills:** `roblox-physics`, `roblox-characters-animation` (load these for work here)

## What it does
Death presentation for players and enemies: the body goes limp instead of the engine breaking its joints. Since 2026-09-21 it also does a recoverable stagger (Baton stun, RPG survivors), and kill flings (shotguns, RPG) are applied after the body is ragdolled.

## Where it lives
- `ReplicatedStorage.Modules.RagdollController`: `prepare`, `ragdoll`, `isRagdolled`, `stagger`, `recover`.
- `ServerScriptService.Ragdoll.Scripts.PlayerRagdoll` (player death hold, raises `Players.RespawnTime` to match).
- Callers: `ServerScriptService.Blaster.Scripts.ShotResolver` (`flingRagdoll`, stun -> `stagger`, `explode`), the enemy death path ([[Enemies and Spawner]]).

## How it works
- `prepare` sets `BreakJointsOnDeath = false`. The character rig's R15 joints (`Root`, `Waist`, `Neck`, hips) are `AnimationConstraint`s, not Motor6Ds; `ragdoll` disables them, sets `PlatformStand`, adds a `RagdollRootWeld`, sets `IsRagdolled`, and zeroes every part's velocity (deliberate: kills death-lunge momentum). For an enemy this runs a frame after the humanoid dies.
- Corpses use a collision group that does not self-collide (the same mechanism the spawner uses for live enemies).
- `stagger(character, duration)` captures per-part `CanCollide` and `CollisionGroup` before ragdolling and schedules `recover`, which restores them, re-enables the constraints, restores `PlatformStand` / `AutoRotate` / `WalkSpeed` / `JumpPower`, asks for `GettingUp`, clears `IsRagdolled` and returns network ownership to a player. No-op on a body already down; refuses on one that died while down.
- `ragdoll`'s `onFinished` / `holdDuration` scheduling sits above its already-ragdolled guard, so a body killed mid-stagger is still cleaned up.
- `flingRagdoll` waits (up to `FLING_RAGDOLL_WAIT` 0.5 s) for `isRagdolled`, waits one more frame, then sets velocity on every BasePart except those in a carried Tool.
- Player respawn: the visible countdown went 2 -> 5 s on 2026-09-12 with `PlayerRagdoll`'s duration adjusted to stay longer than the death sequence ([[Death Screen]]).

## Extend it
Any knock-down effect should call `RagdollController.stagger` (it restores captured state). A post-death impulse must go through `flingRagdoll`'s wait, never inline with `Died`.

## Watch out
- `AnimationConstraint.C0` can be read but not assigned: old `StarterCharacterScripts.Lean` / `.Turning` errored every frame on this rig and were disabled (2026-09-11); a rewrite is outstanding. `Lean` line 25 still errored on respawn on 2026-09-24 (direct `HumanoidRootPart` index; a `WaitForChild` would fix it).
- Because `BreakJointsOnDeath` is off, dying does not unequip a Tool; the camera reset on death is explicit in `BlasterController`.
- An impulse in the same frame as death is erased by the zeroing pass; pushing only the root moves a ragdoll about 2 studs (14 assemblies drag it back).
- Restore captured values, never defaults: alive rigs had 4 colliding parts, ragdolled 19.
- A server push on another player's character may land softer (client physics ownership); not verified.
- Settled distance varies with terrain (16.5 vs 41 studs at the same speed in one test).

## History
- 2026-09-24: RPG uses `flingRagdoll` for the killed and `stagger` (1.2 s) for survivors. [[FPS-RPG-Gamepass-Launcher]]
- 2026-09-21: `stagger` / `recover`; onFinished moved above the guard. [[FPS-Baton-Stun-Becomes-A-Stagger]]
- 2026-09-20: `flingRagdoll` waits for the ragdoll and pushes every part. [[FPS-Shotgun-Kill-Knockback]]
- 2026-09-19: enemies get a non-self-colliding group, as corpses already had. [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]
- 2026-09-12: respawn countdown 2 -> 5 s. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: camera resets on death (joints are not broken). [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]]
- 2026-09-11: Lean / Turning disabled for the AnimationConstraint rig. [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]]
- 2026-09-11: velocity zeroing noted as by design. [[FPS-Loadout-Melee-Shotgun-Sniper]]

See [[Batch Log]].
