---
type: batch
tags: [batch, npc-ai, police, combat, animation, robbery, ui]
updated: 2026-11-20
sources: ["90 Reference/Original Prompts/Tycoon/2026-11-20 Smooth Enemies Action Lock Crouch Gun Police Patrols Ragdoll.md", "CityMerge/after-import.md (2026-11-20 late night blocks)", "git log of Luqpic/CrimeLifeRoblox (5d50c4b to this batch)"]
---

# 2026-11-20 Smooth Enemies Patrols and Dropped Duffels

Crimelife City, cloud place "Crimelife Tycoon". Saved as place versions 70 to 78, never published.

## Asked for
The developer's late-night request (verbatim: [[2026-11-20 Smooth Enemies Action Lock Crouch Gun Police Patrols Ragdoll]]), seven parts:
1. Enemies jitter and lag while running, chasing and shooting: smooth them.
2. Robbery actions: tween the player into place and fix them there, no sliding about.
3. Crouching with a gun points the gun down: a fitting pose.
4. Police patrol the city at random; police and criminals fight when they see each other.
5. The killing shot knocks the body back from the part last hit (a headshot kill: the head first).
6. Added mid-turn: a player who dies drops the duffel bag, which other players or they themselves can carry.
7. Added mid-turn: the level-up GUI sometimes stays stuck on the screen.

Picker answers: patrols "6, also chase wanted"; death push "By weapon"; crouch "The gun's own hold"; action lock "Locked until it ends"; duffel "2 minutes" and "Anyone".

## What changed
- **1 Smooth enemies** (`Enemy.Scripts.EnemyAI`, version 70). Measured cause: a moving shooter snapped its facing 12 to 55 degrees a frame, AutoRotate turning it toward the walk and `_faceTowards` snapping the root back to the target four times a second. Now each enemy has a `FacingAttachment` and an AlignOrientation `Facing` (OneAttachment, Responsiveness 30, MaxTorque huge); in Attack `_faceTowards` sets its target and turns AutoRotate off; `_releaseFacing()` on leaving Attack, when stunned and in `_enterDead` (an enabled Facing would hold a ragdoll upright).
- **2 Action lock** (`StarterPlayerScripts.InteractionAnimations`, version 73). Holding a robbery prompt: the PlayerModule controls go off and the root eases over 0.25 s (Quad Out, a Heartbeat lerp) to 2.2 to 3.2 studs from the prompt's part, facing it; an open minigame locks without moving; `stop()` (letting go, the minigame closing, respawn) gives the controls back.
- **3 Crouch keeps the gun hold** (`StarterCharacterScripts.Crouching`, version 74). Cause: the crouch clips (idle 89055632668771 at Action2, walk 107107589904731 at Action3) pose the whole body above Blaster's hold (`Idle` 6170771161 at Action: arms, UpperTorso, Head). While a Tool is held both crouch clips drop to Movement (`setCrouchPriority`, their own priority read once loaded); `Movement` already steps aside while crouched, so nothing else is under them. Without a tool, nothing changes.
- **4 Patrols and faction fights** (version 77).
  - New `ServerScriptService.Wanted.PolicePatrols` (started by `WantedRunner`; numbers `Wanted.Constants` `PATROL_*`): 6 loose Police (`PoliceDispatcher.spawnLoose`, attribute `Patrol`). Each stands up on road or footpath ground 120 to 300 studs from a random player, out of every player's sight and with a path to that player. The dispatcher's `_findSpawn` now also runs without a player or a budget, and patrols pass the player plus a budget of 4 path checks.
  - They walk legs to road points 60 to 200 studs away (a new leg on arrival or after 60 s). A replacement comes 30 s after a death; one 600+ studs from every player and unseen is recycled near a player at once.
  - A wanted player whom the police believe within 250 studs (`PoliceDispatcher.believedPosition`, the squads' own rule) draws them in (`investigate`). They share `POLICE_CAP`.
  - `EnemyAI`: a target is a Player or a hostile NPC's character Model (`characterOf`, `_hostileTo` by the models' `Faction`: Police against Criminal). `_findVisibleTarget` lets a hostile NPC in sight compete with players on distance; `_accepts`, `_targetHumanoid`, `_isTargetDead`, `_alertAllies` and `onDamagedBy` take either; a dead NPC's shooter tokens are cleared.
  - `Blaster.Utility.canDamageHumanoid`: an AI shot hurts the other faction, never a `WitnessRole` Guard. NPC-on-NPC kills pay nobody (cash, XP, quests, heat and spray all need a Player shooter).
- **5 Death knockback** (`Blaster.Scripts.ShotResolver`, version 72). Every killing shot calls `flingRagdoll(humanoid, direction, killPushFor(weapon), bodyPartOf(hit), hitPosition)`.
  - The hit part moves at 1.6x the push, the rest of the body at 0.75x, and the torso spins by the off-centre lever (`HIT_SPIN` 0.06). A hat or hair counts as the part it is worn on.
  - Push by weapon: Pistol 18, AutoRifle 22, Melee 20, Shotgun 55, semi-auto rifles (M14 EBR, HK G3) 42, default 20. A weapon's `killPush` attribute wins.
