--!strict
-- Shared per-location orchestration skeleton (Part 1 unification, 2026-09-12).
--
-- SlowFoodsServer/Gas2GoServer/NewsStationServer all repeat the same lifecycle
-- scaffolding -- Forfeit + BankInstance + zones/ZoneService + AlarmEffects +
-- DuffelBagAttachment -- followed by the same handler set (state broadcast,
-- late joiner, duffel push, weapon-equip trigger, character watch, player
-- cleanup) and the same heartbeat body -- which also steps the Getaway that
-- banks the bag, the claim-zone cash-out handler having gone with the Claim
-- zone itself (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19). Only tags,
-- role names, message literals and each location's own extra components
-- actually differ: SlowFoodsServer and Gas2GoServer measure 93%/85% identical
-- once per-location tokens are canonicalized.
--
-- HeistServer (the Bank) is DELIBERATELY NOT a consumer of this module, and
-- should not be migrated onto it without revisiting the decision. It shares the
-- scaffolding but not the participant model, which is the part this module
-- actually encodes:
--   * "Inside the building" is Lobby OR Vault OR BankVaultZone, not one
--     interior role -- the underground gauntlet must not read as "outside".
--   * It does NOT auto-enrol interior occupants when a session goes Active
--     (it cues Vault occupants instead), and has no late-joiner enrolment
--     handler at all: participants are enrolled through the gauntlet
--     progression. Both behaviours this module provides unconditionally.
--   * It pushes a live accrual RATE (vault-scoped, participant-gated), where
--     every other location is lump-sum and always sends 0.
--   * It connects a zoneService.Exited handler; no other location has one.
-- Supporting all four would mean letting a consumer switch off or replace the
-- enrolment behaviour the other three depend on, which buys the Bank the
-- smallest proportional win of the four (most of its 1000 lines are
-- location-specific gauntlet machinery that stays put regardless) in exchange
-- for the largest blast radius and a vaguer abstraction. Measured with Part 0's
-- profiling: this unification is a maintainability change with no performance
-- effect either way, so the risk is not worth buying.
--
-- What this deliberately does NOT own:
--   * Boot validation. Per-location tag counts are genuinely different
--     invariants, and a misconfigured tag must still name its own location in
--     the assert -- those stay explicit in each location script.
--   * Any location-specific component (registers, safes, lockpick doors,
--     terminals, hazards). Those stay where they are, registered by the
--     location script itself between new() and Start().
--
-- Two-phase, because ordering is load-bearing: components must already be
-- registered on the bank before any handler fires or the heartbeat runs. So
-- new() builds state but connects nothing observable, the location script
-- registers its own components, then Start() connects handlers and spawns the
-- loop -- preserving the exact ordering the hand-written scripts had.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local HeistConfig = require(ReplicatedStorage.HeistShared.Config)

local Heist = ServerScriptService.Heist
local BankInstance = require(Heist.BankInstance)
local Zone = require(Heist.Components.Zone)
local ZoneService = require(Heist.Services.ZoneService)
local Forfeit = require(Heist.Services.Forfeit)
local Getaway = require(Heist.Services.Getaway)
local AlarmEffects = require(Heist.Services.AlarmEffects)
local DuffelBagAttachment = require(Heist.Services.DuffelBagAttachment)
local Net = require(Heist.Services.Net)

local LocationServer = {}
LocationServer.__index = LocationServer

-- Byte-identical at every location that has one today. Owned here rather than
-- passed in: a location needing different wording is a change worth making
-- deliberately, not a knob to turn by accident.
local REFUSAL_MESSAGES = {
	cap_exceeded = "Duffel Full — get clear of the building to bank it.",
	carrying_supplies = HeistConfig.SupplyCarryingRefusalMessage,
	has_duffel = "You need to bank your duffel first before carrying supplies.",
}

local TRIGGER_DEBOUNCE = 1.0

-- Process-wide singletons, required lazily and only when not injected:
-- constructing CurrencyService or CarryState a second time is explicitly
-- unsafe (see their own headers), and a spec injecting stubs must never trip
-- that just by requiring this module.
local function realCurrency()
	return require(ServerScriptService.PlayerData.CurrencyService)
end
local function realCarryState()
	return require(ReplicatedStorage.SharedSystems.CarryState)
end
local function realGamepassManager()
	return require(ReplicatedStorage.SharedSystems.GamepassManager)
end

