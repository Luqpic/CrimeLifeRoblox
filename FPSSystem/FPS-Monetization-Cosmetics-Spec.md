# Spec: Cosmetics Monetisation — Skins, Renown, and the Booster Pass

**Date:** 2026-09-22
**Status:** **SPEC — nothing implemented.** No Studio instance was read while writing this; Studio was
not attached (`list_roblox_studios` returned empty). Every instance path below is derived from the
change-log archive in this folder and **must be confirmed live before any edit**, per the project's
read-before-you-edit rule.

**This is not a change log.** It is the design that change logs will later record against. Change logs
for the work described here should be written per phase, in the usual Summary / Cause / Changes /
Notes shape, one commit each.

**How to use this document.** It is written to be handed to a fresh implementation chat. Do not hand
over the whole thing at once — prompt **one phase at a time** (Phase 1, then 2, then 3). Each phase is
independently shippable and independently revenue-positive. Phase 1 deliberately has no dependency on
a save layer, so it can ship into the place as it stands today.

---

## 1. The commercial thesis

> **Correction, 2026-09-22, after checking against the live place.** The paragraph below is wrong and
> is kept only so the correction makes sense. `ReplicatedStorage.Monetization` and
> `ServerScriptService.Monetization` already exist: six developer products selling Cash for Robux
> (5,000 to 1,000,000), and six game passes including `Vip` ("Exclusive weapon skins"), `DoubleXp`,
> `FastReload` and `InfiniteSprint`. Every id is `0`, which the code treats as unconfigured -- the
> tile renders disabled and never prompts. See
> `docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md` for what was actually built on.

The FPS place currently has **no Robux monetisation at all** — no game passes, no developer products,
no `MarketplaceService` call anywhere in the archive. Cash is a soft currency that buys weapons and
damage upgrades, and it resets when the player leaves.

The opportunity is not "add a shop" — a shop already exists, is good, and is proven
(`FPS-Weaponary-Shop-Refactor.md`, `FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md`). The
opportunity is that **the game has 28 weapon rigs, a rotating 3D detail viewport, a death screen, a
player card and nameplates — four separate surfaces where one player's appearance is shown to another
player — and none of them currently sell anything.**

The money in an FPS is not power. It is identity, and the visibility of that identity to other people.
A skin is worth Robux precisely because someone else sees it. Every one of the four surfaces above is
an advertising slot the game already renders and already pays the performance cost for.

The design below therefore does three things, in priority order:

1. **Make cosmetics exist** and be visible in first person, third person, and on the surfaces above.
2. **Make them earnable by playing** (a soft currency, Renown), so the catalogue has perceived value
   and free players are participants rather than spectators.
3. **Sell the time-skip and the premium tier** for Robux — never the power.

### Why this will not read as a cash grab

Because of a structural rule, not a promise (see §3): the only things Robux can buy are appearance and
the *rate at which cosmetics are earned*. Robux cannot touch damage, health, fire rate, ammo, cash, or
combat level. This is enforced by keeping cosmetic data in a table that the damage path never reads.

---

## 2. Currency model

Three currencies, with a hard wall between two of them.

| Currency | Earned by | Spends on | Robux can buy it? |
|---|---|---|---|
| **Cash** (exists) | Enemy kills, cash drops | Weapons, damage upgrades | **No. Never.** |
| **Renown** (new) | Kills, same `Eliminated` signal Cash uses | Cosmetics only | No (see note) |
| **Robux** | Real money | Premium skins, bundles, Booster pass | — |

**The wall:** Cash buys power. Renown buys appearance. They are separate balances, and no code path
converts one into the other in either direction. This is the whole non-pay-to-win guarantee, and it is
one line of policy that the implementation must never violate: **there is no Cash↔Renown exchange, and
no Robux→Cash product.** The moment a "500 Cash for 99 Robux" product exists, the game is pay-to-win,
because Cash buys the damage upgrades in `UpgradeConfig`.

