---
type: system
tags: [system, weapons, combat, blaster]
updated: 2026-11-17
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Loadout-*.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shotgun-Kill-Knockback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Carried-Weapons-Absorbed-Hits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-*.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Eight-New-Pistols-And-Shotguns.md", "CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau", "CrimeLifeRoblox/FPSSystem/Blaster/BuildNewPistolsShotguns.luau", "CLAUDE.md (Systems)"]
---

# Weapons and Blaster

**Skills:** `roblox-game-systems`, `roblox-networking`, `roblox-security` (load these for work here)

## What it does
Every gun, melee weapon and the RPG runs on one shared, data-driven blaster: stats are attributes on the Tool, one client controller and one server resolver drive every weapon. The server is the authority for hits, damage, headshots, knockback, stun, bleed and explosions.

## Where it lives
- Weapon Tools: `ServerStorage.Weapons.*` (moved out of `StarterPack`; granted by the shop, see [[Weapon Shop and Upgrades]]). Enemy copies live under `ServerStorage.EnemyTemplates.<Type>.<Weapon>`.
- `ReplicatedStorage.Blaster.Constants` (attribute names), `Blaster.Scripts.BlasterController`, `Blaster.Scripts.ViewModelController`, `Blaster.Scripts.WeaponViewmodelMotion` (see [[Viewmodels and Weapon Animation]]).
- `ReplicatedStorage.Blaster.Utility.castRays`, `.drawRayResults`, `.findOwningHumanoid`, `.canDamageHumanoid`; `Blaster.Effects` (`impactEffect`, `laserBeamEffect`, `projectileEffect`); `Blaster.Objects` (`MeleeImpact`, `RPGRocket`); `Blaster.ViewModels.*`; `Blaster.Remotes` (`DamageDirection`, `KillConfirmed`).
- Server: `ServerScriptService.Blaster.Scripts.ShotResolver`, `.DamageDirectionService` ([[Damage Direction]]).
- Repo copies: `CrimeLifeRoblox/FPSSystem/Blaster/ShotResolver.luau`, `FPSSystem/Blaster/BuildNewPistolsShotguns.luau` (re-runnable build for the eight 2026-09-24 guns and the RPG).

## How it works
- **Attributes, not forks.** Per-weapon behaviour is opt-in data: `damage`, `rateOfFire`, `magazineSize`, `range`, spread, `raysPerShot`, `rayRadius`, `reloadTime`, fire mode (semi / auto / burst), `infiniteAmmo`, `knockbackForce`, `knockbackOnKill`, `swingDelay`, `meleeHitEffect`, `stunDuration`, bleed (`BLEED_DURATION_ATTRIBUTE` / `BLEED_DAMAGE_ATTRIBUTE`), `backstabMultiplier`, `Category`, `Price`, `Gamepass`, `ShopViewRotation`, `viewModel`, and the RPG's `explosionRadius` / `explosionEdgeDamage` / `explosionKnockback` / `explosionFlingSpeed` / `projectile`. Every unset attribute leaves the weapon on the original path.
- **Shots.** The client casts, the server re-validates every shot in `ShotResolver`. A hit resolves to its owner with `findOwningHumanoid` (walks up through a carried Tool), so a carried weapon no longer absorbs hits. Headshot ×2 on `Head`; a weapon with `backstabMultiplier` uses that rule instead.
- **Kills and rewards.** Damage goes through `TakeDamage` + `Tagged` / `Eliminated`; cash, XP and quest credit all listen to `Eliminated` (see [[Economy and Cash]], [[Leveling and Renown]], [[Quests and Dialogue]]). `KillConfirmed` tells the killer the victim's name for the kill toast ([[Notifications]]).
- **Knockback.** Per-ray push `knockbackForce / raysPerShot`; with `knockbackOnKill` (all shotguns, `knockbackForce` 38) the full force goes on the killing ray only, through `flingRagdoll` ([[Ragdoll]]). Melee keeps the per-ray push on every swing.
- **Tracers.** A miss is drawn only `MISS_TRACER_LENGTH` = 150 studs (0.75 s); hits draw to the impact point. `LASER_BEAM_VISUAL_SPEED` is 200 studs/s.
- **Burst fire** is client-side (server validates each shot). The shotgun reloads shell by shell and can be cancelled by firing.
- **Muzzle.** Every weapon must carry `MuzzleAttachment` in both its Tool and viewmodel; melee carries an empty one. It sets flash, tracer start, sound origin and shop preview orientation, not aim.
- **RPG** (Category `Launcher`, `Gamepass = "RPG"`, no `Price`): its ray only finds the landing point; `ShotResolver.explode` fires after `distance / PROJECTILE_SPEED` (250), 200 damage at centre to 60 at the 16-stud rim, never the shooter. Engine `Explosion` is flash only (BlastPressure 0). The killed are flung, survivors get `RagdollController.stagger` 1.2 s plus a push. `HideWhenEmpty` parts (the loaded rocket) follow `_ammo`. Pass id is `Monetization.Constants` RPG `gamepassId` ([[Gamepasses]]).
- **Roster** (as recorded): starters plus loadout batches 2026-09-11 (M1911, Mateba 2006M, AKM, HCAR, Kriss Vector, Scar L, six more unnamed in the log), 2026-09-15/16 (M14 EBR, AR-18, HK G3, APS, PB, MP443, Glock 17, S&W 29, Itacha Mag-10, Benelli M4, Spas 12), 2026-09-24 (Glock 18, SIG M17, M45A1, USP Compact, Remington 870, Sawed-Off 870, MP-153, SPAS-13, RPG). Melee: Crowbar, Baton, Knife ([[Melee]]). One log counts 34 guns in its sweep (2026-09-24).

