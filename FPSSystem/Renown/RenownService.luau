-- Renown: a currency earned by killing NPCs and levelling up, spent on skins.
--
-- The earn path is two LISTENERS on signals the game already broadcasts, so no existing file is
-- modified. ShotResolver, KillStatsService and LevelingService are working code in the damage and
-- progression paths, and Phase 1's hardest lesson was that economy and appearance code must not be
-- able to break them. Not touching them at all is stronger than guarding them.
--
-- Session-only. Nothing here persists, matching Cash, Leveling and the kill counters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Renown.Constants)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local RenownService = {}

-- The level each player was last seen at. A baseline, not a cache: LevelingService sets Level inside
-- onPlayerAdded, so without this every player would collect a level-up award simply for joining.
--
-- Correct independent of script load order, since LevelingService and RenownRunner are both plain
-- Scripts with no guaranteed relative order. If RenownRunner runs first, lastLevel[player] is nil when
-- LevelingService's join-time SetAttribute("Level", 1) fires onLevelChanged; previous == nil early-
-- returns and seeds the baseline instead of paying. If LevelingService runs first, the join-time Level
-- is simply read directly as the baseline below, before this listener is even connected. Both land on
-- Renown = 0.
local lastLevel: { [Player]: number } = {}

function RenownService.balanceOf(player: any): number
	local value = player:GetAttribute(Constants.ATTRIBUTE)
	return if typeof(value) == "number" then value else 0
end

function RenownService.grant(player: any, amount: number, reason: string): number
	local balance = RenownService.balanceOf(player)
	-- Guarded rather than trusted: a negative grant would be a silent deduction, and the callers are
	-- rate tables that a later edit could get wrong.
	if typeof(amount) ~= "number" or amount <= 0 then
		return balance
	end
	local updated = balance + math.floor(amount)
	player:SetAttribute(Constants.ATTRIBUTE, updated)
	return updated
end

function RenownService.spend(player: any, amount: number): boolean
	if typeof(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then
		return false
	end
	local balance = RenownService.balanceOf(player)
	if balance < amount then
		return false
	end
	player:SetAttribute(Constants.ATTRIBUTE, balance - amount)
	return true
end

-- Production entry point for the Eliminated BindableEvent. Validates the signal's shape strictly,
-- because this receives whatever ShotResolver passes, then delegates the award rule.
function RenownService.onEliminated(attacker: unknown, victimHumanoid: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return
	end
	RenownService.awardForVictim(attacker, victimHumanoid)
end

-- The award rule, split from the guard above so it can be tested. A Player cannot be constructed with
-- Instance.new, so no test stand-in can ever satisfy `typeof(attacker) == "Instance"`; splitting keeps
-- that check STRICT in production instead of loosening real validation for test convenience.
--
-- Reads the victim's faction exactly as KillStatsService does, which is what makes PvP worthless here:
-- a player's own character carries no Faction attribute, so it resolves to nil and pays zero.
function RenownService.awardForVictim(player: any, victimHumanoid: unknown)
	if typeof(victimHumanoid) ~= "Instance" then
		return
	end
	local character = victimHumanoid.Parent
	if not character then
		return
	end
	local amount = Constants.renownForFaction(character:GetAttribute("Faction"))
	if amount > 0 then
		RenownService.grant(player, amount, "kill")
	end
end

-- Level handler. Awards per level GAINED, so a multi-level jump pays for each one rather than once,
-- and never awards on the join-time set.
function RenownService.onLevelChanged(player: any)
	local level = player:GetAttribute("Level")
	if typeof(level) ~= "number" then
		return
	end
	local previous = lastLevel[player]
	lastLevel[player] = level
	if previous == nil or level <= previous then
		return
	end
	RenownService.grant(player, (level - previous) * Constants.LEVEL_RENOWN, "level")
end

function RenownService.start()
	ServerScriptService.Blaster.Events.Eliminated.Event:Connect(RenownService.onEliminated)

	safePlayerAdded(function(player: Player)
		if player:GetAttribute(Constants.ATTRIBUTE) == nil then
			player:SetAttribute(Constants.ATTRIBUTE, 0)
		end
		-- Recorded BEFORE connecting, so the join-time Level set cannot be read as a level-up.
		lastLevel[player] = player:GetAttribute("Level")
		player:GetAttributeChangedSignal("Level"):Connect(function()
			RenownService.onLevelChanged(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastLevel[player] = nil
	end)
end

return RenownService
