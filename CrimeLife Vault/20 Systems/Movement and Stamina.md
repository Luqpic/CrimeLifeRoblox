---
type: system
tags: [system, movement, stamina, camera, fps]
updated: 2026-11-20
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "CLAUDE.md (Instance tree)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Sprint-Landing-Dead-Stop.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-All-Landings-Dead-Stop.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Camera-Jolt.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Jolt-Root-Cause.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Fall-Animation-Dead-Asset.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-2-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-2-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Movement and Stamina

**Skills:** `roblox-characters-animation`, `roblox-physics`, `roblox-input` (load these for work here)

FPS System place only.

## What it does
Walk, sprint (drains stamina, server-granted), jump, fall and climb animations, a dead stop on every landing with momentum rebuilt over a ramp, the camera bob, and the stamina bar on the HUD. The baton stun clamps a stunned player through the same authority.

## Where it lives
- `ServerScriptService.Movement.Scripts.SprintAuthority`: grants sprint (`IsSprinting` attribute), owns the landing clamp and the stun clamp.
- `ReplicatedStorage.Movement.Constants`: `WALK_SPEED_BASELINE`, `LANDING_RECOVERY_*`, `MIN_DRAIN_SPEED` (22).
- `StarterPlayer.StarterCharacterScripts.Animate2`: client animation and locomotion (`onLanded`, `move()`, fall/climb tracks).
- `StarterGui.Bobbing Camera`: camera bob; also registers `MinZoomDistance` 0.5 / `MaxZoomDistance` 128 with [[Camera Authority]].
- `StarterPlayer.StarterPlayerScripts.StaminaHud` (clones its look from a template into `StaminaGui`).
- `StarterPlayer.StarterCharacterScripts.Lean` (and `Turning`): disabled, see Watch out.
- Unit suites `staminaStep_Test` and `validateRunningState_Test` (passing 10/10 and green on 2026-09-23 per [[FPS-Persistence-Phase-3]]).

