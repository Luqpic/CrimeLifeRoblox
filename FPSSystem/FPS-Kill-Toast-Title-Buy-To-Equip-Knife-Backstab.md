# Change Log: "Killed <Name>" Kill Toast, Buy Goes Straight to Slot Pick, Knife Backstab

**Date:** 2026-09-24
**Status:** Applied — all three verified live in play (readback, and the shop through real clicks); the
place is not saved to disk by this change.

## Summary
- **Kill toast title.** The card already shows both rewards, so its title now names the kill instead
  of repeating the currency: "KILLED SABOTEUR" over "+2 Spraypaint" / "+20 EXP". Players show by display
  name. Several kills in one moment read "KILLED BANDITS ×3". A Spraypaint gain with no kill behind it
  (the level-up bonus from a quest) keeps "SPRAYPAINT".
- **Buy → equip in one step.** Buying a gun you did not own drops the panel straight into the slot
  picker ("Select a slot to equip", slots pulsing). Upgrades never do, and nor does re-viewing a gun you
  already own.
- **Knife backstab.** The Knife no longer gets the headshot ×2. Instead it gets ×2 for a hit on the back
  of the upper torso with the attacker within 60° of straight behind. Every other weapon keeps headshots.

## Changes
- `ReplicatedStorage.Blaster.Remotes.KillConfirmed` (new RemoteEvent) — fired to the killer with the
  victim's name from `LevelingService`'s Eliminated handler, the one handler that sees every player kill
  including PvP. Enemy names come from the `EnemyTemplate` attribute, the same value on the nameplate.
- `StarterPlayerScripts.SpraypaintHud` — collects KillConfirmed names in the same 0.1 s settle window as
  the rewards and titles the card from them. Names are consumed on every read, so a kill that paid no
  Spraypaint cannot lend its name to a later card.
- `StarterPlayerScripts.WeaponaryShopController` — `awaitingEquipAfterPurchase` (a weapon name, set only by
  BUY). When that weapon's `WeaponOwned_` attribute lands and the panel still shows it, the existing
  EQUIP pick mode opens. Back and Close already cancel pick mode.
- `ReplicatedStorage.Blaster.Constants` — `BACKSTAB_MULTIPLIER_ATTRIBUTE = "backstabMultiplier"`.
  `ServerStorage.Weapons.Knife` — `backstabMultiplier = 2`.
- `ServerScriptService.Blaster.Scripts.ShotResolver` — `isBackstab`. A weapon declaring the attribute uses
  it in place of the headshot rule. The damage indicator takes an optional label ("Backstab!"), and
  `IndicatorClient` shows it.

## Verification (play mode)
- Backstab matrix, real `resolveShot` with the Knife against **all 9 enemy templates** — ALL PASS:
  from behind (0°, 45°): 60 = 2 × 30. Side (90°), front-quarter (135°), front (180°): 30. Head from
  behind or front: 30. Crowbar: headshot still ×2 (52.5 on a 1-in-6-ray hit), back of the torso not
  boosted (45).
- Toast on a real knife kill of a live Saboteur: "KILLED SABOTEUR" / "+2 Spraypaint" / "+20 EXP", with
  both icons.
- Shop, real clicks. Before: BUY left the panel on EQUIP, needing a second press. After: Glock 18, BUY →
  owned, swap prompt shown → click Slot 2 → `LoadoutSlot2 = "Glock 18"`, gun in the Backpack, prompt
  closed. Then UPGRADE → level 1, no picker.
- 0 server errors. Client errors: 10 from `StarterCharacterScripts.Lean` line 25 (see Notes), none from
  this change.

## Notes — the backstab took four measurements, and each one moved the rule
1. **A name check fails.** `HumanoidRootPart` is queryable and fills the same box as the upper torso
   (1.0 vs 1.004 studs deep), and back gear takes the ray first. So the rule is geometric: the attacker's
   angle decides "behind", and the hit point decides "upper torso".
2. **Padding the box by the ray radius (0.75) scored a head hit from behind as a backstab.** The head
   hit landed at y 1.25 against the torso's 0.85 half-height, inside 0.85 + 0.75. Height is now held to
   +0.15.
3. **Tightening every axis to +0.15 then scored nothing, even from dead behind.** The ray was hitting the
   Thug's hoodie 0.40 studs behind the torso (z 0.90). Across the templates, back gear reached 1.11
   studs (a Smuggler's duffel bag, a Bandit's own slung Mossberg).
4. **From 45° behind, 6 of 9 templates failed on width,** where the ray met the back of the arm. So
   depth and width are open (the rear half only), height is tight, and "from behind" is left to the
   angle check.
- Known edge, kept deliberately: the Smuggler's duffel bag rises above its shoulders, so a knife aimed
  at its head from behind strikes the bag and counts. That is still a stab in the back.
- **Also fixed:** a backstab's "Backstab! 60" was overwritten within a second by the Knife's first bleed
  tick, which relabelled the merged total as a plain "68". A bonus hit now keeps its label for the whole
  3 s merge window. Measured after: "Backstab! 68 → 72 → 76 → 80".
- **Not fixed (out of scope):** `StarterCharacterScripts.Lean` line 25 indexes
  `character.HumanoidRootPart` directly and errors when the root part has not loaded yet. This is the same
  class of bug as the nameplate fix in the previous change; a WaitForChild would fix it.
