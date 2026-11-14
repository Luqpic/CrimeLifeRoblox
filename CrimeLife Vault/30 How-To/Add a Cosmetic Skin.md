---
type: howto
tags: [howto, cosmetics, skins]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/Cosmetics/Palettes.luau", "CrimeLifeRoblox/FPSSystem/Cosmetics/Palettes_Test.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weapon-Skins-Phase-1.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Revert-Global-Spraypaint-Balance.md", "CrimeLifeRoblox/FPSSystem/Persistence/Schema.luau"]
---

# Add a Cosmetic Skin

A new weapon skin is one palette row; every weapon, present or future, wears it. System: [[Cosmetics and Skins]], [[Spraypaint]].

Skills: `roblox-monetization` (if sold), `roblox-ui` (if the card changes).

## Steps
1. **Append an entry** to `Palettes.list` in `ReplicatedStorage.Cosmetics.Palettes` (mirror `FPSSystem/Cosmetics/Palettes.luau`). Order is screen order; never reorder or edit existing entries.
   - `key`, `name` (upper case), `source` = `"Free"` | `"Vip"` | `"Spraypaint"`, `swatch` (the chip colour), `ramp` (3 stops, **dark to light**).
   - `price` only on Spraypaint entries. A Free or Vip entry must not carry one.
2. **Keep it distinguishable:** compute the minimum pairwise RGB distance of all swatches first; the test asserts it stays at or above 52.8. Do not pick by eye.
3. **Update the count tests** that exist to catch a catalogue-shape change (`SpraypaintTier_Test` asserts how many Spraypaint palettes and how many in total).
4. Nothing else: `SkinApplier` ranks each visible part under `Blaster` by its own luminance (never by part name, since about a third of viewmodels render through `Mesh*` parts while `Body` / `Trim*` are invisible donor skeleton); `SkinsCardController` builds a chip per entry; `BuySkinRequest` / `EquipSkinRequest` grant on the server; ownership and equips save in `skinsOwned` / `equippedSkin` ([[Persistence and Saves]]).

## Files to touch
`Palettes` (Studio and mirror), `ServerStorage.UnitTest.Cases.Palettes_Test` / `SpraypaintTier_Test` when counts move.

## Check
- Run `Palettes`, `SkinApplier`, `CosmeticsOwnership`, `Spraypaint` suites in Play ([[Add a Unit Test]]). Mutation-test a new invariant once (make it fail, revert).
- Server refuses: a Vip palette without `GamepassOwned_Vip`, a Spraypaint palette without funds.
- Open the shop by a real click on the HUD button, open a weapon, see the chip in the Skins card.

## Done before
[[FPS-Monetization-Cosmetics-Spec]], [[FPS-Weapon-Skins-Chip-Design]], [[FPS-Weapon-Skins-Phase-1]], [[FPS-Spraypaint-Phase-2]], [[FPS-Skins-Card-Detached-And-Palette-Expansion]], [[Per-Weapon-Spraypaint]], [[Revert-Global-Spraypaint-Balance]].
