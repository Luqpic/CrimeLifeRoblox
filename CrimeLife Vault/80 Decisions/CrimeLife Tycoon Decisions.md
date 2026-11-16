---
type: decision
tags: [decision, tycoon, merge, crimelife-tycoon]
updated: 2026-11-16
sources: [".superpowers/sdd/2026-11-16-robbery-systems-into-city/progress.md", "CrimeLifeRoblox/CityMerge/phase3/classification.md", ".superpowers/sdd/2026-11-15-fps-systems-into-city/progress.md", "The developer's request and answers in the 2026-11-14 planning session", "CrimeLife Vault/90 Reference/Tycoon Market Research 2026-11.md", "CrimeLife Vault/90 Reference/Four Places Survey 2026-11-14.md"]
---

# CrimeLife Tycoon Decisions

The product calls for **CrimeLife Tycoon**: the game made by merging FPS System, Robbery System and the tycoon building into Crimelife City. Evidence: [[Tycoon Market Research 2026-11]] and [[Four Places Survey 2026-11-14]]. The design is `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`, approved by the developer on 2026-11-14 ("Approve design"). Build plans are written one phase at a time in `docs/superpowers/plans/`.

## 2026-11-15: the FPS port and the tycoon building

Made during the overnight run recorded in [[2026-11-15 FPS Systems Into City]]. Quoted text is the developer's own.

### The developer's calls
- **Saving at checkpoints.** "Yes, save at checkpoints": Claude may save `Crimelife city.rbxl` after each finished task that night; never publish. A one-night permission ([[Save and Publish Rules]]). The on-disk file was copied first to `Crimelife city BACKUP pre-cleanup 2026-08-20.rbxl`.
- **When the city differs from the FPS place:** "Fix it in the city and continue". The FPS place stays untouched.
- **Scope for the night:** "HQ in the city + FPS playable there". Later phases get plans only.
- **The HQ goes in by copy-paste.** "I'll copy-paste it now": Test30.4's window refused the local transfer, and the developer pasted `Workspace.HQ` into the city's `ServerStorage`.
- **How far to go:** "run until the very end ... everything is made according to plan and polished".
- They asked "where's the tycoon building?" and expected it in the city; it is phase 4 in the approved order, so a static preview was built on `Plot3` (below).

### Claude's calls
- **Crimelife City is the primary place; FPS System is frozen** as the reference the port was taken from. This follows the approved design (the developer chose the city as the merge target on 2026-11-14). [[Which Project This Is]].
- **Enemy placement rules:** each of the six points at least 180 studs from the spawn, 120 from every plot and from the tycoon preview, 130 from every quest giver, 60 from every other point and robbery building, on a road or footpath, not on the arm toward Plot3; weakest enemy nearest. Positions are provisional.
- **The preview stands on `Plot3`**, the plot nearest the city spawn (any plot would do; `PivotTo` moves it). `ServerStorage.HQ` stays as the untouched source for phases 4 and 5.
- **Fix the class, not the instance** for the client load-order race, and leave `PromptUiController` unchanged.

## Newest first (2026-11-14)

Under this heading, all made by the developer on 2026-11-14, by picking from offered options. Quoted text is the developer's own.

### The game
- **Why a new game:** OBT "isn't pulling a lot of players nowadays"; "this game was prominent back in 2021. Now it's 2026." CrimeLife Tycoon is "also a tycoon" but "more innovative and fun", "more into cartoonish and low poly unlike OBT".
- **What was fun in OBT, to carry over:** building up the base, fighting (PvE or PvP), playing with friends, unlocking gear and vehicles. All four were picked.
- **Feels closest to an open-city crime game**: a shared city with robberies and chases, the tycoon base as home and income.
- **Selling point: base plus open-city heists.** The base grows from what is stolen in the city.
- **One base per player at launch; a shared crew HQ comes later.**
- **Players can raid each other's bases**, only while the owner is online, with a cooldown.
- **Police are NPCs only.**
- **Combat is first-person with a third-person toggle.**
- **The tycoon earns income.** "There's some income made in this tycoon": the four money lines in `docs/crimelife-hq-blueprint.html`.

### The build
- **Base plots stand inside the shared city**, on the blue baseplates.
- **Six players per server**, "because there's 6 placeholder blue baseplates".
- **The tycoon building is `Workspace.HQ.Building` from Test30.4.** `HQ.V1` and `Ace` are left behind.
- **The city art is kept and lightened**, not restyled: duplicates out, streaming on, the heaviest models simplified.
- **Claude may remove the city's free-model scripts and duplicate buildings on its own judgement** and report afterwards.
- **The merge happens directly in `Crimelife city.rbxl`**, not in a copy.
- **The casino is a heist target with no betting.**