function LocationServer.new(cfg)
	assert(type(cfg) == "table", "LocationServer requires a config table")
	assert(type(cfg.name) == "string", "LocationServer requires a name")
	assert(cfg.config, "LocationServer requires a config module")
	assert(type(cfg.interiorRole) == "string", "LocationServer requires an interiorRole")
	assert(type(cfg.exitCFrame) == "function", "LocationServer requires an exitCFrame function")

	local self = setmetatable({
		name = cfg.name,
		config = cfg.config,
		interiorRole = cfg.interiorRole,

		_onActive = cfg.onActive,
		_onSealed = cfg.onSealed,
		_onPlayerRemoving = cfg.onPlayerRemoving,
		_heartbeatExtras = cfg.heartbeatExtras,
		_startHeartbeat = cfg.startHeartbeat ~= false,

		_insideBuilding = {},
		_recentTriggerAttempt = {},
		_connections = {},
		_running = false,

		now = cfg.now or function() return workspace:GetServerTimeNow() end,
		net = cfg.net or Net.setup(),
		currency = cfg.currency or realCurrency(),
		carryState = cfg.carryState or realCarryState(),
		getPlayers = cfg.getPlayers or function() return Players:GetPlayers() end,
	}, LocationServer)

	local duffelCapMultiplier = cfg.duffelCapMultiplier
	local accrualRateMultiplier = cfg.accrualRateMultiplier
	if not (duffelCapMultiplier and accrualRateMultiplier) then
		local gamepass = cfg.gamepassManager or realGamepassManager()
		duffelCapMultiplier = duffelCapMultiplier
			or function(player) return gamepass:GetDuffelCapMultiplier(player) end
		accrualRateMultiplier = accrualRateMultiplier
			or function(player) return gamepass:GetAccrualRateMultiplier(player) end
	end

	self.forfeit = cfg.forfeit or Forfeit.new({
		exitCFrame = cfg.exitCFrame,
		teleport = function(player, cframe)
			local character = player.Character
			if character then character:PivotTo(cframe + Vector3.new(0, 4, 0)) end
		end,
		notify = function(player, cause)
			-- timer_expired stays suppressed: a player who has physically moved on
			-- elsewhere finds a stale notice about THIS clock to be irrelevant
			-- noise, unlike "died", which is always immediate personal feedback
			-- about something that just happened to them, wherever they are.
			if cause == "timer_expired" then return end
			local messages = {
				died = "You died before banking. Bag lost.",
			}
			self.net:Toast(player, messages[cause] or "Run failed. Bag lost.")
		end,
	})

	self.bank = cfg.bank or BankInstance.new({
		config = cfg.config,
		now = self.now,
		model = cfg.model,
		-- Only caller is BankInstance:_seal (timer expiry) -- a still-alive
		-- player, always the ejecting half of forfeiture. Teleport only if still
		-- actually inside the interior zone: forfeited either way, just not
		-- yanked back to ExitSpawn if they already left.
		onForfeit = function(player, cause)
			self.forfeit:Eject(self.bank, player, cause,
				self.zoneService:IsInside(self.interiorRole, player))
		end,
		onParticipantAdded = function(player) self.forfeit:Forget(player) end,
		duffelCapMultiplier = duffelCapMultiplier,
		accrualRateMultiplier = accrualRateMultiplier,
	})

	local zones = cfg.zones
	if not zones then
		assert(type(cfg.zoneTag) == "string",
			"LocationServer requires zoneTag (or a prebuilt zones list)")
		zones = {}
		for _, part in ipairs(CollectionService:GetTagged(cfg.zoneTag)) do
			table.insert(zones, Zone.new(part, { config = cfg.config }))
		end
	end
	self.zones = zones
	self.zoneService = cfg.zoneService or ZoneService.new({ zones = zones })

	self.alarm = cfg.alarm
	if not self.alarm then
		local host
		for _, part in ipairs(CollectionService:GetTagged(cfg.zoneTag)) do
			if part:GetAttribute("ZoneRole") == cfg.interiorRole then host = part end
		end
		assert(host, string.format("[%sServer] no %s part has ZoneRole == %q",
			cfg.name, tostring(cfg.zoneTag), cfg.interiorRole))

		local alarmDeps = {
			config = cfg.config,
			now = self.now,
			lights = {},
			templights = {},
			-- The SAME shared template every location uses, cloned into this
			-- location's own interior zone for the duration of a session.
			soundTemplate = cfg.alarmSoundTemplate or workspace.BankVault.AlarmSpeaker.AlarmSound,
			soundHosts = { host },
		}
		-- Gas2Go alone drives pulseLights/pulsePhaseDuration. One merge hook
		-- rather than a flag per field.
		for key, value in pairs(cfg.alarmExtras or {}) do
			alarmDeps[key] = value
		end
		self.alarm = AlarmEffects.new(alarmDeps)
	end

	self.duffelBagAttachment = cfg.duffelBagAttachment
		or DuffelBagAttachment.new({ template = cfg.duffelTemplate or ReplicatedStorage.HeistShared.DuffelBag })

	-- Plain function, not a method: it is handed straight to every component's
	-- own onRefused dependency.
	self.notifyRefused = function(player, reason)
		self.net:Toast(player, REFUSAL_MESSAGES[reason] or "Can't do that right now.")
	end

	self.getaway = cfg.getaway
	if not self.getaway then
		assert(type(cfg.markerFolder) == "string",
			"LocationServer requires markerFolder (or a prebuilt getaway)")
		local markers = workspace:WaitForChild(cfg.markerFolder, 10)
		local anchor = markers and markers:WaitForChild("StatusBillboardAnchor", 10)
		assert(anchor, string.format("[%sServer] %s has no StatusBillboardAnchor",
			cfg.name, cfg.markerFolder))
		self.getaway = Getaway.new({
			escapeDistance = cfg.config.EscapeDistance,
			anchor = anchor,
			isInsideBuilding = function(player)
				return self.zoneService:IsInside(self.interiorRole, player)
			end,
			getDuffel = function(player) return self.bank:GetDuffel(player) end,
			getPlayers = self.getPlayers,
			onEscaped = function(player) self:_bankBag(player) end,
		})
	end

	return self
