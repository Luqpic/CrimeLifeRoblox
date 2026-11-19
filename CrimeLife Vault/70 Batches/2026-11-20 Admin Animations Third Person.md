---
type: batch
tags: [batch, city, admin, animation, camera, third-person, movement, security]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-20-admin-anim-thirdperson/progress.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/admin-design.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-review.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-2-review.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-4-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-4-review.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-security-review.md", "CityMerge/after-import.md (from 'Task 1 review fixes' to the end)", "git log 5eea7eb..HEAD"]
---

# 2026-11-20 Admin Animations Third Person

Four tasks on `main`, base `5eea7eb`, commits `9019748` (animations), `63e51a8` (shoulder camera), `686cb0f` (admin server), `2e128f0` (admin panel), `c9ab154` (camera review fixes), `182f552` (admin review fixes), plus the vault update. Done overnight on the new cloud place "Crimelife Tycoon" (placeId 128488619644399, universe 10777869898, owned by the SolarArc Studios group 4998611; Studio id `9f6e1b42-...`). A second batch (heist police) was dispatched afterwards and is not part of this note.

## Asked for
The developer, 2026-11-20 (from `progress.md`):
- "Design an admin panel I can use in the game (you design)."
- "Ensure there's animations to character; reuse the animations from the group animations."
- "Add a third person POV for the FPS system (can toggle); reuse OBT's weaponry system."

## What changed

### Before the pickers (controller)
- The six city clips (idle 70581846281736, walk 122749871988730, run 136801098480203, jump 94550951381303, crouch 89055632668771, `LandAnim` 91946150190183) and OBT's `Player_` clips are owned by the SolarArc Studios group. The animation service refused them in the city file ("Animation failed to load ... serverplaceid=0"), tracks had `Length` 0. In OBT's group place the same clips loaded (read-only probe). Clips that did load in the city: the Tool hold clips, `CrouchWalkAnim` 107107589904731, the Roblox fall (507767968) and climb (507765644).
- The developer then published the city privately into the group as the cloud place "Crimelife Tycoon" (475 scripts; Heist, Wanted, Blaster and UnitTest present). The group clips load there (idle, walk, `Player_Idle`, `Player_Run_F`, `LandAnim` read back). See [[Places and Studio Windows]] and the trap in [[Sound and Asset Traps]].
- Surveys (Sonnet) of the animation and camera code and of the admin code; the controller wrote `admin-design.md` (binding for Tasks 3 and 4).

### Task 1: character animations (`9019748`, review fixes committed with `63e51a8`)
Full detail in [[Character Movement and Animation]].
- OBT's `Movement.lua` ported as `StarterPlayer.StarterCharacterScripts.Movement`; `ReplicatedStorage.PlayerMovement` holds `Animations` (42 objects: 41 clips and `Empty`), `Config`, `Fallback` and the `Roll` RemoteEvent. Idle, walk, jog, run in four directions, sprint, jump, fall, land, hard land, climb, swim, legs layer under a held tool, roll (Q) and ledge climb.
- Server: `RollAuthority.request` (stamina 12.3, server-owned), `SprintAuthority.spend`, `RunningState` wiring. `Animate2` yields its clips while `MovementAnimations` is set; `LandAnim` quarantined.
- Fallback: any clip that fails to load is swapped for the Roblox default R15 clip, or dropped, with one warn line.

### Task 2: shoulder camera (`63e51a8`, review fixes `c9ab154`), done by the controller
Full detail in [[Weapons and Blaster]] and [[Camera Authority]].
- OBT's shoulder camera ported into CrimeLife's blaster, not OBT's gun engine: `Blaster.Scripts.ShoulderCamera` and `Blaster.Utility.shoulderMath` (pure), a "Shoulder" source in `CameraAuthority`, `AimPitch` (server) and `AimPitchView` (client) for other players' waist and neck, VIEW and SWAP touch buttons, V toggles, Z or R3 swaps the shoulder, DPadUp toggles on a pad.
- A fresh equip starts in third person; V switches to first person and the choice is remembered across equips and respawns. Aim is the shoulder zoom; no gun in CrimeLife has a scope, so decision 5's scoped-gun rule had nothing to apply to.

