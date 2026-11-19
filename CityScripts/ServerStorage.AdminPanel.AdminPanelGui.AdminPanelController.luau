-- Admin panel client (2026-11-20, admin-design.md "Look"). Lives in AdminPanelGui, which Admin.AdminService clones
-- from ServerStorage.AdminPanel into the PlayerGui of a player with a role, and nobody else. Every control calls
-- ReplicatedStorage.AdminRemote; the server re-checks the role, validates and logs, so hiding a helper's controls
-- here is tidiness, not security. F2 or the ADMIN HUD button (AdminHudGui) opens it.
-- Also the admin's own client tools: fly and noclip while the server sets AdminFly / AdminNoclip on the character
-- (the client owns its body), and spectate (camera subject) once the server accepts it.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local gui = script.Parent
local Config = require(gui:WaitForChild("Config"))
local UI = ReplicatedStorage:WaitForChild("UI")
local Panels = require(UI:WaitForChild("Panels"))
local Effects = require(UI:WaitForChild("Effects"))
local Sounds = require(UI:WaitForChild("Sounds"))
local MenuFovBlur = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MenuFovBlur"))
local C = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("UITheme")).Color

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("AdminHudGui", 10)
local remote = ReplicatedStorage:WaitForChild("AdminRemote", 30) :: RemoteFunction

local PANEL_NAME = "Admin"
local panel = gui.Panel
local pages = panel.Pages
local status = panel.Status
local templates = gui.Templates

-- ---------------------------------------------------------------- role and what a helper sees

local helperActions = {}
for name in string.gmatch(gui:GetAttribute("HelperActions") or "", "[^,]+") do
	helperActions[name] = true
end

local function role(): string?
	return player:GetAttribute("AdminRole")
end

local function applyRole()
	panel.Header.RoleChip.Text = string.upper(role() or "")
	local owner = role() == "owner"
	for _, item in panel:GetDescendants() do
		local action = item:IsA("GuiObject") and item:GetAttribute("Action")
		if action then
			item.Visible = owner or (helperActions[action] == true and not item:GetAttribute("OwnerOnly"))
		end
	end
end

-- ---------------------------------------------------------------- remote calls and the status line

local busy, lastReply = false, 0

-- One call at a time, spaced past the server's cooldown.
local function call(action: string, args: { [string]: any }?)
	while busy do
		task.wait()
	end
	busy = true
	local gap = Config.CALL_SPACING - (os.clock() - lastReply)
	if gap > 0 then
		task.wait(gap)
	end
	local ok, reply = pcall(remote.InvokeServer, remote, action, args or {})
	lastReply = os.clock()
	busy = false
	if not ok or type(reply) ~= "table" then
		return { ok = false, message = "No answer from the server." }
	end
	return reply
end

local function show(ok: boolean, message: string)
	status.Text = message
	status.TextColor3 = if ok then C.accent else C.danger
	if not ok then
		Sounds.denied():Play()
	end
end

local currentTab = "PLAYERS"
local refreshers: { [string]: () -> () } = {}

local function refresh()
	local refresher = refreshers[currentTab]
	if refresher then
		task.spawn(refresher)
	end
end

-- Calls, shows the reply at the panel's foot, refreshes the shown tab.
local function act(action: string, args: { [string]: any }?, okMessage: string?)
	local reply = call(action, args)
	show(reply.ok, if reply.ok and okMessage then okMessage else reply.message)
	refresh()
	return reply
end

-- Hover and click sounds plus the shared stroke hover (no size tween: most of these sit in layouts).
local function wire(button: GuiButton, fn: () -> ())
	Sounds.bind(button)
	Effects.bindStrokeHover(button)
	button.Activated:Connect(function()
		task.spawn(fn)
	end)
end

