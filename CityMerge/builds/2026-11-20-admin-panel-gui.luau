-- Builds ServerStorage.AdminPanel (2026-11-20, admin-design.md "Look"). Re-runnable in Edit (execute_luau or the
-- command bar): rebuilds AdminPanelGui and AdminHudGui and keeps the scripts already inside AdminPanelGui
-- (AdminPanelController, Config), which are pushed from CityScripts/.
-- Admin.AdminService clones both ScreenGuis into the PlayerGui of a player with a role, and only theirs.
-- Every control carries an Action attribute (the server action it calls); the controller hides the ones a
-- helper may not use (OwnerOnly marks a control whose action a helper has, but not at that setting).
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.SharedSystems.UITheme).Color
local DISPLAY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local BODY = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.SemiBold)

local function make(class: string, props, parent: Instance?)
	local instance = Instance.new(class)
	for key, value in props do
		if key == "Attributes" then
			for name, attribute in value do
				instance:SetAttribute(name, attribute)
			end
		else
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function round(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function outline(parent)
	make("UIStroke", { Color = C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function at(x, y, w, h)
	return UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
end

local function label(parent, name, text, x, y, w, h, size, font, color, align)
	local position, sizeOf = at(x, y, w, h)
	return make("TextLabel", {
		Name = name, Text = text, Position = position, Size = sizeOf, BackgroundTransparency = 1,
		FontFace = font or BODY, TextSize = size or 15, TextColor3 = color or C.white,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function button(parent, name, text, x, y, w, h, action, attributes)
	local position, sizeOf = at(x, y, w, h)
	local attrs = attributes or {}
	attrs.Action = action
	local b = make("TextButton", {
		Name = name, Text = text, Position = position, Size = sizeOf, BackgroundColor3 = C.raised,
		AutoButtonColor = false, FontFace = BOLD, TextSize = 15, TextColor3 = C.white, Attributes = attrs,
	}, parent)
	round(b, 10)
	outline(b)
	return b
end

local function box(parent, name, placeholder, default, x, y, w, h, center)
	local position, sizeOf = at(x, y, w, h)
	local b = make("TextBox", {
		Name = name, Text = default or "", PlaceholderText = placeholder or "", ClearTextOnFocus = false,
		Position = position, Size = sizeOf, BackgroundColor3 = C.inset, TextColor3 = C.white,
		PlaceholderColor3 = C.muted, FontFace = BODY, TextSize = 15,
		TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
	}, parent)
	round(b, 8)
	outline(b)
	if not center then
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	end
	return b
end

-- [-] [value] [+] at x; names Minus / Value / Plus
local function stepper(parent, x, y, default, boxWidth)
	boxWidth = boxWidth or 64
	button(parent, "Minus", "-", x, y, 32, 32)
	box(parent, "Value", "", default, x + 36, y, boxWidth, 32, true)
	button(parent, "Plus", "+", x + 40 + boxWidth, y, 32, 32)
	return x + 76 + boxWidth
end

local function row(parent, name, order, height, caption, action)
	local r = make("Frame", {
		Name = name, LayoutOrder = order, Size = UDim2.fromOffset(392, height), BackgroundTransparency = 1,
		Attributes = { Action = action },
	}, parent)
	if caption then
		label(r, "Caption", caption, 0, 0, 96, 32, 14, BOLD, C.muted)
	end
	return r
end

local function scroller(parent, name, x, y, w, h, layout)
	local position, sizeOf = at(x, y, w, h)
	local s = make("ScrollingFrame", {
		Name = name, Position = position, Size = sizeOf, BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.muted, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	if layout == "list" then
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	elseif layout then
		make("UIGridLayout", { CellSize = layout, CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
	end
	return s
end

local function grid(parent, name, order, height, cell)
	local g = make("Frame", { Name = name, LayoutOrder = order, Size = UDim2.fromOffset(392, height), BackgroundTransparency = 1 }, parent)
	make("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, g)
	return g
end

-- ---------------------------------------------------------------- the folder, keeping the scripts

local folder = ServerStorage:FindFirstChild("AdminPanel") or make("Folder", { Name = "AdminPanel" }, ServerStorage)
local kept = {}
local old = folder:FindFirstChild("AdminPanelGui")
if old then
	for _, child in old:GetChildren() do
		if child:IsA("LuaSourceContainer") then
			child.Parent = nil
			table.insert(kept, child)
		end
	end
	old:Destroy()
end
local oldHud = folder:FindFirstChild("AdminHudGui")
if oldHud then
	oldHud:Destroy()
end

-- ---------------------------------------------------------------- AdminPanelGui

local gui = make("ScreenGui", {
	Name = "AdminPanelGui", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 25,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, IgnoreGuiInset = false,
}, nil)
make("UIScale", { Name = "FitScale" }, gui) -- the controller fits the panel into the safe area (max 1)

local panel = make("Frame", {
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 480), BackgroundColor3 = C.panel, Visible = false,
}, gui)
round(panel, 16)
outline(panel)
-- Modal frees a locked mouse (first person, shift lock) while the panel is shown.
make("TextButton", { Name = "Modal", Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0) }, panel)

local header = make("Frame", { Name = "Header", Size = UDim2.fromOffset(760, 44), BackgroundTransparency = 1 }, panel)
label(header, "Title", "ADMIN", 20, 0, 90, 44, 24, DISPLAY, C.accent)
local chip = label(header, "RoleChip", "OWNER", 112, 12, 72, 22, 13, BOLD, C.accent, Enum.TextXAlignment.Center)
chip.BackgroundTransparency = 0
chip.BackgroundColor3 = C.raised
round(chip, 11)
outline(chip)
make("ImageButton", {
	Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(36, 36),
	BackgroundTransparency = 1,
}, header) -- image and size from UI.Effects (CLOSE_IMAGE, CLOSE_SIZE) at run time
make("Frame", { Name = "Rule", Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(760, 1), BackgroundColor3 = C.line, BorderSizePixel = 0 }, panel)

local rail = make("Frame", { Name = "Rail", Position = UDim2.fromOffset(0, 45), Size = UDim2.fromOffset(132, 435), BackgroundTransparency = 1 }, panel)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, rail)
make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, rail)
for order, name in { "PLAYERS", "HEISTS", "ME", "SERVER" } do
	local tab = make("TextButton", {
		Name = name, LayoutOrder = order, Size = UDim2.fromOffset(116, 40), BackgroundColor3 = C.raised,
		AutoButtonColor = false, Text = name, FontFace = BOLD, TextSize = 16, TextColor3 = C.white,
	}, rail)
	round(tab, 10)
	local bar = make("Frame", {
		Name = "AccentBar", Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(4, 24), BackgroundColor3 = C.accent,
		BorderSizePixel = 0, Visible = false,
	}, tab)
	round(bar, 2)
end

local pages = make("Frame", { Name = "Pages", Position = UDim2.fromOffset(140, 52), Size = UDim2.fromOffset(608, 396), BackgroundTransparency = 1 }, panel)
label(panel, "Status", "", 140, 452, 608, 22, 15, BODY, C.muted).TextTruncate = Enum.TextTruncate.AtEnd

local function page(name)
	return make("Frame", { Name = name, Size = UDim2.fromOffset(608, 396), BackgroundTransparency = 1, Visible = false }, pages)
end

-- ---------------------------------------------------------------- PLAYERS

local players = page("PLAYERS")
box(players, "Search", "Search players", "", 0, 0, 200, 32)
scroller(players, "List", 0, 40, 200, 356, "list")
local card = make("Frame", { Name = "Card", Position = UDim2.fromOffset(208, 0), Size = UDim2.fromOffset(400, 396), BackgroundTransparency = 1 }, players)
label(card, "Title", "Pick a player", 0, 0, 400, 24, 20, DISPLAY, C.white)
label(card, "Sub", "", 0, 24, 400, 16, 13, BODY, C.muted)
local chips = make("Frame", { Name = "Chips", Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(400, 44), BackgroundTransparency = 1 }, card)
for i, name in { "Level", "Cash", "Spraypaint", "Stars" } do
	local c = make("Frame", { Name = name, Position = UDim2.fromOffset((i - 1) * 100, 0), Size = UDim2.fromOffset(94, 44), BackgroundColor3 = C.raised }, chips)
	round(c, 10)
	outline(c)
	label(c, "Caption", string.upper(name), 0, 4, 94, 14, 12, BOLD, C.muted, Enum.TextXAlignment.Center)
	label(c, "Value", "", 0, 18, 94, 22, 17, BOLD, C.white, Enum.TextXAlignment.Center)
end
local actions = scroller(card, "Actions", 0, 96, 400, 300, "list")
local r = row(actions, "LevelRow", 1, 32, "LEVEL", "setLevel")
button(r, "Set", "SET", stepper(r, 100, 0, "1", 72) + 4, 0, 96, 32, "setLevel")
r = row(actions, "CashRow", 2, 32, "CASH", "addCash")
local x = stepper(r, 100, 0, "1000", 72)
button(r, "Give", "GIVE", x + 4, 0, 58, 32, "addCash")
button(r, "Take", "TAKE", x + 66, 0, 58, 32, "addCash")
r = row(actions, "SprayRow", 3, 32, "SPRAYPAINT", "addSpraypaint")
x = stepper(r, 100, 0, "100", 72)
button(r, "Give", "GIVE", x + 4, 0, 58, 32, "addSpraypaint")
button(r, "Take", "TAKE", x + 66, 0, 58, 32, "addSpraypaint")
r = row(actions, "WeaponRow", 4, 32, "WEAPON", "giveWeapon")
button(r, "Open", "GIVE WEAPON", 100, 0, 288, 32, "giveWeapon")
local quick = grid(actions, "Quick", 5, 70, UDim2.fromOffset(124, 32))
for order, spec in { { "Heal", "HEAL", "heal" }, { "Respawn", "RESPAWN", "respawn" }, { "Freeze", "FREEZE", "freeze" },
	{ "Unfreeze", "UNFREEZE", "unfreeze" }, { "Goto", "GO TO", "goto" }, { "Bring", "BRING", "bring" } } do
	button(quick, spec[1], spec[2], 0, 0, 124, 32, spec[3]).LayoutOrder = order
end
r = row(actions, "ReasonRow", 6, 32, "REASON", "kick")
box(r, "Value", "Kick or ban reason (optional)", "", 100, 0, 288, 32)
local mod = grid(actions, "Moderation", 7, 70, UDim2.fromOffset(124, 32))
for order, spec in { { "Kick", "KICK", "kick" }, { "Ban1h", "BAN 1 HOUR", "ban", "1h" }, { "Ban1d", "BAN 1 DAY", "ban", "1d" },
	{ "Ban7d", "BAN 7 DAYS", "ban", "7d", true }, { "BanForever", "BAN FOREVER", "ban", "forever", true } } do
	local b = button(mod, spec[1], spec[2], 0, 0, 124, 32, spec[3], { Duration = spec[4], OwnerOnly = spec[5] })
	b.LayoutOrder = order
	b.TextColor3 = C.danger
end
local weapons = scroller(card, "WeaponList", 0, 96, 400, 300, UDim2.fromOffset(127, 30))
weapons.BackgroundTransparency = 0
weapons.BackgroundColor3 = C.panel
weapons.Visible = false
weapons.ZIndex = 5

-- ---------------------------------------------------------------- HEISTS

local heists = page("HEISTS")
local cards = make("Frame", { Name = "Cards", Size = UDim2.fromOffset(608, 190), BackgroundTransparency = 1 }, heists)
make("UIGridLayout", { CellSize = UDim2.fromOffset(301, 92), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, cards)
for order, spec in { { "Bank", "THE BANK" }, { "SlowFoods", "SLOW FOODS" }, { "Gas2Go", "GAS STATION" }, { "NewsStation", "NEWS STATION" } } do
	local c = make("Frame", { Name = spec[1], LayoutOrder = order, BackgroundColor3 = C.raised }, cards)
	round(c, 12)
	outline(c)
	label(c, "Title", spec[2], 12, 6, 280, 22, 17, DISPLAY, C.white)
	label(c, "State", "", 12, 28, 280, 20, 14, BODY, C.muted)
	button(c, "Reset", "RESET", 12, 54, 96, 30, "resetCooldown")
	button(c, "Go", "GO", 114, 54, 96, 30, "teleportTo")
end
local places = make("Frame", { Name = "Places", Position = UDim2.fromOffset(0, 198), Size = UDim2.fromOffset(608, 32), BackgroundTransparency = 1 }, heists)
label(places, "Caption", "GO TO", 0, 0, 96, 32, 14, BOLD, C.muted)
button(places, "Supplier", "ILLEGAL SUPPLIER", 100, 0, 160, 32, "teleportTo")
button(places, "Spawn", "SPAWN", 266, 0, 96, 32, "teleportTo")
button(places, "ResetAll", "RESET ALL", 368, 0, 120, 32, "resetCooldown")
local stars = make("Frame", { Name = "Stars", Position = UDim2.fromOffset(0, 236), Size = UDim2.fromOffset(608, 32), BackgroundTransparency = 1, Attributes = { Action = "setStars" } }, heists)
label(stars, "Caption", "STARS", 0, 0, 96, 32, 14, BOLD, C.muted)
for n = 0, 5 do
	button(stars, "Star" .. n, tostring(n), 100 + n * 42, 0, 38, 32, "setStars", { Stars = n })
end
button(stars, "ClearAll", "CLEAR ALL STARS", 356, 0, 150, 32, "clearAllStars")
local police = make("Frame", { Name = "Police", Position = UDim2.fromOffset(0, 274), Size = UDim2.fromOffset(608, 32), BackgroundTransparency = 1, Attributes = { Action = "spawnPolice" } }, heists)
label(police, "Caption", "POLICE", 0, 0, 96, 32, 14, BOLD, C.muted)
button(police, "Spawn", "SPAWN POLICE", stepper(police, 100, 0, "2", 44) + 4, 0, 140, 32, "spawnPolice")
local enemies = make("Frame", { Name = "Enemies", Position = UDim2.fromOffset(0, 312), Size = UDim2.fromOffset(608, 32), BackgroundTransparency = 1, Attributes = { Action = "spawnEnemy" } }, heists)
label(enemies, "Caption", "ENEMIES", 0, 0, 96, 32, 14, BOLD, C.muted)
button(enemies, "Type", "THUG", 100, 0, 120, 32, "spawnEnemy")
button(enemies, "Spawn", "SPAWN", stepper(enemies, 226, 0, "2", 44) + 4, 0, 96, 32, "spawnEnemy")
local clear = make("Frame", { Name = "Clear", Position = UDim2.fromOffset(0, 350), Size = UDim2.fromOffset(608, 32), BackgroundTransparency = 1, Attributes = { Action = "clearEnemies" } }, heists)
label(clear, "Caption", "CLEAR", 0, 0, 96, 32, 14, BOLD, C.muted)
button(clear, "Mine", "CLEAR MINE", 100, 0, 150, 32, "clearEnemies", { Scope = "mine" })
button(clear, "All", "CLEAR ALL, POLICE TOO", 256, 0, 200, 32, "clearEnemies", { Scope = "all" })

-- ---------------------------------------------------------------- ME

local me = page("ME")
for i, spec in { { "God", "GOD", "god" }, { "Invisible", "INVISIBLE", "invisible" }, { "Fly", "FLY", "fly" }, { "Noclip", "NOCLIP", "noclip" } } do
	button(me, spec[1], spec[2], (i - 1) * 152, 0, 144, 44, spec[3]).TextSize = 17
end
local speed = make("Frame", { Name = "Speed", Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(608, 32), BackgroundTransparency = 1, Attributes = { Action = "walkSpeed" } }, me)
label(speed, "Caption", "WALK SPEED", 0, 0, 96, 32, 14, BOLD, C.muted)
x = stepper(speed, 100, 0, "40", 56)
button(speed, "Set", "SET", x + 4, 0, 90, 32, "walkSpeed")
button(speed, "Normal", "NORMAL", x + 100, 0, 90, 32, "walkSpeed")
label(me, "FlyHint", "Fly: WASD, Space up, Ctrl down", 340, 100, 268, 32, 13, BODY, C.muted, Enum.TextXAlignment.Right).Visible = false
label(me, "SpectateCaption", "SPECTATE", 0, 100, 96, 32, 14, BOLD, C.muted)
button(me, "Stop", "STOP", 100, 100, 96, 32, "spectate")
scroller(me, "SpectateList", 0, 140, 608, 256, UDim2.fromOffset(196, 32))

-- ---------------------------------------------------------------- SERVER

local server = page("SERVER")
box(server, "Message", "Announcement to everyone (140 characters)", "", 0, 0, 500, 32):SetAttribute("Action", "announce")
button(server, "Send", "SEND", 508, 0, 100, 32, "announce")
local statsBox = label(server, "Stats", "", 0, 44, 608, 48, 15, BODY, C.white)
statsBox.BackgroundTransparency = 0
statsBox.BackgroundColor3 = C.raised
round(statsBox, 10)
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, statsBox)
label(server, "LogCaption", "ACTION LOG (NEWEST FIRST)", 0, 100, 300, 20, 14, BOLD, C.muted)
local log = scroller(server, "Log", 0, 124, 608, 272, "list")
log:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 2)

-- ---------------------------------------------------------------- templates the controller clones

local templates = make("Frame", { Name = "Templates", Visible = false, BackgroundTransparency = 1 }, gui)
local playerRow = make("TextButton", {
	Name = "PlayerRow", Size = UDim2.fromOffset(192, 44), BackgroundColor3 = C.raised, AutoButtonColor = false, Text = "",
}, templates)
round(playerRow, 10)
outline(playerRow)
label(playerRow, "Title", "", 10, 4, 176, 20, 15, BOLD, C.white)
label(playerRow, "Info", "", 10, 22, 176, 18, 13, BODY, C.muted)
local listButton = make("TextButton", {
	Name = "ListButton", Size = UDim2.fromOffset(196, 32), BackgroundColor3 = C.raised, AutoButtonColor = false,
	Text = "", FontFace = BOLD, TextSize = 14, TextColor3 = C.white, TextWrapped = true,
}, templates)
round(listButton, 8)
outline(listButton)
make("TextLabel", {
	Name = "LogRow", Size = UDim2.fromOffset(600, 20), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	FontFace = BODY, TextSize = 14, TextColor3 = C.white, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, templates)

for _, script in kept do
	script.Parent = gui
end
gui.Parent = folder

-- ---------------------------------------------------------------- AdminHudGui: the HUD button, and fly UP / DOWN

local hud = make("ScreenGui", {
	Name = "AdminHudGui", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 0,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, IgnoreGuiInset = false,
}, nil)
make("UIScale", { Name = "ClusterScale" }, hud) -- the controller copies Custom Inventory's ClusterScale
-- One more slot in the Custom Inventory column: same size, corner, stroke and 88 px step (-371 is weaponaryButton).
local adminButton = make("ImageButton", {
	Name = "AdminButton", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 27, 1, -459),
	Size = UDim2.fromOffset(76, 76), BackgroundColor3 = C.panel, AutoButtonColor = false,
}, hud)
round(adminButton, 18)
outline(adminButton)
label(adminButton, "Label", "ADMIN", 0, 0, 76, 76, 15, DISPLAY, C.accent, Enum.TextXAlignment.Center)
for i, spec in { { "FlyUp", "UP" }, { "FlyDown", "DOWN" } } do
	local b = make("TextButton", {
		Name = spec[1], AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 4 + (i - 1) * 60),
		Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.panel, BackgroundTransparency = 0.15, AutoButtonColor = false,
		Text = spec[2], FontFace = DISPLAY, TextSize = 15, TextColor3 = C.accent, Visible = false,
	}, hud)
	round(b, 28)
	outline(b)
end
hud.Parent = folder

return "built: " .. #gui:GetDescendants() .. " in AdminPanelGui, " .. #hud:GetDescendants() .. " in AdminHudGui, kept " .. #kept .. " scripts"