- In the city, `ServerScriptService.Blaster.Scripts.Blaster.validateFireInterval` (pure) is called last by `validateShot`: a shot is refused when its claimed timestamp is less than 0.9 x 60 / rateOfFire after the last accepted one for the same player and weapon name; a nil or non-number rate-of-fire attribute is accepted. `validateShootArguments` refuses non-canonical hit keys. Tests `ShotRate_Test`, `BlasterGuard_Test` ([[2026-11-15 FPS Hardening In City]]).

## Extend it
- New gun: run the donor-skeleton build (`BuildNewPistolsShotguns.luau`): same-class donor, keep its `Body` as a hidden anchor, hang the new mesh off it, never replace the core part. Add a `profiles` entry in `WeaponViewmodelMotion` or first person never starts. Give it `Category` (+ `Price` or `Gamepass`) and the shop picks it up. Upload a `TextureId` icon.
- New behaviour: add an opt-in attribute to `Blaster.Constants` and read it in the shared code; never branch per weapon.

## Watch out
- A missing `MuzzleAttachment` aborts the weapon's setup before equip/fire/reload connect; the Tool then behaves as a plain held object.
- A missing `profiles` entry asserts in `WeaponViewmodelMotion.new` and kills `BlasterController.new` (no first person).
- Copying a weapon does not redirect welds that point outside the copied subtree: rebuild viewmodel joints against the viewmodel's own `Body`.
- Reference rigs disagree where the left hand hangs (body vs magazine); assume nothing.
- `raysPerShot` is only listed explicitly on shotguns; a clone can inherit nothing.
- The Glock 17, Benelli M4 and Spas 12 Tool `MuzzleAttachment` now sits at the barrel end (measured to 0.000 of the barrel-end point, 2026-11-17) and carries a `FlashEmitter`. 12 other guns (APS, AR-18, Glock 18, HK G3, Itacha Mag-10, M14 EBR, M45A1, MP443, PB, S&W 29, SIG M17, USP Compact) still have no third-person `FlashEmitter`, and their muzzle positions were not checked.
- The RPG's blast is no longer an engine `Explosion` (its bang cannot be silenced): `ShotResolver.explode` clones `ReplicatedStorage.Blaster.Objects.RPGBlast`, a particle burst. Damage, `Tagged` / `Damaged` / `Eliminated` are unchanged. The burst is smaller than the old fireball and was not judged by eye.
- Mossberg 590 and Spas 12 have no `Pump` part or `PumpJoint`: their fore-ends are fused into long meshes, so they cannot rack. The fix is a mesh split in Blender plus an upload (the developer); `WeaponViewmodelMotion` already moves any `Pump` joint.
- Every Tool has a `Description` (38 of 38, longest 53 characters); `WeaponShopService.CATALOG_ATTRIBUTES` carries it to the shop's detail card.
- A shotgun's ammo readout counts shells up through the shell-by-shell reload (`GuiController.updateAmmoText`); magazine weapons keep the dashes while reloading.
- Dry-fire cue: a press that the client's own fire-rate cooldown holds back plays `GuiController.DryFire` (not for Auto fire, not for melee), once per press. The server never answers a refused shot, so the cue cannot play for one.
- The repo copy `FPSSystem/Blaster/ShotResolver.luau` was last committed with per-weapon Spraypaint and has no `explode()`; Studio holds the newer code.
- Never reuse the old prop-impulse formula on characters (range-scaled; once flung a corpse at 584 studs/s).
- The `StarterCharacterScripts.Lean` line 25 error (direct `HumanoidRootPart` index) shows up in weapon testing; unfixed as of 2026-09-24.