-- [-] [value] [+]: returns a reader for the number in the box.
local function stepper(rowFrame: Instance)
	local step, low, high = table.unpack(Config.STEPPERS[rowFrame.Name])
	local box = rowFrame:FindFirstChild("Value") :: TextBox
	local function nudge(delta: number)
		box.Text = tostring(math.clamp((tonumber(box.Text) or low) + delta, low, high))
	end
	wire(rowFrame:FindFirstChild("Minus") :: GuiButton, function() nudge(-step) end)
	wire(rowFrame:FindFirstChild("Plus") :: GuiButton, function() nudge(step) end)
	return function(): number?
		return tonumber(box.Text)
	end
end

-- A kick or ban fires on the second click within CONFIRM_SECONDS.
local armed: GuiButton? = nil
local function confirmed(button: GuiButton, label: string, what: string): boolean
	if armed == button then
		armed = nil
		button.Text = label
		return true
	end
	armed = button
	button.Text = "CLICK AGAIN"
	status.Text = `Click again to {what}.`
	status.TextColor3 = C.muted
	task.delay(Config.CONFIRM_SECONDS, function()
		if armed == button then
			armed = nil
			button.Text = label
		end
	end)
	return false
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ---------------------------------------------------------------- PLAYERS

local playersPage = pages.PLAYERS
local card = playersPage.Card
local actions = card.Actions
local weaponList = card.WeaponList
local rows = {}
local selectedId = player.UserId

local function selectedRow()
	for _, row in rows do
		if row.userId == selectedId then
			return row
		end
	end
	return nil
end

local function renderCard()
	local row = selectedRow()
	card.Title.Text = if row then row.displayName else "Pick a player"
	card.Sub.Text = if row
		then "@" .. row.name .. (if row.role ~= "" then ", " .. row.role else "") .. (if row.frozen then ", frozen" else "")
		else ""
	local chips = card.Chips
	chips.Level.Value.Text = if row then tostring(row.level) else ""
	chips.Cash.Value.Text = if row then tostring(row.cash) else ""
	chips.Spraypaint.Value.Text = if row then tostring(row.spraypaint) else ""
	chips.Stars.Value.Text = if row then tostring(row.stars) else ""
end

local function renderList()
	for _, child in playersPage.List:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local query = string.lower(playersPage.Search.Text)
	for order, row in rows do
		if query == "" or string.find(string.lower(row.name), query, 1, true) or string.find(string.lower(row.displayName), query, 1, true) then
			local item = templates.PlayerRow:Clone()
			item.Name = row.name
			item.LayoutOrder = order
			item.Title.Text = row.displayName
			item.Info.Text = `LV {row.level}, {row.stars} STARS`
			if row.userId == selectedId then
				item.UIStroke.Color = C.accent
			end
			Sounds.bind(item)
			item.Activated:Connect(function()
				selectedId = row.userId
				weaponList.Visible = false
				renderList()
				renderCard()
			end)
			item.Parent = playersPage.List
		end
	end
end

refreshers.PLAYERS = function()
	local reply = call("lookup")
	if reply.ok then
		rows = reply.data
		renderList()
		renderCard()
	end
end
playersPage.Search:GetPropertyChangedSignal("Text"):Connect(renderList)

local function target()
	return { target = selectedId }
end

local level = stepper(actions.LevelRow)
wire(actions.LevelRow.Set, function()
	act("setLevel", { target = selectedId, level = level() })
end)
for _, rowName in { "CashRow", "SprayRow" } do
	local amount = stepper(actions[rowName])
	local action = if rowName == "CashRow" then "addCash" else "addSpraypaint"
	wire(actions[rowName].Give, function()
		act(action, { target = selectedId, amount = amount() })
	end)
	wire(actions[rowName].Take, function()
		local n = amount()
		act(action, { target = selectedId, amount = n and -n })
	end)
end

local weaponsFilled = false
wire(actions.WeaponRow.Open, function()
	if not weaponsFilled then
		weaponsFilled = true
		local catalog = ReplicatedStorage:WaitForChild("Weapons"):WaitForChild("Catalog", 5)
		local names = {}
		for _, entry in if catalog then catalog:GetChildren() else {} do
			table.insert(names, entry.Name)
		end
		table.sort(names)
		for order, name in names do
			local item = templates.ListButton:Clone()
			item.Name = name
			item.LayoutOrder = order
			item.Text = string.upper(name)
			wire(item, function()
				weaponList.Visible = false
				act("giveWeapon", { target = selectedId, weapon = name })
			end)
			item.Parent = weaponList
		end
	end
	weaponList.Visible = not weaponList.Visible
end)

