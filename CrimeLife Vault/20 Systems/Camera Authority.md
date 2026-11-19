---
type: system
tags: [system, camera, input]
updated: 2026-11-20
sources: ["CLAUDE.md (Systems, Known traps)", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/BlasterController.luau", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/ViewModelController.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-UltimateUIPack-Effects-Integration.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Camera-Jolt.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Jolt-Root-Cause.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Monetization-Cosmetics-Spec.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-3-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-3-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
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
- **Third-person shots read the camera, they do not claim it (2026-11-18).** The aim comes from `Blaster.Utility.thirdPersonAim`: a ray along `camera.CFrame`'s look, started level with the head so the shoulder camera (5.79 studs behind the character) cannot send the shot backwards, with the aim point at the crosshair hit or 1000 studs out (`CROSSHAIR_FAR_DISTANCE`). No `CameraAuthority` channel is involved ([[Weapons and Blaster]]). The third-person rig keeps rebuilding the camera from the head, so a test aims by turning the camera.
- Source priorities are not recorded in the change logs; read `CameraAuthority` before relying on an order.

## The "Shoulder" source (2026-11-20)
`CameraAuthority` gained a character-scoped **"Shoulder"** source on top of `CameraOffset` (applied at once, not tweened, so the wall clamp and the swap never lag) and `MinZoomDistance` / `MaxZoomDistance`; `PropertyAuthority.Get(source)` was added and the applier now also receives the winning source. `ShoulderCamera` writes it, `exit()` clears CameraOffset, Min and Max, and `CharacterAdded` clears every "Shoulder" claim. The 5.79-stud shoulder camera mentioned under 2026-11-18 was replaced by this one. Detail: [[Weapons and Blaster]].

## Extend it
- A feature that needs the player's aim in third person calls `thirdPersonAim` (pure, `cast` injected) rather than starting from the muzzle or the camera position.
- Any new panel raises/lowers `MenuFovBlur` and routes camera claims through the authority rather than writing `Camera.FieldOfView` directly (cosmetics spec rule).

## Watch out
- UltimateUIPack's demo blur wrote FOV directly; copying it would have fought ADS and sprint.
- `MouseBehavior = LockCenter` while equipped pins the cursor; click-versus-drag tests must measure cursor movement.
- `Bobbing Camera` rotates by an angle times frame time; its frame time is clamped to the 30 fps value, and its lean divides by `max(WalkSpeed, MovementConstants.WALK_SPEED_BASELINE)` (landing set `WalkSpeed` to 0 and the lean exploded). See [[Movement and Stamina]].

## History
- 2026-11-20: "Shoulder" source and `PropertyAuthority.Get` added for the shoulder camera; `SmoothShiftLock` stands aside while `ShoulderCam` or `MoveAction` is set. [[2026-11-20 Admin Animations Third Person]]
- 2026-11-18: third-person shots cast from the head toward the crosshair (`thirdPersonAim`), with a far-distance aim point for a miss; no change to the authority channels. [[2026-11-18 Open Items Pass]]
- 2026-09-19 (Robbery): `PropertyAuthority`, `CameraAuthority`, `MenuFovBlur` ported verbatim. [[Shared-UI-Effects-FOV-Blur-And-Sounds]]
- 2026-09-19: landing camera jolt: real cause was the lean divisor at `WalkSpeed` 0; frame-time clamp kept. Zoom registrations untouched. [[FPS-Landing-Jolt-Root-Cause]], [[FPS-Landing-Camera-Jolt]]
- 2026-09-16: "Menu" entry added; `MenuFovBlur` created. [[FPS-UltimateUIPack-Effects-Integration]]
- 2026-09-11: camera reset on death fixes the stuck first-person view. [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]]
- When `CameraAuthority` itself was first written is not recorded in the change-log archive.

See [[Batch Log]].
