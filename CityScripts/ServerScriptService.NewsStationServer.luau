--!strict
-- Fourth, independent robbery location (spec addendum, 2026-09-2X). Follows
-- the SlowFoods/Gas2Go style for its base mechanics (no obby/gauntlet/C4/
-- teleporter sequence), plus RobbableObject (Register/ATM), SupplyObject
-- (ExpensiveCamera), LockedDoor, the DeadlyOil hazard, LightSphere fade, and
-- MasterComputer's own fully server-authoritative Word Scramble hacking chain
-- plus the 3 Safe.Safe props it shares one session code with.
--
-- Part 1 unification (2026-09-12): the lifecycle scaffolding this script used
-- to spell out by hand -- Forfeit, BankInstance, zones/ZoneService,
-- AlarmEffects, DuffelBagAttachment, the state/late-joiner/claim/duffel/
-- trigger/character/cleanup handlers and the heartbeat -- now lives in the
-- shared Heist.Services.LocationServer. What remains here is what is
-- genuinely NewsStation's own: its boot invariants, its oil hazard, its
-- components, its Safe/MasterComputer code sharing, its LightSphere fade, and
-- its own message literals. Ordering is preserved exactly: LocationServer.new()
-- wires the core but connects nothing, this script registers its components
-- onto that bank in the original order, then Start() connects the handlers and
-- spawns the heartbeat.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.NewsStationShared.Config)
local HeistConfig = require(ReplicatedStorage.HeistShared.Config)
local NPCReactionAnimator = require(ReplicatedStorage.SharedSystems.NPCReactionAnimator)
local NPCSpawnManager = require(ReplicatedStorage.SharedSystems.NPCSpawnManager)
local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)
local SupplyObject = require(ReplicatedStorage.SharedSystems.SupplyObject)
local LockedDoor = require(ReplicatedStorage.SharedSystems.LockedDoor)
-- Global singleton, shared with SlowFoodsServer/Gas2GoServer/HeistServer/
-- SuppliesServer -- see CarryState's own header for why this must never be
-- constructed a second time.
local carryState = require(ReplicatedStorage.SharedSystems.CarryState)

local Heist = ServerScriptService.Heist
local ComponentRegistry = require(Heist.ComponentRegistry)
local AccessBarrier = require(Heist.Components.AccessBarrier)
local Safe = require(Heist.Components.Safe)
local MasterComputer = require(Heist.Components.MasterComputer)
local LaserHazard = require(Heist.Components.LaserHazard)
local LocationServer = require(Heist.Services.LocationServer)
-- Security guards (police and wanted Task 3, 2026-11-17): the Bank's GuardPost component on NewsStation's
-- own posts, built by this script's registry exactly as HeistServer builds the Bank's.
local GuardPost = require(Heist.Components.GuardPost)
local WantedConstants = require(ReplicatedStorage.Wanted.Constants)
-- Broadcast takeover (heist layers 2026-11-17).
local BroadcastDesk = require(Heist.Components.BroadcastDesk)
local WantedService = require(ServerScriptService.Wanted.WantedService)

-- NewsStation carries its OWN tag table, unlike SlowFoods/Gas2Go which both
-- read HeistConfig.Tags. The weapon tag is the exception -- there is no
-- NewsStation-specific one, so the shared LocationServer's own
-- HeistConfig.Tags.Weapon check is the same check this script used to make.
local T = Config.Tags

