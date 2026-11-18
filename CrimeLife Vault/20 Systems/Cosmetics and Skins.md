---
type: system
tags: [system, cosmetics, skins, monetisation, fps]
updated: 2026-11-18
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md", "CrimeLifeRoblox/docs/superpowers/plans/2026-09-22-cosmetics-phase-1.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weapon-Skins-Phase-1.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold.md", "CrimeLifeRoblox/.superpowers/sdd/skins-card-revamp-report.md", "CrimeLifeRoblox/.superpowers/sdd/skins-card-sticky-fix-report.md", "CrimeLifeRoblox/FPSSystem/Cosmetics/Palettes.luau", "CrimeLifeRoblox/FPSSystem/Cosmetics/SkinApplier.luau", "CrimeLifeRoblox/FPSSystem/Cosmetics/CosmeticsService.luau", "CrimeLifeRoblox/FPSSystem/Cosmetics/SkinsCardController.luau", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md"]
---

# Cosmetics and Skins

**Skills:** `roblox-monetization`, `roblox-ui`, `roblox-game-systems` (load these for work here)

## What it does
Weapon skins: 20 colour palettes, any of which can dress any weapon. A skin recolours only the weapon's visible geometry, identically on the world Tool (what others see) and the first-person viewmodel (what the owner sees). Players pick, preview and buy skins on the Skins card that slides in beside the Weaponary shop. Five are free; fifteen cost [[Spraypaint]].

## Where it lives
- `ReplicatedStorage.Cosmetics.Palettes` (catalogue), `.SkinApplier` (`apply` / `remove` / `applyKey`, shared server and client), `.Remotes.EquipSkinRequest`.
- `ReplicatedStorage.Spraypaint.Remotes.BuySkinRequest` (purchase; see [[Spraypaint]]).
- `ServerScriptService.Cosmetics.Scripts.CosmeticsService` (`ownsPalette`, `EquippedSkin_<weapon>` attribute, `applyToTool`, `handleEquipRequest`).
- `ServerScriptService.Weapons.Scripts.WeaponShopService.grantWeapon` applies the skin (pcall-guarded) on equip and respawn restore.
- `ReplicatedStorage.Blaster.Scripts.ViewModelController` `dressViewModel` (first person).
- `StarterPlayer.StarterPlayerScripts.SkinsCardController` (own ScreenGui `SkinsCardGui`, Sibling, DisplayOrder 6; `BUY_CONFIRM_SECONDS` 4 in the Spraypaint constants) driven from `WeaponaryShopController`.
- Tests: `ServerStorage.UnitTest.Cases.Palettes_Test`, `SkinApplier_Test`, `CosmeticsOwnership_Test`.
- Repo copies: `CrimeLifeRoblox/FPSSystem/Cosmetics/*.luau`. Figma design: file `iRetcvpbMMD190DJA9Mwrm`, page `02 · Redesign` (chip node `139:67`, card node `147:6`).

## How it works
- **Palette** = `key`, `name`, `source` (`Free` | `Vip` | `Spraypaint`), `swatch`, a 3-stop dark-to-light `ramp`, and `price` on Spraypaint entries only. Free: Stock, Carbon, Sandstorm, Crimson, Acid. Spraypaint: Cobalt 500, Verdigris 700, Ember 900, RoseGold 1200, Slate 1500, Rust 1800, Forest 2200, Coral 2600, Aqua 3100, Lilac 3700, Fuchsia 4400, Arctic 5200, Obsidian 6100, Gold 7100, Nebula 8200. No Vip palette exists while Vip is on hold.
- **Applying.** `SkinApplier` works inside the Tool's `Blaster` sub-model, takes only parts with `Transparency < 1`, and ranks them by luminance against their stock colour onto the palette ramp, so every weapon keeps its own contrast. It never keys on part names: 11 of 29 viewmodels render through `Mesh1..8` parts while `Body`/`TrimA..` are invisible donor skeleton (Spas 12, Glock 17). Original colours are recorded (`SkinOriginalColor`) and restored exactly on `remove`.
- **Signal.** `SkinId` attribute on the Tool; the viewmodel re-dresses on `GetAttributeChangedSignal("SkinId")`, strictly after `WeaponViewmodelMotion` has solved joints.
- **Ownership.** Free always; Spraypaint palettes need `SkinOwned_<key>` (gate keyed on `source`, fails closed); Vip would need `GamepassOwned_Vip`. `handleEquipRequest`: type check -> armoury check -> weapon ownership (`ownsWeapon`, `WeaponOwned_<name>`) -> palette ownership check -> write -> refresh. A skin for a weapon the player does not own is refused before any write or charge (2026-11-17). A successful buy auto-equips.
- **Skins card** (240x580, 20 chips, price row with the spray icon). Click a locked chip = preview on the 3D model with an accent ring, the price row reading "Buy for N?" in accent; a second click on that chip within `BUY_CONFIRM_SECONDS` 4 = buy (click tone, or denied tone + red outline flash if unaffordable); on success the purchase sound and a spray-can burst (`UI.CashBurst` with a style). `paintChip` alone owns each chip's outline: rest dark 1px, hover grey 2px, previewed/equipped accent green 3px, can't-afford red 3px. The card tracks the shop's `AbsolutePosition`/`AbsoluteSize` live and shares its UIScale; the shop slides left by `SHOP_SHIFT` (130) to make room.
- **Two states, not one (2026-11-18).** `previewPalette` is the 3D preview and the accent ring (the 2026-09-24 lifetime: it moves to another chip and ends on BACK, close, re-targeting the card or the equip landing). `armedPalette` is the "Buy for N?" question: `arm` starts the 4 s timeout and a press watch, `disarm` (timeout, a press outside the chip, another chip, or the buy click) clears it and repaints the price. Only a click on the armed chip buys; a click on the previewed chip after its question ended re-arms (asks again). The timeout never ends the preview (controller ruling: the 2026-09-24 design kept the preview on purpose). The spray icon hides while the question is up: "Buy for 8200?" is 71.5 px in Montserrat Heavy size 11 (`TextService:GetTextBoundsAsync`), and icon (11) plus gap (3) plus text is 85.5 px against the chip's 84. The press watch is an `InputBegan` connection that exists only while a question is up, and tests the press against the chip's `AbsolutePosition` and `AbsoluteSize` (a real click read (916, 408) against a centre of (915.7, 408.2); `GetMouseLocation` reads 58 px lower, the Studio top-bar inset). A gamepad ButtonA press is neither a mouse nor a touch press, so it does not cancel; the timeout still does.
- **Measured (Play, real clicks, a server counter on `BuySkinRequest`).** Cobalt: one click "Buy for 500?", back to "500" at +4.01 s with 6 of 6 parts still Cobalt and the accent ring kept, 0 fires; a press on the card title 0.94 s later disarmed it, 0 fires; a second click 0.6 s after the first bought once (Spraypaint 5000 to 4500, equipped). 4 questions, 3 ended without a buy, 1 confirmed, 1 fire. Nebula (scrolled into view) "Buy for 8200?" sat inside the chip with 7.3 px margins. Not driven: a phone-size read.
- **Persistence.** Owned skins and equipped skin per weapon are in the profile since 2026-09-23 ([[Persistence and Saves]]).

