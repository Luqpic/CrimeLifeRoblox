# Change Log: Illegal Supplier Moved Onto The Shared Dialogue Engine

**Date:** 2026-09-19
**Status:** Applied (verified, with one gap noted)

## Summary
The Illegal Supplier is mechanically a mini-quest -- walk up, get asked whether you are carrying, hand over, get paid. It was presented as a bespoke ScreenGui with Yes/No buttons while the FPS place's quest givers used a billboard dialogue engine. The supplier now runs on that same engine, so the two places have one dialogue system instead of two.

## Changes
- `ReplicatedStorage.DialogModule` -- ported in from the FPS place, byte-identical (16219 bytes, 424 lines, matching checksums), with its `sounds` folder (`tick`, `tick2`).
- `StarterGui.QuestResponsesGui` -- the shared billboard that holds the numbered response rows, rebuilt to match.
- The supplier rig's `Head` gained a `gui` BillboardGui with the `name` / `arrow` / `dialog` labels the engine drives. Header reads **ILLEGAL SUPPLIER** rather than a quest level.
- The supplier's ProximityPrompt tagged `NPCprompt` (so a conversation disables it) with ActionText "Talk".
- New `StarterPlayerScripts.SupplierDialogueController`, the direct counterpart of the FPS place's `QuestDialogueController`.
- Supplier wiring removed from `HeistClient` and from `UiButtonEffects`; `SuppliesServer` no longer answers the prompt.

## Dialogue flow
The offer asks whether the player is holding, with three replies: sell, ask where supplies come from, or decline. The explainer is a second node that leads back into the same sale, so a player who asks can still hand over without re-opening the conversation. Selling with nothing carried is refused by the server and answered in dialogue.

The explainer names the real sources -- the diner and the gas station, and the news station camera that pays double -- because a hint that sends the player somewhere with no supplies is worse than no hint.

## Notes
- The conversation opens CLIENT-side off the prompt now, as the quest NPCs do. The outcome is still fully server-authoritative: `SubmitSupplierChoice`/`SupplierResult` are untouched and `CarryState:Consume` is still re-checked at the moment "yes" is clicked, never upfront.
- `OpenSupplierDialog` is left defined but unfired; removing it would touch the remote list every robbery-site script shares.
- `StarterGui.SupplierDialogGui` is now orphaned. It was left in place rather than deleted, and disabled so it cannot render.
- The FPS place hides no other GUI during a conversation and applies FOV without blur. That behaviour was matched rather than keeping this place's old focus-mode blur, since the point was to replicate the engine.
- **Verified:** conversation opens and types out, exactly the three intended replies appear, and all four branches were exercised -- explainer, decline, "got it", and a sale with nothing carried (full server round trip returning `no_supplies` in 0.1s).
- **Not verified live:** clicking a response row with a real mouse. The Studio viewport was collapsed to 1x1 with the render loop stopped, so no input reached the game. The branches were driven through the same signal a click fires.
