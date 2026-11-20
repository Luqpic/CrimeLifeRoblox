-- Kill-based leveling: XP is granted on every kill by a real player, for both AI and PvP kills --
-- unlike CashService, which deliberately excludes PvP so cash cannot be farmed that way.
-- Saved: level and XP live in the player's profile through ProfileGateway (ProfileStore, since 2026-09-23),
-- restored by `hydrate` below and written by every mirror call.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local LevelingConstants = require(ReplicatedStorage.Leveling.Constants)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)

-- Source of truth for the MaxHealth bonus on respawn -- leaderstats.Level is the display copy.
local playerLevels: { [Player]: number } = {}

local function applyMaxHealth(character: Model, level: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = LevelingConstants.maxHealth(level)
	humanoid.Health = humanoid.MaxHealth
end

-- Sets a level outright, bypassing XP accumulation entirely: Level, XP 0, NextLevelXP, the max health bonus
-- and the save. Two callers (2026-11-20): the admin panel's setLevel for any player, through Admin.Hooks, and
-- SetLevelRequest below for its sender. Placed after applyMaxHealth because it calls it.
local function setLevel(player: Player, targetLevel: number)
	-- Clamped rather than rejected, so 0, negatives and absurd values all resolve to something
	-- legal instead of erroring or writing a nonsense level.
	local level = math.clamp(math.floor(targetLevel), 1, LevelingConstants.LEVEL_CAP)

	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue then
		levelValue.Value = level
	end
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", 0)
	local capped = level >= LevelingConstants.LEVEL_CAP
	player:SetAttribute("NextLevelXP", if capped then 0 else LevelingConstants.xpToNextLevel(level))
	playerLevels[player] = level

	-- mirror hands the callback the PROFILE, not profile.Data -- see the note in CashService. Writing
	-- `data.level` here landed on a stray top-level field that is never serialised.
	ProfileGateway.mirror(player, function(profile)
		profile.Data.level = level
		profile.Data.xp = 0
	end)

	local character = player.Character
	if character then
		applyMaxHealth(character, level)
	end
end
require(ServerScriptService.Admin.Hooks).setLevel = setLevel

-- The old /setlevel and F2 panel remote: gated on the server to the owner role (Admin.Roles; it held one account
-- id until 2026-11-20). The client panel that sent it is retired; the admin panel calls setLevel instead.
local AdminRoles = require(ServerScriptService.Admin.Roles)
ReplicatedStorage.Leveling.Remotes.SetLevelRequest.OnServerEvent:Connect(function(player: Player, targetLevel: any)
	if AdminRoles.get(player) ~= "owner" then
		return
	end
	if typeof(targetLevel) ~= "number" or targetLevel ~= targetLevel then -- NaN survives floor and clamp
		return
	end
	setLevel(player, targetLevel)
end)

-- Creates only what is missing. CashService writes Cash into this same folder and sibling scripts
-- have no guaranteed init order, so neither script may assume it owns the folder.
local function onPlayerAdded(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local level = leaderstats:FindFirstChild("Level")
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Value = 1
		level.Parent = leaderstats

		-- Defaults only, and only on first creation -- a hydrator may already have run (order with
		-- ProfileGateway's own PlayerAdded handler is not guaranteed) and restored the real values, in
		-- which case `level` above was found rather than created and none of this runs, so a restored
		-- XP/Level is never clobbered back to a fresh join's defaults.
		playerLevels[player] = 1
		-- Mirrored as attributes alongside the leaderstats IntValue so the client HUD has one
		-- consistent GetAttributeChangedSignal path for XP, NextLevelXP and Level.
		player:SetAttribute("Level", 1)
		player:SetAttribute("XP", 0)
		player:SetAttribute("NextLevelXP", LevelingConstants.xpToNextLevel(1))
	end

	player.CharacterAdded:Connect(function(character: Model)
		applyMaxHealth(character, playerLevels[player] or level.Value)
	end)
	if player.Character then
		applyMaxHealth(player.Character, playerLevels[player] or level.Value)
	end
end

-- Restores level, xp, the leaderstats IntValue and the playerLevels source of truth from the profile,
-- then recomputes NextLevelXP from the restored level -- NEVER read from the profile, it is derived
-- (Schema.DERIVED) and is not stored. Registered as a hydrator (bottom of file); may run before or
-- after onPlayerAdded above (order is not guaranteed), so it creates leaderstats/Level itself if
-- onPlayerAdded hasn't yet, or overwrites the values if it has.
local function hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local levelValue = leaderstats:FindFirstChild("Level")
	if not levelValue then
		levelValue = Instance.new("IntValue")
		levelValue.Name = "Level"
		levelValue.Parent = leaderstats
	end

	local level = profile.Data.level
	local xp = profile.Data.xp

	levelValue.Value = level
	playerLevels[player] = level
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", xp)
	local capped = level >= LevelingConstants.LEVEL_CAP
	player:SetAttribute("NextLevelXP", if capped then 0 else LevelingConstants.xpToNextLevel(level))

	-- The fourth of four level-changing paths, and previously the only one that skipped this.
	-- CharacterAutoLoads can spawn a character before this hydrator's profile load resolves (it does
	-- not yield, ProfileGateway's does), so onPlayerAdded's CharacterAdded connection can already have
	-- applied MaxHealth for the level-1 default by the time this runs -- a level-70 returning player
	-- would otherwise spend their whole first life at 100 HP instead of 376, uncorrectable by a
	-- level-up at the cap. Guarded on Character existing: if it doesn't exist yet, onPlayerAdded's
	-- CharacterAdded connection fires later and reads the playerLevels value this just set, so both
	-- orderings land on the correct health.
	--
	-- This is a full heal (applyMaxHealth also sets Health = MaxHealth), which is only safe here
	-- because hydration runs once at join, before any combat -- do not reuse this call elsewhere a
	-- mid-fight full heal would be exploitable.
	if player.Character then
		applyMaxHealth(player.Character, level)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

ProfileGateway.registerHydrator(hydrate)

Players.PlayerRemoving:Connect(function(player: Player)
	playerLevels[player] = nil
end)

-- Same tier detection CashService.getEnemyTier uses, duplicated rather than shared -- this one also
-- runs against player victims (for PvP), which CashService's version never needs to.
local function getCharacterTier(character: Model): string
	local weapon = character:FindFirstChildOfClass("Tool")
	if not weapon then
		return "Pistol" -- reasonable middle tier if somehow unarmed
	end
	if weapon:GetAttribute(BlasterConstants.INFINITE_AMMO_ATTRIBUTE) then
		return "Melee"
	end
	if weapon:GetAttribute(BlasterConstants.FIRE_MODE_ATTRIBUTE) == BlasterConstants.FIRE_MODE.AUTO then
		return "AutoRifle"
	end
	return "Pistol"
end

local function grantXp(player: Player, amount: number)
	local level = playerLevels[player] or 1
	if level >= LevelingConstants.LEVEL_CAP then
		return -- capped: extra XP is simply dropped, nothing left to progress toward
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")

	local xp = ((player:GetAttribute("XP") :: number?) or 0) + amount

	-- Looped, not a single if, so one large grant can correctly cross more than one level at once.
	while level < LevelingConstants.LEVEL_CAP do
		local needed = LevelingConstants.xpToNextLevel(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1

		if levelValue then
			levelValue.Value = level
		end
		player:SetAttribute("Level", level)

		if cash then
			cash.Value += LevelingConstants.CASH_PER_LEVEL_UP
		end

		local character = player.Character
		if character then
			applyMaxHealth(character, level)
		end
	end

	playerLevels[player] = level

	local capped = level >= LevelingConstants.LEVEL_CAP
	local finalXp = if capped then 0 else xp
	player:SetAttribute("XP", finalXp)
	player:SetAttribute("NextLevelXP", if capped then 0 else LevelingConstants.xpToNextLevel(level))

	ProfileGateway.mirror(player, function(profile)
		profile.Data.level = level
		profile.Data.xp = finalXp
	end)
end

-- Reuses the same Eliminated BindableEvent CashService listens to -- no new event, no second place
-- that has to learn what a kill is. Unlike CashService this does NOT check whether the dying
-- character is tagged as an enemy: PvP kills grant XP too, by design.
-- Quest rewards grant XP through this exact path rather than a separate copy, so level-up
-- thresholds and the max-health-per-level side effect can never drift between kill-based and
-- quest-based XP. grantXp is already a local above, so nothing else is needed here.
local grantXpEvent = ServerScriptService.Quests.Events.GrantXp
grantXpEvent.Event:Connect(function(player: Player, amount: number)
	grantXp(player, amount)
end)

-- Tells the killer who they killed, for the kill toast's "KILLED <name>" title. Sent from here because
-- this is the one handler that sees every kill a player makes, PvP included (Cash, Spraypaint and the
-- kill counters all skip PvP). The rewards themselves still reach the client as attributes.
local killConfirmedRemote = ReplicatedStorage.Blaster.Remotes.KillConfirmed

-- The name the victim is shown under: a player's display name, or an enemy's type -- the same value
-- EnemySpawner writes on its nameplate (every rig is literally named "Enemy").
local function victimName(character: Model): string
	local victimPlayer = Players:GetPlayerFromCharacter(character)
	if victimPlayer then
		return victimPlayer.DisplayName
	end
	local enemyType = character:GetAttribute("EnemyTemplate")
	return if typeof(enemyType) == "string" then enemyType else character.Name
end

local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated
eliminatedEvent.Event:Connect(function(shooter: Player | Model, humanoid: Humanoid)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end

	local character = humanoid.Parent
	if not character then
		return
	end

	killConfirmedRemote:FireClient(shooter, victimName(character :: Model))
	-- A heist guard killed outside a robbery pays nothing (GuardPost sets NoKillReward; developer, 2026-11-20).
	if not character:GetAttribute("NoKillReward") then
		grantXp(shooter, LevelingConstants.XP_VALUES[getCharacterTier(character :: Model)])
	end
end)
