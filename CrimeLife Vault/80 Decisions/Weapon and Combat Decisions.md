---
type: decision
tags: [decision, weapons, combat, melee]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Remove-Sniper.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Loadout-Melee-Shotgun-Sniper.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Loadout-Expansion-10-New-Guns.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shotgun-Kill-Knockback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Eight-New-Pistols-And-Shotguns.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "CLAUDE.md (How to work in this project, rule 7)"]
---

# Weapon and Combat Decisions

Calls about guns, melee and how hits land. The code is in [[Weapons and Blaster]], [[Melee]] and [[Viewmodels and Weapon Animation]]. Only calls a log attributes to the developer say "developer"; the rest are what the log recorded, without guessing who chose.

## Standing rules

- **Extend weapons by attribute, not by fork.** Weapon behaviour is data on the Tool (`infiniteAmmo`, `knockbackForce`, ADS zoom, burst mode, ray count); the shared blaster code reads an opt-in attribute and is never branched per weapon. (`CLAUDE.md`, rule 7)
- **Viewmodels add a mesh to the core part, never replace it** (donor-skeleton swap; the build script copies raw meshes). See [[Viewmodels and Weapon Animation]].

## Newest first

- **2026-11-20: third person is OBT's shoulder camera inside CrimeLife's blaster** (not OBT's gun engine), shown first whenever a gun comes out, V toggles and is remembered, aim is a shoulder zoom. Developer picker answers 3, 4 and 5; the full set is in [[Admin, Animation and Camera Decisions]]. [[2026-11-20 Admin Animations Third Person]]
- **2026-11-18: the APS is the Stechkin machine pistol**, not the underwater rifle: Pistol category, full-auto 750 rpm, magazine 20, Price 650. Its mesh is still a 7.02-stud rifle with rifle hold clips; a pistol mesh is the developer's call. Reverses the 2026-09-15 rifle reading. [[2026-11-18 Open Items Pass]]
- **2026-11-18: the default fall and climb animations stay**; the original 2026-09-19 ones were not custom work, so nothing is re-uploaded. [[2026-11-18 Open Items Pass]] [[FPS-Fall-Animation-Dead-Asset]]
- **2026-09-24: the RPG is a gamepass weapon.** Unlocked by a R$499 pass, never buyable with Cash; the shop's All tab became a Gamepass tab and the shop opens on Melee. [[FPS-RPG-Gamepass-Launcher]] (pass ids: [[Cosmetics and Monetisation Decisions]])
- **2026-09-24: the two clashing new guns ship as Glock 18 and SPAS-13**, "at the user's direction"; the Glock 18 got the real gun's full-auto. [[FPS-Eight-New-Pistols-And-Shotguns]]
- **2026-09-24: the Knife gets a x2 backstab instead of the x2 headshot.** A hit on the Smuggler's duffel bag counting as "back" is kept on purpose. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- **2026-09-21: a carried gun is no shield.** A bullet that strikes a carried weapon damages its holder (it used to be absorbed). [[FPS-Carried-Weapons-Absorbed-Hits]]
- **2026-09-21: the Baton stun becomes a stagger**: the target drops instead of freezing. [[FPS-Baton-Stun-Becomes-A-Stagger]]
- **2026-09-21: the Knife** reuses the Crowbar's animations; damage 30, a bleed of 5 ticks of 4, price 350. [[FPS-Knife-Bleed-Melee]]
- **2026-09-20: viewmodel animations use linear easing**, and the KeyframeSequence export covers viewmodel animations only, not player animations. [[FPS-Viewmodel-Animation-Linear-Easing]] [[FPS-Viewmodel-KeyframeSequence-Export]]
- **2026-09-19 (retuned 2026-09-20): shotguns spend their knockback only on the killing shot**, 38 on all of them; melee still pushes on every swing. Reverses 2026-09-11's "a kill does not fling the corpse". [[FPS-Shotgun-Kill-Knockback]]
- **2026-09-15: the APS is full-auto and the M14 EBR semi-auto only**, both on purpose. [[FPS-Loadout-Expansion-10-New-Guns]]
- **2026-09-15: the Baton is the only weapon that stuns**; it costs 500. [[FPS-Weaponary-Melee-Display-Fixes-And-Baton]]
- **2026-09-11: the sniper (Snipex Alligator) and its per-weapon zoom are removed.** [[FPS-Remove-Sniper]]
- **2026-09-11: the FN P-90 is left unbuilt** (no mesh). [[FPS-Loadout-Expansion]]
- **2026-09-11: backpack and ammo HUD show weapon names, not icons**; a kill does not fling the corpse (reversed for shotguns on 2026-09-19). [[FPS-Loadout-Melee-Shotgun-Sniper]]