### Tasks 3 and 4: admin server and panel (`686cb0f`, `2e128f0`, review fixes `182f552`), one Opus implementer
Full detail in [[Admin Panel]].
- `ServerScriptService.Admin` (`Config`, `Roles`, `Hooks`, `Actions`, `AdminService`): 31 actions (17 owner-only, 14 helper), roles from Studio, the creator, or group rank, no account id in code. Hooks in the owning scripts, not copies.
- `ServerStorage.AdminPanel`: `AdminPanelGui` (F2, four tabs) and `AdminHudGui` (the HUD button), delivered by the server only to role holders. Fly, noclip and spectate run on the client.
- The old F2 "Admin: Set Level" and `/setlevel` are retired (`ServerStorage.CityQuarantine.AdminReplaced`).

### Vault and repo cleanup (this update)
- The hard-coded admin account id was removed from three lines in two batch notes (see [[Vault Conventions]] note on secrets); it also appears in three notes under `90 Reference/Original Prompts/`, which stay untouched.
- The vault now names the cloud place as the working copy ([[Start Here]], [[Home]], [[Which Project This Is]], [[Places and Studio Windows]], [[Save and Publish Rules]]).

## Decisions
Eight picker answers, the run mode and the saving rule (2026-11-20), quoted in short. Full text: [[Admin, Animation and Camera Decisions]].
1. Animations unblock: the developer publishes the city privately into SolarArc Studios; a Roblox-default fallback for any clip that fails.
2. Clip set: OBT's `Player_` set plus roll and ledge climb; CrimeLife's crouch, lean and stamina stay.
3. Third person: OBT's shoulder camera in CrimeLife's blaster; V toggles; remembered; phone button.
4. Start view when a gun comes out: third person.
5. Third-person aim: shoulder zoom; scoped guns to first-person sights while aiming (no scoped gun exists).
6. Admin access: owner plus group helpers (rank 255 everything and any Studio session; rank 252 and up a limited set); no account ids in code.
7. Admin tool sets: all four (Players, Heists and police, My tools, Server and moderation).
8. Admin look: a CrimeLife panel on F2, tabs down the left, a HUD button only admins see, works on phones.
- Run mode "Hybrid": Task 1 as a subagent, Task 2 natively by the controller, Tasks 3 and 4 merged into one Opus implementer, one Sonnet review per feature plus a security review of the admin server, no more surveys.
- Saving: "Yes, save after each task", with `save_place` (a place version, never a publish), controller only, only after a task passes its tests. One-night permission, like 2026-11-15 ([[Save and Publish Rules]]).
- Claude's rulings (in the briefs): roll key Q (C is crouch, Z is the shoulder swap); no roll or ledge while carrying, crouching, stunned, ragdolled or frozen; roll stamina server-owned through a `Roll` remote; remote pitch relayed at 10 Hz, clamp 70 degrees; admin GUI delivered from `ServerStorage` only to role holders; admin hooks exposed from the owning scripts; the quarantined `AdminLevelController` has its account number replaced by 0. More in [[Character Movement and Animation]] and [[Admin Panel]].

## Measurements
City suites per step: 322 / 322 after Task 1, 327 / 327 after Task 2, 352 / 352 after Tasks 3 and 4, 353 / 353 after the admin fixes; heist 740 / 0 every time. Client boot 0 non-asset errors. Server boot 1 non-asset error: the DataStore `StudioAccessToApisNotAllowed` (Studio API access is off for the cloud place; a developer setting).

