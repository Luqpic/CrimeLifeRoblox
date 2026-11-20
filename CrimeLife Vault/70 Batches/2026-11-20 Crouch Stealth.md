---
type: batch
tags: [batch, city, movement, stealth, police, enemies]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 4)", "Play checks, 2026-11-20 evening", "CityMerge/after-import.md ('Crouch stealth 2026-11-20')"]
---

# 2026-11-20 Crouch Stealth

Part 4 of [[Current Work]]. Built natively.

## Asked for
"Since we have a crouch, I figured the purpose of teh crouch is to allow us to go on sneak mode, basically allowing us to hide or evade from polices (must be surrounded by objects, not open areas ofc) as standing will make you feel more seen. This also applies to criminal enemies when they see you too."
Pickers: "Strong" (hidden 25 studs, crouched in the open 70, standing unchanged); "3 of 8 sides" within 6 studs at waist height; breakers: firing a gun, sprinting or rolling, getting hit, too close (within 8 studs in front); HUD: a screen vignette.

## How it works
- **Server-owned crouch.** `StarterCharacterScripts.Crouching` fires `ReplicatedStorage.PlayerMovement.Crouch` (true / false) when the crouch starts and stops (before, `IsCrouching` lived only on the client and the server never saw it). `RunningState` hands it to the new `ServerScriptService.Movement.Scripts.Stealth`.
- **Stealth** ticks 4 times a second per player: crouched, not sprinting (`IsSprinting`), not rolling (`RollingUntil`), not faster than a crouch walk (8 + 3 studs a second), not exposed. Then 8 flat rays of 6 studs from the root: 3 or more blocked by terrain or a visible part that is not a body = **Hidden** (range 25), else **Crouched** (range 70). Published on the character as attributes `Stealth` and `StealthRange` (nil when standing).
- **Who reads it:** `EnemyAI` (criminals, police and heist police: acquiring a target and keeping one, `Stealth.noticeRange`), `PoliceDispatcher.isSeen` (officers and, through `Witnesses.guardSees(position, range)`, guards: a hidden wanted player is unseen beyond 25 studs, so the stars drain), `GuardPost` candidates (heist guards).
- **Breakers (3 s, `EXPOSE_SECONDS`):** a gunshot (`Blaster` after a validated shot, not melee), a hit taken (Blaster's `Tagged`), an enemy, officer or guard within 8 studs whose look is within 60 degrees of the player. Sprinting or rolling simply counts as standing.
- **Vignette:** `StarterGui.StealthVignette` (ScreenGui, IgnoreGuiInset, ResetOnSpawn off): `Vignette` frame with four black edge frames and gradients; `StealthVignetteController` fades their `BackgroundTransparency` to 0.1 while `Stealth` is Hidden. To look at it in Edit set the four edges to 0.1.

## Verified (Play)
- Crouched in the open: `Crouched` / 70. Inside three 2 x 8 x 2 posts 4 studs away: `Hidden` / 25.
- An Offender 40 studs away: stayed on patrol while the player was hidden; attacked within 2.5 s after the player stood up.
- Crouched while being shot: never stealthy (sampled 8 times); 3.6 s after the shooter left: Hidden again. A gunshot: not stealthy at once, Hidden again 3.3 s later.
- The vignette draws (capture). City 373 / 373 / 0 (new `Stealth_Test`, 3 cases); heist 764 passed / 0 failed; no Stealth warnings.

## Trap found
A `CanvasGroup` holding the vignette frames did not draw in the Studio capture (GroupTransparency read 0.15, nothing on screen); plain frames did. See [[UI Layout Traps]].

## Left open
- Witness civilians (`Witnesses.sees`, crime reports) ignore stealth on purpose: crimes are loud.
- Phones: crouch needs its touch button to send the same remote (it goes through `Crouch()` / `Stop()`, so it does); not tested on a phone.

## Saved
Studio saved to Roblox (Save, never Publish). NOT published.

## Links
[[Movement and Stamina]] · [[Police and Wanted]] · [[Enemies and Spawner]] · [[Robbery Heists and Getaway]] · [[Current Work]]