for name, action in { Heal = "heal", Respawn = "respawn", Freeze = "freeze", Unfreeze = "unfreeze", Goto = "goto", Bring = "bring" } do
	wire(actions.Quick[name], function()
		act(action, target())
	end)
end

local reason = actions.ReasonRow.Value :: TextBox
for _, button in actions.Moderation:GetChildren() do
	if button:IsA("TextButton") then
		local label = button.Text
		local duration = button:GetAttribute("Duration")
		wire(button, function()
			local row = selectedRow()
			local who = if row then row.displayName else "this player"
			if not confirmed(button, label, if duration then `ban {who} ({duration})` else `kick {who}`) then
				return
			end
			if duration then
				act("ban", { target = selectedId, duration = duration, reason = reason.Text })
			else
				act("kick", { target = selectedId, reason = reason.Text })
			end
		end)
	end
end

-- ---------------------------------------------------------------- HEISTS

local heistsPage = pages.HEISTS
local STATE_TEXT = { Idle = "READY", Active = "ROBBING, %s LEFT", Cooldown = "COOLDOWN, %s", Missing = "NOT LOADED" }
local STATE_COLOR = { Idle = C.accent, Active = C.danger, Cooldown = C.gold, Missing = C.muted }

refreshers.HEISTS = function()
	local reply = call("heistState")
	if not reply.ok then
		return
	end
	for _, row in reply.data do
		local heistCard = heistsPage.Cards:FindFirstChild(row.name)
		if heistCard then
			heistCard.State.Text = string.format(STATE_TEXT[row.state] or row.state, clock(row.seconds))
			heistCard.State.TextColor3 = STATE_COLOR[row.state] or C.muted
		end
	end
end

for _, heistCard in heistsPage.Cards:GetChildren() do
	if heistCard:IsA("Frame") then
		wire(heistCard.Reset, function()
			act("resetCooldown", { heist = heistCard.Name })
		end)
		wire(heistCard.Go, function()
			act("teleportTo", { place = heistCard.Name })
		end)
	end
end
wire(heistsPage.Places.Supplier, function()
	act("teleportTo", { place = "Illegal Supplier" })
end)
wire(heistsPage.Places.Spawn, function()
	act("teleportTo", { place = "Spawn" })
end)
wire(heistsPage.Places.ResetAll, function()
	act("resetCooldown", { heist = "All" })
end)
for n = 0, 5 do
	wire(heistsPage.Stars["Star" .. n], function()
		act("setStars", { target = selectedId, stars = n })
	end)
end
wire(heistsPage.Stars.ClearAll, function()
	act("clearAllStars")
end)
local policeCount = stepper(heistsPage.Police)
wire(heistsPage.Police.Spawn, function()
	act("spawnPolice", { count = policeCount() })
end)

local enemyTypes = string.split(gui:GetAttribute("EnemyTypes") or "", ",")
local enemyIndex = math.max(1, table.find(enemyTypes, "Thug") or 1)
local typeButton = heistsPage.Enemies.Type :: TextButton
typeButton.Text = string.upper(enemyTypes[enemyIndex] or "")
wire(typeButton, function()
	enemyIndex = enemyIndex % #enemyTypes + 1
	typeButton.Text = string.upper(enemyTypes[enemyIndex])
end)
local enemyCount = stepper(heistsPage.Enemies)
wire(heistsPage.Enemies.Spawn, function()
	act("spawnEnemy", { enemyType = enemyTypes[enemyIndex], count = enemyCount() })
end)
for _, button in { heistsPage.Clear.Mine, heistsPage.Clear.All } do
	wire(button, function()
		act("clearEnemies", { scope = button:GetAttribute("Scope") })
	end)
end

-- ---------------------------------------------------------------- ME: toggles, walk speed, spectate