**Note on Renown and Robux:** Renown is deliberately *not* sold directly for Robux either, even though
it only buys cosmetics. Selling the currency invites a treadmill design. Instead Robux buys *the
items* directly, and buys the *Booster* that doubles Renown earn rate. This keeps the catalogue
legible — a player always knows what they are getting for their money.

### Why the XP multiplier boosts Renown and not combat level

The original idea was a 2× XP game pass. `FPS-Kill-Leveling-System.md` records that every level-up
grants **a small max-health bonus** plus a cash bonus. A pass that accelerates that curve is therefore
selling faster access to more health and more cash — mild, but it is pay-for-power-speed, and it is
exactly the thing that gets a game called pay-to-win in its own comments section.

So: **combat level XP is never boosted.** Everyone levels at the same rate. The Booster multiplies
**Renown only**, which buys appearance only. The convenience boost survives intact, the accusation
does not.

This also creates the progression track a season pass would later hang off, without building seasons
now.

---

## 3. The structural non-pay-to-win guarantee

> **STRUCK, 2026-09-22.** This section cannot be delivered and is retained only as a record of the
> original intent. The place already sells Cash for Robux, and Cash buys the damage upgrades in
> `UpgradeConfig` — so by this section's own test the game is already pay-to-win. `DoubleXp`
> contradicts §2, and `FastReload` and `InfiniteSprint` sell combat power outright. The owner's
> decision was to keep those surfaces and drop this guarantee rather than remove live revenue
> surfaces. Cosmetics are an additional surface; `Vip` becomes the skins pass it already claims to be.
>
> The `Cosmetics` namespace is still kept out of `ShotResolver` and `WeaponUpgradeService` — not as a
> promise to players, but because appearance data has no business in the damage path.

Stated precisely, so it can be checked rather than believed:

1. A skin is **appearance data only** — a set of `SurfaceAppearance` instances and/or `Color3` values,
   keyed by part name. It contains no numbers.
2. Skin data lives in `ReplicatedStorage.Cosmetics.*`, a namespace that
   `ServerScriptService.Blaster.Scripts.ShotResolver` and
   `ServerScriptService.Weapons.Scripts.WeaponUpgradeService` **do not require and must never
   require**. A reviewer can verify the guarantee with one `grep`.
3. Damage is already recomputed from the weapon's stock value plus the player's upgrade level, never
   stacked incrementally (`FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System.md`). Cosmetics are not
   an input to that computation and adding one would require changing that function's signature —
   i.e. it cannot happen by accident.
4. Renown cannot be spent on anything in `ServerStorage.Weapons` or `Weapons.UpgradeConfig`.

**Acceptance test for the guarantee:** `grep -r "Cosmetics" ` over the server weapon/blaster scripts
returns nothing outside the cosmetics services themselves. If it ever returns a hit inside
`ShotResolver` or `WeaponUpgradeService`, the guarantee is broken.

---

## 4. Phasing

Three phases. **Phase 1 ships revenue with no save layer**, which matters because this place is a
module that will later be merged into a combined workspace with Robbery System and others — so the
less this depends on place-local persistence before that merge, the better.

| Phase | Ships | Needs persistence? | Revenue |
|---|---|---|---|
| **1** | Booster game pass + 4–6 flagship skin **game passes**, skin rendering, all four display surfaces | **No** — Roblox itself remembers game pass ownership, permanently, across places and rejoins | Live |
| **2** | Renown currency, the earnable catalogue, `PlayerProfile` save module, developer products | Yes | Recurring |
| **3** (optional) | Crates / gacha, seasonal rotation | Yes | Highest, highest risk |

Phase 1 is the whole point of the phasing. `MarketplaceService:UserOwnsGamePassAsync` is authoritative
and permanent without a single DataStore call on our side, so a player who buys a skin today still has
it after the combined-workspace merge, regardless of what happens to place-local data in between.

---

## 5. How a skin is applied — the critical technical rule

