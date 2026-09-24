# Skins card: preview before buying, hover and click feedback, spray burst, Vip on hold

**Status:** Confirmed live through the real input path (HUD weaponry button → AK47 card → skin chips),
with screenshots and frame-by-frame recordings. Suite **147/147** in a real server VM. The re-pointed
ownership tests were mutation-tested: making Spraypaint skins free turned exactly the two expected
tests red, then the mutation was reverted and the source checksummed back to the original. All nine
touched scripts are checksummed identical between Studio and the repo. `UI.CashBurst` has a repo
mirror for the first time.

## Summary

Five changes to the Skins panel, all requested:

1. **Vip is on hold.** Its four skins are now sold for Spraypaint.
2. **Hover** thickens a chip's outline and plays the hover tone, the same effect as the weapon cards.
3. **Every price** carries the spray-can icon.
4. **Buy feedback** matches the weapon BUY button: a click tone, a red outline and the denied tone when
   the player can't afford it, and on success a burst of spray cans (not coins) plus the purchase
   sound.
5. **Clicking a locked skin previews it** on the 3D weapon. Clicking the same skin again buys it.

## Cause

User-requested polish and a pricing change.

## Changes

- `ReplicatedStorage.Cosmetics.Palettes`: Arctic 5200, Obsidian 6100, Gold 7100 and Nebula 8200 change
  from `source = "Vip"` to Spraypaint. Each is converted in place, so swatches and ramps are
  byte-identical. They are moved from after Acid to the end of the list, so the grid still reads
  cheapest to priciest. A comment at the entries says exactly how to restore Vip.
- `ReplicatedStorage.Spraypaint.Constants`: `ICON_ASSET_ID` is now the one owner of the spray-can icon
  id. The shop's balance badge, the card's price rows and the burst all read it from here, replacing
  the literal that was in `WeaponaryShopController`.
- `ReplicatedStorage.UI.CashBurst`: `burstFrom` takes an optional `style` argument
  (`{ image, color, size }`). Without it the burst throws the shared coin exactly as before, so every
  existing call is unchanged.
- `StarterPlayer.StarterPlayerScripts.SkinsCardController`:
  - `paintChip` is now the single owner of each chip's outline. It works out colour and thickness from
    three states at once: equipped, previewed and hovered.
  - Hover adds +2 thickness through `paintChip` and plays `Sounds.hover()`.
  - The price row is a Frame holding the icon and the amount, laid out horizontally and centred.
  - Clicking a locked chip calls `preview`: it dresses the 3D model in that palette, gives the chip the
    accent ring, and sets the label to `BUY <price>`. Clicking the same chip again buys it.
    - If the player can't afford it, `denyChip` plays the denied tone and flashes the outline red.
    - If they can, it plays a click and fires `BuySkinRequest`.
    - When `SkinOwned_<key>` replicates, the chip plays the purchase sound and a spray-can burst.
  - The old `arm`/`disarm` two-click confirm and its 3-second timeout are removed; the preview
    replaces them.
- Tests:
  - `Palettes_Test` no longer requires a Vip palette to exist.
  - `SpraypaintTier_Test`: the Spraypaint count is now 15 (was 11), and the nil-price check uses
    Carbon (was Gold).
  - `CosmeticsOwnership_Test`: re-pointed; see the first note.

## Verification (live, 1286-point viewport)

