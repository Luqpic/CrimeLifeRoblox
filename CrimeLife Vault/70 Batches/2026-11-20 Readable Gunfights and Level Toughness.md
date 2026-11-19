---
type: batch
tags: [batch, city, combat, enemies, npc-ai, guards, leveling, balance]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-20-combat-balance/brief.md", ".superpowers/sdd/2026-11-20-combat-balance/report.md", ".superpowers/sdd/2026-11-20-combat-balance/review.md", ".superpowers/sdd/2026-11-20-combat-balance/progress.md", "CityMerge/after-import.md ('Combat balance 2026-11-20' and 'Combat review fixes 2026-11-20')", "git log 3327d15..ff8caf5"]
---

# 2026-11-20 Readable Gunfights and Level Toughness

Two commits on `main`: `86a0073` (the build) and `ff8caf5` (review fixes), plus the vault update. Third batch of the night on the cloud place "Crimelife Tycoon" (placeId 128488619644399), after [[2026-11-20 Heist Police and Bank Guards]]. One Opus implementer built it from the controller's brief; one Sonnet review read it.

## Asked for
The same request as the batch before, second half (developer, 2026-11-20, verbatim, typos kept):
> "After you are done with that, I plan to polish up the robbery systems + FPS system. I suggest for Big robberies like bank, spawn in a few police first after a few minutes. Replace those dummies at teh vault area of the bank with securities and Police, and when the player activates the rolling vault to the place wehre teh player can start collecting money, you can spawn in armed polices into the bank. After that, I need you to hekp with rebalancing the damage and level curve. I notice that players are increbly weak to the enemies that uses gun. Provide a creative solution to solve this, perhaps we might need to rework the shooting mechanics for enemies? You decide."

Target the developer chose: a new player should "win 1v2 comfortably", by "Health + armor by level". The brief added, after Batch 2, that the Bank guards' fire (invisible, from Batch 2) and a Security guard hitting at range with a Baton must be fixed as part of this batch.

## What changed
The controller's design, "readable gunfights". All numbers live in the new `ReplicatedStorage.Enemy.Combat`; PvP is untouched.

