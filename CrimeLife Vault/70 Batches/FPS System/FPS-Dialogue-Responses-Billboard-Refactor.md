# Change Log: Dialogue Replies Moved Off the Screen and Beside the Quest Giver

**Date:** 2026-09-16
**Status:** Applied

## Summary
The numbered replies in a conversation used to sit at a fixed spot on the screen, disconnected from
whoever was being spoken to. They now float in the world beside the quest giver himself, to the
viewer's left of him and clear of the name and speech bubble already over his head.

## Changes
- `ReplicatedStorage.GuiTemplates.QuestResponsesBillboard` (new) — the reply panel as a world-facing
  billboard. It reuses the existing reply panel wholesale rather than rebuilding its look, so the
  dark background, rounded corners and typeface carry over unchanged.
- `Workspace.Quests` — a copy attached to each of the six quest givers.
- `ReplicatedStorage.DialogModule` — the conversation engine points at each quest giver's own panel
  instead of the single shared one on the screen.
- `StarterGui.dialog` — removed. Nothing referred to it any longer.

## Notes
- The panel is attached to the quest giver's upper torso rather than his head. Both were tried; on
  the head it sat on top of the name and speech bubble already there and hid them.
- Making the panel belong to each quest giver, rather than keeping one shared panel, was not optional
  once it moved into the world. One set of buttons cannot float beside six people standing in six
  different places. The previous design got away with a shared panel only because exactly one
  conversation can be open at a time.
- Everything about how the conversation itself works is untouched: the letter-by-letter reveal, the
  hover growth, the number-key shortcuts and the reply formatting all measure their positions the
  same way whether the panel is on the screen or in the world.
- The replies were left visible but unclickable by this change. That is corrected separately; the
  cause is not in anything listed above.