| Check | Result |
|---|---|
| Hover Cobalt | outline 1 → 3; neighbour stays 1; equipped Stock keeps accent at 2 |
| Price rows | spray icon plus figure on every locked chip; Arctic 5200 … Nebula 8200 shown |
| First click on Cobalt | AK47 in the 3D view turns Cobalt blue; chip reads `BUY 500` in accent (screenshot) |
| Second click with 0 balance | outline recorded going accent → red `#FF4B4B` → accent, ~0.4s; balance unchanged, not owned |
| Second click with 1000 balance | 9 spray cans burst (the coin formula's count for 500), tinted accent; balance 1000 → 500; `SkinOwned_Cobalt` true; auto-equipped on AK47; chip unlocked and ringed |

## Notes

**Re-pointing the Vip tests was necessary, not optional.** `CosmeticsOwnership_Test` found its test
subject by searching the catalogue for the first Vip palette. With none left, that search returns
`nil`, so "a Vip palette is refused without the pass" would have kept passing while testing nothing,
the tests-that-cannot-fail trap this project has hit eight times. The ownership gate those tests guard
still exists and still matters, so they now exercise it through a Spraypaint palette:

- refused until bought, even with the Vip pass;
- allowed once `SkinOwned_<key>` is set;
- the equip handler refuses an unbought skin.

A new test asserts that no palette is Vip-gated while Vip is on hold. The day a Vip palette returns,
it fails, and its comment says which Vip-pass tests to bring back. Mutation-tested: with the
Spraypaint branch of `ownsPalette` forced to `return true`, exactly these two go red:

```
[FAIL] ... a Spraypaint palette is refused until it has been bought, even with the Vip pass | expected falsy, got true
[FAIL] ... handleEquipRequest refuses an unbought Spraypaint palette and leaves the attribute unset | expected falsy, got "Cobalt"
```

**A test that was passing for the wrong reason, fixed along the way.** `Palettes_Test`'s "at least one
free palette" counted every non-Vip palette as free. So a catalogue with no Free palette at all, only
Spraypaint ones, would still have passed. It now counts `source == "Free"`.

**Why the preview took over the purchase confirmation.** The card already required two clicks to buy,
so one stray click could not spend up to 8200. But the first click only said `CONFIRM`, and it timed
out after 3 seconds because it had nothing else to show. Previewing on the first click gives that
step a purpose. The timeout is gone, because a preview that vanished while the player was still
looking at it would be worse than none. A preview now lasts until the player picks another chip, goes
BACK, closes the shop, or the card switches to another weapon. Switching weapons also clears it, so the
next click can't buy against a weapon the player has moved away from.

**Why one function owns the outline.** A chip has one `UIStroke`, and it now carries the equipped
ring, the preview ring and the hover thickening. The weapon card's hover effect tweens its stroke
directly, which is fine for a card with no other stroke states. Here, three independent tweens on the
same property would overwrite each other mid-flight. `paintChip` computes the result from all three
states instead. The two rings can share the accent colour without ambiguity: only an owned chip can
be equipped, and only an unowned one previewed.

**Red on the outline, not the fill.** The weapon BUY button turns its background red. On a chip the
background is the palette's own colour, and turning it red would show the player a skin that doesn't
exist. So the refusal colours the outline instead.

**No preview flicker after a purchase.** Ownership replicates first, then the server's auto-equip. If
the preview were cleared as soon as ownership arrived, the model would briefly flash back to the old
skin. `repaint` clears it only once the equipped skin equals the previewed one.

**Burst position.** `AbsolutePosition` is reported below the top bar for every ScreenGui, including
ones that ignore the inset: a full-screen inset-ignoring frame reads `y = -58`. `CashBurst`'s existing
inset correction is therefore right for a chip in the card's own inset-ignoring ScreenGui as well. No
change was needed there.

**The Vip game pass itself is untouched.** It still exists and advertises "Exclusive weapon skins",
which it now does not grant. Its id is `0` (unconfigured), so it cannot be bought. Update or disable
it before the place ever sells it.

**Implied grind for the new top of the curve**, at the real earn rates (Criminal kill 2, Police kill
5, level-up 25): Nebula at 8200 is about 4100 Criminal kills or 1640 Police kills before level
income. That is deliberate for the premium tier, but it is the number to revisit if Vip stays on hold
for long.

**One console note, pre-existing and unrelated.** During play Studio logs dozens of
`Failed to load sound … User is not authorized to access Asset` and "experience doesn't have access
permission" lines, for about ten sound asset ids. They are sounds the published experience has not
been granted access to. They predate this change; none are the sounds used here, which all play.
Worth sharing access to them in the Creator Dashboard.
