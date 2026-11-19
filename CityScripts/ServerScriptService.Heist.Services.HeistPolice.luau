-- HeistPolice: the police a big robbery calls INTO the building (heist police and Bank guards, 2026-11-20;
-- developer decisions 1 and 3, the controller's squad hold).
--
-- A bank component (BankInstance's OnSessionStart / Seal / Rearm) of the Bank and NewsStation; Update() runs on the
-- location's heartbeat and acts once a HEIST_POLICE_TICK. `plan` (the location Config's HeistPolice) sends waves from
-- the session's start: plan.count officers at plan.first seconds, then plan.more every plan.every seconds, never more
-- than plan.cap of the plan alive. The Bank's `vaultPlan` (HeistPoliceVault) does the same from the vault door's
-- opening (OnVaultOpened, once a session). A wave goes only while a robber is inside (a participant, or a wanted
-- player, in the building); a wave due with nobody inside is skipped, and dead officers wait for the next wave.
--
-- Officers come from PoliceDispatcher.spawnLoose, so they look, fight, count and pay like police (faction Police,
-- witnesses, "seen"); they stand up at the location's HeistPoliceSpawn markers in turn, and their target filter is
-- this robbery's participants and wanted players inside the building, never bystanders. Each tick the ones without
-- a target are sent toward the robber nearest the first marker, when a path from that marker leads there (one path
-- check a tick: an unreachable robber, past the Bank's obby pit, costs no path per officer). They share POLICE_CAP
-- with the star squads: a wave takes only free room (PoliceDispatcher.room, re-checked per officer) and moves no
-- squad officer, and the squads count them as taken room. Seal removes every one; the getaway is the squads' job.
--
-- holdsSquad(player), registered with PoliceDispatcher.addSquadHold: until the first wave is due, the star squad of
-- a participant or of anyone in the building waits (the stars and the HUD still rise at the alarm). It is also an
-- active robbery for WantedService (the held robber counts as seen), so those stars do not drain while the police
-- wait: the Bank's trigger player is no participant until the vault teleporter, and nobody would see them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Wanted.Constants)
local STATE = require(ServerScriptService.Enemy.Scripts.EnemyAI).State

local HeistPolice = {}
HeistPolice.__index = HeistPolice

-- Pure: the waves of `plan` due `elapsed` seconds after it started.
function HeistPolice.wavesDue(plan, elapsed: number): number
	if elapsed < plan.first then
		return 0
	end
	return 1 + math.floor((elapsed - plan.first) / plan.every)
end

-- Pure: the officers wave `index` (1 = the first) sends, with `alive` of the plan up and `room` free under POLICE_CAP.
function HeistPolice.waveSize(plan, index: number, alive: number, room: number): number
	local size = if index == 1 then plan.count else plan.more
	return math.max(0, math.min(size, plan.cap - alive, room))
end

-- The location's HeistPoliceSpawn markers (BaseParts named HeistPoliceSpawn<n>), in name order.
function HeistPolice.markersIn(folder: Instance): { BasePart }
	local markers = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and string.match(child.Name, "^HeistPoliceSpawn%d+$") then
			table.insert(markers, child)
		end
	end
	table.sort(markers, function(a, b)
		return a.Name < b.Name
	end)
	return markers
end

-- deps: bank, plan, vaultPlan (optional), markers, isInside(player); seams: now, spawn, room, reaches, players, wait,
-- addSquadHold, addActiveRobbery.
function HeistPolice.new(deps)
	local dispatcher = require(ServerScriptService.Wanted.PoliceDispatcher)
	assert(deps.markers and #deps.markers > 0, "HeistPolice needs at least one HeistPoliceSpawn marker")
	local self = setmetatable({
		bank = deps.bank,
		markers = deps.markers,
		isInside = deps.isInside,
		now = deps.now or os.clock,
		spawn = deps.spawn or dispatcher.spawnLoose,
		room = deps.room or dispatcher.room,
		reaches = deps.reaches or dispatcher._reaches,
		players = deps.players or function() return Players:GetPlayers() end,
		wait = deps.wait or task.wait,
		_timed = { plan = deps.plan, officers = {}, fired = 0 },
		_vault = if deps.vaultPlan then { plan = deps.vaultPlan, officers = {}, fired = 0 } else nil,
		_nextTick = 0,
		_nextMarker = 0,
		_steering = false,
	}, HeistPolice)
	self._plans = { self._timed, self._vault }
	self._filter = function(player)
		return self:mayTarget(player)
	end
	local function holds(player)
		return self:holdsSquad(player)
	end
	;(deps.addSquadHold or dispatcher.addSquadHold)(holds)
	;(deps.addActiveRobbery or require(ServerScriptService.Wanted.WantedService).addActiveRobbery)(holds)
	return self
end

-- This robbery's participants anywhere, and wanted players inside the building.
function HeistPolice:mayTarget(player): boolean
	return self.bank:IsParticipant(player)
		or ((player:GetAttribute("WantedStars") or 0) >= 1 and self.isInside(player) == true)
end

function HeistPolice:holdsSquad(player): boolean
	local started = self._timed.startedAt
	return started ~= nil
		and self.bank:GetState() == "Active"
		and self.now() - started < self._timed.plan.first
		and (self.bank:IsParticipant(player) or self.isInside(player) == true)
end

function HeistPolice:_clear()
	for _, entry in self._plans do
		for _, ai in entry.officers do
			if not ai.destroyed then
				ai:destroy()
			end
		end
		entry.officers, entry.startedAt, entry.fired = {}, nil, 0
	end
end

function HeistPolice:OnSessionStart()
	self:_clear()
	self._timed.startedAt = self.now()
end

function HeistPolice:Seal()
	self:_clear()
end

function HeistPolice:Rearm()
	self:_clear()
end

-- The Bank's vault door has opened (HeistServer's once-a-session latch): the vault plan starts now.
function HeistPolice:OnVaultOpened()
	local vault = self._vault
	if vault and not vault.startedAt and self.bank:GetState() == "Active" then
		vault.startedAt = self.now()
		self._nextTick = 0
	end
end

-- Live officers of a plan; the dead and the removed leave its list.
function HeistPolice:_alive(entry): number
	local officers = entry.officers
	for i = #officers, 1, -1 do
		if officers[i].destroyed or officers[i].state == STATE.Dead then
			table.remove(officers, i)
		end
	end
	return #officers
end

function HeistPolice:_sendWave(entry, index: number)
	local n = HeistPolice.waveSize(entry.plan, index, self:_alive(entry), self.room())
	if n <= 0 then
		return
	end
	task.spawn(function()
		for _ = 1, n do
			-- Re-checked per officer: a squad or the other plan may have taken the room since.
			if self.bank:GetState() ~= "Active" or self.room() <= 0 or self:_alive(entry) >= entry.plan.cap then
				break
			end
			self._nextMarker = self._nextMarker % #self.markers + 1
			local scatter = Constants.HEIST_POLICE_SCATTER
			local position = self.markers[self._nextMarker].Position
				+ Vector3.new((math.random() * 2 - 1) * scatter, 0, (math.random() * 2 - 1) * scatter)
			local _, ai = self.spawn(entry.plan.template, position, self._filter)
			if ai then
				table.insert(entry.officers, ai)
			end
			self.wait() -- one officer a frame
		end
	end)
end

-- Officers with no target head for the robber nearest the first marker, when a path from that marker leads there.
function HeistPolice:_steer(robbers: { BasePart })
	if self._steering then
		return
	end
	local idle = {}
	for _, entry in self._plans do
		for _, ai in entry.officers do
			if not ai.destroyed and (ai.state == STATE.Patrol or ai.state == STATE.Search) then
				table.insert(idle, ai)
			end
		end
	end
	if #idle == 0 then
		return
	end
	local from = self.markers[1].Position
	local goal, best = nil, math.huge
	for _, root in robbers do
		local d = (root.Position - from).Magnitude
		if d < best then
			goal, best = root.Position, d
		end
	end
	self._steering = true
	task.spawn(function()
		local ok, reaches = pcall(self.reaches, from, goal)
		self._steering = false
		if ok and reaches then
			for _, ai in idle do
				if not ai.destroyed then
					ai:investigate(goal)
				end
			end
		end
	end)
end

function HeistPolice:Update()
	local now = self.now()
	if now < self._nextTick or self.bank:GetState() ~= "Active" then
		return
	end
	self._nextTick = now + Constants.HEIST_POLICE_TICK
	local robbers = {}
	for _, player in self.players() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and humanoid.RootPart and self.isInside(player) == true and self:mayTarget(player) then
			table.insert(robbers, humanoid.RootPart)
		end
	end
	for _, entry in self._plans do
		if entry.startedAt then
			local due = HeistPolice.wavesDue(entry.plan, now - entry.startedAt)
			while entry.fired < due do
				entry.fired += 1
				if #robbers > 0 then
					self:_sendWave(entry, entry.fired)
				end
			end
		end
	end
	if #robbers > 0 then
		self:_steer(robbers)
	end
end

return HeistPolice