**Task 1.** Test avatar leg scale 1.044 in one session and 1.096 in another. Playback rate at 1.096: speed 8 gave Jog_F 0.61, 12 gave 0.91, 20 gave Run_F 0.91, 38 gave Sprint 0.91. Hip swing sprinting with the AK47 (Euler X range): 140.2 degrees before (CrimeLife's AK hold never keyed the legs), 111.6 after. Roll standing: 18.07 studs, `MoveAction` 0.634 s, upright 1.000, stamina 100 to 87.70; a second Q 0.3 s later did nothing; server cooldown: request at 0.76 spent, at 0.86 refused, at 2.07 spent (90.41 to 78.11). Carrying (cap 12): Q gives no move, two direct requests spent nothing. Ledge (temporary 12 x 6 x 4 part): feet 1.00 to 7.00, `MoveAction` 0.999 s, limbs' `CanCollide` restored; carrying gives a plain jump. Landing: Land at vy -50.7, LandHard from a 45-stud drop at vy -127.5. Fallback test: `Walk_F` and `Roll` pointed at a bad id gave the warn "clips that did not load: Roll skipped, Walk_F -> default", a roll with no clip still ran (18.89 studs). NPCs: 84 server humanoids, 71 to 72 playing tracks, 0 with `Length` 0; police 10 officers, 22 tracks, 0 dead. A stray Core idle from `Animate` (75822810238289) was found and stopped by `Animate2`.

**Task 2.** Equip: third person, zoom 9, offset (1.75, 1.40). V to first, re-equip first, respawn first, V to third. Wall 1.7 studs to the right: offset 1.20. Z: -1.75. Aim: offset (1.10, 1.30), FOV 50, sensitivity 0.5; crouch plus aim: Y 0.30. Look 45 up: neck 18 degrees, server `AimPitch` 0.79. A gun at a dummy 50 studs ahead: right shoulder 6 rounds 90 damage, left shoulder 6 rounds 80 damage. Strafe-roll: facing back to the camera 0.0 degrees. After the review fixes: Crowbar in the shoulder view, two swings took a dummy 100 to 10; RMB held through V and V: aim offset back, FOV 50; strafe 2.5 s, facing within 0.1 degrees, `AutoRotate` never on; V 0.2 s into a roll: `AutoRotate` stays off until the roll ends; Sit and PlatformStand release and return; `LoadCharacter` clean; `AimPitch` -0.26 then 0; touch VIEW and SWAP read back at 1100 x 679 with no overlap (VIEW 16.8 px clear of Shoot, 30 px of Reload).

**Tasks 3 and 4.** Every action through the real `AdminRemote` and read back on the server, forged calls (NaN, infinity, a Character as target, 1e300, wrong types, unknown action) refused, a role-less caller refused with one log row. Setting level 12 gave Level 12, XP 0, max health 122; cash gift of 2,000,000 refused (cap 1,000,000 per call); god: 3 admin Thugs attacking for 6 s, health 122 to 122, `TakeDamage(50)` 104 to 104, 2 s in the Bank death pit alive (control with god off: health 0), void at y -470 back at the spawn within 0.3 s; invisible 19 of 19 parts hidden and restored exactly; walk speed 50 held, 101 refused; fly: Space 0.4 s gave +24.00 studs, LeftControl 0.4 s gave -24.00; noclip walked 7.5 studs past a wall face. Panel at 1100 x 679: 760 x 480 at (170, 70), fit scale 1; text sweep 0 not fitting on every tab; HUD button 47.8 x 47.8 at the column's x with a 7.5 px gap. Specs: `AdminRoles_Test` 9, `Admin_Test` 16 (seven checks each shown to fail when removed), plus 1 added in the fixes. After the fixes: role removed mid-fly, noclip and panel open: server `Admin*` attributes cleared, both GUIs gone, no movers, root collides again, blur 0, FOV 70; an owner with god demoted to helper lost god.

## Review findings and fixes
Sonnet reviews, controller fixes. Verdicts as the reviews wrote them.

**Task 1 review (verdict "changes needed", 0 Critical, 2 Important, 9 Minor).** I1 the `CharacterAdded` connection in `Movement` was never disconnected (a leak per respawn): fixed. I2 per-frame tables, closures and name building in the Heartbeat step: fixed (cleared module tables, names built once, tool flag cached, weights set only when they move). Also fixed: the server refuses a roll while crouched, seated or PlatformStand and from a player who left (M1), `spend` refuses while locked out (M3). Not fixed: see Left open.

**Task 2 review (verdict "changes needed", 0 Critical, 5 Important, 9 Minor).** I1 aim lost across exit and enter: fixed (module `wantAiming`). I2 the closing 0 over an unreliable remote could be lost: fixed by making `AimPitch` a reliable `RemoteEvent`. I3 `AimPitchView` lost characters on stream-out: fixed (a 10 Hz poll of each player's current character, joints found lazily). I4 a second `AutoRotate` writer in `SmoothShiftLock`: fixed (its early return moved above the write; `exit()` turns `AutoRotate` on only with no `MoveAction`). I5 missing checks: run in the Play above, except NPC dialogue mid-shoulder.

**Admin correctness review (0 Critical, 2 Important, 7 Minor).** I1 a role lost mid-session left admin states and client tools live: fixed. I2 spectate kept the replication focus after the admin's own respawn: fixed. M1 Space typed in a TextBox lifted a flying admin, M2 the "CLICK AGAIN" label could stick, M4 attribute-change sync on every attribute: fixed. M3 a helper acting on staff whose role was still loading: fixed.

**Admin security review (0 Critical, 2 Important, 8 Minor).** I1 `text()` used a quadratic pattern before any length cap, so a helper could stall the server with one long run of spaces: fixed (bytes bounded first; see [[Luau and Scripting Traps]]). I2 the `AdminRole` Player attribute replicated and named the staff to every client: fixed (the role rides on the delivered GUIs; see [[Streaming and Replication Traps]]). M1 a god guard leaked when the character was removed alive, M5 a filter failure blocked kick and ban, M6 helper announce spam (5 s gap, owners exempt): fixed. No path was found by which a role-less client reaches any action or hook.

Weighed and not changed: "CLEAR ALL, POLICE TOO" does not kill heist guards (only the spawner, the dispatcher and the admin action build `EnemyAI`); `SetLevelRequest` stays (owner-only now, its only sender is retired, so it is a dead entry point).

## Verified
Every result above was read back in Play on the cloud place: the 31 actions through the real remote, the panel by real clicks and key presses (F2, tabs, buttons) before the display slept, fly with real keys, every script byte-equal with `CityScripts/` by length and Adler-32 (9 / 9 for Task 1, 16 / 16 for Task 2, 20 / 20 and 5 / 5 for Tasks 3 and 4, 4 / 4 and 6 / 6 for the two fix rounds; rows in `CityMerge/after-import.md`). Mirrors written on disk and pushed because the Studio MCP refuses HTTP to 127.0.0.1 ([[Studio MCP Gotchas]]).

## Not verified
- Spectate on another player (solo Studio): camera follows, `ReplicationFocus`, stops on death, leave and STOP.
- The GIVE WEAPON list click (virtual input stopped reaching the game when the display slept; `giveWeapon` itself is proven through the remote).
- The phone panel: 760 x 480 fits at scale 0.658 (computed at 844 x 390, text 7.9 to 10.5 px), the touch fly UP and DOWN, the ADMIN HUD button, the roll button (x 556..612, y 306..362 computed) and the VIEW and SWAP buttons at 844 x 390: all computed or read at 1100 x 679, none seen on a device.
- NPC dialogue mid-shoulder.
- A roll out of a sprint, the touch and gamepad roll paths, a second player watching the moves, a death mid-ledge.
- The Tool hold pose in the published place was not looked at; the hold clips load in the cloud place (the AK47 hold read back at weight 1.00).
- A real two-server role refresh: roles are cached once per join.

## Left open
In [[Open Items]], section "Admin, animation and third person (2026-11-20)": the checks above; the developer's Studio API access setting for DataStores; the Task 1, Task 2 and admin Minors that were not fixed; `AutoRotate` stuck false in one long session (CustomShiftLock suspected, not investigated); the git history still holds the old account id (security M8), only a history rewrite would remove it.

## Saved
The place was saved after each task that passed its tests with `save_place`: versions 10 (Task 1), 15 (Task 2), 21 (after the camera review fixes) and 23 (after the admin review fixes). Version 21 and 23 were taken with the admin work in the place; no separate save of Tasks 3 and 4 is recorded. Never published. A save makes a place version; it is not a publish.

NOT published.

## Models and skills used
Opus: the Task 1 implementer, the merged Task 3 and 4 implementer, and the controller's native Task 2 and the review fixes. Sonnet: the surveys, the reviews and the vault drafts. Skills loaded for the code work: `roblox-characters-animation`, `roblox-input`, `roblox-physics`, `roblox-security`, `roblox-networking`, `roblox-game-systems`, `roblox-ui` ([[Vault Skills Only and Model Routing]]).

## Links
[[Character Movement and Animation]] [[Admin Panel]] [[Movement and Stamina]] [[Weapons and Blaster]] [[Camera Authority]] [[Viewmodels and Weapon Animation]] [[Leveling and Renown]] [[Police and Wanted]] [[Robbery Heists and Getaway]] [[Weapon Shop and Upgrades]] [[Notifications]] [[HUD and UI Shell]] [[Nameplates and Billboards]] [[Persistence and Saves]] [[Open Items]] [[Admin, Animation and Camera Decisions]] [[Camera and Input Traps]] [[Physics and Character Traps]] [[Sound and Asset Traps]] [[Luau and Scripting Traps]] [[Streaming and Replication Traps]] [[Tween and Render Traps]]
