-- PoliceDispatcher: police squads for wanted players (police and wanted, Task 2, 2026-11-17).
--
-- One squad per wanted player, topped up every TOPUP_INTERVAL toward SquadPlan.target(stars), the server
-- cap shared highest stars first (SquadPlan.allocate). Officers are the Police / Armed Police templates on
-- the shared EnemyAI, built by EnemyRig like any enemy, with config.targetFilter = "wanted" and
-- config.faction = "Police". The first squad after an alarm spawns in a ring around the robbed location's
-- StatusBillboardAnchor; later ones in a ring around the player; every point passes isValidSpawn. Officers
-- head for where the police believe their player is (design section 9): the player's position during the
-- search window or an active robbery (the robbery's entrance when the player is inside it), else the spot
-- an officer last saw them; their own chase takes over on sight, and each prefers its squad's player. An
-- officer whose player is cleared, dead or gone takes another wanted player it can see, or walks away and
-- despawns once no player sees it (LEAVE_TIMEOUT at most); a leaving officer sees nobody for "seen".
--
-- Also installs WantedService's seen provider: a wanted player is seen while a live officer within
-- SEEN_RANGE can see them, or a live guard within SEEN_RANGE has them in sight (Witnesses.guardSees, Task 3).
-- start() is called by WantedRunner.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Wanted.Constants)
local SquadPlan = require(ReplicatedStorage.Wanted.SquadPlan)
local WantedService = require(script.Parent.WantedService)
local EnemyAI = require(ServerScriptService.Enemy.Scripts.EnemyAI)
local EnemyRig = require(ServerScriptService.Enemy.Scripts.EnemyRig)
local Sight = require(script.Parent.Sight)
local Witnesses = require(script.Parent.Witnesses)

local PoliceDispatcher = {}

local FACTION = "Police"
-- Where each alarm location's StatusBillboardAnchor lives (names WantedService.onAlarm receives).
local MARKERS = { Bank = "HeistMarkers", SlowFoods = "SlowFoodsMarkers", Gas2Go = "Gas2GoMarkers", NewsStation = "NewsStationMarkers" }
-- The four robbery locations' roots (CityMerge/phase3/locations.md 6.1): main models are one box each, the
-- zone folders one box per zone part. Map.Robbery's children are boxes too.
-- Each markers model's location model (the building the robber is in).
local LOCATION_MODEL = { HeistMarkers = "Bank", SlowFoodsMarkers = "SlowFoods", Gas2GoMarkers = "Gas2Go", NewsStationMarkers = "NewsStation" }
local ROBBERY_MODELS = { "SlowFoods", "Gas2Go", "NewsStation", "Bank", "BankVault" }
local ROBBERY_ZONE_FOLDERS = { "SlowFoodsZones", "Gas2GoZones", "NewsStationZones", "HeistZones" }

-- ===== where police may stand =====

local boxes -- { plots = { {cframe, size} }, robbery = { {cframe, size} } }, measured once (static geometry)
local groundRoots -- road and footpath containers (not Workspace.Ground: one baseplate under the whole city)

local function partBox(part: BasePart)
	return { part.CFrame, part.Size }
end

local function getBoxes()
	if boxes then
		return boxes
	end
	local plots, robbery = {}, {}
	for _, plot in Workspace.Plots:GetChildren() do
		if plot:IsA("BasePart") then
			table.insert(plots, partBox(plot))
		end
	end
	for _, name in ROBBERY_MODELS do
		local model = Workspace:FindFirstChild(name)
		if model and model:IsA("Model") then
			table.insert(robbery, { model:GetBoundingBox() })
		end
	end
	for _, name in ROBBERY_ZONE_FOLDERS do
		local folder = Workspace:FindFirstChild(name)
		for _, zone in folder and folder:GetChildren() or {} do
			if zone:IsA("BasePart") then
				table.insert(robbery, partBox(zone))
			end
		end
	end
	for _, child in Workspace.Map.Robbery:GetChildren() do
		if child:IsA("Model") then
			table.insert(robbery, { child:GetBoundingBox() })
		end
	end
	boxes = { plots = plots, robbery = robbery }
	return boxes
end

local function isGround(instance: Instance): boolean
	if not groundRoots then
		local map = Workspace.Map
		groundRoots = { map.City.Roads, map.Roads, map.City.FootPaths }
	end
	for _, root in groundRoots do
		if instance:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

