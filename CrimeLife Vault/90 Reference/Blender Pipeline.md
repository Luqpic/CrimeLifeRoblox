---
type: reference
tags: [reference, pipeline, blender]
updated: 2026-11-14
sources: ["Roblox-Claude-Workflow.md §10, §10.1, §10.3", "Blender/ (listing 2026-11-14)", "CrimeLifeRoblox/FPSSystem/Blaster/BuildNewPistolsShotguns.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Eight-New-Pistols-And-Shotguns.md"]
---

# Blender Pipeline

**Not yet used in CrimeLife.** `Documents/Roblox/Blender/` holds another project's rigs, previews and kits; nothing in it is CrimeLife's (listing 2026-11-14). CrimeLife builds its weapons in Studio from raw imported meshes staged in Workspace with a Luau build script ([[Add a Gun]]) and animates viewmodels in code ([[Animation Pipeline]]). This note keeps the generic method for when a Blender job comes up. Skill: `roblox-blender-modelling` (meshes), `roblox-characters-animation` (clips).

## Purpose

Blender animates, builds skinned rigs and authors camera tracks. It does not make the game's look. Two lessons from the other project set that boundary:
- **Blender animates; the game renders.** Trailers and cutscenes use the real game models and world ([[Trailer and Cinematic Pipeline]]).
- **The look comes from Roblox.** A prop kit modelled as Blender meshes was rejected as not Roblox style; it was rebuilt as plain Parts ([[Asset Kit Pipeline]]).

## How it runs

- Headless: `B=/Applications/Blender.app/Contents/MacOS/Blender`, then `$B -b <file>.blend --python <script>.py -- <args>`. A symlink to the binary loses Blender's bundled Python; use a wrapper script if you want `blender` on PATH.
- `ffmpeg` installed (Blender 5 has no FFMPEG image format).
- Uploads go through an Open Cloud key with Assets read and write, made under the group that owns the game so group-owned assets play. For CrimeLife the owning group and key location are **not recorded**; ask before the first upload. Never print a key.
- Drive Studio's UI only when the developer is not using the machine (the other project gates on a `ready.sh` READY check).
- Every result gets a preview (an `index.html` or a contact sheet) and the developer's OK before upload.

## Suggested layout (if CrimeLife starts using it)
| Folder | Holds |
|---|---|
| `_pipeline/` | The shared engine: build rig, animate, export, package, upload, render, preview |
| `_tools/` | Studio-side helpers (rig dump), measured checks |
| `_ids/` | `ids.json`: every uploaded id |
| `<RigName>/` | One folder per rig: `rig.json`, `.rest.blend`, `.blend`, logs |
| `Previews_*/` | Preview pages per batch |

Keep CrimeLife jobs out of the existing project folders (a separate prefix or sub-folder), so neither project's upload globs pick up the other's files.

## Rules

- Never File > Export as .obj in Studio on a big place (it hangs Studio); use Export Selection.
- Prefer reshaping the developer's existing meshes over modelling from scratch.
- When a mesh really is needed: measure texel density, export by motion group, one MeshPart per independently moving part (the skill covers this).
- Check the Mac is not paging before trusting any timing; two large Studio windows have paged it before.

## CrimeLife's in-Studio equivalent

The weapon build script does in Luau what a Blender build would do: it measures source extents from `Part.Size` (sources are `Part` + `SpecialMesh`), scales `Size` with `SpecialMesh.Scale` / `Offset`, aligns the mesh to the donor's rear-top edge, and welds it to the donor skeleton. See [[FPS-Eight-New-Pistols-And-Shotguns]].

Related: [[Animation Pipeline]], [[Places and Studio Windows]].
