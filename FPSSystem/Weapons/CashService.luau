-- Cash currency: native leaderstats (shows automatically in the default Roblox leaderboard, no
-- custom HUD needed), plus tiered cash DROPS on enemy kills -- the only way to earn cash today.
--
-- Kills no longer credit Cash directly. Instead a fraction of kills drop a physical, pickupable
-- object whose value depends on how dangerous the dying enemy was.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local Constants = require(ReplicatedStorage.Enemy.Constants)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)
local Schema = require(ReplicatedStorage.Persistence.Schema)

local cashTemplate = ServerStorage:WaitForChild("Cash")

-- Placeholders, not balance: tune freely (by editing Schema.template.cash, the single source of
-- truth -- see that file's comment). This used to be a local literal here, DEBUG-overridden to
-- 10000 for buy-testing new weapons, but that override stopped meaning anything once hydrate
-- (below) always governs Cash.Value for any player with a profile: a fresh profile's cash comes
-- from this exact same template value, so the two could never have been allowed to drift anyway.
local STARTING_CASH = Schema.template.cash
local DROP_CHANCE = 0.3
local DESPAWN_TIME = 10
local IMPLODE_TIME = 0.4
local IMPLODE_SIZE = Vector3.new(0.05, 0.05, 0.05)
local CASH_VALUES = {
	Melee = 20,
	Pistol = 35,
	AutoRifle = 50,
}
local PROMPT_MAX_DISTANCE = 8
local COLLECT_SOUND_ID = "rbxassetid://127722178646940"
local COLLECT_SOUND_LINGER = 2 -- seconds the sound may keep playing after the model is gone
local DROPS_FOLDER_NAME = "CashDrops"

-- The guard is per-VALUE, not per-folder. LevelingService also puts a value in this same shared
-- leaderstats folder, and sibling scripts in ServerScriptService have no guaranteed init order -- so
-- a folder-level guard would silently skip creating Cash whenever LevelingService happened to make
-- the folder first.
local function onPlayerAdded(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = STARTING_CASH
		cash.Parent = leaderstats
	end

	-- Mirrors every future change to Cash.Value into the profile, wherever it comes from: the pickup
	-- below, LevelingService's level-up bonus, WeaponShopService/WeaponUpgradeService purchases,
	-- QuestService rewards, MonetizationService grants. One listener here is the only way to cover all
	-- of those without touching five other files for a single shared IntValue. Wired unconditionally
	-- (outside the `if not cash` branch), so it attaches even when `hydrate` below created Cash first --
	-- ordering between this handler and the gateway's hydrator phase is not guaranteed.
	--
	-- Safe during hydration too: ProfileGateway.mirror no-ops until the profile is bound, which happens
	-- strictly after every hydrator finishes, so a hydrate-triggered Value change firing this listener
	-- cannot race a real mirror write with un-hydrated data.
	cash:GetPropertyChangedSignal("Value"):Connect(function()
		ProfileGateway.mirror(player, function(data)
			data.cash = cash.Value
		end)
	end)
end

-- Restores the persisted balance instead of STARTING_CASH -- a returning player must not be handed
-- the starting amount again. Registered as a hydrator (bottom of file), so it runs before the profile
-- is bound and may run before or after onPlayerAdded above (order between the two is not guaranteed):
-- it creates leaderstats/Cash itself if onPlayerAdded hasn't yet, or overwrites the value if it has.
local function hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = leaderstats
	end
	cash.Value = profile.Data.cash
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

ProfileGateway.registerHydrator(hydrate)

-- Determines the dying enemy's difficulty tier from the weapon it was actually holding, reusing the
-- same attributes that already distinguish weapon behaviour everywhere else in this codebase
-- (infiniteAmmo for melee, fireMode for the rest) rather than hardcoding a list of enemy template
-- names -- a future 7th enemy type is tiered correctly with no change here.
local function getEnemyTier(character: Model): string
	local weapon = character:FindFirstChildOfClass("Tool")
	if not weapon then
		return "Pistol" -- reasonable middle tier if somehow unarmed
	end
	if weapon:GetAttribute(BlasterConstants.INFINITE_AMMO_ATTRIBUTE) then
		return "Melee"
	end
	if weapon:GetAttribute(BlasterConstants.FIRE_MODE_ATTRIBUTE) == BlasterConstants.FIRE_MODE.AUTO then
		return "AutoRifle"
	end
	return "Pistol"
end

local function getDropsFolder(): Folder
	local folder = Workspace:FindFirstChild(DROPS_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DROPS_FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder :: Folder
end

-- Shrinks every part to near-zero and fades to full transparency, then destroys. Shared by both
-- "player collected it" and "it despawned", so the two look identical.
local function implode(cashModel: Model)
	local tweenInfo = TweenInfo.new(IMPLODE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in cashModel:GetDescendants() do
		if part:IsA("BasePart") then
			-- Stop it colliding while it shrinks, so a player standing on it is not nudged around,
			-- and drop the prompt immediately so a collected pile cannot be re-triggered mid-fade.
			part.CanCollide = false
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
			TweenService:Create(part, tweenInfo, {
				Size = IMPLODE_SIZE,
				Transparency = 1,
			}):Play()
		end
	end
	-- Destroys the whole model, so nothing invisible or zero-sized is left behind either way.
	Debris:AddItem(cashModel, IMPLODE_TIME)
end

-- Plays independently of the cash model's own lifetime: the model is destroyed by `implode` well
-- before a short pickup sound would finish, and a Sound parented to a part that gets Destroyed is
-- cut off immediately regardless of its own Debris timer. Anchoring it to a short-lived throwaway
-- part avoids that.
local function playPickupSound(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "CashPickupSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = COLLECT_SOUND_ID
	sound.Volume = 0.8
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, COLLECT_SOUND_LINGER)
end

local function spawnCashDrop(position: Vector3, value: number)
	local cashModel = cashTemplate:Clone()
	cashModel:PivotTo(CFrame.new(position))

	for _, part in cashModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.ObjectText = `${value}`
	prompt.ActionText = "Take"
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	-- Off, unlike the weapon stations. The prompt's origin is the centre of the cash body, which ends
	-- up resting on the floor and enclosed by its own geometry -- measured: a drop settled on the
	-- ground 4.3 studs from the player, in range and enabled, could not be collected at all with the
	-- default RequiresLineOfSight = true. A small floor collectible cannot afford that check.
	prompt.RequiresLineOfSight = false
	prompt.Parent = cashModel.PrimaryPart

	local collected = false
	prompt.Triggered:Connect(function(player: Player)
		if collected then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if not cash then
			return
		end
		collected = true
		cash.Value += value
		-- Only on collection. The despawn path below deliberately stays silent.
		playPickupSound(cashModel.PrimaryPart.Position)
		implode(cashModel)
	end)

	task.delay(DESPAWN_TIME, function()
		if collected or not cashModel.Parent then
			return
		end
		collected = true -- also blocks a last-instant pickup racing the despawn
		implode(cashModel)
	end)

	-- Under a folder rather than loose in Workspace, matching how Enemies are grouped.
	cashModel.Parent = getDropsFolder()
end

-- Reuses the Eliminated BindableEvent ShotResolver already fires on every kill, so there is no new
-- event and no second place that has to learn what a kill is. It fires as
-- (shooter, humanoid, appliedDamage); the shooter may be a Player or an enemy character Model.
local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated
eliminatedEvent.Event:Connect(function(shooter: Player | Model, humanoid: Humanoid)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end

	-- Only enemies drop cash, never another player, so this cannot be farmed via PvP.
	local character = humanoid.Parent
	if not (character and CollectionService:HasTag(character, Constants.ENEMY_TAG)) then
		return
	end

	if math.random() > DROP_CHANCE then
		return
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	local dropPosition = (upperTorso and (upperTorso :: BasePart).Position)
		or (character :: Model):GetPivot().Position

	spawnCashDrop(dropPosition, CASH_VALUES[getEnemyTier(character :: Model)])
end)