local mePage = pages.ME
local TOGGLES = { God = { "god", "AdminGod" }, Invisible = { "invisible", "AdminInvisible" }, Fly = { "fly", "AdminFly" }, Noclip = { "noclip", "AdminNoclip" } }

local function isOn(attribute: string): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute(attribute) == true
end

local function renderToggles()
	for name, spec in TOGGLES do
		local on = isOn(spec[2])
		mePage[name].BackgroundColor3 = if on then C.accent else C.raised
		mePage[name].TextColor3 = if on then C.panel else C.white
	end
	mePage.FlyHint.Visible = isOn("AdminFly") and UserInputService.PreferredInput ~= Enum.PreferredInput.Touch
end

for name, spec in TOGGLES do
	wire(mePage[name], function()
		act(spec[1], { on = not isOn(spec[2]) })
	end)
end
local speed = stepper(mePage.Speed)
wire(mePage.Speed.Set, function()
	act("walkSpeed", { value = speed() })
end)
wire(mePage.Speed.Normal, function()
	act("walkSpeed", {})
end)

-- Spectate: the camera follows the target's humanoid until STOP, its death or it leaving (the server keeps the
-- target's area streamed in for us meanwhile). Closing the panel does not stop it.
local spectating: { RBXScriptConnection }? = nil

local function stopSpectating(message: string?)
	if not spectating then
		return
	end
	for _, connection in spectating do
		connection:Disconnect()
	end
	spectating = nil
	local own = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if own then
		Workspace.CurrentCamera.CameraSubject = own
	end
	if message then
		show(true, message)
	end
end

local function startSpectating(targetPlayer: Player)
	local humanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	stopSpectating()
	local own = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if own then
		own:UnequipTools() -- the shoulder camera follows a held gun; spectating needs the camera free
	end
	Workspace.CurrentCamera.CameraSubject = humanoid
	spectating = {
		humanoid.Died:Connect(function()
			stopSpectating("The spectated player died.")
		end),
		targetPlayer.AncestryChanged:Connect(function()
			if not targetPlayer.Parent then
				stopSpectating("The spectated player left.")
			end
		end),
	}
end

refreshers.ME = function()
	renderToggles()
	local reply = call("lookup")
	if not reply.ok then
		return
	end
	for _, child in mePage.SpectateList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for order, row in reply.data do
		if row.userId ~= player.UserId then
			local item = templates.ListButton:Clone()
			item.Name = row.name
			item.LayoutOrder = order
			item.Text = row.displayName
			wire(item, function()
				local answer = act("spectate", { target = row.userId })
				local targetPlayer = Players:GetPlayerByUserId(row.userId)
				if answer.ok and targetPlayer then
					startSpectating(targetPlayer)
				end
			end)
			item.Parent = mePage.SpectateList
		end
	end
end
wire(mePage.Stop, function()
	act("stopSpectate")
	stopSpectating()
end)

-- ---------------------------------------------------------------- SERVER

local serverPage = pages.SERVER

local function renderStats(stats)
	serverPage.Stats.Text = string.format("Players %d / %d     Uptime %s     Server memory %d MB\nHeartbeat %d fps     Average ping %d ms",
		stats.players, stats.maxPlayers, clock(stats.uptime), stats.memoryMb, stats.heartbeatFps, stats.pingMs)
end

refreshers.SERVER = function()
	local stats = call("stats")
	if stats.ok then
		renderStats(stats.data)
	end
	local log = call("log")
	if not log.ok then
		return
	end
	for _, child in serverPage.Log:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for order, row in log.data do
		local item = templates.LogRow:Clone()
		item.LayoutOrder = order
		item.Text = `{os.date("%H:%M:%S", row.t)}   {row.admin}   {row.action}   {row.target}   {row.detail}`
		item.Parent = serverPage.Log
	end
end

wire(serverPage.Send, function()
	local reply = call("announce", { text = serverPage.Message.Text })
	show(reply.ok, if reply.ok then "Announcement sent." else reply.message)
	if reply.ok then
		serverPage.Message.Text = ""
	end
	refresh()
end)

