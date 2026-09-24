# Change Log: RPG — Gamepass Rocket Launcher, Explosive Rounds, Gamepass Tab

**Date:** 2026-09-24
**Status:** Applied — shop, gamepass lock, claim, first person, explosion, fling, knockback and reload all
verified live in play. The place is not saved to disk by this change.

## Summary
The RPG model in the Workspace is a working weapon, unlocked by a gamepass rather than bought with Cash.
It fires one rocket per 3 s reload, and the rocket flies visibly to where it lands and explodes:

- 200 damage at the centre, falling to 60 at the 16-stud rim.
- Everyone caught takes damage: enemies and other players, but never the shooter.
- Anyone killed is flung (800–827 studs, measured).
- A survivor is knocked down and shoved (51 studs at the rim).

The Weaponary's "All" tab is now a **Gamepass** tab at the end of the row. The shop opens on Melee.

## Changes
- **Weapon** — built by `Blaster/BuildNewPistolsShotguns.luau` on an AK47 donor, like the earlier guns.
  - `ServerStorage.Weapons.RPG`: Category `Launcher`, `Gamepass = "RPG"`, **no Price**. The donor's Price
    is cleared, because a leftover one would have made it cash-buyable; the donor's ShopViewRotation too.
  - `ReplicatedStorage.Blaster.ViewModels.RPG`, and `Blaster.Objects.RPGRocket` (the round in flight).
  - The shot sound is the engine's own `rbxasset://sounds/Launching rocket.wav`.
  - The build now takes per-weapon source axes and skips specs whose source model is gone (see Notes).
- `Blaster.Constants` — `explosionRadius` / `explosionEdgeDamage` / `explosionKnockback` /
  `explosionFlingSpeed`, `projectile`, `PROJECTILE_SPEED = 250`, `HideWhenEmpty`.
- `ShotResolver` — `explode()`.
  - An explosive weapon's ray deals nothing itself; it only finds the landing point, so a direct hit
    is never counted twice.
  - The blast fires after `distance / PROJECTILE_SPEED`, so it lands with the flying model.
  - It uses an engine `Explosion` for the flash and bang only (BlastPressure 0, no joint breaking),
    and applies its own damage by distance.
  - The killed go through the existing `flingRagdoll`. Survivors get `RagdollController.stagger` (1.2 s)
    plus a push, because a standing humanoid cancels a bare push within a frame. Loose props are thrown.
- `Effects.projectileEffect` (new) + `drawRayResults` — a weapon naming a `projectile` flies that model,
  with smoke and a glow, instead of drawing a laser. The same path serves other players' view.
- `WeaponShopService.grantWeapon` + `ViewModelController` — parts tagged `HideWhenEmpty` (the loaded
  rocket) follow the Tool's replicated `_ammo`: they vanish when fired and return when the reload
  finishes, in both third and first person.
- `WeaponShopService` BuyRequest — a gamepass weapon needs `GamepassOwned_<key>` on the server and costs
  0. The catalog carries `Gamepass`.
- `Monetization.Constants` — `RPG` pass, placeholder id 0, R$499. It also shows in the Gamepass shop.
- `WeaponaryShopController` + the `WeaponaryShop` template — `TabAll` became `TabGamepass` (last). The tab
  lists every weapon with a `Gamepass` attribute, whatever its category.
  - Card: "GAMEPASS" in Robux green.
  - Detail panel, pass not owned: **GAMEPASS · R$499**, and a click is refused and prompts the pass.
  - Pass owned: **CLAIM · FREE**, which then opens the slot picker.
  - A pass bought mid-session flips the panel live.
- `WeaponViewmodelMotion` — `RPG` profile (rifle, the heaviest kick 1.80, slowest raise 0.60).

## Verification (play mode)
- **Shop:**
  - It opened on Melee; the Gamepass tab showed the RPG card, and the card opened.
  - GAMEPASS click → refused ("no id configured yet" logged, as intended for id 0), with no RPG and
    Cash unchanged. A crafted `BuyRequest` from the client was also refused.
  - Pass attribute set → the panel flipped to CLAIM · FREE. Claim → owned, Cash still 20,000, picker
    open → Slot 2 → in the Backpack.
- **Firing:** ammo 1 → 0, the `RPGRocket` model was seen in flight, the loaded rocket was hidden (T 1).
  After R + 3 s: ammo 1, rocket shown in the viewmodel and on the Tool (T 0).
- **Explosion**, three live enemies pinned at 0 / 6 / 12 studs, blast 1.3 / 6.0 / 11.9 studs from them:

  | | HP | Result | Travel |
  |---|---|---|---|
  | centre | 150 | killed | 827 studs |
  | 6 studs | 100 | killed | 800 studs |
  | 12 studs | 1000 | 904 (−96, as the falloff predicts) | 51 studs |

- 0 client errors from this change. The one server error came from my own test recorder reading a
  flung corpse's missing root part; no game script indexes it that way.

## Notes
- **Tuning, measured rather than assumed.** At fling 380 / knockback 110, the first run in the test arena
  flew the killed only 391 and 140 studs — the arena walls stopped them. On open baseplate they flew 1,208
  and 1,211, off the edge of the map. Distance grows roughly with the square of the speed, so fling 290
  aims at ~700 (measured 800–827) and knockback 65 at a shove (measured 51, from 111).
- **Testing needed a ForceField.** Enemies kept killing the test character between steps, which silently
  dropped the equipped RPG. That is also where the repeated `Lean` line-25 errors came from, one per
  respawn (the bug noted in the previous change log).
- **The source models for the eight pistols/shotguns are gone** (deleted after they shipped). Their
  built weapons are complete and untouched, but the build script can no longer rebuild them from
  source; it now skips them and says so, instead of erroring.
- **Not done:**
  - The RPG has no shop/hotbar icon yet (no picture was supplied), so its card shows the name only.
  - The gamepass id is a placeholder 0: set `Monetization.Constants` RPG `gamepassId` in the real
    universe.
  - The knockback on another *player* was not verified: solo test, and a player's character is
    physics-owned by their own client, so a server-applied push may land softer there.
