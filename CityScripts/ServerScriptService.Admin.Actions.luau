-- Admin actions and their dispatcher (2026-11-20, admin-design.md "Remote" and "Actions").
--
-- Actions.list[name] = { role = "owner" | "helper", read = no log row, target = takes args.target (a UserId),
-- staffSafe = a helper may aim it at staff, validate(args, role) -> (clean | nil, why), run(ctx, admin, clean, d)
-- -> (ok, message, data) }. Every service a run touches comes through ctx (Actions.liveContext in the game, fakes
-- in Admin_Test). The logic stays in the owning code: levels, weapons and heists go through Admin.Hooks, wanted
-- level through WantedService, police through PoliceDispatcher, enemies through EnemyRig + EnemyAI.
--
-- Dispatch order: role, action and its role, arguments a table, target (a UserId of a player in this server;
-- a helper never acts on staff unless the action is staffSafe), validate, cooldown, run in pcall, log.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local LEVEL_CAP = require(ReplicatedStorage.Leveling.Constants).LEVEL_CAP
local WALK_BASELINE = require(ReplicatedStorage.Movement.Constants).WALK_SPEED_BASELINE
local MAX_CASH_CREDIT = require(ReplicatedStorage.HeistShared.Config).MaxCashCredit

local ADMIN_TAG = "AdminSpawned"
local NO_CHARACTER = "No character right now."

local Actions = {}

Actions.REFUSE = table.freeze({
	role = "Not allowed.",
	unknown = "Unknown action.",
	ownerOnly = "Owner only.",
	badArgs = "Bad request.",
	notFound = "Player not found.",
	staff = "Helpers cannot act on staff.",
	self = "Not on yourself.",
	tooFast = "Too fast. Try again in a moment.",
	failed = "That failed. The server output has the error.",
})
local R = Actions.REFUSE

-- ---------------------------------------------------------------- argument checks

-- A finite whole number in lo..hi, or nil (NaN and infinities fail `% 1 == 0`).
local function int(value, lo: number, hi: number): number?
	if type(value) ~= "number" or value % 1 ~= 0 or value < lo or value > hi then
		return nil
	end
	return value
end

-- Valid UTF-8, trimmed, 1..max characters, or nil.
local function text(value, max: number): string?
	if type(value) ~= "string" or utf8.len(value) == nil then
		return nil
	end
	local trimmed = string.match(value, "^%s*(.-)%s*$") :: string
	local length = utf8.len(trimmed)
	if trimmed == "" or not length or length > max then
		return nil
	end
	return trimmed
end

local function toggle(args)
	if type(args.on) ~= "boolean" then
		return nil, "On or off."
	end
	return { on = args.on }
end

local function amount(limit: number, label: string)
	return function(args)
		local n = int(args.amount, -limit, limit)
		if not n or n == 0 then
			return nil, `{label}: a whole number, not 0.`
		end
		return { amount = n }
	end
end

-- The optional reason of a kick or ban ("" when none).
local function reason(args): string?
	if args.reason == nil or args.reason == "" then
		return ""
	end
	return text(args.reason, Config.KICK_REASON_MAX)
end

local function isEnemyType(name): boolean
	if type(name) ~= "string" then
		return false
	end
	local template = ServerStorage.EnemyTemplates:FindFirstChild(name)
	return template ~= nil and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") ~= nil
		and template:GetAttribute("Faction") ~= "Police" -- police have their own button
end

-- ---------------------------------------------------------------- world helpers

local function humanoidOf(player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function rootOf(player): BasePart?
	local humanoid = humanoidOf(player)
	return humanoid and humanoid.RootPart
end

local function placeCFrame(name: string): CFrame?
	local path = Config.PLACES[name]
	local found: Instance? = nil
	if path == true then
		for _, child in Workspace:GetChildren() do
			if child:IsA("SpawnLocation") and child.Enabled then
				found = child
				break
			end
		end
	else
		found = Workspace
		for _, step in path do
			found = found and found:FindFirstChild(step)
		end
	end
	if not (found and found:IsA("PVInstance")) then
		return nil
	end
	return CFrame.new((found :: PVInstance):GetPivot().Position + Vector3.new(0, Config.TELEPORT_UP, 0))
end

-- Streams the spot in for that player first (StreamingEnabled), then moves the character.
local function teleport(player: Player, cframe: CFrame): (boolean, string)
	local root = rootOf(player)
	if not root then
		return false, NO_CHARACTER
	end
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 5)
	end)
	if not root.Parent then
		return false, NO_CHARACTER
	end
	(root.Parent :: Model):PivotTo(cframe)
	return true, "Moved."
