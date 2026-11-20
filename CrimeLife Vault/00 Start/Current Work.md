---
type: reference
tags: [start, in-progress]
updated: 2026-11-20
sources: ["The developer's request, 2026-11-20 evening: [[2026-11-20 Quest NPCs Combat Stealth Gacha]]"]
---

# Current Work

**Read this first after a context compaction.** It holds the request in progress, every answer the developer gave, what is done and what is next. Update it after each step. When a part is finished, it moves to a batch note in `70 Batches/` and the line here says so.

## NEWEST request in progress (2026-11-20 late night): smooth enemies, action lock, crouch gun, police patrols, ragdoll
Verbatim: [[2026-11-20 Smooth Enemies Action Lock Crouch Gun Police Patrols Ragdoll]]. Five parts:
1. **Enemies jitter and lag** while running, chasing and shooting: smooth them.
2. **Robbery actions:** tween the player into place facing the object and lock him there; no sliding about.
3. **Crouch with a gun:** the gun points down; needs a fitting animation.
4. **Police patrol the city randomly**; police and criminals fight when they see each other.
5. **Death knockback** from the part last hit (a headshot kill: the head takes the impact first), more precise and realistic ragdoll.
6. **Duffel drop on death** (added mid-turn, verbatim): "Also if a player dies, tehy drop their duffelbag in which other players or themselves can carry".
7. **Level-up GUI stuck** (added mid-turn, verbatim): "Also another bug where the level up GUI sometimes gets stuck on teh screen".

### Answers (pickers)
- **Patrols:** "6, also chase wanted": 6 officers walk random routes on city roads, a new one 30 s after one dies; they shoot criminals on sight and go after wanted players like squads; criminals shoot them on sight too.
- **Death push:** "By weapon": pistols and rifles knock the body back a few studs from the hit point; shotguns and snipers launch it like OBT.
- **Crouch gun:** "The gun's own hold": crouched legs only, the arms keep the gun's normal hold.
- **Action lock:** "Locked until it ends": no walking while the prompt is held or the minigame is open; letting go or closing the minigame frees him.
- **Duffel drop:** "2 minutes": the bag lies where they died for 120 s with a pick-up prompt, then it and its cash are gone; "Anyone" can pick it up (the owner after respawning, a teammate, another player), and whoever carries it banks it.

### Status
| Part | Status |
|---|---|
| 1 Smooth enemies | **done** (version 70): in Attack a `Facing` AlignOrientation (Responsiveness 30) replaces the 4 Hz root snaps, AutoRotate off; released leaving Attack, when stunned, on death. Client: facing snaps over 12 deg/frame 10 of 10 moving frames (up to 55) -> 0 (max 4); chasing Thugs 16.5 to 17.6 of 18 studs/s, 0 to 1 stalls in 11 s. EnemyAI 59,066 / 566881909 |
| 2 Action lock | **done** (version 73): `StarterPlayerScripts.InteractionAnimations` `lock(prompt)` turns the PlayerModule controls off and eases the root over 0.25 s (Quad Out, Heartbeat lerp) to 2.2 to 3.2 studs from the prompt's part, facing it; `unlock()` in `stop()`; a minigame opening locks without moving. Live: from 4.9 studs, held E: 3.20 studs, facing 0 deg off; W while held moved 0.00; after release S walked 12. InteractionAnimations 6,930 / 2625369882 |
| 3 Crouch gun | to build |
| 4 Police patrols + faction fights | to build |
| 5 Death knockback | **done** (version 72): every killing shot flings the ragdoll from the part it hit (`ShotResolver.flingRagdoll(..., hitPart, hitPosition)`: the hit part 1.6x, the body 0.75x, the torso spun by the off-centre lever; a hat or hair counts as the part it is worn on); push by weapon (`killPushFor`: Pistol 18, AutoRifle 22, Melee 20, Shotgun 55, semi-auto rifles 42, a `killPush` attribute wins). Live: AUG kill 2.0 studs (hit hand first, 24 studs/s), S&W 29 4.3 studs (head first, 36), Remington 870 12.8 studs (hit hand first, 54). ShotResolver 43,510 / 245144580 |
| 6 Duffel drop on death | to build |
| 7 Level-up GUI stuck | **done**: reproduced (a level-up, then a death: after the respawn the popup stayed at 0.88 / 0.94). Cause: `ReplicatedStorage.UI.Transitions` fades the HUD back in after the death screen and restores each element to the transparency it had when it joined the GUI; the popup joins with its template's near-visible values. Fix: `popup:SetAttribute("UITransitionIgnore", true)` before parenting (LevelingHud 13,711 / 2819421582); after the fix nothing visible after a respawn |

