# ZIndexBehavior.Global audit (phase 2b Task 4)

Measured 2026-11-15 in `Crimelife city.rbxl` (resolved by name). Nothing saved or published. Tool: `phase2b/paint-order.luau`; its self-check ran in Edit before any measurement and passed: (a) all `ZIndex` 1 gives the same list in both modes (5 entries); (b) the notification case (card `ZIndex` 4 with a label `ZIndex` 1, beside a card `ZIndex` 3) gives different lists, and under Global the label comes before its own card (Global `Container[1], Container[1]/Card4[1]/Label[1], Container[1]/Card3[2], Container[1]/Card4[1]`; Sibling `Container[1], Container[1]/Card3[2], Container[1]/Card4[1], Container[1]/Card4[1]/Label[1]`).

**Rule:** a ScreenGui is flipped to `Sibling` only when its Global and Sibling paint-order lists are the same in every measurement. Lists are compared exactly; a hash below is Adler-32 of the list joined with newlines (`hash 1` is the empty list).

## Step 2: Play 1 (city spawn, Client datamodel)

Pass A at 25 s after start (`DistributedGameTime` 25.0); pass B after the sequence: character moved by a server-side `PivotTo` to 6.0 studs from the "Level 1 Quest" giver, `BuyRequest:FireServer("AK47")` (cash 500 to 300, `WeaponOwned_AK47` true), one notification (client `SetAttribute("Spraypaint", 0 -> 3)`), `AcceptQuestRequest:FireServer("Level1Thugs")`, then the measurement at 67.7 s. In pass B the lists below are identical to pass A except where a "B" value is given.

| ScreenGui | mode | objects (A / B) | Global hash | Sibling hash | equal (A and B) | swapped pairs | swapped AND overlapping | capture |
|---|---|---|---|---|---|---|---|---|
| CashShopGui | Global | 66 / 66 | 3167257660 | 3983115324 | no | 233 | 0 | no panel shown without a click |
| GamepassShopGui | Global | 55 / 55 | 2952834556 | 466529788 | no | 51 | 0 | same |
| WeaponaryShopGui | Global | 88 / 88 | 790166282 | 3883334410 | no | 609 | 0 | same |
| QuestLogGui | Global | 6 / 6 | 2285647946 | 2298427466 | no | 2 | 0 | same |
| DeathScreenGui | Global | 6 / 6 | 2634108003 | 2659011683 | no | 3 | 3 (all hidden) | same |
| PromptUiGui | Global | 0 / 4 | A: 1, B: 311894726 | A: 1, B: 311894726 | yes, yes | 0 | 0 | prompt not on screen |
| AdminLevelGui | Global | 6 / 6 | 391654033 | 391654033 | yes, yes | 0 | 0 | `Enabled = false` |
| DamageDirectionIndicator | Global | 0 / 0 | 1 | 1 | yes, yes (empty) | 0 | 0 | none (no arrow alive) |
| cash burst gui (`CashSpendBurst`) | n/a | absent / absent | | | | | | |
| Custom Inventory | Global | 30 / 30 | 2715035090 | 1687561682 | no | 123 | 0 | same |

"Swapped AND overlapping" counts the pairs whose order differs between the modes and whose `AbsolutePosition`/`AbsoluteSize` rectangles overlap (positive area), over all objects, visible or not.

First GuiObject `AbsoluteSize` (pass A): CashShop 760 x 570, GamepassShop 760 x 570, WeaponaryShop 920 x 580, QuestLog 420 x 460, DeathScreen 1080 x 659, Panel (AdminLevelGui) 300 x 200, Inventory 563.5 x 240.0; PromptUiGui and DamageDirectionIndicator had none at 25 s. These equal the figures in `first-run.md` Step 3.

The overlapping pairs that would swap:

- DeathScreenGui (pass A and B, all three hidden at the time, `Visible = false`): `DeathScreen[1]/TextContainer[2]/Phrase[1]` (z2) vs `DeathScreen[1]/TextContainer[2]` (z5); `.../Countdown[2]` (z2) vs `TextContainer[2]` (z5); `.../BannerPlate[3]` (z2) vs `TextContainer[2]` (z5). Same notification-card shape: a container at z5 with children at z2. Under Global the three children paint under their own container; under Sibling over it.
- The other five unequal ScreenGuis: no swapped pair overlaps. The swaps are between objects in different branches that sit in different places, for example CashShop: `CashShop[1]/Subtitle[4]` (z1) vs `CashShop[1]/TitleBar[3]/Balance[2]` (z2); GamepassShop: `PassTemplate[4]` (z1) vs `TitleBar[2]/CloseButton[2]` (z12); WeaponaryShop: `InventoryColumn[3]` (z1) vs `TitleBar[2]/CashChip[2]` (z5); QuestLog: `QuestList[4]` (z1) and `BannerPlate[5]` (z10) vs `TitleBar[3]/CloseButton[2]` (z12); Custom Inventory: `hotBar[3]` (z0) vs `Inventory[2]/Frame[1]` (z1). Not flipped regardless: the rule is list equality. The developer can look at these if a Sibling move is wanted later.

Live probes in the same Play (so the on-demand ScreenGuis had a tree to measure):