-- A plot counts by its footprint (any height above or below the plate); a robbery box in full.
local function inBox(box, position: Vector3, footprintOnly: boolean): boolean
	local cframe, size = box[1], box[2]
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2
		and math.abs(p.Z) <= size.Z / 2
		and (footprintOnly or math.abs(p.Y) <= size.Y / 2)
end

local function policeFolder(): Folder
	local folder = Workspace:FindFirstChild("Police")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Police"
		folder.Parent = Workspace
	end
	return folder :: Folder
end

-- The rays and the line-of-sight probe live in Sight (Task 3: shared with witnesses and guards).
local worldParams = Sight.params
-- Would an officer standing at `position` be in view from `eye`?
PoliceDispatcher._inSight = Sight.inSight

local function reaches(from: Vector3, to: Vector3): boolean
	local path = PathfindingService:CreatePath(Constants.POLICE_AGENT)
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	return ok and path.Status == Enum.PathStatus.Success
end

-- The ExitSpawn of the robbery location whose box holds `position`, or nil.
local function entranceNear(position: Vector3): Vector3?
	for _, name in MARKERS do
		local markers = Workspace:FindFirstChild(name)
		local location = markers and Workspace:FindFirstChild(LOCATION_MODEL[name])
		if location and inBox({ location:GetBoundingBox() }, position, false) then
			for _, child in markers:GetChildren() do
				if child:IsA("BasePart") and string.sub(child.Name, -9) == "ExitSpawn" then
					return child.Position
				end
			end
		end
	end
	return nil
end

