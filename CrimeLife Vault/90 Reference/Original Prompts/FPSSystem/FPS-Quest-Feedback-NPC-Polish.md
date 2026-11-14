# Prompt: Quest Completion Feedback (Toast + Banner + VFX + Sound) and NPC Polish

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**Depends on `FPS-Quest-System-Level1-KillThugs.md` already being applied** — this document adds to
`QuestService`, `QuestConfig`, and the `QuestDialogue` LocalScript that document builds. If that one
hasn't landed yet, apply it first; the attributes and scripts referenced below (`Quest_<id>_State`,
`Workspace.Quests."Level 1 Quest".Animate`, etc.) won't exist otherwise.

**On the reference image:** it's being used purely as a style reference for a notification's look
(dark rounded panel, bold red "Notification!" header, bold-lead + gray-rest message line), not proof
that panel already exists in this project — confirmed live, nothing matching it exists in
`StarterGui`/`ReplicatedStorage.GuiTemplates` today. This document builds it fresh.

**One thing worth flagging so it isn't confused with what you asked for:** this place's `DataModel`
does have a `NotificationService` at the root — that's a real, unrelated built-in Roblox engine
service (native platform notifications), not a custom object, and not what's being built here. The
toast in this document is an ordinary custom GUI, matching this game's own visual system, unrelated to
that service.

**On the NPC's animation script, confirmed live:** `Workspace.Quests."Level 1 Quest".Animate` is the
*unmodified* stock Roblox R15 animate script — verified by reading its full source. Two things that
matters here:
1. It supports a config-override pattern already: an `Animation` instance parented under
   `Animate.idle` overrides the hardcoded default idle animations. `Animate.idle` already has two such
   children (`Animation1`, `Animation2`) from whatever this rig shipped with — replacing them is the
   correct, already-supported way to set the new idle clip, not a hack.
2. It already has a fully configured "point" emote — its own `animNames.point` table (read directly
   from the live script) is `{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 }`, and
   the script exposes `script.PlayEmote` (a `BindableFunction`) specifically so other scripts can
   trigger it by name. That means the exact animation id doesn't need to be supplied or guessed at
   all — invoking `Animate.PlayEmote:Invoke("point")` plays this NPC's own already-correct classic
   Roblox point emote directly.