- Purchase: `CashSpendBurst` did not appear in the 4 s after `BuyRequest` (the shop never called the burst because the panel was not open and laid out: `CashBurst.burstFrom` returns when the origin `AbsoluteSize.X == 0`). Not caught from the purchase.
- Burst called directly: `require(ReplicatedStorage.UI.CashBurst).burstFrom(LevelingGui.LevelingBar, 200)`: 8 coin ImageLabels, all `ZIndex` 1, Global hash = Sibling hash = 1169630659, equal. Read from the script (lines 81-91): every coin is a plain `ImageLabel` with no `ZIndex` set.
- Damage arrow: `DamageDirection:FireClient` from the server, repeated every 0.4 s: 3 arrows alive, all `ZIndex` 1, hash 1635848113 under both modes, equal.
- Notification card: the `Spraypaint` attribute path was run in Play 2 (below), where the card was seen (Card z4, labels z1).

Capture: one `screen_capture` of the Play 1 view worked (`CityMerge/screenshots/phase2b-task4-play1-hud.jpg`); none of the ten ScreenGuis is visible without a click, so there is no per-panel capture ("no capture" per row).

## Step 4: Play 2 (after the edit, same sequence)

Pass A at 25.4 s, pass B at 52.1 s (character 6.0 studs from the giver, AK47 bought: cash 500 to 300, notification raised, quest accepted). `Custom Inventory` was not changed.

| ScreenGui | mode (A / B) | Global list hash, Play 1 | Global list hash, Play 2 (A / B) | Sibling list hash, Play 2 | lists equal | first GuiObject `AbsoluteSize` vs `first-run.md` |
|---|---|---|---|---|---|---|
| PromptUiGui | Sibling / Sibling | A: 1, B: 311894726 | 1 / 311894726 | 1 / 311894726 | yes, yes | none vs none |
| AdminLevelGui | Sibling / Sibling | 391654033 | 391654033 / 391654033 | 391654033 / 391654033 | yes, yes | Panel 300 x 200 vs 300 x 200 |
| DamageDirectionIndicator | Sibling / Sibling | 1 (empty) | 1 / 1 (empty) | 1 / 1 | yes, yes | none vs none |
| `CashSpendBurst` (called directly) | Sibling | 1169630659 (8 objects) | 1169630659 | 1169630659 | yes | not in `first-run.md` (coin 37 x 37) |

Live damage arrow in Play 2: mode Sibling, 4 arrows (Play 1 had 3 at the moment of the read; the server fires every 0.4 s), all `ZIndex` 1, Global hash = Sibling hash = 1957893361, equal (the Play 1 value 1635848113 belongs to 3 arrows; the count differed by timing, not by order).

The five unflipped ScreenGuis and Custom Inventory were measured again in both passes and stay Global: their Global and Sibling hashes differ in Play 2 exactly as in Play 1 (CashShop 3821700163 / 269255747, GamepassShop 2420747866 / 4136676954, WeaponaryShop 3516595026 / 1651243858, QuestLog and DeathScreen and Custom Inventory identical to Play 1). The three shop lists changed between Plays (sibling indexes in the paths differ: those panels build their children in an order that is not the same on every run); that does not touch the decision.

Notification: the card was seen live in Play 2 under `NotificationGui` (Sibling): `Container(z1), Card(z4), TitleLabel(z1), MessageLabel(z1), AccentEdge(z2), MessageLabelIcon(z1)`.

Unit tests (temporary server Script, removed before Play stopped): 171 run, 171 passed, 0 failed; 0 `[FAIL]` lines through `LogService.MessageOut`.

Console (distinct warning/error lines, Client 37 of 449 messages: 1 output, 158 warnings, 290 errors; Server 46 of 512: 205 output, 177 warnings, 130 errors): every distinct line is in a known class from `first-run.md` and the baseline: ContentId warnings and failed sound/animation loads, `Infinite yield possible on 'Workspace:WaitForChild("WeaponAnimationPreview")'`, and the unit-test persistence noise. No line about the four edited scripts; no `HumanoidRootPart` error. No new line.

Capture: `CityMerge/screenshots/phase2b-task4-play2-hud.jpg` beside the Play 1 one: the same HUD (cash 300, hotbar, quest banners); none of the four flipped ScreenGuis draws anything visible without a trigger, so the two captures show the HUD around them only. Both taken once.

## Result

**Flipped to Sibling (4), all by one line after `Instance.new("ScreenGui")`:**
- `PromptUiGui` (`PromptUiController`): lists equal at 0 and 4 objects.
- `AdminLevelGui` (`AdminLevelController`): equal, 6 objects.
- `DamageDirectionIndicator` (`DamageDirectionIndicator`): equal; empty at rest, and with live arrows (3 and 4) all `ZIndex` 1.
- the cash burst gui `CashSpendBurst` (`ReplicatedStorage.UI.CashBurst`): equal; every coin `ZIndex` 1 (trivially order-equal). Caught alive only through a direct `burstFrom` call, not through the purchase.

**Left Global (6), with the reason (lists differ):**
- `CashShopGui`: 233 swapped pairs, none overlapping.
- `GamepassShopGui`: 51 swapped pairs, none overlapping.
- `WeaponaryShopGui`: 609 swapped pairs, none overlapping (it was already left Global on purpose, see the trap note).
- `QuestLogGui`: 2 swapped pairs, none overlapping.
- `DeathScreenGui`: 3 swapped pairs, all overlapping (container z5 over children z2), all hidden at the time of the read.
- `Custom Inventory` (Creator Store package, property untouched): 123 swapped pairs, none overlapping.
