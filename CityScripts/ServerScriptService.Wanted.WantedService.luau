-- WantedService: the server-owned wanted level (police and wanted, Task 1, 2026-11-17).
--
-- Heat per player (0..5, saved nowhere), replicated as the player attributes WantedHeat and WantedStars;
-- the client only reads those. Raised by robbery alarms (onAlarm, called where each robbery path announces
-- NotifyRobberyTriggered), by hits and kills on police, and by witnessed crimes on other NPCs (onDamaged /
-- onEliminated, fed by Blaster.Events.Damaged and Eliminated). Unseen for DRAIN_INTERVAL seconds, heat drops
-- one step; seen, the timer restarts. Death and leaving clear it. Each step also publishes WantedSeen (seen, or
-- the active-robbery bypass) and WantedDraining (the unseen timer is running) for the star meter (Task 4).
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
local Witnesses = require(script.Parent.Witnesses)

local WantedService = {}

WantedService._deps = {
	now = os.clock,
	-- Task 2 installs the police and guard line-of-sight check through setSeenProvider.
	seen = function(_player): boolean return false end,
	-- Is the attacker seen by a witness (Witness tag, WITNESS_RANGE, line of sight; Task 3)?
	witness = function(player): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root ~= nil and Witnesses.sees(root.Position)
	end,
	playerFromCharacter = function(character) return Players:GetPlayerFromCharacter(character) end,
	-- Still in the game with a living character. A hit or kill from anyone else (a bleed or a bullet landing
	-- after the shooter died or left) must not re-create heat on a player who was just cleared.
	attackerActive = function(attacker): boolean
		if attacker.Parent ~= Players then return false end
		local character = attacker.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0
	end,
}
-- Design section 9 (fix round 1): seconds after a rise in heat before the unseen timer may start.
WantedService._deps.searchSeconds = Constants.SEARCH_SECONDS

-- Robberies register a check "is this player a participant of my Active session?" (LocationServer:Start,
-- HeistServer); a participant of any of them counts as seen.
local robberies = {}
function WantedService.addActiveRobbery(isActiveFor: (Player) -> boolean)
	table.insert(robberies, isActiveFor)
	return {
		Disconnect = function()
			local i = table.find(robberies, isActiveFor)
			if i then table.remove(robberies, i) end
		end,
	}
end
WantedService._deps.activeRobbery = function(player): boolean
	for _, isActiveFor in robberies do
		local ok, active = pcall(isActiveFor, player)
		if ok and active == true then return true end
	end
	return false
end

local deps = WantedService._deps

local heatOf = {} -- [player] = heat, only while > 0
local timerFrom = {} -- [player] = when the drain timer last restarted
local raisedAt = {} -- [player] = when heat last rose (the search window runs from here)
local lastPoliceHit = {} -- [player] = { [Humanoid] = time of the last credited hit }
local lastSeenWarning = -math.huge