**A skin never changes geometry. It never adds, removes, renames or re-parents a part. It only adds
appearance children and sets colour properties.**

This is not stylistic. Three things in the archive break if it is violated:

- `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` **asserts** on a weapon it has no profile
  for, and that exception aborts `BlasterController.new`, so the viewmodel is never built and the
  camera never switches to first person (`FPS-Knife-Bleed-Melee.md`). **A skin that renames a Tool
  from `AK47` to `AK47 Gold` therefore destroys first person for that weapon entirely.** Names are
  load-bearing identifiers. Skins must be a separate attribute.
- The same module's `frameInBody` walks the Motor6D chain at `Motion.new` to cancel each hand's
  off-plane drift (`FPS-Viewmodel-Hands-Off-Weapon.md`). Adding or removing parts changes that chain.
  Appearance children do not.
- The weapon rigs use a core part as the rig hub — arms Motor6D to it, and the tool weld,
  `MuzzleAttachment` and the trail all hang off it. The archive's standing rule is **add a mesh rather
  than replace the core part**. A skin must not even come close to it.

### The two skin classes

**Tint skins** — a map of `partName → Color3`. Zero texture memory, zero art pipeline, authored in
seconds. This is the Renown-earnable tier and it lets the catalogue launch with real breadth on day
one without commissioning anything.

**Texture skins** — a map of `partName → SurfaceAppearance` (ColorMap / NormalMap / RoughnessMap /
MetalnessMap). Real art cost, real memory cost, real visual impact. This is the Robux tier, and the
cost asymmetry is exactly what justifies the price difference to a player.

### Application mechanics

```
apply(model, skinDef):
  for each part in model:
    if skinDef.tints[part.Name]      -> record original Color, set part.Color
    if skinDef.surfaces[part.Name]   -> clone the SurfaceAppearance, parent to part, tag it
remove(model):
  destroy every tagged SurfaceAppearance, restore every recorded original Color
```

Tag the clones (`CollectionService` tag, or a fixed child name) so removal is exact and never has to
guess. Removal must be non-destructive — the underlying weapon returns to stock.

### Where it is applied, and by whom

- **World Tool (third person — what other players see).** Server applies it when it hands the weapon
  back on spawn, in the same place `WeaponShopService` already rebuilds carried weapons from its
  ownership record. Applying server-side means the appearance replicates once, to everyone, with no
  per-client work.
- **Viewmodel (first person — what the buyer sees).** Built client-side by `ViewModelController` from
  `ReplicatedStorage.Blaster.ViewModels.<Name>`. The client reads the equipped Tool's `SkinId`
  attribute and applies the same definition **after** the viewmodel is built and its joints are
  solved.

Both are required. The second is what the buyer experiences; the first is what sells the next copy.

### Why an attribute, not a remote

Stamp `SkinId` as an attribute on the Tool. The archive already established this pattern: `StunnedUntil`
and `BleedingUntil` are stamped on the target's root part as *"a plain replicated signal, so anything
that wants to SHOW it can read it without the resolver knowing"* (`FPS-Knife-Bleed-Melee.md`). The
death screen, nameplates and player card can then all read a killer's equipped skin with **no new
networking whatsoever**. Do not add a remote for something an attribute already replicates.

---

## 6. Instance tree — what gets added

All paths archive-derived, **unconfirmed live**.

### ReplicatedStorage

```
Cosmetics/                                  (new)
  SkinConfig            ModuleScript  — the catalogue: every skin, its tier, price, target weapon
  SkinApplier           ModuleScript  — apply/remove, shared by server and client. ONE implementation.
  Remotes/
    EquipSkinRequest    RemoteEvent   — client asks to equip; server validates and decides
    PurchaseSkinRequest RemoteEvent   — client asks to buy with Renown
    RenownChanged       RemoteEvent   — server pushes balance changes to the owner
  Skins/                              — the actual appearance assets
    <SkinId>/           Folder        — SurfaceAppearance instances named for their target part
```

