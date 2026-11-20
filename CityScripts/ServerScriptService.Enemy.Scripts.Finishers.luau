--!strict
-- Wounded enemies, finishers and stealth takedowns (combat, developer picker 2026-11-20).
-- Wounded: an EnemyAI NPC a player's hit leaves below WOUNDED_FRACTION of its health has a WOUNDED_CHANCE (once per
-- life) to go down on one knee for WOUNDED_SECONDS: stunned (EnemyAI holds fire and stays put), the crouch clip,
-- attribute Wounded on the model. Then it gets up. A player within FINISH_RANGE presses E (CombatActions) to finish
-- it. No crawl: EnemyAI's stun holds WalkSpeed at 0, and the crouch idle clip would only glide (tested 2026-11-20).
-- Takedown: a player crouched (Stealth) within TAKEDOWN_RANGE behind an enemy that has no target (EnemyAI publishes
-- Aware) presses E for a silent kill (no stealth breaker fires).
-- Both kills fire Blaster's Tagged and Eliminated with the player as the shooter, so XP, the cash drop and quest
-- credit come as for any kill, plus BONUS of the kill's XP and cash (Admin.Hooks.killBonus / cashBonus).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EnemyConstants = require(ReplicatedStorage.Enemy.Constants)
local Clips = require(ReplicatedStorage.Combat.Clips)

local Finishers = {}

Finishers.WOUNDED_FRACTION = 0.2
Finishers.WOUNDED_CHANCE = 0.4
Finishers.WOUNDED_SECONDS = 6
Finishers.FINISH_RANGE = 8
Finishers.TAKEDOWN_RANGE = 5
Finishers.BEHIND_DOT = -0.5 -- the enemy's look direction against the direction to the player
Finishers.BONUS = 0.5
Finishers.REQUEST_GAP = 0.4
Finishers.KNEEL_CLIP = "rbxassetid://89055632668771" -- Animate2's crouch idle
Finishers.CHOKE_SECONDS = 1.6
Finishers.CHOKE_BEHIND = 1.6 -- studs behind the enemy's root

-- Pure: is a player at `playerPos` behind an enemy at `enemyCFrame` (within range, outside its view)?
function Finishers.isBehind(enemyCFrame: CFrame, playerPos: Vector3, range: number): boolean
	local offset = playerPos - enemyCFrame.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > range or flat.Magnitude < 0.01 then
		return false
	end
	local look = Vector3.new(enemyCFrame.LookVector.X, 0, enemyCFrame.LookVector.Z)
	return look.Magnitude > 0.01 and look.Unit:Dot(flat.Unit) <= Finishers.BEHIND_DOT
end

local rolled: { [Humanoid]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastRequest: { [Player]: number } = {}
local random = Random.new()

local function aiFor(humanoid: Humanoid): any?
	local EnemyAI = require(ServerScriptService.Enemy.Scripts.EnemyAI) :: any
	for _, ai in EnemyAI.getLive() do
		if ai.humanoid == humanoid then
			return ai
		end
	end
	return nil
end

local function wound(ai: any)
	local humanoid: Humanoid = ai.humanoid
	local character: Model = ai.character
	local root: BasePart = ai.rootPart
	local now = os.clock()
	character:SetAttribute("Wounded", true)
	root:SetAttribute("StunnedUntil", math.max(root:GetAttribute("StunnedUntil") or 0, now + Finishers.WOUNDED_SECONDS))
	local track: AnimationTrack? = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local ok, loaded = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = Finishers.KNEEL_CLIP
			return animator:LoadAnimation(animation)
		end)
		if ok and loaded then
			track = loaded
			-- Action4: at Action it blended with the held weapon's own Action clips and hardly showed, so a wounded
			-- enemy just stood still for 6 s ("Thugs freeze with health left", 2026-11-20).
			loaded.Priority = Enum.AnimationPriority.Action4
			loaded.Looped = true
			loaded:Play(0.15)
		end
	end
	task.delay(Finishers.WOUNDED_SECONDS, function()
		if track then
			track:Stop(0.2)
		end
		if character.Parent and humanoid.Health > 0 then
			character:SetAttribute("Wounded", nil)
		end
	end)
end

-- Tagged listener: a player's hit that leaves an EnemyAI NPC low may wound it.
local function onTagged(attacker: any, humanoid: any)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") or typeof(humanoid) ~= "Instance" or not humanoid:IsA("Humanoid") then
		return
	end
	if rolled[humanoid] or humanoid.Health <= 0 or humanoid.Health > humanoid.MaxHealth * Finishers.WOUNDED_FRACTION then
		return
	end
	rolled[humanoid] = true
	local ai = aiFor(humanoid)
	if ai and random:NextNumber() < Finishers.WOUNDED_CHANCE then
		wound(ai)
	end
