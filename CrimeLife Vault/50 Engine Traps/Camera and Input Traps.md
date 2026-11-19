---
type: trap
tags: [trap, camera, input, prompts, mouse]
updated: 2026-11-20
sources: ["CLAUDE.md (Known traps)", "70 Batches/FPS System/Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip.md", "70 Batches/FPS System/Enemies-Climbing-Each-Other-And-Nameplate-Gap.md", "70 Batches/FPS System/FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel.md", "70 Batches/FPS System/FPS-Landing-Jolt-Root-Cause.md", "70 Batches/FPS System/FPS-Dialogue-Responses-Clickable-Fix.md", "OBT Vault/50 Engine Traps/Camera and Input Traps.md (generic traps)", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-3-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Camera and Input Traps

Engine behaviour of cameras, the mouse, keys, touch and ProximityPrompts. Harness quirks are in [[Studio MCP Gotchas]]. Systems: [[Camera Authority]], [[Inventory and Hotbar]], [[Movement and Stamina]].

## Mouse

### Equipping locks the cursor at screen centre (Known trap)
- **Symptom:** clicking a hotbar slot often refused to equip, and played no equip sound ("the equip never ran at all").
- **Cause:** equipping sets `MouseBehavior` to `LockCenter`. The click-versus-drag test measured the cursor against the frame's `AbsolutePosition` corner within 60 px: a click in the middle of a 56 px slot is already ~39 px from that corner, and with a weapon out the cursor sat ~237 px away.
- **Fix:** capture the cursor position on press and measure how far the mouse actually moved. Any click-versus-drag test must measure cursor movement, never a distance to a frame.
- **Bit us:** [[Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip]]; a slot click could not be exercised by the harness either ([[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]).

### A single stray mouse-move starts a "drag"
- **Symptom:** an ordinary click to equip triggered the failed-drop snap-back.
- **Cause:** the drag flag is set by one mouse-move event even when the cursor has not moved.
- **Fix:** reuse the inventory's movement-distance threshold to tell a click from a drag. [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]].

### Focus loss drops the mouse lock (OBT)
- After alt-tab, a TextBox or the Esc menu the cursor is free while a gun is out, and a same-value write does not restore it. Re-arm (Default for one frame, then LockCenter) on `WindowFocused`, `TextBoxFocusReleased` and menu close.

## Camera

### A divide-by-zero guard became a 2500x amplifier
- **Symptom:** a violent camera jolt on landing.
- **Cause:** `StarterGui.Bobbing Camera` divides velocity by `math.max(WalkSpeed, 0.01)`. A landing change set WalkSpeed to exactly 0 at touchdown while the character still moved ~25 studs/s: leanTarget measured -18.542 where about 0.02 is normal.
- **Fix:** divide by `math.max(humanoid.WalkSpeed, MovementConstants.WALK_SPEED_BASELINE)`, a reference pace that cannot collapse. A frame-time clamp tried first in the same session was correct on its own but **not** the cause. **Bit us:** [[FPS-Landing-Jolt-Root-Cause]] (after [[FPS-Landing-Camera-Jolt]]).

### A camera claim must be released with the thing that took it
- The dialogue reply panel and the conversation's camera are released at the same moment; a panel rebuilt on respawn while the engine kept the old one left the player "stuck zoomed in after dying". Route camera claims through `Modules.CameraAuthority`. [[FPS-Dialogue-Responses-Clickable-Fix]].

### In third person the gun muzzle is too far from the root part to be a shot origin
- **Symptom:** in third person, standing still, shots with long guns were refused (AK47 ammo 30 to 30; Itacha Mag-10 4 to 4, while a control origin 2 studs ahead was accepted).
- **Cause:** `BlasterController` sent the Tool's muzzle as the shot origin, and `validateShot` refuses an origin more than 5 + 0.4 x speed studs from the root part. In Studio's hold pose the muzzle sits 5.16 to 7.06 studs from the root part on 11 long guns (AK47 5.47, AMB-17 5.16, Benelli M4 5.22, HCAR 5.24, M16A1 6.11, MP-153 5.85, Mossberg 590 5.55, RPG 7.06, Remington 870 5.18, SPAS-13 5.58, Spas 12 5.58); every pistol is 2.5 to 3.4. Moving 5 more muzzles to their barrel ends would have refused those guns too.
- **Fix:** a head origin: third-person shots start at the head and aim at the crosshair hit point (`Blaster.Utility.thirdPersonAim`); the server check was not loosened. Measured: AK47, Spas 12, Itacha Mag-10, Glock 18 and RPG accepted and hit a target 50 studs ahead from an origin 1.40 to 1.42 studs from the root part. The hold pose is Studio's default tool hold ([[Sound and Asset Traps]]), so a published place may differ. [[2026-11-18 Open Items Pass]], [[Camera Authority]].

### Every Tool's BlasterController hears global key input
- **Symptom:** pressing Z (the shoulder swap) with one gun did nothing: two guns in the backpack each ran the swap, so the offset flipped twice and ended where it began.
- **Cause:** each Tool has its own `BlasterController` and each binds the same keys, so every controller handles a key press, equipped or not.
- **Fix:** a per-key action checks `self.equipped` (the equipped controller only). Same rule for V (guarded by `ViewModelController.enabled`), Z and R3. [[Weapons and Blaster]]
- **Bit us:** [[2026-11-20 Admin Animations Third Person]]

### A character PivotTo does not turn the camera (OBT)
- Move the camera yourself, or pass a camera to the capture.

### Widening the zoom limits leaves the camera where it is (OBT)
- Restoring `CameraMinZoomDistance` / `Max` after a first-person pin keeps the current zoom; push it out by raising the min for a moment.

### A server body swap leaves CameraSubject on the old body (OBT)
- Setting `player.Character` on the server does not move `CurrentCamera.CameraSubject`; move it on `CharacterAdded`.

## ProximityPrompts

### The prompt service takes the key first (OBT)
- `PromptTriggered` fires first, then `InputBegan` arrives with `processed = true`. A "pressed but nothing triggered" watcher must count triggers too.

### An off-screen prompt never shows (OBT)
- Pressing its key does nothing. In tests hold the camera on it in the same call.

### A prompt's `HoldDuration` is enforced on the client, so the server must pace attempts
- **Symptom (by reading and a spec, not exploited live):** the NewsStation safe's 8 s hold did nothing against a client that fires the remote itself: each `SubmitSafeCode` was judged on its own, so codes could be tried about twice a second.
- **Cause:** the hold timer runs in the player's `ProximityPromptService`; the server only sees `Triggered` (or the remote), never how long the key was held.
- **Fix:** keep a per-player last-attempt time on the server and refuse an attempt closer than the prompt's own `HoldDuration` (`Safe` `enforceHold`, shared across a player's safes). Also: an automated hold works only while the prompt's part is on screen, so aim the camera first (the entry above). [[2026-11-16 Robbery Systems Into City]]

### Two prompts on one key: only one shows (OBT)
- With `Exclusivity = OnePerButton`, the nearer prompt wins. Give a prop's prompt its own key.

### PromptShown misses a prompt already showing (OBT)
- Judge a prompt by its result, not by a late listener.

### MaxActivationDistance should match what the player can see
- The stat billboard is visible to 20 studs; its prompt's `MaxActivationDistance` was raised from 10 to 20 to match. [[FPS-Damage-Direction-Indicator-And-Prompt-Range]].

## Touch

### Touch controls hidden until the first touch (OBT)
- After an emulator switch the last input is keyboard, so the PlayerModule hides the thumbstick until a real touch. Not a bug ([[Phone Testing]]).

### The input type is wrong at load (OBT)
- The emulator reports mouse and keyboard for a moment after Play starts. Read the input type at layout time and on change.

Related: [[Engine Traps MOC]] · [[Physics and Character Traps]]
