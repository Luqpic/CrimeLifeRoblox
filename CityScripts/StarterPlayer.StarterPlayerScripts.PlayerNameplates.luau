-- Name + health above every player, in the game's own design language, and a prompt to open another
-- player's card.
--
-- Roblox's default overhead name and health bar are suppressed per character rather than globally:
-- Humanoid.DisplayDistanceType = None hides both, and it is a per-Humanoid property, so it has to be
-- reapplied on every respawn.
--
-- Everything here is CLIENT-ONLY. The billboards and prompts are built locally on replicated
-- characters, which is all that is needed for a local readout and a local interaction, and it keeps
-- the server out of a purely cosmetic system entirely.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelingConstants = require(ReplicatedStorage:WaitForChild("Leveling"):WaitForChild("Constants"))
local openPlayerCard = ReplicatedStorage:WaitForChild("UI"):WaitForChild("OpenPlayerCard")
local Panels = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Panels"))

-- Every prompt this script has created, so they can all be stood down while a panel is open.
-- Weak keys: a prompt destroyed with its character must not be held alive by this table.
local activePrompts: { [ProximityPrompt]: true } = setmetatable({}, { __mode = "k" }) :: any
local promptsAllowed = true

-- Admin invisible (2026-11-20): a character the server marks AdminInvisible shows no plate and no prompt to anyone.
local function isHidden(character: Instance?): boolean
	return character ~= nil and character:GetAttribute("AdminInvisible") == true
end

Panels.onChanged(function(openPanel: string?)
	promptsAllowed = openPanel == nil
	for prompt in activePrompts do
		if prompt.Parent then
			prompt.Enabled = promptsAllowed and not isHidden(prompt.Parent.Parent)
		end
	end
end)

local localPlayer = Players.LocalPlayer

-- Figma "EnemyGUI - Billboard" -- the same treatment a character's overhead readout gets there,
-- reused so players and NPCs read as one system.
local PANEL_DEEP = Color3.fromHex("0E1016")
local LINE = Color3.fromHex("2A2F3C")
local DANGER = Color3.fromHex("FF4B4B")
local WHITE = Color3.fromHex("FFFFFF")
local DISPLAY = Font.fromName("Montserrat", Enum.FontWeight.Heavy)
local BODY_STRONG = Font.fromName("RobotoCondensed", Enum.FontWeight.SemiBold)

local PROMPT_DISTANCE = 12

-- BillboardGui.Size: the SCALE component is studs (world space, shrinks with distance), the OFFSET
-- component is screen pixels (constant on screen, so it grows relative to the character as you back
-- away). The first version used fromOffset(250, 64) and ballooned at range. These are the same studs
-- the EnemyGUI template uses, so player and NPC plates match at every distance.
-- 1.6 studs tall, not EnemyGUI's 1.2: the extra 0.4 is the rank line above the name. The name and the
-- health bar keep EnemyGUI's stud sizes exactly (0.48 and 0.264 studs), expressed as fractions of the
-- taller plate, and the plate sits 0.2 studs higher so the bar stays where it was over the head.
local PLATE_SIZE = UDim2.fromScale(5, 1.6)
local PLATE_STUDS_OFFSET = Vector3.new(0, 2.3, 0)
local PLATE_MAX_DISTANCE = 50

