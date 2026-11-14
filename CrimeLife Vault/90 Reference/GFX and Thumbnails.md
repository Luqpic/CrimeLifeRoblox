---
type: reference
tags: [reference, pipeline, gfx, thumbnails, marketing]
updated: 2026-11-14
sources: ["GFX/ (listing 2026-11-14)", "BadgeGFX/ (listing 2026-11-14)", "Roblox-Claude-Workflow.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Batch Log.md"]
---

# GFX and Thumbnails

**Not yet used in CrimeLife.** No thumbnail, game icon, badge art or key art has been made for CrimeLife: `Documents/Roblox/GFX/` and `BadgeGFX/` hold only another project's art and a group-logo folder (listing 2026-11-14), and no CrimeLife change log records GFX work. This is the generic method, kept ready.

## Purpose
Marketing art (game thumbnails, game icon, badge art, logo, key art) made from the game's real characters, weapons and places. Serves [[Gamepasses]] (pass icons) and any future badges.

## Steps (generic)
1. **Reference shots** in Studio of each subject: a main shot and a close-up, neutral light, flat backdrop. For CrimeLife the natural subjects are the enemy templates (`ServerStorage.EnemyTemplates`), the quest givers in their law-enforcement outfits, and the weapons.
2. **Prompts**, one self-contained block per image, kept in a markdown file next to the references:
   - thumbnails 16:9 at 1920 x 1080;
   - badges and icons 1:1, 512 x 512 minimum;
   - a flat magenta `#FF00FF` background when the subject must be cut out later.
   Carry the fixes inside each prompt ("keep the blocky Roblox proportions", "flat solid background, zero gradient").
3. **The developer generates** in their image tool with the main shot attached as the reference.
4. **Background removal** for cut-outs (Color Range in an editor, or a remover); defringe parts that share the key colour.
5. **Upload and wire:** pass icons go through [[Add a Gamepass]]; in-game pictures through [[Icon Pipeline]].

## Suggested home
`Documents/Roblox/GFX/CrimeLife/` with sub-folders by subject, and the prompt files beside the references. Not created yet.

Related: [[Trailer and Cinematic Pipeline]].
