# Prompt: Refactor Dialogue Responses from Screen GUI to a Per-NPC BillboardGui

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**Brainstormed and approved before writing this.** The core finding, confirmed by reading
`DialogModule.lua`'s complete current source: the response panel
(`StarterGui.dialog.dialogResponses`) is resolved **once**, as a module-level local, shared by every
`DialogModule.new(...)` call:

```lua
local DIALOG_RESPONSES_UI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("dialog"):WaitForChild("dialogResponses")
```

The constructor clones 9 numbered response buttons from a `template` child and **destroys the
template** — so only the first NPC a player ever talks to actually builds those buttons; the other 5
silently reuse that same shared set. This works today only because exactly one conversation can ever
be open at a time (globally enforced via the `NPCprompt` tag). That assumption cannot survive turning
responses into a BillboardGui anchored at each NPC's own head — 6 NPCs cannot share one physical set
of buttons floating at 6 different world positions. So this refactor necessarily makes the response
container **per-NPC-instance** instead of a shared singleton. That's not scope creep on top of "change
the GUI type" — it's what correctly doing that change requires once more than one NPC exists.

Everything else about the mechanism is unchanged and stays unchanged: typewriter reveal, hover/click
tweens, keyboard 1-9 shortcuts, the `<font color=...>` response text formatting, connection cleanup —
all of it operates on `UDim2` scale/offset values that mean exactly the same thing inside a
`BillboardGui` as inside a `ScreenGui`. None of that logic needs to change, only *which container* it
targets.

