# Change Log: Quest System — a Quest Giver, a Quest Log, and the First Quest

**Date:** 2026-09-16
**Status:** Applied

## Summary
The game has quests. A quest giver stands in the world with a name and a floating speech bubble over
his head; walking up and pressing the prompt starts a conversation with him, and the player answers
by picking one of the numbered replies. The first quest asks for ten thugs to be defeated and pays
cash and experience on hand-in. Progress is tracked as the player fights, and a new Quests button
opens a log listing what is taken, how far along it is, and what it pays.

## Changes
- `ReplicatedStorage.Quests.QuestConfig` (new) — the quest definitions themselves: who gives them,
  what they ask for, what they pay, and what the giver says at each stage. Everything else reads this
  rather than carrying its own copy, so adding a quest later is an edit in one place.
- `ReplicatedStorage.Quests.Remotes` (new) — the two messages passed between player and server for
  starting a quest and handing one in.
- `ServerScriptService.Quests.Scripts.QuestService` (new) — the authority on quest state. It records
  what each player has taken and how far along they are, counts kills as they happen, and pays out on
  hand-in. Nothing about progress is decided on the player's own machine.
- `ServerScriptService.Weapons.Scripts.LevelingService` — now also grants experience when a quest
  pays out, rather than only from kills.
- `ReplicatedStorage.Blaster.Utility.canDamageHumanoid` — quest givers can no longer be shot. Anyone
  marked invulnerable is skipped, which the quest giver is.
- `ServerScriptService.Enemy.Scripts.EnemySpawner` — each spawned enemy now carries the name of the
  kind it was spawned from, so a quest can ask for a specific kind rather than for kills in general.
- `ReplicatedStorage.DialogModule` — the conversation engine that came with the dialogue template,
  with two faults corrected. Its walk-away check read a body part that only exists on the older
  character rig, so it failed every frame against this game's characters. And it wrote the camera's
  field of view directly, which would have fought with aiming, sprinting and open menus; it now goes
  through the same arbitration everything else does.
- `Workspace.Quests."Level 1 Quest"` — the quest giver himself: the floating name and speech bubble
  over his head, the interaction prompt, and his quest settings.
- `StarterPlayer.StarterPlayerScripts.QuestDialogueController` (new) — drives the conversation: what
  he says depends on whether the quest is untaken, in progress or ready to hand in, and the player's
  reply is what starts or completes it.
- `ReplicatedStorage.GuiTemplates.QuestLog` (new), `StarterGui."Custom Inventory".questsButton` (new)
  and `StarterPlayer.StarterPlayerScripts.QuestLogController` (new) — the Quests button and the panel
  it opens.

## Notes
- The dialogue script was specified to live on the quest giver himself, in the world. Scripts placed
  there never run — the game only runs the player's scripts from a handful of specific places, and
  the world is not one of them. It was moved to where the player's own scripts live and given the
  quest giver by name instead. Left as specified, nothing would have happened on walking up to him.
- The first attempt at the conversation showed replies that were invisible: the buttons were being
  sized from their text, but the setting that makes a button take its size from its text had not been
  carried over when the panel was rebuilt, so every reply came out zero pixels wide.
- A worse fault was found by playing rather than by reading. Accepting the quest and then dying left
  the player permanently zoomed in with no way out: the reply panel is rebuilt from scratch on
  respawn, so the buttons the conversation was waiting on no longer existed, and the conversation
  could never be ended. The panel is now kept across respawns, and the conversation clears its claim
  on the camera when the player dies regardless.
- Kill counting reuses the signal the levelling system already fires when something dies, rather than
  adding a second way of noticing a kill. Two independent counters would eventually disagree.