end

-- `n` points on a ring around `origin`, dropped onto whatever is below (players and NPCs ignored).
local function ringAround(origin: Vector3, n: number): { Vector3 }
	local exclude = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for _, name in { "Enemies", "Police" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local points = {}
	for i = 1, n do
		local angle = i / n * math.pi * 2
		local point = origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.SPAWN_RING
		local hit = Workspace:Raycast(point + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
		table.insert(points, (if hit then hit.Position else point) + Vector3.new(0, 3, 0))
	end
	return points
end

local function enemiesFolder(): Instance
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Enemies"
		folder.Parent = Workspace
	end
	return folder :: Instance
end

-- ---------------------------------------------------------------- per-character admin states

-- Invisible: every part and decal of the character at 1, the original values kept to restore exactly (also
-- parts that arrive later, such as an equipped Tool; restored wherever they are by then). The nameplate reads
-- the AdminInvisible attribute (PlayerNameplates).
local hidden = setmetatable({}, { __mode = "k" }) -- [Model] = { saved = { [Instance] = number }, connection }

local function hide(saved, instance: Instance)
	if (instance:IsA("BasePart") or instance:IsA("Decal")) and saved[instance] == nil then
		saved[instance] = (instance :: any).Transparency
		;(instance :: any).Transparency = 1
	end
end

local function setInvisible(character: Model, on: boolean)
	local entry = hidden[character]
	if on and not entry then
		entry = { saved = {} }
		for _, descendant in character:GetDescendants() do
			hide(entry.saved, descendant)
		end
		entry.connection = character.DescendantAdded:Connect(function(descendant)
			hide(entry.saved, descendant)
		end)
		hidden[character] = entry
		character:SetAttribute("AdminInvisible", true)
	elseif not on and entry then
		entry.connection:Disconnect()
		for instance, value in entry.saved do
			(instance :: any).Transparency = value
		end
		hidden[character] = nil
		character:SetAttribute("AdminInvisible", nil)
	end
end

-- God: an invisible ForceField refuses every Humanoid:TakeDamage (shots, bleed, splash, melee, enemies, police,
-- guards, lasers); the Bank death pit, the one Health = 0 kill, checks AdminGod itself; the void is the one
-- death left, so a god admin near Workspace.FallenPartsDestroyHeight is put back on the spawn. No fall damage
-- exists in the city (grep 2026-11-20).
local function setGod(character: Model, on: boolean)
	local field = character:FindFirstChild("AdminGod")
	if not on then
		if field then
			field:Destroy()
		end
		character:SetAttribute("AdminGod", nil)
		return
	end
	character:SetAttribute("AdminGod", true)
	if field then
		return
	end
	field = Instance.new("ForceField")
	field.Name = "AdminGod"
	field.Visible = false
	field.Parent = character
	local guard
	guard = RunService.Heartbeat:Connect(function()
		if not (field :: Instance).Parent then
			guard:Disconnect()
			return
		end
		local root = character.PrimaryPart
		if root and root.Position.Y < Workspace.FallenPartsDestroyHeight + Config.VOID_MARGIN then
			local spawn = placeCFrame("Spawn")
			if spawn then
				character:PivotTo(spawn)
			end
		end
	end)
end

-- Spectate: the target's root is the admin's ReplicationFocus until stop, the target's death, or its body or
-- the target leaving (the client watches the same events for its camera).
local spectating = {} -- [admin] = { connections }

local function stopSpectate(admin: Player)
	local entry = spectating[admin]
	if not entry then
		return
	end
	spectating[admin] = nil
	for _, connection in entry do
		connection:Disconnect()
	end
	if admin.Parent then
		admin.ReplicationFocus = nil
	end
end

local function startSpectate(admin: Player, root: BasePart, humanoid: Humanoid)
	stopSpectate(admin)
	admin.ReplicationFocus = root
	spectating[admin] = {
		humanoid.Died:Connect(function()
			stopSpectate(admin)
		end),
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(Workspace) then
				stopSpectate(admin)
			end
		end),
	}
end

-- Death (AdminService calls this on Died) clears every per-life state of that character.
function Actions.clearCharacter(character: Model)
	setInvisible(character, false)
	setGod(character, false)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and character:GetAttribute("AdminFrozen") then
		root.Anchored = false
	end
	for _, name in { "AdminFrozen", "AdminWalkSpeed", "AdminFly", "AdminNoclip" } do
		character:SetAttribute(name, nil)
	end
end

function Actions.forgetPlayer(player: Player)
	stopSpectate(player)
end

-- The admin's own living character, for the Me tab.
local function own(admin): (Model?, Humanoid?)
	local humanoid = humanoidOf(admin)
	return humanoid and humanoid.Parent :: Model, humanoid
end

-- ---------------------------------------------------------------- the actions

local function targetName(player)
	return player.DisplayName
end

Actions.list = {
	-- Players tab
	lookup = {
		role = "helper",
		read = true,
		run = function(ctx)
			local rows = {}
			for _, player in ctx.players() do
				local character = player.Character
				local leaderstats = player:FindFirstChild("leaderstats")
				local cash = leaderstats and leaderstats:FindFirstChild("Cash")
				table.insert(rows, {
					name = player.Name,
					displayName = player.DisplayName,
					userId = player.UserId,
					level = player:GetAttribute("Level") or 1,
					cash = if cash then cash.Value else 0,
					spraypaint = player:GetAttribute("Spraypaint") or 0,
					stars = player:GetAttribute("WantedStars") or 0,
					role = ctx.roleOf(player) or "",
					frozen = character ~= nil and character:GetAttribute("AdminFrozen") == true,
				})
			end
			table.sort(rows, function(a, b)
				return string.lower(a.name) < string.lower(b.name)
			end)
			return true, `{#rows} players`, rows
		end,
	},
	setLevel = {
		role = "owner",
		target = true,
		validate = function(args)
			local level = int(args.level, 1, LEVEL_CAP)
			if not level then
				return nil, `Level: 1 to {LEVEL_CAP}.`
			end
			return { level = level }
		end,
		run = function(ctx, _admin, a)
			ctx.hooks.setLevel(a.target, a.level)
			return true, `{targetName(a.target)} is level {a.level}.`
		end,
	},
	addCash = {
		role = "owner",
		target = true,
		validate = amount(Config.CASH_LIMIT, "Cash"),
		run = function(ctx, _admin, a)
			local leaderstats = a.target:FindFirstChild("leaderstats")
			local cash = leaderstats and leaderstats:FindFirstChild("Cash")
			if not cash then
				return false, "No cash loaded yet."
			end
			local before = cash.Value
			if a.amount > 0 then
				ctx.currency:Add(a.target.UserId, a.amount) -- its own bound: MaxCashCredit per call
				if cash.Value == before then
					return false, `Give at most {MAX_CASH_CREDIT} at a time.`
				end
			else
				cash.Value = math.max(0, before + a.amount)
			end
			return true, `{targetName(a.target)}: cash {before} to {cash.Value}.`
		end,
	},
	addSpraypaint = {
		role = "owner",
		target = true,
		validate = amount(Config.SPRAYPAINT_LIMIT, "Spraypaint"),
		run = function(ctx, _admin, a)
			local spray = ctx.spraypaint
			local before = spray.balanceOf(a.target)
			if a.amount > 0 then
				spray.grant(a.target, a.amount, "admin")
			elseif before > 0 then
				spray.spend(a.target, math.min(-a.amount, before)) -- never below 0: takes what is there
			end
			return true, `{targetName(a.target)}: Spraypaint {before} to {spray.balanceOf(a.target)}.`
		end,
	},
	giveWeapon = {
		role = "owner",
		target = true,
		validate = function(args)
			local name = args.weapon
			local template = type(name) == "string" and ServerStorage.Weapons:FindFirstChild(name)
			if not (template and template:IsA("Tool")) then
				return nil, "Unknown weapon."
			end
			return { weapon = name }
		end,
		run = function(ctx, _admin, a)
			local ok, message = ctx.hooks.giveWeapon(a.target, a.weapon)
			return ok, `{a.weapon}: {message}`
		end,
	},
	heal = {
		role = "owner",
		target = true,
		run = function(_ctx, _admin, a)
			local humanoid = humanoidOf(a.target)
			if not humanoid then
				return false, NO_CHARACTER
			end
			humanoid.Health = humanoid.MaxHealth
			return true, `{targetName(a.target)} healed.`
		end,
	},
	respawn = {
		role = "owner",
		target = true,
		run = function(_ctx, _admin, a)
			a.target:LoadCharacter()
			return true, `{targetName(a.target)} respawned.`
		end,
	},
	freeze = {
		role = "helper",
		target = true,
		run = function(_ctx, _admin, a)
			local root = rootOf(a.target)
			if not root then
				return false, NO_CHARACTER
			end
			root.Anchored = true
			;(root.Parent :: Model):SetAttribute("AdminFrozen", true)
			return true, `{targetName(a.target)} frozen.`
		end,
	},
	unfreeze = {
		role = "helper",
		target = true,
		run = function(_ctx, _admin, a)
			local character = a.target.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and character:GetAttribute("AdminFrozen")) then
				return false, "Not frozen."
			end
			root.Anchored = false
			character:SetAttribute("AdminFrozen", nil)
			return true, `{targetName(a.target)} unfrozen.`
		end,
	},
	["goto"] = {
		role = "helper",
		target = true,
		staffSafe = true,
		run = function(_ctx, admin, a)
			local root = rootOf(a.target)
			if not root then
				return false, NO_CHARACTER
			end
			return teleport(admin, root.CFrame * CFrame.new(0, 0, 4))
		end,
	},
	bring = {
		role = "helper",
		target = true,
		run = function(_ctx, admin, a)
			local root = rootOf(admin)
			if not root then
				return false, NO_CHARACTER
			end
			return teleport(a.target, root.CFrame * CFrame.new(0, 0, -4))
		end,
	},
	kick = {
		role = "helper",
		target = true,
		validate = function(args)
			local why = reason(args)
			if not why then
				return nil, `Reason: up to {Config.KICK_REASON_MAX} characters.`
			end
			return { reason = why }
		end,
		run = function(ctx, admin, a)
			if a.target == admin then
				return false, R.self
			end
			local message = if a.reason == "" then "Removed by an admin." else ctx.filterBroadcast(a.reason, admin.UserId)
			a.target:Kick(message)
			return true, `{targetName(a.target)} kicked: {message}`
		end,
	},
	ban = {
		role = "helper",
		target = true,
		validate = function(args, role)
			local seconds = type(args.duration) == "string" and Config.BAN_DURATIONS[args.duration]
			if not seconds then
				return nil, "Pick a ban length."
			end
			if role ~= "owner" and (seconds < 0 or seconds > Config.HELPER_BAN_MAX) then
				return nil, "Helpers ban for a day at most."
			end
			local why = reason(args)
			if not why then
				return nil, `Reason: up to {Config.KICK_REASON_MAX} characters.`
			end
			return { duration = args.duration, seconds = seconds, reason = why }
		end,
		run = function(ctx, admin, a)
			if a.target == admin then
				return false, R.self
			end
			local message = if a.reason == "" then "Banned by an admin." else ctx.filterBroadcast(a.reason, admin.UserId)
			local ok, err = pcall(ctx.ban, {
				UserIds = { a.target.UserId },
				Duration = a.seconds,
				DisplayReason = message,
				PrivateReason = `{admin.Name}: {message}`,
				ExcludeAltAccounts = false,
				ApplyToUniverse = true,
			})
			if not ok then
				warn("[Admin] ban failed: " .. tostring(err))
				return false, if ctx.isStudio then "Ban works only in a published game." else "Ban failed. The server output has the error."
			end
			return true, `{targetName(a.target)} banned ({a.duration}): {message}`
		end,
	},

	-- Heists tab
	heistState = {
		role = "helper",
		read = true,
		run = function(ctx)
			local rows = {}
			for _, name in Config.HEISTS do
				local bank = ctx.hooks.heists[name]
				local state, seconds = "Missing", 0
				if bank then
					state = bank:GetState()
					if state == "Cooldown" then
						seconds = math.max(0, (bank:GetCooldownEndsAt() or 0) - bank.now())
					elseif state == "Active" then
						seconds = bank:GetSecondsRemaining()
					end
				end
				table.insert(rows, { name = name, state = state, seconds = math.ceil(seconds) })
			end
			return true, "", rows
		end,
	},
	resetCooldown = {
		role = "owner",
		validate = function(args)
			if args.heist ~= "All" and not (type(args.heist) == "string" and table.find(Config.HEISTS, args.heist)) then
				return nil, "Unknown heist."
			end
			return { heist = args.heist }
		end,
		run = function(ctx, _admin, a)
			local reset = {}
			for _, name in if a.heist == "All" then Config.HEISTS else { a.heist } do
				local bank = ctx.hooks.heists[name]
				if bank and bank:ResetCooldown() then
					table.insert(reset, name)
				end
			end
			if #reset == 0 then
				return false, "No cooldown to reset (a robbery in progress is never reset)."
			end
			return true, `Reset: {table.concat(reset, ", ")}.`
		end,
	},
	teleportTo = {
		role = "helper",
		validate = function(args)
			if type(args.place) ~= "string" or not Config.PLACES[args.place] then
				return nil, "Unknown place."
			end
			return { place = args.place }
		end,
		run = function(_ctx, admin, a)
			local cframe = placeCFrame(a.place)
			if not cframe then
				return false, "That place is not in the map."
			end
			return teleport(admin, cframe)
		end,
	},
	setStars = {
		role = "owner",
		target = true,
		validate = function(args)
			local stars = int(args.stars, 0, Config.STARS_MAX)
			if not stars then
				return nil, `Stars: 0 to {Config.STARS_MAX}.`
			end
			return { stars = stars }
		end,
		run = function(ctx, _admin, a)
			ctx.wanted.setStars(a.target, a.stars)
			return true, `{targetName(a.target)}: {a.stars} stars.`
		end,
	},
	clearAllStars = {
		role = "owner",
		run = function(ctx)
			for _, player in ctx.players() do
				ctx.wanted.clear(player)
			end
			return true, "Every star cleared."
		end,
	},
	spawnPolice = {
		role = "owner",
		validate = function(args)
			local count = int(args.count, 1, Config.SPAWN_COUNT_MAX)
			if not count then
				return nil, `Count: 1 to {Config.SPAWN_COUNT_MAX}.`
			end
			return { count = count }
		end,
		run = function(ctx, admin, a)
			local root = rootOf(admin)
			if not root then
				return false, NO_CHARACTER
			end
			local made = 0
			for i, position in ringAround(root.Position, a.count) do
				local kind = if i >= Config.POLICE_ARMED_FROM then "Armed Police" else "Police"
				local character = ctx.police.spawnLoose(kind, position)
				if character then
					CollectionService:AddTag(character, ADMIN_TAG)
					made += 1
				end
			end
			return made > 0, `{made} police spawned.`
		end,
	},
	spawnEnemy = {
		role = "owner",
		validate = function(args)
			local count = int(args.count, 1, Config.SPAWN_COUNT_MAX)
			if not isEnemyType(args.enemyType) then
				return nil, "Unknown enemy type."
			elseif not count then
				return nil, `Count: 1 to {Config.SPAWN_COUNT_MAX}.`
			end
			return { enemyType = args.enemyType, count = count }
		end,
		run = function(ctx, admin, a)
			local root = rootOf(admin)
			if not root then
				return false, NO_CHARACTER
			end
			local template = ServerStorage.EnemyTemplates:FindFirstChild(a.enemyType)
			local made = 0
			for _, position in ringAround(root.Position, a.count) do
				local character, weapon, config = ctx.enemyRig.build(template, a.enemyType)
				if character and weapon then
					CollectionService:AddTag(character, ADMIN_TAG)
					ctx.enemyRig.place(character, weapon, CFrame.new(position), enemiesFolder())
					ctx.enemyAI.new(character, weapon, position, nil, config) -- no spawner accounting
					made += 1
				end
			end
			return made > 0, `{made} {a.enemyType} spawned.`
		end,
	},
	clearEnemies = {
		role = "owner",
		validate = function(args)
			if args.scope ~= "mine" and args.scope ~= "all" then
				return nil, "Mine or all."
			end
			return { scope = args.scope }
		end,
		-- Killed, not destroyed: the normal death path runs (the spawner refills its own, police leave squads).
		run = function(ctx, _admin, a)
			local cleared = 0
			if a.scope == "mine" then
				for _, character in CollectionService:GetTagged(ADMIN_TAG) do
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid.Health = 0
						cleared += 1
					end
				end
			else
				for _, ai in ctx.enemyAI.getLive() do
					ai.humanoid.Health = 0
					cleared += 1
				end
			end
			return true, `{cleared} cleared.`
		end,
	},

	-- Me tab
	god = {
		role = "owner",
		validate = toggle,
		run = function(_ctx, admin, a)
			local character, humanoid = own(admin)
			if not (character and humanoid) then
				return false, NO_CHARACTER
			end
			setGod(character, a.on)
			if a.on then
				humanoid.Health = humanoid.MaxHealth
			end
			return true, if a.on then "God on." else "God off."
		end,
	},
	invisible = {
		role = "owner",
		validate = toggle,
		run = function(_ctx, admin, a)
			local character = own(admin)
			if not character then
				return false, NO_CHARACTER
			end
			setInvisible(character, a.on)
			return true, if a.on then "Invisible." else "Visible."
		end,
	},
	walkSpeed = {
		role = "owner",
		validate = function(args)
			if args.value == nil then
				return { value = false } -- back to normal
			end
			local value = int(args.value, Config.WALK_SPEED_MIN, Config.WALK_SPEED_MAX)
			if not value then
				return nil, `Walk speed: {Config.WALK_SPEED_MIN} to {Config.WALK_SPEED_MAX}.`
			end
			return { value = value }
		end,
		-- Animate2 and SprintAuthority both read AdminWalkSpeed; the server's value replicates once.
		run = function(_ctx, admin, a)
			local character, humanoid = own(admin)
			if not (character and humanoid) then
				return false, NO_CHARACTER
			end
			character:SetAttribute("AdminWalkSpeed", a.value or nil)
			humanoid.WalkSpeed = a.value or WALK_BASELINE
			return true, if a.value then `Walk speed {a.value}.` else "Walk speed normal."
		end,
	},
	fly = {
		role = "owner",
		validate = toggle,
		run = function(_ctx, admin, a)
			local character = own(admin)
			if not character then
				return false, NO_CHARACTER
			end
			character:SetAttribute("AdminFly", a.on or nil) -- the admin's client flies the body it owns
			return true, if a.on then "Fly on." else "Fly off."
		end,
	},
	noclip = {
		role = "owner",
		validate = toggle,
		run = function(_ctx, admin, a)
			local character = own(admin)
			if not character then
				return false, NO_CHARACTER
			end
			character:SetAttribute("AdminNoclip", a.on or nil)
			return true, if a.on then "Noclip on." else "Noclip off."
		end,
	},
	spectate = {
		role = "helper",
		target = true,
		staffSafe = true,
		run = function(_ctx, admin, a)
			if a.target == admin then
				return false, R.self
			end
			local humanoid = humanoidOf(a.target)
			if not (humanoid and humanoid.RootPart) then
				return false, NO_CHARACTER
			end
			startSpectate(admin, humanoid.RootPart, humanoid)
			return true, `Spectating {targetName(a.target)}.`
		end,
	},
	stopSpectate = {
		role = "helper",
		run = function(_ctx, admin)
			stopSpectate(admin)
			return true, "Stopped spectating."
		end,
	},

	-- Server tab
	announce = {
		role = "helper",
		validate = function(args)
			local message = text(args.text, Config.ANNOUNCE_MAX)
			if not message then
				return nil, `Message: 1 to {Config.ANNOUNCE_MAX} characters.`
			end
			return { text = message }
		end,
		run = function(ctx, admin, a)
			local filtered = ctx.filterBroadcast(a.text, admin.UserId)
			ctx.broadcast(filtered)
			return true, filtered
		end,
	},
	stats = {
		role = "helper",
		read = true,
		run = function(ctx)
			return true, "", ctx.stats()
		end,
	},
	log = {
		role = "helper",
		read = true,
		run = function(_ctx, _admin, _a, d)
			return true, "", table.clone(d.log)
		end,
	},
}

