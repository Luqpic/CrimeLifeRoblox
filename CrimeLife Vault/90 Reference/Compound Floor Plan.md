---
type: reference
tags: [reference, tycoon, building, floor-plan, crimelife-tycoon]
updated: 2026-11-17
sources: ["CrimeLifeRoblox/docs/crimelife-compound-plan.html", "CrimeLife Vault/90 Reference/Original Prompts/Tycoon/2026-11-17 Compound Floor Plan.md", "docs/crimelife-hq-blueprint.html"]
---

# Compound Floor Plan

The drawing set the developer's hired builder works from for the CrimeLife tycoon base. It **supersedes the tower-style HQ blueprint** (`Documents/Roblox/docs/crimelife-hq-blueprint.html`, drawn 2026-09-30) and the 2023 tycoon build as the layout to build.

- **PDF:** `CrimeLifeRoblox/docs/crimelife-compound-plan.pdf` (A4 landscape, 16 pages), printed from the HTML; reprint after any change to the HTML.
- **Look:** modern industrial (2026-11-18), not scrappy: light-grey concrete, charcoal cladding, black steel, big glass, warm wood, LED strips, a safety-yellow accent. Front company "Southside Logistics".
- **Reference image:** `CrimeLifeRoblox/docs/compound-views/compound-top.png` (top view of the block model) plus `flow-prompts.md` for Google Flow. Re-render after layout changes (headless Chrome on the HTML with `#view-Top` etc.).
- **Page:** `CrimeLifeRoblox/docs/crimelife-compound-plan.html` is a standalone file (doctype + UTF-8 added) that the developer sends the builder directly; it opens in any browser and needs internet for the fonts and the 3D view. The same page is also published as a private artifact at https://claude.ai/artifact/Q9v2zXssGBmYU81wWsfmQ3. The builder can open it only after the developer shares it from the page's Share menu.
- **Sheets:** a 3D block model (orbit, level toggles, Explode, Fixtures), S-00 Site, S-01 Ground, S-02 Upper, S-03 Roof terrace, S-04 Bunker, S-05 Section + unlock order. Each sheet has a room schedule with X/Z ranges, sizes and fit-out notes.
- **Prompt and answers:** [[Original Prompts]] (`Tycoon/2026-11-17 Compound Floor Plan.md`). Decisions: [[CrimeLife Tycoon Decisions]].

## The layout in short

- **Plot 361 × 300** (the whole base plate). Origin at the NW corner, +X east, +Z south. Levels: B1 −24 to 0, G 0 to 20, F2 20 to 40, roof terrace at 40 with a parapet to 44.
- **Building** x 4–268, z 36–280, with the SE corner cut on a diagonal (268,232)→(220,280). Rooms ring an **open Yard** (an octagon, x 72–200, z 96–212) that holds the player spawn pad and a 36 × 36 fight pit. A 16-wide covered deck (G) and gallery (F2) wrap the yard.
- **East side:** a 32-wide drive lane (x 268–300) from the south gate to the north service lane. The garage bays open onto it. A skybridge at F2 (z 54–66) crosses the lane to the Watchtower (x 300–356, z 44–104, 60 tall). Parking, gatehouse, and corner towers T1–T3.
- **Ground:** Bar + Stage, Dispatch, Scrap Foundry, Warehouse, Core, Tailor, Weapon Shop, Reception (main glass entrance on the south), Display Armory, Chop Shop, Garage Bays 1–2, Showroom + Bay 3.
- **Upper:** Counterfeit Printers, Cash Counting, Boss Penthouse, Exec Hall, Lounge, Meeting Office, Shooting Range, Weapon Workshop, Upper lobby, and one **spare slot** (x 4–56, z 80–150) left free.
- **Roof:** Roof Terrace over the south wing and the cut corner, a stair house, and a service roof.
- **Bunker** (under the west wing and the yard): Generator Room, Interrogation, Gold Refinery, Vault, Blast Corridor, Weapon Cache, Cells C1–C3.
- **Money lines:** Foundry (G), Printers (F2), Chop Shop (G), Gold Refinery (B1). The unlock order runs stages 0 to 8. Prices are not set.

## How it gets bought and built (2026-11-17)

- **No buttons.** CrimeLife reuses Outbreak Tycoon's build mechanics: everything is bought from the BUILD menu and drops into place. The plot has no button pads or price boards. The builder makes one model per purchase, sorted by floor (Ground, Upper, Roof, Bunker, Outside) and section, splits each into a few sub-models for the drop-in, and adds a `CameraPoint` part per purchase. The builder is new and does not know Outbreak Tycoon, so the page explains the BUILD menu from the player's side (cards, camera, hologram, BUY, drop-in) and builds the whole base finished in place, because the scripts hide unbought purchases.
- **Build in order, never remove.** No temporary roof caps and no early fence. Each floor's structure includes its ceiling slab, which is the next floor's floor. Upper-floor walls stand on the slab edge. The base plate edge marks the plot until the perimeter wall is bought.

## Changes from the HQ blueprint

- Four stacked levels (B1, F1, F2, F3) on a 200 × 200 footprint became a flatter ring around a yard, following the developer's reference screenshot.
- Weapon Shop, Display Armory and Tailor moved from F2 to the ground floor. Range, Meeting Office, Lounge, Exec Hall and Penthouse moved from F3 to F2.
- Four corner towers became three corner towers plus one larger Watchtower on a skybridge.
- The yard is new: spawn and fight pit.
