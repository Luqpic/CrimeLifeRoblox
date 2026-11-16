-- WantedService: the server-owned wanted level (police and wanted, Task 1, 2026-11-17).
--
-- Heat per player (0..5, saved nowhere), replicated as the player attributes WantedHeat and WantedStars;
-- the client only reads those. Raised by robbery alarms (onAlarm, called where each robbery path announces
-- NotifyRobberyTriggered), by hits and kills on police, and by witnessed crimes on other NPCs (onDamaged /
-- onEliminated, fed by Blaster.Events.Damaged and Eliminated). Unseen for DRAIN_INTERVAL seconds, heat drops
-- one step; seen, the timer restarts. Death and leaving clear it.
--
-- Requiring this connects nothing: WantedRunner calls start() and steps the drain at SEEN_CHECK_HZ.
-- _deps holds the clock, the seen provider, the witness check and the character-to-player lookup, so the
-- tests (WantedService_Test) can inject them and drive _step without waiting real seconds.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Wanted.Constants)
local HeatModel = require(ReplicatedStorage.Wanted.HeatModel)

local WantedService = {}

WantedService._deps = {
	now = os.clock,
	-- Task 2 installs the police and guard line-of-sight check through setSeenProvider.
	seen = function(_player): boolean return false end,
	-- Is the attacker seen by a witness? Task 3 replaces this stub with the Witness-tag check.
	witness = function(_player): boolean return false end,
	playerFromCharacter = function(character) return Players:GetPlayerFromCharacter(character) end,
}
local deps = WantedService._deps

local heatOf = {} -- [player] = heat, only while > 0
local timerFrom = {} -- [player] = when the drain timer last restarted
local lastPoliceHit = {} -- [player] = { [Humanoid] = time of the last credited hit }

local listeners = {}
-- Changed(player, heat, stars), fired on every change of heat.
WantedService.Changed = {
	Connect = function(_, fn)
		table.insert(listeners, fn)
		return {
			Disconnect = function()
				local i = table.find(listeners, fn)
				if i then table.remove(listeners, i) end
			end,
		}
	end,
}

local function set(player, heat: number)
	local old = heatOf[player] or 0
	if heat > 0 then
		heatOf[player] = heat
	else
		heatOf[player] = nil
		timerFrom[player] = nil
		lastPoliceHit[player] = nil
	end
	local stars = HeatModel.stars(heat)
	player:SetAttribute("WantedHeat", heat)
	player:SetAttribute("WantedStars", stars)
	if heat ~= old then
		for _, fn in table.clone(listeners) do
			task.spawn(fn, player, heat, stars)
		end
	end
end

function WantedService.getHeat(player): number
	return heatOf[player] or 0
end

function WantedService.setSeenProvider(fn: (Player) -> boolean)
	deps.seen = fn
end

-- reason is for reading call sites and debugging only.
function WantedService.addHeat(player, amount: number, _reason: string)
	if amount <= 0 then return end
	set(player, HeatModel.raise(WantedService.getHeat(player), amount))
	timerFrom[player] = deps.now()
end

-- A robbery's alarm: every participant's heat becomes at least the location's level. A location without a
-- level (a test location) gives nothing.
function WantedService.onAlarm(locationName: string, players: { Player })
	local level = Constants.ALARM_LEVELS[locationName]
	if not level then return end
	for _, player in players do
		set(player, HeatModel.atLeast(WantedService.getHeat(player), level))
		timerFrom[player] = deps.now()
	end
end

function WantedService.clear(player)
	set(player, 0)
end

local function isPolice(character): boolean
	return Constants.POLICE_TEMPLATES[character:GetAttribute("EnemyTemplate")] == true
end

-- A non-police NPC: anything that is not a player's character.
local function isNpc(character): boolean
	return deps.playerFromCharacter(character) == nil
end

-- attacker is a Player (the runner filters). Police hit: +0.25, pellets of one shot counted once. A heist
-- civilian (tagged Witness) hurt while a witness sees: +0.25. Anything else: nothing.
function WantedService.onDamaged(attacker, humanoid: Humanoid, _amount: number?)
	local character = humanoid.Parent
	if not character then return end
	if isPolice(character) then
		local now = deps.now()
		local hits = lastPoliceHit[attacker]
		local last = hits and hits[humanoid]
		if last and now - last < Constants.HIT_MERGE_WINDOW then return end
		WantedService.addHeat(attacker, Constants.POLICE_HIT_HEAT, "police hit")
		hits = lastPoliceHit[attacker] or setmetatable({}, { __mode = "k" })
		hits[humanoid] = now
		lastPoliceHit[attacker] = hits
	elseif isNpc(character) and CollectionService:HasTag(character, "Witness") and deps.witness(attacker) then
		WantedService.addHeat(attacker, Constants.PUBLIC_HURT_HEAT, "civilian hurt")
	end
end

-- Police kill: +1. Any other NPC killed while a witness sees: +0.5. A player killed: nothing.
function WantedService.onEliminated(attacker, humanoid: Humanoid)
	local character = humanoid.Parent
	if not character then return end
	if isPolice(character) then
		WantedService.addHeat(attacker, Constants.POLICE_KILL_HEAT, "police kill")
	elseif isNpc(character) and deps.witness(attacker) then
		WantedService.addHeat(attacker, Constants.PUBLIC_KILL_HEAT, "public kill")
	end
end

-- One drain evaluation for every wanted player. now defaults to the injected clock.
function WantedService._step(now: number?)
	local t = now or deps.now()
	for player, heat in heatOf do
		if deps.seen(player) then
			timerFrom[player] = t
		elseif t - (timerFrom[player] or t) >= Constants.DRAIN_INTERVAL then
			set(player, HeatModel.drainStep(heat))
			if heatOf[player] then timerFrom[player] = t end
		end
	end
end

function WantedService._watchCharacter(player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			WantedService.clear(player)
		end)
	end
end

local function isPlayer(value): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function isHumanoid(value): boolean
	return typeof(value) == "Instance" and value:IsA("Humanoid")
end

function WantedService.start()
	local function onPlayer(player: Player)
		player:SetAttribute("WantedHeat", 0)
		player:SetAttribute("WantedStars", 0)
		player.CharacterAdded:Connect(function(character)
			WantedService._watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(WantedService._watchCharacter, player, player.Character)
		end
	end
	require(ReplicatedStorage.Utility.safePlayerAdded)(onPlayer)
	Players.PlayerRemoving:Connect(WantedService.clear)

	-- Both events also carry NPC attackers (an enemy's shot); only a player commits a crime.
	local events = ServerScriptService.Blaster.Events
	events.Damaged.Event:Connect(function(attacker, humanoid, amount)
		if isPlayer(attacker) and isHumanoid(humanoid) then
			WantedService.onDamaged(attacker, humanoid, amount)
		end
	end)
	events.Eliminated.Event:Connect(function(attacker, humanoid)
		if isPlayer(attacker) and isHumanoid(humanoid) then
			WantedService.onEliminated(attacker, humanoid)
		end
	end)
end

return WantedService
