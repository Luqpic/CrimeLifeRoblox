-- Builds and maintains the population of AI enemies.
--
-- Spawn points are Parts tagged Constants.SPAWN_POINT_TAG ("EnemySpawnPoint"), matching how this
-- game already marks world instances -- "Target" on the practice dummies, "RayExclude" and
-- "NonStatic" on geometry -- rather than introducing a folder-based convention alongside them.
--
-- Enemies are CLONED from designer-editable rig templates under ServerStorage.EnemyTemplates rather
-- than assembled in code, so what an enemy looks like and what stats it starts with are Studio
-- properties. Duplicating a template, restyling it and editing its attributes produces a new enemy
-- variant with no script changes; see ReplicatedStorage.Enemy.templateConfig for the attributes read.
--
-- Templates live in ServerStorage rather than Workspace deliberately: a template parented into the
-- world would be a live, visible, shootable character standing in the map. They remain ordinary
-- Models, editable in the Explorer like anything else.
--
-- Whatever is cloned has its scripts stripped and its physics ownership pinned to the server: an
-- enemy is a fully server-controlled character with no client input, no camera, no viewmodel and no
-- HUD.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Enemy.Constants)
local EnemyAI = require(script.Parent.EnemyAI)
-- Building a body from a template (scripts stripped, weapon, nameplate, collision group, server
-- ownership) lives in EnemyRig, shared with the police dispatcher (police and wanted, 2026-11-17).
local EnemyRig = require(script.Parent.EnemyRig)

local ENEMIES_FOLDER_NAME = "Enemies"
-- Rig templates live in ServerStorage rather than Workspace: they are design-time source objects, and
-- a template sitting in Workspace would be a live, visible, shootable character standing in the map.
-- They are still ordinary Models, editable in the Explorer like any other instance.
local TEMPLATES_FOLDER_NAME = "EnemyTemplates"
-- How often the population is topped back up to the configured maximum. This is not death polling
-- (the AI reports its own death, see onEnemyDied); it only covers server start-up and spawn attempts
-- that found no valid point.
local TOP_UP_INTERVAL = 2.5
-- How high above a spawn point the rig is placed, so it settles onto the floor instead of into it.
local SPAWN_HEIGHT_OFFSET = 3

-- How far from its spawn point a rig may be placed. Every type has a SINGLE spawn point, so without
-- this the whole roster is stacked on one spot and reads as a cluster standing inside each other --
-- they no longer launch (they are in a no-self-collision group) but they still overlap visually.
-- Scattered over a disc instead, so a group looks like a group.
local SPAWN_SCATTER_RADIUS = 22


-- Keyed by enemy type name (matches a spawn point's EnemyType value, and the template's own Name).
-- A spawn point with no EnemyType child buckets under UNASSIGNED_TYPE -- unused today (every
-- current spawn point has one), kept only as a safe fallback.
local UNASSIGNED_TYPE = "Unassigned"
local aliveCounts: { [string]: number } = {}
-- Spawns that have been committed to but not yet finished, so a burst of top-up ticks cannot
-- overshoot MAX_CONCURRENT_ENEMIES_PER_TYPE part-way through building one.
local pendingCounts: { [string]: number } = {}

local function getAliveCount(enemyType: string): number
	return aliveCounts[enemyType] or 0
end

local function getPendingCount(enemyType: string): number
	return pendingCounts[enemyType] or 0
end

-- Forward declaration: a death schedules the next spawn, and the spawn function is defined below it.
local trySpawn: () -> boolean

