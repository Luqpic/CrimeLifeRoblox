---
type: batch
tags: [batch, city, combat, blaster, bug]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 3)", "Play measurements, 2026-11-20 evening", "CityMerge/after-import.md ('Hit registration 2026-11-20')"]
---

# 2026-11-20 Hit Registration

Part 3 of [[Current Work]]. Built natively.

## Asked for
"Soemtimes when I move while hitting the enemies, or shoot teh enemies, the damage isn't registered. Likewise when they try to hurt me too."

## Measured (before)
A server listener on `Blaster.Remotes.Shoot` re-ran every check on each shot (timestamp, origin distance, fire interval, `validateTag` per claimed hit) and counted the `Tagged` events that really landed. Input through `user_keyboard_input` (W held) and `user_mouse_input` (clicks), target a static enemy-tagged rig.
- Standing, Glock 17: 8 shots, 8 claimed, 8 landed.
- Walking forward while shooting: 10 shots, 8 hits claimed by the client, **6 landed**. Both refusals came from `ShotResolver.validateTag`'s angle rule: the target's pivot was 71 and 73 degrees off the ray at 4.9 and 7.0 studs, over the allowed atan(10 / distance) = 64 and 55 degrees. No timestamp, origin or fire-interval refusals.
- Enemies on a moving player: a Crowbar Thug swung 16 times and every swing landed (96 ray hits). An Offender fired 30 shots: 16 bullets crossed the player's body on the server and 14 did damage; the 3 mismatches seen in a second run all went through an **accessory** (`Handle` of hair, a hat, a coat collar) and on into a building. 13 of 50 shots were near misses passing within 2.5 studs of the torso.

## Cause
- **Player hits:** `validateTag` refused a claimed hit when the angle from the ray to the target's pivot exceeded atan(10 / distance). Far away that is "within 10 studs of the aim line"; up close the angle grows fast, so a hit on a body's edge, or on an enemy the player walks into, was refused while the client had already shown the hit marker.
- **Enemy hits:** no server fault. `Blaster.Scripts.AccessoryFiltering` (from the Blaster template) tags every player accessory and tool part `RayExclude`, so bullets pass through hair, hats and coats without counting; together with grazing near misses this reads as "they hit me but nothing happened".

## What changed
- `ServerScriptService.Blaster.Scripts.ShotResolver.validateTag` (first mirror): the ray must pass within `DIRECTION_BUFFER_CONSTANT` (10) studs of the target's pivot **measured sideways from the ray**, with the pivot at most `BEHIND_BUFFER_CONSTANT` (3) studs behind the ray's start. The wall check is unchanged.
- New test `ServerStorage.UnitTest.Cases.ValidateTag_Test`: the measured close case (4.9 studs, 73 degrees) passes; 9 studs aside at 100 passes, 11 does not; 5 studs behind does not.

## Verified
- Walking into a normal-size enemy while swinging the Crowbar: 8 swings, 6 claimed, **6 landed**, no refusals.
- City 370 / 370 / 0 (test player shielded); heist 764 passed / 0 failed.

## Left open
- Enemy bullets through a player's hair, hat or coat do not count (template rule, kept: big accessories would otherwise grow a hitbox). The combat batch's hit feedback should make real incoming hits obvious.
- Test artifact: an anchored, scaled-up test rig counts as a wall for the occlusion check (`castRays` static mode skips only `NonStatic` parts); use normal-size rigs for hit tests.

## Saved
Studio saved to Roblox (Save, never Publish). NOT published. Nothing pushed.

## Links
[[Weapons and Blaster]] · [[Melee]] · [[Enemies and Spawner]] · [[Current Work]]
