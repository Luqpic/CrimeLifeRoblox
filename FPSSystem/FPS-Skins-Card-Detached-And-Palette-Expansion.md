# Skins card detaches from the shop panel, palette catalogue grows 12 -> 20

**Status:** Implemented and verified at the data/property level in a real server+client VM (Play
mode) — 146/146 tests, real server VM, temporary `Script`. Screenshot and click-driven verification
were **not possible in this Studio session** (headless: `ViewportSize` reads `1, 1`, simulated
input never reaches the engine, `screen_capture` times out in both Play and Edit mode) — see Notes.
Everything that can be confirmed without a rendered frame — geometry, colour, chip count, lock/price
state, positioning math — has been, against the real running instances, not by reading source and
assuming.

## Summary

The skins row under the weapon shop's 3D preview was a cramped 60px-tall horizontal strip inside
`DetailPanel`, with a `BuyStrip` that swapped in over it to confirm a Spraypaint purchase. It is
replaced with a detached **Skins card**: its own 240x580 panel, 20px to the right of the shop's
outer frame with tops aligned, that tweens in (slide + fade) when a weapon's detail view opens and
tweens out when it closes. Built natively from `Frame`/`UICorner`/`UIStroke` to the Figma spec
(`iRetcvpbMMD190DJA9Mwrm`, node `147:6`) — no image import, Studio's asset upload is blocked here.

The palette catalogue (`ReplicatedStorage.Cosmetics.Palettes`) grows from 12 to 20: 7 new Spraypaint
entries (Slate, Rust, Forest, Coral, Aqua, Lilac, Fuchsia) and 1 new Vip entry (Nebula), appended
after the existing 12, which are untouched. A regression test now asserts the catalogue's minimum
pairwise swatch distance stays >= 52.8 — turning a discipline the file's own comments only ever
stated in prose into something that fails automatically.

`SkinRowController` and the `SkinRow`/`BuyStrip` instances it owned are deleted, not left orphaned.
Buying and equipping still go through the same `BuySkinRequest`/`EquipSkinRequest` remotes with the
same argument shapes — no server script changed.

## Cause

Feature request: the skins row was cramped, and the catalogue needed 8 more palettes.

## Changes

