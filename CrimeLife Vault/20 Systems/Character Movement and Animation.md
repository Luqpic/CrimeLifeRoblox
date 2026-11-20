---
type: system
tags: [system, animation, movement, roll, ledge, city]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-20-admin-anim-thirdperson/progress.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-review.md", "CityMerge/after-import.md (Task 1 and Task 1 review fixes, 2026-11-20)", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Character Movement and Animation

**Skills:** `roblox-characters-animation`, `roblox-input`, `roblox-physics` (load these for work here)

Crimelife City (the cloud place "Crimelife Tycoon") only. Sprint, stamina, landings and the camera bob are in [[Movement and Stamina]]; this note is the animation layer and the two new moves. Built 2026-11-20 on the developer's brief "Ensure there's animations to character; reuse the animations from the group animations" ([[2026-11-20 Admin Animations Third Person]]).

## What it does
The player character plays OBT's `Player_` clip set through one script: idle, walk, jog and run in four directions, sprint, jump, fall, land and hard land, climb, swim, a legs layer under a held tool, and two moves, **roll** (Q) and **ledge climb** (Space at a ledge). CrimeLife's crouch, lean and stamina stay as they were. 41 clips load in the cloud place.

## Where it lives
- `StarterPlayer.StarterCharacterScripts.Movement` (LocalScript): OBT's `Movement.lua`, ported. It sets the character attribute `MovementAnimations`. Removed from the OBT original: walker morphs, fly clips, avatar packs, emote detection, SFX and UI shell hooks, the run-time id wait.
- `ReplicatedStorage.PlayerMovement`: `Animations` (42 Animation objects named as `Movement` expects: 41 clips and `Empty`), `Config` (speeds, bands, roll and ledge numbers), `Fallback` (pure, name to Roblox default R15 clip), `Roll` (RemoteEvent).
- `ServerScriptService.Movement.Scripts.RollAuthority` (`request(player, now)`), `SprintAuthority.spend`, `RunningState` (wires `Roll.OnServerEvent` and cleanup on leave).
- `StarterPlayer.StarterCharacterScripts.Animate2`: yields its own clips while `MovementAnimations` is set (sit still plays); still owns the WalkSpeed ramp, sprint input, landing recovery and sprint FOV; stops `Animate`'s leftover tracks.
- `ServerStorage.CityQuarantine.AnimationsReplaced.LandAnim` (disabled, `OriginalPath` kept).
- Tests: `ServerStorage.UnitTest.Cases.Fallback_Test` (3), `RollAuthority_Test` (4).

## How it works
- **Config numbers.** `BaseSpeed` Walk 3, Jog 12, Run 20, Sprint 38: each CrimeLife gait plays its kind of clip at rate about 1 (a 2.0-leg rig: carry 12 is Jog, walk 20 Run, sprint 38 Sprint). Bands `WalkToJog` {4, 7}, `JogToRun` {13, 18}, `RunToSprint` {26, 34}. `FallbackWait` 3 s.
- **Roll.** Key Q, pad ButtonB, 0.62 s, speed 30 falling to 12, cooldown 0.9 s, sprint roll boost, stamina cost **12.3** (40 / 325 x 100, server-owned). The client rolls (it owns the body) and fires `Roll`; the server refuses on cooldown (`os.clock()`), dead, any carry (`CarrySpeedCap` or `CarryState:IsCarrying`), `StunnedUntil`, ragdoll, anchored, `AdminFrozen`, crouched, seated, PlatformStand, a player who left, and sprint locked out; then spends the stamina. A refused roll costs nothing and is not undone (the character already moved; `ponytail:` comment in `RollAuthority`).
- **Ledge climb.** `Reach` 2.6, height 3.8 to 8, 1.0 s; raycasts respect `CanCollide`, and the limbs are kept out of collisions during the move and restored at the end.
- **Blocked** (client): dead, `Sit`, PlatformStand, root anchored, ragdolled, frozen, crouching, any carry or supply Tool, any open panel (`UI.Panels.current() ~= nil`). While crouching `Movement` plays nothing: `Crouching`'s clips play alone.
- **Layers.** A shared phase and a directional blend; under a held tool the legs clips (`*Legs`) play at Action4 and full-body loops at Core, so the gun's hold clip stays on the arms.
- **Fallback.** After `PreloadAsync`, a clip whose fetch failed or whose `Length` is still 0 after 3 s is replaced by its Roblox default (Idle 507766388, Walk and Jog 507777826, Run and Sprint 507767714, Jump 507765000, Fall 507767968, Climb 507765644, Swim 507784897, SwimIdle 507785072) or dropped (legs layers, Land, LandHard, Roll, LedgeClimb), with one warn line.
- **NPCs and police** keep their own clips: 84 server humanoids, 0 with `Length` 0 (measured 2026-11-20).

## Extend it
- A new clip: add an Animation object to `PlayerMovement.Animations` under the name `Movement` expects and, if a default exists, a `Fallback` row. Put numbers in `Config`.
- A new move: client-owned, checked by a server authority that spends stamina, refused while carrying (copy the roll's pattern).
- The group clips load only in a group-owned place; a copy of the file on disk will play the fallbacks ([[Sound and Asset Traps]]).

## Watch out
- **Clips load only in the group-owned place.** In the unpublished file every group clip fails with `Length` 0; this is why the developer published the city into SolarArc Studios ([[Places and Studio Windows]]).
- **The joints are AnimationConstraints**, not Motor6Ds ([[Physics and Character Traps]], [[Ragdoll]]).
- Leg scale is read once when the script starts; the same avatar gave 1.044 and 1.096 in two sessions, so playback rates vary about 5% per spawn (open).
- Feet slip about a fifth to a quarter of the speed (Jog base 12 was chosen so every gait plays at one rate; the clips' true foot speeds are in the Config comment).
- `Animate2`'s startup stop loop can stop a `Movement` track once (loops heal; a one-shot would be lost; low odds).
- A move is not cancelled by a mid-move stun, freeze, ragdoll or carry pick-up; a crouched jump still plays `Jump`; a client that skips `FireServer` rolls free at the client cooldown; a stale `Stamina` attribute can make a legitimate roll free ([[Open Items]]).
- In one long Play session `AutoRotate` stayed false and the shift-lock cursor showed with no key pressed, on a fresh `LoadCharacter` character; not the roll (a fresh Play was true before and after), `CustomShiftLock` suspected, not investigated.
- The touch roll button is computed, not read back: x 556..612, y 306..362 at 844 x 390 (blaster UIScale 0.6); at 1920 x 1080 it sits 10 px below the Shoot circle.
- Hold clips and the third-person camera are in [[Weapons and Blaster]] and [[Viewmodels and Weapon Animation]].

## History
- 2026-11-20: crouching with a tool out keeps the tool's hold: `Crouching` drops its clips (idle Action2, walk Action3) to Movement while a Tool is held, so the Blaster hold (Action) keeps the arms; robbery prompts lock the controls and ease the player into place (`InteractionAnimations`). [[2026-11-20 Smooth Enemies Patrols and Dropped Duffels]]
- 2026-11-20: built. Review fixes: the leaked `CharacterAdded` connection, per-frame allocations, roll refused while crouched, seated or PlatformStand and after leaving, `spend` refused while locked out. Measured: roll 18.07 studs in 0.634 s for 12.3 stamina; ledge 6.00 studs in 0.999 s; sprint hip swing 140.2 degrees before and 111.6 after. [[2026-11-20 Admin Animations Third Person]]

See [[Batch Log]].