## History
- 2026-11-17: descriptions on all 38 Tools, shotgun reload readout, dry-fire cue, RPG blast as a particle burst, three muzzles moved to the barrel end. [[2026-11-17 Known Issues Pass]]
- 2026-09-25: the RPG reload carries the rocket in the hand. [[FPS-RPG-Reload-Hand-Carries-Rocket]]
- 2026-09-24: RPG preview upright (`ShopViewRotation` 180,0,0), stand-in pass id 10904398, own sounds and icon. [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]]
- 2026-09-24: RPG gamepass launcher with explosive rounds. [[FPS-RPG-Gamepass-Launcher]]
- 2026-09-24: pistol magazines and pump fore-ends move. [[FPS-New-Guns-Magazines-And-Pump-Forends]]
- 2026-09-24: eight new pistols and shotguns. [[FPS-Eight-New-Pistols-And-Shotguns]]
- 2026-09-24: Knife backstab replaces its headshot; `KillConfirmed` remote. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- 2026-09-22: miss tracers cut to 150 studs. [[FPS-Miss-Tracers-And-Spawn-Cap]]
- 2026-09-21: `findOwningHumanoid`: carried weapons stop absorbing hits. [[FPS-Carried-Weapons-Absorbed-Hits]]
- 2026-09-19/20: `knockbackOnKill`, `flingRagdoll`, shotgun knockback 38. [[FPS-Shotgun-Kill-Knockback]]
- 2026-09-16: eleven new weapons, donor-skeleton swap; AK47 preview upright. [[FPS-AK47-Display-Fix-11-New-Guns-Integration]]
- 2026-09-15: ten new guns lacked `MuzzleAttachment`. [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]] / [[FPS-Loadout-Expansion-10-New-Guns]]
- 2026-09-11: world pickups and Custom Inventory. [[FPS-Weapon-Pickups-And-Inventory-Integration]]
- 2026-09-11: equip sound explicit, `swingDelay`. [[FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync]]
- 2026-09-11: shotgun shell-by-shell reload, swing variants. [[FPS-Melee-Combo-And-Shotgun-Reload-Refactor]]
- 2026-09-11: sniper removed with its per-weapon zoom. [[FPS-Remove-Sniper]] / [[FPS-Loadout-Bugfixes-Sounds-VFX]]
- 2026-09-11: burst fire, renames, six weapons. [[FPS-Loadout-Rename-Burst-Expansion]]
- 2026-09-11: three models rotated 180°. [[FPS-Loadout-Orientation-Fix]]
- 2026-09-11: six weapons as pure content. [[FPS-Loadout-Expansion]]
- 2026-09-11: `infiniteAmmo`, `knockbackForce`, Crowbar / Mossberg / sniper. [[FPS-Loadout-Melee-Shotgun-Sniper]]

See [[Batch Log]].