## Earlier request (done) (2026-11-20 late evening): bugs, interaction clips, enemy moves, takedown prompt
Verbatim: [[2026-11-20 Combat Bugs Interaction Animations Takedown Prompt]]. Six parts:
1. **Bug: Thugs freeze when shot** with health left.
2. **Bug: police stutter while chasing** ("as if they have high ping"); they must move fluidly.
3. **Bug: police never enter SlowFoods / Gas2Go** during a robbery; there should be gunfights inside.
4. **Interaction animations** other players can see.
5. **Enemies climb ledges and roll.**
6. **Silent takedown prompt** with a takedown animation.

### Answers (pickers, 2026-11-20 late evening)
- **New clips:** "Upload straight away". Make them in Blender on the OBT player rig (`Blender/Player/Player.rest.blend`) and upload to group 4998611 with `Blender/_pipeline/upload_anims.py` and `~/.roblox_key` (never print it); no preview stop; the developer reviews in game.
- **Which interactions:** "Every interaction": cash registers (stores and bank), safes, the computer hack (MasterComputer / broadcast desk), plus ATMs, deposit boxes, lockpicking doors, planting C4, picking up supplies.
- **Takedown:** "Prompt + chokehold": a ProximityPrompt "Takedown" (E / pad X / tap) on the enemy's back, only when crouched behind an unaware enemy; a paired 1.6 s chokehold (both locked, silent, the enemy goes limp). Mid-takedown spotted: "It still finishes".
- **Enemy moves** (all four): climb ledges 3.8 to 8 studs when chasing; vault walls under 3.8; roll to dodge (gun enemies, sometimes when shot, cooldown); roll to reach cover. Reuse the player's group clips `LedgeClimb` 91136281858672 and `Roll` 96743750031591 (enemies are R15).
- **Store police:** "Squads follow + a store wave": wanted squads path through the front door, and each SlowFoods / Gas2Go robbery sends a timed wave (2 officers about 60 s in, +1 every 60 s, at most 3) through the door.

### Findings (measured in Play, 2026-11-20 late evening)
- **Stutter (police and every EnemyAI):** 5 Thugs chasing (WalkSpeed 18): 13 to 35 % of chase frames under 2 studs/s, 2 to 4 stops over 0.05 s each, longest 0.82 s, mean speed 11 to 14. Cause: `_followPath` issues the next waypoint only on the 0.25 s think, and a 4-stud waypoint takes a runner 0.2 s; also the `ComputeAsync` yield with nothing issued. Network ownership is already the server's (`EnemyRig`). Fix: advance on `Humanoid.MoveToFinished`, and head straight for the goal while a first path computes.
- **Thug freeze:** AUG shots at charging Thugs: still (away from melee) at most 0.63 s, from path stalls, the 0.5 s headshot stagger (a stun with nothing visible), and the wound. The wound's kneel clip (89055632668771) plays at Action, the same priority as the Thug's two Crowbar hold clips (6170792878, 6783954162), so it blends to almost nothing: a wounded Thug stands still 6 s = "frozen with health left". Fix: kneel at Action4, a real stagger clip, the pathing fix.
- **Police in stores:** SlowFoods: `ComputeAsync` with EnemyAI's `AgentRadius` 2 = NoPath to every interior point (register, kiosks, tables, cashier); radius 1 = Success. Gas2Go: radius 2 paths in from all four sides, so police there stay out by behaviour (engaging from outside). Fix: a smaller agent radius plus the store wave entering through the door.
- `WantedService.setStars(player, 2)` at the spawn produced no squad in 40 s (no valid spawn spot near spawn?); not investigated.