### How it is built (picked after the questions)
- **Heists feed the base by hauling loot home**: carry it to your HQ past police and rival players; it pays more there and supplies the money lines.
- **The tycoon is one data-driven service** with server-computed income that saves and earns while away, not the marketplace kit.
- **Buying can remove parts**: "the tycoon has parts that needs removal and what not (buy this and it will remove certai parts)". The catalog must carry each purchase's remove-list, read from the kit's buttons in `HQ.Building` before they are stripped (phase 4).
- **Reuse OBT's systems**: "you can just reuse some of the existing systems from OBT such as the build menu, ect." OBT is read, never edited; which systems and what changes in the port are in `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`.

- **Six players, two spare plots**: the city has eight blue plates; two stay empty.
- **The base yard shrinks to fit the 300 by 361 plate**; the blueprint's 360 by 360 plot gives way.
- **PvP in the city, bases safe**: plots are safe zones with owner-only doors until raids ship.
- **The base earns a trickle; heists are the main income.**

### Scope
- **First milestone: a playable merged build**, with no date. Spawn, shoot, rob and own a basic base in one place; new systems come after.
- **Monetization covers** gamepasses and skins as today, a season pass, and private servers. Paid base cosmetics were not picked.

## Open, raised by these calls

- With six players a server, raids and the later crew HQ have few targets. Accepted for now; revisit after playtests.
- Merging without a copy leaves no clean fallback inside Studio. A file copy made in Finder before the first cleanup costs nothing.
- Two calls in the design are Claude's and unconfirmed: one drivable car from OBT in the first milestone, and Moderate as the maturity target.

## 2026-11-15, phase 2b (hardening in the city)

The developer's call, quoted: "Run, save checkpoints". Claude saved `Crimelife city.rbxl` after each task whose review was clean, never published ([[Save and Publish Rules]]).

Claude's calls (the controller's rulings, from `.superpowers/sdd/2026-11-15-fps-hardening-in-city/progress.md`; the developer has not confirmed them):

- **A missing rate limit alone is OK plus a note, but `Shoot` rate of fire is a FIX.** 100 swings a second kill everything in reach and pay out (rule c). It is enforced on claimed timestamps (already bounded to the last second of server time) with a 10% margin under the interval. Cost if wrong: legit shots dropped under lag, unverifiable without a person shooting.
- **Rate state is keyed by player and weapon name, not by Tool.** The wording "per tool" was the defect: a fresh clone reset the limit. Cost if wrong: two copies of one weapon share a cooldown, which is the intent.
- **`SetLevelRequest` NaN is a FIX** (one line): NaN reached the save. Admin-only, so low stakes either way.
- **Accept and turn-in need the character within 30 studs of the giver** (`MAX_INTERACT_DISTANCE`, from the prompt distance of 10).
- **OK plus a note, no change:** re-slotting a held weapon leaves a second copy; a skin can be stored for an unowned weapon type; one burst after idle; out-of-range ray keys pass the canonical check and `ShotResolver` skips them.
- **A completion toast must not replay on restore.** Fix on the client with a server signal (player attribute `QuestsRestored`, set last by the hydrator); the smallest change that does not reorder the load. Cost if wrong: one more attribute.
- **Non-table quest data in a profile is repaired to `{}` in `hydrate`**, and `restore` gets tests for a lowered target, huge progress and a Completed entry: cheap data-loss prevention.
- **ScreenGuis flip to `Sibling` only where the paint order is measured equal.** Four flipped, six left `Global` ([[Open Items]]).
- **Created test modules count in the expected-difference list** of the closing checksum run; edits to a script that already carries `CityMergeDeviation` append to the attribute, never overwrite it.
- **26 empty files with leading-space names in `CityScripts/` are left alone.** A failed shell loop in Task 1 made them; the implementer's delete was blocked by a safety check, so the controller did not delete them on its behalf. They are hidden from git through `.git/info/exclude` and were reported to the developer. Cost if wrong: clutter only.
- **`Workspace.HQ` is left untouched.** It (58,277 descendants, 24 enabled scripts) appeared in the place during the run, was not added by any task and was the selected object in Studio. The controller saved with it present, because removing it is the developer's call. Cost if wrong: a heavier saved place until it is removed (`ServerStorage.HQ` still holds the source).
- **Work stays on `main`** (vault convention, the developer's standing consent for commits; not pushed).

## 2026-11-16, phase 3 (the four heists in the city)

The developer's words, quoted: "Plan phase 3" (the plan for this phase), "Run, save checkpoints" (run it; save `Crimelife city.rbxl` after each task whose review is clean; never publish; the Robbery and FPS places stay frozen) and "Both are open, go" (the city and the Robbery window were opened for the run). Claude saved at each clean checkpoint and never published ([[Save and Publish Rules]]).

Claude's calls (the Task 1 gate G1 to G12 in `CityMerge/phase3/classification.md`, then the controller's rulings, from `.superpowers/sdd/2026-11-16-robbery-systems-into-city/progress.md`; the developer has not confirmed them, and the batch note asks for review: [[2026-11-16 Robbery Systems Into City]]):

