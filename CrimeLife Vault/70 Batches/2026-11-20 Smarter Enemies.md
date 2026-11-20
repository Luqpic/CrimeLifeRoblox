---
type: batch
tags: [batch, city, combat, enemies, npc-ai, police]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 2, depth)", "Play checks, 2026-11-20 evening", "CityMerge/after-import.md ('Combat D, smarter enemies 2026-11-20')"]
---

# 2026-11-20 Smarter Enemies

Part 2 of [[Current Work]], step D of the combat "depth" half. Follows [[2026-11-20 Combat Feel]]. Built natively.

## Asked for
Picker, combat depth: "Smarter enemies" (criminals take cover between bursts, flank, back off when badly hurt, call nearby allies when they spot you), together with "Melee combos and block" (step E, next).

## What changed
- New `ServerScriptService.Enemy.Scripts.Tactics`: the pure geometry and numbers (`shouldBackOff`, `backOffPoint`, `flankPoint`, `findCover`, `inAlertRange`).
- `EnemyAI` uses it in four places. It applies to every EnemyAI enemy: criminals, street police, heist police.
  - **Alert.** When an enemy takes a target it had none for, every enemy of its faction (template attribute `Faction`, else `config.faction`) within 60 studs that has no target, and may fight that player (`_accepts`, so the bank's armed police only answer for players they may target), investigates the player's position. It must still see the player to fight.
  - **Back off.** A gun enemy below 30 % health backs away 10 studs a think while it keeps firing, until it is 0.9 of its engage range away, then holds there. It never flanks or closes in again.
  - **Cover.** After a burst that fired, a gun enemy that is not hurt has a 50 % chance to look for cover: 8 directions on rings of 6 and 12 studs, a point the target cannot see at chest height (`Stealth.solidCast`, now public), reachable in a straight line, with ground under it. It goes there for 2 s, neither shooting nor chasing. Then the usual sight check sends it to Chase, which brings it out to shoot after a fresh wind-up (the red aim line).
  - **Flank.** When another enemy entered Attack on the same target earlier, a gun enemy takes a point 60 to 90 degrees round the target from that enemy (side picked once per Attack), at its current distance (10 studs up to its preferred range). The first attacker holds its line. An enemy that leaves Attack (cover, lost sight) and comes back is a later attacker, so the roles rotate.
- Melee enemies (Thugs) keep rushing: no back-off, cover or flank.
- `EnemyAI` publishes attribute `Tactic` on the model (`Cover`, `Flank`, `BackOff`, or none) next to `AIState`, so Studio shows what each enemy is doing.
- New test `Tactics_Test` (5).

## Decisions
- Back off holds at range instead of flanking back in: the first build let a hurt enemy back off to 78 studs and then switch to Flank, whose point sits at the preferred range, so it would have walked back in (seen in Play, fixed before saving).
- Cover is a chance, not every burst, so fights keep their pace; open ground gives no cover and the enemy just holds.

## Verified (Play)
- **Alert:** 3 Offenders, the player shown to one: both allies (45 and 53 studs away) went Patrol to Search at the spotter's exact moment, then Chase and Attack.
- **Flank:** with all three attacking, the two later ones stood at 62 and 75 degrees round the player from the first (22 studs); 18 hits on the shielded player in 8 s.
- **Cover:** open ground: `findCover` found nothing for any of the three (correct). With a temporary wall beside the first attacker (Play only, gone after): after a burst it went to Cover, hidden from the player for about 2 s, then Chase, then Attack.
- **Back off:** an Offender in Attack at 15 studs set to 25 % health: 21, 27, 33 ... 77, 82 studs, then held at 82 (BackOff) for 3 s.
- **Melee:** a Thug at 25 % health stayed in at 2 studs, Attack, no tactic.
- City 387 / 387 / 0 (temporary Script); heist 764 passed / 0 failed. Edit read-back: the 4 scripts match their mirrors (length and Adler-32); no test leftovers in Edit.

## Not verified
- Heist police in a real robbery (they run the same AI; the alert respects their target filter).
- Server cost under a full city of fights: cover adds at most 48 rays after a burst (when the 50 % roll passes); flank scans the live enemies once per Attack think.

## Left open
- `findCover` checks only a straight walk to the spot; a spot round a corner the enemy cannot walk to directly is skipped.
- Back-off and cover moves use a direct `MoveTo` (like `_sidestep`), with no ledge check.

## Saved
Studio saved to Roblox (version 53, Save, never Publish). NOT published. Nothing pushed.

## Links
[[Enemies and Spawner]] · [[Police and Wanted]] · [[Movement and Stamina]] · [[2026-11-20 Combat Feel]] · [[Current Work]]
