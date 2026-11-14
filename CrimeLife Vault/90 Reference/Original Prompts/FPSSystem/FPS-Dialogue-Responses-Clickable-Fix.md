# Prompt: Fix Unclickable Dialogue Response Billboard (Move to PlayerGui + Adornee)

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**Root cause, adopting the reported research rather than second-guessing it:** BillboardGuis
parented directly under a `Workspace` `BasePart` are documented in multiple independent community
reports to have unreliable click/`MouseButton1Down` detection, even with `Active = true` set correctly
(confirmed live: it already is, on both the billboard and the button template — that alone isn't the
fix). The reliable fix is what was researched: host the billboard in `PlayerGui`/`StarterGui` instead
and point it at its target via `Adornee`, rather than parenting it onto the part directly.

**A contributing factor, found while re-reading the live state, consistent with the same underlying
problem:** the current `responsesGui` sits only `2.6` studs from the NPC's own `UpperTorso`, and
`AlwaysOnTop` is confirmed `false` live (despite an earlier prompt asking for `true` — whatever
applied that pass evidently didn't carry it through, or it was reset since). With `AlwaysOnTop` off,
the NPC's own body mesh can render (and, plausibly, hit-test) in front of the billboard depending on
camera angle — compounding the same class of problem from a different angle. Both are fixed below.

**The real adaptation problem, and why this isn't a drop-in property change:** a single `PlayerGui`
billboard is shared across all 6 NPCs by nature — there's only one `PlayerGui` per client. That's
actually fine here, *because* only one conversation can ever be open at a time (already enforced via
the `NPCprompt` tag). But it means the design has to go back to a **shared** response panel (like the
very first version, before last time's per-NPC-instance refactor) — with one new piece that version
never needed: the billboard's `Adornee` must be set to whichever NPC's conversation is currently
open, and cleared when it closes. Get that lifecycle wrong and either responses show up next to the
wrong NPC, or stay visibly stuck next to whoever you last talked to. This document ties `Adornee`
exactly to the same conversation-open/close lifecycle boundary `DialogModule` already uses for
clearing its camera FOV source, so it can't drift out of sync with it.

**Confirmed live, so this document builds on fact, not the last document's assumptions:**
- `ReplicatedStorage.GuiTemplates.QuestResponsesBillboard` still exists with its `template` button
  intact (never consumed — only its six *clones*, one per NPC, were).
- Each of the 6 NPCs currently has its own `UpperTorso.responsesGui` (confirmed on `Level 1 Quest`) —
  these become dead weight once this document lands, and are removed in Part 3.
- `DialogModule`'s per-NPC `self.responsesGui` resolution, and the per-constructor button-cloning it
  drives, are exactly what needs to unwind back to a shared, module-level resolution — done carefully
  this time, with the `Adornee` swap making it safe for 6 NPCs instead of the multi-NPC bug the very
  first version had.

---

## Part 1 — a single response billboard living in `StarterGui`

Run once:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local existing = StarterGui:FindFirstChild("QuestResponsesGui")
if existing then
	existing:Destroy() -- idempotent re-run
end

local billboard = ReplicatedStorage.GuiTemplates.QuestResponsesBillboard:Clone()
billboard.Name = "QuestResponsesGui"
billboard.AlwaysOnTop = true -- was false live; also requested explicitly
billboard.Adornee = nil -- nothing to point at until a conversation actually opens (Part 2)
billboard.Parent = StarterGui

print("QuestResponsesGui created in StarterGui, Adornee-driven.")
```

This clones from the original prefab (untouched, `template` still intact), not from any of the 6
already-built per-NPC copies — so the usual "build 9 numbered buttons from `template`, then destroy
it" step still has a real template to consume.

### Verify

- [ ] `StarterGui.QuestResponsesGui` exists, `AlwaysOnTop = true`, `Adornee = nil`, containing the
      `dialogResponses` Frame with its `template` button still present (not yet consumed — that
      happens once, at module load, in Part 2).

---

## Part 2 — `DialogModule`: shared panel again, now with `Adornee` lifecycle

**`ReplicatedStorage.DialogModule`** — replace the module-scope comment block that currently reads:

```lua
-- Responses used to live in one shared PlayerGui panel resolved here, at module scope. They are now
-- per-NPC: each quest NPC carries its own `responsesGui` BillboardGui on its Head, resolved in the
-- constructor below. One shared set of buttons cannot float beside six NPCs at six world positions,
-- and the old design only ever built buttons for whichever NPC was talked to first.
--
-- This also removes the module's dependency on a respawn-sensitive PlayerGui path entirely.
```

with:

```lua
-- Shared again, not per-NPC -- but safely this time. Exactly one conversation can ever be open at
-- once (enforced by turnProximityPromptsOn below), so one BillboardGui in PlayerGui, re-Adornee'd to
-- whichever NPC is currently being talked to, correctly serves all six without needing a separate
-- copy per NPC. Adornee is set in showGui() and cleared in hideGui()'s genuine-exit branch -- the
-- exact same lifecycle boundary already used for clearing the Dialogue camera FOV source below, so
-- the two can't drift out of sync with each other.
--
-- Living in PlayerGui with Adornee, rather than parented directly onto each NPC's part in Workspace
-- (the previous design): BillboardGui button clicks were unreliable when parented directly under a
-- Workspace part in this game, confirmed against community reports of the same limitation. This
-- also removes the module's dependency on a respawn-sensitive PlayerGui path in the sense that
-- mattered before -- StarterGui.QuestResponsesGui has the same ResetOnSpawn = false guarantee the
-- original shared panel relied on.
local RESPONSES_BILLBOARD = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("QuestResponsesGui")
local DIALOG_RESPONSES_UI = RESPONSES_BILLBOARD:WaitForChild("dialogResponses")

-- Built exactly once, here, not inside DialogModule.new: DIALOG_RESPONSES_UI is shared across every
-- NPC's DialogModule instance now, so building it again per-constructor would either duplicate the
-- 9 buttons or -- since `template` is destroyed after the first build -- silently build nothing for
-- every NPC after the first. That second failure mode is exactly the bug this module had the very
-- first time responses were a shared panel, before they were (temporarily) made per-NPC.
do
	local template = DIALOG_RESPONSES_UI:FindFirstChild("template")
	if template then
		for i = 1, 9 do
			local newResponseButton = template:Clone()
			newResponseButton.Parent = DIALOG_RESPONSES_UI
			newResponseButton.Name = i
		end
		template:Destroy()
	end
end
```

In the constructor (`DialogModule.new`), delete this line entirely (no replacement — the panel is
resolved at module scope now, not per-instance):

```lua
	-- On UpperTorso, not Head: the Head already carries the name/dialogue bubble, and two billboards
	-- on the same part overlap and hide each other.
	self.responsesGui = self.npc:WaitForChild("UpperTorso"):WaitForChild("responsesGui"):WaitForChild("dialogResponses")
```

Also delete the button-cloning block that currently follows it in the constructor (this moved to
module scope above, so it must not also run per-instance):

```lua
	-- Per-instance now: this builds buttons into THIS NPC's own panel. Under the old shared-panel
	-- design only the first NPC ever talked to actually built any, and every other NPC silently
	-- reused that one set -- which worked solely because one conversation can be open at a time.
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
		local uiResponses = self.responsesGui
```

with:

```lua
		-- Show responses
		local uiResponses = DIALOG_RESPONSES_UI
```

In `hideGui`, replace:

```lua
	-- hide player response options
	local playerReponseOptions = self.responsesGui
```

with:

```lua
	-- hide player response options
	local playerReponseOptions = DIALOG_RESPONSES_UI
```

In `showGui`, set the `Adornee` to this conversation's NPC. Add right after the existing
`turnProximityPromptsOn(false)` line:

```lua
	RESPONSES_BILLBOARD.Adornee = self.npc:FindFirstChild("UpperTorso")
```

In `hideGui`, clear it on genuine exit — the existing FOV-source branch already distinguishes
"genuinely closing" from "still open, just mid-typewriter-exit-quip"; add the clear to the same
branch that already clears the FOV source. Currently:

```lua
	if notActuallyAnExitQuip then
		CameraAuthority.FieldOfView:Set(FOV_SOURCE, TALKING_FOV)
	else
		CameraAuthority.FieldOfView:Clear(FOV_SOURCE)
	end
```

becomes:

```lua
	if notActuallyAnExitQuip then
		CameraAuthority.FieldOfView:Set(FOV_SOURCE, TALKING_FOV)
	else
		CameraAuthority.FieldOfView:Clear(FOV_SOURCE)
		RESPONSES_BILLBOARD.Adornee = nil
	end
```

No other line in the file references `self.responsesGui` or the old per-NPC resolution — confirmed
by reading the complete current file before writing this.

### Verify

- [ ] Talking to any of the 6 NPCs now shows a **clickable** response billboard beside that NPC —
      actually click a response with the mouse, don't just confirm it renders.
- [ ] The billboard is not occluded by the NPC's own body from any normal camera angle
      (`AlwaysOnTop = true` fixed this).
- [ ] Talking to NPC A, closing the conversation, then talking to NPC B shows B's responses next to
      B — not stale, not still adorned to A.
- [ ] Walking away mid-conversation (the existing range-check exit path) also clears the `Adornee` —
      trace this specific path since it calls `hideGui()` with different arguments than a normal
      response click; confirm it lands in the branch that clears `Adornee`, not the one that doesn't.
- [ ] Keyboard 1-9 shortcuts still select responses correctly (unaffected by this change, but confirm
      rather than assume).
- [ ] Only one conversation's responses are ever visible at a time, even if you rapidly walk between
      two NPCs' prompts.

---

## Part 3 — cleanup, after Part 2 is verified

The 6 per-NPC `responsesGui` BillboardGuis (on each NPC's `UpperTorso`) are now dead weight — nothing
resolves them anymore. Remove them, reading the NPC list from `QuestConfig` rather than hardcoding six
names:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)
local questsFolder = Workspace.Quests

for questId, quest in QuestConfig.Quests do
	local npc = questsFolder:FindFirstChild(quest.npcName)
	local upperTorso = npc and npc:FindFirstChild("UpperTorso")
	local staleGui = upperTorso and upperTorso:FindFirstChild("responsesGui")
	if staleGui then
		staleGui:Destroy()
	end
end

print("Stale per-NPC responsesGui instances removed.")
```

### Verify

- [ ] No NPC's `UpperTorso` has a `responsesGui` child anymore.
- [ ] All 6 NPCs' conversations still work fully end to end after this cleanup (proof nothing still
      depended on the per-NPC copies, not just an assumption from the earlier code change alone).

## Master verification checklist

- [ ] Every one of the 6 quest NPCs' dialogue responses are clickable via mouse, not just visible.
- [ ] `AlwaysOnTop` is `true` on the response billboard.
- [ ] Switching between NPCs never shows stale or misplaced responses.
- [ ] Every other quest-system behavior (accept/progress/turn-in/reward, the point emote, the Quest
      Log, completion feedback, the existing name/dialogue bubble) is completely unaffected.

## Notes for whoever applies this

- Every fact above (the live `Active`/`AlwaysOnTop` values, the `UpperTorso`-not-`Head` placement, the
  complete current `DialogModule` source) was verified live immediately before this was written.
- `script_grep` and `script_read` have been observed to report different line numbers for the same
  script in this project. Match edits on the quoted code, not on line numbers.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