local function getEnemiesFolder(): Folder
	local folder = Workspace:FindFirstChild(ENEMIES_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ENEMIES_FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder :: Folder
end

-- A spawn point is valid if no living player is standing too close to it, so enemies never appear on
-- top of someone.
local function isSpawnPointClear(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		local rootPart = humanoid.RootPart
		if rootPart and (rootPart.Position - position).Magnitude < Constants.MIN_SPAWN_DISTANCE_FROM_PLAYER then
			return false
		end
	end
	return true
end

local function getSpawnPointType(point: Instance): string
	local enemyTypeValue = point:FindFirstChild("EnemyType")
	if enemyTypeValue and enemyTypeValue:IsA("StringValue") and enemyTypeValue.Value ~= "" then
		return enemyTypeValue.Value
	end
	return UNASSIGNED_TYPE
end

-- Returns the chosen point, its position, and its resolved enemy type -- callers no longer need
-- to re-read the EnemyType child themselves. A spawn point is only offered as a candidate if its
-- own type has not already reached MAX_CONCURRENT_ENEMIES_PER_TYPE; this is the one place the cap
-- is enforced.
local function pickSpawnPoint(): (Instance?, Vector3?, string?)
	local candidates = {}
	for _, point in CollectionService:GetTagged(Constants.SPAWN_POINT_TAG) do
		local position
		if point:IsA("BasePart") then
			position = point.Position
		elseif point:IsA("Attachment") then
			position = point.WorldPosition
		end
		if not position or not isSpawnPointClear(position) then
			continue
		end

		local enemyType = getSpawnPointType(point)
		if getAliveCount(enemyType) + getPendingCount(enemyType) >= Constants.MAX_CONCURRENT_ENEMIES_PER_TYPE then
			continue -- this type is already at its own cap
		end

		table.insert(candidates, { point = point, position = position, enemyType = enemyType })
	end

	if #candidates == 0 then
		return nil, nil, nil
	end
	local candidate = candidates[math.random(1, #candidates)]
	return candidate.point, candidate.position, candidate.enemyType
end


-- Every rig template registered for spawning: any Model dropped into ServerStorage.EnemyTemplates.
--
-- Adding an enemy variant is therefore a Studio operation with no code change -- duplicate a
-- template, restyle it, edit its attributes -- and this list picks it up automatically.
local function getTemplates(): { Model }
	local folder = ServerStorage:FindFirstChild(TEMPLATES_FOLDER_NAME)
	if not folder then
		return {}
	end
	local templates = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			table.insert(templates, child)
		end
	end
	return templates
end


local function onEnemyDied(enemy)
	-- The AI's own Dead state calls this. The spawner never watches enemy health itself.
	--
	-- Only accounting happens here. Destroying the corpse belongs to the death presentation and is
	-- owned by the ragdoll in EnemyAI:_enterDead, so that how long a body lies on the floor and when
	-- its replacement spawns are independent of each other.
	local enemyType = (enemy.character:GetAttribute("EnemyTemplate") :: string?) or UNASSIGNED_TYPE
	aliveCounts[enemyType] = math.max(getAliveCount(enemyType) - 1, 0)

	task.delay(Constants.RESPAWN_DELAY, function()
		-- trySpawn re-checks the cap and the minimum distance, so a queued respawn can never
		-- overshoot.
		trySpawn()
	end)
end

function trySpawn(): boolean
	-- No global cap check here any more: the cap is enforced per candidate inside pickSpawnPoint.
	local spawnPoint, spawnPosition, enemyType = pickSpawnPoint()
	if not spawnPoint or not spawnPosition or not enemyType then
		return false
	end

	local templates = getTemplates()
	if #templates == 0 then
		warn(
			`EnemySpawner: no rig templates found. Put a Model containing a Humanoid under `
				.. `ServerStorage.{TEMPLATES_FOLDER_NAME}.`
		)
		return false
	end

	-- A spawn point carrying an EnemyType StringValue child only ever produces the template of that
	-- name, so each zone stays a single-type test area instead of every zone drawing from the whole
	-- pool. A point with no EnemyType keeps the original behaviour: any template may spawn there.
	--
	-- A child Value object rather than an attribute: it shows up in the Explorer tree next to the
	-- spawn point it configures, so what a zone spawns is visible without selecting the Part.
	local eligibleTemplates = templates
	if enemyType ~= UNASSIGNED_TYPE then
		eligibleTemplates = {}
		for _, template in templates do
			if template.Name == enemyType then
				table.insert(eligibleTemplates, template)
			end
		end
		if #eligibleTemplates == 0 then
			warn(`EnemySpawner: no template named "{enemyType}" for spawn point {spawnPoint:GetFullName()}`)
			return false
		end
	end

	pendingCounts[enemyType] = getPendingCount(enemyType) + 1

	-- The character comes from a designer-editable rig now, not from code.
	local template = eligibleTemplates[math.random(1, #eligibleTemplates)]
	local character, weapon, config = EnemyRig.build(template, enemyType)
	if not character or not weapon then
		pendingCounts[enemyType] -= 1
		return false
	end

	-- sqrt on the radius keeps the distribution even across the disc; sampling the radius linearly
	-- would bunch rigs toward the centre, which is the clustering this is meant to avoid.
	local scatterAngle = math.random() * math.pi * 2
	local scatterRadius = SPAWN_SCATTER_RADIUS * math.sqrt(math.random())
	local scatter = Vector3.new(math.cos(scatterAngle) * scatterRadius, 0, math.sin(scatterAngle) * scatterRadius)
	EnemyRig.place(
		character,
		weapon,
		CFrame.new(spawnPosition + scatter + Vector3.new(0, SPAWN_HEIGHT_OFFSET, 0)),
		getEnemiesFolder()
	)

	EnemyAI.new(character, weapon, spawnPosition, onEnemyDied, config)

	pendingCounts[enemyType] -= 1
	aliveCounts[enemyType] = getAliveCount(enemyType) + 1
	return true
end

local function initialize()
	if #getTemplates() == 0 then
		warn(
			`EnemySpawner: no rig templates. Put a Model containing a Humanoid under `
				.. `ServerStorage.{TEMPLATES_FOLDER_NAME} -- duplicate one to add an enemy variant.`
		)
	end

	if #CollectionService:GetTagged(Constants.SPAWN_POINT_TAG) == 0 then
		warn(
			`EnemySpawner: no spawn points found. Tag Parts or Attachments in Workspace with `
				.. `"{Constants.SPAWN_POINT_TAG}" to place enemies.`
		)
	end

	-- Edit is the truth (developer rule, 2026-11-20): each spawn point carries a rig of its enemy type in Edit, standing
	-- on the pad. The pad moves under that rig (ServerScriptService.Heist.EditRig) and the rig leaves the world before
	-- anything spawns, so moving the rig in Edit moves where that type spawns. The enemies still come from the templates.
	local EditRig = require(game:GetService("ServerScriptService").Heist.EditRig)
	for _, point in CollectionService:GetTagged(Constants.SPAWN_POINT_TAG) do
		if point:IsA("BasePart") then
			EditRig.take(point, point.Size.Y / 2 + 3.2) -- a template rig's root stands 3.2 over its feet
		end
	end

	-- Top up to the configured maximum. Covers server start-up and any spawn attempt that found no
	-- valid point (every player was standing too close, for instance); deaths themselves are
	-- reported by the AI rather than discovered here.
	-- Unconditional: different types sit at different fill levels simultaneously, so there is no
	-- single boolean to pre-check any more. pickSpawnPoint returns nothing once every type is full,
	-- so this stays just as cheap when the roster is saturated.
	while true do
		trySpawn()
		task.wait(TOP_UP_INTERVAL)
	end
end

initialize()