-- Stats every STATS_SECONDS only while the Server tab is shown on an open panel; nothing runs otherwise.
local statsLoop = false
local function runStats()
	if statsLoop then
		return
	end
	statsLoop = true
	while true do
		task.wait(Config.STATS_SECONDS)
		if not (panel.Visible and currentTab == "SERVER") then
			break
		end
		local stats = call("stats")
		if stats.ok and panel.Visible then
			renderStats(stats.data)
		end
	end
	statsLoop = false
end

-- ---------------------------------------------------------------- tabs, open and close

local function showTab(name: string)
	currentTab = name
	for _, tab in panel.Rail:GetChildren() do
		if tab:IsA("TextButton") then
			local on = tab.Name == name
			tab.AccentBar.Visible = on
			tab.TextColor3 = if on then C.accent else C.white
		end
	end
	for _, tabPage in pages:GetChildren() do
		tabPage.Visible = tabPage.Name == name
	end
	refresh()
	if name == "SERVER" then
		task.spawn(runStats)
	end
end

for _, tab in panel.Rail:GetChildren() do
	if tab:IsA("TextButton") then
		wire(tab, function()
			showTab(tab.Name)
		end)
	end
end

local savedMouseIcon: boolean? = nil

-- Declared before open(): UI.Panels holds it as this panel's closer.
local function close()
	if not panel.Visible then
		return
	end
	panel.Visible = false
	weaponList.Visible = false
	MenuFovBlur.close()
	if savedMouseIcon ~= nil then
		UserInputService.MouseIconEnabled = savedMouseIcon
		savedMouseIcon = nil
	end
	Panels.closed(PANEL_NAME)
end

local function open()
	if panel.Visible or not role() then
		return
	end
	Panels.opened(PANEL_NAME, close)
	applyRole()
	status.Text = ""
	panel.Visible = true -- the Modal button inside frees a locked mouse while shown
	MenuFovBlur.open()
	savedMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = true
	showTab(currentTab)
end

local function toggle()
	if panel.Visible then
		close()
	else
		open()
	end
end

local closeButton = panel.Header.Close :: ImageButton
closeButton.Image = Effects.CLOSE_IMAGE
closeButton.Size = UDim2.fromOffset(Effects.CLOSE_SIZE, Effects.CLOSE_SIZE)
Effects.bindClose(closeButton)
closeButton.Activated:Connect(close)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Config.TOGGLE_KEY and role() then
		toggle()
	elseif input.KeyCode == Enum.KeyCode.ButtonB and panel.Visible then
		close()
	end
end)

-- Fits the 760 x 480 panel into the safe area (CoreUISafeInsets), never above 1.
local function fit()
	local area = gui.AbsoluteSize
	if area.X > 0 and area.Y > 0 then
		gui.FitScale.Scale = math.min(1, (area.X - Config.FIT_MARGIN) / Config.PANEL_SIZE.X, (area.Y - Config.FIT_MARGIN) / Config.PANEL_SIZE.Y)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- ---------------------------------------------------------------- the HUD button (phones and pads), fly UP / DOWN

local adminButton = hud.AdminButton :: ImageButton
Effects.bind(adminButton, { style = "bounce" }) -- the HUD column's hover 1.1 and click bounce, with its sounds
adminButton.Activated:Connect(toggle)

-- Hidden while any panel is up, as the Custom Inventory column is; shown only with a role.
local function showHudButton()
	adminButton.Visible = role() ~= nil and Panels.current() == nil
end
Panels.onChanged(showHudButton)

-- Same scale as the Custom Inventory column (HudClusterScale owns it), read after it updates.
local function syncScale()
	local column = playerGui:FindFirstChild("Custom Inventory")
	local scale = column and column:FindFirstChildOfClass("UIScale")
	hud.ClusterScale.Scale = if scale then scale.Scale else 1
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	task.defer(syncScale)
end)
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "Custom Inventory" then
		task.delay(0.1, syncScale)
	end