- **6 Dropped duffels** (version 78).
  - New `ServerScriptService.Heist.Services.DuffelDrop`, called from the `Died` handlers of `LocationServer` (SlowFoods, Gas2Go, NewsStation) and `HeistServer` (the Bank) after `Forfeit:Die(..., "died")`. The bag model (`HeistShared.DuffelBag`, anchored, no collision or query) lies on the floor where they fell, with a "Pick up bag" prompt (hold 0.5, 8 studs, the amount as ObjectText). It stays `HeistShared.Config.DroppedBagSeconds` 120, or less if that run ends first.
  - A living player who picks it up joins the robbery (`AddParticipant`, which also clears their forfeit latch) and gets the cash in their own bag over the cap (`AddBonus`, in grants of at most `MaxBagGrant`). The location's getaway then banks it as usual, and a later death drops it again. The owner gets "Your bag dropped where you fell. Get it back within 2 minutes."; the picker gets "Picked up N Cash. Get clear to bank it."
  - The pick-up plays the `PickUp` clip (InteractionAnimations, "pick up").
- **7 Level-up popup stuck** (`StarterPlayerScripts.LevelingHud`). Cause: `ReplicatedStorage.UI.Transitions` records each element's resting transparency when it joins a bound GUI and restores it after the death screen switches the HUD off and on; the popup joined with its template's near-visible values. Fix: `popup:SetAttribute("UITransitionIgnore", true)` before parenting.

## Decisions
- Patrols are loose officers on the shared EnemyAI and the police cap; they answer a wanted player only within 250 studs of where the police believe them, so a 1-star player is not swarmed by all six.
- Police and criminal NPCs fight by `Faction`; heist guards stay out of NPC fire; NPC kills pay no one.
- A dropped bag belongs to that run: its picker joins the robbery and banks through the normal getaway; the bag goes with the run's end.
- The crouch with a tool is legs-only by priority, not a new clip.

## Verified
In Play, by property read-back (no recordings):
- **1:** client-side, facing snaps over 12 degrees a frame on 10 of 10 moving frames (up to 55) became 0 (max 4); chasing Thugs ran 16.5 to 17.6 of 18 studs/s with 0 to 1 stalls in 11 s.
- **2:** from 4.9 studs, held E: 3.20 studs from the register, facing it 0 degrees off; W while held moved 0.00 studs; after letting go, S walked 12.
- **3:** AUG, crouched: barrel pitch -20 degrees and 46 degrees to the side before, 0 and 2 after (standing 8 and 2), idle and crouch-walking at 8 studs/s (`Idle@Action`, `CrouchWalk@Movement`); the Crowbar keeps its hold; no tool: `Crouching@Action2`, head 0.55 above the root (whole-body crouch as before).
- **4 Patrols:** all 6 stood up within 1 s of the player loading (270 to 306 studs away) and walked legs at 12 studs/s (167 and 261 studs in 20 s). Before the spawn fix it took 34 s for 5.
- **4 Faction fights:** an officer put 40 studs from Offenders: both sides in Attack at once, the Offender hit (90 to 82), the officer killed in 4 s. Patrols fought gangs on their own (73 and 87 hp, one killed).
- **4 Wanted:** with 2 stars and seen, a patrol at 256 studs went to Search and closed in (241, 203, 165); 0 warnings or errors.
- **5:** AUG kill 2.0 studs (hit part first at 24 studs/s); S&W 29 kill 4.3 studs (head first, 36); Remington 870 at 4 studs launched 12.8 studs (54).
- **6:** SlowFoods register, 2,000 in the bag, death: the bag lay 1.4 studs from the death spot on the floor (y 1.63 floor, centre +1.05) with "Pick up bag / 2000 Cash". After the respawn (2.3 s) the player picked it up (E 0.9 s): it left the ground and was on their back. At 230 studs out, cash went 7,421 to 9,421 (+2,000) 0.3 s after arriving. Gas2Go: an unclaimed 2,000 bag was gone after 121 s.
- **7:** reproduced (a level-up, then a death: after the respawn the popup stayed at 0.94 / 0.88); with the fix nothing is visible after a respawn.
- **Tests:** `FactionFights_Test` (3) and the heist `DuffelDropSpec` (3) are new. City 397 / 397 (from a temporary Script), heist 767 / 0.

## Not verified
- How other players see the crouch priority change, the action lock and a picked-up bag (needs the developer's 2-player test).
- Another player (not the owner) picking up a dropped bag in a live game; the Bank and NewsStation drops (same code path as SlowFoods and Gas2Go, not run live).
- Patrols with several players spread over the map; their cost with 24 gang NPCs over a long session (no profiler run).

## Left open
- The gacha Robux products still wait for the developer's approval of `open_cloud_invoke` (see [[Current Work]]).
- A dropped bag in the Bank vault can only be reached by players who get into the vault.

## Links
[[Current Work]] · [[Enemies and Spawner]] · [[Police and Wanted]] · [[Robbery Heists and Getaway]] · [[Character Movement and Animation]] · [[Weapons and Blaster]] · [[Leveling and Renown]] · [[Physics and Character Traps]] · [[UI Layout Traps]]
