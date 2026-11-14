# CrimeLife Tycoon: Game and Merge Design

Date: 2026-11-14. Status: **approved by the developer on 2026-11-14**.
Evidence: `CrimeLife Vault/90 Reference/Tycoon Market Research 2026-11.md`, `CrimeLife Vault/90 Reference/Four Places Survey 2026-11-14.md`, `docs/crimelife-hq-blueprint.html` (in `Documents/Roblox/docs/`).
Decisions already made by the developer: `CrimeLife Vault/80 Decisions/CrimeLife Tycoon Decisions.md`.

Lines marked **(Claude's call)** were not decided by the developer and can be overturned.

## 1. Intent

Outbreak Tycoon was built for 2021 and no longer pulls players. CrimeLife Tycoon is a cartoonish, low-poly crime tycoon for 2026: a shared open city where you rob, and a base that grows from what you bring home. It should hold players for weeks, give friends a reason to play together, and offer one thing no other crime game has.

**The selling point:** a persistent base plus open-city heists, joined by the haul home. Jailbreak has the city without the base; base games have the base without the city.

## 2. Goals, non-goals, anti-goals

**Goals**
- One place (`Crimelife city.rbxl`) containing the city, the FPS systems, the robbery systems and the tycoon base.
- First milestone: a playable merged build. Spawn, claim a plot, shoot, rob, haul loot home, buy base buttons, rejoin with everything saved.
- The base and the city need each other every session.
- Runs on phones.

**Non-goals for the first milestone**
- Raids, the season pass, private servers, the crew HQ, player police, a restyle of the city art, a balanced economy (prices stay placeholders until playtests).

**Anti-goals** (failure even if it works)
- A dropper tycoon with a city attached: income that never requires leaving the base.
- Losses that make a young player quit: raids never take banked cash or built rooms.
- Any playable gambling. The casino is a heist target only.
- Anything that needs text chat to work.

## 3. Constraints

- **Six players per server**, one plot each.
- **Phones first** (`10 Rules/Phones First and Keep Optimised`). The city today is 264,072 instances with streaming off.
- **Claude never saves or publishes.** The developer saves. The merge runs directly in `Crimelife city.rbxl` with no in-Studio fallback.
- **Shared modules win; weapons extend by attribute** (existing CrimeLife rules).
- **Roblox policy:** cartoon violence to keep the maturity label low; paid random items are avoided entirely **(Claude's call)**.
- Persistence can only be proven on a published place; until then it runs on the mock store.

## 4. Approaches considered

**How heists feed the base**

| Approach | Trade-off |
|---|---|
| **A. Haul it home (chosen)** | Loot must be carried to your HQ past police and rivals; it pays more there and supplies the money lines. Most work; the only option where city and base meet every session. |
| B. Loot unlocks stages | One special item per money line. Simple, but the link ends after the unlock. |
| C. Cash only | Fastest. What every tycoon already does. |

**How the tycoon is built**

| Approach | Trade-off |
|---|---|
| **A. One data-driven service (chosen)** | Stages and pads in one config table, server-computed income that saves and earns while away. Droppers become visuals. |
| B. Keep the marketplace kit | Quick, but 236 unnamed scripts, no saves, physical drop parts for six bases. |

On the same day the developer added that OBT's systems can be reused. OBT's tycoon core is already approach A, so A is delivered by porting it, not by writing it new (section 6).

The developer picked A for both on 2026-11-14.

## 5. The core loop

1. **Rob.** Trigger a heist in the city (Bank, SlowFoods, Gas2Go, NewsStation, later Casino and Warehouse). Puzzles and the duffel work as they do today.
2. **Haul.** Leaving the building starts the haul. NPC police pursue. If you die, the duffel drops where you fell and any player can pick it up.
3. **Bank at your HQ.** Carrying the duffel onto your plot's drop-off banks it: full cash, plus the heist's material.
4. **Supply the lines.** A material puts its money line into "hot" production for a time.
5. **Build.** Cash buys the next button. New rooms unlock gear, the weaponry, the garage, the next money line.
6. **Go bigger.** Better gear opens harder heists with better materials.

**Quick stash (Claude's call):** getting 200 studs clear, as today, still banks the bag, but at half cash and with no material. It keeps a heist worth doing for a player far from home and keeps the tested getaway code alive.

**Materials (Claude's call; names and sources are placeholders)**

| Material | Stolen from | Feeds |
|---|---|---|
| Scrap | SlowFoods, Gas2Go | Scrap Foundry (F1) |
| Printing plates | Bank | Counterfeit Printers (F2) |
| Cars | Street, later Warehouse | Chop Shop (Garage) |
| Gold | Casino | Gold Refinery (B1) |

## 6. The tycoon

The building, rooms, 26 pads, nine stages and four money lines are those of the blueprint. The code that runs them is **Outbreak Tycoon's tycoon core, carried over**, at the developer's direction ("you can just reuse some of the existing systems from OBT such as the build menu"). OBT already has the data-driven service chosen in section 4, built and tested: one buy path, a catalog, server-computed income, offline earnings, and a template cloned per plot. Writing a second one would be waste.

**Carried over from OBT** (source: `studio-mirror/`, described in `OBT Vault/20 Systems`). OBT itself is only read, never edited.

| OBT system | Used in CrimeLife Tycoon for | When |
|---|---|---|
| `TycoonService` (`Buttons`, `Catalog`, `Config`, plot claim, template build) | The base: claiming a plot, buying, building from `ServerStorage.TycoonTemplate` | Phase 5 |
| `DropperService`, dropper visuals, collector | The four money lines and the collector | Phase 5 |
| Build Menu (cards by floor and section, camera, cutaway, hologram) | The way to buy base purchases; the blueprint's pad strips become its entry points | Phase 5 |
| Offline earnings (Welcome Back card) | Away income | Phase 5 |
| Vehicles and Garage | Driving the haul home; the Garage stage | Phase 6 |
| Security and Guards | Stage 8 towers and guards; the defence against raids | With raids |
| Rebirth | The long ladder after stage 8 | After the milestone |
| Daily Quests, Codes and Daily Rewards, First Goals, Onboarding Funnel | Daily contracts, rewards, the first-hour chain, the new-player funnel | Weekly cadence |
| Outbreaks scheduler, Supply Truck | Timed city events and a rotating shop | Weekly cadence |

**What has to change in the port (Claude's calls)**

- **One cash figure.** OBT keeps money in `profile.tycoon.Money`; CrimeLife's is `leaderstats.Cash` through `CashService`. The ported tycoon reads and writes CrimeLife's cash. There is never a second balance.
- **One save system.** OBT's purchases move into CrimeLife's profile as a `tycoon` table in `Schema.template`, adopted through `ProfileGateway` like every other CrimeLife service. OBT's own save module is not brought over.
- **One look.** Ported panels are re-skinned onto CrimeLife's `Theme` / `UITheme` and Figma slices; OBT's `UIShell` is not brought over. The Build Menu's logic, camera and cutaway come as they are.
- **Catalog.** OBT's lab catalog is replaced by one built from the blueprint: every purchase with its floor, section, stage, price and camera point. Prices start at the blueprint's bands.
- **Streaming.** OBT requires `Workspace.ModelStreamingBehavior = Legacy` or plots stream out. The city's streaming setup in phase 1 must respect that.
- OBT-only content stays behind: walkers, serum, gacha, morphs, minions, bosses.

**What is new, on top of the port**

- **Uncollected income held in the base.** Income accrues to an uncollected balance (the Counting Room cash pile and the Vault gold stack, as the blueprint draws them) with a cap that grows by stage, paid to Cash at the collector **(Claude's call)**. This is what raids later steal from.
- **Hot production.** A banked material doubles its line's rate for a fixed time; more of the same material extends it up to a cap **(Claude's call; numbers are placeholders)**. A line never stops without material: the base always earns, heists make it earn faster.

## 7. The merge

Order matters: each phase ends with the game runnable and measured.

| Phase | What | Done when | Model |
|---|---|---|---|
| 0. Baseline | The developer copies the file in Finder. Measure instance count, memory and frame rate at phone settings. | Numbers recorded in the vault | Sonnet |
| 1. City cleanup | Remove the 636 free-model scripts, the duplicate buildings and the loose tycoon parts; group Workspace into named folders; turn streaming on. | Same city on screen, measured lighter, no script errors | Sonnet, Fable reviews the delete list |
| 2. FPS in | Bring over the FPS services, UI, enemies, quests and persistence. | The FPS unit tests pass in the city; a player can spawn, buy, shoot and level | Opus |
| 3. Robbery in | Swap the city's unscripted robbery buildings for the Robbery place's scripted ones; move robbery cash onto `CashService`; one copy of each shared UI module. | The heist specs pass; a heist banks into `leaderstats.Cash` | Opus |
| 4. Plots and HQ | Turn `HQ.Building` into one clean template (kit scripts out, buttons tagged per the blueprint); place the plots. | A template builds onto every plot within the measured budget | Opus |
| 5. Tycoon core from OBT | Section 6: port, adapt cash, saves and look, new catalog, then uncollected income. | Buy from the Build Menu, earn, collect, rejoin with the base rebuilt | Opus |
| 6. Haul it home | Section 5: drop-off, dropped duffels, materials, hot production, a drivable car from OBT's vehicles. | A Bank job hauled home pays more than a quick stash and heats the Printers | Opus |

Phase 6 completes the first milestone. Fable writes each phase's plan and reviews each batch.

## 8. After the milestone, in order

1. **Third-person toggle**, finishing the third-person weapon hold.
2. **Raids.** A rival enters your HQ while you are online and carries off part of your *uncollected* income as a duffel. You are alerted; dropping the raider returns it. A per-base cooldown follows. Banked cash and rooms are never touched. Stage 8's towers and guards become the defence.
3. **The weekly cadence.** A featured heist each week with a boosted material, daily contracts, analytics events on every step of the loop, then the season pass and private servers.
4. **Crew HQ.**

With six players a server, raids and crews have few targets. That is accepted for now and revisited after playtests.

## 9. Existing systems improved on the way in

These open items are closed by the phase that touches them, not left for later:

- Robbery cash runs on `PlayerData.CurrencyService`, FPS cash on `CashService`: unified in phase 3.
- The getaway distance formula exists twice (server and client): hoisted into one shared module in phase 6, when it changes anyway.
- `CashClaimVFX` and the two config specs fail in the Robbery place: fixed in phase 3.
- The remote ownership audit (`UpgradeRequest` shipped without a check): every remote is checked as it is ported in phases 2 and 3, and every new tycoon remote is written with one.
- Eleven ScreenGuis still on `ZIndexBehavior.Global`: fixed in phase 2.
- Quest progress is not saved: added to the schema in phase 2.

Not in scope: placeholder gamepass ids, the unpublished animations and the sound permissions. Those need the developer.

## 10. Calls made after a reviewer's read (all Claude's calls)

- **No live saves exist.** The FPS place has only ever run on the mock store, so the schema may gain fields freely. The standing rule still holds: `Schema.VERSION` only moves forward. Which universe the game publishes under is the developer's choice at publish time and does not change the build.
- **No OBT save import.** OBT players' data never enters CrimeLife Tycoon.
- **The built model wins over the blueprint.** Phase 4 opens with a room-by-room comparison of `HQ.Building` against the blueprint. The catalog is written to match what is built; anything the blueprint draws that is missing (a pad strip, the cash pile, the gold stack) goes on a list for the developer to model.
- **The HQ must get lighter.** `HQ.Building` is 52,304 instances; six of them would outweigh the city. Phase 4 includes a reduction pass, a base is only built on a claimed plot, and unbought purchases do not exist as instances.
- **Performance targets are set at the end of phase 0**, from the measured baseline and the FPS place's own numbers, and agreed with the developer before phase 1. Every later phase is measured against them.
- **The city's layout wins.** In phase 3 the Robbery place's scripted buildings move to where the city already has those buildings. Getaway distances are re-measured there.

## 11. Left to the builder

File layout inside each service, remote names, UI layout of the collector and the haul widget (built from the existing Figma slices and `UITheme`), chunk sizes for building a base, and the test cases. Each phase's plan settles these.

## 12. Settled with the developer on 2026-11-14

- **Six players per server, two spare plots.** The two spare plates stay empty.
- **The yard shrinks to fit the 300 by 361 plate.** The city map does not change.
- **PvP is on in the city; bases are safe.** Rivals can fight a hauling player and take a dropped duffel. Plots are safe zones with owner-only doors until raids ship.
- **The base earns a trickle; heists are the main income.** Base rates, the uncollected cap and away income are sized so that a player who never leaves the base progresses slowly. Hot production is therefore worth more than a doubling: the multiplier is tuned in playtests.

## 13. Still Claude's calls, open to correction

- **One drivable car, ported from OBT, is part of phase 6.** The plots are up to about 3,700 studs apart; a haul on foot does not work.
- **The maturity target is Moderate.** Player-versus-player gunfights in the city make Mild unlikely. The Roblox questionnaire decides at publish time.
