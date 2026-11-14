---
type: reference
tags: [reference, pipeline, ui, figma, art]
updated: 2026-11-14
sources: ["CLAUDE.md (Systems: UI)", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Figma-Image-Export-Pipeline.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Figma-Frame-Layer-Archive.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-1to1-Image-Export-And-Font-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/GUI-Audit-And-Figma-Redesign.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Figma-Slices-Imported-To-Studio.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Slice-Transparency-And-Anchor-Fixes.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md"]
---

# Figma and UI Art Pipeline

**Used by both CrimeLife places.** The UI is designed in one Figma file (key `iRetcvpbMMD190DJA9Mwrm`; the Robbery change logs call the file `Roblox`), and panel chrome ships as exported image slices. Systems: [[HUD and UI Shell]], [[Robbery Prompts]]. Recipe: [[Add a Menu Panel]].

## Sources of truth
| What | Where |
|---|---|
| Design file | Figma `iRetcvpbMMD190DJA9Mwrm`. FPS redesign on page `9:2` "02 · Redesign"; Robbery as-built on page `01 · Roblox As-Built` and redesign on `02 · Redesign` |
| FPS asset registry | `ReplicatedStorage.UI.Theme` (fonts, `FontIntent`, icon and banner ids, `applyBakedBanner()`, `applyBanner()`) |
| Robbery asset registry | `ReplicatedStorage.SharedSystems.UITheme` (every slice id, its 1x display size, ribbon overhang offsets) |
| Frame-to-instance map | The Figma pipeline prompt (`90 Reference/Original Prompts/FPSSystem/FPS-Figma-Image-Export-Pipeline.md`), see [[Original Prompts]] |
| Old layer names | `FPS-Figma-Frame-Layer-Archive.md` (archive of the deleted `MultiExport` scaffold) |

## The slice doctrine
- **Image:** anything Roblox cannot draw natively: panel chrome, banner plates with baked titles, angled cuts, bevels, shadows, button skins, icons, complex gradients.
- **Native:** anything that changes at runtime: all text that varies, all bars, all lists and grids, anything a controller sets.
- **Titles are baked into banner art**, so re-centring a title is a re-export, not a layout property.
- Export elements, never whole screens.

## Steps
1. **Inventory the Figma page** first: every frame, its size, which layers are chrome and which are live. Get the export list approved.
2. **Export** through the Figma REST `/v1/images` endpoint at **4x** (the FPS banners and icons), or through the Figma MCP's asset URLs. The REST call needs a Figma token; never write it into the vault. Clear the export page's background first: a plugin-made page defaults to light grey and every slice comes back fully opaque (an alpha channel that is 255 everywhere passes a `hasAlpha` check).
3. **Prepare:** icons in **pure white** (`ImageColor3` multiplies, so a coloured source can only be darkened); keep every texture at or under 1024 px (Roblox downscales larger silently); a stretched image is 9-sliced with a `SliceCenter` measured off the exported pixels.
4. **Upload** in one batch. `upload_image` (Studio MCP) takes http/https URLs only, never local paths; local PNGs have been served from a temporary localhost server, stopped straight after. Uploads are moderated and irreversible: upload once from a reviewed list and record every id (`CrimeLifeRoblox/.superpowers/sdd/uploaded-asset-ids.md` holds one such record).
5. **Register** every id in `Theme` / `UITheme`; no `rbxassetid://` literals in controllers.
6. **Re-skin one template at a time**, keeping every instance name and path (controllers index by name). Reset `AnchorPoint` on anything repositioned with top-left coordinates.
7. **Verify:** screenshots against the frame, `AbsolutePosition` / `AbsoluteSize` read back, every sound re-checked (replacing a `TextButton` with an `ImageButton` drops its connections; re-bind through `UI.Sounds.bind`).

## Fonts
Roblox does not have the design's faces (Archivo Black, Barlow Semi Condensed); `Font.fromName` fails silently and falls back to the default (59 of 95 FPS labels were broken on 2026-09-18). Static headers are baked into art in the real face; dynamic text uses Montserrat Heavy (display) and RobotoCondensed SemiBold / Medium (body). `Theme.FontIntent` records the intended faces. Custom font upload is not reachable from this setup.

## Anti-patterns (each already happened)
- Rebuilding a Figma frame from `Frame` + `UICorner` + `UIStroke` and calling it 1:1. (Exception, recorded: the Skins card was built natively to its Figma node because image upload was blocked that day.)
- An ImageLabel tree mirroring Figma layer names with `rbxassetid://0` (the 1,155-descendant `MultiExport`, deleted).
- Substituting a font by feel.
- A Figma read that returns an empty file can be an authentication problem (a View seat returns a hollow document), not an empty file.

## Shared between the places
`UI.Effects` (close button slice, `bindClose`), `UI.Transitions`, the cash widget and the notification card were made identical in both places so a merge has nothing to reconcile. See [[Places and Studio Windows]].

Related: [[Icon Pipeline]], [[GUI Rules]].
