--!strict
-- Second, independent robbery location (spec addendum, 2026-09-06). Reuses
-- every shared/universal system verbatim (BankInstance, ComponentRegistry,
-- ZoneService, Forfeit, AlarmEffects, Net, GamepassManager, CurrencyService,
-- NPCReactionAnimator, AccessBarrier) with its own Config, its own tags,
-- and its own bank/registry/zoneService/forfeit/alarm INSTANCES -- entirely
-- independent RobberyActive/timer/cooldown state from the Bank. Confirmed
-- simpler: no CounterDoor/obby/vault gauntlet -- trigger makes every
-- register immediately robbable.
--
-- Part 1 unification (2026-09-12): the lifecycle scaffolding this script used
-- to spell out by hand -- Forfeit, BankInstance, zones/ZoneService,
-- AlarmEffects, DuffelBagAttachment, the state/late-joiner/claim/duffel/
-- trigger/character/cleanup handlers and the heartbeat -- now lives in the
-- shared Heist.Services.LocationServer. What remains here is what is
-- genuinely SlowFoods' own: its boot invariants, its components, and its own
-- message literals. Ordering is preserved exactly: LocationServer.new() wires
-- the core but connects nothing, this script registers its components onto
-- that bank in the original order, then Start() connects the handlers and
-- spawns the heartbeat.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.RestaurantShared.Config)
local HeistConfig = require(ReplicatedStorage.HeistShared.Config)
local NPCReactionAnimator = require(ReplicatedStorage.SharedSystems.NPCReactionAnimator)
local NPCSpawnManager = require(ReplicatedStorage.SharedSystems.NPCSpawnManager)

local Heist = ServerScriptService.Heist
local ComponentRegistry = require(Heist.ComponentRegistry)
local AccessBarrier = require(Heist.Components.AccessBarrier)
local LocationServer = require(Heist.Services.LocationServer)
local FleeingManager = require(Heist.Components.FleeingManager)
-- Open items pass 2026-11-18: the manager-key layer's wiring (key, Use Key, storage safe), under SlowFoodsKeySpec.
local SlowFoodsKey = require(Heist.Services.SlowFoodsKey)

local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)
local SupplyObject = require(ReplicatedStorage.SharedSystems.SupplyObject)
local LockedDoor = require(ReplicatedStorage.SharedSystems.LockedDoor)
-- Global singleton, shared with Gas2GoServer/HeistServer/SuppliesServer
-- (spec addendum, 2026-09-19) -- see CarryState's own header for why this
-- must never be constructed a second time.
local carryState = require(ReplicatedStorage.SharedSystems.CarryState)

local T = HeistConfig.Tags

