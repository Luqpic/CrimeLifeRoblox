# Renown — Phase 2 Design

## Why this document exists

Phase 1 shipped weapon skins: eight palettes, five free and three behind the `Vip` game pass, applied
as luminance ramps over each weapon's visible parts. It is live, reviewed and pushed. Its one gap as a
monetisation design is that a player who will never spend Robux has nothing to work towards — the free
palettes are handed over at once and the rest are a paywall.

Phase 2 adds **Renown**: a currency earned by playing, spent on a third tier of skins. It gives the
non-paying player a path to cosmetics without weakening the pass, and it gives the paying player a
reason to keep playing after buying it.

This phase deliberately does **not** add persistence. The profile schema is written down here so that
turning persistence on later is a scoped job against a documented contract, but no `DataStoreService`
code is written.

---

## What the live place already has, measured

Read from the running place on 2026-09-23, not assumed:

- **No persistence whatsoever.** Zero `DataStoreService` calls anywhere. Three separate modules —
  `Leveling.Constants`, `Stats.Constants` and `KillStatsService` — carry comments stating session-only
  is deliberate. The earlier claim that persistence existed came from those comments matching a naive
  search for the word; they document its absence.
- **Developer products already work.** `MonetizationService` implements `ProcessReceipt`, and
  `Monetization.Constants.CashTiers` defines six Robux→Cash products from 5,000 to 1,000,000. Phase 2
  adds no new purchase plumbing.
- **Kills already broadcast.** `ServerScriptService.Blaster.Events.Eliminated` is a BindableEvent fired
  by `ShotResolver` as `Fire(shooter, victimHumanoid, damage)`. `KillStatsService` connects to it, and
  its own comment notes it shares that event with another listener — multiple subscribers are the
  established pattern, not a new one.
- **Levels already broadcast.** `LevelingService` publishes `Level`, `XP` and `NextLevelXP` as player
  attributes. It also sets `Level` inside `onPlayerAdded`.
- **Cash is public.** `leaderstats.Cash` is an IntValue, visible in the player list.
- **There is no confirmation dialog anywhere.** The only things matching are a `SwapPrompt` TextLabel
  in the shop's inventory column and the quest dialogue frames. A purchase confirmation is new UI.
- **The detail panel has one free region.** `DetailPanel` is 700x438 with no layout; content occupies
  to y=432; the skins row sits in the only gap, x 0-290, y 372-432. Phase 1's row is a ScrollingFrame
  of 52x52 chips with a 46x46 inset swatch, canvas 466 wide in a 290 window.

---

## Decisions taken

1. **Full progression is the eventual target; nothing persists this phase.** The profile schema below
   names every field that will eventually be saved. No `DataStoreService` code is written now, because
   an unexercised save path is untested risk whose bugs only appear once saving is real.
2. **Renown is earned by kills and level-ups.** Not by survival time, which rewards idling and would
   need anti-AFK machinery for a weaker signal.
3. **Renown buys a third tier of skins.** It never unlocks the `Vip` palettes; that would undercut the
   pass being sold.
4. **The spend surface reuses the existing row's footprint.** No new panel, no modal.

---

## The currency

New instances:

| Path | Responsibility |
|---|---|
| `ReplicatedStorage.Renown.Constants` (ModuleScript) | Earn rates and palette prices. Data only. |
| `ServerScriptService.Renown.Scripts.RenownService` (ModuleScript) | Balance authority: grant, spend, validate. |
| `ReplicatedStorage.Renown.Remotes.BuySkinRequest` (RemoteEvent) | Client asks, server decides. |

The balance replicates as a player attribute, `Renown`, matching `Level`, `XP`, `CriminalKills` and
`PoliceKills`. No remote is needed to read it and no `leaderstats` column is added: Cash is public
because it is the combat economy, and a second column for a cosmetic currency clutters the player list
for every player in the server.

`RenownService` is a ModuleScript, not a Script, because the remote handler and the purchase logic must
be reachable from a unit test. Phase 1 established this: its equip handler was extracted into
`CosmeticsService.handleEquipRequest` precisely so the security ordering could be tested rather than
proven once by hand.

---

## Earn path

**Both hooks are listeners on things that already broadcast. No existing file is modified.**

That property is the point. `ShotResolver`, `KillStatsService` and `LevelingService` are all working,
reviewed code in the damage and progression paths; Phase 1's hardest-won lesson was that appearance and
economy code must not be able to break them.

**Kills.** `RenownService` connects `ServerScriptService.Blaster.Events.Eliminated` independently of
`KillStatsService`, and determines the victim exactly as that service does: `victimCharacter:GetAttribute("Faction")`,
which reads `"Police"` or `"Criminal"`.

