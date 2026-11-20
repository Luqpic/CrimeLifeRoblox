---
type: decision
tags: [decision, admin, animation, camera, third-person, workflow]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-20-admin-anim-thirdperson/progress.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/admin-design.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-4-report.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Admin, Animation and Camera Decisions

Calls from 2026-11-20 ([[2026-11-20 Admin Animations Third Person]]). The request, quoted: "Design an admin panel I can use in the game (you design). Ensure there's animations to character; reuse the animations from the group animations. Add a third person POV for the FPS system (can toggle); reuse OBT's weaponry system." Code: [[Admin Panel]], [[Character Movement and Animation]], [[Weapons and Blaster]], [[Camera Authority]].

## The eight picker answers (developer, 2026-11-20), binding
1. **Animations unblock.** The developer publishes the city privately into SolarArc Studios (File > Publish to Roblox As > group > a new place, kept private); Claude adds a Roblox-default fallback for any clip that fails to load. Done the same day: the cloud place "Crimelife Tycoon" (placeId 128488619644399) ([[Which Project This Is]]).
2. **Clip set.** OBT's `Player_` set plus roll and ledge climb: idle, walk, jog and run in four directions, sprint, jump, fall, land and hard land, climb, swim, a legs layer under a held tool, roll, ledge climb. CrimeLife's crouch, lean and stamina stay.
3. **Third person.** OBT's shoulder camera ported into CrimeLife's blaster, not OBT's gun engine: shoulder offset, Z swaps the shoulder, wall clamp, the upper body pitches with the aim; V toggles; the choice is remembered across equips and respawns; a phone button.
4. **Start view when a gun comes out:** third person. V switches to first person and that is remembered.
5. **Third-person aim:** shoulder zoom (camera tight over the shoulder, FOV narrows); scoped guns go to first-person sights while aiming. CrimeLife has no scoped gun, so the second half has nothing to apply to yet.
6. **Admin access:** owner plus group helpers. SolarArc Studios rank 255 and any Studio session get everything; rank 252 and up get a limited set (look up, teleport, kick, short ban, announce). **No account ids in code.**
7. **Admin tool sets:** all four. Players (find, set level, give or take cash and Spraypaint, give weapon, heal, respawn, teleport to or bring, freeze); Heists and police (reset heist cooldowns, set or clear stars, spawn police or enemies, clear enemies, teleport to each heist); My tools (fly and noclip, god mode, invisible, walk speed, spectate); Server and moderation (announce, kick, timed ban through the Ban API, server stats, action log).
8. **Admin look:** a CrimeLife panel on F2 with tabs down the left (Players, Heists, Me, Server), the shared close and sounds, a HUD button only admins see, works on phones. It replaces the old F2 "Set Level" panel.

## Crouch and robbery actions (developer, 2026-11-20 late night)
- **Crouching with a gun: "The gun's own hold".** The crouch poses the legs only and the arms keep the held tool's pose; done by priority (the crouch clips drop under the hold while a Tool is held), no new clip. [[2026-11-20 Smooth Enemies Patrols and Dropped Duffels]]
- **Robbery actions: "Locked until it ends".** Holding a robbery prompt or with its minigame open, the player is eased into place facing the object and cannot walk until they let go or the minigame closes. [[2026-11-20 Smooth Enemies Patrols and Dropped Duffels]]

## Run mode and saving (developer, 2026-11-20)
- **Run mode "Hybrid".** Task 1 finishes as a subagent; Task 2 (the camera) natively by the controller; Tasks 3 and 4 (admin server and panel) merged into one Opus implementer; one Sonnet review per feature (animations, camera, admin) plus a security review of the admin server; no more surveys ([[Model Assignment]]).
- **"Yes, save after each task."** The controller saves the cloud place with `save_place` (Save, never Publish) only after a task passes its tests; implementers never save. A one-night permission ([[Save and Publish Rules]]). It made place versions 10, 15, 21 and 23.

## Claude's rulings (recorded in the briefs and reports)
- Roll key Q: C is crouch, Z is the shoulder swap. No roll or ledge climb while carrying, crouching, stunned, ragdolled or frozen. Roll stamina (12.3) is server-owned through a `Roll` remote. Cost if wrong: a key to move.
- Jog base speed 12 so every gait plays at one rate; feet slip about a fifth to a quarter of the speed.
- Remote pitch relayed through a remote, 10 Hz, clamp 70 degrees; made a reliable `RemoteEvent` after review so the closing 0 arrives.
- Admin GUI delivered from `ServerStorage` only to role holders; admin hooks exposed from the owning scripts through `Admin.Hooks`, not copied; the heist reset lives on `BankInstance`.
- Roles from group rank, not account ids; the quarantined `AdminLevelController` has its account number replaced by 0; the role rides on the delivered GUIs, not on the Player (staff were named to every client otherwise).
- God is an invisible ForceField plus a death-pit check plus a void guard; spawned police are loose officers; a cash gift is capped at 1,000,000 per call.
- Kick and ban reasons are filtered like announcements and fall back to fixed text if the filter fails; helper announcements are held 5 s apart (owners not).

Related: [[Weapon and Combat Decisions]], [[Vault and Documentation Decisions]], [[Decisions MOC]].
