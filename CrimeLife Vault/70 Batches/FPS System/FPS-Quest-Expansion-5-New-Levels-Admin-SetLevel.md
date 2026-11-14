# Change Log: Five More Quests, a Higher Level Cap, and an Admin Level Tool

**Date:** 2026-09-16
**Status:** Applied

## Summary
Five more quest givers join the first one, gated at levels 10, 20, 35, 50 and 70, each asking for a
different kind of enemy and paying more than the last. The level cap was raised to accommodate them.
An admin tool was added for testing: a chat command and a panel opened with F2, both of which set a
player's level directly rather than having to grind to it.

## Changes
- `ReplicatedStorage.Leveling.Constants` — level cap raised.
- `ReplicatedStorage.Quests.QuestConfig` — five new quests, and the name of the enemy a quest asks
  for is now part of the quest's own definition.
- `Workspace.Quests` — five new quest givers, each with the same floating name, speech bubble and
  interaction prompt as the first.
- `StarterPlayer.StarterPlayerScripts.QuestDialogueController` — what a quest giver says now names
  the enemy that quest actually asks for.
- `ReplicatedStorage.Leveling.Remotes` (new) and
  `ServerScriptService.Weapons.Scripts.LevelingService` — the server side of setting a level.
- `StarterPlayer.StarterPlayerScripts.AdminLevelController` (new) — the chat command and the F2 panel.

## Notes
- The quest giver's lines had the first quest's enemy written into them rather than reading it from
  the quest. With one quest that was invisible; with six it would have had every giver asking for
  thugs regardless of what their quest actually counted. The name is now part of each quest's own
  definition, so the line and the objective cannot disagree.
- The five new givers are placed in a straight line at temporary positions and still need moving to
  wherever they belong in the map.
- The panel was not in the original specification, which described only a chat command. Both exist
  and share the same underlying path, so they cannot behave differently from one another.
- Neither the command nor the panel has been driven in a running game yet — sending that kind of
  message is not something that can be triggered from outside a live session, so both still need
  confirming by hand.