- **Ruling G1: the Bank vault goes underground** below its transformed spot, split from the lobby by containment (the top 40 studs below the lowest city geometry, reached only by the teleporter; the code calls it underground). Cost if wrong: the look differs; one `PivotTo` moves it.
- **Ruling G2 and G3: registration yaws and translations for all four locations.** Cost if wrong: under 0.25 stud.
- **Ruling G4: `CurrencySpec` retired** to `ServerStorage.CityQuarantine.RetiredSpecs`; the Robbery currency adapter and backends are left behind and a bridge writes `leaderstats.Cash` (one cash system). Cost if wrong: 11 cases out of the suite, and the Robbery save layer is not in the city.
- **Ruling G5: one cash display**, the city's `Custom Inventory.cashDisplay`; `CashClaimVFX` stops building `CashDisplay` and flies coins there. Cost if wrong: visual only.
- **Ruling G6: the Robbery `NotificationGui` is renamed `HeistNotificationGui`** and its stack moved clear of the city's. Cost if wrong: two notification styles remain on screen (they do: [[Open Items]]).
- **Ruling G7: add `MenuFovBlur.acquire`** to the city's copy. Cost if wrong: none.
- **Ruling G8: carry `UiButtonEffects`** (puzzle focus mode and button effects). Cost if wrong (Claude's estimate, not in the ledger): the puzzles lose focus mode; one script to remove.
- **Ruling G9: tag every `ServerStorage.Weapons` Tool `Weapon`, with a city test guarding it.** Cost if wrong: melee can start a robbery.
- **Ruling G10: `HeistClient` stops re-enabling the Backpack core GUI** (two `SetCoreGuiEnabled` arguments become `false`). Cost if wrong (Claude's estimate): the core backpack could reappear next to the city's hotbar; two lines to revert.
- **Ruling G11: `Illegal Supplier` moves with SlowFoods.** Cost if wrong (Claude's estimate): the supplier stands in the wrong place; one `PivotTo`.
- **Ruling G12: transform the three `openCFrame` literals in-script** (`SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer`). Cost if wrong (Claude's estimate): a lockpicked door opens at the old coordinates; the Robbery value is kept in a comment on each line.
- **Ruling: the unrequested `RunAll` edit is accepted** (`CurrencySpec` dropped from its list): the direct consequence of G4. Cost if wrong: none.
- **Ruling: the Bank keeps `EscapeDistance` 200** although only 5 of its 32 ring points are clear ground (the rule's threshold is 8): the ring only needs one reachable road exit, and Task 4 walked the Bank escape along a road to prove it. Cost if wrong: the Bank is harder to bank; tuned in playtests.
- **Ruling: the marker Folders became Models of the same name with `ModelStreamingMode = Persistent`:** no script path changed and both getaway readers read the same part. Cost if wrong: four small models always streamed.
- **Ruling: the character-removed case is a FIX carried into Task 5** (void the bag on `CharacterRemoving`, with a spec), not fixed in Task 4: no client can reach `LoadCharacter` without dying today, but a removed character should bank nothing. Cost if wrong: one extra hook.
- **FIX approved: `SubmitSupplierChoice` gets a reach check** (refuse unless the root is within 15 studs of `Illegal Supplier.Interaction`; the sale body moves into `Heist.Services.SupplierSale` with a spec): a client could sell 10,000 to 20,000 of supplies from 1,000 studs away. Cost if wrong: an honest seller just outside 15 studs is refused.
- **Ruling: also clear `SuppliesServer`'s carry state on `CharacterRemoving`:** the same principle, a removed character keeps nothing. Cost if wrong: a carried barrel lost on a server-side respawn.
- **Ruling: `GamepassManager` re-checks ownership with `pcall(UserOwnsGamePassAsync)` before caching** a purchase: a client-reported flag is not proof, and with the placeholder id `0` one accepted event grants the x4 duffel. Cost if wrong: one web call per purchase.
- **Ruling: the NewsStation safe enforces a minimum interval between a player's attempts** equal to the prompt's `HoldDuration` (8 s), because a prompt's hold is enforced on the client; with a spec. Cost if wrong: none for honest players.
- **Ruling: `LockpickStopRequested` is OK plus a note:** the client already holds every timing input. Cost if wrong: a cheating client picks any instant in the last second.
- **Ruling, fix round 1: the purchase confirm clears the cached entry and retries** (up to 3 pcall'd `UserOwnsGamePassAsync` attempts 2 s apart; caches true on success, leaves nil otherwise so the next read re-queries; spec "cached false, then purchase confirmed -> owned"). The first ruling's premise was incomplete: a stale false right after a real purchase gave the buyer nothing for the session. Cost if wrong: one short retry loop per purchase.
- **Ruling: the vault update belongs to Task 6,** as the plan orders: the batch note and its commit satisfy the review's "batch rule" finding. Cost if wrong: none.
- **Ruling (plan): cooldowns follow the specs** (1200 and 600; "spec values win"); the developer reviewed the plan and said "Run, save checkpoints". Cost if wrong: SlowFoods and Gas2Go reopen after 20 and 10 minutes instead of 1.

Related: [[Economy and Progression Decisions]], [[Robbery Decisions]], [[Decisions MOC]].
