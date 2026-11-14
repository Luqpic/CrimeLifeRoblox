---
type: system
tags: [system, camera, input]
updated: 2026-11-14
sources: ["CLAUDE.md (Systems, Known traps)", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/BlasterController.luau", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/ViewModelController.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-UltimateUIPack-Effects-Integration.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Camera-Jolt.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Jolt-Root-Cause.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Monetization-Cosmetics-Spec.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md"]
---

# Camera Authority

**Skills:** `roblox-input`, `roblox-architecture` (load these for work here)

## What it does
Arbitrates every claim on camera and mouse properties (field of view, camera offset, mouse sensitivity, mouse behaviour, zoom distance) so aiming, sprinting, crouching, menus and the bob script do not overwrite each other. The highest-priority claim wins; clearing a claim hands the property back.

## Where it lives
- `ReplicatedStorage.Modules.CameraAuthority` (built on `ReplicatedStorage.Modules.PropertyAuthority`).
- `ReplicatedStorage.Modules.MenuFovBlur` (claims as "Menu").
- Claimants: `ReplicatedStorage.Blaster.Scripts.BlasterController` ("ADS"), `ReplicatedStorage.Blaster.Scripts.ViewModelController` ("Blaster"), `StarterGui."Bobbing Camera"`, sprint/crouch.
- Test: `ServerStorage.UnitTest.Cases.PropertyAuthority_Test` (8/8 on 2026-09-23).
- Robbery place: same modules, ported verbatim on 2026-09-19.

## How it works
- Each property is a channel: `CameraAuthority.<Property>:Set(source, value)` / `:Clear(source)`. Seen in code: `FieldOfView`, `CameraOffset`, `MouseDeltaSensitivity` (ADS), `MouseBehavior` (`LockCenter` while a gun is equipped), `MinZoomDistance` / `MaxZoomDistance` (Blaster; Bobbing Camera sets 0.5 / 128).
- The authority's default `MaxZoomDistance` is 30; deleting `Bobbing Camera` would drop the max zoom to that.
- `MenuFovBlur` is reference-counted and hands back a one-shot release, so one menu closing never cancels another's blur or FOV pull.
- On death the blaster resets the camera the same way as on unequip.
- Source priorities are not recorded in the change logs; read `CameraAuthority` before relying on an order.

## Extend it
- Any new panel raises/lowers `MenuFovBlur` and routes camera claims through the authority rather than writing `Camera.FieldOfView` directly (cosmetics spec rule).

## Watch out
- UltimateUIPack's demo blur wrote FOV directly; copying it would have fought ADS and sprint.
- `MouseBehavior = LockCenter` while equipped pins the cursor; click-versus-drag tests must measure cursor movement.
- `Bobbing Camera` rotates by an angle times frame time; its frame time is clamped to the 30 fps value, and its lean divides by `max(WalkSpeed, MovementConstants.WALK_SPEED_BASELINE)` (landing set `WalkSpeed` to 0 and the lean exploded). See [[Movement and Stamina]].

## History
- 2026-09-19 (Robbery): `PropertyAuthority`, `CameraAuthority`, `MenuFovBlur` ported verbatim. [[Shared-UI-Effects-FOV-Blur-And-Sounds]]
- 2026-09-19: landing camera jolt: real cause was the lean divisor at `WalkSpeed` 0; frame-time clamp kept. Zoom registrations untouched. [[FPS-Landing-Jolt-Root-Cause]], [[FPS-Landing-Camera-Jolt]]
- 2026-09-16: "Menu" entry added; `MenuFovBlur` created. [[FPS-UltimateUIPack-Effects-Integration]]
- 2026-09-11: camera reset on death fixes the stuck first-person view. [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]]
- When `CameraAuthority` itself was first written is not recorded in the change-log archive.

See [[Batch Log]].
