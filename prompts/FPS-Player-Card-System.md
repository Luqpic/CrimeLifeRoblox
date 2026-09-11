# Prompt: Player Card (Button, Card GUI, /view Chat Command)

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

**Prerequisite:** requires `FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar.md` (specifically its Part 1) to have already been applied — this prompt adds two more templates to the same `ReplicatedStorage.GuiTemplates` folder that prompt creates. If that folder doesn't exist yet, run that prompt's Part 1 first.

## Context — two deliberate design choices, explained rather than silently made

**Why the card is a template you `Clone()`, but the button is not.** The reminder that "all GUIs should be a cloneable object, not `Instance.new`" is about not hand-constructing visual trees in code — it does not mean every single GUI element must be dynamically cloned at runtime. `StarterGui."Custom Inventory".openButton` already demonstrates the alternative: a real, static, hand-editable object that simply sits in `StarterGui` and is auto-copied into every player's `PlayerGui` by the engine, with zero script construction at all. The new player-card button only ever needs to exist once per player, in a fixed position, so it follows `openButton`'s exact pattern — added as a real sibling object under `StarterGui."Custom Inventory"`, not cloned. The **card itself** is different: it needs to be instantiated on demand (opened, closed, reopened for a different target), possibly more than once in sequence, with content that changes per viewing — that's exactly the case a template-plus-`Clone()` pattern is for, so the card lives in `ReplicatedStorage.GuiTemplates` and is cloned each time it's opened.

**Why viewing another player needs no server code.** `Level`/`XP`/`NextLevelXP` are `Player` Attributes (set by `LevelingService`), and `Humanoid.Health`/`MaxHealth` are ordinary properties of a replicated Instance in `Workspace` — both already replicate to every client by default, the same way `leaderstats.Cash` already shows for everyone in the default leaderboard. Reading a target player's stats from a LocalScript needs no new RemoteEvent.