-- A minimal signal: :Connect(fn) returns { Disconnect }, fire(...) spawns every listener.
local function newSignal()
	local listeners = {}
	local signal = {
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
	local function fire(...)
		for _, fn in table.clone(listeners) do
			task.spawn(fn, ...)
		end
	end
	return signal, fire
end

local fireChanged, fireAlarmed
-- Changed(player, heat, stars), fired on every change of heat.
WantedService.Changed, fireChanged = newSignal()
-- Alarmed(locationName, players), fired by every onAlarm with a level: the police dispatcher sends the first
-- squad to that location (Task 2).
WantedService.Alarmed, fireAlarmed = newSignal()

local function set(player, heat: number)
	local old = heatOf[player] or 0
	if heat > 0 then
		heatOf[player] = heat
	else
		heatOf[player] = nil
		timerFrom[player] = nil
		raisedAt[player] = nil
		lastPoliceHit[player] = nil
		player:SetAttribute("WantedSeen", false)
		player:SetAttribute("WantedDraining", false)
	end
	local stars = HeatModel.stars(heat)
	player:SetAttribute("WantedHeat", heat)
	player:SetAttribute("WantedStars", stars)
	if heat ~= old then
		fireChanged(player, heat, stars)
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
	raisedAt[player] = deps.now()
end

-- A robbery's alarm: every participant's heat becomes at least the location's level. A location without a
-- level (a test location) gives nothing.
function WantedService.onAlarm(locationName: string, players: { Player })
	local level = Constants.ALARM_LEVELS[locationName]
	if not level then return end
	for _, player in players do
		set(player, HeatModel.atLeast(WantedService.getHeat(player), level))
		timerFrom[player] = deps.now()
		raisedAt[player] = deps.now()
	end
	fireAlarmed(locationName, players)
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

-- attacker is a Player (start()'s handlers filter) still in the game and alive. Police hit: +0.25, pellets of one shot counted once. A heist
-- civilian (tagged Witness) hurt while a witness sees: +0.25. Anything else: nothing.
function WantedService.onDamaged(attacker, humanoid: Humanoid, _amount: number?)
	local character = humanoid.Parent
	if not character or not deps.attackerActive(attacker) then return end
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
	if not character or not deps.attackerActive(attacker) then return end
	if isPolice(character) then
		WantedService.addHeat(attacker, Constants.POLICE_KILL_HEAT, "police kill")
	elseif isNpc(character) and deps.witness(attacker) then
		WantedService.addHeat(attacker, Constants.PUBLIC_KILL_HEAT, "public kill")
	end
end

-- A throwing seen provider counts as "not seen" (warned at most once a minute), so it cannot stop the drain.
local function isSeen(player, t: number): boolean
	local ok, result = pcall(deps.seen, player)
	if ok then return result == true end
	if t - lastSeenWarning >= 60 then
		lastSeenWarning = t
		warn("[WantedService] seen provider failed: " .. tostring(result))
	end
	return false
end

-- Do the police know where the player is? During the search window after a rise in heat, and while a
-- robbery they are in is active. The dispatcher sends officers to the player's position then.
function WantedService.knowsWhere(player, now: number?): boolean
	local t = now or deps.now()
	local raised = raisedAt[player]
	return (raised ~= nil and t - raised <= deps.searchSeconds) or deps.activeRobbery(player) == true
end

-- One drain evaluation for every wanted player. now defaults to the injected clock. Seen, inside the
-- search window or in an active robbery: the timer restarts. Otherwise the player is draining.
function WantedService._step(now: number?)
	local t = now or deps.now()
	for player, heat in heatOf do
		local seen = deps.activeRobbery(player) == true or isSeen(player, t)
		local draining = not (seen or WantedService.knowsWhere(player, t))
		if not draining then
			timerFrom[player] = t
		elseif t - (timerFrom[player] or t) >= Constants.DRAIN_INTERVAL then
			set(player, HeatModel.drainStep(heat))
			if heatOf[player] then timerFrom[player] = t end
		end
		if heatOf[player] then
			player:SetAttribute("WantedSeen", seen)
			player:SetAttribute("WantedDraining", draining)
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

-- The handlers start() connects. Both events also carry NPC attackers (an enemy's shot); only a player
-- commits a crime.
function WantedService._onDamagedEvent(attacker, humanoid, amount)
	if isPlayer(attacker) and isHumanoid(humanoid) then
		WantedService.onDamaged(attacker, humanoid, amount)
	end
end

function WantedService._onEliminatedEvent(attacker, humanoid)
	if isPlayer(attacker) and isHumanoid(humanoid) then
		WantedService.onEliminated(attacker, humanoid)
	end
end

WantedService._onPlayerRemoving = WantedService.clear

function WantedService.start()
	local function onPlayer(player: Player)
		player:SetAttribute("WantedHeat", 0)
		player:SetAttribute("WantedStars", 0)
		player:SetAttribute("WantedSeen", false)
		player:SetAttribute("WantedDraining", false)
		player.CharacterAdded:Connect(function(character)
			WantedService._watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(WantedService._watchCharacter, player, player.Character)
		end
	end
	require(ReplicatedStorage.Utility.safePlayerAdded)(onPlayer)
	Players.PlayerRemoving:Connect(WantedService._onPlayerRemoving)
	local events = ServerScriptService.Blaster.Events
	events.Damaged.Event:Connect(WantedService._onDamagedEvent)
	events.Eliminated.Event:Connect(WantedService._onEliminatedEvent)
end

return WantedService
