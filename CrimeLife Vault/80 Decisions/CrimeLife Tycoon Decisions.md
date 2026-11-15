---
type: decision
tags: [decision, tycoon, merge, crimelife-tycoon]
updated: 2026-11-15
sources: [".superpowers/sdd/2026-11-15-fps-systems-into-city/progress.md", "The developer's request and answers in the 2026-11-14 planning session", "CrimeLife Vault/90 Reference/Tycoon Market Research 2026-11.md", "CrimeLife Vault/90 Reference/Four Places Survey 2026-11-14.md"]
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

Related: [[Economy and Progression Decisions]], [[Robbery Decisions]], [[Decisions MOC]].
