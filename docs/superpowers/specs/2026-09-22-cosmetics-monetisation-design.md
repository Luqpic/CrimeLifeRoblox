# Design: Weapon Cosmetics, Phase 1

**Date:** 2026-09-22
**Status:** Approved in brainstorming. Not yet implemented.
**Supersedes the template at:** `FPSSystem/FPS-Monetization-Cosmetics-Spec.md`

---

## Why this document exists

The template spec was written with Studio detached and is archive-derived throughout. Checking it
against the live place found one premise false and one promise undeliverable. This document records
what was actually decided, and why, so the implementation plan is built on verified ground.

---

## What the live place already had

The template opens: *"The FPS place currently has no Robux monetisation at all -- no game passes, no
developer products, no `MarketplaceService` call anywhere in the archive."*

That is not true. `ReplicatedStorage.Monetization` and `ServerScriptService.Monetization` exist and
are complete:

- **Six developer products selling Cash for Robux** -- 5,000 through 1,000,000 -- granted by
  `grantCash` directly into `leaderstats.Cash`.
- **Six game passes**: `DoubleCash`, `DoubleXp`, `Vip` ("Exclusive weapon skins"), `ExtraSlot`,
  `FastReload` ("25% quicker reloads"), `InfiniteSprint`.
- Every id is `0`. `Constants.isConfigured` treats that as "not configured": the tile renders
  disabled and never prompts, rather than calling `MarketplaceService` with a bad id.
- `Constants.ownedAttributeFor(key)` generates `GamepassOwned_<key>`, deliberately mirroring
  `UpgradeConfig.ownedAttributeFor`.

Two consequences. First, the stub-ownership approach chosen for Phase 1 **already exists** and should
be reused rather than reinvented. Second, the template's central guarantee was already broken.

## The non-pay-to-win guarantee is dropped, deliberately

The template's §15 states one inviolable rule: *"No Robux->Cash product, ever. Cash buys damage. This
is the single line that must not be crossed."* Six such products already exist, and Cash buys the
damage upgrades in `UpgradeConfig`. By the template's own test the game is already pay-to-win.
`DoubleXp` likewise contradicts §2's argument that combat XP must never be boosted, and `FastReload`
and `InfiniteSprint` sell combat power outright.

**Decision: keep the existing surfaces, drop the guarantee.** Cosmetics are added as an additional
surface and `Vip` becomes the skins pass it already claims to be. §3 of the template is struck rather
than left to promise something the code contradicts.

This was decided while every id is still `0`, so no revenue existed to lose either way. Removing the
power sales would have cost nothing today and a great deal after launch; that trade was put to the
owner and this is the answer they gave.

The `Cosmetics` namespace is still kept out of `ShotResolver` and `WeaponUpgradeService`. Not as a
marketing promise now, but because appearance data has no business in the damage path and the
separation keeps both easier to reason about.

---

## Decisions taken

| Question | Answer |
|---|---|
| Are real game passes possible yet? | No -- not published. Build against the existing unconfigured-id pattern; real ids drop in as config. |
| Tint skins or texture skins? | **Tint only** in Phase 1. Zero art pipeline, zero texture memory, provable end to end today. |
| Where do players browse skins? | A **skins row in the weapon's detail panel**, under the existing 3D viewport. |
| Reconcile the P2W conflict how? | **Keep both surfaces, drop the guarantee** (above). |
| Catalogue model? | **Universal palettes** (below). |

## Catalogue model: universal palettes

Measured across the live armoury:

- **29 weapons, 11 distinct visible part names between them.**
- `Body` appears in 29/29 (100%), `TrimA` and `TrimB` in 27/29 (93%), `TrimC` in 26/29 (90%).
- Mean 5.4 visible parts per weapon; 158 in total.

The vocabulary is shared enough that one tint map covers the whole armoury. A skin is therefore a
**palette** -- a named map over `{Body, TrimA..TrimG, Magazine, ChargingHandle, Blade}` -- applied to
any weapon. At eight palettes that is 232 weapon-skin combinations from eight small tables, every
weapon covered on day one including the Knife, and adding a palette later is a five-line edit.

Eight is an illustration, not a requirement. **The launch palette list, and which of them `Vip`
gates, are decided in the implementation plan**, not here -- they are content choices that do not
affect the architecture.

The cost is that a palette cannot flatter one gun's silhouette specifically. Per-weapon signature
skins stay available as a Phase 2 extension: such a skin is a palette whose lookup is additionally
keyed by weapon name, so the resolution path grows rather than being replaced.

---

## Architecture

### New: `ReplicatedStorage.Cosmetics` (verified absent today)

- **`Palettes`** -- the catalogue. Each entry `{ key, name, rarity, tints = { [partName] = Color3 },
  source = "Free" | "Vip" }`. Colours and strings only; no numbers that could reach a damage path.
- **`SkinApplier`** -- `apply(model, palette)` / `remove(model)`, shared by server and client so one
  implementation serves both. Records each part's original `Color` before writing and restores it
  exactly on removal.

