--!strict
-- Third, independent robbery location (spec addendum, 2026-09-14). Follows
-- the SlowFoods style exactly -- no obby/gauntlet/buttons/C4/teleporter
-- sequence, that structure stays Bank-exclusive. Reuses every shared/
-- universal system verbatim (BankInstance, ComponentRegistry, ZoneService,
-- Forfeit, AlarmEffects, RobbableObject, DuffelBagAttachment, Net,
-- GamepassManager, CurrencyService, NPCReactionAnimator, NPCSpawnManager,
-- AccessBarrier) with its own Config, its own tags, and its own bank/
-- registry/zoneService/forfeit/alarm INSTANCES -- entirely independent
-- RobberyActive/timer/cooldown state from both the Bank and SlowFoods.
--
-- Part 1 unification (2026-09-12): the lifecycle scaffolding this script used
-- to spell out by hand -- Forfeit, BankInstance, zones/ZoneService,
-- AlarmEffects, DuffelBagAttachment, the state/late-joiner/claim/duffel/
-- trigger/character/cleanup handlers and the heartbeat -- now lives in the
-- shared Heist.Services.LocationServer. What remains here is what is
-- genuinely Gas2Go's own: its boot invariants, its RobberyAlarmLights pulse
-- fixtures, its components, and its own message literals. Ordering is
-- preserved exactly: LocationServer.new() wires the core but connects
-- nothing, this script registers its components onto that bank in the
-- original order, then Start() connects the handlers and spawns the
-- heartbeat.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Gas2GoShared.Config)
local HeistConfig = require(ReplicatedStorage.HeistShared.Config)
local NPCReactionAnimator = require(ReplicatedStorage.SharedSystems.NPCReactionAnimator)
local NPCSpawnManager = require(ReplicatedStorage.SharedSystems.NPCSpawnManager)

local Heist = ServerScriptService.Heist
local ComponentRegistry = require(Heist.ComponentRegistry)
local AccessBarrier = require(Heist.Components.AccessBarrier)
local LocationServer = require(Heist.Services.LocationServer)

local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)
local SupplyObject = require(ReplicatedStorage.SharedSystems.SupplyObject)
local LockedDoor = require(ReplicatedStorage.SharedSystems.LockedDoor)
-- Global singleton, shared with SlowFoodsServer/HeistServer/SuppliesServer
-- (spec addendum, 2026-09-19) -- see CarryState's own header for why this
-- must never be constructed a second time.
local carryState = require(ReplicatedStorage.SharedSystems.CarryState)

local T = HeistConfig.Tags

