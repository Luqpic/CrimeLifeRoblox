---
type: batch
tags: [batch, city, combat, melee, animation]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 2, depth)", "Play checks, 2026-11-20 evening", "CityMerge/after-import.md ('Combat E, melee combos and block 2026-11-20')"]
---

# 2026-11-20 Melee Combos and Block

Part 2 of [[Current Work]], step E, the last combat step. Follows [[2026-11-20 Smarter Enemies]]. Built natively.

## Asked for
Picker, combat depth: "Melee combos and block" (a 3-hit combo with timing, a charged heavy swing, block or parry with a melee weapon). Plus, from the feel round: "Add animations if necessary for better visuals on teh combat, use the animation pipeline we built".

## What changed
Applies to every melee weapon: Crowbar, Knife, Baton (all swing every 0.667 s).
- **Combo.** A press swings at once. A press within the cooldown plus 0.6 s of the last swing is the next step: x1, x1.2, x1.5, then it starts over. The server keys it on the swings' own validated timestamps (`Blaster.onShootEvent` → `MeleeMoves.onSwing` → `resolveShot{damageMultiplier}`), so latency cannot add a step.
- **Heavy.** Keep holding after a swing: once the cooldown ends the weapon coils, and the client sends `Combat.Remotes.MeleeCharge` with that swing's timestamp. The server accepts only the last swing's timestamp. Let go 0.8 s or more after the swing for a heavy: x2, and it staggers what it hits for 0.8 s (`StunnedUntil` + `RagdollController.stagger`); the combo starts over. Let go sooner and the coil is dropped (`MeleeCharge(false)`).
- **Block.** Hold F, gamepad L1 or the touch BLOCK button while holding a melee weapon (`Combat.Remotes.Block`, `Blocking` attribute on the character).
  - A melee hit from the front half takes 30 %, with no stun and no bleed.
  - **Parry:** a hit within 0.25 s of the block starting does nothing and stuns the attacker 1 s (NPC or player). Each block press can parry once, and only if it started at least 1 s after the previous press, so tapping F cannot keep the window open.
  - From behind, a block does nothing.
  - Applies to NPC melee (Thugs, Security batons) and to PvP.
- **Animations** (OBT's `PLAYER_SWORD` set, group-owned, already in the city; no new uploads needed):
  - `Slash1`, `Slash2`, `Slash3` for the combo steps
  - `Charge` looped while coiling, `Heavy` on the heavy
  - `Hold` looped as the guard while blocking
  - All at `Action4` on the player's own character (they replicate). Preloaded on equip; without that, the first Charge and Heavy played before the clip had downloaded.
  - First person keeps the procedural viewmodel swing.
- **Code.**
  - New `ReplicatedStorage.Combat.MeleeRules` (numbers and pure rules), `ServerScriptService.Blaster.Scripts.MeleeMoves` (server state, remotes, `defend`, stuns) and `ReplicatedStorage.Blaster.Scripts.MeleeController` (client, one per melee weapon, owned by its `BlasterController`).
  - `BlasterController`: stamps `lastShotTime`, routes press and release to the melee controller.
  - `Blaster`: passes the swing's multiplier and heavy flag.
  - `ShotResolver.applyDamage`: block and parry once per swing per victim, the multiplier, the heavy stagger, no stun or bleed on a blocked hit.
- **In Edit:** remotes `ReplicatedStorage.Combat.Remotes.MeleeCharge` and `.Block`; `BlockButton` in `TouchInputController.BlasterTouchGui.Buttons` (a VIEW button copy, 100 x 100 at the RELOAD spot, hidden; a melee weapon shows it and hides RELOAD).
- New test `MeleeMoves_Test` (4).

## Verified (Play, real mouse and keyboard)
- **Combo** (Crowbar, damage 45, 6 rays, on a pinned 5,000 HP Thug copy): 45, 54, 67.5, then 45 (wrapped), and 45 after a 2.5 s gap. Unpinned, the Crowbar's knockback threw the target to 10 studs after two swings, out of its 6-stud reach.
- **Heavy:** held 1.2 s: a light 45 at the press, `MeleeCharge` with that swing's timestamp 0.68 s later, 90 on release, the target stunned until the hit + 0.8 s. Clips logged: Slash1, Charge, Heavy, and Hold while blocking.
- **Block** (a Thug copy's Crowbar driven through the live `ShotResolver` by a temporary Script, the player level 3):
  - unblocked: 44.64 (6 x 7.44)
  - hit the moment `Blocking` turned on: 0, attacker stunned 1.00 s
  - 0.5 and 0.8 s into the block: 13.39 (6 x 2.23, x0.30)
  - a second press 1.8 s after the first: parried again (re-arm counts from the last press's start)
- **Touch:** the Crowbar's touch GUI shows BLOCK and hides RELOAD; the guns keep RELOAD.
- All six clips fetched on equip (`AssetFetchStatus` Success).
- City 391 / 391 / 0 (temporary Script); heist 764 passed / 0 failed. Edit read-back: the 7 scripts match their mirrors (length and Adler-32); the remotes and `BlockButton` are in Edit; no test leftovers.

## Not verified
- One early block run read 15.6 for a hit 0.6 s into the block, one ray's worth (2.2) above 13.4. The logged rerun gave exactly 13.39 twice; the extra was not reproduced or explained.
- Gamepad L1 and a phone tap on BLOCK (no device here); the heavy and the parry against a live Thug's own swing timing; how the sword clips look holding the Knife and Baton.

## Left open
- Block has no sound or flash of its own; the visible cues are the guard pose and the attacker's stagger.
- F also opens the SlowFoods key prompt near it (that prompt takes the key there).

## Saved
Studio saved to Roblox (version 55, Save, never Publish). NOT published. Nothing pushed.

## Links
[[Melee]] · [[Weapons and Blaster]] · [[Character Movement and Animation]] · [[2026-11-20 Combat Feel]] · [[2026-11-20 Smarter Enemies]] · [[Current Work]]
