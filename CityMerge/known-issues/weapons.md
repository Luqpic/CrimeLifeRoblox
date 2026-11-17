# Weapons: instance edits (known issues pass 2026-11-17, Task 3)

Instance edits in `Crimelife city.rbxl` that are not scripts. NOT saved / NOT published.

## Descriptions (`Description` attribute, `ServerStorage.Weapons.<Tool>`, 38)

Copied to the shop catalog by `WeaponShopService` (`CATALOG_ATTRIBUTES`). Longest 53 characters.

| Tool | Description |
|---|---|
| AK47 | Starter auto rifle with a 30-round magazine |
| AKM | Harder-hitting auto rifle, 30 rounds, slower reload |
| AMB-17 | Fast-firing auto rifle with a 30-round magazine |
| APS | Full-auto machine pistol, 26 rounds, shorter range |
| AR-18 | Light auto rifle, 30 rounds, quick to reload |
| AUG A-3 | Bullpup auto rifle, 30 rounds, an all-rounder |
| Baton | Melee club that stuns the target for a second |
| Benelli M4 | Semi-auto shotgun, 7 shells, quick follow-up shots |
| Crowbar | Starter melee weapon for heavy close-up swings |
| Deagle | Hard-hitting semi-auto pistol, 10 rounds |
| FN P-90 | Fast-firing auto weapon with a 50-round magazine |
| Glock 17 | Reliable semi-auto pistol with a 17-round magazine |
| Glock 18 | Full-auto pistol, 33 rounds, very fast fire |
| HCAR | Heavy auto rifle, 50 rounds, strong hits, slow reload |
| HK G3 | Full-auto battle rifle, 20 rounds, strong hits |
| Itacha Mag-10 | Hardest-hitting shotgun, 4 shells, slow to fire |
| Knife | Quick melee blade, double damage from behind |
| Kriss Vector | Very fast-firing auto weapon, 25 rounds |
| M14 EBR | Semi-auto marksman rifle, 20 rounds, high damage |
| M16A1 | Burst-fire rifle with a 30-round magazine |
| M1911 | Classic semi-auto pistol, 7 rounds, heavy hits |
| M45A1 | Semi-auto pistol, 7 rounds, heavy hits at range |
| MP-153 | Semi-auto shotgun, 5 shells, the fastest shotgun fire |
| MP443 | Semi-auto service pistol with a 17-round magazine |
| MP9 | Compact auto weapon with the fastest fire rate |
| Mateba 2006M | Revolver, 6 rounds, the hardest-hitting pistol |
| Mossberg 590 | Pump-action shotgun with an 8-shell tube |
| PB | Compact semi-auto pistol, 8 rounds, short range |
| RPG | Rocket launcher, one explosive round per reload |
| Remington 870 | Pump-action shotgun with a 7-shell tube |
| S&W 29 | Heavy revolver, 6 rounds, big damage per shot |
| SIG M17 | Semi-auto service pistol, 17 rounds, good range |
| SPAS-13 | Pump-action shotgun, 8 shells, a faster pump |
| Sawed-Off 870 | Cut-down pump shotgun, 4 shells, close range only |
| Scar L | Auto rifle with a 30-round magazine, solid damage |
| Sig MPX | Compact auto weapon, 30 rounds, quick reload |
| Spas 12 | Combat shotgun, 8 shells, pump action |
| USP Compact | Compact semi-auto pistol, 12 rounds, solid damage |

## Third-person muzzles (`<Tool>.Blaster.Body.MuzzleAttachment`, Body-local studs; forward is Body -X)

| Tool | Old Position | New Position | Orientation | FlashEmitter |
|---|---|---|---|---|
| Glock 17 | (0.822, 0, 0) (stock end) | (-0.89, 0.47, 0) | (0, 0, 0) -> (0, -90, 0) | none -> copied from `Blaster.ViewModels.Glock 17` muzzle |
| Benelli M4 | (1.517, 0, 0) (stock end) | (-3.16, 0.48, 0) | (0, 0, 0) -> (0, -90, 0) | none -> copied from `Blaster.ViewModels.Benelli M4` muzzle |
| Spas 12 | (3.566, 0, 0) (stock end) | (-3.566, 0.28, 0) | (0, 0, 0) -> (0, -90, 0) | none -> copied from `Blaster.ViewModels.Spas 12` muzzle |

New X = the front of the gun's meshes along the forward axis (Glock 17 TrimA/TrimB front -0.882/-0.900; Benelli TrimC front -3.159; Spas 12 Body front -3.566). Y = the barrel bore height, read from side-view captures against marker spheres (about ±0.05). Orientation and emitter follow the Tools that already had a third-person flash (Mossberg 590 and others: (0, -90, 0) with a FlashEmitter).

## New instances
- `ReplicatedStorage.Blaster.Scripts.GuiController.DryFire` (Sound): `rbxassetid://17682720424` (the original Blaster weapons' `MagIn` click, 0.25 s), Volume 0.6.
- `ReplicatedStorage.Blaster.Objects.RPGBlast` (Part, anchored, invisible, no collide/query/touch): a copy of `ReplicatedStorage.HeistShared.ModelTemplates.ExplosionEffect` with its emitter renamed `Flash` and disabled; `ShotResolver.explode` clones it per blast.