`Skins` **must** live in ReplicatedStorage, not ServerStorage: the client needs them to skin the
viewmodel and to render shop previews, and `ServerStorage` does not replicate — a trap this archive
has already paid for twice (`FPS-Weapon-Icon-Decals.md`,
`FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System.md`).

```
GuiTemplates/
  SkinCard              — mirrors the existing WeaponCard, including its hover outline
  SkinsPanel            — or a new tab inside the existing WeaponaryShop template (preferred)
```

### ServerScriptService

```
Cosmetics/Scripts/
  RenownService         — listens to the existing Eliminated signal; grants Renown; applies Booster
  CosmeticsService      — ownership record, equip validation, applies skins to spawned weapons
  MonetisationService   — the ONLY script that talks to MarketplaceService. ProcessReceipt lives here.
```

### StarterPlayer.StarterPlayerScripts

```
CosmeticsController     — the Skins tab, previews, equip, purchase prompts
```

Everything else is a small edit to an existing script, listed per phase below.

---

## 7. Data schemas

### Skin definition (`SkinConfig`)

```lua
{
  id       = "AK47_Gilded",        -- unique, permanent, NEVER reused after retirement
  weapon   = "AK47",               -- must match the Tool name in ServerStorage.Weapons exactly
  display  = "Gilded",             -- what the player reads. The weapon name is shown beside it.
  tier     = "Premium",            -- Common | Rare | Premium | Exclusive
  class    = "Texture",            -- Tint | Texture
  tints    = { Body = Color3.fromRGB(...), Magazine = ... },   -- Tint class only
  renown   = 800,                  -- nil = not earnable, Robux only
  gamePass = 000000,               -- nil unless sold as its own pass (Phase 1 flagships)
  product  = 000000,               -- developer product id (Phase 2)
}
```

**`id` is permanent.** It is what lands in save data. Renaming or reusing one silently gives players
the wrong skin after a merge. Retire, never recycle.

**`weapon` must match exactly.** The shop already proves this style of data-driven binding works:
`WeaponShopService` builds its catalogue from every Tool carrying a `Category`, which is why the Knife
reached the shop *with no shop code touched*. Skins should inherit that property — adding one is a
data change, not a code change.

### Player profile (Phase 2)

Namespaced from day one, because this place merges into a combined workspace later. One profile per
user, sub-tables per system, so Robbery System and anything else slot in beside it without a rewrite:

```lua
{
  version   = 1,
  Cosmetics = { owned = { ["AK47_Gilded"] = true }, equipped = { AK47 = "AK47_Gilded" }, renown = 1240 },
  -- Weapons = {...}, Leveling = {...}, Robbery = {...}  -- added later, by their own systems
}
```

`version` is present from the first write so a migration has something to branch on. The save module
must expose a narrow interface (`get(player)`, `update(player, fn)`) and own its own retry/session
locking — it must not be reachable by other systems poking the table directly.

### Remote contracts

| Remote | Direction | Payload | Server does |
|---|---|---|---|
| `EquipSkinRequest` | C→S | `skinId` or `nil` to clear | Validates ownership, then equips. **Never trusts the client.** |
| `PurchaseSkinRequest` | C→S | `skinId` | Validates tier is Renown-earnable, balance sufficient, not already owned; debits; grants |
| `RenownChanged` | S→C | `newBalance, delta` | Owner only |

Validation mirrors `WeaponShopService`, which already *"validates every purchase: ownership, the
four-weapon cap, the swap target, and funds are all checked before anything is charged"*. Same
discipline, no exceptions: the client requests, the server decides.

---

## 8. The four conversion surfaces

This is the section that answers "how do I get players to spend". Each one already exists and already
renders; each needs a small addition.

**1. The shop preview — the single highest-leverage change.** The detail panel already clones the
selected weapon's model, frames it from its bounding box and spins it. Apply the skin to that clone
and a player sees the skin *on the gun they already own* before paying. Locked skins must be
previewable — hiding them behind the purchase kills the sale. Show the price, show the Renown progress
(`340 / 800`), let them spin it.

