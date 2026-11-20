-- Police patrols (2026-11-20, developer: "Polices can patrol randomly in the city, if a police sees a criminal and vice
-- versa, they can get into a gun fight"; picker "6, also chase wanted"). Constants.PATROL_COUNT Police walk the city's
-- roads, each from one random road point to the next; one that dies is replaced PATROL_RESPAWN seconds later. They are
-- loose officers (PoliceDispatcher.spawnLoose: the gang EnemyAI, Police faction, engaging wanted players), so they fight
-- criminals on sight (EnemyAI faction targets) and shoot wanted players; a wanted player the police believe to be within
-- PATROL_RESPOND studs draws them in like a squad. They share POLICE_CAP: a patrol waits while there is no room.
-- start() is called by WantedRunner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Wanted.Constants)
local PoliceDispatcher = require(script.Parent.PoliceDispatcher)
local Sight = require(script.Parent.Sight)

local PolicePatrols = {}

-- slot = { ai, leg, legSince, freeAt }: a live officer, or the time its replacement may stand up.
PolicePatrols.slots = {}

local function playerRoots(): { BasePart }
	local roots = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and humanoid.RootPart then
			table.insert(roots, humanoid.RootPart)
		end
	end
	return roots
end

local function seenByAny(position: Vector3, roots: { BasePart }): boolean
	for _, root in roots do
		local head = root.Parent and root.Parent:FindFirstChild("Head")
		if head and Sight.inSight(head.Position, position) then
			return true
		end
	end
	return false
end

local function nearestDistance(position: Vector3, roots: { BasePart }): number
	local best = math.huge
	for _, root in roots do
		best = math.min(best, (root.Position - position).Magnitude)
	end
	return best
end

local function isLive(ai): boolean
	return ai ~= nil and not ai.destroyed and ai.state ~= "Dead"
end

-- Walk to a new road point PATROL_LEG_MIN..MAX away (its patrol circles there); false when none was found.
local function newLeg(slot, now: number): boolean
	local ai = slot.ai
	local point = PoliceDispatcher._findSpawn(ai.rootPart.Position, Constants.PATROL_LEG_MIN, Constants.PATROL_LEG_MAX, nil, nil)
	if not point or not PoliceDispatcher._reaches(ai.rootPart.Position, point) then
		return false
	end
	slot.leg, slot.legSince = point, now
	ai.spawnPosition = point
	ai.patrolRadius = 6
	ai:_clearPath()
	return true
end

-- Near a random player: the dispatcher's search checks that player's sight while sampling and a path to them
-- (PATROL_SPAWN_PATHS calls at most); the other players' sight after.
local function spawnInto(slot, roots: { BasePart }, now: number)
	local root = roots[math.random(#roots)]
	local player = Players:GetPlayerFromCharacter(root.Parent)
	if player then
		local point = PoliceDispatcher._findSpawn(root.Position, Constants.PATROL_SPAWN_MIN, Constants.PATROL_SPAWN_MAX, player, { paths = Constants.PATROL_SPAWN_PATHS })
		if point and not seenByAny(point, roots) then
			local _, ai = PoliceDispatcher.spawnLoose("Police", point)
			if ai then
				ai.character:SetAttribute("Patrol", true)
				slot.ai, slot.freeAt = ai, nil
				newLeg(slot, now)
			end
		end
	end
end

local function step(now: number)
	local roots = playerRoots()
	for i = 1, Constants.PATROL_COUNT do
		local slot = PolicePatrols.slots[i]
		if not slot then
			slot = { freeAt = 0 }
			PolicePatrols.slots[i] = slot
		end
		local ai = slot.ai
		if ai and not isLive(ai) then
			slot.ai, slot.freeAt = nil, now + Constants.PATROL_RESPAWN
			ai = nil
		end
		if not ai then
			if #roots > 0 and now >= slot.freeAt and PoliceDispatcher.room() > 0 then
				spawnInto(slot, roots, now)
			end
			continue
		end
		local position = ai.rootPart.Position
		-- Gone from every player: back near one at once (it did not die).
		if nearestDistance(position, roots) > Constants.PATROL_FAR and not seenByAny(position, roots) then
			ai:destroy() -- removes the character too
			slot.ai, slot.freeAt = nil, now
			continue
		end
		if ai.state ~= "Patrol" and ai.state ~= "Search" then
			continue -- chasing or fighting: its own AI
		end
		-- A wanted player believed near: go there like a squad.
		local respond = nil
		for _, player in Players:GetPlayers() do
			local believed = PoliceDispatcher.believedPosition(player)
			if believed and (believed - position).Magnitude <= Constants.PATROL_RESPOND then
				respond = believed
				break
			end
		end
		if respond then
			ai.spawnPosition = respond
			ai:investigate(respond)
			slot.leg = nil
		elseif ai.state == "Patrol" then
			local arrived = slot.leg ~= nil and Vector3.new(slot.leg.X - position.X, 0, slot.leg.Z - position.Z).Magnitude < 12
			if slot.leg == nil or arrived or now - slot.legSince > Constants.PATROL_LEG_TIMEOUT then
				newLeg(slot, now)
			end
		end
	end
end

function PolicePatrols.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(step, os.clock())
			if not ok then
				warn("[PolicePatrols] step failed: " .. tostring(err))
			end
			task.wait(Constants.PATROL_TICK)
		end
	end)
end

return PolicePatrols