**PvP kills earn no Renown, deliberately.** A player's own character carries no `Faction` attribute, so
player kills fall out of that check and count for nothing — which is already how `KillStatsService`
behaves, and how `CashService` behaves, both explicitly so the economy cannot be farmed. Renown must
inherit it: without the exclusion two players could trade kills indefinitely and the earn path becomes
meaningless. This is not an edge case to handle later; it is the difference between a currency worth
having and a number players print at will.

**Level-ups.** `RenownService` connects `player:GetAttributeChangedSignal("Level")`.

**The join guard.** `LevelingService.onPlayerAdded` sets `Level`, so a naive attribute listener pays
out 25 Renown to every player for logging in. `RenownService` records the level seen at join as a
baseline and awards only on a strict increase, by the difference — so a multi-level jump pays for each
level rather than once.

### Rates

All in `Renown.Constants`, tunable without touching logic:

| Source | Renown |
|---|---|
| Thug kill | 2 |
| Police kill | 5 |
| Level-up | 25 per level gained |

Police are weighted higher because `EnemyAI` gives them per-type accuracy and damage overrides that
make them the harder target.

The cheapest skin at 250 is therefore roughly 125 thug kills, or 50 police kills, or ten levels, or a
realistic mix of all three. The intent is that a skin is one good session's work, not a week's. These
figures are a starting point to play-test, not a balance claim.

---

## Catalogue: the Renown tier

Four new palettes, keeping Phase 1's shape exactly — a `swatch` for the chip and a ramp of stops dark
to light, applied by luminance. Chosen to be distinguishable from the existing eight (grey, near-black,
tan, red, chartreuse, gold, purple, ice), each verified at least 60 apart in RGB space from every
other swatch:

| Key | Name | Price | Swatch |
|---|---|---|---|
| `Cobalt` | COBALT | 250 | `#1E3A8A` |
| `Verdigris` | VERDIGRIS | 350 | `#2F7A6B` |
| `Ember` | EMBER | 500 | `#C2410C` |
| `RoseGold` | ROSE GOLD | 750 | `#B76E79` |

The catalogue grows from 8 chips to 12. The row already scrolls — canvas moves from 466 to 698 in the
same 290px window — so no layout changes and nothing in the panel moves.

`Palette` gains two fields: `source` extends to `"Free" | "Vip" | "Renown"`, and `price: number?`,
present only on Renown entries. `Palettes.isVipOnly` is unchanged; a new `Palettes.priceOf(key)`
returns the price or nil.

---

## Spend surface

An unowned Renown chip renders as a dimmed swatch with a small coin badge in place of the lock glyph —
distinguishable at a glance from a Vip chip, which stays locked.

Clicking one swaps the row's contents **in place** for a confirm strip: the palette name, the price,
a BUY button and a dismiss. The strip occupies the same 290x60 the row does, so the panel's only free
region is never exceeded and nothing can be displaced. Dismissing, or completing the purchase, restores
the chips.

When the balance is short, BUY is disabled and the price renders in the danger token `#FF4B4B`. The
player is never prompted to buy Robux from here; that is the Cash shop's job and conflating them makes
the currency feel like a paywall rather than a reward.

On success the chip becomes owned and the **server** equips the skin in the same call — it writes the
`EquippedSkin_<weapon>` attribute directly rather than making the client fire a second remote, so a
purchase cannot half-complete into "owned but not worn". Phase 1's existing machinery does the rest
unchanged: the attribute change drives `repaint`, which already applies the equipped key to the preview
model, and `CosmeticsService.refresh` re-dresses the held weapon while the viewmodel's `SkinId`
listener catches first person.

---

## Server authority

`RenownService.handleBuyRequest(player, paletteKey)`, reachable by test, called by the remote:

1. `paletteKey` is a string.
2. The palette exists.
3. Its `source` is `"Renown"` — a free or Vip key is refused, so this path can never be used to
   sidestep the pass.
4. It is not already owned.
5. The balance is at least the price.

Then deduct, set `SkinOwned_<key>` on the player, and publish the new balance. Ownership mirrors the
existing `WeaponOwned_*` convention.

The attribute name is built by `Renown.Constants.ownedAttributeFor(key)`, living beside the rates in
ReplicatedStorage so both sides derive it from one place rather than hardcoding a prefix twice — the
same reason `Monetization.Constants.ownedAttributeFor` exists. It must sanitise as
`CosmeticsService.attributeFor` does: Phase 1 measured that 16 of the 29 weapon names contain
characters Roblox rejects in an attribute name, and a palette key added later could do the same.

`CosmeticsService.ownsPalette` extends by one branch: a Renown palette is owned when
`SkinOwned_<key>` is true. Free and Vip behaviour is untouched, and Phase 1's eleven ownership tests
must continue to pass unchanged.