Watch the pivot trap: the archive found that spinning about a weapon's *authored* pivot makes large
rifles orbit rather than turn in place; spin about the centred origin
(`FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md`). Reuse the existing viewport code rather
than writing a second one, and tear the spin down when the panel closes, as the existing code does.

**2. The death screen — every death becomes an advertisement.** When a player is killed, show the
killer's name *and their equipped skin*. This is the strongest organic driver in the genre: the moment
of highest attention is the moment you see what beat you.

Trap: the death screen's words are **baked into the Figma artwork**, not set in a script — changing
"YOU WERE ELIMINATED" to "YOU DIED" was an image export, not a property edit
(`FPS-Death-Screen-You-Died-And-Alignment.md`). A killer/skin line is therefore a **new dynamic
TextLabel**, positioned alongside the baked banner, not an edit to it.

**3. The player card.** It already shows name, photo, health and level. Add the equipped skin (or a
small showcase of owned ones). `/view <username>` already works, so one player can inspect another's
collection with no new networking — the card reads data that already replicates.

**4. Nameplates.** Optional, and the one to be most careful with: a small badge for Booster owners or
a chosen title. Keep it tasteful. Nameplate scale has already been tuned once
(`FPS-Nameplate-Scaling-And-Death-Hud-Hide.md`); do not undo that work for a badge.

### Two soft levers, deliberately kept mild

- **A featured rotation.** A handful of skins highlighted weekly, driven entirely by data in
  `SkinConfig` (a `featuredUntil` field), no code change to rotate. Creates a reason to come back
  without a countdown-timer-and-flashing-red treatment.
- **Visible Renown progress.** A locked skin showing `340 / 800` converts twice: some players grind,
  some players buy. Both outcomes are good, and neither requires pressuring anyone.

**Deliberately excluded:** first-purchase-only discounts that expire on a timer, pop-ups on join,
anything that interrupts the player to sell. They raise short-term conversion and cost more in
sentiment than they return.

---

## 9. Earning Renown

`ShotResolver` fires an `Eliminated` signal. `CashService`, `LevelingService` and `QuestService` all
already listen to it — *"All three listen to `Eliminated`, and none of them had to learn that bleeding
exists"* (`FPS-Knife-Bleed-Melee.md`).

So `RenownService` listens to the **same existing signal** and `ShotResolver` is not touched at all.
That is the correct seam and it is already proven by three consumers.

```
on Eliminated(victim, killer, ...):
    if killer is a player:
        base   = Renown for the victim's kind (mirror the tiered cash-drop values)
        amount = base * (ownsBooster(killer) and 2 or 1)
        credit(killer, amount)
```

`ownsBooster` reads a **cached** ownership flag — see §10.

---

## 10. Optimisation rules

These are requirements, not suggestions. Two of them are the difference between a smooth game and a
stuttering one.

**1. Cache game pass ownership. Never call `UserOwnsGamePassAsync` in a hot path.** It is a web
request. Call it **once per player on join**, store the result, and refresh it only on
`MarketplaceService.PromptGamePassPurchaseFinished`. Calling it per kill would put an HTTP round trip
inside combat. Wrap the join-time call in `pcall` and default to *not owned* on failure, then retry —
never hard-fail a player's session on a web hiccup.

**2. Apply skins on equip and spawn only.** Never per frame, never on a loop. The apply operation
touches a handful of parts; doing it once is free, doing it every frame is a stall.

**3. Budget texture memory deliberately.** Every unique `SurfaceAppearance` map set is loaded memory,
and a meaningful share of the playerbase is on mobile. Keep Texture-class skins to a curated few and
let the Tint class carry catalogue breadth. A tint skin costs nothing but three numbers.

**4. Publish the catalogue once.** The weapon catalogue is already published for clients to browse;
follow the same shape. Do not re-send skin data per player per panel open.