end

-- Drives the client's PlayerInZone AND the RobberyActive gate for the heist
-- timer. Fires only on an actual change, never once per sweep.
function LocationServer:_updateZoneOccupancy()
	for _, player in ipairs(self.getPlayers()) do
		local inside = self.zoneService:IsInside(self.interiorRole, player)
		if self._insideBuilding[player] ~= inside then
			self._insideBuilding[player] = inside
			self.net:BroadcastZoneOccupancy(self.name, player, inside)
		end
	end
end

-- No continuous accrual exists at these locations (lump-sum registers/ATM
-- only), so the rate is always 0 -- the client's extrapolation math still
-- works, it just never advances between updates. The DuffelBag accessory
-- tracks the same amount, matching the client's own wantDuffel formula.
function LocationServer:_pushDuffel(player)
	local amount = self.bank:GetDuffel(player)
	self.net:SendDuffel(self.name, player, amount, 0, self.now(), self.bank:GetDuffelCap(player))
	self.duffelBagAttachment:Sync(player, amount > 0)
end

-- The payout, moved verbatim out of the old claim-zone Entered handler
-- (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19). Now called by Getaway
-- when the player gets clear; the body itself is unchanged.
function LocationServer:_bankBag(player)
	local amount = self.bank:Claim(player)
	if amount <= 0 then return end
	local banked = math.floor(amount)
	self.currency:Add(player.UserId, banked)
	self.net:Toast(player, string.format("Banked %d %s.", banked, HeistConfig.CurrencyName))
	-- Fired after currency:Add so leaderstats.Cash.Value has already
	-- replicated the new total by the time the client reacts to this.
	self.net:NotifyRobberySuccess(player)
end

function LocationServer:_hasEquippedWeapon(character): boolean
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and CollectionService:HasTag(child, HeistConfig.Tags.Weapon) then
			return true
		end
	end
	return false
end

function LocationServer:TryTriggerRobbery(player)
	-- Belt-and-braces on top of CarryState:PickUp's own Unequipped-based
	-- safeguard: closes the "equip a weapon while carrying" loophole even in
	-- the unlikely event ordering ever let the weapon's equip logic run first.
	if self.carryState:IsCarrying(player) then
		self.net:Toast(player, HeistConfig.SupplyCarryingRefusalMessage)
		return
	end

	local nowClock = os.clock()
	local last = self._recentTriggerAttempt[player]
	if last and (nowClock - last) < TRIGGER_DEBOUNCE then return end
	self._recentTriggerAttempt[player] = nowClock

	local ok, reason = self.bank:TryStart(player)
	if ok then
		self.bank:AddParticipant(player)
		-- No personal Toast (2026-09-13): NotifyRobberyTriggered fires to ALL
		-- clients including this one, so a separate personal "Alarm triggered"
		-- message was duplicate information for exactly the player who had just
		-- been told. Removing it also deleted a real per-location divergence --
		-- SlowFoods hardcoded "You have two minutes." while Gas2Go/NewsStation
		-- computed "%d minutes" from SessionDuration, rendering differently.
		self.net:NotifyRobberyTriggered(self.name, player.Name)
		return
	end
	if reason == "cooldown" then
		local remaining = math.max(0, (self.bank:GetCooldownEndsAt() or 0) - self.now())
		self.net:Toast(player, string.format("%s sealed -- %d:%02d remaining.",
			self.name, remaining // 60, math.floor(remaining % 60)))
	end
end

function LocationServer:_watchCharacter(player, character)
	-- Entry point B: zone entered while the weapon is already equipped.
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		if not CollectionService:HasTag(child, HeistConfig.Tags.Weapon) then return end
		if not self.zoneService:IsInside(self.interiorRole, player) then return end
		self:TryTriggerRobbery(player)
	end)

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			if self.bank:GetState() == "Active" and self.bank:IsParticipant(player) then
				self.forfeit:Die(self.bank, player, "died")
			end
		end)
	end
