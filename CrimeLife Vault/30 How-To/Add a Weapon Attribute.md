---
type: howto
tags: [howto, weapons, attributes]
updated: 2026-11-14
sources: ["CLAUDE.md (How to work, rule 7)", "CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shotgun-Kill-Knockback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab.md"]
---

# Add a Weapon Attribute

New weapon behaviour as an opt-in Tool attribute that the shared blaster code reads. Never branch the shared code per weapon. Rule: [[Shared Code Extended by Attributes]]. System: [[Weapons and Blaster]].

Skills: `roblox-game-systems`, `roblox-security` (server authority for hits).

## Steps
1. **Name it once** in `ReplicatedStorage.Blaster.Constants`: `<NAME>_ATTRIBUTE = "camelCase"` (for example `KNOCKBACK_ON_KILL_ATTRIBUTE = "knockbackOnKill"`, `BLEED_DURATION_ATTRIBUTE`, `BACKSTAB_MULTIPLIER_ATTRIBUTE = "backstabMultiplier"`).
2. **Read it where the behaviour lives**, through the constant:
   - hits, damage, knockback, stun, bleed, explosions: `ServerScriptService.Blaster.Scripts.ShotResolver` (server authority);
   - firing, swing timing, aim: `ReplicatedStorage.Blaster.Scripts.BlasterController`;
   - first-person look: `ViewModelController` / `WeaponViewmodelMotion`.
3. **Unset means the old behaviour.** `nil` must leave every other weapon exactly as it was; check the existing path is untouched.
4. **Effects on a target** are plain replicated attributes on its root part (`StunnedUntil`, `BleedingUntil`), so any display can read them without the resolver knowing.
5. **Damage over time** goes through the same `TakeDamage` + `Tagged` / `Eliminated` path as a hit, so cash, XP, quests and kill stats keep working untouched.
6. **Set it on every Tool that opts in**, including copies inside enemy templates (the Bandits' Mossberg 590 got `knockbackOnKill`).
7. If the shop should show it, it travels with the catalog entry like the other stats.

## Files to touch
`Blaster.Constants`, the one reader script, the opted-in Tools. Mirror edited scripts into `FPSSystem/Blaster/` or `FPSSystem/ViewmodelAnimations/`.

## Check
- Measure before and after by driving `ShotResolver.resolveShot` against a pinned live enemy ([[Measure Before and After]]); include a weapon without the attribute as the regression control.
- Harness traps: enemies walk out of the cone; positioning with the shooter's full CFrame can drop the target under the floor. Print what each ray struck before blaming the code.
- Count ticks, not `os.clock()` against an expiry (`task.wait` overshoots; a 5 s bleed dealt 16 instead of 20).

## Done before
[[FPS-Shotgun-Kill-Knockback]] (`knockbackOnKill`), [[FPS-Knife-Bleed-Melee]] (bleed), [[FPS-Baton-Stun-Becomes-A-Stagger]] (stun), [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]] (backstab), [[FPS-RPG-Gamepass-Launcher]] (explosion, `projectile`, `HideWhenEmpty`), [[FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync]] (`swingDelay`), [[FPS-Loadout-Rename-Burst-Expansion]] (burst fire).
