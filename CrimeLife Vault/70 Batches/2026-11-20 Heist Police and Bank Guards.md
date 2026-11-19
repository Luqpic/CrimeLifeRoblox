---
type: batch
tags: [batch, city, heists, police, bank, guards, npc-ai]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-20-heist-police/brief.md", ".superpowers/sdd/2026-11-20-heist-police/report.md", ".superpowers/sdd/2026-11-20-heist-police/progress.md", "CityMerge/after-import.md (from 'Heist police 2026-11-20' to 'Combat balance 2026-11-20', review fixes included)", "git log 182f552..3327d15"]
---

# 2026-11-20 Heist Police and Bank Guards

Two commits on `main`: `ba555fe` (the build) and `3327d15` (review fixes), plus the vault update. Second of three batches done overnight on the cloud place "Crimelife Tycoon" (placeId 128488619644399). It follows [[2026-11-20 Admin Animations Third Person]]; the next batch is [[2026-11-20 Readable Gunfights and Level Toughness]]. The brief was written by the controller; one Opus implementer built it and one Sonnet review read it.

## Asked for
The developer, 2026-11-20 (verbatim, typos kept):
> "After you are done with that, I plan to polish up the robbery systems + FPS system. I suggest for Big robberies like bank, spawn in a few police first after a few minutes. Replace those dummies at teh vault area of the bank with securities and Police, and when the player activates the rolling vault to the place wehre teh player can start collecting money, you can spawn in armed polices into the bank. After that, I need you to hekp with rebalancing the damage and level curve. I notice that players are increbly weak to the enemies that uses gun. Provide a creative solution to solve this, perhaps we might need to rework the shooting mechanics for enemies? You decide."

This batch covers the first half (police and guards). The second half is [[2026-11-20 Readable Gunfights and Level Toughness]]. One clarification from the developer: "I meant when you start the robbery, the police will come after a few minutes."

## What changed

### Timed heist police (new `Heist.Services.HeistPolice`)
- A component on the Bank and NewsStation sessions (start, seal, rearm), updated on each location's heartbeat and acting once a second (`HEIST_POLICE_TICK` 1). Waves come from each location's `Config.HeistPolice`.
- **Bank:** Police 3 at 120 s, then +2 every 90 s, at most 8 alive. **NewsStation:** Police 2 at 120 s, then +1 every 90 s, at most 4 alive.
- Officers are made by `PoliceDispatcher.spawnLoose` (they look, fight, count as seen and pay like police) at new markers `HeistPoliceSpawn1..3`, within 1.5 studs (`HEIST_POLICE_SCATTER`), one a frame. Targets: that robbery's participants anywhere and wanted players inside the building, never bystanders.
- Idle officers are sent (`investigate`) toward the robber nearest marker 1, only when one path check from that marker reaches the robber. The seal removes every heist officer.
- Sharing `POLICE_CAP` 24: a wave fills only free room (`PoliceDispatcher.room()` re-checked before each officer) and never removes a squad officer. Squads count heist officers as taken room.

### The rolling vault
- `Config.HeistPoliceVault`: Armed Police, 4 at the opening, +2 every 60 s, at most 8. Triggered by HeistServer's existing once-per-session vault-door latch (the edge that unlocks ATMs, registers, safes and deposit boxes), which now calls `heistPolice:OnVaultOpened()`.

### The Bank's guards are Security and Police
- `GuardPost.templateFor` reads the Bank's `{ "Security", "Police" }` by post: posts 1 and 3 Security, posts 2 and 4 Police. Built through EnemyRig (look, weapon, health, nameplate, ragdoll), with `Witness` and `WitnessRole = "Guard"`, root anchored at the post, idle and hold clips. They stand at their posts at all times (`GuardsAlwaysPosted`) and ignore everyone until the robbery starts or someone damages them (`GuardPost:Provoke`, fed by one Blaster `Tagged` listener; the attacker stays a target 30 s, also outside a session). NewsStation keeps the grey `GuardTemplate` in this batch (the next batch changes that).
- Config: `GuardSpawnLift` 3.2, `GuardRespawnSeconds` 60, `GuardProvokeSeconds` 30. Outside a session a dead guard returns at its post after 60 s. At a session start a standing guard is counted again and a dead one replaced (else `TryStart` zeroing the count would keep the GuardRoom gate shut).
- `HeistMarkers.GuardPost4` moved from y -115.31 to -118.00 (its old guard floated 5.7 studs); `OriginalCFrame` keeps the old value. Anchored guards skip cover (the old code computed a path every second for a guard that could not move).

### Star squads wait too (controller ruling)
- `PoliceDispatcher.addSquadHold` and `isHeld`: while a player is held, the top-up asks for 0 officers for them (live ones still count) and the alarm ring is kept for the first round after the hold. HeistPolice registers the hold, and registers with `WantedService.addActiveRobbery` so a held robber counts as seen and keeps the stars (added after Play run 1). The stars and the HUD still rise at the alarm.

