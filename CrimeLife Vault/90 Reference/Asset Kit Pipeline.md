---
type: reference
tags: [reference, pipeline, assets, world]
updated: 2026-11-14
sources: ["Roblox-Claude-Workflow.md §10.3", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Eight-New-Pistols-And-Shotguns.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md"]
---

# Asset Kit Pipeline

**Not yet used in CrimeLife.** No prop kit or world dressing has been built for either CrimeLife place. This is the generic method carried over from another project, kept ready for map work. Skill: `roblox-world-building`, and `roblox-blender-modelling` only when a mesh is really needed.

## Purpose
Build props and dress areas of the map in the game's own Roblox-parts style without hurting performance.

## Steps (the parts route)
1. **Author** each prop set as a Blender Python script with a small helper library that records every primitive (block, wedge, corner wedge, cylinder). A build script renders a labelled **contact sheet** to preview. See [[Blender Pipeline]].
2. **Export to part data:** the primitives become JSON of Part / WedgePart / CornerWedgePart / Cylinder with size, CFrame, material and colour.
3. **Build in Studio:** a script builds the JSON into real Parts, one Model per asset with a set pivot. A check script verifies it.
4. **Back up** the kit as an `.rbxm` (export through `SerializationService`, confirm the checksum).
5. **Dress the map** with a re-runnable build script and a placement plan that checks keep-clear areas, ground, slope and footprints.
6. **The developer saves.**

## Rules
- **Style:** plain Parts, Wedges and Cylinders; built-in Material and Color; no `TextureID` (a texture hides the material texture); chunky (at least 0.2 studs). Neon only for glow.
- **Budget:** props at most 15 parts, large pieces at most 80; anchored; decoration has CanCollide, CanTouch, CanQuery and CastShadow off; repeated props built once and cloned.
- **No gaps, no grooves:** never boolean-union touching parts; round only exposed edges.
- **Light dressing:** about 10 to 15 placements per area; reuse objects already in the game.
- **Keep clear** (CrimeLife's equivalents): `Workspace.EnemySpawns` and the 22-stud scatter radius around each, the player spawn, `Workspace.Quests` givers and their prompts, weapon displays, and the Robbery place's robbery locations and getaway routes.
- **Never re-run a dressing script on an area hand-edited since.** It clears the folder; make targeted edits.
- **Reshape the developer's existing meshes** rather than designing from scratch.

## What CrimeLife does today instead
- Weapons: imported meshes turned into Tools by the weapon build script ([[Add a Gun]]); source models are deleted once their weapons ship.
- Enemy and quest-giver looks: marketplace accessories and outfits cloned between templates ([[Add an Enemy Type]], [[Add a Quest]]).

Related: [[Places and Studio Windows]], [[GFX and Thumbnails]].