**Why the point emote (and the rest of this NPC's dialogue) is deliberately client-local, not
broadcast to every nearby player:** `Animate` is a `LocalScript`, so every client runs its own
independent copy with its own independent animation state — and the entire dialogue system this NPC
uses (`DialogModule`) is already built the same way: purely client-local, no server synchronization,
confirmed in the previous document. Making just the point emote broadcast to everyone while the
conversation itself stays private per-player would be an inconsistent, partial fix bolted onto an
architecture that doesn't support it anywhere else. So: the accepting player sees the NPC point at
them; other nearby players don't. If you want every nearby player to see it, that's a materially
bigger change (partially server-synchronizing the dialogue system) and not something to take on as a
side effect of a small polish pass — say so explicitly if you want that scoped separately.

---

## Part 1 — Anchor the NPC and set its idle animation

**`Workspace.Quests."Level 1 Quest".HumanoidRootPart`** — set `Anchored = true`. Everything else in
the rig is joint/constraint-connected relative to this part, so anchoring just the root is sufficient
to hold the whole rig in place; no need to anchor every limb individually.

**`Workspace.Quests."Level 1 Quest".Animate.idle`** — replace its two existing `Animation` children
with one pointing at the new clip:

```lua
local Workspace = game:GetService("Workspace")
local idle = Workspace.Quests["Level 1 Quest"].Animate.idle

for _, child in idle:GetChildren() do
	if child:IsA("Animation") then
		child:Destroy()
	end
end

local newIdle = Instance.new("Animation")
newIdle.Name = "Animation1"
newIdle.AnimationId = "rbxassetid://125474693216077"
newIdle.Parent = idle

print("Level 1 Quest idle animation set.")
```

The stock script's own `ChildAdded`/`ChildRemoved` listeners on `Animate.idle` reconfigure the idle
animation set live when this runs — no need to restart anything.

### Wire the point emote into the accept response

**`Workspace.Quests."Level 1 Quest".QuestDialogue`** (the `LocalScript` from the previous document) —
in the `responded` handler, in the `currentMode == "Offer" and responseNum == 1` branch, add the emote
trigger alongside the existing accept logic:

```lua
	if currentMode == "Offer" and responseNum == 1 then
		acceptQuestRequest:FireServer(QUEST_ID)
		local animateScript = npc:FindFirstChild("Animate")
		if animateScript then
			animateScript.PlayEmote:Invoke("point")
		end
		dialogObject:hideGui("Good luck out there.")
```

### Verify

- [ ] The NPC no longer falls, ragdolls, or can be pushed by anything.
- [ ] It idles with the new animation (`125474693216077`), not the previous default idle.
- [ ] Accepting the quest makes the NPC play the classic Roblox point gesture once, for the accepting
      player. It returns to idling afterward (the stock script already handles that — `point` is a
      non-looping emote in its own `emoteNames` table).

---

## Part 2 — quest-completion feedback: banner, bright effect, and sound

All three fire together, client-side, the moment *this player's own* `Quest_<id>_State` attribute
transitions to `QuestConfig.STATE_COMPLETED` — the same reactive-attribute pattern
`WeaponaryShopController` already uses for `WeaponUpgrade_`/`WeaponOwned_`/`LoadoutSlot`.

### GUI template — `ReplicatedStorage.GuiTemplates.QuestCompleteBanner` (new)

A centered `Frame`, matching the game's dark/rounded theme, sized for one short line of large text
(e.g. `Size = UDim2.fromOffset(500, 90)`, `AnchorPoint = (0.5, 0.5)`, `Position = UDim2.fromScale(0.5, 0.3)`,
dark background `Color3.fromRGB(20, 20, 24)`, `BackgroundTransparency = 0.05`, `UICorner` at `0.15`
scale). One child `TextLabel` (`Label`), `TextScaled = true`, GothamSSm Bold, white text with a black
`UIStroke`, `RichText = true` (so the quest name can be bolded).

### `StarterPlayer.StarterPlayerScripts.QuestFeedbackController` (new `LocalScript`)

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local COMPLETE_SOUND_ID = "rbxassetid://95148743653937"
local BANNER_HOLD_TIME = 2
local BANNER_FADE_TIME = 0.4

local completeSound = Instance.new("Sound")
completeSound.Name = "QuestCompleteSound"
completeSound.SoundId = COMPLETE_SOUND_ID
completeSound.Volume = 0.7
completeSound.Parent = SoundService

local gui = Instance.new("ScreenGui")
gui.Name = "QuestFeedbackGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Tracks which quest ids we've already shown completion feedback for, so a stray extra
-- AttributeChanged firing (e.g. a later unrelated attribute update) can never replay it.
local acknowledged: { [string]: boolean } = {}

local function showBanner(questName: string)
	local banner = guiTemplates.QuestCompleteBanner:Clone()
	banner.Label.Text = `<b>{questName}</b> Completed!`
	banner.GroupTransparency = 1
	banner.Parent = gui

	local fadeIn = TweenService:Create(banner, TweenInfo.new(BANNER_FADE_TIME), { GroupTransparency = 0 })
	fadeIn:Play()
	fadeIn.Completed:Connect(function()
		task.wait(BANNER_HOLD_TIME)
		local fadeOut = TweenService:Create(banner, TweenInfo.new(BANNER_FADE_TIME), { GroupTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			banner:Destroy()
		end)
	end)
end

local function playBrightEffect()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	-- Reuses the exact same shine particle LevelUpVFX already attaches to every character at spawn,
	-- rather than adding a second emitter that does visually the same thing.
	local shine = rootPart and rootPart:FindFirstChild("LevelUpShine")
	if shine and shine:IsA("ParticleEmitter") then
		shine:Emit(30)
	end
end

local function onQuestStateChanged(questId: string)
	local state = player:GetAttribute(QuestConfig.stateAttributeFor(questId))
	if state ~= QuestConfig.STATE_COMPLETED or acknowledged[questId] then
		return
	end
	acknowledged[questId] = true

	local quest = QuestConfig.Quests[questId]
	if not quest then
		return
	end

	showBanner(quest.name)
	playBrightEffect()
	completeSound:Play()
end

for questId in QuestConfig.Quests do
	player:GetAttributeChangedSignal(QuestConfig.stateAttributeFor(questId)):Connect(function()
		onQuestStateChanged(questId)
	end)
end
```

`QuestCompleteBanner`'s root should be a `CanvasGroup` (not a plain `Frame`) so `GroupTransparency`
fades the whole banner — background, text, and stroke together — in one tween, the same technique
`LevelingBar`/`StaminaBar` already use in this game's GUI templates. If you build it as a `Frame`
instead, fade `BackgroundTransparency` and the `Label`'s `TextTransparency`/`UIStroke.Transparency`
together instead of relying on a single property.

### Verify

- [ ] Turning in the completed quest shows the banner ("A Warning to Thugs Completed!" — or whatever
      the quest's `name` is, bolded), plays the sound, and emits the shine effect on the player's own
      character — confirmed by actually turning in a quest, not just reading the code.
- [ ] The banner fades in, holds, fades out, and removes itself — no leftover GUI instance after it's
      done.
- [ ] It fires exactly once per completion — repeatedly re-triggering `AttributeChanged` for the same
      already-`Completed` quest (e.g. from an unrelated attribute update racing in) does not replay it.
- [ ] Other players near the completing player do not see this banner or hear the sound — it's
      personal feedback, not a broadcast (matches what was actually asked for: acknowledging *the
      player's* completion, not announcing it to everyone).

---

## Part 3 — bottom-left "Notification!" toast

A small, reusable, generic notification display — not wired to anything except quest completion for
now, but shaped so a later, unrelated notification could reuse the same `show` function without
rebuilding it (this is the one thing in this document that's intentionally a little more general than
today's single caller needs, because the reference image itself is clearly a general-purpose pattern,
not a one-off).

### GUI template — `ReplicatedStorage.GuiTemplates.Notification` (new)

A `Frame`, dark rounded panel matching the reference's proportions (roughly `UDim2.fromOffset(420, 100)`),
`UICorner` at `0.1` scale, background `Color3.fromRGB(20, 20, 24)` at `BackgroundTransparency = 0.05`.
Two `TextLabel` children stacked with a `UIListLayout` and some `UIPadding`:
- `TitleLabel` — GothamSSm Bold, `Text = "Notification!"`, `TextColor3 = Color3.fromRGB(220, 60, 60)`.
- `MessageLabel` — GothamSSm Bold, `RichText = true`, `TextColor3 = Color3.fromRGB(200, 200, 205)`
  (the gray base color from the reference — bolded portions of the message can be tagged
  `<font color="rgb(255,255,255)">...</font>` inline by the caller for the white-highlighted part).

### `ReplicatedStorage.Modules.NotificationController` (new `ModuleScript`) — the reusable part

```lua
-- Generic bottom-left toast notification. One function, `show`, clones the template, slides/fades it
-- in, holds it, then slides/fades it out and destroys it. Multiple notifications stack via the
-- container's own UIListLayout rather than needing separate queue-management code -- each call is
-- fully independent and self-contained.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local HOLD_TIME = 4
local SLIDE_TIME = 0.35

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local gui = Instance.new("ScreenGui")
gui.Name = "NotificationGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.BackgroundTransparency = 1
container.AnchorPoint = Vector2.new(0, 1)
container.Position = UDim2.new(0, 20, 1, -20)
container.Size = UDim2.fromOffset(420, 400)
container.Parent = gui

local listLayout = Instance.new("UIListLayout")
listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = container

local NotificationController = {}

function NotificationController.show(message: string)
	local notification = guiTemplates.Notification:Clone()
	notification.MessageLabel.Text = message
	notification.Position = UDim2.fromOffset(-440, 0) -- start off-screen to the left
	notification.LayoutOrder = os.clock() * 1000 -- newest at the bottom, oldest above it
	notification.Parent = container

	local slideIn = TweenService:Create(
		notification,
		TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, 0) }
	)
	slideIn:Play()

	task.delay(SLIDE_TIME + HOLD_TIME, function()
		local slideOut = TweenService:Create(
			notification,
			TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(-440, 0) }
		)
		slideOut:Play()
		slideOut.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