end

local function kill(player: Player, humanoid: Humanoid, kind: string)
	local events = ServerScriptService.Blaster.Events
	local amount = humanoid.Health
	humanoid:TakeDamage(amount)
	events.Tagged:Fire(player, humanoid, amount)
	events.Eliminated:Fire(player, humanoid, amount, kind)
	local Hooks = require(ServerScriptService.Admin.Hooks) :: any
	local character = humanoid.Parent :: Model
	for _, name in { "killBonus", "cashBonus" } do
		local hook = Hooks[name]
		if hook then
			pcall(hook, player, character, Finishers.BONUS)
		end
	end
end

-- The takedown (developer picker 2026-11-20, "Prompt + chokehold"): a CHOKE_SECONDS chokehold from behind, both locked
-- in place (the enemy stunned, both roots anchored, the player CHOKE_BEHIND studs behind it facing the same way), the
-- player's Choker clip and the enemy's Choked clip (Combat.Clips), then the kill. It finishes even if another enemy sees
-- it ("It still finishes").
local function chokehold(player: Player, humanoid: Humanoid, enemyRoot: BasePart, root: BasePart)
	local model = humanoid.Parent :: Model
	local character = root.Parent :: Model
	model:SetAttribute("TakenDown", true)
	enemyRoot:SetAttribute("StunnedUntil", math.max(enemyRoot:GetAttribute("StunnedUntil") or 0, os.clock() + Finishers.CHOKE_SECONDS + 0.3))
	enemyRoot.Anchored = true
	root.Anchored = true
	character:PivotTo(enemyRoot.CFrame * CFrame.new(0, 0, Finishers.CHOKE_BEHIND))
	local tracks: { AnimationTrack } = {}
	for _, pair in { { humanoid, "Choked" }, { character:FindFirstChildOfClass("Humanoid"), "Choker" } } do
		local animator = pair[1] and (pair[1] :: Humanoid):FindFirstChildOfClass("Animator")
		local track = animator and Clips.track(animator, pair[2] :: string, {})
		if track then
			track.Looped = pair[2] == "Choked"
			track:Play(0.1)
			table.insert(tracks, track)
		end
	end
	task.delay(Finishers.CHOKE_SECONDS, function()
		for _, track in tracks do
			track:Stop(0.15)
		end
		if root.Parent then
			root.Anchored = false
		end
		if enemyRoot.Parent then
			enemyRoot.Anchored = false
		end
		model:SetAttribute("TakenDown", nil)
		if humanoid.Health > 0 then
			kill(player, humanoid, "Takedown")
		end
	end)
end

-- E from CombatActions: kind "Finish" or "Takedown" on `model`. Checked here; true when it killed.
function Finishers.request(player: Player, model: unknown, kind: unknown): boolean
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < Finishers.REQUEST_GAP then
		return false
	end
	lastRequest[player] = now
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not CollectionService:HasTag(model, EnemyConstants.ENEMY_TAG) then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local enemyRoot = model.PrimaryPart
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local own = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and enemyRoot and root and own) or humanoid.Health <= 0 or own.Health <= 0 then
		return false
	end
	if model:GetAttribute("TakenDown") == true or character:GetAttribute("TakingDown") == true then
		return false -- one at a time
	end
	if kind == "Finish" then
		if model:GetAttribute("Wounded") ~= true or (enemyRoot.Position - root.Position).Magnitude > Finishers.FINISH_RANGE then
			return false
		end
	elseif kind == "Takedown" then
		local Stealth = require(ServerScriptService.Movement.Scripts.Stealth) :: any
		local ai = aiFor(humanoid)
		if not (Stealth.isCrouched(player) and ai and ai.target == nil and Finishers.isBehind(enemyRoot.CFrame, root.Position, Finishers.TAKEDOWN_RANGE)) then
			return false
		end
	else
		return false
	end
	if kind == "Takedown" then
		(character :: Model):SetAttribute("TakingDown", true)
		task.delay(Finishers.CHOKE_SECONDS, function()
			(character :: Model):SetAttribute("TakingDown", nil)
		end)
		chokehold(player, humanoid, enemyRoot, root)
		return true
	end
	kill(player, humanoid, kind :: string)
	return true
end

local started = false
function Finishers.start()
	if started then
		return
	end
	started = true
	ServerScriptService.Blaster.Events.Tagged.Event:Connect(onTagged)
	ReplicatedStorage.Combat.Remotes.Finish.OnServerEvent:Connect(function(player: Player, model: unknown, kind: unknown)
		Finishers.request(player, model, kind)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Finishers