-- Boot validation, same discipline as every other location script. These
-- counts stay here rather than moving into LocationServer -- they are
-- genuinely NewsStation's own invariants, and a failure must name this
-- location.
do
	local zones = CollectionService:GetTagged(T.NewsStationZone)
	-- The Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	assert(#zones == 1,
		string.format("[NewsStationServer] expected exactly 1 NewsStationZone part (Newsroom), found %d", #zones))
	local roles = {}
	for _, z in ipairs(zones) do
		roles[z:GetAttribute("ZoneRole")] = true
	end
	assert(roles.Newsroom,
		"[NewsStationServer] NewsStationZone parts must cover role Newsroom")
end

do
	local barriers = CollectionService:GetTagged(T.NewsStationAccessBarrier)
	assert(#barriers >= 1,
		string.format("[NewsStationServer] expected at least 1 NewsStationAccessBarrier part, found %d", #barriers))
end

do
	local npcSpawners = 0
	for _, spawner in ipairs(CollectionService:GetTagged("NPCSpawner")) do
		if spawner:GetAttribute("NPCTemplate") == "NewsWorker" then npcSpawners += 1 end
	end
	assert(npcSpawners == 2, string.format("[NewsStationServer] expected exactly 2 NewsWorker NPCSpawner placeholders, found %d", npcSpawners))
end

do
	local registers = CollectionService:GetTagged(T.NewsStationRegister)
	assert(#registers == 2, string.format("[NewsStationServer] expected exactly 2 NewsStationRegister parts, found %d", #registers))
	local atms = CollectionService:GetTagged(T.NewsStationATM)
	assert(#atms == 1, string.format("[NewsStationServer] expected exactly 1 NewsStationATM part, found %d", #atms))
end

do
	local cameras = CollectionService:GetTagged(T.NewsStationCamera)
	assert(#cameras == 2, string.format("[NewsStationServer] expected exactly 2 NewsStationCamera parts, found %d", #cameras))
end

do
	local posts = CollectionService:GetTagged(T.NewsStationGuardPost)
	assert(#posts == WantedConstants.NEWSSTATION_GUARDS, string.format("[NewsStationServer] expected exactly %d NewsStationGuardPost parts, found %d", WantedConstants.NEWSSTATION_GUARDS, #posts))
end

do
	local oilParts = CollectionService:GetTagged(T.NewsStationOilHazard)
	assert(#oilParts == 15, string.format("[NewsStationServer] expected exactly 15 NewsStationOilHazard parts, found %d", #oilParts))
end

do
	local safes = CollectionService:GetTagged(T.NewsStationSafe)
	assert(#safes == 3, string.format("[NewsStationServer] expected exactly 3 NewsStationSafe parts, found %d", #safes))
end

-- DeadlyOil: a static, always-armed touch hazard -- CycleTime=0 (already
-- set on the real parts) makes LaserHazard.isArmedAt/transparencyAt return
-- "always armed, always solid" with zero code changes to LaserHazard.lua
-- itself. Same debounced-per-(player,source) damage pattern as
-- HeistServer's own applyLaserDamage, replicated here since neither
-- SlowFoods nor Gas2Go has ever needed a hazard component.
--
-- Declared above LocationServer.new(): recentLaserHit is cleared by this
-- location's own onPlayerRemoving hook, and applyLaserDamage is handed to
-- the registry's componentDeps further down.
local recentLaserHit = {} -- player -> {[source] = os.clock() of last hit}
local function applyLaserDamage(player, source)
	local nowClock = os.clock()
	local perPlayer = recentLaserHit[player]
	if not perPlayer then
		perPlayer = {}
		recentLaserHit[player] = perPlayer
	end
	local last = perPlayer[source]
	if last and (nowClock - last) < HeistConfig.LaserDamageCooldown then return end
	perPlayer[source] = nowClock

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(humanoid.MaxHealth * HeistConfig.LaserDamageFraction)
	end
end

-- Forward-declared so the LocationServer hooks below can close over them:
-- each is built further down, but the hooks only ever fire after Start(),
-- by which point every one of these is assigned.
local oilHazards = {}
local guardPosts = {}
local masterComputer
local broadcastDesk
local lastNewsStationSafeSubmit = {}
local fadeLightSphere

-- The shared skeleton: Net.setup, Forfeit, BankInstance, zones/ZoneService,
-- AlarmEffects (cloned into the Newsroom zone) and DuffelBagAttachment.
-- Connects nothing yet -- see Start() at the bottom.
local location = LocationServer.new({
	name = "NewsStation",
	config = Config,
	model = workspace:FindFirstChild("NewsStation"),
	interiorRole = "Newsroom",
	zoneTag = T.NewsStationZone,
	markerFolder = "NewsStationMarkers",
	-- Resolved lazily on every call with a CFrame.new() fallback, unlike
	-- SlowFoods/Gas2Go which resolve their exit spawn eagerly at boot and
	-- assert it exists. A deliberately different failure mode, preserved.
	exitCFrame = function()
		local exitSpawn = CollectionService:GetTagged(T.NewsStationExitSpawn)[1]
		return exitSpawn and exitSpawn.CFrame or CFrame.new()
	end,
	-- LightSphere is NOT AlarmEffects' templight mechanism and cannot go
	-- through alarmExtras -- see the fadeLightSphere block below for why.
	onActive = function() fadeLightSphere(true) end,
	onSealed = function() fadeLightSphere(false) end,
	-- NewsStation is the only location with a hazard to sweep.
	heartbeatExtras = function()
		for _, oil in ipairs(oilHazards) do
			oil:Update()
		end
		-- Guards act only while the session is Active (GuardPost:Update), as at the Bank.
		for _, post in ipairs(guardPosts) do
			post:Update()
		end
		broadcastDesk:Update()
	end,
	-- Per-player state the shared skeleton doesn't know about.
	onPlayerRemoving = function(player)
		masterComputer:Forget(player)
		broadcastDesk:Forget(player)
		recentLaserHit[player] = nil
		lastNewsStationSafeSubmit[player] = nil
	end,
	-- Leftovers (2026-11-18): a Go Live hold begun before a death is not honoured after it.
	onDied = function(player) broadcastDesk:Forget(player) end,
})

local bank = location.bank
local net = location.net
local notifyRefused = location.notifyRefused

local registry = ComponentRegistry.new({
	config = Config,
	componentDeps = {
		onContact = applyLaserDamage,
		-- Guards deal damage the Bank's way (HeistServer's damage dep).
		damage = function(player, amount)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then humanoid:TakeDamage(amount) end
		end,
	},
	classes = {
		[T.NewsStationAccessBarrier] = AccessBarrier,
		[T.NewsStationOilHazard] = LaserHazard,
		[T.NewsStationGuardPost] = GuardPost,
	},
})
local byTag = registry:BindAll(bank)
oilHazards = byTag[T.NewsStationOilHazard] or {}
guardPosts = byTag[T.NewsStationGuardPost] or {}

-- Cash Registers and the ATM aren't bound through the generic registry (they
-- need extra deps -- promptTemplate, amount, onRefused, playRobSound -- that
-- would otherwise have to be threaded through componentDeps for every other
-- class too). Built directly instead, and explicitly registered onto the bank
-- so they still get the standard OnSessionStart/Seal dispatch. Reuses the SAME
-- prompt templates already built for SlowFoods (RobRegisterPrompt) and the
-- Bank (RobATMPrompt) verbatim -- same precedent as Gas2GoServer's own
-- registers/ATM.
local robbableObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.NewsStationRegister)) do
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
for _, model in ipairs(CollectionService:GetTagged(T.NewsStationATM)) do
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

-- Supplies Robbery (ExpensiveCamera): a bespoke pickup component, not
-- RobbableObject -- see SupplyObject's own header for why.
local supplyObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.NewsStationCamera)) do
	local supply = SupplyObject.new(model, {
		bank = bank,
		promptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.StealSuppliesPrompt,
		repickupPromptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.RepickupSuppliesPrompt,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
		-- NewsStation's own bank duffel -- see SupplyObject's own hasDuffel
		-- comment for the cross-location scope limit.
		hasDuffel = function(player) return bank:GetDuffel(player) > 0 end,
		-- Per-location cash-out generalization: NewsStation's own ExpensiveCamera
		-- value, distinct from SlowFoods/Gas2Go's own 10000.
		cashOutAmount = 20000,
		onRefused = notifyRefused,
		onPickup = function(player, supplyObjectSelf)
			carryState:PickUp(player, ReplicatedStorage.NewsStationShared.ModelTemplates.ExpensiveCameraTool, supplyObjectSelf)
		end,
	})
	bank:RegisterComponent(supply)
	table.insert(supplyObjects, supply)
end

-- NewsWorkers: recloned unconditionally from NPCSpawner placeholders every
-- cooldown-end, same pattern as every other location's own cashier/clerk-
-- equivalent NPC.
local newsWorkerSpawnManager = NPCSpawnManager.new({
	template = ReplicatedStorage.NewsStationShared.ModelTemplates.NewsWorker,
	npcTag = T.NewsWorker,
	spawnerTemplateValue = "NewsWorker",
	npcParent = workspace.NewsStation,
	controllerClass = NPCReactionAnimator,
})
bank:RegisterComponent(newsWorkerSpawnManager)

-- LockedDoor lockpicking: one persistent, non-consumable door, already
-- manually placed by the project owner (workspace.NewsStation.LockedDoor).
-- Exact closed/open Position+Orientation supplied by the project owner --
-- this door is a pure in-place rotation (no translation): the open state
-- keeps the SAME position as the closed state, only the orientation
-- changes ((0,180,0) closed -> (0,-45,0) open). Gives the full rotary-
-- needle puzzle (orbiting needle, shrinking success zone, +/-25% progress,
-- needle-reset-and-shake-on-fail, all 3 sound cues, ProximityPart Handle-
-- mounted prompt) entirely for free -- LockedDoor.lua itself needs zero
-- changes, this is purely wiring.
local lockedDoor = LockedDoor.new(workspace.NewsStation.LockedDoor, {
	bank = bank,
	net = net,
	location = "NewsStation",
	openCFrame = CFrame.new(-672.500, 17.775, 1005.252) * CFrame.Angles(0, math.rad(45), 0), -- city (phase 3 G12); Robbery: CFrame.new(-231.65239, 17.775013, -375.499969) * CFrame.Angles(0, math.rad(-45), 0)
})
bank:RegisterComponent(lockedDoor)

-- MasterComputer: a fully server-authoritative hacking chain, built directly
-- against the one pre-placed workspace.NewsStation.MasterComputer model (no
-- tag needed, same singleton-by-path precedent as LockedDoor above). Owns the
-- ONE shared per-session 4-digit code the 3 Safe.Safe props below all validate
-- guesses against -- same "one shared code, independently-crackable safes"
-- shape as the Bank's own SafeCode/Safe pairing, just with the code source
-- being MasterComputer itself rather than a dedicated SafeCode instance
-- (there is no separate physical code-combination display here to own).
-- Broadcast takeover (heist layers 2026-11-17): the first breach arms the desk; one "Go Live" puts
-- the station on air for Config.BroadcastSeconds of air time held by participants at the desk.
-- Final review I1 (2026-11-18): carriers can't go live and are not paid. Leftovers (2026-11-18): a
-- bystander's or carrier's press is told why; the go-live toast is gone (the city card already says it,
-- and the desk counts down).
broadcastDesk = BroadcastDesk.new(workspace.NewsStation.BroadcastDesk, {
	bank = bank,
	config = Config,
	isBlocked = function(player) return carryState:IsCarrying(player) end,
	onRefused = function(player, reason)
		if reason == "not_participant" or reason == "carrying_supplies" then notifyRefused(player, reason) end
	end,
	onLive = function(player)
		net:NotifyBroadcastHijacked(player.Name)
		for _, participant in ipairs(bank:GetParticipants()) do
			local heat = WantedService.getHeat(participant)
			if heat < Config.BroadcastHeatFloor then
				WantedService.addHeat(participant, Config.BroadcastHeatFloor - heat, "broadcast")
			end
		end
		for _, post in ipairs(guardPosts) do
			post:Alert()
		end
	end,
	onComplete = function(players)
		for _, player in ipairs(players) do
			if bank:AddBonus(player, Config.BroadcastPayout) then
				net:Toast(player, string.format("Broadcast complete: %d added to your bag.", Config.BroadcastPayout))
			end
		end
	end,
})
bank:RegisterComponent(broadcastDesk)

masterComputer = MasterComputer.new(workspace.NewsStation.MasterComputer, {
	bank = bank,
	net = net,
	onBreached = function() broadcastDesk:Arm() end,
})
bank:RegisterComponent(masterComputer)

-- The 3 real Safe.Safe props: same shared Safe mechanic as the Bank's own,
-- reusing HeistShared's own RobSafePrompt template verbatim. safeId is offset
-- by 1000 (not 0/1-based like HeistServer's own counter) -- both scripts
-- independently register their own OnSafeCodeSubmitted handler on the SAME
-- shared SubmitSafeCode remote (Net.setup() is idempotent, every location
-- shares one Remotes folder), so a Bank safeId (0/1) and a NewsStation safeId
-- must never collide; each handler below no-ops for any safeId not in its own
-- table.
local newsStationSafeById = {}
local newsStationSafeObjects = {}
do
	local nextId = 1000
	for _, model in ipairs(CollectionService:GetTagged(T.NewsStationSafe)) do
		nextId += 1
		local safeId = nextId
		local safe = Safe.new(model, {
			bank = bank,
			promptTemplate = ReplicatedStorage.HeistShared.PromptTemplates.RobSafePrompt,
			amount = 5000,
			getCode = function() return masterComputer:GetCode() end,
			onRefused = notifyRefused,
			playRobSound = function(part) part.SafeRobSound:Play() end,
			onOpenGui = function(player) net:OpenSafeGui(player, safeId) end,
			isBlocked = function(player) return carryState:IsCarrying(player) end,
			-- City (phase 3 Task 5): one player's attempts at least RobSafePrompt.HoldDuration
			-- apart, server-side (the hold itself is only enforced on the client).
			enforceHold = true,
		})
		bank:RegisterComponent(safe)
		newsStationSafeById[safeId] = safe
		table.insert(newsStationSafeObjects, safe)
	end
end

-- Same debounce discipline as HeistServer's own SubmitSafeCode handler --
-- guards against network-level spam/automation only, not a gameplay
-- throttle (unlimited manual retries, no cooldown, by spec).
local NEWSSTATION_SAFE_SUBMIT_DEBOUNCE = 0.5
net:OnSafeCodeSubmitted(function(player, safeId, digits)
	if type(safeId) ~= "number" or type(digits) ~= "string" then return end
	local safe = newsStationSafeById[safeId]
	if not safe then return end -- not one of THIS location's safes -- HeistServer's own handler owns it
	local nowClock = os.clock()
	local last = lastNewsStationSafeSubmit[player]
	if last and (nowClock - last) < NEWSSTATION_SAFE_SUBMIT_DEBOUNCE then return end
	lastNewsStationSafeSubmit[player] = nowClock

	local ok, reason = safe:TrySubmitCode(player, digits)
	if ok then
		net:Toast(player, "Safe cracked!")
	elseif reason == "wrong_code" then
		net:Toast(player, "Wrong Code")
	elseif reason == "already_robbed" then
		net:Toast(player, "Already cracked.")
	elseif reason == "inactive" then
		net:Toast(player, "NewsStation is sealed.")
	end
end)

-- LightSphere (spec addendum, 2026-09-2X): a one-shot Brightness fade tied
-- to RobberyActive. NOTE, correcting the "reuse the same pattern as
-- Templight" framing: Templight's own mechanism (AlarmEffects.lua) only
-- ever tweens Color on an always-Enabled=true fixture (recoloring it red
-- during an alarm, back to its own cached default color after) -- it never
-- toggles Enabled/Brightness at all, so it isn't literally reusable for
-- what THIS light actually needs (Enabled=false by default, fade
-- Brightness up on session start, fade back down and only THEN set
-- Enabled=false on session end). Built here as its own small, self-
-- contained one-shot pair instead -- same underlying TweenService
-- technique, shaped for this specific light's own on/off semantics. This is
-- also exactly why it is driven through LocationServer's onActive/onSealed
-- hooks rather than through alarmExtras: it is not an AlarmEffects
-- capability at all.
local lightSpherePart = workspace.NewsStation:FindFirstChild("LightSphere")
assert(lightSpherePart, "[NewsStationServer] Workspace.NewsStation.LightSphere is missing")
local lightSphereLight = lightSpherePart:FindFirstChildOfClass("PointLight")
assert(lightSphereLight, "[NewsStationServer] LightSphere has no PointLight")
local LIGHT_SPHERE_FADE_DURATION = 0.75 -- tunable placeholder, matches this project's own established default elsewhere
local lightSpherePeakBrightness = lightSphereLight.Brightness -- cached ONCE, before this script ever touches it
local lightSphereTween = nil
local function cancelLightSphereTween()
	if lightSphereTween then
		pcall(function() lightSphereTween:Cancel() end)
		lightSphereTween = nil
	end
end
fadeLightSphere = function(on: boolean)
	cancelLightSphereTween()
	if on then
		lightSphereLight.Enabled = true
		lightSphereLight.Brightness = 0
		lightSphereTween = TweenService:Create(lightSphereLight,
			TweenInfo.new(LIGHT_SPHERE_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = lightSpherePeakBrightness })
		lightSphereTween:Play()
	else
		local tween = TweenService:Create(lightSphereLight,
			TweenInfo.new(LIGHT_SPHERE_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0 })
		lightSphereTween = tween
		tween.Completed:Connect(function()
			if lightSphereTween == tween then
				lightSphereLight.Enabled = false
				lightSphereTween = nil
			end
		end)
		tween:Play()
	end
end

do
	local manifest = registry:Manifest()
	local parts = {}
	for tag, count in pairs(manifest) do
		table.insert(parts, string.format("%s=%d", tag, count))
	end
	table.sort(parts)
	print(string.format("[NewsStationServer] NewsStation booted: %s NewsStationRegister=%d NewsStationATM=%d NewsStationCamera=%d NewsStationOilHazard=%d Safe=%d, zones=%d",
		table.concat(parts, " "), #CollectionService:GetTagged(T.NewsStationRegister), #CollectionService:GetTagged(T.NewsStationATM),
		#CollectionService:GetTagged(T.NewsStationCamera), #oilHazards, #newsStationSafeObjects, #location.zones))
end

-- Every component is registered: connect the handlers and start the
-- heartbeat.
location:Start()