end

return NotificationController
```

Note this module creates its own `ScreenGui`/container the first time it's required by a given
client, and every subsequent `require(...)` anywhere on that same client returns the same cached
module table (standard Luau `require` behavior) — so multiple callers share one notification stack
correctly, without needing to coordinate.

### Wire it into quest completion

**`StarterPlayer.StarterPlayerScripts.QuestFeedbackController`** — add near the top:

```lua
local NotificationController = require(ReplicatedStorage.Modules.NotificationController)
```

In `onQuestStateChanged`, alongside the existing `showBanner`/`playBrightEffect`/`completeSound:Play()`
calls, add:

```lua
	NotificationController.show(`You have completed <font color="rgb(255,255,255)">{quest.name}</font>`)
```

### Verify

- [ ] Completing a quest slides in a "Notification! / You have completed **[Quest Name]**" toast at
      the bottom-left, matching the reference's dark rounded panel with a red "Notification!" header.
- [ ] It holds for a few seconds, then slides back out and removes itself.
- [ ] Triggering it twice in quick succession (e.g. two different quest completions close together)
      stacks both toasts cleanly rather than overlapping — confirm this even though only one quest
      exists today, since the container is already built to hold more than one.

## Master verification checklist

- [ ] Level 1 Quest NPC is anchored, idles with the new animation, and points (for the accepting
      player only) on quest accept.
- [ ] Quest completion shows the center banner, bright shine effect, and sound together.
- [ ] Quest completion also shows the bottom-left "Notification!" toast.
- [ ] Nothing about the existing quest flow (accept/progress/turn-in/reward granting), the shop, the
      player card, or combat regressed.

## Notes for whoever applies this

- Every fact above (the stock `Animate` script's exact content, the existing `idle` override
  children, the `point` emote's real animation id, the presence of an unrelated
  `NotificationService` engine singleton) was verified live immediately before this was written.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