**5. Preload deliberately.** The archive already preloads weapon assets and reports load times
(`icon loaded, equip 0.21s, hits 1.36s`). Skin textures should be preloaded the same way, so the first
equip does not pop in grey.

**6. Tear down previews.** The existing detail panel already tears down its spin on close. Any preview
added must do the same, or the shop leaks a running connection per open.

---

## 11. Platform and compliance

- **`ProcessReceipt` is set exactly once, on the server, in `MonetisationService` alone.** Two handlers
  in one place means one silently wins and purchases are lost. It must return
  `Enum.ProductPurchaseDecision.PurchaseGranted` **only after the grant is durably saved** — returning
  it before the save means a failed save is a paid-for item that vanishes, with no way to recover it.
  Return `NotProcessedYet` on any failure so Roblox retries.
- **Game passes need no save layer.** Ownership is Roblox's record, permanent, and survives the
  workspace merge. This is why Phase 1 leads with them.
- **Developer products need the save layer to be correct before they are enabled.** Do not ship a
  consumable product against session-only data.
- **Gacha (Phase 3) requires disclosed odds.** Roblox policy requires that paid randomised item
  mechanics display their odds, and there are additional restrictions around minors in some regions.
  Confirm the current policy text before building it — do not take this document's summary as
  authoritative on a rule that changes.
- **Pricing.** Roblox takes a platform cut on in-experience sales (developer receives roughly 70% —
  verify the current rate). Suggested starting points, all tunable from data:
  Booster pass ~199–399 R$; Tint skins ~49–99 R$ or Renown-only; Texture skins ~199–499 R$; a founder
  bundle ~799 R$. Price discovery matters more than any number here — ship, watch, adjust.

---

## 12. Adding a skin after launch — the five-minute path

This is the "future update friendly" requirement, made concrete. After Phase 2, adding a new tint skin
should require **no code change at all**:

1. Add one entry to `SkinConfig`.
2. For a Texture skin, add a folder of `SurfaceAppearance` instances under
   `ReplicatedStorage.Cosmetics.Skins.<SkinId>`, each named for the part it targets.
3. For a Robux-sold skin, create the pass/product on the Roblox site and paste its id into the entry.

Nothing else. The shop tab builds itself from the config, exactly as the weapon shop builds itself from
every Tool carrying a `Category` — which is why the Knife reached the shop with no shop code touched.
**If adding the second skin requires touching a script, the data model is wrong and should be fixed
before the catalogue grows.**

The same property is what makes a season pass cheap to add later: the Renown track already exists, so a
season is a reward table over a currency that is already earned and already spent.

---

## 13. Traps inherited from this archive

Each of these cost a debugging session already. They apply directly to this work.

- **Studio's Edit-mode module cache serves a stale module.** Tooling that requires a module it has just
  edited must **clone-require**, or it measures and exports the old behaviour and looks like a logic
  bug (`FPS-Viewmodel-Hands-Off-Weapon.md`). This will bite anyone iterating on `SkinApplier`.
- **`WeaponViewmodelMotion` asserts on an unknown weapon name**, aborting `BlasterController.new` and
  killing first person. Never rename a Tool or viewmodel folder to express a skin.
- **`ServerStorage` does not replicate.** Skin assets the client needs live in `ReplicatedStorage`.
- **`TextureId` is a property, not an attribute**, so it does not travel in a generic attribute loop and
  needs its own line (`FPS-Weapon-Icon-Decals.md`). Relevant if skins ever carry their own shop icon.