## How it works
- **Speeds.** Walk baseline 20 (`Animate2` `originalWalkSpeed`); sprint configured as 20 + `runSpeedBoost` 18 = 38; client accelerates at `runAcceleration` 50 studs/s².
- **Every landing** (sprint-jump, standing hop, kerb) drops `WalkSpeed` to `LANDING_RECOVERY_WALK_SPEED` = 0, holds `LANDING_RECOVERY_HOLD` = 0.12 s, then ramps at `LANDING_RECOVERY_ACCELERATION` = 50 back to the baseline; the window is `LANDING_RECOVERY_DURATION` = 0.55 s, sized to outlast the curve. Sprint is revoked for the window. Measured: dead stop by ~0.12 s, walk pace by ~0.5-0.57 s, sprint re-granted ~0.63 s.
- Client (`Animate2`) and server (`SprintAuthority`) read the **same constants**, and the server clamp follows the ramp upward as well as down, so its release does not stamp the client's rebuilt speed back.
- **Camera bob.** Lean divides by `max(WalkSpeed, WALK_SPEED_BASELINE)` so a 0 `WalkSpeed` on landing cannot blow it up; rotation frame time is clamped to the 30 fps value, and the hitch-reset guard reads the unclamped value.
- **Fall / climb** use Roblox default R15 animations (`507767968`, `507765644`); the rig is R15. The developer decided on 2026-11-18 that the defaults are fine, so the custom-animation item is closed.
- **Heavy carries.** `Crouching` `Stop()` sets `WalkSpeed = carryCapped(originalSpeed)`, so a carrier standing up from a crouch is capped on the same frame (2026-11-18). Carriers use the collision group `Carrier`, which is what lets them cross the Bank's carrier-only ledges ([[Robbery Heists and Getaway]]).
- **Stamina bar** is a `CanvasGroup`; its `UIStroke` is tweened alongside `GroupTransparency` (a group's own stroke is not faded by the group) and starts at `Transparency = 1`. Opening a panel hides `StaminaGui` with the rest of the HUD ([[HUD and UI Shell]]).

## Animation layer and the roll (2026-11-20)
Clip playback, the roll (Q) and the ledge climb moved to [[Character Movement and Animation]]. What changed here: `Animate2` yields its clips while the character attribute `MovementAnimations` is set and stops `Animate`'s leftover tracks; `SprintAuthority.spend(player, amount)` (refuses while locked out) pays the roll's 12.3 stamina; `SprintAuthority` writes the admin `AdminWalkSpeed` last in its tick and `Animate2` uses it as the only target while set ([[Admin Panel]]); `LandAnim` is quarantined (`Animate2` still owns landing recovery).

## Roll stamps RollingUntil (2026-11-20)
`RollAuthority` now writes `RollingUntil` (server clock, `os.clock()` plus 0.744 s, the longest roll) on the character's root for every accepted roll; a refused roll stamps nothing. NPC aim reads it and gives a rolling target the widest cone ([[Enemies and Spawner]]). The remote carries no argument, so the client cannot pick the time. The stamp does not check that the character moves: a roll in place gets the same cone, bounded by stamina (12.3 a roll) and the 0.9 s cooldown, about 37 % uptime sustained (review Minor, open). Spec: `RollAuthority_Test` (5 cases). [[2026-11-20 Readable Gunfights and Level Toughness]]

## Extend it
- Movement tuning goes in `ReplicatedStorage.Movement.Constants` only, so client and server stay in step.
- If small drops feel sluggish, add a fall-height or fall-speed threshold for opening the landing window, not a return of the sprint test.
- Restore custom fall/climb animations only after re-uploading them under an account this place can read.

## Watch out
- Test animation assets with `ContentProvider:PreloadAsync` then poll `AnimationTrack.Length`; `Length` reads 0 until the asset resolves, which faked "dead" for every id once.
- Anything dividing by `WalkSpeed` breaks now that landing sets it to exactly 0.
- The `Crouching` stand-up clamp (carry cap on the same frame) was not measured: key input was not driven in the Play (2026-11-18).
- Sprint detection on the server must read `IsSprinting`, not server-side velocity (server read below 22 on a 25.4 studs/s landing).
- Lean/turn effect has been **off, not fixed** since 2026-09-11 (old rig assumptions threw every frame); a rewrite for the current rig is outstanding.
- Explained and fixed 2026-11-17: the 20.00 / 25.83 swing came from `Animate2`. Pressed against a wall, collision made the velocity read backward, so the backward clamp (`min(WalkSpeed, 20)`) fired, and the `move()` ramp (+50 per second on a 0.1 s tick, 20 + 5.83) lifted it again. The clamp now keys on input (`isInputBackwards`, `Humanoid.MoveDirection` against the look vector); walking backwards still clamps to 20. Inside the 0.55 s landing window the client ramp and the server's replicated cap still interleave in a small sawtooth (not changed).
- If the landing jolt reappears on a steady 60 fps client, the cause is the speed-scaled roll term (`calcRootMagnitude`), not frame time.
- Lean is slightly reduced while crouched (side effect of the baseline divisor).
- Deleting `Bobbing Camera` would drop max zoom to the authority default of 30.

## History
- 2026-11-20: an accepted roll stamps `RollingUntil` for NPC aim. [[2026-11-20 Readable Gunfights and Level Toughness]]
- 2026-11-20: OBT movement clips, roll and ledge climb added ([[Character Movement and Animation]]); `SprintAuthority.spend`; admin walk speed. [[2026-11-20 Admin Animations Third Person]]
- 2026-11-18: `Crouching` `Stop()` caps `WalkSpeed` at once for a carrier (`carryCapped`); not measured in Play; carriers cross the Bank ledges through the `Carrier` collision group; fall and climb defaults confirmed as fine by the developer. [[2026-11-18 Open Items Pass]]
- 2026-11-17: character attribute `CarrySpeedCap` (12, `Movement.Constants`) set by `CarryState` for heavy loot: `Animate2`, `SprintAuthority` and `Crouching` cap WalkSpeed at it and grant no sprint; clearing it hands back 20. Measured sprint 38 uncapped, 12 capped. [[2026-11-17 Heist Layers]]
- 2026-11-17: `Animate2` backward clamp keys on input, not velocity: the 20 / 25.83 `WalkSpeed` swing against a wall is gone. [[2026-11-17 Known Issues Pass]]
- 2026-09-20: every landing is a dead stop; soft floor (12) and sprint detection deleted. [[FPS-All-Landings-Dead-Stop]]
- 2026-09-19: sprint landing dead stop with shared ramp; landing camera jolt traced to the lean divisor (first fix, frame-time clamp, kept but was not the cause); dead fall/climb animation assets replaced. [[FPS-Sprint-Landing-Dead-Stop]] [[FPS-Landing-Camera-Jolt]] [[FPS-Landing-Jolt-Root-Cause]] [[FPS-Fall-Animation-Dead-Asset]]
- 2026-09-18: stamina outline no longer visible while idle. [[FPS-Figma-UI-Bugfix-Pass]]
- 2026-09-12: landing slowdown added, independent of sprint. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: stamina bar converted to a template; Lean/Turning disabled to stop per-frame errors. [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]] [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]]

See [[Batch Log]].