### Status
| Part | Status |
|---|---|
| 1 Thug freeze | **done** [[2026-11-20 Enemy Movement and Store Police]] (no standing on the last seen spot, search sweep, kneel at Action4; the headshot stagger gets a clip with the Blender set) |
| 2 Police stutter | **done** [[2026-11-20 Enemy Movement and Store Police]] |
| 3 Police in stores + wave | **done** [[2026-11-20 Enemy Movement and Store Police]] |
| 4 Interaction clips | **done** [[2026-11-20 Interaction Animations and Takedown Prompt]] (the 5 Crime clips uploaded on the second try, ids in `Combat.Clips`, version 69) |
| 5 Enemy climb / vault / roll | **done** [[2026-11-20 Enemies Climb Vault and Roll]] |
| 6 Takedown prompt + chokehold | **done** [[2026-11-20 Interaction Animations and Takedown Prompt]] (CrimeChoke uploaded and playing) |

### Design for parts 5 and 6, and the clip set (Claude, 2026-11-20 late evening; build from this)
- **Part 5, enemy moves** (new server module `ServerScriptService.Enemy.Scripts.EnemyMoves`, EnemyAI glue; clips are the player's group clips read from `ReplicatedStorage.PlayerMovement.Animations.Roll` / `.LedgeClimb`, played on the NPC's Animator at Action4):
  - stuck detection in `EnemyAI:think`: a moving state (Chase / Search / Attack closing in) with a MoveTo goal over 3 studs away and under 1.5 studs/s for 0.6 s, then look for an obstacle within 3 studs ahead
  - the obstacle's top (a downward ray 2.5 studs ahead, from 8.5 studs above the feet): 3.8 to 8 studs up = climb (LedgeClimb clip, 1 s); 1.5 to 3.8 = vault (the same clip at 1.6x)
  - the move anchors the root and tweens it up and over, then unanchors; a `moveLockUntil` makes `think` skip the AI while it runs
  - roll to dodge: a gun enemy hit by a player in Attack or Chase, 30 % chance, 4 s cooldown, not stunned or wounded: 12 studs sideways (the side with a clear line and ground; else the other; else none), WalkSpeed 24 for 0.62 s with the Roll clip
  - roll to cover: `_maybeTakeCover` rolls to the cover spot when it is 6 studs or more away
- **Part 6, takedown prompt + chokehold:**
  - a ProximityPrompt "Takedown" (E / pad X / tap, HoldDuration 0) made on the client on the enemy's root, shown only while `CombatActions` judges a takedown possible (crouched, behind, unaware); the current hint stays for FINISH only
  - server `Finishers.request(Takedown)` then plays a paired 1.6 s chokehold: the player's clip on their character, the victim's clip on the enemy; both rooted (the player anchored, CFrame placed behind the enemy, facing the same way), the enemy stunned; the kill lands at the end ("it still finishes" if spotted)
- **Clip set (Blender, OBT player rig `Blender/Player/Player.rest.blend`, upload with `Blender/_pipeline/upload_anims.py 4998611 --prefix Crime_`, ids recorded in the vault):** RobRegister (loop), CrackSafe (loop, crouched dial), Hack (loop, typing), Lockpick (loop, crouched), PlantC4 (one-shot, kneel), PickUp (one-shot), Takedown_Attacker + Takedown_Victim (paired, 1.6 s), HitStagger (enemy headshot stagger, 0.5 s). ATMs use RobRegister, deposit boxes use Lockpick.

