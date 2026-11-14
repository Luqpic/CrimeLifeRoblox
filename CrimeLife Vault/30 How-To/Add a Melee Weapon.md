---
type: howto
tags: [howto, weapons, melee]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Viewmodel-Swing.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-AI-6-Types.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync.md", "CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau"]
---

# Add a Melee Weapon

A new melee Tool on the shared blaster code, cloned from the Crowbar mechanism (the Baton and the Knife were made this way). System: [[Melee]], [[Weapons and Blaster]].

Skills: `roblox-game-systems`, `roblox-physics` (knockback).

## Steps
1. **Clone the Crowbar** Tool into `ServerStorage.Weapons.<name>` and its viewmodel into `ReplicatedStorage.Blaster.ViewModels.<name>`.
2. **Swap the look, not the rig.** `Blaster.Body` is the rig hub (arm Motor6Ds, tool weld, `MuzzleAttachment`, trail). Either swap its `SpecialMesh` (Baton) or make Body invisible and weld the new mesh on (Knife's `Blade`). Remove the cosmetic Trim collars. Do the same in the viewmodel.
3. **Keep the empty `MuzzleAttachment`**: melee weapons carry one deliberately and the controller expects it.
4. **Attributes** on the Tool: `damage`, `range`, `rateOfFire`, `knockbackForce`, `swingDelay` (damage resolves at visual contact), `meleeHitEffect`, `magazineSize = 1`, `reloadTime = 0`, `Category = "Melee"`, `Price`, `viewModel`. Opt-in extras: `stunDuration` (Baton stagger), `bleedDuration` + `bleedDamage` (Knife), `backstabMultiplier` (replaces the headshot rule). New behaviour: [[Add a Weapon Attribute]].
5. **Viewmodel profile:** add `["<name>"]={"melee", ...}` to `WeaponViewmodelMotion.profiles` (the Knife copied the Crowbar's entry verbatim).
6. **Swing:** nothing to author. `ViewModelController.playShootAnimation` runs the procedural wind-up / strike / settle arc for any weapon with `meleeHitEffect`, choosing among the `Shoot`, `Shoot2`, `Shoot3` names in the viewmodel's `Animations` folder. Tune with `MELEE_SWING_DURATION` / `MELEE_SWING_REACH`.
7. **Enemy use:** an enemy template carrying it needs an `EngageRangeFraction` override, or a short-range weapon never counts as in range. See [[Add an Enemy Type]].
8. Icon and sounds: [[Icon Pipeline]], [[Add a Sound]] (equip and swing sounds play explicitly, not from animation markers).

## Files to touch
`ServerStorage.Weapons.<name>`, `ReplicatedStorage.Blaster.ViewModels.<name>`, `WeaponViewmodelMotion` (Studio and `FPSSystem/ViewmodelAnimations/` mirror), optionally `Blaster.Constants` and `ShotResolver` for a new effect.

## Check
- Drive `ShotResolver.resolveShot` against a pinned live enemy inside `range`: damage equals the attribute; effect ticks measured (the Knife: five ticks of 4, total 20, three rapid cuts still 20).
- Catalog entry present with `Category=Melee`; viewmodel present; contact pose lands on `swingDelay`.
- A real click in game is still needed to see the swing fire; synthetic mouse input does not reach Studio here.

## Done before
[[FPS-Loadout-Melee-Shotgun-Sniper]], [[FPS-Enemy-AI-6-Types]] (Baton), [[FPS-Baton-Viewmodel-Real-Mesh-Fix]], [[FPS-Crowbar-Hitbox-And-Shotgun-Cooldown-Fix]], [[FPS-Melee-Viewmodel-Swing]], [[FPS-Baton-Stun-Becomes-A-Stagger]], [[FPS-Knife-Bleed-Melee]], [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]], [[FPS-Melee-Shop-View-And-Bleed-Effect]].
