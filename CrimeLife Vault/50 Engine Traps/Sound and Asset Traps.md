---
type: trap
tags: [trap, sound, assets, animation, images]
updated: 2026-11-18
sources: ["CLAUDE.md (Known traps)", "70 Batches/FPS System/FPS-Fall-Animation-Dead-Asset.md", "70 Batches/FPS System/FPS-Figma-1to1-Image-Export-And-Font-Fix.md", "70 Batches/FPS System/FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold.md", "70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "70 Batches/Robbery System/Slice-Transparency-And-Anchor-Fixes.md", "70 Batches/FPS System/FPS-Weapon-Icon-Decals.md", "CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", "OBT Vault/50 Engine Traps/Sound and Asset Traps.md (generic traps)", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-3-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md"]
---

# Sound and Asset Traps

Audio, images, decals and animation assets. Pipelines: [[Icon Pipeline]], [[Figma and UI Art Pipeline]], [[Animation Pipeline]].

## Sound

### PlaybackLoudness ignores Volume (Known trap)
- **Symptom:** a quieter sound measures as loud as before.
- **Cause:** `Sound.PlaybackLoudness` reports the raw waveform and ignores `Volume`.
- **Fix:** use it to compare assets, never to measure applied gain.

### "User is not authorized to access Asset"
- **Symptom:** about 9 weapon sounds fail to load in Studio, every session.
- **Cause:** asset ownership and experience access, not wiring.
- **Fix:** re-upload under the place owner or swap the asset; until then, treat the warning as known noise and do not chase it as a code bug.
- **Bit us:** [[FPS-Figma-1to1-Image-Export-And-Font-Fix]], [[FPS-Figma-UI-Bugfix-Pass]], [[FPS-Quest-Overflow-And-Dead-Code-Removal]], [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]], the viewmodel motion README.

### A Sound parented to a non-part plays to everyone (OBT)
- A Sound under a Folder or Model plays 2D for every client. A sound for one player plays on their client; a world sound hangs on a part.

## Animation

### The Tools' hold clips fail to load in Studio, so a Studio hold pose is the default hold
- Measured 2026-11-18: the third-person hold clips 6170771161 (rifle idle) and 6170792878 (pistol idle) fail to load on the unpublished file ("Requester does not have permission", `serverplaceid=0`). Every hold pose or muzzle distance measured in Studio is therefore the default tool hold, which points guns down and to the right; a published place may hold them differently and was not measured. Same class as the weapon-sound warning above. [[2026-11-18 Open Items Pass]], [[Weapons and Blaster]].

### A dead animation asset plays as nothing
- **Symptom:** no fall animation, no climb animation.
- **Cause:** after an explicit `ContentProvider:PreloadAsync`, `FallAnim` (79120124804027) and `ClimbAnim` (132969691712833) report a track length of 0.000 s: they never resolve, and a zero-length track plays and ends in the same frame.
- **Fix:** preload, then poll `Length` until non-zero or a deadline. The dead ids were replaced with the Roblox default R15 fall (507767968, 0.792 s) and climb (507765644, 1.042 s).
- **Bit us:** [[FPS-Fall-Animation-Dead-Asset]].

### The Animation Editor only loads from the rig's AnimSaves
- **Symptom:** exported KeyframeSequences are invisible in the Animation Editor's Load list.
- **Cause:** the list is populated solely from an `AnimSaves` **ObjectValue** (not a Folder) under the selected rig; it never looks in `ServerStorage`. The viewmodel templates ship an empty one.
- **Fix:** copy each rig's clip set into its `AnimSaves` (49 sequences); keep `ServerStorage.ViewmodelKeyframeSequences` as the master. [[FPS-Viewmodel-KeyframeSequence-Export]].

### A just-uploaded animation plays its old version (OBT)
- Wait a minute before the Play that tests it.

### Registered keyframe sequences die when collected (OBT)
- `KeyframeSequenceProvider:RegisterKeyframeSequence` ids die when the sequence is garbage-collected, and a fresh track reports `Length` 0 for a moment. Keep a reference; wait for `Length > 0`.

## Images

### A slice can have an alpha channel that is 255 everywhere
- **Symptom:** white boxes behind every badge and ribbon panel; a lockpick success arc rendered as a solid green rectangle.
- **Cause:** Figma's export baked the export page's background into each image as opaque. The PNGs had an alpha channel, but it was 255 everywhere, so a tint filled the whole rectangle. A `hasAlpha` check does not catch it.
- **Fix:** clear the export page's background, re-export (all 23 slices), and decode real pixel alpha before upload. [[Slice-Transparency-And-Anchor-Fixes]] (Robbery System, 2026-09-18).

### Source file names do not match Tool names
- `FN-P90` vs `FN P-90`, `Scar-L` vs `Scar L`: check each icon lands on the right weapon after upload. [[FPS-Weapon-Icon-Decals]].

### A decal id is not an image id (OBT)
- Resolve a Decal asset with `InsertService:LoadAsset(id)` and read its `Decal.Texture`.

### The CDN can be flaky (OBT)
- PreloadAsync can say Failure and then Success a minute later. Retry before calling an asset broken; confirm loads in Play, since an Edit preload of web images can fail even for good ones.

### Free-model packs can carry malware (OBT)
- Several Creator Store packs carried hidden malicious scripts. Review rules: [[Safety and Security Rules]].

Related: [[Engine Traps MOC]] · [[Studio MCP Gotchas]] (`upload_image` takes URLs only)
