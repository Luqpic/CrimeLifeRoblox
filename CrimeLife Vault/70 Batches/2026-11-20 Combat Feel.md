---
type: batch
tags: [batch, city, combat, enemies, stealth, blaster]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 2)", "Play checks, 2026-11-20 evening", "CityMerge/after-import.md ('Combat A', 'Combat B', 'Combat C' 2026-11-20)"]
---

# 2026-11-20 Combat Feel

Part 2 of [[Current Work]], the "feel" half (steps A, B, C). The "depth" half (D smarter enemies, E melee combos and block) follows in its own note. Built natively.

## Asked for
"Improve the combating system and find ways to make it more interactive. Provide ideas, let me approve and you can work on it."
Picker, feel: all four (richer hit feedback, enemy hit reactions, wounded and finishers, stealth takedowns), plus, verbatim: "Add animations if necessary for better visuals on teh combat, use the animation pipeline we built".

## What changed
**A. Hit feedback.** `ReplicatedStorage.Blaster.Scripts.GuiController`: a body hit marks white, a server-confirmed headshot red with a higher ding (`DamageIndicator` isHeadshot), a kill a bigger red X turned 45 degrees with a lower, louder sound (`KillConfirmed`). Floating damage numbers already existed (`IndicatorClient`).

**B. Enemy hit reactions.** New `ServerScriptService.Enemy.Scripts.HitReaction`, called by `ShotResolver.applyDamage` once per shot per NPC a player hits:
- every hit: a red Highlight flash (0.12 s) and a push away from the shooter (6 studs a second)
- a headshot staggers (`StunnedUntil` + 0.5 s, at most once per 1.5 s)
- a shotgun within 8 studs knocks down (`FallingDown`, stun 1.6 s, push 22, once per 3 s)

**C. Wounded, finishers, takedowns.** New `ServerScriptService.Enemy.Scripts.Finishers` (started by the Script `FinishersServer`) and client `StarterPlayer.StarterPlayerScripts.CombatActions`:
- **Wounded.** A player's hit that leaves an EnemyAI NPC below 20 % health has a 40 % chance (once per life) to put it on one knee for 6 s: attribute `Wounded` on the model, stunned (holds fire, stays put), the crouch idle clip `89055632668771` (Animate2's) looped. Then it gets up.
- **Finish.** Within 8 studs of a wounded enemy the hint shows "E  FINISH".
- **Takedown.** Crouched (server-side `Stealth.isCrouched`) within 5 studs behind an enemy (its look against the direction to the player at most -0.5) that has no target: "E  TAKEDOWN". Silent: no stealth breaker fires.
- **Input.** E, gamepad X, or a tap on the hint (touch shows the word only) fires `ReplicatedStorage.Combat.Remotes.Finish(model, kind)`. The server checks everything again (enemy tag, alive, range, wounded or crouched-behind-unaware, 0.4 s between requests).
- **Reward.** The kill fires Blaster's `Tagged` and `Eliminated` with the player as the shooter, so XP, the cash drop and quest credit come as for any kill. On top, +50 % of the kill's XP (`Admin.Hooks.killBonus`, in `LevelingService`) and of its cash drop value, credited at once (`Admin.Hooks.cashBonus`, in `CashService`).
- **Enemies can be snuck up on.** `EnemyAI` publishes `Aware` (true while it has a target). `_findVisibleTarget` no longer sees a crouched player behind it (its look against the direction to them below 0). Before this, enemies saw all round, so a takedown could never happen.
- **GUI in Edit:** `StarterGui.CombatHint` (ScreenGui) with the `Hint` TextButton (200 x 40, hidden until a finish or takedown is possible).
- New test `Finishers_Test` (2): `isBehind` cases; a model that is not a tagged enemy is refused.

## Decisions
- **No crawl.** The design had a wounded enemy crawl away at speed 4. EnemyAI's stun branch sets WalkSpeed to 0 every think and cancels moves, and the kneel clip is an idle, so a crawl would glide. A wounded enemy kneels in place.
- **No new clips yet.** Hit reactions use a flash, a push and the existing stun and `FallingDown`; the kneel reuses Animate2's crouch idle; finishers and takedowns are instant kills. Dedicated clips (hit react, finisher, takedown) need the [[Animation Pipeline]] and an upload (Open Cloud `asset:write` is not granted). E's melee combo and heavy will use OBT's `PLAYER_SWORD` clips, which already load in the city.
- The takedown range is 5 studs (the design said 4); the test stood the player 4 studs behind.

## Verified (Play)
- A: the two remotes fired at the player: a kill marks a 45-degree red X, a headshot a red marker; no errors.
- B: a Glock shot dealt 22, flashed and pushed a Thug 0.97 studs.
- C takedown: player crouched 4 studs behind an unaware Saboteur (130 HP), hint "E  TAKEDOWN" (450, 336, 200 x 40), E: Saboteur 0 HP; XP 25 + 20 kill + 10 bonus crossed level 1 to 2; cash +50 (25 level-up, 25 bonus).
- C finish: an Offender (90 HP) flagged wounded, player 6 studs in front, standing: "E  FINISH", E: 0 HP, XP and cash paid (level 2 to 3).
- C wounded: 8 enemies at 15 % health hit through the real `Tagged` event: 3 knelt (the 40 % roll), the kneel clip playing, stunned 5.5 s; 6 s later `Wounded` cleared, the clip stopped, the enemy walked again (WalkSpeed 12).
- C refusals seen live: once shot, the client stood up and the enemy turned `Aware`, so no hint and no request reached the server.
- City 382 / 382 / 0 (from a temporary Script in the live server); heist 764 passed / 0 failed. Edit read-back: all 8 changed scripts match their mirrors byte for byte (length and Adler-32), the `Finish` remote and `CombatHint` are in Edit.

## Trap found
Running the city suite from `execute_luau` in Play reported 5 false failures in `ProfileAdoption_Test` (quest and cash hydrators "expected true, got nil", "expected 1300, got 800"): that context's `require` gets a fresh `ProfileGateway` whose hydrator list is empty, because the Script services registered theirs in the live server's copy. The same suite from a temporary Script: 382 / 382. [[Unit Test Runner]]

## Not verified
- Phones (the touch hint is a TextButton; not tapped on a device) and a gamepad X press.
- The heist police and guards: they run on EnemyAI, so takedowns and wounds apply to them too; not tried in a robbery.

## Left open
- Clips for hit reactions, finishers and takedowns (needs `asset:write` or the developer's upload).
- A level-up still fully heals mid-fight (older open item); a finisher that levels the player up heals them.

## Saved
Studio saved to Roblox (version 51, Save, never Publish). NOT published. Nothing pushed.

## Links
[[Enemies and Spawner]] · [[Weapons and Blaster]] · [[Movement and Stamina]] · [[Leveling and Renown]] · [[Economy and Cash]] · [[2026-11-20 Crouch Stealth]] · [[Current Work]]
