---
type: reference
tags: [reference, pipeline, cinematic, trailer]
updated: 2026-11-14
sources: ["Roblox-Claude-Workflow.md §10.4, §11", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Batch Log.md"]
---

# Trailer and Cinematic Pipeline

**Not yet used in CrimeLife.** Neither place has cutscenes or a trailer, and no change log records one. This is the generic method from another project, kept ready.

## The one rule
**Blender animates; the game renders.** A fully Blender-rendered trailer with stand-in sets was rejected in the other project: trailers and cutscenes use the real game models, the real map and the game's own effects. Blender authors motion and the camera only.

## In-game cinematic route
1. **Author the scene in Blender** with a scene script that appends the real rigs, lays clips on the timeline and keys the camera from a shot list ([[Animation Pipeline]] for any new clips).
2. **Write a track:** the script writes `track.json` (camera samples, cues, marks); a converter turns it into a Luau `Track` module.
3. **Play in game:** a cinematic player module plays the Track on the real world with local copies of real actors and the game's own effects. In CrimeLife the camera claim must go through `CameraAuthority` ([[Camera Authority]]) and the HUD hide through `UI.Panels` ([[HUD and UI Shell]]).
4. **Review live:** build an admin cutscene player (PREV / NEXT / PLAY) and let the developer watch it. Do not record long MP4 reviews (they ran for hours and paged the Mac).

Axes: Roblox `(x, y, z)` = Blender `(-x, z, y)`, 1 Blender unit = 1 stud; both use a vertical FOV. Blender 5 layered actions have no `action.fcurves` (walk `layers -> strips -> channelbags -> fcurves`). A camera riding a moving actor needs linear keys, or it stops at every key. Before changing a scene script, regenerate it unchanged and diff against the game's `Track` module.

## Gameplay trailer route
The developer screen-records real play; Claude cuts it with the `video-use` skill, on the music's beat grid, with a crop that hides Roblox's buttons; the developer finishes it in their editor.
- **Lag check before picking a shot:** macOS records only when the screen changes, so frame timestamps (`ffprobe -show_entries packet=pts_time`) show the game's own stutter; count gaps over 60 ms per 5 s window.
- Fast scan of a long recording: decode keyframes only (`-skip_frame nokey`).
- A macOS `.mov` name has a narrow no-break space before AM / PM; match it with a glob.

## For CrimeLife specifically (open questions, nothing decided)
- An FPS trailer would mostly be the gameplay route; the in-game route needs a cinematic player module that does not exist yet.

Related: [[Blender Pipeline]], [[GFX and Thumbnails]].