-- Boot validation, same discipline as HeistServer/SlowFoodsServer: a
-- misconfigured tag must surface the moment you press Play. These counts stay
-- here rather than moving into LocationServer -- they are genuinely Gas2Go's
-- own invariants, and a failure must name this location.
local function requireSingleton(tag: string)
	local tagged = CollectionService:GetTagged(tag)
	assert(#tagged >= 1, string.format("[Gas2GoServer] required tag %s has no instances", tag))
	return tagged[1]
end

local exitSpawn = requireSingleton(T.Gas2GoExitSpawn)
assert(ReplicatedStorage.HeistShared:FindFirstChild("DuffelBag")
		and ReplicatedStorage.HeistShared.DuffelBag:IsA("Model")
		and ReplicatedStorage.HeistShared.DuffelBag.PrimaryPart,
	"[Gas2GoServer] ReplicatedStorage.HeistShared.DuffelBag is missing, not a Model, or has no PrimaryPart")

do
	local zones = CollectionService:GetTagged(T.Gas2GoZone)
	assert(#zones == 2,
		string.format("[Gas2GoServer] expected exactly 2 Gas2GoZone parts (Station, Claim), found %d", #zones))
	local roles = {}
	for _, z in ipairs(zones) do
		roles[z:GetAttribute("ZoneRole")] = true
	end
	assert(roles.Station and roles.Claim,
		"[Gas2GoServer] Gas2GoZone parts must cover roles Station and Claim")
end

-- Not an exact-count invariant, same reasoning as SlowFoods' own
-- OpenCloseBarriers: Gas2Go's perimeter fence is built from repeating
-- segments (13 sub-models x 2 parts each at the time of writing), a
-- modular count a level designer could reasonably adjust later -- the
-- registry binds one AccessBarrier component per tagged instance
-- regardless of how many there are.
do
	local barriers = CollectionService:GetTagged(T.Gas2GoAccessBarrier)
	assert(#barriers >= 1,
		string.format("[Gas2GoServer] expected at least 1 Gas2GoAccessBarrier part, found %d", #barriers))
end

do
	local registers = CollectionService:GetTagged(T.Gas2GoRegister)
	assert(#registers == 2, string.format("[Gas2GoServer] expected exactly 2 Gas2GoRegister parts, found %d", #registers))
	local atms = CollectionService:GetTagged(T.Gas2GoATM)
	assert(#atms == 1, string.format("[Gas2GoServer] expected exactly 1 Gas2GoATM part, found %d", #atms))
end

do
	-- Supplies Robbery (spec addendum, 2026-09-19).
	local barrels = CollectionService:GetTagged(T.Gas2GoBarrel)
	assert(#barrels == 2, string.format("[Gas2GoServer] expected exactly 2 Gas2GoBarrel parts, found %d", #barrels))
end

-- RobberyAlarmLights (spec addendum, 2026-09-14): Gas2Go's own visual
-- signature, exclusive to this location -- a smooth, synchronized red
-- Brightness pulse via AlarmEffects' pulseLights capability. Collected by
-- descendant/class scan, same pattern already used for the Bank's own
-- alarmLights/templights (see HeistServer's own "0.2FlashAlarm" comment) --
-- not by tag, so this scales automatically if fixtures are added/removed
-- under RobberyAlarmLights later. The old per-fixture Flash.Script loops
-- (one "while true do wait(0.2) ... end" per fixture) were removed --
-- exactly the desync problem AlarmEffects.phaseAt was already introduced to
-- solve for the Bank, now solved here the same way via a single
-- synchronized TweenService cycle instead.
--
-- Collected here rather than inside LocationServer: it is a Gas2Go-only
-- invariant, and the assert must name this location. Handed to the shared
-- alarm through alarmExtras below.
local pulseLights = {}
local alarmLightsModel = workspace.Gas2Go:FindFirstChild("RobberyAlarmLights")
if alarmLightsModel then
	for _, d in ipairs(alarmLightsModel:GetDescendants()) do
		if d:IsA("PointLight") or d:IsA("SpotLight") then
			table.insert(pulseLights, d)
		end
	end
end
assert(#pulseLights >= 1, "[Gas2GoServer] RobberyAlarmLights has no PointLight/SpotLight fixtures")

-- The shared skeleton: Net.setup, Forfeit, BankInstance, zones/ZoneService,
-- AlarmEffects (cloned into the Station zone, plus this location's own
-- pulseLights) and DuffelBagAttachment. Connects nothing yet -- see Start()
-- at the bottom.
local location = LocationServer.new({
	name = "Gas2Go",
	config = Config,
	model = workspace:FindFirstChild("Gas2Go"),
	interiorRole = "Station",
	zoneTag = T.Gas2GoZone,
	exitCFrame = function() return exitSpawn.CFrame end,
	-- Gas2Go alone drives the alarm's pulse capability.
	alarmExtras = {
		pulseLights = pulseLights,
		pulsePhaseDuration = 0.2,
	},
})

local bank = location.bank
local net = location.net
local notifyRefused = location.notifyRefused

local registry = ComponentRegistry.new({
	config = Config,
	componentDeps = {},
	classes = {
		[T.Gas2GoAccessBarrier] = AccessBarrier,
	},
})
local byTag = registry:BindAll(bank)

-- Cashiers (spec addendum, 2026-09-14): recloned unconditionally from
-- NPCSpawner placeholders every cooldown-end, same pattern as the Bank's
-- Clerks and SlowFoods' own Cashiers -- see NPCSpawnManager for why an
-- individually-registered, bind-once component can't support "destroy and
-- replace every cycle". Reuses RestaurantShared's own Cashier rig directly
-- (structurally identical, same three-state animation IDs) rather than a
-- duplicate Gas2Go-specific template.
local cashierSpawnManager = NPCSpawnManager.new({
	template = ReplicatedStorage.RestaurantShared.ModelTemplates.Cashier,
	npcTag = T.Gas2GoCashier,
	spawnerTemplateValue = "Gas2GoCashier",
	npcParent = workspace.Gas2Go,
	controllerClass = NPCReactionAnimator,
})
bank:RegisterComponent(cashierSpawnManager)

-- Cash Registers and the ATM aren't bound through the generic registry
-- (they need extra deps -- promptTemplate, amount, onRefused,
-- playRobSound -- that would otherwise have to be threaded through
-- componentDeps for every other class too). Built directly instead, and
-- explicitly registered onto the bank so they still get the standard
-- OnSessionStart/Seal dispatch. Reuses the SAME prompt templates already
-- built for SlowFoods (RobRegisterPrompt, "Rob register") and the Bank
-- (RobATMPrompt, "Rob ATM machine") verbatim -- the confirmed PromptText for
-- both matches those exactly, so no new near-duplicate template is needed.
local robbableObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.Gas2GoRegister)) do
	local register = RobbableObject.new(model, {
		bank = bank,
		promptTemplate = ReplicatedStorage.RestaurantShared.PromptTemplates.RobRegisterPrompt,
		amount = Config.RegisterRobAmount,
		onRefused = notifyRefused,
		playRobSound = function(part) part.RegisterRobSound:Play() end,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
	})
	bank:RegisterComponent(register)
	table.insert(robbableObjects, register)
end
for _, model in ipairs(CollectionService:GetTagged(T.Gas2GoATM)) do
	local atm = RobbableObject.new(model, {
		bank = bank,
		promptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.RobATMPrompt,
		amount = Config.ATMRobAmount,
		onRefused = notifyRefused,
		playRobSound = function(part) part.ATMRobSound:Play() end,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
	})
	bank:RegisterComponent(atm)
	table.insert(robbableObjects, atm)
end

-- Supplies Robbery (spec addendum, 2026-09-19): a bespoke pickup component,
-- not RobbableObject -- see SupplyObject's own header for why.
local supplyObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.Gas2GoBarrel)) do
	local supply = SupplyObject.new(model, {
		bank = bank,
		promptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.StealSuppliesPrompt,
		repickupPromptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.RepickupSuppliesPrompt,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
		-- Gas2Go's own bank duffel -- see SupplyObject's own hasDuffel comment
		-- for the cross-location scope limit.
		hasDuffel = function(player) return bank:GetDuffel(player) > 0 end,
		-- Per-location cash-out generalization (spec addendum, 2026-09-2X):
		-- was previously read from a flat global constant everywhere -- now
		-- required per-object. Gas2Go's own value is unchanged (10000).
		cashOutAmount = HeistConfig.SupplyCashOutAmount,
		onRefused = notifyRefused,
		onPickup = function(player, supplyObjectSelf)
			carryState:PickUp(player, ReplicatedStorage.RestaurantShared.ModelTemplates.BarrelTool, supplyObjectSelf)
		end,
	})
	bank:RegisterComponent(supply)
	table.insert(supplyObjects, supply)
end

-- LockedDoor lockpicking (spec addendum, 2026-09-2X): one persistent,
-- non-consumable door, already manually placed by the project owner
-- (workspace.Gas2Go.LockedDoor) -- no tag needed, referenced directly by
-- path, same precedent as the Illegal Supplier NPC.
-- Exact closed/open Position+Orientation supplied by the project owner
-- (spec addendum, 2026-09-2X) -- Gas2Go's own literal values, distinct from
-- SlowFoods', per this project's own "never share a per-location literal"
-- discipline (see OpenCloseBarrier's own precedent for exactly this class
-- of cross-location copy-paste bug).
local lockedDoor = LockedDoor.new(workspace.Gas2Go.LockedDoor, {
	bank = bank,
	net = net,
	-- Location-scoped GUI-close fix (spec correction, 2026-09-2X): see
	-- SlowFoodsServer's identical own comment. Matches this location's own
	-- BroadcastState literal exactly.
	location = "Gas2Go",
	openCFrame = CFrame.new(-111.893, 5.539, -337.486) * CFrame.Angles(0, math.rad(90), 0),
})
bank:RegisterComponent(lockedDoor)

do
	local manifest = registry:Manifest()
	local parts = {}
	for tag, count in pairs(manifest) do
		table.insert(parts, string.format("%s=%d", tag, count))
	end
	table.sort(parts)
	print(string.format("[Gas2GoServer] Gas2Go booted: %s Gas2GoRegister=%d Gas2GoATM=%d pulseLights=%d, zones=%d",
		table.concat(parts, " "), #CollectionService:GetTagged(T.Gas2GoRegister), #CollectionService:GetTagged(T.Gas2GoATM),
		#pulseLights, #location.zones))
end

-- Every component is registered: connect the handlers and start the
-- heartbeat.
location:Start()
