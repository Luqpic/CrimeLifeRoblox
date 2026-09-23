-- Per-faction kill counters for the player card.
--
-- Listens to the SAME ServerScriptService.Blaster.Events.Eliminated BindableEvent that
-- LevelingService and QuestService already consume, so a kill counted here can never disagree with
-- the kill that granted XP or advanced a quest. Nothing about damage or death is re-derived.
--
-- Persisted through ProfileGateway, keyed by the same attribute names the counters use in memory --
-- one shape, no translation table between the live counts and the saved ones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Stats.Constants)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated

-- Server-side source of truth. The player attributes are the replicated view of this, the same
-- split LevelingService uses between playerLevels and leaderstats.Level.
local counts: { [Player]: { [string]: number } } = {}

local function publish(player: Player)
	local playerCounts = counts[player]
	if not playerCounts then
		return
	end
	player:SetAttribute(Constants.CRIMINAL_ATTRIBUTE, playerCounts[Constants.CRIMINAL_ATTRIBUTE] or 0)
	player:SetAttribute(Constants.POLICE_ATTRIBUTE, playerCounts[Constants.POLICE_ATTRIBUTE] or 0)
end

local function onPlayerAdded(player: Player)
	-- Guarded: hydrate below may already have restored this player's counts, and the order between this
	-- handler and the gateway's hydrator phase is not guaranteed. An unconditional reset here would
	-- zero a restored count whenever this ran second.
	if not counts[player] then
		counts[player] = {}
		publish(player)
	end
end

-- Restores the counters from the profile and republishes the attributes. Creates the table itself if
-- onPlayerAdded has not run yet, so either ordering ends on the restored counts.
local function hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end

	local restored = {}
	for attribute, count in profile.Data.kills do
		if typeof(count) == "number" then
			restored[attribute] = count
		end
	end
	counts[player] = restored
	publish(player)
end

safePlayerAdded(onPlayerAdded)
ProfileGateway.registerHydrator(hydrate)

Players.PlayerRemoving:Connect(function(player: Player)
	counts[player] = nil
end)

-- attacker is a Player OR an enemy character Model -- ShotResolver fires Eliminated for both, and
-- its own comment warns listeners not to assume Player. An enemy killing another enemy (splash,
-- crossfire) must credit nobody, so the IsA check is load-bearing, not defensive noise.
eliminatedEvent.Event:Connect(function(attacker: Player | Model, victimHumanoid: Humanoid)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return
	end

	local victimCharacter = victimHumanoid.Parent
	if not victimCharacter then
		return
	end

	-- A player's own character carries no Faction attribute, so PvP kills fall out here and count
	-- toward neither bucket. That is deliberate and matches CashService, which already excludes PvP
	-- so it cannot be farmed.
	local faction = victimCharacter:GetAttribute(Constants.FACTION_ATTRIBUTE)
	local attribute = Constants.attributeForFaction(faction)
	if not attribute then
		return
	end

	-- A player can be eliminated-from mid-flight of their own leave, so re-check rather than assume
	-- the join handler's table still exists.
	local playerCounts = counts[attacker]
	if not playerCounts then
		return
	end

	playerCounts[attribute] = (playerCounts[attribute] or 0) + 1
	publish(attacker)
	-- After the live credit, never instead of it: a failed save must never cost a kill. Copied rather
	-- than aliased -- playerCounts is cleared on PlayerRemoving and keeps being mutated in place.
	ProfileGateway.mirror(attacker, function(profile)
		profile.Data.kills = table.clone(playerCounts)
	end)
end)
