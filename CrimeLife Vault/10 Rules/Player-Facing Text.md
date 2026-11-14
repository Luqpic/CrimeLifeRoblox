---
type: rule
tags: [rule, writing, text]
updated: 2026-11-14
sources: ["OBT Vault/10 Rules/Player-Facing Text.md (adapted)", "70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass.md", "70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md"]
---

# Player-Facing Text

## Rule

- **No dash as punctuation.** Anything a player reads (dialogue, quest text, GUI labels, toasts, prompts, billboards) never uses a spaced dash (" - ", en dash, em dash) as punctuation. Write "." (a new sentence) or "," instead. Hyphenated words, ranges and minus signs stay. Code comments are not player text.
- **No text may overlap or clip anywhere.** Size boxes to the longest label; check with `TextBounds` or `TextService:GetTextBoundsAsync` at the label's real size ([[UI Layout Traps]]).
- **Markup needs `RichText`.** A label that receives `<font>` tags must have `RichText` on, or players read the tags ([[FPS-Figma-UI-Bugfix-Pass]]).
- **Text baked into art is changed in the art.** Banner titles and the death screen's words are Figma slices ([[GUI Rules]]).
- **Touch wording on touch screens:** a prompt names the touch button, not a keyboard key, where the HUD has a touch path.

## Why

- The dash rule was set by the developer on OBT on 2026-10-25 ("Ensure to make this a rule for future writing"). Carried to CrimeLife on 2026-11-14 as a writing rule of the same developer; earlier CrimeLife text has not been swept for it (not recorded).
- [[FPS-Figma-UI-Bugfix-Pass]]: `QuestFeedbackController` pushed a whole sentence with `<font>` markup into a single-line label without `RichText`, with `TextScaled` at `TextSize` 8.

## How to apply

- Check every new player-readable line for " - " before finishing a batch.
- Content limits: [[Content Maturity Rules]].