**"Armor stats" clarified:** per your last message, this means current Health/MaxHealth (which already varies by level via `LevelingService`'s `MAX_HEALTH_PER_LEVEL` bonus) — not a new armor/defense system. That's what the card's Health row shows.

---

## Part 1 — Add two templates (one-time setup)

Run this **once**, the same way as the GUI-template-conversion prompt's Part 1 (Command Bar, or a temporary `Script` you delete afterward):

```lua
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConstants = require(ReplicatedStorage.Movement.Constants)

local templates = ReplicatedStorage:WaitForChild("GuiTemplates")

-- ============================================
-- playerCardButton -- a real static object, NOT cloned, matching openButton's own pattern.
-- Stacked directly below openButton in the same top-right corner.
-- ============================================
do
	local inventoryGui = StarterGui:WaitForChild("Custom Inventory")
	local openButton = inventoryGui:WaitForChild("openButton")

	local button = Instance.new("ImageButton")
	button.Name = "playerCardButton"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -20, 0, 78) -- 20px below openButton (48px tall + 10px gap)
	button.Size = UDim2.fromOffset(48, 48)
	button.BackgroundColor3 = openButton.BackgroundColor3
	button.BackgroundTransparency = openButton.BackgroundTransparency
	button.Image = ""
	button.Parent = inventoryGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = button

	local icon = Instance.new("TextLabel")
	icon.Name = "icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.BuilderSans
	icon.TextScaled = true
	icon.TextColor3 = Color3.new(1, 1, 1)
	icon.Text = "🪪"
	icon.Parent = button
end

-- ============================================
-- PlayerCard -- cloned fresh each time a card is opened (your own, or /view'd from another player)
-- ============================================
do
	local card = Instance.new("Frame")
	card.Name = "PlayerCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(320, 420)
	card.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
	card.BackgroundTransparency = 0.05 -- more opaque than the thin HUD bars -- this is a readable panel

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.fromOffset(28, 28)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "\u{2715}"
	closeButton.ZIndex = 2
	closeButton.Parent = card

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0.3, 0)
	closeCorner.Parent = closeButton

	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Name = "Thumbnail"
	thumbnail.AnchorPoint = Vector2.new(0.5, 0)
	thumbnail.Position = UDim2.new(0.5, 0, 0, 20)
	thumbnail.Size = UDim2.fromOffset(120, 120)
	thumbnail.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	thumbnail.Image = ""
	thumbnail.Parent = card

	local thumbnailCorner = Instance.new("UICorner")
	thumbnailCorner.CornerRadius = UDim.new(0.15, 0)
	thumbnailCorner.Parent = thumbnail

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 150)
	nameLabel.Size = UDim2.new(1, -40, 0, 30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = ""
	nameLabel.Parent = card

	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Position = UDim2.new(0, 20, 0, 195)
	statsContainer.Size = UDim2.new(1, -40, 1, -215)
	statsContainer.BackgroundTransparency = 1
	statsContainer.Parent = card

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = statsContainer

	-- HealthRow -- same stat-row visual language as WeaponStatPanel, authored directly here (a
	-- separate template tree, not a shared dependency, so it's a deliberate duplication of style
	-- values rather than a code link between the two).
	local healthRow = Instance.new("Frame")
	healthRow.Name = "HealthRow"
	healthRow.LayoutOrder = 1
	healthRow.Size = UDim2.new(1, 0, 0, 36)
	healthRow.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	healthRow.BackgroundTransparency = 0.15
	healthRow.Parent = statsContainer

	local healthRowCorner = Instance.new("UICorner")
	healthRowCorner.CornerRadius = UDim.new(0.3, 0)
	healthRowCorner.Parent = healthRow

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "Label"
	healthLabel.BackgroundTransparency = 1
	healthLabel.Position = UDim2.fromScale(0.05, 0)
	healthLabel.Size = UDim2.fromScale(0.4, 1)
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.TextScaled = true
	healthLabel.TextColor3 = Color3.new(1, 1, 1)
	healthLabel.TextXAlignment = Enum.TextXAlignment.Left
	healthLabel.Text = "Health"
	healthLabel.Parent = healthRow

	local healthValue = Instance.new("TextLabel")
	healthValue.Name = "Value"
	healthValue.BackgroundTransparency = 1
	healthValue.Position = UDim2.fromScale(0.45, 0)
	healthValue.Size = UDim2.fromScale(0.5, 1)
	healthValue.Font = Enum.Font.GothamBold
	healthValue.TextScaled = true
	healthValue.TextColor3 = Color3.new(1, 1, 1)
	healthValue.TextXAlignment = Enum.TextXAlignment.Right
	healthValue.Parent = healthRow

	-- LevelRow -- mirrors LevelingBar's own composition (a small bar with the level label overlaid),
	-- just larger, for visual consistency with the HUD bar.
	local levelRow = Instance.new("CanvasGroup")
	levelRow.Name = "LevelRow"
	levelRow.LayoutOrder = 2
	levelRow.Size = UDim2.new(1, 0, 0, 36)
	levelRow.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
	levelRow.BackgroundTransparency = 0
	levelRow.Parent = statsContainer

	local levelRowCorner = Instance.new("UICorner")
	levelRowCorner.CornerRadius = UDim.new(0.3, 0)
	levelRowCorner.Parent = levelRow

	local levelFill = Instance.new("Frame")
	levelFill.Name = "Fill"
	levelFill.AnchorPoint = Vector2.new(0, 0.5)
	levelFill.Position = UDim2.fromScale(0, 0.5)
	levelFill.Size = UDim2.fromScale(0, 1)
	levelFill.BackgroundColor3 = MovementConstants.HUD_FILL_COLOR
	levelFill.BorderSizePixel = 0
	levelFill.Parent = levelRow

	local levelFillCorner = Instance.new("UICorner")
	levelFillCorner.CornerRadius = UDim.new(0.3, 0)
	levelFillCorner.Parent = levelFill

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 1
	levelLabel.Size = UDim2.fromScale(1, 1)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextScaled = true
	levelLabel.TextColor3 = Color3.new(1, 1, 1)
	levelLabel.Text = "Lv. 1"
	levelLabel.Parent = levelRow

	card.Parent = templates
end

print("Player card templates ready.")
```

### Verify
- `StarterGui."Custom Inventory"` now has a `playerCardButton` sibling to `openButton`, visually similar, stacked directly beneath it.
- `ReplicatedStorage.GuiTemplates.PlayerCard` exists with `CloseButton`, `Thumbnail`, `PlayerName`, `StatsContainer.HealthRow.Value`, `StatsContainer.LevelRow.Fill`, `StatsContainer.LevelRow.LevelLabel`.
- Only run this once; re-running duplicates the button and card (delete the old ones first if you need to re-run it).

---

## Part 2 — `PlayerCardController` (client)

**New `StarterPlayer.StarterPlayerScripts.PlayerCardController`** (LocalScript):
```lua
-- Opens a player card: your own (top-right button) or another player's (the /view <username> chat
-- command). Reads only data that already replicates to every client by default -- Player attributes
-- (Level/XP/NextLevelXP, set by LevelingService) and Humanoid properties (Health/MaxHealth) -- so
-- viewing someone else needs no RemoteEvent or server script.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local gui = Instance.new("ScreenGui")
gui.Name = "PlayerCardGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local currentCard: Frame? = nil

local function closeCard()
	if currentCard then
		currentCard:Destroy()
		currentCard = nil
	end
end

local function openCard(target: Player)
	closeCard()

	local card = guiTemplates:WaitForChild("PlayerCard"):Clone()
	card.Parent = gui
	currentCard = card

	local nameLabel = card:WaitForChild("PlayerName") :: TextLabel
	local thumbnail = card:WaitForChild("Thumbnail") :: ImageLabel
	local statsContainer = card:WaitForChild("StatsContainer")
	local healthValue = statsContainer:WaitForChild("HealthRow"):WaitForChild("Value") :: TextLabel
	local levelRow = statsContainer:WaitForChild("LevelRow")
	local levelLabel = levelRow:WaitForChild("LevelLabel") :: TextLabel
	local levelFill = levelRow:WaitForChild("Fill") :: Frame
	local closeButton = card:WaitForChild("CloseButton") :: TextButton

	nameLabel.Text = target.DisplayName
	closeButton.MouseButton1Click:Connect(closeCard)

	local function refreshHealth()
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			healthValue.Text = `{math.floor(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
		else
			healthValue.Text = "—"
		end
	end

	local function refreshLevel()
		local level = (target:GetAttribute("Level") :: number?) or 1
		local xp = (target:GetAttribute("XP") :: number?) or 0
		local nextLevelXp = (target:GetAttribute("NextLevelXP") :: number?) or 0

		levelLabel.Text = `Lv. {level}`
		local fraction = if nextLevelXp > 0 then math.clamp(xp / nextLevelXp, 0, 1) else 1
		levelFill.Size = UDim2.fromScale(fraction, 1)
	end

	refreshHealth()
	refreshLevel()

	local connections = {}
	table.insert(connections, target:GetAttributeChangedSignal("Level"):Connect(refreshLevel))
	table.insert(connections, target:GetAttributeChangedSignal("XP"):Connect(refreshLevel))
	table.insert(connections, target:GetAttributeChangedSignal("NextLevelXP"):Connect(refreshLevel))
	table.insert(
		connections,
		target.CharacterAdded:Connect(function()
			task.wait(0.1)
			refreshHealth()
		end)
	)

	-- Health has no single changed-signal to hook once: the Humanoid instance itself is replaced on
	-- every respawn, and Health changes continuously in combat. Polling while the card is open is
	-- simpler and more robust than chasing every Humanoid instance's Changed signal individually.
	task.spawn(function()
		while card.Parent do
			refreshHealth()
			task.wait(0.5)
		end
	end)

	card.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	task.spawn(function()
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			target.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.X180Y180
		)
		if ok and card.Parent then
			thumbnail.Image = image
		end
	end)
end

-- ============================================
-- OWN CARD: top-right button
-- ============================================
local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local cardButton = inventoryGui:WaitForChild("playerCardButton") :: ImageButton
cardButton.MouseButton1Click:Connect(function()
	if currentCard then
		closeCard()
	else
		openCard(player)
	end
end)

-- ============================================
-- OTHER PLAYERS' CARDS: /view <username>
-- ============================================
local function findPlayerByName(query: string): Player?
	query = query:lower()
	local prefixMatch: Player? = nil
	for _, candidate in Players:GetPlayers() do
		local name = candidate.Name:lower()
		if name == query then
			return candidate
		end
		if not prefixMatch and name:sub(1, #query) == query then
			prefixMatch = candidate
		end
	end
	return prefixMatch
end

-- TextChatCommand is the modern, correct way to register a slash command: unlike parsing
-- Player.Chatted by hand, the command text is NOT shown as a public chat message. This assumes the
-- default modern chat (TextChatService) is active, which it is unless this game explicitly opted
-- into legacy chat -- nothing in this codebase does, confirmed by grep. If Play-mode verification
-- shows /view doing nothing AND typing it sends a literal chat message, this game is on legacy
-- chat instead; swap this block for a Players.LocalPlayer.Chatted connection.
local viewCommand = Instance.new("TextChatCommand")
viewCommand.Name = "ViewPlayerCard"
viewCommand.PrimaryAlias = "/view"
viewCommand.Parent = TextChatService

viewCommand.Triggered:Connect(function(_, unfilteredText: string)
	local username = unfilteredText:match("^/view%s+(%S+)$")
	if not username then
		return
	end
	local target = findPlayerByName(username)
	if target then
		openCard(target)
	end
end)
```

### Verify
- Click the new top-right button: your own card opens (your name, your headshot, your current Health/MaxHealth, your Level and XP fill). Click again (or the close button): it closes.
- With a second player in the session, type `/view <their username>` (exact and a partial-prefix match, e.g. `/view Luq` matching `Luqpic`): their card opens instead, showing **their** stats, not yours — and the `/view ...` text does not appear as a public chat message.
- `/view` with a nonexistent username: nothing happens, no error in the output.
- Open a card, then watch the target take damage or level up while it's open: Health and the Level/XP fill update live without closing/reopening the card.
- Open a card for a player who is mid-respawn (no Character yet): Health shows `—` instead of erroring, and updates once they respawn.
- Close a card, confirm no leftover connections keep running afterward (open/close several times in a row and check the output for errors or growing lag).

## Verification checklist

- [ ] `playerCardButton` is a real static sibling to `openButton`, not cloned; `PlayerCard` is a template, cloned fresh each open.
- [ ] Own card opens/closes via the button; shows correct name, headshot, Health/MaxHealth, Level, and XP progress.
- [ ] `/view <username>` opens another player's card with their data, without posting a visible chat message; unmatched usernames no-op safely.
- [ ] Card content updates live while open (health changes, level-ups) for whichever player it's currently showing.
- [ ] No errors or connection leaks from repeatedly opening/closing cards for yourself and others.