-- Boot validation, same discipline as HeistServer: a misconfigured tag must
-- surface the moment you press Play. These counts stay here rather than
-- moving into LocationServer -- they are genuinely SlowFoods' own invariants,
-- and a failure must name this location.
local function requireSingleton(tag: string)
	local tagged = CollectionService:GetTagged(tag)
	assert(#tagged >= 1, string.format("[SlowFoodsServer] required tag %s has no instances", tag))
	return tagged[1]
end

local exitSpawn = requireSingleton(T.SlowFoodsExitSpawn)
assert(ReplicatedStorage.HeistShared:FindFirstChild("DuffelBag")
		and ReplicatedStorage.HeistShared.DuffelBag:IsA("Model")
		and ReplicatedStorage.HeistShared.DuffelBag.PrimaryPart,
	"[SlowFoodsServer] ReplicatedStorage.HeistShared.DuffelBag is missing, not a Model, or has no PrimaryPart")

do
	local zones = CollectionService:GetTagged(T.SlowFoodsZone)
	-- The Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	assert(#zones == 1,
		string.format("[SlowFoodsServer] expected exactly 1 SlowFoodsZone part (Restaurant), found %d", #zones))
	local roles = {}
	for _, z in ipairs(zones) do
		roles[z:GetAttribute("ZoneRole")] = true
	end
	assert(roles.Restaurant,
		"[SlowFoodsServer] SlowFoodsZone parts must cover role Restaurant")
end

-- Not an exact-count invariant (spec addendum, 2026-09-13): barrier count
-- may grow (OpenCloseBarriers now groups multiple parts under one folder,
-- all sharing this tag) without any code change here -- the registry binds
-- one AccessBarrier component per tagged instance regardless of how many
-- there are, same as every other N-per-tag class.
do
	local barriers = CollectionService:GetTagged(T.SlowFoodsAccessBarrier)
	assert(#barriers >= 1,
		string.format("[SlowFoodsServer] expected at least 1 SlowFoodsAccessBarrier part, found %d", #barriers))
end

do
	-- Supplies Robbery (spec addendum, 2026-09-19).
	local supplyBoxes = CollectionService:GetTagged(T.SlowFoodsSupplyBox)
	assert(#supplyBoxes == 2,
		string.format("[SlowFoodsServer] expected exactly 2 SlowFoodsSupplyBox parts, found %d", #supplyBoxes))
end

-- Heist layers 2026-11-17: the fleeing Manager, his spawner, his escape point and the storage safe.
local MANAGER_TAG = "SlowFoodsManager"
do
	local managerSpawners = 0
	for _, spawner in ipairs(CollectionService:GetTagged("NPCSpawner")) do
		if spawner:GetAttribute("NPCTemplate") == "Manager" then managerSpawners += 1 end
	end
	assert(managerSpawners == 1,
		string.format("[SlowFoodsServer] expected exactly 1 Manager NPCSpawner, found %d", managerSpawners))
	assert(ReplicatedStorage.RestaurantShared.ModelTemplates:FindFirstChild("Manager"),
		"[SlowFoodsServer] RestaurantShared.ModelTemplates.Manager is missing")
	local markers = workspace:FindFirstChild("SlowFoodsMarkers")
	local escapePoint = markers and markers:FindFirstChild("ManagerEscapePoint")
	assert(escapePoint and escapePoint:IsA("BasePart"), "[SlowFoodsServer] SlowFoodsMarkers.ManagerEscapePoint is missing")
	assert(workspace.SlowFoods:FindFirstChild("StorageSafe"), "[SlowFoodsServer] Workspace.SlowFoods.StorageSafe is missing")
end

-- The manager-key layer (one key per run, Use Key, the storage safe). Built below the storage-room door;
-- forward-declared for the leave and death hooks and the Manager's onKeyTaken.
local keyLayer

-- The shared skeleton: Net.setup, Forfeit, BankInstance, zones/ZoneService,
-- AlarmEffects (cloned into the Restaurant zone) and DuffelBagAttachment.
-- Connects nothing yet -- see Start() at the bottom.
local location = LocationServer.new({
	name = "SlowFoods",
	config = Config,
	model = workspace:FindFirstChild("SlowFoods"),
	interiorRole = "Restaurant",
	zoneTag = T.SlowFoodsZone,
	markerFolder = "SlowFoodsMarkers",
	exitCFrame = function() return exitSpawn.CFrame end,
	onPlayerRemoving = function(player)
		if keyLayer then keyLayer:Forget(player) end
	end,
	onDied = function(player)
		if keyLayer then keyLayer:OnDied(player) end
	end,
})

local bank = location.bank
require(ServerScriptService.Admin.Hooks).heists.SlowFoods = bank -- admin panel (2026-11-20)
local net = location.net
local notifyRefused = location.notifyRefused

local registry = ComponentRegistry.new({
	config = Config,
	componentDeps = {},
	classes = {
		[T.SlowFoodsAccessBarrier] = AccessBarrier,
	},
})
local byTag = registry:BindAll(bank)

-- Cashiers (spec addendum, 2026-09-09): recloned unconditionally from
-- NPCSpawner placeholders every cooldown-end, same pattern as the Bank's
-- Clerks -- see NPCSpawnManager for why an individually-registered,
-- bind-once component can't support "destroy and replace every cycle".
local cashierSpawnManager = NPCSpawnManager.new({
	template = ReplicatedStorage.RestaurantShared.ModelTemplates.Cashier,
	npcTag = T.Cashier,
	spawnerTemplateValue = "Cashier",
	npcParent = workspace.SlowFoods,
	controllerClass = NPCReactionAnimator,
})
bank:RegisterComponent(cashierSpawnManager)

-- Heist layers 2026-11-17: the Manager flees on the alarm; whoever catches him gets the key.
local managerSpawnManager = NPCSpawnManager.new({
	template = ReplicatedStorage.RestaurantShared.ModelTemplates.Manager,
	npcTag = MANAGER_TAG,
	spawnerTemplateValue = "Manager",
	npcParent = workspace.SlowFoods,
	controllerClass = FleeingManager,
	controllerDeps = {
		bank = bank,
		config = Config,
		escapePoint = workspace.SlowFoodsMarkers.ManagerEscapePoint,
		onKeyTaken = function(player) keyLayer:Give(player) end,
	},
})
bank:RegisterComponent(managerSpawnManager)

-- Cash registers aren't bound through the generic registry: they need extra
-- deps (promptTemplate, onRefused) that would otherwise have to be threaded
-- through componentDeps for every other class too. Built directly instead,
-- and explicitly registered onto the bank so they still get the standard
-- OnSessionStart/Seal dispatch.
local cashRegisters = {}
for _, model in ipairs(CollectionService:GetTagged(T.CashRegister)) do
	local register = RobbableObject.new(model, {
		bank = bank,
		promptTemplate = ReplicatedStorage.RestaurantShared.PromptTemplates.RobRegisterPrompt,
		amount = Config.RegisterRobAmount,
		onRefused = notifyRefused,
		-- Pre-placed on each register's attach part, same static-instance
		-- pattern as Terminal's ButtonClickSound (spec addendum, 2026-09-09).
		playRobSound = function(part) part.RegisterRobSound:Play() end,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
	})
	bank:RegisterComponent(register)
	table.insert(cashRegisters, register)
end

-- Supplies Robbery (spec addendum, 2026-09-19): a bespoke pickup component,
-- not RobbableObject -- see SupplyObject's own header for why. onPickup
-- hands off to the global Carry State the instant the world object hides
-- itself; SupplyObject has no opinion on what "carrying" actually does.
local supplyObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.SlowFoodsSupplyBox)) do
	local supply = SupplyObject.new(model, {
		bank = bank,
		promptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.StealSuppliesPrompt,
		repickupPromptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.RepickupSuppliesPrompt,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
		-- SlowFoods' own bank duffel -- see SupplyObject's own hasDuffel
		-- comment for the cross-location scope limit.
		hasDuffel = function(player) return bank:GetDuffel(player) > 0 end,
		-- Per-location cash-out generalization (spec addendum, 2026-09-2X):
		-- was previously read from a flat global constant everywhere -- now
		-- required per-object. SlowFoods' own value is unchanged (10000).
		cashOutAmount = HeistConfig.SupplyCashOutAmount,
		onRefused = notifyRefused,
		onPickup = function(player, supplyObjectSelf)
			carryState:PickUp(player, ReplicatedStorage.RestaurantShared.ModelTemplates.SupplyFoodBoxTool, supplyObjectSelf)
		end,
	})
	bank:RegisterComponent(supply)
	table.insert(supplyObjects, supply)
end

-- Heist layers 2026-11-17: the key holder's "Use Key" prompt on the storage-room door (wired below
-- the door; built first so the door's onSolved can hide it).
local useKeyPrompt = Instance.new("ProximityPrompt")
useKeyPrompt.Name = "UseKeyPrompt"
useKeyPrompt.ActionText = "Use Key"
useKeyPrompt.ObjectText = "Storage Room"
useKeyPrompt.HoldDuration = 0
useKeyPrompt.KeyboardKeyCode = Enum.KeyCode.F
useKeyPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
useKeyPrompt.MaxActivationDistance = 10
useKeyPrompt.RequiresLineOfSight = false
useKeyPrompt.Enabled = false
useKeyPrompt.Parent = workspace.SlowFoods.LockedDoor["ProximityPart Handle"]

-- LockedDoor lockpicking (spec addendum, 2026-09-2X): one persistent,
-- non-consumable door, already manually placed by the project owner
-- (workspace.SlowFoods.LockedDoor) -- no tag needed, referenced directly by
-- path, same precedent as the Illegal Supplier NPC (a hand-placed singleton,
-- unlike SupplyObject's 2-per-location tagged set).
-- Exact closed/open Position+Orientation supplied by the project owner
-- (spec addendum, 2026-09-2X) -- SlowFoods' own literal values, distinct
-- from Gas2Go's, per this project's own "never share a per-location literal"
-- discipline (see OpenCloseBarrier's own precedent for exactly this class
-- of cross-location copy-paste bug).
local lockedDoor = LockedDoor.new(workspace.SlowFoods.LockedDoor, {
	bank = bank,
	net = net,
	-- Location-scoped GUI-close fix (spec correction, 2026-09-2X): threaded
	-- through every OpenLockpickGui/LockpickUpdate payload so the client can
	-- tell this location's own puzzle apart from another location's session
	-- ending. Matches this location's own BroadcastState literal exactly.
	location = "SlowFoods",
	openCFrame = CFrame.new(76.727, 5.000, 1691.862) * CFrame.Angles(0, math.rad(-90), 0), -- city (phase 3 G12); Robbery: CFrame.new(131.888, 6.062, -293.044) * CFrame.Angles(0, math.rad(180), 0)
	onSolved = function() useKeyPrompt.Enabled = false end,
})
bank:RegisterComponent(lockedDoor)

-- Heist layers 2026-11-17: "Use Key" on the storage-room door (shown to everyone while the door is closed in
-- an Active run, accepted only from the key holder) and the storage safe (open from session start, robbable
-- only by the key holder, paid over the bag cap through AddBonus). Final review 2026-11-18: a carrier can't
-- rob the safe (I1), its 8 s hold is timed on the server (M1) and the server measures the reach (M3).
-- Open items pass 2026-11-18: all of it lives in Heist.Services.SlowFoodsKey, unchanged.
keyLayer = SlowFoodsKey.new({
	bank = bank,
	net = net,
	carryState = carryState,
	notifyRefused = notifyRefused,
	door = lockedDoor,
	useKeyPrompt = useKeyPrompt,
	safeModel = workspace.SlowFoods.StorageSafe,
	safePromptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.RobSafePrompt,
	safeAmount = Config.ManagerSafeAmount,
	playRobSound = function(part) part.SafeRobSound:Play() end,
})
bank:RegisterComponent(keyLayer)
bank:RegisterComponent(keyLayer.storageSafe)

do
	local manifest = registry:Manifest()
	local parts = {}
	for tag, count in pairs(manifest) do
		table.insert(parts, string.format("%s=%d", tag, count))
	end
	table.sort(parts)
	print(string.format("[SlowFoodsServer] SlowFoods booted: %s CashRegister=%d, zones=%d",
		table.concat(parts, " "), #cashRegisters, #location.zones))
end

-- Every component is registered: connect the handlers and start the
-- heartbeat.
location:Start()
