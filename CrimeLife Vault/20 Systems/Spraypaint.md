---
type: system
tags: [system, currency, spraypaint, cosmetics, fps]
updated: 2026-11-17
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-renown-phase-2-design.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Per-Weapon-Spraypaint.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Revert-Global-Spraypaint-Balance.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Spraypaint-Badge-Beside-Price-Label.md", "CrimeLifeRoblox/.superpowers/sdd/per-weapon-spraypaint-report.md", "CrimeLifeRoblox/.superpowers/sdd/revert-global-spraypaint-report.md", "CrimeLifeRoblox/FPSSystem/Spraypaint/Constants.luau", "CrimeLifeRoblox/FPSSystem/Spraypaint/SpraypaintService.luau", "CrimeLifeRoblox/FPSSystem/Spraypaint/SpraypaintHud.luau"]
---

# Spraypaint

**Skills:** `roblox-game-systems`, `roblox-data-stores`, `roblox-monetization` (load these for work here)

## What it does
The cosmetic currency. Earned only by killing NPCs and levelling up, spent only on weapon skins ([[Cosmetics and Skins]]). One balance per player. It never buys power and cannot be bought or converted from Cash. It was called "Renown" in the Phase 2 design (`docs/superpowers/specs/2026-09-23-renown-phase-2-design.md`) and renamed Spraypaint.

## Where it lives
- `ReplicatedStorage.Spraypaint.Constants` (`ATTRIBUTE = "Spraypaint"`, `ICON_ASSET_ID`, `KILL_SPRAYPAINT`, `LEVEL_SPRAYPAINT`, `spraypaintForFaction`, `ownedAttributeFor`), `ReplicatedStorage.Spraypaint.Remotes.BuySkinRequest`.
- `ServerScriptService.Spraypaint.Scripts.SpraypaintService` (`balanceOf`, `grant`, `spend`, `onEliminated` / `awardForVictim`, `onLevelChanged`, `handleBuyRequest`, `start`) and `SpraypaintRunner` (the only caller of `start()`).
- `StarterPlayer.StarterPlayerScripts.SpraypaintHud` (gain toast, kill toast), the `SpraypaintChip` balance pill in the Weaponary `DetailPanel`.
- Tests: `ServerStorage.UnitTest.Cases.SpraypaintConstants_Test`, `SpraypaintService_Test`, `SpraypaintTier_Test`.
- Repo copies: `CrimeLifeRoblox/FPSSystem/Spraypaint/*.luau`.

## How it works
- **Earn.** `SpraypaintService` listens to the existing `ServerScriptService.Blaster.Events.Eliminated` BindableEvent and to the `Level` player attribute; no existing file was edited to add the earn path. Criminal kill +2, Police kill +5 (keyed by the victim's `Faction` attribute), +25 per level gained. Anything that is not a recognised NPC faction pays 0, including `nil` — players carry no `Faction`, so PvP pays nothing (anti-farming).
- **Balance.** A single `Spraypaint` player attribute, persisted as the scalar `spraypaint` in the profile ([[Persistence and Saves]], schema v3).
- **Spend.** `BuySkinRequest(paletteKey)` -> server checks the palette is a Spraypaint palette, the player does not own it and can afford it, spends, sets `SkinOwned_<key>`, auto-equips. Ownership is global across weapons.
- **Toast.** Kill card titled "KILLED <NAME>" (or "KILLED BANDITS ×3"), "+N Spraypaint" with the spray icon, and a second "+N EXP" line. A gain with no kill behind it keeps the title "SPRAYPAINT". Rewards and `KillConfirmed` names are gathered in a 0.1 s settle window.
- Rates are "a play-testing starting point, not a balance claim" (comment in `Constants`).

## Extend it
- Tune rates in `Spraypaint.Constants` only.
- New spend target: price it as a `Spraypaint`-source palette in `Cosmetics.Palettes`; gate on `source`, never on `price` being present.
- The spec's Booster pass (2x Spraypaint, never XP or Cash) was designed but not built.

## Watch out
- **Never "revert" a schema version.** Per-weapon balances shipped as schema v2; reverting `VERSION` to 1 would have tripped `migrate`'s assert for every v2 profile and kicked those players on every join. The revert rolled forward to v3 instead.
- Attribute-changed signals fire deferred in this place: write `Level`, then `task.wait()` before reading `Spraypaint`.
- `Eliminated` is shared with `LevelingService`; a kill test can cross a level and add +25, which once looked like a broken PvP rule. Test the rule through `awardForVictim` directly.
- `ShotResolver` still passes a weapon name as a 4th `Eliminated` argument from the per-weapon era; it is unread and was left on purpose.
- `RunUnitTest`'s filter is an unanchored substring match: a case name containing another's name runs both (fixed by renaming, the filter is unchanged).
- Join toast fixed: `SpraypaintService.hydrate` sets `SpraypaintRestored` (`Constants.RESTORED_ATTRIBUTE`) last, and `SpraypaintHud` re-seeds its previous balance and XP at every change while the flag is not true. The join was emulated with an attribute sequence in one Play; a real rejoin with a saved balance was not run.

## History
- 2026-11-17: no more join toast: `SpraypaintRestored` flag; `handleBuySkinRequest` refuses a weapon the player does not own before it charges. [[2026-11-17 Known Issues Pass]]
- 2026-09-24: back to one global balance (schema v2 -> v3 migration sums per-weapon balances plus the shared bucket); prices raised: Cobalt 500, Verdigris 700, Ember 900, RoseGold 1200. [[Revert-Global-Spraypaint-Balance]]
- 2026-09-24: per-weapon balances (schema v1 -> v2, `spraypaintShared` grandfather bucket). Reverted the same day. [[Per-Weapon-Spraypaint]]
- 2026-09-24: kill toast titled "KILLED <NAME>"; XP line and icons on the toast. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]] [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]]
- 2026-09-24: spray-can balance badge becomes an uploaded icon. [[FPS-Weaponry-Category-Icons]]
- 2026-09-23: spray-can badge beside the buy strip's price. [[FPS-Spraypaint-Badge-Beside-Price-Label]]
- 2026-09-23: balance and owned skins persist. [[FPS-Persistence-Phase-3]]
- 2026-09-23: "Renown" renamed to Spraypaint everywhere (folders, attribute, strings); pure rename. `.superpowers/sdd/2026-09-23-renown-phase-2/spraypaint-rename-report.md`
- 2026-09-23: Phase 2 ships: earn rates, four priced palettes (then 250-750), buy strip, gain toast; 71/71 tests. [[FPS-Spraypaint-Phase-2]]
- 2026-09-22: currency first specified (as part of cosmetics monetisation). [[FPS-Monetization-Cosmetics-Spec]]

See [[Batch Log]].