1. **Shooter tokens.** At most 2 enemies (gangs, police, heist police, guards) fire at one player at a time. Others keep their aim and wait. A token is held for one burst and given back at the burst's end, on lost sight, stun, death, target change and destroy. The registry is in new `Enemy.Scripts.NpcFire` and is cleared on a player's death and leave. Pure allocation (`Combat.newTokens`): one target per shooter, an 8 s stale timeout as a safety net.
2. **Wind-up with a tell.** The first shot of an engagement (a new target, or the same target after more than 1.5 s unseen) waits 0.6 s (semi) or 0.8 s (auto). `NpcFire.showTell` draws a plain red Beam from the muzzle to the target's root until the first shot (a 2 s `Debris` net). No upload.
3. **Focus ramp.** The aim cone starts at x2.5 and tightens to x1 over 2 s of continuous sight; losing sight resets it. A hit on the shooter flinches it (focus back 0.75 s, next shot +0.3 s). A rolling target gets the widest cone: `RollAuthority` stamps `RollingUntil` (server clock, 0.744 s) on the root of an accepted roll.
4. **Bursts.** Every NPC gun fires 3 to 5 shots, then pauses 0.8 to 1.2 s with the token released. Semi-automatic guns fire no faster than one shot per 0.45 s. Melee keeps its own path (no token, no line, no burst).
5. **Range falloff** (NPC shots only, in `ShotResolver.applyDamage`): x1 to 25 studs, linear to x0.5 at 90 studs and beyond.
6. **Player toughness.** `Leveling.Constants.maxHealth(level)` = 100 + 4 x (level - 1) (376 at level 70; was +2, 238). **Armor** 0.4 % a level above 1, at most 25 %, in the same NPC branch (lasers and the death pit are unaffected). **Regen:** new `StarterPlayer.StarterCharacterScripts.Health` replaces Roblox's default script: 6 % of max a second after 6 s without a loss, asleep at full health, it only raises Health.
7. **Tuning** after measuring 1 to 6: `EnemyTemplates.Police.DamageOverride` 12 to 9, `Bandits` 3 to 1.5 a pellet (Studio attributes, no mirror).
8. **Guards (the controller's addition).** `GuardPost` fires real shots through `ShotResolver.resolveShot` from the weapon's muzzle (tracer, flash and sound on every client, the Shoot clip, `Tagged`, falloff and armor), in the template's cone with the focus ramp, using tokens, the aim line and bursts. Weapon damage is `GuardDamage` (6), set at spawn; the magazine is topped up before each shot, so guards never reload. A melee guard (Security, Baton) turns first, then strikes only within the Baton's reach (6 from the muzzle), and never at a target still staggered or within `GuardFireInterval` of its last stun (anti stun-lock). NewsStation's guards are now `EnemyTemplates.Police` rigs with a real Mateba (`GuardTemplates { "Police" }`, `GuardSpawnLift` 3.2); the grey `GuardTemplate` stays in the place because `WorldSpec` asserts it. The guards' `damage` closures in `HeistServer` and `NewsStationServer` were removed.

### Review fixes (`ff8caf5`, controller)
Sonnet review of `86a0073` (code only, not run in Studio): 0 Critical, 2 Important, 6 Minor (the review lists 7 numbered Minors; one needed no action).
- **I2 fixed:** a flinch is limited to once per `Combat.FLINCH_COOLDOWN` (1 s) for enemies and guards. Without it a fast gun (the Glock at 4 clicks a second or more) could keep a shooter silent for good, and it would hold one of the target's two tokens. The provocation still renews. Specs added in `Combat_Test` and `GuardSpec`.
- **Guard turn fixed:** `_face` skips a turn within 2 degrees (`FACE_TOLERANCE`), so guards no longer replicate the whole rig ten times a second.
- **Dismissed:** "guards target through walls". `GuardPost.selectTarget` takes only `visible` candidates (a raycast in `_candidates`).
- **I1 left for the developer:** guards pay XP, 30 % cash and quest credit when killed outside a robbery and respawn every 60 s (see Left open).

## Decisions
Picker answers and rulings, 2026-11-20. Full text in [[Weapon and Combat Decisions]], [[Economy and Progression Decisions]] and [[Enemy and World Decisions]].
- Combat target: "win 1v2 comfortably"; "Health + armor by level"; "Yes, save after each task". Fact the picker got wrong: a new player owns only the Crowbar, so the target was measured with the Glock 17 (400 of the 500 starting cash) and a Crowbar rush.
- Claude's rulings (brief and report): tokens max 2 per player; wind-up with a red aim line; focus ramp; bursts; falloff; health 100 + 4 a level; armor 0.4 % a level up to 25 %; regen 6 % a second after 6 s; guards fire real shots; Security strikes only in reach; NewsStation guards are Police rigs; Police 12 to 9 and Bandits 3 to 1.5.
- Implementer rulings: semi-automatic guns also fire bursts (a token is one burst, five pistol enemies rotate); the wind-up happens once per engagement; "rolling" means the server `RollingUntil`; melee is exempt from tokens and the line; any player hit flinches (also from a player the police filter ignores); falloff and armor apply to every NPC hit on a player, melee included; regen replaces the default Health script by name; no free starter gun (the developer's call); only Police and Bandits tuned.

## Measurements
Setup: flat ground at (-200, 1.75, 1200), 1,300 studs from the spawners; player level 1 set through the admin tool; enemies built with EnemyRig and EnemyAI, no filter, at 35 studs (x +-4, z 35) for 10 s. Damage is the sum of `Tagged`; MaxHealth 100,000 for the window; shots are `_ammo` decrements; strafing is A and D at 20 studs/s switching every second. Display awake, RenderStepped 15 to 16 a second.

Live values read before any change (Studio attributes): Thug 9 / 90 / Crowbar 45; Security 9 / 80 / Baton 45, range 6, stun 1; Offender 8 / 90 / aim 4, 6.5, 6.5, 3, 16 / M1911 38, 400 rpm, mag 7; Police 12 / 100 / Mateba 60, 220 rpm, mag 6; Smuggler 4 / 85 / PB; Bandits 3 / 100 / Mossberg 15 x 8; Disrupters 4 / 110 / AKM; Saboteur 2 / 130 / P-90; Armed Police 3 / 120 / Scar L (DamageOverride / MaxHealth / weapon). AimConfig defaults: base 2, distance 4.5, movement 5.5, max 12, acquisition 3 over 0.8 s. `MAX_HEALTH_PER_LEVEL` was 2; starting cash 500; the cheapest pistol is the Glock 17 at 400. Regen already existed (Roblox's default Health script, 1 % a second, no delay): the survey's "no regen" was wrong.

Damage taken per second, 10 s:

| Scenario | Before | After items 1 to 6 | Final (tuned) |
|---|---|---|---|
| 1v2 Offender standing | 7.2 (42 shots, 8 hits) | 12.1, 15.1, 15.9 | 12.9 (mean of 4: 14.0) |
| 1v2 Offender strafing | 8.0 | 8.2 | 6.1 |
| 1v2 Police standing | 18.0 (24 shots, 12 hits) | 22.7, 15.9, 10.2, 18.2, 20.5, 8.0 (mean 15.9) | 13.7, 17.1, 15.4 |
| 1v2 Police strafing | 7.2 | 13.5 | 8.5 |
| 1v2 Bandits standing | not run | 33.2 | 15.5, 14.9 |
| 1v2 Bandits strafing | not run | not run | 12.6 |
| 1v2 Smuggler, Disrupters, Saboteur standing | not run | 4.8, 6.1, 4.8 | not tuned |
| 1v5 mixed gangs standing | 56.1 (all 5 fired in the same 0.5 s) | 28.4 | 14.9 |

- **Why Offender and Police got more accurate.** Before, semi-automatic shots every 0.25 s let recoil (18 to 34 degrees a shot, the AI's decay 69 degrees a second) climb over the target's head: 8 of 42 hit. At 0.45 s it settles: 15 of 26. Pooled over 9 Police runs, tuned is about 12 dps.
- **Tokens.** At most 2 tokens, 2 aim lines and 2 overlapping bursts in every after-run (1v5: Offender 2.83 to 4.68 s, then Smuggler 4.76 to 6.61 s). Four distinct shooters in one 0.5 s bucket only at hand-overs.
- **Aim line.** Exactly its wind-up and it ends at the first shot (Offender 0.62 to 1.22 s, first shot 1.21 s; Police 0.80 to 1.38 s; Disrupters 0.60 to 1.40 s); one per engagement. Seen in a screenshot (not saved).
- **The 1v2 target** (Glock 17: 5 hits per enemy, 70 % accuracy gives 14.3 shots for both, one magazine; 1.3 s at 650 rpm, 3.6 s at 4 clicks a second). End health = 100 - D x 1.8 - D/2 x 1.8. Before: Offender 81 % standing, 79 % strafing; Police 52 % standing, 81 % strafing. Final: Offender 62 % standing, 81 to 84 % strafing; Police 59 % standing (66, 74, 70 % from the hit timeline), 77 % strafing; Bandits 59 % standing (60, 50 %), 66 % strafing. Two of five untuned Police runs ended at 43 % and 37 %, hence the Police tune.
- **Crowbar rush 1v1** (Offender at 30 studs): before, health on arrival 44, 68, 68 HP and after 2 swings 37 and 53 (one survived at 45); after, on arrival 92, 92, 92 and after 2 swings 76, 68, 68, the Offender dead at the second swing every time.
- **Level 70.** MaxHealth 238 to 376. One Offender hit at 20 studs 8 to 6.00 (x0.75). Regen before: +2.4 a second from the first second. Regen after: 200 held until 5.98 s, 211.7 at 6.25 s, then about 22.9 a second (expected 22.6) to 280.9 at 9.38 s.
- **Bank guards.** Two Police guards provoked (emulated `Tagged`), the player at 17 and 21 studs: aim lines 0.11 to 0.76 s, first shots at 0.76 s, then about one shot a second each, 15 hits of 6 (90 HP) in 8 s, the Shoot clip on every shot, a `ReplicateShot` for every guard shot (16 Police shots, 6 Security swings). Security: at 14.8 studs in sight and provoked, 0 strikes in 4 s; at 3.5 studs it struck at 0.1, 2.1 and 4.1 s for 12 each (6 rays, head doubled), the target stunned 0.1 to 1.1, 2.1 to 3.1 and 4.1 to 5.0 s and free between.
- **NewsStation guards:** Police rigs with a Mateba, damage 6, on the floor (root 3.20 above the floor at all three posts). Not watched firing in Play.

**Tests.** RED first: `Combat_Test` 0 / 1 (module missing); `RollAuthority_Test` 4 / 5; `GuardSpec` errored. GREEN: Combat 9 / 9, RollAuthority 5 / 5, Guard 29 / 0. A Play bug (Security never struck at 3.5 studs) got a regression case, RED "4 studs: it strikes, expected 1, got 0", GREEN once the guard turned first. The full city suite caught `EnemyTargetFilter_Test > onDamagedBy` ("EnemyAI:501 arithmetic on nil"): `_setTarget` called `_stopFiring` on a stand-in, so a new target now stops a burst only while one runs. After the build: city 365 / 365 / 0, heist 759 / 0. After the review fixes: city 366 / 366 / 0, heist 760 / 0, run from the Server command bar (from a temp Script the two `Source` specs fail, see [[Luau and Scripting Traps]]). Server boot: only the known DataStore error.

Files: 15 scripts in the build (4 new: `Enemy.Combat`, `NpcFire`, the `Health` script, `Combat_Test`; `Leveling.Constants` got its first mirror), 5 in the review fixes. Every mirror equals the place by length and Adler-32 (15 / 15). Rows in `CityMerge/after-import.md` "Combat balance 2026-11-20" and "Combat review fixes 2026-11-20".

## Verified
The table and bullets above were read in Play on the cloud place: tokens, the aim line, bursts, falloff (x0.75 armor at level 70 read back from one hit), max health, regen timing, the Crowbar rush, and the guards' shots and strikes. End state: Edit mode, 1 enabled SpawnLocation, no `Tmp*` object, no Workspace attributes.

## Not verified
- Two players, and a phone.
- A real Blaster hit on a guard, NewsStation guards firing in Play, and a roll against NPC fire.
- A flinch in Play (specs only), real Crowbar clicks.
- The 1v2 verdict assumes 4 clicks a second; at the Glock's 650 rpm cap every case ends above 75 %.

## Left open
In [[Open Items]], section "Heist police, gunfights and level toughness (2026-11-20)":
- **Offender deadlier standing:** 7.2 to 14.0 dps (62 % health left) because recoil no longer ruins follow-ups. Lever: Offender `DamageOverride` 8 to 6, if 1v2 feels hard.
- **Guard pay outside a robbery** (review I1), a developer call. The ceiling is about 95 XP and 64 cash a minute across all 7 guards (Bank 2 Security and 2 Police, NewsStation 3 Police), plus 5 Police quest kills a minute; Police guards also give police heat; NewsStation guards newly pay cash and quest credit because they are Police rigs.
- **A free starter gun:** a new player owns only the Crowbar; the Glock 17 costs 400 of the 500 starting cash.
- **A level-up still fully heals mid-fight.**
- Run-to-run variance (Police standing 8.0 to 22.7; the before cells are single runs); Bandits standing is the tightest (one run 50 %).
- Review Minors left: a roll in place gets the widest NPC cone (bounded by stamina, about 37 % uptime sustained); the 8 s token timeout against a very slow weapon (none today); NPC explosions and bleed bypass falloff and armor (by design); the `Health` script stays asleep if MaxHealth rises without a Health write (nothing does that today).

## Saved
Place saved to Roblox with `save_place` after the build and after the review fixes (version 33 after this batch). Never published, nothing pushed.

NOT published

## Models and skills used
Opus: the implementer and the controller's review fixes. Sonnet: the review (with `roblox-code-review` and `roblox-security`). Skills for the code work: `roblox-npc-ai`, `roblox-game-systems`, `roblox-security` ([[Vault Skills Only and Model Routing]]). The implementer's report was again returned as text because the harness refused the Write.

## Links
[[Enemies and Spawner]] [[Police and Wanted]] [[Robbery Heists and Getaway]] [[Leveling and Renown]] [[Weapons and Blaster]] [[Movement and Stamina]] [[Open Items]] [[Weapon and Combat Decisions]] [[Economy and Progression Decisions]] [[Enemy and World Decisions]] [[Physics and Character Traps]] [[Luau and Scripting Traps]] [[Studio MCP Gotchas]] [[2026-11-20 Heist Police and Bank Guards]]