### The application rule

**A skin never changes geometry.** It never adds, removes, renames or re-parents a part; it sets
colour properties only. This is not stylistic -- three things in this codebase break otherwise, all
of which have already cost a debugging session:

- `WeaponViewmodelMotion` **asserts** on a weapon it has no profile for, and that exception aborts
  `BlasterController.new`, so the viewmodel is never built and the camera never enters first person.
  A skin that renames a Tool destroys first person for that weapon. Names are load-bearing.
- The same module walks the Motor6D chain at construction to cancel each hand's off-plane drift.
  Adding or removing parts changes that chain.
- The rigs use a core part as the hub: arms Motor6D to it, and the tool weld, `MuzzleAttachment` and
  the trail hang off it. The standing rule is add a mesh rather than replace the core part.

### Two application points

- **World Tool (third person).** Server-side, in `WeaponShopService`'s existing restore path -- the
  same place it already rebuilds carried weapons on respawn. Applying server-side replicates the
  appearance once, to everyone, with no per-client work. It must inherit that path's existing silence
  discipline: a respawn handing back four weapons must not fire four purchase sounds.
- **Viewmodel (first person).** Client-side in `ViewModelController`, **strictly after**
  `WeaponViewmodelMotion.new` has run and the joints are solved. This ordering is load-bearing for the
  reason above.

Both are required. The second is what the buyer sees; the first is what sells the next copy.

### The signal is an attribute

`SkinId` is stamped on the Tool, following the `StunnedUntil` / `BleedingUntil` precedent already in
this codebase: a plain replicated signal that anything wanting to SHOW it can read without the
resolver knowing. The death screen, nameplates and player card can then show a killer's skin with no
new networking. No remote is added for something an attribute already replicates.

### Ownership and persistence

- Ownership reuses `Monetization.Constants.ownedAttributeFor`; `Vip` gates a subset of palettes and
  the remainder are free in Phase 1. Which palettes fall either side is a plan-level content choice.
  Renown gating is Phase 2.
- `EquipSkinRequest` is server-authoritative: the server validates ownership before stamping `SkinId`,
  so a forged request naming an unowned skin is refused.
- The equipped skin per weapon lives in a player attribute, republished the way `LoadoutSlot` already
  is, so a respawn restores it. **No DataStore in Phase 1** -- which is what lets Phase 1 ship before
  the combined-workspace merge.

---

## UI

A row of palette chips in the existing `DetailPanel`, under the rotating `DetailViewport`. Four
states: rest, hover, equipped, locked. Equipped uses the accent-green outline convention already
established on the loadout slots. Selecting a chip applies the palette to the live preview model
immediately -- free, because the preview is already a real model in a viewport, and it means the skin
is seen before purchase rather than after.

Locked palettes show a lock and route to the existing `PromptGamepassPurchase` remote, which already
handles the unconfigured-id case by disabling rather than prompting.

Designed in the existing Figma file, page `02 · Redesign`, against the tokens already there: panel
`#171A22`, raised `#1E222C`, accent `#CBF23C`, the Acid 2px stroke convention. Panel titles are baked
into banner artwork, so a "SKINS" heading is a 4x export through the existing pipeline, not a layout
property.

---

## Verification

Stated as numbers before implementation starts, per the project rule that a change log which cannot
cite a before and after is not finished.

| Claim | Measured how |
|---|---|
| Renders in third person | Read `Color` back off the **live** Tool, not the edit-time model |
| Renders in first person | Camera is `LockFirstPerson` **and** the viewmodel carries the colours |
| Rig undisturbed | Hand-to-weapon gap unchanged from the post-fix figures (worst 0.25, mean 0.041 studs) |
| Removal is exact | Apply then remove; every part's `Color` back to its recorded original |
| Survives respawn | Equip, die, respawn, read it back off the new Tool |
| Damage unaffected | Same weapon skinned and unskinned; identical damage |
| Server-authoritative | Fire `EquipSkinRequest` with an unowned skin; server refuses |
| Not in a hot path | Ownership calls counted: one per player, plus one per purchase |

---

## Phase boundaries

- **Phase 1 (this document).** Palettes, applier, both application points, the skins row, Vip gating,
  session persistence via attributes. Stop and report measurements before Phase 2 begins.
- **Phase 2.** Renown currency and its earn path, a session-locked profile store, developer products.
- **Phase 3.** Crates. Optional, highest reputational risk, may never be worth it.

## Non-goals for Phase 1

- No texture skins. No art pipeline is required to prove the application path.
- No Renown, no DataStore, no seasons, no trading, no gacha.
- No geometry-swapping skins, ever.
- Robbery System is not touched.
- No new purchase plumbing: the existing Monetization service is reused as-is.

## Open items

- The `Vip` game pass id, once the place is published. Until then the tile is disabled by the
  existing unconfigured-id handling and cannot prompt.
- Per-weapon signature skins, if palettes prove too uniform in practice. Phase 2 at the earliest.