-- Can a police officer stand at `position` (SPAWN_HEIGHT above its ground)? Not in a plot's footprint or a
-- robbery building's box, on road or footpath ground; with a player, also out of that player's line of
-- sight and reachable by a path to them. Returns false and the first reason that failed.
function PoliceDispatcher.isValidSpawn(position: Vector3, player: Player?): (boolean, string?)
	local b = getBoxes()
	for _, box in b.plots do
		if inBox(box, position, true) then
			return false, "plot"
		end
	end
	for _, box in b.robbery do
		if inBox(box, position, false) then
			return false, "robbery"
		end
	end
	local params = worldParams()
	local hit = Workspace:Raycast(position, Vector3.new(0, -Constants.GROUND_PROBE, 0), params)
	if not hit or not isGround(hit.Instance) then
		return false, "ground"
	end
	if not player then
		return true
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return false, "no character"
	end
	if PoliceDispatcher._inSight(head.Position, position) then
		return false, "sight"
	end
	-- Reachable: a path to the player, or, when no path leads to the player (the robbery interiors are cut
	-- off from the city's navmesh: measured at SlowFoods, door to inside NoPath), to the entrance of the
	-- robbery location they are in, its ExitSpawn marker.
	if not reaches(position, root.Position) then
		local entrance = entranceNear(root.Position)
		if not entrance or not reaches(position, entrance) then
			return false, "path"
		end
	end
	return true
end

-- A valid point in the ring rMin..rMax (horizontal) around `center`, or nil after SPAWN_TRIES.
local function findSpawn(center: Vector3, rMin: number, rMax: number, player: Player): Vector3?
	for _ = 1, Constants.SPAWN_TRIES do
		local angle = math.random() * 2 * math.pi
		local radius = rMin + math.random() * (rMax - rMin)
		local top = Vector3.new(center.X + math.cos(angle) * radius, Constants.SAMPLE_TOP_Y, center.Z + math.sin(angle) * radius)
		local hit = Workspace:Raycast(top, Vector3.new(0, -Constants.SAMPLE_DEPTH, 0), worldParams())
		if hit and isGround(hit.Instance) then
			local position = hit.Position + Vector3.new(0, Constants.SPAWN_HEIGHT, 0)
			if PoliceDispatcher.isValidSpawn(position, player) then
				return position
			end
		end
	end
	return nil
end

-- ===== squads =====

local squads = {} -- [Player] = { [record] = true }; record = { ai, owner }
local leaving = {} -- [record] = time it started leaving
local alarmAnchor = {} -- [Player] = anchor position for that player's next spawn round
local lastSeen = {} -- [Player] = where an officer last saw them
local leavingAi = setmetatable({}, { __mode = "k" }) -- [EnemyAI] = true while leaving: sees nobody for "seen"
local nextTopUp = 0
local toppingUp = false
-- Play-check aid, off by default: when true, every spawn is logged in _spawnLog (last 40).
PoliceDispatcher.debug = false
PoliceDispatcher._spawnLog = {}

local function isWanted(player): boolean
	return (player:GetAttribute("WantedStars") or 0) >= 1
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid.RootPart
	end
	return nil
end

local function isLive(record): boolean
	return not record.ai.destroyed and record.ai.state ~= EnemyAI.State.Dead
end

local function forget(record)
	leaving[record] = nil
	local squad = record.owner and squads[record.owner]
	if squad then
		squad[record] = nil
	end
end

local function spawnOfficer(templateName: string, position: Vector3, owner: Player, alarm: boolean)
	local template = ServerStorage.EnemyTemplates:FindFirstChild(templateName)
	if not template then
		warn(`PoliceDispatcher: no template {templateName}`)
		return
	end
	local character, weapon, config = EnemyRig.build(template, templateName)
	if not character or not weapon then
		return
	end
	local record = { owner = owner }
	config.faction = FACTION
	config.targetFilter = isWanted
	config.preferTarget = function()
		return record.owner
	end
	CollectionService:AddTag(character, "Witness")
	EnemyRig.place(character, weapon, CFrame.new(position), policeFolder())

	local root = rootOf(owner)
	record.ai = EnemyAI.new(character, weapon, root and root.Position or position, function()
		forget(record)
	end, config)
	squads[owner] = squads[owner] or {}
	squads[owner][record] = true

	if not PoliceDispatcher.debug then
		return
	end
	local ownerCharacter = owner.Character
	table.insert(PoliceDispatcher._spawnLog, {
		template = templateName,
		distance = root and (root.Position - position).Magnitude or -1,
		seenAtSpawn = ownerCharacter ~= nil and record.ai:canSee(ownerCharacter),
		alarm = alarm,
		time = os.clock(),
	})
	if #PoliceDispatcher._spawnLog > 40 then
		table.remove(PoliceDispatcher._spawnLog, 1)
	end
end

local function countLive(): number
	local n = 0
	for _, ai in EnemyAI.getLive() do
		if ai.config.faction == FACTION then
			n += 1
		end
	end
	return n
end

local function topUp()
	local requests = {}
	local inSquads = 0
	for _, player in Players:GetPlayers() do
		if isWanted(player) and rootOf(player) then
			local alive = 0
			for record in squads[player] or {} do
				if isLive(record) then
					alive += 1
				end
			end
			inSquads += alive
			table.insert(requests, { player = player, stars = player:GetAttribute("WantedStars"), alive = alive })
		end
	end
	-- Officers outside these squads (leaving ones) still count against the server cap.
	local allowed = SquadPlan.allocate(requests, Constants.POLICE_CAP - (countLive() - inSquads))
	for _, request in requests do
		local player = request.player
		local n = allowed[player] or 0
		-- An alarm sends only the round right after it; with no room now, the next round is a normal top-up.
		local anchor = alarmAnchor[player]
		alarmAnchor[player] = nil
		if n > 0 then
			local police, armed = SquadPlan.target(request.stars)
			for record in squads[player] or {} do
				if isLive(record) then
					if record.ai.character:GetAttribute("EnemyTemplate") == "Armed Police" then
						armed -= 1
					else
						police -= 1
					end
				end
			end
			for _ = 1, n do
				local root = rootOf(player)
				if not root or not isWanted(player) then
					break
				end
				-- Around the robbed location first; where its ring has no valid point (SlowFoods' own box covers
				-- most of it), around the player as for a top-up.
				local position = anchor and findSpawn(anchor, Constants.ALARM_RING_MIN, Constants.ALARM_RING_MAX, player)
				local fromAlarm = position ~= nil
				position = position or findSpawn(root.Position, Constants.TOPUP_RING_MIN, Constants.TOPUP_RING_MAX, player)
				if position then
					local templateName = if police > 0 or armed <= 0 then "Police" else "Armed Police"
					if templateName == "Police" then
						police -= 1
					else
						armed -= 1
					end
					spawnOfficer(templateName, position, player, fromAlarm)
				end
			end
		end
	end
end

-- A wanted, living player this officer can see, or nil.
local function visibleWanted(ai)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and isWanted(player)
			and (root.Position - ai.rootPart.Position).Magnitude <= ai.config.detectionRadius
			and ai:canSee(player.Character)
		then
			return player
		end
	end
	return nil
end

local function seenByAnyPlayer(ai): boolean
	for _, player in Players:GetPlayers() do
		if rootOf(player) and ai:canSee(player.Character) then
			return true
		end
	end
	return false
end

local function startLeaving(record, now: number)
	leaving[record] = now
	record.owner = nil
	local ai = record.ai
	leavingAi[ai] = true
	ai.config.targetFilter = function() return false end -- leaving: engage nobody
	ai:_setState(EnemyAI.State.Patrol) -- not Search: that would walk it to the player's last known spot
	-- Walk away from the nearest player: the patrol picks its next point around this.
	local nearest, best = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local d = root and (root.Position - ai.rootPart.Position).Magnitude
		if d and d < best then
			nearest, best = root, d
		end
	end
	if nearest then
		local away = ai.rootPart.Position - nearest.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 1e-3 then
			away = Vector3.new(1, 0, 0)
		end
		ai.spawnPosition = ai.rootPart.Position + away.Unit * Constants.LEAVE_DISTANCE
		ai:_clearPath()
	end
end

-- Where the police believe `player` is (design section 9), or nil when they have no idea.
local function believedPosition(player: Player, root: BasePart): Vector3?
	if WantedService.knowsWhere(player) then
		-- Inside a robbery building the interior is off the navmesh: go to its entrance.
		return entranceNear(root.Position) or root.Position
	end
	return lastSeen[player]
end

-- Every DISPATCH_TICK: squads of players no longer wanted break up, squads head for the believed position,
-- leavers despawn out of sight; every TOPUP_INTERVAL a top-up runs on its own thread (one at a time, so the
-- cap holds) and cannot stall this loop.
local function tick(now: number)
	local adopted = {} -- applied after the walk: no new keys in squads while iterating it
	for player, squad in squads do
		local root = player.Parent == Players and isWanted(player) and rootOf(player)
		for record in squad do
			if not isLive(record) then
				squad[record] = nil
			elseif not root then
				squad[record] = nil
				local other = visibleWanted(record.ai)
				if other then
					record.owner = other
					table.insert(adopted, record)
				else
					startLeaving(record, now)
				end
			else
				local believed = believedPosition(player, root)
				if believed then
					record.ai.spawnPosition = believed -- a later patrol circles here, not the spawn point
					record.ai:investigate(believed)
				end
			end
		end
		if next(squad) == nil then
			squads[player] = nil
		end
	end
	for _, record in adopted do
		squads[record.owner] = squads[record.owner] or {}
		squads[record.owner][record] = true
	end
	for record, since in leaving do
		if not isLive(record) then
			leaving[record] = nil
		elseif now - since >= Constants.LEAVE_TIMEOUT or not seenByAnyPlayer(record.ai) then
			leaving[record] = nil
			record.ai:destroy()
		end
	end
	if now >= nextTopUp and not toppingUp then
		nextTopUp = now + Constants.TOPUP_INTERVAL
		toppingUp = true
		task.spawn(function()
			local ok, err = pcall(topUp)
			toppingUp = false
			if not ok then
				warn("[PoliceDispatcher] top-up failed: " .. tostring(err))
			end
		end)
	end
end

-- Seen: a live officer, not leaving, within SEEN_RANGE has line of sight to the player, or a live guard
-- within SEEN_RANGE does (Task 3); records where. Strictly a boolean.
function PoliceDispatcher.isSeen(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	for _, ai in EnemyAI.getLive() do
		if ai.config.faction == FACTION
			and not leavingAi[ai]
			and (ai.rootPart.Position - root.Position).Magnitude <= Constants.SEEN_RANGE
			and ai:canSee(player.Character)
		then
			lastSeen[player] = root.Position
			return true
		end
	end
	if Witnesses.guardSees(root.Position) then
		lastSeen[player] = root.Position
		return true
	end
	return false
end

function PoliceDispatcher.start()
	WantedService.setSeenProvider(PoliceDispatcher.isSeen)
	local function forgetPlayer(player)
		alarmAnchor[player] = nil
		lastSeen[player] = nil
	end
	WantedService.Changed:Connect(function(player, heat)
		if heat <= 0 then
			forgetPlayer(player)
		end
	end)
	Players.PlayerRemoving:Connect(forgetPlayer)
	WantedService.Alarmed:Connect(function(locationName: string, players: { Player })
		local markers = Workspace:FindFirstChild(MARKERS[locationName] or "")
		local anchor = markers and markers:FindFirstChild("StatusBillboardAnchor")
		if not anchor then
			return
		end
		for _, player in players do
			alarmAnchor[player] = anchor.Position
		end
		nextTopUp = 0 -- the first squad goes now, not at the next top-up
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(tick, os.clock())
			if not ok then
				warn("[PoliceDispatcher] tick failed: " .. tostring(err))
			end
			task.wait(Constants.DISPATCH_TICK)
		end
	end)
end

return PoliceDispatcher