Every Renown mutation is server-side. The client displays a balance it is told and asks for purchases
it cannot grant itself.

---

## Profile schema — written, not built

Nothing below is implemented this phase. It is the contract a later phase implements.

```
Profile = {
    version        = 1,          -- migration marker; bump when a field's meaning changes
    renown         = 0,          -- RenownService
    skinsOwned     = {},         -- [paletteKey] = true         RenownService
    equippedSkin   = {},         -- [weaponName] = paletteKey   CosmeticsService
    cash           = 0,          -- CashService (leaderstats.Cash today)
    level          = 1,          -- LevelingService
    xp             = 0,          -- LevelingService
    kills          = {},         -- { Criminal = n, Police = n } KillStatsService
    weaponsOwned   = {},         -- [weaponName] = true         WeaponShopService
    weaponUpgrades = {},         -- [weaponName] = level        WeaponUpgradeService
    loadout        = {},         -- [slotIndex] = weaponName    WeaponShopService
}
```

Notes for whoever implements it:

- Every field above is currently held in a per-service in-memory table or a player attribute, and every
  owning service documents session-only as deliberate. Persisting is a reversal of a considered
  decision, not an oversight — it needs its own design pass.
- Session locking matters more here than the save format. Two servers holding one player's profile is
  how progression gets silently rolled back.
- `version` exists so a later change to a field's meaning is a migration rather than a data-loss event.
- The riskiest field is `cash`, because it is the one a player can convert Robux into. A lost save
  after a Cash purchase is a refund request.

---

## Verification

Stated as numbers before implementation starts, per the project rule that a change log which cannot
cite a before and after is not finished.

| Claim | Measured how |
|---|---|
| Kills award Renown | Kill a Thug and a Police rig; balance moves by exactly 2 and 5 |
| Level-ups award Renown | Grant XP to cross a level; balance moves by exactly 25 |
| Joining awards nothing | Join a fresh session; `Renown` is 0 after `Level` is published |
| PvP kills award nothing | Kill another player; balance unchanged, matching CashService's anti-farm rule |
| A multi-level jump pays per level | Force a two-level gain; balance moves by 50, not 25 |
| Purchase deducts and grants | Buy Cobalt at 250; balance falls by 250 and `SkinOwned_Cobalt` is true |
| Insufficient funds refused | Attempt a purchase below price; balance and ownership both unchanged |
| Double purchase refused | Buy the same palette twice; balance falls once |
| A Vip key cannot be bought with Renown | Fire `BuySkinRequest("Gold")`; refused, balance unchanged |
| Forged request refused | Fire `BuySkinRequest` for an unowned palette with a zero balance; refused |
| Phase 1 still passes | Palettes, SkinApplier and CosmeticsOwnership suites all still green |
| The panel is undisturbed | `AbsolutePosition` of the five panel witnesses unchanged, same-session A/B |
| Nothing persists | A rejoin starts at 0 Renown with no skins owned |

---

## Phase boundaries

- **Phase 1 (shipped).** Palettes, applier, both application points, the skins row, Vip gating.
- **Phase 2 (this document).** Renown, its earn path, the Renown skin tier, the spend surface, and the
  profile schema on paper. Stop and report measurements before Phase 3.
- **Phase 3.** Persistence: the session-locked profile store implementing the schema above. Optionally
  a Robux→Renown product, decided deliberately rather than by drift.
- **Phase 4.** Crates. Optional, highest reputational risk, may never be worth it.

## Non-goals for Phase 2

- No `DataStoreService`, no persistence, no session locking.
- No Robux→Renown developer product. It is a legitimate lever and most games ship one, but it competes
  directly with the earn path this phase exists to create. Deciding it deliberately in Phase 3 is
  better than absorbing it now.
- No new purchase plumbing: `MonetizationService` and its Cash tiers are reused as-is.
- Renown never unlocks a `Vip` palette.
- No changes to `ShotResolver`, `KillStatsService`, `LevelingService`, `CashService`,
  `WeaponShopService` or `WeaponUpgradeService`. The earn path is listeners only.
- Robbery System is not touched.

## Open items

- The earn rates and the four prices are starting points for play-testing, not balance claims.
- Whether Renown should appear on the HUD during play, or only in the shop. Phase 2 announces gains
  through the existing `NotificationController` and shows the balance in the shop; a persistent HUD
  counter can follow if it turns out players cannot find it.
- The coin badge for an unowned Renown chip needs a glyph. Phase 1's lock was built from two Frames
  after `upload_image` refused the Figma export as an untrusted URL; the same approach applies unless
  that upload path starts working.