- **Panel titles are baked into the banner artwork.** A "SKINS" tab title is a Figma export, not a
  layout property (`FPS-Death-Screen-You-Died-And-Alignment.md`, and the project's own UI notes).
- **Arm the purchase sound on the click, not the grant.** Restoring weapons on respawn goes through the
  same path as a purchase; the existing code distinguishes them so a respawn that hands back four
  weapons is silent. Skin restore-on-spawn must inherit that discipline.
- **`UIPadding` offsets children rather than insetting the frame**, and a `CanvasGroup`'s
  `GroupTransparency` does not fade its own `UIStroke`. Both matter for the new card template — reuse
  `WeaponCard`, which has already solved them.
- **Reuse `MenuFovBlur` and `CameraAuthority`.** Any new panel must raise and lower the shared blur
  (which reference-counts, deliberately) and route camera claims through the arbiter rather than
  writing field of view directly (`FPS-UltimateUIPack-Effects-Integration.md`).
- **Assets named after a thing are frequently not that thing.** The enemy outfit pass found that only
  four of fourteen marketplace references were what they claimed
  (`FPS-Enemy-Marketplace-Outfits.md`). Check every texture asset before it ships, and strip any
  scripts that ride along with a marketplace asset.

---

## 14. Verification plan

The project rule is that a change log which cannot cite a before and after number is not finished.
These are the numbers this work should produce.

| Claim | How it is measured |
|---|---|
| Skin renders in third person | Read the applied part's `Color` / child `SurfaceAppearance` back off the live Tool, not the edit-time model |
| Skin renders in first person | Confirm camera is `LockFirstPerson` and the viewmodel carries the applied appearance — the Knife pass proves the viewmodel can silently fail to build |
| Skin does not disturb the rig | Hand-to-weapon gap re-measured after applying: must stay at the post-fix figures (worst 0.25, mean 0.041 studs) |
| Skin survives respawn | Equip, die, respawn, read the appearance back off the new Tool |
| No pay-to-win leak | `grep` for the cosmetics namespace inside `ShotResolver` and `WeaponUpgradeService` returns nothing |
| Damage unchanged by skin | Fire the same weapon skinned and unskinned; damage figures identical |
| Booster multiplies Renown only | Kill with and without the pass: Renown 2×, Cash unchanged, combat XP unchanged |
| Ownership is server-authoritative | Fire `EquipSkinRequest` with an unowned `skinId` from the client; server refuses |
| Ownership call is not in a hot path | Count `UserOwnsGamePassAsync` calls across a session: one per player, plus one per purchase |
| Purchase is durable | Buy, leave, rejoin, confirm the item is still owned |

State plainly in each change log which of these were confirmed live and which still need a person.

---

## 15. Explicit non-goals

Out of scope for this design. Each is a deliberate omission, not an oversight.

- ~~**No Robux→Cash product, ever.** Cash buys damage. This is the single line that must not be
  crossed.~~ **Struck:** six such products already existed before this spec was written. See §3.
- **No boosted combat XP.** The Booster touches Renown only.
- **No stat-bearing cosmetics** — no "skins with +2 damage", no weapon variants that are cosmetics in
  name only.
- **No seasons in Phase 1 or 2.** The Renown track is designed so seasons *can* be added; they are not
  being built now.
- **No trading or player-to-player marketplace.** Enormously more surface area, including fraud and
  moderation, for no additional revenue at this stage.
- **No gacha until Phase 3**, and only with disclosed odds and a deliberate decision that the
  reputational trade is worth it.
- **No geometry-swapping skins**, per §5.
- **Robbery System is not touched.** It is a separate project. Cosmetics are designed to merge cleanly
  later via the namespaced profile, not to reach across now.

---

## 16. Open questions for the implementation chat

1. **Which weapons get flagship skins first?** Recommend the three most-used, not the three most
   expensive — a skin sells on how often its owner is seen holding it.
2. **Tint-only launch, or one Texture skin at launch?** A single premium Texture skin at launch proves
   the price ceiling; tint-only proves the pipeline more cheaply.
3. **Does the Booster also grant a cosmetic?** A Booster-exclusive skin or badge makes the pass visible
   to other players, which sells more passes. Recommended, and cheap.
4. **Which save library for Phase 2?** A session-locked profile store is the standard answer; whichever
   is chosen must own session locking rather than writing raw `DataStoreService` calls.
5. **Confirm every instance path in §6 against live Studio** before the first edit. This document was
   written with Studio detached and is archive-derived throughout.