local function buildNameplate(character: Model, humanoid: Humanoid, player: Player)
	local displayName = player.DisplayName
	-- Waited for, not looked up: CharacterAdded can fire before the Head has arrived (and a streamed
	-- remote character's parts can land later still), and a missed lookup silently built no plate while
	-- the View Card prompt -- which already waits for its root part -- still appeared.
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end

	local existing = head:FindFirstChild("PlayerNameplate")
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerNameplate"
	billboard.Size = PLATE_SIZE
	billboard.StudsOffset = PLATE_STUDS_OFFSET
	billboard.LightInfluence = 0
	-- Matching EnemyGUI: not drawn through walls, and gone past 50 studs.
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = PLATE_MAX_DISTANCE
	billboard.Parent = head

	-- Criminal rank, right above the name, in its tier's colour (Leveling.Constants.RANKS).
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "Rank"
	rankLabel.Size = UDim2.fromScale(1, 0.18)
	rankLabel.BackgroundTransparency = 1
	rankLabel.FontFace = BODY_STRONG
	rankLabel.TextScaled = true
	rankLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	rankLabel.TextStrokeTransparency = 0.1
	rankLabel.Parent = billboard

	local function refreshRank()
		local rank = LevelingConstants.rankForLevel(player:GetAttribute("Level") or 1)
		rankLabel.Text = string.upper(rank.title)
		rankLabel.TextColor3 = rank.color
	end
	refreshRank()
	-- On the Player, which outlives this character: disconnected with the plate, or every respawn
	-- would leave one more listener writing to a destroyed label.
	local rankConnection = player:GetAttributeChangedSignal("Level"):Connect(refreshRank)
	billboard.Destroying:Connect(function()
		rankConnection:Disconnect()
	end)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DisplayName"
	nameLabel.Position = UDim2.fromScale(0, 0.2)
	nameLabel.Size = UDim2.fromScale(1, 0.3)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.upper(displayName)
	nameLabel.FontFace = DISPLAY
	nameLabel.TextColor3 = WHITE
	nameLabel.TextScaled = true
	-- The Figma plate carries a hard drop shadow; a text stroke is the closest native equivalent and
	-- is what keeps the name readable against a bright skybox.
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.1
	nameLabel.Parent = billboard

	local track = Instance.new("Frame")
	track.Name = "HealthTrack"
	track.Size = UDim2.fromScale(0.84, 0.165)
	track.Position = UDim2.fromScale(0.08, 0.575)
	track.BackgroundColor3 = PANEL_DEEP
	track.BorderSizePixel = 0
	track.Parent = billboard
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 999)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = LINE
	trackStroke.Thickness = 1
	trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trackStroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = DANGER
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 999)
	fillCorner.Parent = fill

	-- Health icon inside the bar's left end, white over the red fill, opposite the right-aligned number.
	local healthIcon = Instance.new("ImageLabel")
	healthIcon.Name = "HealthIcon"
	healthIcon.BackgroundTransparency = 1
	healthIcon.Image = LevelingConstants.HEALTH_ICON_ID
	healthIcon.ImageColor3 = WHITE
	healthIcon.ScaleType = Enum.ScaleType.Fit
	healthIcon.AnchorPoint = Vector2.new(0, 0.5)
	healthIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	healthIcon.Size = UDim2.fromScale(0.75, 0.75)
	healthIcon.Position = UDim2.fromScale(0.02, 0.5)
	healthIcon.ZIndex = 3
	healthIcon.Parent = track

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthNum"
	healthLabel.Size = UDim2.new(1, -10, 1, 0)
	healthLabel.BackgroundTransparency = 1
	healthLabel.FontFace = BODY_STRONG
	healthLabel.TextColor3 = WHITE
	healthLabel.TextScaled = true
	healthLabel.TextXAlignment = Enum.TextXAlignment.Right
	healthLabel.ZIndex = 3
	healthLabel.Parent = track

	local function refresh()
		local maxHealth = humanoid.MaxHealth
		local fraction = if maxHealth > 0 then math.clamp(humanoid.Health / maxHealth, 0, 1) else 0
		fill.Visible = fraction > 0.001
		fill.Size = UDim2.fromScale(fraction, 1)
		healthLabel.Text = tostring(math.floor(humanoid.Health))
	end

	refresh()
	-- Both signals: Health alone misses a MaxHealth change from a level-up, which would leave the
	-- bar showing a stale fraction until the next point of damage.
	humanoid.HealthChanged:Connect(refresh)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	-- Suppress Roblox's built-in overhead name and health bar. Per-Humanoid, so this must run for
	-- every character, not once at startup.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if player == localPlayer then
		-- No plate over your OWN head: it sits in the middle of the screen in third person and gets
		-- in the way of the thing you are aiming at. Your health is on the player card, and the
		-- suppression above still applies so Roblox's default does not come back either.
		-- No prompt either -- the HUD button already opens your own card.
		return
	end

	buildNameplate(character, humanoid, player)

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local existing = root:FindFirstChild("ViewCardPrompt")
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ViewCardPrompt"
	prompt.ActionText = "View Card"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	-- A character can spawn while a card is already open, so the new prompt starts in whatever state
	-- the panel system is currently in rather than assuming it is free to show.
	prompt.Enabled = promptsAllowed
	prompt.Parent = root
	activePrompts[prompt] = true

	prompt.Triggered:Connect(function()
		-- Guarded: the target can leave between the prompt showing and the press landing.
		if player.Parent then
			openPlayerCard:Fire(player)
		end
	end)

	local function applyHidden()
		local hidden = isHidden(character)
		local head = character:FindFirstChild("Head")
		local plate = head and head:FindFirstChild("PlayerNameplate")
		if plate then
			plate.Enabled = not hidden
		end
		prompt.Enabled = promptsAllowed and not hidden
	end
	applyHidden()
	character:GetAttributeChangedSignal("AdminInvisible"):Connect(applyHidden)
end

local function watch(player: Player)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