end)
syncScale()

player:GetAttributeChangedSignal("AdminRole"):Connect(function()
	if not role() then
		close()
	end
	applyRole()
	showHudButton()
end)
applyRole()

-- ---------------------------------------------------------------- fly and noclip (client-owned body)

local controls = nil
local function moveVector(): Vector3
	if controls == nil then
		local ok, found = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript):GetControls()
		end)
		controls = if ok then found else false
	end
	return if controls then controls:GetMoveVector() else Vector3.zero
end

local flying = nil
local keyDown, touchUp, touchDown = 0, 0, 0

local function stopFly()
	if not flying then
		return
	end
	flying.step:Disconnect()
	for _, mover in { flying.velocity, flying.align, flying.attachment } do
		mover:Destroy()
	end
	if flying.humanoid.Parent then
		flying.humanoid.PlatformStand = false
	end
	ContextActionService:UnbindAction("AdminFlyDown")
	flying = nil
	keyDown, touchUp, touchDown = 0, 0, 0
	hud.FlyUp.Visible = false
	hud.FlyDown.Visible = false
end

local function startFly(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if flying or not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "AdminFly"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AdminFly"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "AdminFly"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = Config.FLY_RESPONSIVENESS
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	humanoid.PlatformStand = true
	-- LeftControl is the shift-lock key (SmoothShiftLock binds it through ContextActionService at Medium). While
	-- flying this binding sits above it at High and sinks the key: Ctrl means down and shift lock never toggles.
	ContextActionService:BindActionAtPriority("AdminFlyDown", function(_, state)
		keyDown = if state == Enum.UserInputState.Begin then 1 else 0
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftControl)
	local touch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
	hud.FlyUp.Visible = touch
	hud.FlyDown.Visible = touch
	flying = {
		humanoid = humanoid,
		velocity = velocity,
		align = align,
		attachment = attachment,
		step = RunService.Heartbeat:Connect(function()
			local camera = Workspace.CurrentCamera
			local move = moveVector()
			local up = (if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 1 else 0) + touchUp - keyDown - touchDown
			local direction = camera.CFrame:VectorToWorldSpace(Vector3.new(move.X, 0, move.Z)) + Vector3.new(0, up, 0)
			velocity.VectorVelocity = if direction.Magnitude > 0.01 then direction.Unit * Config.FLY_SPEED else Vector3.zero
			local look = camera.CFrame.LookVector
			if math.abs(look.X) + math.abs(look.Z) > 0.01 then
				align.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
			end
		end),
	}
end

for _, spec in { { hud.FlyUp, function(v) touchUp = v end }, { hud.FlyDown, function(v) touchDown = v end } } do
	local function pressed(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	spec[1].InputBegan:Connect(function(input)
		if pressed(input) then
			spec[2](1)
		end
	end)
	spec[1].InputEnded:Connect(function(input)
		if pressed(input) then
			spec[2](0)
		end
	end)
end

-- Noclip: the body's parts stop colliding every Stepped while on; each part's own value comes back after.
local noclip = nil -- ponytail: walks the character every Stepped, only while an admin has noclip on

local function stopNoclip()
	if not noclip then
		return
	end
	noclip.step:Disconnect()
	for part, value in noclip.saved do
		part.CanCollide = value
	end
	noclip = nil
end

local function startNoclip(character: Model)
	if noclip then
		return
	end
	local saved = {}
	noclip = {
		saved = saved,
		step = RunService.Stepped:Connect(function()
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					if saved[part] == nil then
						saved[part] = part.CanCollide
					end
					part.CanCollide = false
				end
			end
		end),
	}
end

local function watchCharacter(character: Model)
	stopFly()
	stopNoclip()
	stopSpectating()
	local function sync()
		if character:GetAttribute("AdminFly") then
			startFly(character)
		else
			stopFly()
		end
		if character:GetAttribute("AdminNoclip") then
			startNoclip(character)
		else
			stopNoclip()
		end
		renderToggles()
	end
	character.AttributeChanged:Connect(sync)
	sync()
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