### Clip plan (decided while building, 2026-11-20 late evening)
- **Reuse uploaded group clips** (in `Blender/_enemies/ids.json`, group 4998611, they load in the city):
  - `Player_Choked` 84852849800147 = the takedown victim
  - `Player_Repair_Kneel` 121944371724979 + `Player_Repair_Loop` 90730140087815 = safe, lockpick, deposit boxes, C4
  - `Player_DeviceBrowse` 115684067438169 kept as a fallback for hacking
- **New clips** in `Blender/_pipeline/animate_player.py`, a section built only with `--only` like Repair:
  - `CrimeRegister` (loop, both hands grabbing from a drawer)
  - `CrimeType` (loop, typing at a desk)
  - `CrimePickUp` (one-shot squat and lift)
  - `CrimeChoke` (one-shot 48 f = 1.6 s, the attacker's chokehold from behind)
  - `CrimeStagger` (one-shot 15 f, an enemy's headshot stagger)
  - Names have no underscore (the bake loop special-cases names with one).
- **Pipeline:** back up `Player/Player.blend` as `Player.before_crime.blend`, then:
  1. `Blender -b Player/Player.blend --python _pipeline/animate_player.py -- --only CrimeRegister,...`
  2. `Blender -b Player/Player.blend --python _pipeline/export.py -- Player --anims-only`
  3. `make_rbxmx.py`
  4. `split_motor_anims.py <file> Player_Motor6D Player`
  5. `upload_anims.py 4998611 --prefix Player_Crime` (only new names go up)
- **Hook:** a client LocalScript plays the clip on the local character (it replicates) while a robbery prompt is held and while its minigame is open. Clips by the robbable object's tag:
  - registers and ATMs: CrimeRegister
  - safes, lockpicks, deposit boxes, C4: Repair_Kneel then Repair_Loop
  - the computer hack and the broadcast desk: CrimeType
  - supplies: CrimePickUp

## Previous request (2026-11-20 evening): all done except the gacha Robux products (scope)
Verbatim: [[2026-11-20 Quest NPCs Combat Stealth Gacha]]. Five parts:
1. **Police quest NPCs follow the criminals.** The developer moved the criminal Edit rigs to their designated areas; move the police quest NPCs alongside.
2. **Combat more interactive.** Propose ideas, the developer approves, then build.
3. **Hit registration bug.** Moving while hitting or shooting enemies sometimes deals no damage; the same when enemies hit the player.
4. **Crouch is stealth.** Crouched and surrounded by objects (not in the open), police and criminals see the player less; standing is more visible.
5. **Gacha.** Build the weapon gacha (decided 2026-11-20 morning: weapons come from a gacha instead of buying; no free starter gun).

Rules in force: Edit is the truth (rigs in Edit), native work only (no subagents), vault skills only, ask first in pickers then build, save after each part (never publish, never push unless asked), record everything here and in the vault.

## Status
| Part | Status |
|---|---|
| 1 Quest NPCs | **done** [[2026-11-20 Quest NPCs by Their Criminals]] |
| 2 Combat | **done**: feel (A, B, C) [[2026-11-20 Combat Feel]]; D [[2026-11-20 Smarter Enemies]]; E [[2026-11-20 Melee Combos and Block]] |
| 3 Hit registration | **done** [[2026-11-20 Hit Registration]] |
| 4 Crouch stealth | **done** [[2026-11-20 Crouch Stealth]] |
| 5 Gacha | **built** [[2026-11-20 Weapon Gacha]]; Robux products **blocked**: the Studio Assistant lacks the Open Cloud scope `developer-product:write` (asked the developer to grant it in Studio, Assistant, MCP Permissions) |

## Answers from the developer
- **Combat, feel (all four):** richer hit feedback (red hit marker on headshots, X on kills, heavier sounds, floating damage numbers); enemy hit reactions (visible flinch on every hit, stagger on headshots, close shotgun knockdown); wounded and finishers (an enemy below about 20 % may kneel for a few seconds, E for a melee finisher with bonus cash and XP, or it crawls away); stealth takedowns (crouched behind an unaware enemy, E for a silent one-hit takedown). Plus, verbatim: "Add animations if necessary for better visuals on teh combat, use the animation pipeline we built".
- **Combat, depth:** smarter enemies (criminals take cover between bursts, flank, back off when badly hurt, call nearby allies when they spot you); melee combos and block (a 3-hit combo with timing, a charged heavy swing, block or parry with a melee weapon). Not chosen: throwables, new enemy types.
- **Stealth:** "Strong": crouched among objects, noticed only within 25 studs; crouched in the open, 70; standing unchanged (criminals 120, police `SEEN_RANGE` 150); hiding near police lets the stars drain. Hidden = solid objects within 6 studs on at least 3 of 8 directions at waist height. Breaks it (fully visible for a few seconds): firing a gun (3 s; melee and takedowns stay quiet), sprinting or rolling (counts as standing), getting hit, within 8 studs and in front of an enemy. HUD: a soft dark screen vignette while hidden (no eye icon).
- **Gacha:** "Cash and Robux": cash rolls (300 a roll, 2,700 for 10) plus Robux crate keys; odds shown before buying; Robux rolls hidden where paid random items are restricted (`PolicyService` `ArePaidRandomItemsRestricted`). Weapons are no longer bought; owned weapons stay. Odds "4 rarities": Common 60 % (12 weapons up to 450 cash), Rare 28 % (11, 475 to 700), Epic 10 % (9, 750 to 950), Legendary 2 % (4, 1,050+); a `Rarity` attribute on each weapon Tool in Edit (defaults by price, the developer can change any); a 10-roll gives at least one Rare; pity: an Epic by roll 30, a Legendary by roll 100. Duplicates pay cash: Common 60, Rare 150, Epic 400, Legendary 1,000. Where: the HUD gun button's weapon panel, its buy page becomes a Crate page with a reel of weapon cards that spins and slows onto the prize, coloured by rarity.
- **Gacha, Robux (follow-up round):** keep Premium Robux keys: a key opens a Premium crate (Rare 72 %, Epic 22 %, Legendary 6 %), 49 R$ for 1, 399 R$ for 10; cash rolls keep the normal odds. Players where paid random items are restricted (`PolicyService` `ArePaidRandomItemsRestricted`) get no gacha (Roblox rule: cash can be bought with Robux, so cash rolls count as paid random items) and see the old buy page instead. Claude creates the developer products through Studio's Open Cloud tool (vault skill `roblox-open-cloud`), the developer confirming each in its dialog: the 2 key products and the 6 cash bundles in `ReplicatedStorage.Monetization.Constants` that still have `productId = 0`.
- **Quest NPCs:** edge of each area: about 80 studs from its criminals' pad, outside their 70-stud wander, on open ground facing them.

## Findings
- **Quest NPCs:** `Workspace.Quests` holds 6 police quest givers ("Level 1 Quest" Thug, "Level 10 Quest" Smuggler, "Level 20 Quest" Offender, "Level 35 Quest" Bandits, "Level 50 Quest" Disrupters, "Level 70 Quest" Saboteur; `ReplicatedStorage.Quests.QuestConfig` npcName / objectiveEnemyTemplate), in one row at z 2477.5, x -44.9 to -114.9, y 2. The developer moved the 6 criminal pads (rig and pad together): Thug (-320.2, 1.5, 2638.6), Offender (-324.4, 2.5, 2368.4), Smuggler (-90.3, 5.2, 1797.1), Bandits (980.1, 2.7, 3429.3), Disrupters (-550.9, 5.4, 1329.4), Saboteur (-46.0, 1.5, 956.0). Criminals wander `PATROL_RADIUS` 70 round their pad and notice players within `DETECTION_RADIUS` 120.
- **Hit registration (suspects, not yet measured):** `Blaster.validateShot` refuses a shot whose client timestamp is even slightly ahead of the server clock (`timestamp > now`), older than 1 s, or whose origin is more than 5 + 0.4 x speed studs from the root. `ShotResolver.validateTag` refuses a claimed hit when the target's pivot is more than atan(10 / distance) off the ray direction (at melee range a target whose centre is behind the weapon tip, e.g. when walking into it, fails), or when static geometry stops the server ray 5 studs short. NPC shots are server raycasts against the server's copy of the player, and a moving player widens the NPC aim cone by design (`movement` 5.5). To do: measure in Play with counters on each refusal reason.
- **Crouch:** `StarterCharacterScripts.Crouching` (C key, speed 8) sets `IsCrouching` on the root from the client only, so the server never sees it (RollAuthority's check reads nil). Stealth needs a server-checked crouch state (a remote, refused when moving faster than crouch speed).
- **Combat today:** hitscan Blaster with spread, recoil, headshots, a crosshair hit marker with sound, melee backstab and bleed, Baton stun, roll, crouch, sprint, ledge climb, shoulder camera; NPCs with shooter tokens, wind-up aim line, bursts, focus ramp, flinch, falloff, level armor.
- **Weapons for the gacha:** 38 Tools in `ServerStorage.Weapons`: 36 with a Price (200 to 1,300 cash: 14 AutoRifle, 12 Pistol, 8 Shotgun, Knife 350, Baton 500), Crowbar (starter, `WeaponShopService.STARTING_WEAPON`), RPG (gamepass). Shop: `WeaponShopService`, client `WeaponaryShopController` (HUD gun button). Starting cash 500.

## Notes
- Combat clips found (2026-11-20): OBT's group-owned melee set `PLAYER_SWORD` in `Documents/Roblox/studio-mirror/ReplicatedStorage/MeleeEngine/Sets.lua` (Hold 108243579707637, Slash1 127462674626273, Slash2 134523728388679, Slash3 132607297852668, Charge 103447955916892, Heavy 74911061348171; hit windows Slash1 7-13, Slash2 5-11, Slash3 9-15, Heavy 3-12 frames at 30 fps) loads in the city (same group). Use them for the combo and heavy. Hit reactions, kneel, finisher, takedown and block have no clip yet: use short stuns, the existing ragdoll, and code poses first; new clips need the Blender pipeline plus an upload (Open Cloud `asset:write`, not granted).
- Combat A done (2026-11-20): `Blaster.Scripts.GuiController` marks a body hit white, a server-confirmed headshot red (DamageIndicator isHeadshot) with a higher ding, a kill as a bigger red X (KillConfirmed) with a lower, louder sound; floating damage numbers already existed (`IndicatorClient`). GuiController 8,430 / 151342320. Verified in Play by firing the two remotes.
- Combat B done (2026-11-20): new `ServerScriptService.Enemy.Scripts.HitReaction` (3,671 / 4239444562), called from `ShotResolver.applyDamage` (38,919 / 2033886659) once per shot per NPC hit by a player: a red Highlight flash (0.12 s) and a 6 studs/s push away from the shooter; a headshot staggers (StunnedUntil +0.5 s, at most once per 1.5 s); a shotgun within 8 studs knocks down (FallingDown, stun 1.6 s, push 22, once per 3 s). Test `HitReaction_Test` (2). City 380 / 380, heist 764 / 0. Live: a Glock shot dealt 22, flashed and pushed the Thug 0.97 studs.
- Combat C design (Claude, 2026-11-20): one server module `ServerScriptService.Enemy.Scripts.Finishers` and one client `StarterPlayerScripts.CombatActions`. Wounded: an EnemyAI NPC dropped below 20 % by a player hit has a 40 % chance (once per life) to kneel 6 s (EnemyAI stunned via StunnedUntil, WalkSpeed 4 crawl away, the crouch clip 89055632668771 from Animate2, attribute `Wounded` true on the model); then it gets up. E within 8 studs of a wounded enemy = Finish. E crouched (Stealth) within 4 studs behind an enemy with no target (attribute `Aware` false, look dot toward the player below -0.5) = Takedown (silent: no expose). Remote `ReplicatedStorage.Combat.Remotes.Finish(model)`, server-checked (alive, distance, state). The kill fires Blaster's Tagged and Eliminated with the player as shooter (normal XP, cash drop, quest credit) plus a bonus (Finisher +50 % of the kill XP and a +50 % cash drop, Takedown the same). Client hint: "E  FINISH" / "E  TAKEDOWN" near the crosshair, a TextButton on touch.
- Combat C done (2026-11-20): as designed, except no crawl (EnemyAI's stun holds WalkSpeed 0; a wounded enemy kneels in place) and the takedown range is 5. Live: takedown, finish and the 40 % wound roll all verified; city 382 / 382, heist 764 / 0; version 51. Details in [[2026-11-20 Combat Feel]].
- Combat build order: A hit feedback, B hit reactions, C wounded / finishers / takedowns, D smarter enemies, E melee combos and block. Commit and save after each. A to E all done (2026-11-20 evening).
- Combat E done (2026-11-20): `Combat.MeleeRules`, `Blaster.Scripts.MeleeMoves` (server), `Blaster.Scripts.MeleeController` (client); combo x1 / x1.2 / x1.5, heavy x2 + 0.8 s stagger after holding 0.8 s past a swing, block F / L1 / touch BLOCK (-70 % front), parry in the first 0.25 s (attacker stunned 1 s, one parry per press, presses 1 s apart); OBT sword clips. City 391 / 391, heist 764 / 0; version 55. Details in [[2026-11-20 Melee Combos and Block]].
- **What is left of the request:** only the gacha's Robux products, blocked until the developer grants `developer-product:write` (Studio, Assistant, MCP Permissions). Then create the 8 products and fill `Gacha.Config.KEY_PRODUCTS` and `Monetization.Constants`.
- Combat D done (2026-11-20): new `Enemy.Scripts.Tactics` + EnemyAI glue: alert (60 studs, same faction, `_accepts`), back off below 30 % (then hold; fixed after a Play run showed it flanking back in), cover after a burst (50 %, 2 s), flank 60 to 90 degrees for later attackers; `Tactic` attribute; melee unchanged. City 387 / 387, heist 764 / 0; version 53. Details in [[2026-11-20 Smarter Enemies]].
- 2026-11-20: the universe (10777869898) had no developer products. Create with `open_cloud_invoke` POST `/developer-products/v2/universes/10777869898/developer-products` (multipart fields name, description, isForSale, price; scope `developer-product:write`): Premium Key 49, 10 Premium Keys 399, and the 6 cash bundles in `Monetization.Constants` (5,000 for 49 up to 1,000,000 for 5,999); then put the ids in `Gacha.Config.KEY_PRODUCTS` and `Monetization.Constants`. The first try was refused: scope not granted.
- 2026-11-20: `StarterGui.AdminHudGui` was found switched on in Edit (Claude left it off; the developer probably ticked it). Left as the developer set it; the game switches it on anyway.

## Design for the remaining parts (Claude, 2026-11-20 evening; build from this)
**Gacha (do next, before combat: it is self-contained; combat needs animation assets checked first).**
- Data: a `Rarity` attribute on every weapon Tool in `ServerStorage.Weapons` (Edit; defaults: Common up to 450 cash, Rare 475 to 700, Epic 750 to 950, Legendary 1,050+; Crowbar and RPG get none and are not in the pool). Config module `ReplicatedStorage.Gacha.Config`: roll price 300, ten-roll 2,700 (one Rare+ guaranteed), odds Common 60 / Rare 28 / Epic 10 / Legendary 2, Premium odds Rare 72 / Epic 22 / Legendary 6, pity Epic by 30 and Legendary by 100 (counters per player, saved in the profile), duplicate cash Common 60 / Rare 150 / Epic 400 / Legendary 1,000, Robux products: Premium key 49 R$, 10 keys 399 R$ (product ids filled after creation).
- Server `ServerScriptService.Gacha.GachaService`: `Roll(player, count, crate)` remote (RemoteFunction), validates cash or keys, draws with pity, grants through `WeaponShopService`'s grant path (owned set + profile), pays duplicates, returns the results for the reel; `PolicyService:GetPolicyInfoForPlayerAsync` `ArePaidRandomItemsRestricted` true = gacha refused and the client shows the old buy page (the existing buy path stays for those players only). Keys: a `GachaKeys` count in the profile; `MonetizationService` ProcessReceipt grants keys for the 2 new products (idempotent, like the cash bundles).
- Client: the weapon panel (`WeaponaryShopController`, HUD gun button) buy page becomes a Crate page: Roll 1 / Roll 10 (cash), Open Premium (keys) and Buy keys (Robux), odds shown on the page, a horizontal reel of weapon cards (rarity colours) that spins and eases onto the prize. GUI built in Edit (Edit rule), no text clipped, phone layout.
- Products: create the 2 key products and the 6 cash bundles (`Monetization.Constants`, productId 0) through Studio's Open Cloud tool, vault skill `roblox-open-cloud`, the developer confirming each.
**Combat (after the gacha).** Approved: richer hit feedback, enemy hit reactions, wounded and finishers, stealth takedowns, smarter enemies, melee combos and block; animations through [[Animation Pipeline]] if needed (first check which clips exist: OBT group clips, the templates' clips; uploads need the developer or Open Cloud).
- Hit feedback: server `ShotResolver` tells the shooting player each applied hit (damage, headshot, kill) through a new remote; client: damage numbers at the hit point, red hit marker on headshots, an X on kills, heavier sounds.
- Hit reactions: EnemyAI plays a hit-react clip (or a short stun from its existing stun state) on every player hit; headshot = 0.5 s stagger; a shotgun blast within 8 studs = knockdown (longer stun plus a push).
- Wounded: below 20 % health, 40 % chance an enemy kneels for 6 s (no attacks, slow crawl away); a ProximityPrompt "Finish" (server-checked range) kills it with +50 % XP and cash; else it gets up.
- Takedowns: crouched, within 4 studs behind an enemy that has no target (look dot below -0.5), prompt E: silent kill, no expose.
- Smarter enemies: between bursts move to a nearby spot with cover from the target; when another enemy already engages, take a flank point 60 to 90 degrees around the target; below 30 % health back off; on spotting a player, alert same-faction enemies within 60 studs.
- Melee: 3-hit combo (clicks within 0.6 s: damage x1, x1.2, x1.5), hold 0.8 s for a heavy swing (x2, staggers), hold F to block (front melee damage -70 %), a block started within 0.25 s before an enemy swing lands parries (stuns the enemy 1 s).

## Next (work order)
All questions are answered (2026-11-20 evening). Build in this order; after each part: tests, an Edit read-back, a batch note in `70 Batches/`, the Batch Log line, the touched system notes, this note's status, one commit, a Studio save (never publish).
1. **Hit registration:** measure first (refusal-reason counters in `validateShot` / `validateTag` during a Play run of moving while shooting and swinging, and NPC hits on a moving player), then fix the cause.
2. **Quest NPCs:** move each `Workspace.Quests` model to about 80 studs from its criminals' pad, on open ground, facing the pad.
3. **Crouch stealth:** a server-checked crouch state; detection ranges 25 / 70 / unchanged; the 3-of-8 cover rule; the four breakers; the vignette.
5. **Combat (after the gacha):** hit feedback, hit reactions, wounded and finishers, stealth takedowns, smarter enemies, melee combos and block; clips through [[Animation Pipeline]] if needed.
4. **Gacha (next):** `Rarity` attributes, the Crate page and reel, cash rolls, Premium keys, odds display, pity, duplicates to cash, restricted-player buy page, the Robux products.
