---
type: batch
tags: [batch, city, heists, police, bank, guards, npc-ai, rules]
updated: 2026-11-20
sources: ["The developer's morning message and picker answers, 2026-11-20", "CityMerge/after-import.md ('Walking Bank guards and Edit rigs 2026-11-20')", "git log a0263ad..HEAD"]
---

# 2026-11-20 Walking Bank Guards and Edit Rigs

The morning after the three night batches ([[2026-11-20 Heist Police and Bank Guards]], [[2026-11-20 Readable Gunfights and Level Toughness]]). Built natively by Opus in the main thread (no subagents, the developer's new rule). Cloud place "Crimelife Tycoon" (placeId 128488619644399).

## Asked for
The developer, 2026-11-20 morning (verbatim, typos kept):
> "Reuse teh OBT rule whereby everything happening in edit mode is the last source of truth. Every changes must also happen in edit mode, for example if you added enemies during the gameplay, I also need to see teh enemies in edit mode so I am aware of their location. Likewise for GUIs too. Ensure no GUIs is cut, I saw the admin panel and some of the buttons were cut. But for now, leave it, as we will revamp the GUI in the future. I think we should go native since the usage was too much."
> "For the armed polices, I suggest them to just stay at teh upper level of teh bank, only teh normal polices come to teh vault, this is because I don't want it ot be overcrowded in teh vault. The police and security that was replaced as a dummy didn't move at all bu tthey still attack. Polices also spawn right after the obby pit so players can have a gun fight while stayong inside of the money vault"
> "Pay should start after robbery. NO free gun, actually I want to revamp the weaponary. Instead of buying, we are doing gacha."

Picker answers: guards "Patrol, then cover"; police sides "Split each wave"; guard pay "Only during a robbery"; Edit view "Real rigs".

## What changed

### Rules
- [[Verify in Edit and by Screenshot]]: Edit is the last source of truth, and anything spawned in Play is also visible in Edit (rigs on markers).
- [[Vault Skills Only and Model Routing]] and [[Model Assignment]]: work native, no subagents unless the developer asks.
- [[GUI Rules]]: no GUI is cut. The admin panel's cut buttons wait for the GUI revamp.

### Edit rigs (new `ServerScriptService.Heist.EditRig`)
- `EditRig.take(marker, lift)`: a marker's Model child is the NPC the developer sees in Edit. On the server the marker moves to the rig (its pivot, less `lift`) and the rig leaves the world.
- 20 rigs placed in Edit, one undo step ("Bank Edit rigs and police spawns"): the Bank's 4 guards (posts 1 and 3 Security, 2 and 4 Police), NewsStation's 3 Police guards, a Police rig on each of the Bank's 3 old and 3 new police spawns, an Armed Police rig on each of the 4 lobby spawns, a Police rig on NewsStation's 3 spawns. Roots anchored in Edit; the weapon placed in the right hand.
- A guard is built from its post's Edit rig (`EnemyRig.build(rig, rig.Name)`), so swapping the rig in Edit swaps the guard. Without a rig the post falls back to `Config.GuardTemplates` by name.

### Guards walk
- Roots are no longer anchored. Clips: EnemyAI's idle, walk or run choice (`EnemyAI._updateLocomotionAnimation` on a small state table).
- Outside a robbery (no provocation): a beat round the post, a point within 8 studs at walk speed 6, then a 3 to 6 s pause. A point with no path is skipped.
- Engaged (the robbery runs, or a player hurt it): full speed. A gun guard runs to its claimed `HeistCoverPoint` (NewsStation has none: back to its post) and fires only while standing. A Security guard (Baton) goes straight for its target while the target stays within 20 studs of its post, else walks back (Claude's ruling: cover is no use to a melee guard).
- A walk is one path per goal, computed off the update thread, then its waypoints in turn; it ends within 2 studs or after 10 s. A guard in cover computes no more paths (the old code recomputed every second).

### Police sides
- `HeistPolice.markersIn(folder, prefix)`; new Bank markers `HeistPoliceInnerSpawn1..3` after the obby pit, between the glass wall and the money-vault corridor ((1350, -94.5, 2548), (1382, -94.5, 2548), (1366, -94.5, 2551); the last one has a clear line from inside the vault).
- The timed plan takes the two sides in turn (before the pit, after it, before it, ...). Steering is per side, one side a tick.
- The armed plan stands at `HeistPoliceUpperSpawn1..4` in the lobby ((1255, 13.4, 2340), (1230, 13.3, 2340), (1240, 13.3, 2300), (1210, 13.4, 2320), facing TeleporterBankA). It fights only robbers in the Lobby zone, patrols at most 12 studs (`HeistPoliceVault.patrolRadius`, read by EnemyAI as `ai.patrolRadius`), and is never steered. Robbers leave the vault through TeleporterBankB to the lobby, so they meet them on the way out.

### Guard pay
- GuardPost sets `NoKillReward` on its guard outside a robbery. CashService, LevelingService (XP; the kill toast stays), QuestService and SpraypaintService skip such a body.

## Verified
- Tests: city 366 / 366 / 0; heist 764 passed / 0 failed (4 new cases: Edit rig as template, pay and patrol, markersIn prefix and rig, two sides plus the armed plan).
- Edit: 20 rigs read back on their markers (feet on the floor: posts -117.99 over a -118.00 floor; inner spawns -97.69 over -98.00), screenshots of the after-pit room. After Play the rigs are still in Edit.
- Play: 0 rigs left on markers at boot; 7 guards unanchored, walking 3.6 to 7.6 studs in 12 s at speed 6 with walk clips; `NoKillReward` true outside a robbery.
- Pay: an Eliminated fire on a Security guard outside the robbery gave XP 15 to 15; the same body without the flag 15 to 25.
- Robbery started by walking into the lobby with a Glock: pay flag cleared within 0.1 s; both Police guards reached their claimed cover points (0.1 and 0.2 studs off); speeds back to 12 and 10.
- 2:00 wave: 3 Police, one at the old spawn, one 0.8 studs from `HeistPoliceInnerSpawn1`, one at the old side again.
- Guard room, player standing still in the open for 10 s: 178 HP lost (Police 17 hits of 6 from cover; the near Security guard closed 9.4 studs and swung about 5 times; the far one stayed outside its leash). No errors or guard warnings in the log.

## Not verified
- The armed wave live: the vault door prompt did not fire from the test (a client `InputHoldBegin` and a real E hold; the teleported player was likely not a participant). The plan is covered by the spec; the wiring by the boot read-back.
- Two players, a phone, NewsStation guards in a robbery.

## Left open
See [[Open Items]] (Walking guards and Edit rigs).

## Saved
Studio saved to Roblox (Save, never Publish) after the tests. NOT published. Nothing pushed.

## Links
[[Robbery Heists and Getaway]] · [[Police and Wanted]] · [[Economy and Cash]] · [[Enemies and Spawner]] · [[Robbery Decisions]] · [[Economy and Progression Decisions]] · [[Vault and Documentation Decisions]]
