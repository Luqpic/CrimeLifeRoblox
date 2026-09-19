# Change Log: Dialogue Replies Made Clickable

**Date:** 2026-09-16
**Status:** Applied, awaiting confirmation in a running game

## Summary
The replies beside a quest giver could be read but not clicked, and did not react to the cursor at
all. They are still shown in the same place beside him, but are now hosted with the player's own
interface and pointed at him, rather than being attached to him directly — which is what puts them
in front of the mouse.

## Changes
- `StarterGui.QuestResponsesGui` (new) — one reply panel belonging to the player, kept across
  respawns, pointed at whichever quest giver is currently being spoken to.
- `ReplicatedStorage.DialogModule` — goes back to one shared reply panel, and points it at the right
  quest giver when a conversation opens and clears it when the conversation genuinely ends, including
  when the player walks away or dies mid-conversation.
- `Workspace.Quests` — the six reply panels attached to the quest givers themselves are removed.
  Nothing referred to them any longer.

## Notes
- The cause was not any property on the panel or its buttons, and not the mouse being locked by the
  weapon system. The game only considers a button for a click if it belongs to the player's own
  interface. Anything attached directly to an object in the world is still drawn, but is never put in
  front of the mouse at all — which is exactly what was seen: visible replies that ignored both
  hovering and clicking, with or without a weapon in hand.
- Two earlier explanations for this were wrong and are worth recording so they are not tried again.
  The first was that the weapon system's mouse lock was swallowing the click; that was disproved by
  the replies being just as dead with nothing equipped, and the change made on that theory was
  reverted in full. The second was that drawing the panel through walls was bypassing the click test;
  that was also wrong, and drawing through walls has been turned back on.
- Returning to one shared panel is safe here for the same reason it was safe originally — only one
  conversation can be open at a time — but it now needs the panel pointed at the right person and
  cleared afterwards, which is tied to the same moment the conversation releases the camera so the
  two cannot fall out of step.
- The specification for this change asserted the panel would keep its setting for surviving respawns
  but never actually set it. Left as written, the reply panel would have been thrown away and rebuilt
  on the player's first death while the conversation engine went on referring to the discarded copy —
  reintroducing, exactly, the trap that left the player stuck zoomed in after dying. It is now set
  explicitly.
- One thing is outstanding: the click itself has not been confirmed in a running game — that needs a
  person.