- `ReplicatedStorage.Cosmetics.Palettes` — 8 new entries appended after RoseGold (7 Spraypaint,
  then Nebula last, matching the brief's table order): Slate 1500, Rust 1800, Forest 2200, Coral
  2600, Aqua 3100, Lilac 3700, Fuchsia 4400, Nebula (Vip, no price). Swatches and ramps exactly as
  given; the existing 12 entries, including the four Spraypaint prices the last change set, are
  byte-for-byte unchanged.
- `ServerStorage.UnitTest.Cases.Palettes_Test` — new case, `"no two swatches sit closer than 52.8
  apart in RGB space"`, computing the true minimum pairwise Euclidean RGB distance across the whole
  catalogue rather than trusting the comment. Mutation-tested (see Notes).
- `ServerStorage.UnitTest.Cases.SpraypaintTier_Test` — two hardcoded counts updated: "four Spraypaint
  palettes" -> eleven, "the catalogue now holds twelve palettes" -> twenty. Both are pre-existing
  tests from an earlier phase that exist specifically to catch a catalogue-shape change; this
  expansion is that change, deliberately, so the counts move with it.
- **New:** `StarterPlayer.StarterPlayerScripts.SkinsCardController` (repo:
  `FPSSystem/Cosmetics/SkinsCardController.luau`) — builds the detached card once at module load (its
  own `ScreenGui`, all 20 chips), exposes `.open(shopFrame, weaponName, previewModel)` /
  `.close()`. Reuses `UI.Transitions.fade`/`.set` for the opacity half of the tween (checked before
  writing anything new) and a plain `TweenService:Create` for the 40px slide, since `Transitions` has
  no concept of position.
- `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — requires `SkinsCardController`
  instead of the retired `SkinRowController`; `showDetail()` calls `SkinsCardController.open(shop,
  weaponName, displayModel)` (the outer shop frame, not `detailPanel` — the card's 580px height
  matches the shop's full-open height); `backButton`'s click handler and `closeShop()` both now also
  call `SkinsCardController.close()`, since the card is a sibling `ScreenGui` and does not follow the
  shop's own `Visible` toggle automatically.
- **Deleted:** `StarterPlayer.StarterPlayerScripts.SkinRowController` (live and repo);
  `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.SkinRow` and `.BuyStrip` (live
  instances only — GUI object trees are not mirrored to the repo).

## Notes

**The ZIndex decision: a second ScreenGui, not a flipped `ZIndexBehavior`.**
`WeaponaryShopGui` is `ZIndexBehavior.Global` — the project's own documented trap
(`Notification-Blank-Card-ZIndexBehavior.md`): under Global every descendant sorts by absolute
`ZIndex` instead of drawing with its parent, so a panel whose `ZIndex` is higher than its own
children's paints over its own text. Flipping `WeaponaryShopGui` to `Sibling` was considered and
rejected: under Global a higher `ZIndex` currently wins regardless of tree position *anywhere in
that GUI*, so flipping the whole shop's behaviour risks silently re-layering the title bar,
inventory column, category tabs, weapon grid and detail panel — none of which were audited for this
change and all of which currently depend on Global's ordering being what it is. A second,
`Sibling`-behaviour `ScreenGui` (`SkinsCardGui`, `DisplayOrder` 6, one above the shop's 5) sidesteps
the trap without touching the shop at all. Its companion trap — `AbsolutePosition` is measured below
the top-bar inset, but a `ScreenGui` that ignores the inset is not — is handled by adding
`GuiService:GetGuiInset()` back onto the shop's measured `AbsolutePosition`, the same correction
`UI.CashBurst` already makes for the identical reason (read from that module, not reinvented).
Verified live: shop `AbsolutePosition (226, 133)`, inset `(0, 58)` -> card `Position.Y = 191`,
exactly `133 + 58`. No 36px-high miss.

**Why the colours were distance-checked rather than picked by eye.** `Palettes.luau`'s own comments
already carry this discipline — RoseGold's entry documents an earlier ivory that sat 37.4 from
Arctic and was rejected for it, replaced with one at 68.0. A chip is roughly 52-84px on screen and
has to stay distinguishable at that size, under colour-vision deficiency, across 190 pairwise
comparisons in a 20-swatch catalogue — not something to trust to eyeballing, and not something to
trust to a comment either, which is why the new test makes the check automatic: computed the true
minimum pairwise Euclidean RGB distance across all 20 swatches (`52.8`, Stock<->Sandstorm,
unchanged and pre-existing) before writing a single new ramp, then mutation-tested the test itself —
temporarily added a colour 20 units from Slate, confirmed the suite went red
(`Palettes_Test: 11 run, 10 passed, 1 failed`), reverted, confirmed green again.

**A deliberate UX simplification from the old flow, flagged rather than silently shipped.** The old
skins row's locked Spraypaint chips opened a separate `BuyStrip` (price + BUY/CANCEL) on first
click; the new card has no space reserved for a strip in its fixed 240x580 layout, and the price is
now printed on the chip itself before any click happens — the old flow hid it until the first click.
Given that, a locked, affordable Spraypaint chip now fires `BuySkinRequest` directly on click,
matching how the Vip chip already fires its gamepass prompt with no confirm step. This is a
judgement call, not something the design brief specified either way, and it removes a confirmation
step from a real-currency action (Spraypaint, not Robux, so low but non-zero risk of an accidental
click). Worth a second look if a confirm step is wanted back.

**What could not be verified, and why — read this before trusting a "looks right" claim about this
change.** Neither a click-driven walkthrough nor a screenshot was achievable in this Studio session.
`workspace.CurrentCamera.ViewportSize` reads `1, 1` during Play; `user_mouse_input`,
`user_keyboard_input` (tried by instance path, by screen coordinate, and via the shop's own `B`
keybind) and `VirtualUser:ClickButton1`/`SendKeyEvent` all produced zero events on a direct
`UserInputService.InputBegan` probe; `screen_capture` timed out in both Play and Edit mode. This is a
headless Studio process with no real rendered window, not a fault in the implementation.
Separately — and worth recording because it looks like it should work and quietly does not —
`execute_luau` runs in its own Luau VM with its own `require()` cache, **client-side as well as in
Edit mode**: a manual `require()` of the already-loaded `SkinsCardController` module from
`execute_luau` produced a second, independent `SkinsCardGui` in the same live `PlayerGui`, confirmed
by descendant count. Property reads on real `Instance`s are unaffected (the DataModel is shared
regardless of VM) and are what the verification above relies on; calling into a module's cached
closure from `execute_luau` is not reliable, exactly the caution this project already documents for
`RunUnitTest` in Edit mode ("a false 127/132 here") — this is the same hazard, just discovered again
on the client. Worked around by adding a temporary three-line diagnostic *inside*
`WeaponaryShopController` itself (same VM as the real code, calling the real `openShop()` /
`showDetail()`), reading the resulting properties, then removing the diagnostic and re-diffing the
script byte-for-byte against the repo mirror to confirm no trace was left. Even driven correctly,
the entrance tween's own *progression* could not be observed — `card.Position` was caught still at
its pre-tween start (`target + 40px`) — which is this project's own documented trap:
`TweenService is render-driven. With the Studio viewport collapsed, RenderStepped reports 0 FPS and
tweens do not advance.` Both tween endpoints were confirmed correct by the math; the motion between
them needs a person with a real Studio window to watch.

**Repo/Studio drift, checked after every edit, not just once at the end** — the previous change log
in this file found drift the hard way after its own clean test run. Every script this change
touched (`Palettes.luau`, `Palettes_Test.luau`, `WeaponaryShopController.luau`, the new
`SkinsCardController.luau`, `SpraypaintTier_Test.luau`) was read back from Studio in full and diffed
character-for-character against its repo mirror immediately after each edit. No drift found; the
only drift-risk moment was the temporary diagnostic above, added, exercised, removed and re-diffed
clean.

---

## Amendment: a priced chip now needs two clicks, not one

Landed before this change log shipped, so the card described above is the card with this behaviour.

The first implementation fired `BuySkinRequest` on a single click of an unowned Spraypaint chip. The
reasoning given was that the fixed 240x580 card has no room for a confirm strip and the price is
already printed on the chip, and that the Vip chip already prompts with no confirm step of its own.

Both halves of that are true and the conclusion still does not hold. The Vip chip is not a
counter-example: it opens Roblox's own Robux dialog, which IS the confirmation, and Roblox owns it.
A Spraypaint chip had nothing equivalent. The old `DetailPanel` BuyStrip was a separate, deliberate
confirm control, and this card retired it without replacing it -- so the revamp quietly removed a
guard rather than deciding it was unnecessary.

That was survivable when the top price was 250. This same round raised the curve to 4400, which is
several hundred kills, and spending it needed one stray click on a scrolling grid of twenty chips
with no undo anywhere in the system.

**Now:** the first click PRIMES the chip -- accent stroke, and the price label reads `CONFIRM` -- and
only a second click inside a 3 second window buys. Priming a different chip stands the first one
down, and the primed state is cleared when the window lapses, when the card closes, when an owned
chip is clicked to equip, and when the card is re-targeted at a different weapon. That last one
matters on its own: without it the next click would buy against a weapon the player was no longer
looking at when they primed it.

The primed state deliberately reuses the accent stroke that marks the equipped chip. That is
unambiguous rather than confusing, because only an UNOWNED chip can be primed and only an OWNED one
can be equipped -- the two can never appear on the same chip at once -- and the word `CONFIRM` in
place of the price is what separates them at a glance.

Suite after the change: 146/146 across 12 suites, run in a real server VM through a temporary Script
(added, read, removed, and the live source re-checksummed against the repo mirror: 18445 bytes, 480
lines, both sides identical).

**Still unverified, and it needs a person.** No screenshot of the finished card exists. This Studio
session reports `ViewportSize` of 1,1 -- the window is collapsed -- so `screen_capture` hangs, input
tools deliver nothing, and `RenderStepped` reports 0 FPS, which means the open/close tweens cannot
advance and any `AbsolutePosition` reading is meaningless. Everything above is verified at the
property level and by the suite. The card's actual appearance, the tween, and the two-click purchase
as experienced by a hand on a mouse are all unconfirmed.