end

-- City (phase 3 Task 5): a character removed WITHOUT dying (LoadCharacter, anything that skips
-- Died) forfeits exactly like a death. The bag is keyed by Player, and the city spawn is past
-- EscapeDistance from every location, so otherwise the respawn banked it. In-heist moves
-- (forfeit ejects, teleporters) use PivotTo and never remove the character. After a real death
-- the player is already off the roster, so the CharacterRemoving that follows does nothing.
function LocationServer:_onCharacterRemoving(player)
	if self.bank:GetState() == "Active" and self.bank:IsParticipant(player) then
		self.forfeit:Die(self.bank, player, "died")
	end
end

function LocationServer:ForgetPlayer(player)
	self.bank:RemoveParticipant(player)
	self.bank:ForgetPlayer(player)
	self.zoneService:ForgetPlayer(player)
	self.forfeit:Forget(player)
	self.getaway:Forget(player)
	self.duffelBagAttachment:Forget(player)
	self._recentTriggerAttempt[player] = nil
	self._insideBuilding[player] = nil
	if self._onPlayerRemoving then self._onPlayerRemoving(player) end
end

-- The heartbeat body, exposed so it can be driven a tick at a time under test
-- instead of racing a real 10Hz loop.
function LocationServer:Tick()
	self.bank:Step()
	self.zoneService:Update()
	self.alarm:Update()
	if self._heartbeatExtras then self._heartbeatExtras() end
	self:_updateZoneOccupancy()
	self.getaway:Step()
end

function LocationServer:Start()
	assert(not self._running, "LocationServer:Start called twice for " .. self.name)
	self._running = true

	local bank, zoneService, net = self.bank, self.zoneService, self.net
	local conns = self._connections

	table.insert(conns, bank.StateChanged:Connect(function(state)
		net:BroadcastState(self.name, state, bank:GetEndsAt(), bank:GetCooldownEndsAt())
		if state == "Active" then
			self.alarm:Start()
			if self._onActive then self._onActive(state) end
			-- Anyone already standing inside the instant the session goes Active
			-- (the triggering player, or a bystander) joins the roster
			-- immediately -- there is no separate transit step to gate this on.
			for _, player in ipairs(zoneService:GetOccupants(self.interiorRole)) do
				bank:AddParticipant(player)
			end
		else
			self.alarm:Stop()
			if self._onSealed then self._onSealed(state) end
			if state == "Idle" then
				-- A genuine re-open after a cooldown, never server boot: BankInstance
				-- seeds its initial Idle as a plain field rather than through
				-- _setState, so this signal only ever fires from _rearm.
				net:NotifyLocationOpened(self.name)
			end
			if state == "Cooldown" then
				-- Session-end safety net: every actual participant is already
				-- detached via the DuffelChanged -> _pushDuffel chain that
				-- VoidDuffel triggers during _seal. This is defensive redundancy
				-- against any missed :Sync, checked against every currently
				-- connected player rather than just this session's roster.
				self.duffelBagAttachment:ForceDetachAll(self.getPlayers())
			end
		end
	end))

	-- Late joiner: walks into an already-Active session.
	table.insert(conns, zoneService.Entered:Connect(function(role, player)
		if role ~= self.interiorRole then return end
		if bank:GetState() == "Active" then
			bank:AddParticipant(player)
		end
	end))

	table.insert(conns, bank.DuffelChanged:Connect(function(player)
		self:_pushDuffel(player)
	end))

	-- Entry point A: weapon equipped while already inside the zone.
	table.insert(conns, zoneService.Entered:Connect(function(role, player)
		if role ~= self.interiorRole then return end
		local character = player.Character
		if character and self:_hasEquippedWeapon(character) then
			self:TryTriggerRobbery(player)
		end
	end))

	table.insert(conns, require(ReplicatedStorage.Utility.safePlayerAdded)(function(player)
		if player.Character then self:_watchCharacter(player, player.Character) end
		player.CharacterAdded:Connect(function(character)
			self:_watchCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			self:_onCharacterRemoving(player)
		end)
	end))

	table.insert(conns, Players.PlayerRemoving:Connect(function(player)
		self:ForgetPlayer(player)
	end))

	if self._startHeartbeat then
		task.spawn(function()
			local interval = 1 / self.config.HeartbeatRate
			local accumulator = 0

			while true do
				local dt = RunService.Heartbeat:Wait()
				accumulator += dt
				if accumulator < interval then continue end
				accumulator = 0

				self:Tick()
			end
		end)
	end

	return self
end

function LocationServer:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
	self._running = false
end

return LocationServer