## Extend it
- New palette: append an entry to `Palettes` (swatch, ramp, source, price). No script change. `Palettes_Test` fails if any two swatches sit closer than 52.8 apart in RGB.
- Restore Vip: the comment at the entries says how (set `source = "Vip"`, drop the price, move Gold/Obsidian/Arctic back after Acid); a test asserting "no Vip palette while on hold" will go red and names the Vip-pass tests to bring back.
- Per-weapon signature skins and texture (SurfaceAppearance) skins are designed-for but not built.

## Watch out
- A skin never changes geometry, names or parenting. Renaming a Tool breaks `WeaponViewmodelMotion` (asserts on unknown weapons) and first person.
- `UIStroke` from `Instance.new` defaults to `Contextual`, which on a TextButton strokes the (empty) text; chips need `ApplyStrokeMode.Border`.
- Run unit suites in a fresh Play session: Edit-mode `require` cache served a stale `CosmeticsService` and faked a regression. `execute_luau` has its own require cache on the client too (it built a second `SkinsCardGui`).
- `WeaponaryShopGui` is `ZIndexBehavior.Global`; the card is a separate Sibling ScreenGui on purpose.
- A chip scrolled outside its clipped window swallows clicks with no error.
- One click on a locked chip never bought (measured 2026-11-18: 7 first clicks, 0 fires): the two-click preview has existed since 2026-09-24, so the open item "bring back a buy confirm step" was stale.
- The `rarity` field from the spec was dropped deliberately; nothing reads it.

## History
- 2026-11-18: locked chips ask "Buy for N?": a second click within 4 s buys; the timeout and a press elsewhere end only the question, the preview stays (`armedPalette` apart from `previewPalette`). Measured 7 first clicks 0 fires, 1 confirmed click 1 fire. [[2026-11-18 Open Items Pass]]
- 2026-11-17: a skin choice or purchase for an unowned weapon is refused (`CosmeticsService.ownsWeapon`; `SpraypaintService.handleBuySkinRequest` checks before it charges). [[2026-11-17 Known Issues Pass]]
- 2026-09-24: chip outlines finally render (`ApplyStrokeMode.Border`). [[FPS-Skins-Chip-Outline-And-Weapon-Level-Pill]]
- 2026-09-24: Vip on hold (Arctic 5200, Obsidian 6100, Gold 7100, Nebula 8200 sold for Spraypaint); hover, preview-then-buy, spray burst. [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]
- 2026-09-24: shop slides aside rather than shrinking. [[FPS-Skins-Card-Shop-Slides-Aside]]
- 2026-09-24: card tracks the shop live; shop owns its own responsive scale. [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]]
- 2026-09-24: detached Skins card replaces the in-panel `SkinRow`/`BuyStrip`; catalogue 12 -> 20 (Slate..Fuchsia, Nebula). [[FPS-Skins-Card-Detached-And-Palette-Expansion]]
- 2026-09-24: Spraypaint skin prices raised. [[Revert-Global-Spraypaint-Balance]]
- 2026-09-23: skins persist. [[FPS-Persistence-Phase-3]]
- 2026-09-23: four Spraypaint palettes and the buy strip. [[FPS-Spraypaint-Phase-2]]
- 2026-09-23: Phase 1 close-out, eight palettes (5 Free, 3 Vip), all eight verification rows live. [[FPS-Weapon-Skins-Phase-1]]
- 2026-09-22: chip and row designed in Figma (52x52, four states). [[FPS-Weapon-Skins-Chip-Design]]
- 2026-09-22: monetisation spec (template, later superseded by the design doc). [[FPS-Monetization-Cosmetics-Spec]]

See [[Batch Log]].