### Specs
`HeistPoliceSpec` (heist suite, 11 cases, 12 after the review), four new `GuardSpec` cases, city case `HeistSquadHold_Test` (2).

### Review fixes (`3327d15`, controller)
Sonnet review of `ba555fe`: 0 Critical, 2 Important, 4 Minor.
- **I1 fixed:** the squad hold covers the robbery's participants and whoever was inside when it started. It was every wanted player who walked in during the first 2 minutes.
- **Minor 1 fixed:** a wave with no `POLICE_CAP` room waits for room (it was used up).
- **Minor 3 fixed:** `BankInstance.NotifyGuardSpawned` and `NotifyGuardDied` count only while the Bank is Active, so a guard respawned between robberies cannot fire `GuardsCleared` (the GuardRoom gate) on its next death.
- **Minor 4 fixed:** a session counter stops a wave that is still sending after the robbery ended.
- **Left:** I2 (see Left open) and M2 (one steering path check a second while robbers are inside).

## Decisions
Picker answers (the developer's own choices), 2026-11-20. Full text in [[Robbery Decisions]].
- Timing: "I meant when you start the robbery, the police will come after a few minutes". Bank "3 at 2:00, +2 every 90 s" (cap 8). NewsStation 2 at 2:00, +1 every 90 s (cap 4). Scope "Bank + NewsStation"; SlowFoods and Gas2Go unchanged.
- The Bank vault dummies are replaced by Security and Police guards that fight "once the robbery starts" (or when attacked).
- Rolling vault open: "4 now, +2 every 60 s, cap 8" Armed Police.
- Saving: "Yes, save after each task".

Rulings by the implementer and controller (in the report and brief):
1. A wave goes only while a robber (participant, or wanted player inside) is in the building. A wave due with nobody inside is used up, not delayed; dead officers wait for the next wave. (Later changed for the cap-room case, see Minor 1.)
2. Vault-open armed police use the markers by the B arrival. Measured: no path from B past the obby pit, so they hold the gauntlet and the way out.
3. Steering: one path check per tick from marker 1; `investigate` only when it succeeds.
4. The squad hold lasts until the first wave by time and counts as an active robbery so the stars hold (narrowed by review I1).
5. Guards built through EnemyRig pay like an enemy of that type (XP, 30 % cash drop, quest credit), and hits on Police-type guards give police heat. Their fire stays `GuardDamage` 6 every 0.9 s; the templates' `DamageOverride` is not used.
6. Provocation 30 s in both configs; NewsStation guards get provocation and face-the-target through the shared `GuardPost`.
7. `GuardSpawnLift` 3.2 and the GuardPost4 height fix.

## Measurements
Setup: Play on the cloud place, display awake (client RenderStepped 15 a second), no timer shortened, times counted from the moment the session went Active through the real trigger. The robber stood in an invisible ForceField except in damage windows.

**Bank run 1** (lobby 0 to 110 s, vault corridor as participant 110 to 150 s, then lobby; vault door open at 23.6 s; seal forced at 395.3 s).
- Police in the vault: 0 before 2:00; 3 at 121.0 s; 5 at 210.5 s; 7 at 300.0 s; 8 at 390.4 s (cap, 1 sent).
- Armed Police: 4 at 23.7 s, 6 at 144.4 s, 8 at 203.9 s; the 263.9 s wave sent 0 (cap). The 84 s wave (+60 s) was skipped: the trigger player is not a participant until the vault teleporter, nobody saw them while the squad was held, and their 3 stars drained to 0 by about 44 s, so no robber counted as inside. Fixed by the active-robbery registration.
- Spawn positions within 1.5 studs of the markers (for example (1389.1, -114.9, 2264.4) and (1383.5, -114.9, 2263.9)). The markers are out of sight of the `TeleporterBankB` arrival (rays at legs, root and head).
- Path: the three 2:00 officers were 70.5, 72.4 and 75.5 studs away at 121.3 s and 69.1, 51.6 and 51.1 at 137.7 s, all in Attack (they fire from range).
- Damage (5 s, ForceField off, MaxHealth 1000 for the window): 11 police hits, 63 by `Tagged`, 53.5 HP net. The `Tagged` total is the reliable one.
- Seal: all heist police gone, `Workspace.Police` empty, `ResetCooldown` back to Idle with 4 fresh guards.

**Bank run 2** (after the hold fix; the robber stays in the lobby and is never a participant): stars 3 with `WantedSeen` true through 110.2 s, draining from 120.4 s. Squad none before 2:00; 4 Police at 121.7 to 122.0 s and 2 Armed at 122.1 to 122.2 s (for example at (1124, 4, 2306)), shrinking as stars drained. Armed 4 at 23.7 s, 6 at 84.6 s, 8 at 144.4 s. Police 3 at 120.5 s. Seal at 165.3 s left 0.

**NewsStation** (participant throughout, 2 stars): heist police 2 at 120.5 s, +1 at 211.0 s, +1 at 300.4 s (cap 4). Squad none before 2:00, then 4 Police outside at 122.9 to 123.2 s (x about -499 to -502) who walked in. Officers were 12.2 and 17.4 studs away at 121 s, in Attack by 124 s. Seal at 305.1 s removed the 4 heist officers; the 4 squad officers stay for the getaway.

**Guards (Bank).** Screenshot of POLICE and SECURITY rigs with weapons and nameplates (not saved). Security 80 hp, Police 100 hp, roots y -114.8 (feet on the -118 floor). Passive outside a session: a 0-star player 9.98 studs from a guard for 30 s, health 100, the guard never turned. Hit outside a session (emulated `Tagged` plus `TakeDamage(10)`): guard 100 to 90; the player then lost 31 HP in 5 s (100 to 69, one guard at 6 a shot), the guard faced the player (dot 0.99993), the other three stayed passive. After the start, participant in view: 20 hits of 6 = 120 HP in 5 s. `GuardsRemaining` 4 at the start (the GuardRoom gate works).

**Tests.** RED first: HeistPoliceSpec 0 / 1 (module missing); Guard 22 / 4 failed (the four new cases). GREEN: HeistPolice 11 / 0, Guard 26 / 0, HeistSquadHold_Test 2 / 2. After the build: city 355 / 355 / 0, heist 755 / 0. After the review fixes: city 355 / 355 / 0, heist 756 / 0 (HeistPolice 12, BankInstance 37). Server boot: only the known DataStore `StudioAccessToApisNotAllowed` error; client 0 errors. Play after the fix: walking into the Bank lobby with the Crowbar set off the alarm (3 stars, seen) and `PoliceDispatcher.isHeld` was true for that player (inside at the start).

Files: 12 scripts in the build (3 new), 4 in the review fixes; every mirror in `CityScripts/` equals the place by length and Adler-32 (12 / 12, then 4 / 4); rows in `CityMerge/after-import.md` "Heist police 2026-11-20". Studio objects: `HeistMarkers.HeistPoliceSpawn1..3` at (1390, -115, 2265), (1384, -115, 2263.5), (1372, -115, 2264); `NewsStationMarkers.HeistPoliceSpawn1..3` at (-640, 5.3, 1000), (-645, 5.3, 1006), (-650, 5.3, 995); each a 2 x 1 x 2 anchored invisible Part with collide, query and touch off.

## Verified
Every number above was read in Play on the cloud place. The timed waves, the vault waves, the caps, the marker positions, the squad hold, the guard look and passivity, provocation, and the seal clean-up. End state: Edit mode, 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attributes.

## Not verified
- Two players, and a phone.
- A real Blaster hit on a guard (the provocation was emulated with `Tagged`).
- NewsStation's 6:30 wave (the run ended at 5:05; the cap is covered by the spec and by the Bank's 6:30 wave).
- Guard shots were invisible in this batch (no tracer, no shoot clip); the next batch fixed that.

