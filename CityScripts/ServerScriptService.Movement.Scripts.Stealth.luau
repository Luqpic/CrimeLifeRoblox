--!strict
-- Crouch stealth (developer, 2026-11-20 evening; picker "Strong"): crouched among objects a player is noticed only
-- within HIDDEN_RANGE, crouched in the open within CROUCHED_RANGE, standing as before (criminals' detection radius,
-- police SEEN_RANGE). "Among objects" is COVER_SIDES of 8 waist-high directions blocked within COVER_DISTANCE.
--
-- The server owns it. The client only reports its crouch (PlayerMovement.Crouch, a boolean), and a crouch counts only
-- while the player moves no faster than a crouch walk. Each TICK the state is published on the character: attribute
-- Stealth ("Hidden" / "Crouched" / nil) and StealthRange (the notice range, or nil when standing). EnemyAI,
-- PoliceDispatcher.isSeen, Witnesses.guardSees and GuardPost read StealthRange; the client's StealthVignette reads
-- Stealth.
--
-- Breakers (fully visible for EXPOSE_SECONDS): a gunshot (Blaster, not melee), a hit taken (Blaster's Tagged), an
-- enemy, officer or guard within CLOSE_RANGE facing the player; sprinting or rolling counts as standing.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Stealth = {}

Stealth.HIDDEN_RANGE = 25
Stealth.CROUCHED_RANGE = 70
Stealth.COVER_SIDES = 3
Stealth.COVER_DISTANCE = 6
Stealth.EXPOSE_SECONDS = 3
Stealth.CLOSE_RANGE = 8
Stealth.CLOSE_FACING = 0.5 -- the enemy's look direction within 60 degrees of the player
Stealth.CROUCH_SPEED = 8 -- StarterCharacterScripts.Crouching config.Speed
Stealth.SPEED_MARGIN = 3
Stealth.TICK = 0.25

-- Pure: the state for one player. crouched, sprinting, rolling, exposed: booleans; speed: horizontal studs a second;
-- coverSides: how many of the 8 directions are blocked. Returns state, range.
function Stealth.decide(crouched: boolean, sprinting: boolean, rolling: boolean, speed: number, exposed: boolean, coverSides: number): (string?, number?)
	if not crouched or sprinting or rolling or exposed or speed > Stealth.CROUCH_SPEED + Stealth.SPEED_MARGIN then
		return nil, nil
	end
	if coverSides >= Stealth.COVER_SIDES then
		return "Hidden", Stealth.HIDDEN_RANGE
	end
	return "Crouched", Stealth.CROUCHED_RANGE
end

-- Pure: how many of 8 flat directions from `origin` are blocked within COVER_DISTANCE. cast(origin, direction)
-- returns true when something solid is there.
function Stealth.coverSides(origin: Vector3, cast: (Vector3, Vector3) -> boolean): number
	local blocked = 0
	for i = 0, 7 do
		local angle = i * math.pi / 4
		if cast(origin, Vector3.new(math.cos(angle), 0, math.sin(angle)) * Stealth.COVER_DISTANCE) then
			blocked += 1
		end
	end
	return blocked
end

-- The notice range a watcher uses for this character: min(theirs, the character's StealthRange).
function Stealth.noticeRange(character: Instance?, normal: number): number
	local range = character and character:GetAttribute("StealthRange")
	if typeof(range) == "number" then
		return math.min(normal, range)
	end
	return normal
end

local crouched: { [Player]: boolean } = {}
local exposedUntil: { [Player]: number } = {}

function Stealth.setCrouch(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	crouched[player] = if on then true else nil
end

-- Takedowns (Finishers): the server's crouch for this player.
function Stealth.isCrouched(player: Player): boolean
	return crouched[player] == true
end

function Stealth.expose(player: Player, seconds: number?)
	local untilTime = os.clock() + (seconds or Stealth.EXPOSE_SECONDS)
	exposedUntil[player] = math.max(exposedUntil[player] or 0, untilTime)
end

-- Something solid (terrain, or a visible part that is not part of a character) within the ray. Also EnemyAI's cover
-- search (Enemy.Scripts.Tactics).
function Stealth.solidCast(origin: Vector3, direction: Vector3): boolean
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _ = 1, 4 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return false
		end
		local instance = hit.Instance
		local model = instance:FindFirstAncestorOfClass("Model")
		local isBody = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
		if instance:IsA("Terrain") or (not isBody and instance.Transparency < 0.9) then
			return true
		end
		table.insert(ignore, if isBody then model :: Instance else instance)
	end
	return false
end

-- An enemy, officer or guard within CLOSE_RANGE facing the player.
local function caughtUpClose(root: BasePart): boolean
	local EnemyAI = require(ServerScriptService.Enemy.Scripts.EnemyAI) :: any
	local function facing(watcher: BasePart): boolean
		local offset = root.Position - watcher.Position
		if offset.Magnitude > Stealth.CLOSE_RANGE then
			return false
		end
		return offset.Magnitude < 0.5 or watcher.CFrame.LookVector:Dot(offset.Unit) >= Stealth.CLOSE_FACING
	end
	for _, ai in EnemyAI.getLive() do
		if not ai.destroyed and ai.rootPart and facing(ai.rootPart) then
			return true
		end
	end
	for _, model in CollectionService:GetTagged("Witness") do
		if model:IsA("Model") and model:GetAttribute("WitnessRole") == "Guard" and model.PrimaryPart and facing(model.PrimaryPart) then
			return true
		end
	end
	return false
end

local function publish(character: Model, state: string?, range: number?)
	if character:GetAttribute("Stealth") ~= state then
		character:SetAttribute("Stealth", state)
	end
	if character:GetAttribute("StealthRange") ~= range then
		character:SetAttribute("StealthRange", range)
	end
end

local function evaluate(player: Player, now: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root) then
		return
	end
	if humanoid.Health <= 0 then
		publish(character, nil, nil)
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local rollingUntil = root:GetAttribute("RollingUntil")
	local rolling = typeof(rollingUntil) == "number" and rollingUntil > now
	if crouched[player] and caughtUpClose(root) then
		Stealth.expose(player)
	end
	local exposed = now < (exposedUntil[player] or 0)
	local sides = 0
	if crouched[player] and not exposed then
		sides = Stealth.coverSides(root.Position, Stealth.solidCast)
	end
	local state, range = Stealth.decide(crouched[player] == true, root:GetAttribute("IsSprinting") == true, rolling, speed, exposed, sides)
	publish(character, state, range)
end

local started = false
function Stealth.start()
	if started then
		return
	end
	started = true
	-- A hit taken gives the player away.
	local tagged = ServerScriptService.Blaster.Events:FindFirstChild("Tagged") :: BindableEvent?
	if tagged then
		tagged.Event:Connect(function(_attacker, victim)
			local player = typeof(victim) == "Instance" and victim.Parent and Players:GetPlayerFromCharacter(victim.Parent)
			if player then
				Stealth.expose(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			crouched[player] = nil
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		crouched[player] = nil
		exposedUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(evaluate, player, now)
				if not ok then
					warn("[Stealth] " .. tostring(err))
				end
			end
			task.wait(Stealth.TICK)
		end
	end)
end

return Stealth
