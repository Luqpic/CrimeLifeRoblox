# Phase 4: Plots and the HQ Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One clean HQ template in `Crimelife city.rbxl` (the building, its tycoon kit pieces in their rooms, and the whole exterior fitted to the plate) that builds onto every plot, with every mesh loading and every purchase's remove-list recorded.

**Architecture:** Reconcile the three copies of the tycoon content first (Test30.4 `Workspace.HQ` and `Workspace.Ace`, and the kit the city's phase 1 quarantined as `LooseTycoon`), then assemble one template in `ServerStorage.TycoonTemplate` from the city's own copies. The kit's scripts come out; its button data becomes catalog data. The exterior is re-laid onto the 361 by 300 plate, never deleted. A build script places the template on a plot and measures it.

**Tech Stack:** Luau in Roblox Studio; `Roblox_Studio` MCP; `CityMerge/transfer/` for exports of sources; the city's `ServerStorage.UnitTest.RunUnitTest`.

**Spec:** `docs/superpowers/specs/2026-11-14-crimelife-tycoon-design.md`: section 6 (remove-on-buy, catalog, streaming), section 7 (phase 4 row: "Turn `HQ.Building` into one clean template (kit scripts out, buttons tagged per the blueprint); place the plots." Done when "A template builds onto every plot within the measured budget"), section 10 ("The built model wins over the blueprint", "The HQ must get lighter"), section 12 ("The yard shrinks to fit the 300 by 361 plate"). Blueprint: `Documents/Roblox/docs/crimelife-hq-blueprint.html`.

**The developer's words for this phase (2026-11-17), binding:**
- "Not all meshes of models have been imported into the crimelife city, for instance the sign, the brown tables, the droppers and such ... please investigate this matter and ensure everything is exported into Crimelife city from Test30.4".
- "I notice you trimmed out the porch with the trees and outside exterior such as the towers alongside with its roads, I want you include them (modify them to the plot size but don't remove)".

**Found while planning (2026-11-17, read-only, measured):**
- The city's `ServerStorage.HQ` is a complete copy of Test30.4's `Workspace.HQ`: same instance counts per folder, same 11,940 `MeshPart`s, no empty `MeshId`. Nothing was dropped by the copy.
- In a city Play, 91 asset ids fail with "Requester does not have permission for Asset", 80 of them meshes used by **3,441 `MeshPart`s of the HQ** (1,811 Industrial floor, 700 Bunker, 531 Executive floor, 327 Ground floor, 72 Garage wing; 113 of the 121 table meshes). The sampled ones are private meshes uploaded by one other user account. In a Test30.4 Play only 11 ids fail. Test30.4 has access to those meshes; the unpublished city file does not.
- `HQ` holds no dropper, conveyor or collector. Test30.4's tycoon kit is in `Workspace.Ace` (28,769 instances, 268 scripts; `Ace.Old.Model` holds 8 droppers, 14 signs, 16 buttons with `DeleteObjects`), which was left behind on 2026-11-14. The city already holds a larger kit in `ServerStorage.CityQuarantine.LooseTycoon` (22,014 instances; 16 droppers, 16 signs, 87 `DeleteObjects`), quarantined in phase 1. Test30.4 also has `Workspace.Blocking` (401 instances) and two loose Models (6 and 4 instances).
- Sizes: the plate is 361 by 300. The building is 213 by 310 (x -686..-473, z 128..438 in the source; 20 stray block-out parts extend the folder's box to x 326). The exterior: `Fence` 370 by 370, `V1` (grass, vegetation, models) 381 by 378, `Road` 340 by 280.

**Models:** Fable writes gates and reviews. Opus builds Tasks 1, 3, 4 and 5. Sonnet runs Task 6 and the reviews.

**Before running:** the developer opens `Crimelife city.rbxl` and `Test30.4` in Studio. Saving the city at checkpoints needs the developer's word for that run.

## Global Constraints

- Target place: **`Crimelife city.rbxl`**, resolved by name before every write. `Test30.4`, `Robbery System.rbxl`, `FPS System.rbxl` and every OBT place: Play and read only, no edit, no save. Test30.4 refuses the local transfer store; that is not worked around: content only it holds comes over by the developer's copy-paste (Task 2).
- Never publish; never change an asset's permissions or ownership. Save the city only with the developer's word for the run.
- **Nothing visible is deleted.** Pieces taken out of the template go to `ServerStorage.CityQuarantine.<Reason>` with `OriginalPath` and `OriginalCFrame` attributes. Only instances with no visual or behavioural effect may be destroyed (a weld between two anchored parts, an empty folder, a duplicate of an identical instance at the same CFrame), and each class destroyed is counted in the batch note.
- The exterior (fence, towers, porch, trees, vegetation, grass, roads) stays: it is re-laid to the plate, not removed. A straight run made of repeated segments may use fewer segments; the spare segments go to quarantine and are counted.
- The building's interior is not re-laid: it moves only as one rigid piece.
- Kit scripts never run in the city. They go to `ServerStorage.CityQuarantine.KitScripts` with `OriginalPath`, after their data has been read.
- The city's existing systems are untouched: 18 city suites **193 / 193 / 0**, the heist suite's failure set (the timing-sensitive `Zone` sweep only), exactly one enabled `SpawnLocation`, `Workspace.HQ` (the developer's paste) untouched.
- Every created or edited script is exported to `CityScripts/` and checked by Adler-32; edited imported scripts carry `CityMergeDeviation`.
- Numbers measured in the run or "not recorded". Git: one commit per task named `Batch: <topic>`, staged by explicit path, `.DS_Store` never, nothing pushed. No key, token, UserId or account name in any file.

## Review Focus

1. **A purchase that removes parts it no longer finds** (a remove-list naming a piece the reduction or the re-lay renamed, merged or quarantined). Every remove-list entry resolves to exactly one template piece. Pinned in Task 3 by `TemplateRemoves_Test`.
2. **Two purchases claiming the same piece**, or a piece in no purchase and not marked always-present. Pinned in Task 3 by the same test.
3. **The template on a plate it was not measured on.** The six city plates differ in position and possibly rotation; each build is checked on its own plate for footprint, ground height and overlap with roads and buildings. Pinned in Task 5.
4. **Meshes that still fail after the developer's fix**, or fail only on some clients. Task 2 counts permission failures in a Play after the fix, and Task 6 again.
5. **The base on a phone.** One built base must stay inside the agreed budget; six must not be built at once. Pinned in Task 5's measurement.

---

## File Structure

| Path | Role |
|---|---|
| `CityMerge/phase4/inventory.md` | The three copies reconciled: what each holds, what the city lacks, the mesh failures with the objects that use them. |
| `CityMerge/phase4/mesh-permissions.md` | Every permission-failing asset id, its use count and areas, the before/after Play counts. |
| `CityMerge/phase4/catalog-draft.md`, `.tsv` | One row per kit button: id, name, the object it builds, price, dependencies, remove-list, room, blueprint stage. |
| `CityMerge/phase4/relay.md` | The exterior re-lay: every exterior piece's old and new CFrame, segments spared, the plate fit checks. |
| `CityMerge/phase4/plots.md` | Per plot: transform, fit, overlaps, instance and memory readings. |
| `ServerStorage.TycoonTemplate` (place) | The one template. Children: `Building` (rigid), `Exterior`, `Purchases` (one Model per purchase), `Removables`, attributes for the plate fit. |
| `ServerStorage.TycoonCatalogDraft` (place, ModuleScript) | Data only: the catalog rows, read by phase 5. |
| `ServerScriptService.TycoonBuild.PlotBuilder` (place, ModuleScript) | `build(plot: BasePart, owned: {[string]: true}?): Model` and `clear(plot: BasePart)`: places the template on a plate, purchases filtered by `owned` (nil = everything, for previews and checks). |

---

### Task 1: Inventory and reconciliation (two legs, controller gate between)

**Files:** Create `CityMerge/phase4/inventory.md`, `mesh-permissions.md`, `catalog-draft.md` / `.tsv`.

**Interfaces:** Produces the gate-approved list of what the developer copies in Task 2, the kit-to-room mapping, and the catalog rows Task 3 turns into data.

Skills to load: `roblox-studio-mcp`, `roblox-world-building`.

**Leg 1 (read only, both windows)**

- [ ] **Step 1: Three copies.** For Test30.4 `Workspace.HQ`, `Workspace.Ace`, `Workspace.Blocking`, the two loose Models, and the city's `ServerStorage.HQ` and `ServerStorage.CityQuarantine.LooseTycoon`: per top-level child, descendant count by class, and a content signature (sorted list of `Name|ClassName|rounded size` per BasePart). Find which pieces are the same object in two copies (signature match) and which exist in only one. For the city's `LooseTycoon`, record its `OriginalCFrame` attributes so its pieces can be placed back where they stood relative to each other.

- [ ] **Step 2: Do the kit pieces belong in the HQ?** Find a rigid offset that lands `LooseTycoon`'s droppers, conveyors, collectors, signs and buttons inside the HQ's rooms (match on shared pieces, as phase 3 registered the robbery buildings), and the same for `Ace.Old.Model`. For each kit piece, record the HQ room it lands in (the room folder whose box contains it), or "outside every room". Compare with the blueprint's four money lines and 26 pads (`crimelife-hq-blueprint.html`): which line and pad each dropper, conveyor, collector and button serves.

- [ ] **Step 3: Meshes.** In one city Play, every asset id that fails with a permission error (from `LogService`), and for each the HQ and kit objects using it (by area). Repeat in one Test30.4 Play. Write `mesh-permissions.md`: the failing ids, their use counts, and the sets that fail in the city only, in both, and in Test30.4 only. Record the asset owner for a sample of ids as "the same account for all sampled" or the distinct count, never the name.

- [ ] **Step 4: Catalog.** For every kit button in the copy Step 2 matched to the HQ (expected: `LooseTycoon`'s 87; also `Ace`'s 16 for comparison): its name, the object it builds (`Object` value), price (`Price` / `CurrencyCost`), dependencies (`Dependencys`), remove-list (`DeleteObjects` values, each resolved to the piece it names, or "unresolved"), its room, and the blueprint stage of that room. One `.tsv` row per button.

- [ ] **Step 5: Propose and stop.** In `inventory.md`, a proposed list of what the developer must copy from Test30.4 (only what the city has no copy of, by signature), which kit copy feeds the template, and every row that needs the gate (unresolved remove-list entries, kit pieces outside every room, blueprint rooms with no kit piece, buttons in both copies with different data).

**Leg 2 (after the gate):** write the rulings into `inventory.md`.

- [ ] **Step 6: Commit.** `git commit -m "Batch: tycoon content inventory"`.

---

### Task 2: The developer's two steps, verified

These are the developer's to do; the task prepares them and checks the result.

- [ ] **Step 1: Copy list.** Write the exact copy-paste list from the gate (Test30.4 path, the city parent to paste into: `ServerStorage.FromTest30_4`), with a one-line purpose for each.

- [ ] **Step 2: Mesh access.** Write the options in `mesh-permissions.md`, in the developer's words: the city must be allowed to load the 80 meshes. Either the account that owns them shares them with the city's experience (which needs the city published as an experience first), or the city is published as a place in the same experience as Test30.4, which already has access, or the owner re-uploads them to the developer's own account and the template's `MeshId`s are swapped (a list of old to new ids would be needed). Claude does none of these.

- [ ] **Step 3: Stop for the developer.** Report both lists. The rest of the plan does not wait for Step 2: Tasks 3 to 5 work with invisible meshes; Task 6 re-checks.

- [ ] **Step 4: Verify the copy.** After the developer pastes: every pasted root's signature equals Test30.4's (Task 1 Step 1 method); `ImportedFrom = "Test30.4"` set on each; scripts inside disabled at once, `KitScript = true`.

- [ ] **Step 5: Verify meshes (when the developer reports it done).** One city Play: count permission failures for HQ and kit meshes; expected 0 of the 80 (the 11 that also fail in Test30.4 are listed apart).

- [ ] **Step 6: Commit.** `git commit -m "Batch: Test30.4 content copied and checked"`.

---

### Task 3: The template, with purchases and remove-lists

**Files:**
- Create (place): `ServerStorage.TycoonTemplate`, `ServerStorage.TycoonCatalogDraft`, `ServerStorage.UnitTest.Cases.TemplateRemoves_Test`, `TemplateShape_Test`.
- Move (place): kit scripts to `CityQuarantine.KitScripts`; the sources used, as copies, so `ServerStorage.HQ` and `LooseTycoon` stay untouched as the record.

**Interfaces:** Produces `TycoonTemplate` with `Building`, `Exterior`, `Purchases`, `Removables`; every purchase Model has attributes `PurchaseId: string`, `Room: string`, `Stage: number`, `Price: number`, `DependsOn: string` (comma list), `Removes: string` (comma list of `RemovableId`s); every removable piece has `RemovableId: string`; `TycoonCatalogDraft` returns `{ [PurchaseId]: { name, room, stage, price, dependsOn: {string}, removes: {string} } }`.

Skills to load: `roblox-world-building`, `roblox-performance`, `roblox-testing`.

- [ ] **Step 1: Failing tests.** `TemplateShape_Test`: the template has the four children; every `Purchases` child is a Model with all six attributes of the right types; `PurchaseId`s unique; every `DependsOn` names an existing purchase and the graph has no cycle; no `LuaSourceContainer` anywhere in the template; every BasePart anchored. `TemplateRemoves_Test`: every `Removes` entry resolves to exactly one `RemovableId`; no `RemovableId` is removed by two purchases unless the gate allowed it; the catalog draft's rows equal the template's purchase attributes. Run: both fail (no template).

- [ ] **Step 2: Assemble.** Copy `ServerStorage.HQ.Building` (without the 20 stray block-out parts, which go to quarantine) as `Building`; copy the exterior (`Fence`, `Road`, `V1`) as `Exterior`; place the gate's kit pieces as `Purchases` at the registered offset. Turn each button's data into the purchase's attributes; give each remove-list target a `RemovableId`, moved under `Removables`. Move kit scripts to quarantine. `TycoonCatalogDraft` written from the same rows.

- [ ] **Step 3: Reduce.** Measure the template's instances by class, then destroy only the no-effect classes the Global Constraints allow (start with `ManualWeld` and `Weld`/`WeldConstraint` whose both parts are anchored, empty folders, exact duplicates), and record the before/after counts. Anything else heavy (for example 3,153 decals in the industrial floor, `Vector3Value` rig data) is listed with a proposal for the developer, not removed.

- [ ] **Step 4: Tests pass.** Both new tests pass; city suites 193 + new cases, 0 failed.

- [ ] **Step 5: Commit.** `git commit -m "Batch: one HQ template with purchases and remove-lists"`.

---

### Task 4: Fit the exterior to the plate (gate on the screenshots)

**Files:** `CityMerge/phase4/relay.md`; place: `TycoonTemplate.Exterior`, template attributes.

Skills to load: `roblox-world-building`.

**Rules (fixed now):**
- The plate is 361 by 300. The building's long side (310) runs along the plate's 361 side, centred, with its entrance side facing the plate's road side (the plate edge nearest a city road; Task 5 measures it per plot). The building moves only as one rigid piece.
- The exterior is laid in the margins that remain (about 25 studs at each end of the long side, about 43 on each flank): grass covers the whole plate; the fence and the outer wall run along the plate's edge, 2 studs inside it; towers go to the plate's corners and gate; the porch and its trees stay at the building's entrance, moved together with their relative layout kept; other vegetation and props keep their order around the building and are moved inward to the nearest free spot in the margin; road pieces join the gate to the entrance and the garage.
- A Part may be resized along its length to fit a run; a MeshPart or union is never stretched. A run of repeated segments uses as many as fit; the spare ones go to `CityQuarantine.ExteriorSpare`.
- Nothing may hang over the plate edge, block the entrance or the garage door, or sit inside the building's box.

- [ ] **Step 1: Re-lay** by these rules; record every piece's old and new CFrame in `relay.md`.
- [ ] **Step 2: Check.** Every exterior part inside the plate box; no exterior part intersecting the building box (with 1 stud clearance) except the porch and road pieces meant to touch it; counts of pieces moved, resized, spared; nothing removed beyond the spares.
- [ ] **Step 3: Pictures, then stop.** Build onto `Plot3` (Task 5's `PlotBuilder` may not exist yet: place a copy by hand and remove it after). Screenshots from four sides and from above (if capture times out, say so). Report to the controller; the controller decides whether the developer should look before Task 5.
- [ ] **Step 4: Commit.** `git commit -m "Batch: HQ exterior fitted to the plate"`.

---

### Task 5: Build onto every plot, measured

**Files:** Create (place) `ServerScriptService.TycoonBuild.PlotBuilder`, `ServerStorage.UnitTest.Cases.PlotBuilder_Test`; `CityMerge/phase4/plots.md`. Remove the old `Workspace.TycoonPreview` to `CityQuarantine` once its replacement stands.

Skills to load: `roblox-performance`, `roblox-world-building`, `roblox-testing`.

- [ ] **Step 1: Failing test `PlotBuilder_Test`.** Against a plate Part made in the test (not parented to Workspace) at a non-zero position and a 90-degree yaw: `build(plate, nil)` returns a Model whose box sits on the plate's top face within 0.1 stud and inside its footprint; with `owned = { [first purchase] = true }` only that purchase exists under the built model and every `Removes` target of it is absent; `clear(plate)` leaves nothing behind. Run: fails (module missing).
- [ ] **Step 2: Implement** `PlotBuilder.build` / `clear` (the template's plate-fit attributes give the anchor; the plate's own CFrame gives the rotation). Built models carry `PlotIndex` and `Preview` attributes. Run: passes.
- [ ] **Step 3: Every plot.** For each of `Plot1` to `Plot6` (and the two spares), one at a time: build everything, check footprint, ground, overlaps with city roads, buildings and other plates' boxes, the entrance facing a road; read the place's instance count and, in a Play from the city spawn, client descendants and memory near that plot; then clear it. Record in `plots.md`.
- [ ] **Step 4: Budget.** Compare one built base against the provisional targets in `CityCleanup/baseline-2026-11-14.md` (the developer has not agreed them; report against them). Report the cost of one base and of six, and which classes dominate.
- [ ] **Step 5: Leave one preview.** Build onto `Plot3` with `Preview = true` (replacing the old `TycoonPreview`, which goes to quarantine); all other plots empty.
- [ ] **Step 6: Commit.** `git commit -m "Batch: the HQ builds onto every plot"`.

---

### Task 6: Closing run and vault

- [ ] **Step 1: Five Plays** from the city spawn: 0 client and 0 server script errors other than asset lines and the `Workspace.HQ` lines; permission failures counted (0 for the 80 if the developer's mesh step is done, else the count, unchanged); both suites as before plus the new cases.
- [ ] **Step 2: Vault** per `Vault Conventions.md`: batch note, Batch Log, `City Map and Plots`, a new `20 Systems/Tycoon Template.md`, Open Items (the mesh step if still open, the heavy classes left for the developer, the copy list if unfinished), Decisions (the developer's two notes quoted, Claude's rulings), Engine Traps (assets private to another account load in one experience and not in another, with no copy error).
- [ ] **Step 3: Commit.** `git commit -m "Batch: plots and the HQ template"`.

---

## Not in this plan

- Buying, income, droppers running, the Build Menu, saves of purchases: phase 5 (OBT's tycoon core).
- Prices tuned to the blueprint's bands: phase 5's catalog; phase 4 records the kit's prices as found.
- Publishing the city or changing asset permissions: the developer's.
