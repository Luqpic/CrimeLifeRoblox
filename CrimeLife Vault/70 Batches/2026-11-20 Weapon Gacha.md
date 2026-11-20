---
type: batch
tags: [batch, city, weapons, gacha, monetization, ui]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 5)", "Play checks, 2026-11-20 evening", "CityMerge/after-import.md ('Weapon gacha 2026-11-20')"]
---

# 2026-11-20 Weapon Gacha

Part 5 of [[Current Work]]. Built natively. Weapons come from crates instead of the buy button (decided 2026-11-20 morning: "Instead of buying, we are doing gacha"; no free starter gun).

## Picker answers
Cash and Robux; "4 rarities"; duplicates pay cash; "Shop tab, case spin"; Premium crate keys (49 R$ for 1, 399 R$ for 10); restricted players get the buy page; Claude creates the developer products (the developer confirming each).

## How it works
- **Rarity** is an attribute on each weapon Tool in `ServerStorage.Weapons` (set in Edit from the old price: Common 12 up to 450, Rare 11 up to 700, Epic 9 up to 950, Legendary 4 above; change any in Edit). It is copied to the client catalog (`WeaponShopService` `CATALOG_ATTRIBUTES`). The Crowbar and the RPG (gamepass) are not in the crates.
- **Numbers** in `ReplicatedStorage.Gacha.Config`: roll 300 cash, ten rolls 2,700 (at least one Rare); Standard odds Common 60 %, Rare 28 %, Epic 10 %, Legendary 2 %; Premium Rare 72 %, Epic 22 %, Legendary 6 %; pity an Epic or better by roll 30 and a Legendary by roll 100 (shared by both crates); duplicates pay Common 60, Rare 150, Epic 400, Legendary 1,000; key products (ids 0 until created).
- **Draw** `ReplicatedStorage.Gacha.Draw` (pure): rarity by cumulative odds, pity upgrade, counters, the ten-roll guarantee.
- **Server** `ServerScriptService.Gacha.GachaService` (module) and `GachaServer` (script): `Remotes.Roll` (RemoteFunction: count 1 or 10, crate Standard or Premium) pays cash or keys, draws, grants through `Admin.Hooks.giveWeapon` (the shop's grant: ownership, a free slot, the profile), pays duplicates, refunds a failed grant; one roll at a time per player. `Remotes.BuyKeys` prompts a key product. Keys and pity in the profile (`Schema`: gachaKeys, gachaSinceEpic, gachaSinceLegendary, gachaReceipts). Key receipts in `MonetizationService.ProcessReceipt`, once per PurchaseId.
- **Paid random items:** `PolicyService` `ArePaidRandomItemsRestricted` per player becomes the attribute `GachaAllowed` (a failed check counts as restricted). Restricted players cannot roll; the weapon panel shows BUY as before and `WeaponShopService` lets only them buy directly (everyone else's `BuyRequest` is refused). The odds are on the crate page before any roll.
- **Client:** the weapon panel shows each unowned weapon's rarity (coloured) and its action reads CRATES, which fires `ReplicatedStorage.Gacha.OpenCrates`. `StarterGui.CrateGui` (built in Edit; set `Panel.Visible` to look at it): Standard and Premium columns with the odds, a reel of 44 cards that eases (Quint, 3.4 s) onto the prize (card 38, the best of ten), a ten-card grid for ten rolls, the key count, live Robux prices (`GetProductInfoAsync`) once the products exist, the pity line. Fitted by the game's `UIScaleController` like every panel.

## Verified (Play)
- `GachaAllowed` true in Studio; a direct `BuyRequest` for the AK47 refused (cash 500 kept).
- Real clicks: ROLL (500 to 200 cash, an S&W 29 Epic granted and slotted); ROLL 10 (5,000 to 2,300, ten cards in the grid, best an Epic named); a Premium roll with no keys refused. The prize card stopped under the marker (card 38). No client or server errors.
- City 378 / 378 / 0 (new `Gacha_Test`, 5 cases); heist 764 passed / 0 failed.

## Trap found
`UIScaleController` fits a ScreenGui by its widest offset-sized descendant: the 5,456-stud reel strip made it shrink the crate page to its 0.4 floor. A strip that sizes itself (`AutomaticSize` X, offset 0) is not measured. See [[UI Layout Traps]].

## Left open
- The Robux developer products (2 key products, and the 6 cash bundles that still have `productId = 0`) are created in the next step; until then the BUY KEYS buttons do nothing.
- Receipts: `MonetizationService` returns PurchaseGranted once the grant is in memory and mirrored to the profile, not after the save lands (the cash bundles have always done this; the monetization skill asks to wait for the save).
- Not checked: a restricted account (the buy page path), a phone, two players.

## Saved
Studio saved to Roblox (Save, never Publish). NOT published.

## Links
[[Weapon Shop and Upgrades]] · [[Economy and Cash]] · [[Gamepasses]] · [[Current Work]]
