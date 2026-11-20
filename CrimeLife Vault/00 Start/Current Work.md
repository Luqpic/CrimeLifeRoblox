---
type: reference
tags: [start, in-progress]
updated: 2026-11-20
sources: ["The developer's request, 2026-11-20 evening: [[2026-11-20 Quest NPCs Combat Stealth Gacha]]"]
---

# Current Work

**Read this first after a context compaction.** It holds the request in progress, every answer the developer gave, what is done and what is next. Update it after each step. When a part is finished, it moves to a batch note in `70 Batches/` and the line here says so.

## The request (2026-11-20 evening)
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
| 1 Quest NPCs | answered, to build (step 2) |
| 2 Combat | answered, to build (step 4) |
| 3 Hit registration | **done** [[2026-11-20 Hit Registration]] |
| 4 Crouch stealth | answered, to build (step 3) |
| 5 Gacha | answered, to build (step 5) |

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

## Next (work order)
All questions are answered (2026-11-20 evening). Build in this order; after each part: tests, an Edit read-back, a batch note in `70 Batches/`, the Batch Log line, the touched system notes, this note's status, one commit, a Studio save (never publish).
1. **Hit registration:** measure first (refusal-reason counters in `validateShot` / `validateTag` during a Play run of moving while shooting and swinging, and NPC hits on a moving player), then fix the cause.
2. **Quest NPCs:** move each `Workspace.Quests` model to about 80 studs from its criminals' pad, on open ground, facing the pad.
3. **Crouch stealth:** a server-checked crouch state; detection ranges 25 / 70 / unchanged; the 3-of-8 cover rule; the four breakers; the vignette.
4. **Combat:** hit feedback, hit reactions, wounded and finishers, stealth takedowns, smarter enemies, melee combos and block; clips through [[Animation Pipeline]] if needed.
5. **Gacha:** `Rarity` attributes, the Crate page and reel, cash rolls, Premium keys, odds display, pity, duplicates to cash, restricted-player buy page, the Robux products.