-- ---------------------------------------------------------------- dispatcher

local function reply(ok: boolean, message: string?, data: any?)
	return { ok = ok, message = message or "", data = data }
end

local function isUserId(value): boolean
	return type(value) == "number" and value % 1 == 0 and math.abs(value) < 2 ^ 53
end

-- ctx needs at least now(), roleOf(player), playerByUserId(id); the runs use the rest.
function Actions.newDispatcher(ctx)
	local d = { log = {} }
	local lastCall = {}
	local lastRefusal = {}

	local function addRow(admin: string, action: string, target: string?, detail: string)
		table.insert(d.log, 1, { t = os.time(), admin = admin, action = action, target = target or "", detail = detail })
		d.log[Config.LOG_SIZE + 1] = nil
	end

	function d.forget(player)
		lastCall[player] = nil
		lastRefusal[player] = nil
	end

	function d.call(player, actionName, args)
		local role = ctx.roleOf(player)
		if role ~= "owner" and role ~= "helper" then
			local now = ctx.now()
			if not lastRefusal[player] or now - lastRefusal[player] >= Config.REFUSAL_LOG_SECONDS then
				lastRefusal[player] = now
				local shown = if type(actionName) == "string" then string.sub(actionName, 1, 32) else typeof(actionName)
				addRow(player.Name, shown, nil, "refused: no admin role")
			end
			return reply(false, R.role)
		end

		local action = if type(actionName) == "string" then rawget(Actions.list, actionName) else nil
		if not action then
			return reply(false, R.unknown)
		end
		if action.role == "owner" and role ~= "owner" then
			return reply(false, R.ownerOnly)
		end
		if args == nil then
			args = {}
		elseif type(args) ~= "table" then
			return reply(false, R.badArgs)
		end

		local target = nil
		if action.target then
			target = if isUserId(args.target) then ctx.playerByUserId(args.target) else nil
			if not target then
				return reply(false, R.notFound)
			end
			if role == "helper" and not action.staffSafe and ctx.roleOf(target) ~= nil then
				return reply(false, R.staff)
			end
		end

		local clean, why = {}, nil
		if action.validate then
			clean, why = action.validate(args, role)
		end
		if not clean then
			return reply(false, why or R.badArgs)
		end
		clean.target = target

		local now = ctx.now()
		if lastCall[player] and now - lastCall[player] < Config.COOLDOWN then
			return reply(false, R.tooFast)
		end
		lastCall[player] = now

		local called, ok, message, data = pcall(action.run, ctx, player, clean, d)
		local targetLabel = target and target.Name
		if not called then
			warn(`[Admin] {actionName} failed: {ok}`)
			addRow(player.Name, actionName, targetLabel, "failed")
			return reply(false, R.failed)
		end
		if ok and not action.read then
			addRow(player.Name, actionName, targetLabel, message or "")
		end
		return reply(ok == true, message, data)
	end

	return d