## Left open
In [[Open Items]], section "Heist police, gunfights and level toughness (2026-11-20)":
- **I2:** the vault Armed Police spawn at the B arrival markers and cannot path past the obby pit, so they hold the gauntlet and exit. A vault-side marker set for `HeistPoliceVault` would put them in the vault.
- **M2:** one steering path check a second while robbers are inside.
- Squads still cannot spawn while every robber is in the vault (the dispatcher's entrance lookup covers `Workspace.Bank`, not `BankVault`). Pre-existing.
- After the hold ends, a non-participant left in the Bank lobby is unseen and their stars drain (run 2). Pre-existing for non-participants.
- A Security guard holding a Baton hit at range, and guard shots were invisible: both closed in the next batch.

## Saved
Place saved to Roblox with `save_place` after the build (version 28) and after the review fixes (version 29). Never published, nothing pushed.

NOT published

## Models and skills used
Opus: the implementer and the controller's review fixes. Sonnet: the review. Skills for the code work: `roblox-npc-ai`, `roblox-game-systems`, `roblox-security` ([[Vault Skills Only and Model Routing]]). The implementer's Write into the gitignored `.superpowers/` folder was refused by the harness, so the controller saved its report from the hand-back ([[Studio MCP Gotchas]]).

## Links
[[Police and Wanted]] [[Robbery Heists and Getaway]] [[Enemies and Spawner]] [[Robbery Decisions]] [[Open Items]] [[Physics and Character Traps]] [[Studio MCP Gotchas]] [[2026-11-20 Readable Gunfights and Level Toughness]]
