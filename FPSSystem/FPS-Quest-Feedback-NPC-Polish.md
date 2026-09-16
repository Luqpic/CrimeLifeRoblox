# Change Log: Quest Completion Feedback, Repeatable Quests, and NPC Polish

**Date:** 2026-09-16
**Status:** Applied

## Summary
Handing in a quest now tells the player it happened: a notification slides in at the bottom left,
holds, and slides back out. The quest giver stands still on his mark with a proper idle stance,
points once when a quest is accepted and once again when a reward is claimed. Quests can be taken
again after being completed, and the Quests button carries a badge showing how many finished quests
are waiting to be handed in.

## Changes
- `Workspace.Quests."Level 1 Quest"` — anchored in place, and given a real idle stance instead of the
  default one.
- `StarterPlayer.StarterPlayerScripts.QuestDialogueController` — plays the point gesture on accepting
  a quest and on claiming a reward.
- `ReplicatedStorage.GuiTemplates.Notification` (new) and
  `ReplicatedStorage.Modules.NotificationController` (new) — the bottom-left notification, built as a
  reusable piece rather than as part of the quest system, so anything else can raise one later.
- `StarterPlayer.StarterPlayerScripts.QuestFeedbackController` (new) — raises the notification when a
  quest is handed in, with sound.
- `ReplicatedStorage.Quests.QuestConfig` and `ServerScriptService.Quests.Scripts.QuestService` —
  quests can now be repeated. Each completion is counted, and a repeatable quest returns to being
  available rather than being marked finished for good.
- `StarterPlayer.StarterPlayerScripts.QuestLogController` — the Quests button gained a badge counting
  the quests that are finished but not yet handed in.

## Notes
- The quest giver's animation script is the stock one and does nothing here — it only runs for actual
  players. His gestures are therefore played directly rather than by asking that script to play them.
- A second, larger banner across the middle of the screen was built alongside the notification and
  then removed: two separate things announcing the same event at once was one too many. Only the
  bottom-left notification remains.
- The point gesture looped endlessly at first. The initial explanation — that the gesture itself was
  authored to loop — was wrong; the gesture is authored to play once. The real cause was that it was
  being started twice, stacking two copies on top of each other so that one was always playing. It is
  now a single reusable gesture with a guard against restarting it while it is still running.
- The badge count is worked out from the number of completions rather than from whether the quest is
  marked finished. With repeatable quests the finished mark is cleared as soon as the reward is
  claimed, so counting it would have shown the wrong number the moment repeats were allowed.
- The notification slides in and out rather than appearing and vanishing. This needed a wrapper
  around it: the notifications are stacked by a layout, and a layout owns the position of anything it
  stacks, so animating the position of a stacked item does nothing at all.