end

-- ---------------------------------------------------------------- the live services

function Actions.liveContext(announceRemote: RemoteEvent)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Stats = game:GetService("Stats")
	local TextService = game:GetService("TextService")
	local Roles = require(script.Parent.Roles)
	return {
		now = os.clock,
		roleOf = Roles.get,
		playerByUserId = function(id)
			return Players:GetPlayerByUserId(id)
		end,
		players = function()
			return Players:GetPlayers()
		end,
		hooks = require(script.Parent.Hooks),
		currency = require(ServerScriptService.PlayerData.CurrencyService),
		spraypaint = require(ServerScriptService.Spraypaint.Scripts.SpraypaintService),
		wanted = require(ServerScriptService.Wanted.WantedService),
		police = require(ServerScriptService.Wanted.PoliceDispatcher),
		enemyRig = require(ServerScriptService.Enemy.Scripts.EnemyRig),
		enemyAI = require(ServerScriptService.Enemy.Scripts.EnemyAI),
		isStudio = RunService:IsStudio(),
		filterBroadcast = function(message: string, fromUserId: number): string
			local result = TextService:FilterStringAsync(message, fromUserId, Enum.TextFilterContext.PublicChat)
			return result:GetNonChatStringForBroadcastAsync()
		end,
		broadcast = function(message: string)
			announceRemote:FireAllClients(message)
		end,
		ban = function(config)
			Players:BanAsync(config)
		end,
		-- Measured on demand (the panel asks every 2 s only while the Server tab is shown): nothing runs between.
		stats = function()
			local started, beats = os.clock(), 0
			while beats < 10 do
				RunService.Heartbeat:Wait()
				beats += 1
			end
			local players = Players:GetPlayers()
			local ping, measured = 0, 0
			for _, player in players do
				local ok, seconds = pcall(player.GetNetworkPing, player)
				if ok then
					ping += seconds
					measured += 1
				end
			end
			return {
				players = #players,
				maxPlayers = Players.MaxPlayers,
				uptime = math.floor(time()),
				memoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
				heartbeatFps = math.floor(beats / (os.clock() - started) + 0.5),
				pingMs = if measured > 0 then math.floor(ping / measured * 1000 + 0.5) else 0,
			}
		end,
	}
end

return Actions
