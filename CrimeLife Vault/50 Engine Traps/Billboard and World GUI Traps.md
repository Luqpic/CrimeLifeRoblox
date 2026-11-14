---
type: trap
tags: [trap, ui, billboard, surfacegui, prompts]
updated: 2026-11-14
sources: ["CLAUDE.md (Known traps)", "70 Batches/FPS System/FPS-Dialogue-Responses-Clickable-Fix.md", "70 Batches/FPS System/FPS-Billboard-Scale-And-Cash-Drop-System.md", "70 Batches/Robbery System/Prompt-Closes-When-Disabled.md", "OBT Vault/50 Engine Traps/Billboard and World GUI Traps.md (generic traps)"]
---

# Billboard and World GUI Traps

BillboardGuis, SurfaceGuis, custom ProximityPrompt UI and GUIs placed in the 3D world. Systems: [[Nameplates and Billboards]], [[Quests and Dialogue]], [[Robbery Prompts]].

### A GUI parented into the world is never clicked (Known trap)
- **Symptom:** dialogue replies were visible but ignored hovering and clicking, with or without a weapon in hand.
- **Cause:** only GUIs under the player's own PlayerGui are hit-tested for the mouse. A BillboardGui or SurfaceGui parented on a world object is drawn but never put in front of the mouse.
- **Fix:** host the GUI in `StarterGui.QuestResponsesGui` (PlayerGui) and point its `Adornee` at the current quest giver.
- **Disproved first:** the weapon's mouse lock swallowing the click (the replies were just as dead with nothing equipped; that change was reverted), and drawing through walls bypassing the click test (turned back on).
- **Bit us:** [[FPS-Dialogue-Responses-Clickable-Fix]].

### BillboardGui size: Scale is studs, Offset is pixels (Known trap)
- A Scale size grows and shrinks with distance like a world object; an Offset size stays the same on screen. Pick deliberately for nameplates and stat billboards (the stat billboard was scaled up 25% for legibility in [[FPS-Billboard-Scale-And-Cash-Drop-System]]).

### A BillboardGui in PlayerGui resets on spawn
- `ResetOnSpawn` defaults to true, so a billboard parented into PlayerGui is replaced on death and code holding the old reference fails. Set `ResetOnSpawn = false` ([[UI Layout Traps]]).

### A custom prompt UI must react to Enabled itself
- **Symptom:** a prompt's face stayed on screen indefinitely after the prompt was switched off.
- **Fix:** the custom `PromptUI` now fades out and destroys its billboard when `Enabled` goes false (measured: 1 billboard mid-fade, 0 after). General to every prompt the game gates by `Enabled`. [[Prompt-Closes-When-Disabled]] (Robbery System).

### StudsOffsetWorldSpace follows the Adornee's axes (OBT)
- On a rotated part the board sits off to the side. Convert first: `part.CFrame:VectorToObjectSpace(worldOffset)`.

### SurfaceGui on a Top face runs along Z (OBT)
- Turn the part 90 degrees for text along X.

### SurfaceGui.MaxDistance uses the editor camera (OBT)
- A capture from a far camera shows no text. See [[Screen Captures]].

### Glass hides transparent things behind it (OBT)
- A BillboardGui or transparent part behind Glass is not drawn: put signs in front of the glass.

### A cloned billboard brings its old scripts (OBT)
- A template with Scripts inside runs them once the clone is in Workspace and overwrites your labels. Destroy every `LuaSourceContainer` in the clone, or keep templates script-free.

### ApplyDescription replaces a dynamic head (OBT)
- `Humanoid:ApplyDescriptionAsync` swaps a MeshPart head for a new instance; tags adorned to the old head point at nothing. Re-point after applying (relevant to [[FPS-Enemy-Marketplace-Outfits]]-style outfit changes).

### Captures skip some billboards (OBT)
- Client captures skip AlwaysOnTop BillboardGuis and BillboardGuis held in PlayerGui. Judge by properties ([[Screen Captures]]).

Related: [[Engine Traps MOC]] · [[UI Layout Traps]] · [[Camera and Input Traps]]
