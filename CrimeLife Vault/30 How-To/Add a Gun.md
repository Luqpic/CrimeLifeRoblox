---
type: howto
tags: [howto, weapons, viewmodel]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/Blaster/BuildNewPistolsShotguns.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Eight-New-Pistols-And-Shotguns.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-New-Guns-Missing-MuzzleAttachment-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Loadout-Expansion-10-New-Guns.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/WeaponViewmodelMotion.luau", "CLAUDE.md"]
---

# Add a Gun

A new firearm on the shared blaster code. The data path: raw model in Workspace -> a row in the re-runnable build script -> a Tool in `ServerStorage.Weapons` (stats as attributes) plus a viewmodel in `ReplicatedStorage.Blaster.ViewModels` -> a `WeaponViewmodelMotion` profile -> the shop catalog and skins pick it up by themselves. System: [[Weapons and Blaster]], [[Viewmodels and Weapon Animation]], [[Weapon Shop and Upgrades]].

Skills: `roblox-game-systems`, `roblox-characters-animation` (see [[Roblox Skills]]).

## Steps
1. **Stage the raw model** in Workspace (the eight 2026-09-24 guns came from `Workspace.Pistols` / `Workspace.Shotguns`). Tag moving pieces with attribute `MovingPiece = "Magazine"` or `"Pump"`; a loaded round that should vanish when empty is tagged `HideWhenEmpty` (the RPG rocket).
2. **Find the source axes** from geometry (grip is the low part at the rear) and confirm by screenshot. The 2026-09-24 sources all lay on their side, muzzle along world -X.
3. **Add a `SPECS` row** to `FPSSystem/Blaster/BuildNewPistolsShotguns.luau`: `src`, `name`, `icon`, `donor` (a same-class weapon: `Glock 17` for pistols, `Mossberg 590` for shotguns, `AK47` for the RPG), `len` (real length at the donor's scale), optional `sounds` (borrow another weapon's set), `shiftX`, and `stats` (`Category`, `Price`, `damage`, `rateOfFire`, `magazineSize`, `range`, `spread`, `recoilMin`, `recoilMax`, `reloadTime`, `fireMode`). Keep stats inside the category's existing band.
4. **Run the build in Edit** (command bar or `execute_luau`). It is a donor-skeleton swap: the donor's `Body` stays as a hidden 0.2-stud anchor (Handle weld, `MuzzleAttachment`), donor trims go, the new mesh welds on as `Mesh1..N`. Add a mesh to the core part; never replace it. It copies raw meshes rather than consuming them, so a failed run can be re-run.
5. **Add a `profiles` entry** in `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` (mirror `FPSSystem/ViewmodelAnimations/WeaponViewmodelMotion.luau`): the mechanical class (`rock`, `rifle`, `bullpup`, `top`, `pistol`, `revolver`, `shell`, `pump`) plus its two tuning numbers. Without it `Motion.new` asserts and first person never starts.
6. **Check `MuzzleAttachment`** sits just inside the barrel tip on both the Tool and the viewmodel. Without it the controller stops before wiring equip, fire and reload, and the gun is held as a plain object. The shared convention is the same proportion of the body on 12 of 15 guns; do not copy one reference gun's position.
7. **Icon:** set the Tool's `TextureId` (hotbar and shop card) and keep the id in the `SPECS` row so a rebuild keeps it. See [[Icon Pipeline]].
8. **Shop preview:** if the 3D preview shows upside down, set `ShopViewRotation` (the AK47 body frame needs `180, 0, 0`). A bounding box cannot tell up from down.
9. **Sounds** live in the Tool's `Sounds` folder; see [[Add a Sound]].
10. Nothing to change in the shop, catalog, upgrades or skins: the catalog picks up any Tool with `Category`, and `SkinApplier` recolours any visible part under `Blaster`.
11. A gamepass gun: `Gamepass = "<key>"` and no `Price` (clear a donor's leftover Price). See [[Add a Gamepass]].

## Files to touch
`FPSSystem/Blaster/BuildNewPistolsShotguns.luau`, `ServerStorage.Weapons.<name>`, `ReplicatedStorage.Blaster.ViewModels.<name>`, `WeaponViewmodelMotion` (Studio and mirror).

## Check
- `ReplicatedStorage.Weapons.Catalog` has the entry with the right Category and Price.
- Equip in Play: 0 client and server errors (ignore the known unauthorized-sound noise); first-person screenshot: upright, muzzle forward, in the hand.
- No joint on the new Tool or viewmodel points outside its own weapon (the baton fault).
- Run the viewmodel motion specs ([[Unit Test Runner]], [[Add a Viewmodel Animation]]).
- Leave for a person: fire, reload and ADS feel, third-person hold (donor `Grip`). The developer saves.

## Done before
[[FPS-Loadout-Expansion]], [[FPS-Loadout-Expansion-10-New-Guns]], [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]], [[FPS-AK47-Display-Fix-11-New-Guns-Integration]], [[FPS-Eight-New-Pistols-And-Shotguns]], [[FPS-New-Guns-Magazines-And-Pump-Forends]], [[FPS-RPG-Gamepass-Launcher]], [[FPS-Loadout-Orientation-Fix]].