**Interpretation of "left side of the NPC's head":** treated as the *viewer's* left while facing the
NPC (the NPC's own right, since a player is normally facing the NPC during a conversation), not the
NPC's own anatomical left. This is a one-character sign flip (`StudsOffset.X`) if it reads backward
once you look at it — flagged clearly below, not something to treat as a blocker.

**Reused rather than rebuilt:** the new billboard's internal response panel is built by cloning the
*existing* `StarterGui.dialog.dialogResponses` (already restyled to this game's theme in an earlier
pass — dark background, rounded corners, GothamSSm) rather than reconstructing it from scratch, and
the 6 NPCs it's attached to are read generically from `QuestConfig.Quests`, matching how every other
quest-adjacent system in this game already avoids hardcoding NPC names.

---

## Part 1 — build the reusable billboard prefab

**`ReplicatedStorage.GuiTemplates.QuestResponsesBillboard`** (new `BillboardGui`) — run once:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local guiTemplates = ReplicatedStorage.GuiTemplates
if guiTemplates:FindFirstChild("QuestResponsesBillboard") then
	guiTemplates.QuestResponsesBillboard:Destroy() -- idempotent re-run
end

local billboard = Instance.new("BillboardGui")
billboard.Name = "QuestResponsesBillboard"
-- Sized in studs (BillboardGui, not screen pixels). 5x2.5 comfortably fits up to a handful of
-- stacked short response lines without dominating the view next to the NPC.
billboard.Size = UDim2.fromOffset(5, 2.5) -- interpreted in studs on a BillboardGui, not pixels
-- Positive X = the NPC's own right, which is the viewer's LEFT while facing the NPC during a
-- conversation (see Context above -- flip the sign here if this reads backward once you look at it).
billboard.StudsOffset = Vector3.new(3, 1, 0)
billboard.MaxDistance = 50 -- matches the existing dialogue billboard (Head.gui)'s own MaxDistance
billboard.AlwaysOnTop = true -- response buttons must stay clickable/visible through world geometry,
                              -- matching how the existing dialogue text already forces AlwaysOnTop
billboard.Enabled = true

-- Clone the EXISTING, already-themed response panel wholesale (dark background, UICorner, GothamSSm
-- template button) rather than rebuilding its look from scratch. Its Size/Position are screen-relative
-- today (meant for a ScreenGui); resized here to fill the billboard's own canvas instead.
local responsesFrame = StarterGui.dialog.dialogResponses:Clone()
responsesFrame.Size = UDim2.fromScale(1, 1)
responsesFrame.Position = UDim2.fromScale(0, 0)
responsesFrame.Parent = billboard

billboard.Parent = guiTemplates
print("QuestResponsesBillboard prefab built.")
```

### Verify

- [ ] `ReplicatedStorage.GuiTemplates.QuestResponsesBillboard` exists, containing a `dialogResponses`
      Frame with its `UIListLayout` and `template` button intact (same visual style as before).

---

## Part 2 — attach the billboard to every quest NPC's head

Run once, after Part 1. Reads the NPC list from `QuestConfig.Quests` rather than a hardcoded set of 6
names, so any future quest NPC gets this automatically:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)
local prefab = ReplicatedStorage.GuiTemplates.QuestResponsesBillboard
local questsFolder = Workspace.Quests

for questId, quest in QuestConfig.Quests do
	local npc = questsFolder:FindFirstChild(quest.npcName)
	local head = npc and npc:FindFirstChild("Head")
	if not head then
		warn(`Could not find Head on NPC "{quest.npcName}" for quest "{questId}" -- skipped`)
		continue
	end

	local existing = head:FindFirstChild("responsesGui")
	if existing then
		existing:Destroy() -- idempotent re-run
	end

	local billboard = prefab:Clone()
	billboard.Name = "responsesGui"
	billboard.Parent = head
end

print("responsesGui attached to every quest NPC's Head.")
```

### Verify

- [ ] Every one of the 6 quest NPCs (`Level 1 Quest` through `Level 70 Quest`) has a `responsesGui`
      `BillboardGui` on its `Head`, each an independent clone (not the same Instance referenced
      twice — confirm by checking their `UniqueId`s differ).

---

## Part 3 — `DialogModule`: make the response container per-instance

**`ReplicatedStorage.DialogModule`** — remove the shared module-level resolution:

```lua
-- Resolved once and held for the session. That is only safe because StarterGui.dialog has
-- ResetOnSpawn = false: with reset on, Roblox destroys and rebuilds this GUI on every respawn,
-- leaving this reference (and the nine response buttons built from it below) pointing at a
-- destroyed copy -- responses then silently stop appearing, which in turn strands the FOV source
-- below because nothing can be clicked to end the conversation.
local DIALOG_RESPONSES_UI = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("dialog"):WaitForChild("dialogResponses")
```

Delete this block entirely (both the comment and the line) — the reasoning it documents no longer
applies once each NPC owns its own response container, cloned fresh at setup rather than resolved
from a respawn-sensitive `PlayerGui` path.

In the constructor (`DialogModule.new`), add the per-instance resolution right after
`self.npcGui = self.npc:WaitForChild("Head"):WaitForChild("gui")`:

```lua
	self.responsesGui = self.npc:WaitForChild("Head"):WaitForChild("responsesGui"):WaitForChild("dialogResponses")
```

Replace the template-cloning block, which currently reads:

```lua
	local template = DIALOG_RESPONSES_UI:FindFirstChild("template")
	if template then
		for i = 1,9 do
			local newResponseButton = template:Clone()
			newResponseButton.Parent = DIALOG_RESPONSES_UI
			newResponseButton.Name = i
		end
		template:Destroy()
	end
```

with:

```lua
	-- Per-instance now, not a shared module-level container: each NPC owns its own responsesGui
	-- (Part 2), so this clones fresh buttons into THIS NPC's own panel every time a DialogModule is
	-- constructed, rather than the old single-shared-panel design where only the first NPC ever
	-- talked to actually built any buttons and the rest silently reused them.
	local template = self.responsesGui:FindFirstChild("template")
	if template then
		for i = 1,9 do
			local newResponseButton = template:Clone()
			newResponseButton.Parent = self.responsesGui
			newResponseButton.Name = i
		end
		template:Destroy()
	end
```

In `triggerDialog`, replace:

```lua
		-- Show responses
		local uiResponses = DIALOG_RESPONSES_UI
```

with:

```lua
		-- Show responses
		local uiResponses = self.responsesGui
```

In `hideGui`, replace:

```lua
	-- hide player response options
	local playerReponseOptions = DIALOG_RESPONSES_UI
```

with:

```lua
	-- hide player response options
	local playerReponseOptions = self.responsesGui
```

No other line in this file references `DIALOG_RESPONSES_UI` — confirmed by reading the complete file
before writing this. Nothing else in the constructor, `triggerDialog`, `showGui`, or `hideGui` needs
to change: the typewriter reveal, hover/click tweens, keyboard shortcuts, and response text
formatting all operate on whatever `uiResponses`/`self.responsesGui` resolves to, unchanged.

### Verify

- [ ] Talking to any one of the 6 NPCs shows response buttons floating beside *that* NPC's own head,
      not at a fixed screen position.
- [ ] Talking to a second NPC (after or instead of the first) shows *that* NPC's own responses,
      correctly populated — not stale buttons left over from a different NPC, and not an empty panel
      (the bug this refactor exists to prevent).
- [ ] Every existing interaction still works identically: hover grows the button and plays the tick
      sound, clicking or pressing 1-9 selects a response, the typewriter reveal timing is unchanged,
      and `<font color=...>`-formatted response numbers still render correctly.
- [ ] Walking away mid-conversation and the "not actually an exit quip" / exit-quip flows all still
      correctly hide the *right* NPC's response buttons.
- [ ] The billboard reads on the correct side once you actually look at it in Play mode — if "left"
      came out backward, flip `StudsOffset.X`'s sign in the `QuestResponsesBillboard` prefab (Part 1)
      and re-run Part 2 to reattach it.

---

## Part 4 — cleanup, after everything above is verified

`StarterGui.dialog` (the `ScreenGui`) is now unreferenced — nothing in `DialogModule` resolves
`PlayerGui.dialog` anymore after Part 3. Confirm that with a search before deleting anything:

```lua
-- Sanity check first -- should find nothing outside this ScreenGui's own subtree.
```

Search the place for `"dialog"` under `PlayerGui`/`StarterGui` references in scripts (e.g. via
`script_grep` for `WaitForChild("dialog")` and `PlayerGui.dialog`) to confirm no other script still
depends on it, then delete `StarterGui.dialog` entirely.

### Verify

- [ ] After deleting `StarterGui.dialog`, every one of the 6 NPCs' conversations still works fully
      end to end (this is the real proof nothing still depended on it, not just the absence of an
      error at deletion time).

## Master verification checklist

- [ ] All 6 quest NPCs show their dialogue responses as a billboard near their own head, positioned to
      the correct side.
- [ ] Multiple NPCs' conversations are fully independent — no shared/stale button state between them.
- [ ] Every pre-existing interaction (typewriter, hover, click, keyboard shortcuts, walk-away,
      exit-quip) behaves identically to before this refactor.
- [ ] `StarterGui.dialog` is removed with nothing left depending on it.
- [ ] The quest system's other pieces (accept/progress/turn-in/reward, the point emote, the Quest Log,
      completion feedback) are completely unaffected — this refactor only touches how responses are
      displayed, not the quest logic itself.

## Notes for whoever applies this

- Every fact above (the shared-singleton response container, the destroy-template-once behavior, the
  complete absence of other `DIALOG_RESPONSES_UI` references) was verified by reading `DialogModule`'s
  full current source immediately before this was written.
- `script_grep` and `script_read` have been observed to report different line numbers for the same
  script in this project. Match edits on the quoted code, not on line numbers.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
