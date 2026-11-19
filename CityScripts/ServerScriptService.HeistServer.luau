--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.HeistShared.Config)
-- Reads the city's published pass ownership (2026-11-18); nothing to initialise.
local GamepassManager = require(ReplicatedStorage.SharedSystems.GamepassManager)
local Heist = ServerScriptService.Heist
local BankInstance = require(Heist.BankInstance)
local ComponentRegistry = require(Heist.ComponentRegistry)
local Gate = require(Heist.Components.Gate)
local Terminal = require(Heist.Components.Terminal)
local Teleporter = require(Heist.Components.Teleporter)
local LaserHazard = require(Heist.Components.LaserHazard)
local GuardPost = require(Heist.Components.GuardPost)
local Zone = require(Heist.Components.Zone)
local DeathVolume = require(Heist.Components.DeathVolume)
local AccessBarrier = require(Heist.Components.AccessBarrier)
local CounterBarrier = require(Heist.Components.CounterBarrier)
local VaultDoor = require(Heist.Components.VaultDoor)
local HighlightSequencer = require(Heist.Components.HighlightSequencer)
local DisplayLights = require(Heist.Components.DisplayLights)
local Safe = require(Heist.Components.Safe)
local SafeCode = require(Heist.Components.SafeCode)
local NPCReactionAnimator = require(ReplicatedStorage.SharedSystems.NPCReactionAnimator)
local NPCSpawnManager = require(ReplicatedStorage.SharedSystems.NPCSpawnManager)
local C4Charge = require(Heist.Components.C4Charge)
local ZoneService = require(Heist.Services.ZoneService)
local Forfeit = require(Heist.Services.Forfeit)
local Getaway = require(Heist.Services.Getaway)
local AlarmEffects = require(Heist.Services.AlarmEffects)
local DuffelBagAttachment = require(Heist.Services.DuffelBagAttachment)
local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)
local SupplyObject = require(ReplicatedStorage.SharedSystems.SupplyObject)
local DepositBoxes = require(Heist.Components.DepositBoxes)
local DepositBoxLoot = require(ReplicatedStorage.HeistShared.DepositBoxLoot)
local CarryGetaway = require(Heist.Services.CarryGetaway)
local HeistPolice = require(Heist.Services.HeistPolice)
local CARRY_SPEED_CAP = require(ReplicatedStorage.Movement.Constants).CARRY_SPEED_CAP
local Net = require(Heist.Services.Net)
-- Global singleton, shared with SlowFoodsServer/Gas2GoServer/SuppliesServer
-- (spec addendum, 2026-09-19) -- see CarryState's own header for why this
-- must never be constructed a second time.
local carryState = require(ReplicatedStorage.SharedSystems.CarryState)
-- Singleton, shared with every other robbery-site script (spec addendum,
-- 2026-09-06) -- see CurrencyService for why this must never be constructed
-- a second time.
local currency = require(ServerScriptService.PlayerData.CurrencyService)

local T = Config.Tags
local function now() return workspace:GetServerTimeNow() end

-- Boot validation: a misconfigured tag must surface the moment you press Play,
-- not forty minutes into a session when a barrier fails to open.
local function requireSingleton(tag: string)
	local tagged = CollectionService:GetTagged(tag)
	assert(#tagged >= 1, string.format("[HeistServer] required tag %s has no instances", tag))
	return tagged[1]
end

local exitSpawn = requireSingleton(T.HeistExitSpawn)

-- A missing CounterDoor gate, a lopsided teleporter pair, or a zone missing a
-- role are exactly the class of defect that let the whole level ship
-- unbound: the old checks here only counted tags, never checked what they
-- were FOR. Assert roles too, so a misconfigured place fails at boot.
do
	local teleporters = CollectionService:GetTagged(T.HeistTeleporter)
	assert(#teleporters == 2, string.format(
		"[HeistServer] expected exactly 2 HeistTeleporter parts, found %d", #teleporters))
	local roles = {}
	for _, tp in ipairs(teleporters) do
		roles[tp:GetAttribute("TeleportRole")] = true
	end
	assert(roles.A and roles.B, "[HeistServer] HeistTeleporter parts must cover roles A and B")
end

do
	local zones = CollectionService:GetTagged(T.HeistZone)
	-- 2 original (Lobby, Vault) + 3 BankVaultZone volumes (spec
	-- addendum, 2026-09-11) covering the underground gauntlet between them --
	-- the Claim zone was retired when the distance-based getaway replaced the
	-- claim-zone cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	-- see ZoneService's role-union support for why several parts sharing one
	-- role is a supported, deliberate shape here, not a duplicate-role bug.
	assert(#zones == 5,
		string.format("[HeistServer] expected exactly 5 HeistZone parts (Lobby, Vault, 3x BankVaultZone), found %d", #zones))
	local roles = {}
	for _, z in ipairs(zones) do
		roles[z:GetAttribute("ZoneRole")] = true
	end
	assert(roles.Lobby and roles.Vault and roles.BankVaultZone,
		"[HeistServer] HeistZone parts must cover roles Lobby, Vault and BankVaultZone")
end

do
	-- CounterDoor is no longer Gate-based (spec addendum, 2026-09-05): it is
	-- 4 static CounterBarrier-tagged parts instead of a single HeistGate with
	-- GateGroup == "CounterDoor".
	local counterBarriers = CollectionService:GetTagged(T.CounterBarrier)
	assert(#counterBarriers == 4,
		string.format("[HeistServer] expected exactly 4 CounterBarrier parts, found %d", #counterBarriers))
end

do
	-- ATM machines (spec addendum, 2026-09-14): same one-time-per-session
	-- flat-value rob mechanic as SlowFoods' cash registers.
	local atms = CollectionService:GetTagged(T.HeistATM)
	assert(#atms == 2, string.format("[HeistServer] expected exactly 2 HeistATM parts, found %d", #atms))
end

do
	-- The Bank's OWN cash registers (spec addendum, 2026-09-14) -- a third
	-- application of the same shared RobbableObject mechanic, distinct from
	-- both the Bank's ATMs and SlowFoods' own registers.
	local bankRegisters = CollectionService:GetTagged(T.BankRegister)
	assert(#bankRegisters == 3, string.format("[HeistServer] expected exactly 3 BankRegister parts, found %d", #bankRegisters))
end

do
	-- Safe (spec addendum, 2026-09-16): a fourth robbable-object variant --
	-- two physical props, one shared session code, independently robbable.
	local safes = CollectionService:GetTagged(T.BankSafe)
	assert(#safes == 2, string.format("[HeistServer] expected exactly 2 BankSafe parts, found %d", #safes))
end

assert(workspace.BankVault:FindFirstChild("Vault Door"), "[HeistServer] Workspace.BankVault.\"Vault Door\" is missing")
assert(ReplicatedStorage.HeistShared:FindFirstChild("DuffelBag")
		and ReplicatedStorage.HeistShared.DuffelBag:IsA("Model")
		and ReplicatedStorage.HeistShared.DuffelBag.PrimaryPart,
	"[HeistServer] ReplicatedStorage.HeistShared.DuffelBag is missing, not a Model, or has no PrimaryPart")

local net = Net.setup()

-- DataStoreService:GetDataStore() throws in an unpublished place (PlaceId == 0)
-- and can also fail when Studio API access is off. Constructing it unguarded at
-- boot took the ENTIRE heist down with it — which violates the spec's own rule
-- that DataStore failures never touch gameplay. Degrade instead: run the heist
-- on an in-memory backend, loudly, so the game is playable and only persistence
-- is lost.
-- Forward declarations: Forfeit needs the bank, the bank needs Forfeit; the
-- onForfeit closure (defined as part of BankInstance.new below) needs
-- zoneService for the forced-eject occupancy check, but zoneService isn't
-- built until after the zones list exists -- same forward-declare-then-
-- assign-later pattern as `bank` itself, so the closure correctly captures
-- the eventual value as an upvalue rather than resolving to a stray global.
local bank
local zoneService
local isInsideBank
local forfeit = Forfeit.new({
	exitCFrame = function() return exitSpawn.CFrame end,
	-- Final review I2 (2026-11-18): the timer's eject takes a heavy carry (the gold bar) held inside.
	carryState = carryState,
	teleport = function(player, cframe)
		local character = player.Character
		if character then character:PivotTo(cframe + Vector3.new(0, 4, 0)) end
	end,
	notify = function(player, cause)
		-- timer_expired removed entirely (spec correction, 2026-09-2X): see
		-- SlowFoodsServer/Gas2GoServer's identical own comment -- a stale
		-- notification about THIS session's own clock running out is
		-- irrelevant noise to a player who's physically moved on elsewhere,
		-- unlike "died"/"death_pit", which remain directly relevant personal
		-- feedback about something that just happened to them.
		if cause == "timer_expired" then return end
		local messages = {
			-- "laser"/"guard" causes are no longer reachable directly: both now deal
			-- damage rather than forfeiting on contact, so a laser- or guard-caused
			-- death surfaces here as "died" instead (see the Humanoid.Died handler).
			death_pit = "You fell. Bag lost.",
			died = "You died before banking. Bag lost.",
		}
		net:Toast(player, messages[cause] or "Run failed. Bag lost.")
	end,
})

bank = BankInstance.new({
	config = Config,
	now = now,
	model = workspace:FindFirstChild("Bank"),
	-- The only caller of onForfeit is BankInstance:_seal, i.e. session end
	-- (timer expiry) -- a still-alive player, so this is always the ejecting
	-- half of forfeiture, never the dying half. Only teleport if the player
	-- is still actually on the premises (spec addendum, 2026-09-11) -- a
	-- player who already left is still forfeited, just not yanked back to
	-- ExitSpawn from wherever they are. "On the premises" spans the lobby AND
	-- the whole underground stretch (vault loot zone + the BankVaultZone
	-- gauntlet volumes between them), reusing the exact same ZoneService
	-- occupancy already driving the heist-timer GUI below.
	onForfeit = function(player, cause)
		local isInside = isInsideBank(player)
		forfeit:Eject(bank, player, cause, isInside)
	end,
	-- A forfeit latch must live only for one forfeiture EPISODE, not for the
	-- rest of the session (spec 2.3/4.6 allow re-entry after a forfeit). Clear
	-- it the moment the player rejoins the roster so a later death forfeits
	-- them again instead of leaving them immune for the rest of the session.
	onParticipantAdded = function(player) forfeit:Forget(player) end,
	-- Universal gamepass modifiers (spec addendum, 2026-09-03) -- BankInstance
	-- never requires GamepassManager itself; this is the one place that wires
	-- them together, same pattern as onForfeit/onParticipantAdded above.
	duffelCapMultiplier = function(player) return GamepassManager:GetDuffelCapMultiplier(player) end,
	accrualRateMultiplier = function(player) return GamepassManager:GetAccrualRateMultiplier(player) end,
})
-- Admin (2026-11-20): the panel's heist state and cooldown reset reach this instance through Admin.Hooks.
require(ServerScriptService.Admin.Hooks).heists.Bank = bank

-- Zones are built directly rather than through the registry, because
-- ZoneService needs the list up front.
local zones = {}
for _, part in ipairs(CollectionService:GetTagged(T.HeistZone)) do
	table.insert(zones, Zone.new(part, { config = Config }))
end
zoneService = ZoneService.new({ zones = zones })

-- Lasers deal damage rather than forfeiting outright (unlike every other
-- hazard), so a player can be hit, retreat, and survive — the same shape as
-- guard combat. Debounced per (player, SOURCE) -- not globally per player --
-- because LaserHazard:Update()/Gate:Update() call onContact on every
-- overlapping tick of a live hazard at 20 Hz; without this, standing in one
-- for a single frame would apply several ticks of damage in one touch.
-- Regression found via user report, 2026-09-17: this used to be keyed by
-- player ALONE, so getting hit by one laser made every OTHER laser/
-- hazardous-gate in the Bank (a shared onContact hook across all of them)
-- deal zero damage for the next 0.75s too -- confirmed live, a fresh player
-- standing on a second, clearly-live laser took no damage at all if hit by
-- a different one moments earlier. source is whichever LaserHazard/Gate
-- instance is calling this (both now pass self as a second argument) --
-- keying by that specific instance means only re-touching the SAME hazard
-- is debounced; a different one always deals its own damage independently.
-- Death from a laser (health reaching 0) is still caught by the generic
-- Humanoid.Died handler below, which still forfeits the bag — only the
-- non-lethal case changed.
local LASER_DAMAGE_COOLDOWN = Config.LaserDamageCooldown
local recentLaserHit = {} -- player -> {[source] = os.clock() of last hit}
local function applyLaserDamage(player, source)
	local nowClock = os.clock()
	local perPlayer = recentLaserHit[player]
	if not perPlayer then
		perPlayer = {}
		recentLaserHit[player] = perPlayer
	end
	local last = perPlayer[source]
	if last and (nowClock - last) < LASER_DAMAGE_COOLDOWN then return end
	perPlayer[source] = nowClock

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(humanoid.MaxHealth * Config.LaserDamageFraction)
	end
end

-- The whole C4/prompt sequence is clone-based (spec addendum, 2026-08-29):
-- the C4 model, the explosion effect, and both ProximityPrompts ("Attach
-- C4", "Go to Vault") are pre-built templates that C4Charge clones in and
-- destroys at the right points -- never Instance.new()'d, matching the
-- pattern already used for sounds.
local heistShared = ReplicatedStorage.HeistShared
local c4PromptTemplates = {
	attach = heistShared.PromptTemplates.AttachC4Prompt,
	goToVault = heistShared.PromptTemplates.GoToVaultPrompt,
}
local c4ModelTemplates = {
	c4 = heistShared.ModelTemplates.C4Model,
	explosion = heistShared.ModelTemplates.ExplosionEffect,
}
local c4SoundTemplates = {
	tick = heistShared.SoundTemplates.C4TickSound,
	explosion = heistShared.SoundTemplates.ExplosionSound,
}
local teleporterBankA = workspace.Bank.TeleporterBankA

-- Gate demolition: the barrier blocking TeleporterBankA physically blows
-- apart the instant the C4 explosion fires (spec addendum, 2026-08-29) --
-- wired as C4Charge's onDetonate hook so it is guaranteed to run in the SAME
-- server-side call as the explosion effect/sound, never a separately timed
-- event that could drift out of sync.
local openGateTemplate = heistShared.ModelTemplates.OpenGate
local currentOpenGate = workspace.Bank.OpenGate
local openGateOriginalPivot = currentOpenGate:GetPivot()

local function demolishOpenGate(originPosition: Vector3)
	local gate = currentOpenGate
	if not gate or not gate.Parent then return end
	currentOpenGate = nil

	local parts = {}
	for _, d in ipairs(gate:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end

	for _, part in ipairs(parts) do
		part.Anchored = false
		local away = part.Position - originPosition
		if away.Magnitude < 0.1 then
			away = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		end
		local direction = away.Unit
		local speed = 15 + math.random() * 15
		part.AssemblyLinearVelocity = direction * speed + Vector3.new(0, 10 + math.random() * 10, 0)
		part.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 10,
			(math.random() - 0.5) * 10,
			(math.random() - 0.5) * 10)
	end

	-- Mandatory cleanup, not polish: unanchored simulating debris left
	-- indefinitely is a known lag source. Real wall-clock delay (like the
	-- autosave loop further down), not the injectable session clock --
	-- purely cosmetic timing, not gameplay-critical.
	task.delay(Config.GateDebrisLifetime, function()
		for _, part in ipairs(parts) do
			if part.Parent then part:Destroy() end
		end
		if gate.Parent then gate:Destroy() end
	end)
end

-- Recommendation (a) from the addendum: OpenGate resets per session, like
-- every other barrier/prompt/C4 state in this system. Idempotent -- a no-op
-- if the current gate (the original, or an earlier respawn) is still
-- standing because no C4 sequence ever completed that robbery.
local function ensureOpenGate()
	if currentOpenGate and currentOpenGate.Parent then return end
	local clone = openGateTemplate:Clone()
	clone.Parent = workspace.Bank
	clone:PivotTo(openGateOriginalPivot)
	currentOpenGate = clone
end

-- A refused Teleporter:Use or C4Charge:Press previously produced ZERO
-- player-visible feedback -- no toast, no sound, nothing but a possibly
-- stale prompt label. That reads exactly like "I pressed the button and
-- nothing happened", indistinguishable from a genuinely broken prompt, even
-- though the underlying gate is working correctly (verified live: the full
-- plant -> countdown -> detonate -> unlock chain succeeds end to end when
-- driven through the real component methods). Root-caused via the debug
-- addendum, 2026-08-28 -- see the spec doc for the full writeup.
local REFUSAL_MESSAGES = {
	inactive = "The heist isn't active right now.",
	too_far = "Get closer before you try that.",
	vault_not_breached = "The vault's still locked. Plant and detonate the C4 first.",
	terminals_incomplete = "Hit both terminals before you can plant the charge.",
	countdown_active = "The charge is already counting down.",
	already_breached = "The vault's already breached. Head to the teleporter.",
	-- Shared with the ATM machines' RobbableObject onRefused (spec addendum,
	-- 2026-09-14) -- same wording as the heartbeat's own Duffel Full toast
	-- below; both were updated together when the claim zone was replaced by
	-- the getaway (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	cap_exceeded = "Duffel Full. Get clear of the building to bank it.",
	-- Supplies Robbery (spec addendum, 2026-09-19) -- shared by every
	-- robbable-object's new isBlocked gate.
	carrying_supplies = Config.SupplyCarryingRefusalMessage,
}
local function notifyRefused(player, reason)
	net:Toast(player, REFUSAL_MESSAGES[reason] or "Can't do that right now.")
end

local registry = ComponentRegistry.new({
	config = Config,
	componentDeps = {
		now = now,
		onRefused = notifyRefused,
		onContact = applyLaserDamage,
		onGuardDied = function() bank:NotifyGuardDied() end,
		-- Guards deal damage (since 2026-11-20 through ShotResolver, GuardPost's own shot); they do not forfeit
		-- directly. Death from any cause is caught by the Humanoid.Died handler below.
		-- Seeds bank:GuardsRemaining() from guards that actually spawned, not from
		-- Config.GuardCount, so a spawn failure cannot leave the guard barrier
		-- permanently unopenable.
		onGuardSpawned = function() bank:NotifyGuardSpawned() end,
		onDetonate = demolishOpenGate,
		teleporterPart = teleporterBankA,
		promptTemplates = c4PromptTemplates,
		modelTemplates = c4ModelTemplates,
		soundTemplates = c4SoundTemplates,
	},
	classes = {
		[T.HeistGate] = Gate,
		[T.HeistTerminal] = Terminal,
		[T.HeistTeleporter] = Teleporter,
		[T.HeistLaser] = LaserHazard,
		[T.HeistGuardPost] = GuardPost,
		[T.HeistDeathVolume] = DeathVolume,
		[T.HeistC4Point] = C4Charge,
		[T.HeistAccessBarrier] = AccessBarrier,
		[T.CounterBarrier] = CounterBarrier,
	},
})

local byTag = registry:BindAll(bank)

-- Bank Clerks (spec addendum, 2026-09-09): recloned unconditionally from
-- NPCSpawner placeholders every cooldown-end, rather than registry-bound
-- once at boot -- see NPCSpawnManager for why an individually-registered,
-- bind-once component can't support "destroy and replace every cycle".
local bankClerkSpawnManager = NPCSpawnManager.new({
	template = ReplicatedStorage.HeistShared.ModelTemplates.BankClerk,
	npcTag = T.BankClerk,
	spawnerTemplateValue = "BankClerk",
	npcParent = workspace.Bank,
	controllerClass = NPCReactionAnimator,
})
bank:RegisterComponent(bankClerkSpawnManager)

-- Vault Door (spec addendum, 2026-09-12): built directly rather than through
-- the registry -- a singular, highly specific structure (unlike Gate/
-- Terminal's uniform per-tag sweep), same reasoning as Zone/CashRegister.
local vaultDoor = VaultDoor.new(workspace.BankVault["Vault Door"], { bank = bank, now = now })
bank:RegisterComponent(vaultDoor)

-- Sequential highlight hints (spec addendum, 2026-09-13): Button1+Button2 ->
-- OpenGate -> Door.Handle, guiding the player through the flow one stage at
-- a time. Built directly, same reasoning as VaultDoor/Zone/CashRegister --
-- a small set of specific, non-tag-driven instances rather than a uniform
-- per-tag sweep.
local function requireHighlight(container: Instance, label: string): Highlight
	local highlight = container:FindFirstChildOfClass("Highlight")
	assert(highlight, "[HeistServer] " .. label .. " is missing its Highlight")
	return highlight
end
local highlightSequencer = HighlightSequencer.new({
	bank = bank,
	vaultDoor = vaultDoor,
	button1Highlight = requireHighlight(workspace.Bank.Button1, "Button1"),
	button2Highlight = requireHighlight(workspace.Bank.Button2, "Button2"),
	handleHighlight = requireHighlight(vaultDoor.handle, "Vault Door.Door.Handle"),
	-- OpenGate is destroyed and respawned from a template across sessions
	-- (see demolishOpenGate/ensureOpenGate below) -- looked up fresh every
	-- time rather than captured once, so this never holds a stale reference
	-- to a gate that has already been blown up.
	getOpenGateHighlight = function()
		return currentOpenGate and currentOpenGate:FindFirstChildOfClass("Highlight")
	end,
})
bank:RegisterComponent(highlightSequencer)
bank.TerminalsChanged:Connect(function() highlightSequencer:OnTerminalPressed() end)
bank.VaultBreachedChanged:Connect(function() highlightSequencer:OnVaultBreached() end)

-- Display1/Display2's neon lights (spec addendum, 2026-09-15): per-button
-- progress feedback, in addition to (not replacing) the highlight hints
-- above -- same reasoning as VaultDoor/Zone/CashRegister for going direct
-- rather than through the tag registry.
local displayLights = DisplayLights.new({
	bank = bank,
	display1 = workspace.Bank.DisplayLights.Display1,
	display2 = workspace.Bank.DisplayLights.Display2,
})
bank:RegisterComponent(displayLights)
bank.TerminalsChanged:Connect(function(id) displayLights:OnTerminalPressed(id) end)


-- Late-bound (construction order across one registry tag-sweep is
-- unspecified): wires the C4 sequence's "Go to Vault" prompt to the real
-- A-teleporter's own validated Use(), once both components definitely exist.
do
	local c4 = byTag[T.HeistC4Point] and byTag[T.HeistC4Point][1]
	local teleporterA
	for _, tp in ipairs(byTag[T.HeistTeleporter] or {}) do
		if tp.role == "A" then teleporterA = tp end
	end
	if c4 and teleporterA then
		c4:SetTeleportAction(function(player) return teleporterA:Use(player) end)
	else
		warn("[HeistServer] could not wire C4Charge to TeleporterBankA -- Go to Vault prompt will never teleport")
	end
end

-- The death volume forfeits with its own cause rather than "laser", and
-- ALSO actually kills the Humanoid — unlike every other hazard, which is
-- deliberate: the spec calls this a "kill-volume", and a silent teleport-out
-- read as "nothing happened" to a player who wasn't watching closely.
-- Forfeiture runs first and unconditionally, so it never depends on the
-- Died event that follows (a disconnect at the moment of death can't skip
-- it). The generic Humanoid.Died handler below will also fire from this and
-- call forfeit:Apply a second time — safe, since Forfeit is idempotent per
-- player per run.
for _, volume in ipairs(byTag[T.HeistDeathVolume] or {}) do
	volume.onContact = function(player)
		-- Admin god (2026-11-20): this Health = 0 kill is the one damage path a ForceField does not stop.
		local godCharacter = player.Character
		if godCharacter and godCharacter:GetAttribute("AdminGod") then
			return
		end
		-- Die, not Eject: this is a death (the spec calls this a kill-volume),
		-- so it must never teleport to ExitSpawn -- only forfeit, then let the
		-- Health = 0 below (and the generic Humanoid.Died handler it triggers)
		-- carry the player through Roblox's own standard respawn flow.
		forfeit:Die(bank, player, "death_pit")
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			-- Open items pass 2026-11-18: a kill from full health reads as a self-reset to WantedService
			-- (the stars would carry); the pit marks the robber hurt first, so it clears heat like any death.
			require(ServerScriptService.Wanted.WantedService).markHurt(player)
			humanoid.Health = 0
		end
	end
end

local alarmLights = {}
local flashModel = workspace.BankVault:FindFirstChild("0.2FlashAlarm")
if flashModel then
	for _, d in ipairs(flashModel:GetDescendants()) do
		if d:IsA("Light") or (d:IsA("BasePart") and d.Parent and d.Parent.Name == "Flash") then
			table.insert(alarmLights, d)
		end
	end
end

-- Templight PointLights fade red on alarm start / back to their own cached
-- color on alarm stop (spec addendum, 2026-09-04) -- distinct from the
-- flash-toggle alarmLights above. Discovered by descendant/class, not by a
-- hardcoded count or individual names, so this scales automatically if
-- lights are added/removed under Bank.Light later.
local templights = {}
-- Bank.Light is NOT a single folder: the scene has 28 separate Model
-- instances all independently named "Light" directly under Bank (one per
-- fixture placement), so FindFirstChild("Light") only ever sees ONE of
-- them arbitrarily and silently misses every templight under the other 27.
-- Scan every descendant of Bank itself and key off the PointLight's own
-- parent being named "TempLight" (the actual per-fixture part), which is
-- unambiguous and unaffected by how many "Light" containers exist above it.
for _, d in ipairs(workspace.Bank:GetDescendants()) do
	if d:IsA("PointLight") and d.Parent and d.Parent.Name == "TempLight" then
		table.insert(templights, d)
	end
end
-- The alarm sound is cloned into both the lobby (BankZone) and the vault
-- (VaultZone) for the duration of an active session and destroyed the
-- instant it ends, so it is audible in both places at once and never
-- lingers (spec addendum, 2026-08-28). AlarmSpeaker.AlarmSound is the
-- pre-placed, pre-configured TEMPLATE -- it is never itself played, only
-- Clone()'d by AlarmEffects.
local alarmSoundTemplate = workspace.BankVault.AlarmSpeaker.AlarmSound
local alarmHosts = { workspace.HeistZones.BankZone, workspace.HeistZones.VaultZone }
local alarm = AlarmEffects.new({
	config = Config, now = now, lights = alarmLights, templights = templights,
	soundTemplate = alarmSoundTemplate, soundHosts = alarmHosts,
})

-- Worn for exactly as long as the DuffelBag GUI would be visible (spec
-- addendum, 2026-09-13) -- see pushDuffel below, the single call site that
-- decides both.
local duffelBagAttachment = DuffelBagAttachment.new({ template = ReplicatedStorage.HeistShared.DuffelBag })

-- ATM machines (spec addendum, 2026-09-14; unlock condition corrected
-- 2026-09-17): same one-time-per-session flat-value rob mechanic as
-- SlowFoods' cash registers, via the shared RobbableObject module --
-- independent of the sequential Button1/Button2 -> OpenGate -> Door.Handle
-- HIGHLIGHT flow above (never gated on that sequence's own stage), but NOT
-- available from session start: deferUnlock defers the prompt/highlight
-- until VaultDoor.isOpen becomes true (see the vaultDoor.isOpen edge-check
-- in the heartbeat loop below) -- confirmed live these are physically
-- reachable only past the Vault Door, so this replaces what used to just be
-- an unenforced "technically on but nobody can reach it yet" gap with the
-- real intended condition.
local atmObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.HeistATM)) do
	local atm = RobbableObject.new(model, {
		bank = bank,
		promptTemplate = heistShared.PromptTemplates.RobATMPrompt,
		amount = Config.ATMRobAmount,
		onRefused = notifyRefused,
		-- Pre-placed on each ATM's attach part, same static-instance pattern
		-- as the SlowFoods registers' own RegisterRobSound.
		playRobSound = function(part) part.ATMRobSound:Play() end,
		deferUnlock = true,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
	})
	bank:RegisterComponent(atm)
	table.insert(atmObjects, atm)
end

-- The Bank's own cash registers (spec addendum, 2026-09-14; unlock
-- condition corrected 2026-09-17): same shared RobbableObject mechanic as
-- the ATMs above, confirmed flat value 2000 (matching SlowFoods' own
-- registers, NOT the Bank ATM's 3000) -- independent of the sequential
-- highlight flow, gated on VaultDoor.isOpen the same way the ATMs are.
local bankRegisterObjects = {}
for _, model in ipairs(CollectionService:GetTagged(T.BankRegister)) do
	local register = RobbableObject.new(model, {
		bank = bank,
		promptTemplate = heistShared.PromptTemplates.RobRegisterPrompt,
		amount = Config.BankRegisterRobAmount,
		onRefused = notifyRefused,
		-- Pre-placed on each register's attach part, same static-instance
		-- pattern as the ATM's own ATMRobSound.
		playRobSound = function(part) part.RegisterRobSound:Play() end,
		deferUnlock = true,
		isBlocked = function(player) return carryState:IsCarrying(player) end,
	})
	bank:RegisterComponent(register)
	table.insert(bankRegisterObjects, register)
end

-- Safe (spec addendum, 2026-09-16): one shared session code owned by
-- SafeCode, validated independently against each of the (currently 2)
-- physical Safe.Safe props -- confirmed live: cracking one does not mark
-- the other robbed, so the same code can be redeemed once per safe. Built
-- directly (SafeCode) plus a small CollectionService sweep (Safe), same
-- shape as ATM/BankRegister above, not through ComponentRegistry (Safe's
-- own onOpenGui hook needs a caller-assigned safeId that ComponentRegistry's
-- generic tag->class map has no way to thread through).
local safeCode = SafeCode.new({
	display = workspace.BankVault["Code Combination"].SurfaceGui.Code,
})
bank:RegisterComponent(safeCode)

local safeById = {}
local safeObjects = {}
do
	local nextId = 0
	for _, model in ipairs(CollectionService:GetTagged(T.BankSafe)) do
		nextId += 1
		local safeId = nextId
		local safe = Safe.new(model, {
			bank = bank,
			promptTemplate = heistShared.PromptTemplates.RobSafePrompt,
			amount = Config.SafeRobAmount,
			getCode = function() return safeCode:GetCode() end,
			onRefused = notifyRefused,
			-- Pre-placed on each safe's attach part, same static-instance
			-- pattern as the ATM's own ATMRobSound.
			playRobSound = function(part) part.SafeRobSound:Play() end,
			onOpenGui = function(player) net:OpenSafeGui(player, safeId) end,
			-- Unlock condition corrected 2026-09-17: gated on VaultDoor.isOpen,
			-- same as ATM/BankRegister above, not session start.
			deferUnlock = true,
			isBlocked = function(player) return carryState:IsCarrying(player) end,
		})
		bank:RegisterComponent(safe)
		safeById[safeId] = safe
		table.insert(safeObjects, safe)
	end
end

-- Heist layers 2026-11-17 (Task 6): the vault's deposit boxes (Heist.Components.DepositBoxes), shut
-- until the vault door opens (the latch in the heartbeat below). One box a run may hold the gold
-- bar: a start-hidden SupplyObject handed to the solver, slowed, bank-only, banked by goldGetaway.
local goldBar = SupplyObject.new(workspace.BankVault.GoldBar, {
	bank = bank,
	-- Never armed (startHidden): the bar only appears through GiveTo or a drop.
	promptTemplate = heistShared.PromptTemplates.PickUpGoldBarPrompt,
	repickupPromptTemplate = heistShared.PromptTemplates.PickUpGoldBarPrompt,
	cashOutAmount = Config.GoldBarValue,
	bankOnly = true,
	speedCap = CARRY_SPEED_CAP,
	startHidden = true,
	-- 2026-11-18: the carry shows the Bank's getaway widget; the re-pickup prompt re-measures reach (M3).
	getawayLocation = "Bank",
	checkReach = true,
	onRefused = notifyRefused,
	isBlocked = function(player) return carryState:IsCarrying(player) end,
	onPickup = function(player, bar)
		return carryState:PickUp(player, heistShared.ModelTemplates.GoldBarTool, bar)
	end,
})
bank:RegisterComponent(goldBar)

-- Leftovers (2026-11-18): only Carrier stands on the carrier-only ledges, whichever group registered
-- first (a group registered later collides with every group by default). Deferred past the boot's
-- other registrations; the two groups scripts register lazily (EnemyRig's EnemyCharacter,
-- RagdollController's Ragdoll) are registered in the place itself for the same reason.
task.defer(function()
	local PhysicsService = game:GetService("PhysicsService")
	local ok, err = pcall(function()
		for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			if group.name ~= "Carrier" then
				PhysicsService:CollisionGroupSetCollidable(group.name, "CarrierLedge", false)
			end
		end
	end)
	if not ok then warn("[HeistServer] carrier ledge groups: " .. tostring(err)) end
end)

local depositBoxes
do
	local boxModels = {}
	for i = 1, Config.DepositBoxCount do
		boxModels[i] = workspace.BankVault.DepositBoxes["DepositBox" .. i]
	end
	depositBoxes = DepositBoxes.new(boxModels, {
		bank = bank,
		net = net,
		config = Config,
		carryState = carryState,
		goldBar = goldBar,
		now = now,
		roll = function(count)
			local forced = Config.Debug.DepositBoxContents
			if forced then return table.clone(forced) end
			return DepositBoxLoot.roll(Random.new(), count, Config.GoldBarChance)
		end,
	})
	bank:RegisterComponent(depositBoxes)
end

-- The one client -> server signal in this system (see Net's own REMOTE_NAMES
-- comment for why this doesn't violate spec 6.8). A 0.5s per-player debounce
-- guards against network-level spam/automation only -- NOT a gameplay
-- throttle: the spec explicitly wants unlimited manual retries with no
-- cooldown, and 0.5s is imperceptible to a human re-opening the prompt and
-- retyping four digits.
local SAFE_SUBMIT_DEBOUNCE = 0.5
local lastSafeSubmit = {}
net:OnSafeCodeSubmitted(function(player, safeId, digits)
	if type(safeId) ~= "number" or type(digits) ~= "string" then return end
	local now2 = os.clock()
	local last = lastSafeSubmit[player]
	if last and (now2 - last) < SAFE_SUBMIT_DEBOUNCE then return end
	lastSafeSubmit[player] = now2

	local safe = safeById[safeId]
	if not safe then return end

	local ok, reason = safe:TrySubmitCode(player, digits)
	if ok then
		net:Toast(player, "Safe cracked!")
	elseif reason == "wrong_code" then
		net:Toast(player, "Wrong Code")
	elseif reason == "already_robbed" then
		net:Toast(player, "Already cracked.")
	elseif reason == "inactive" then
		net:Toast(player, REFUSAL_MESSAGES.inactive)
	end
	-- cap_exceeded/not_participant/invalid_amount are already toasted via
	-- notifyRefused from inside Safe:TrySubmitCode itself.
end)

-- Boot manifest.
do
	local manifest = registry:Manifest()
	local parts = {}
	for tag, count in pairs(manifest) do
		table.insert(parts, string.format("%s=%d", tag, count))
	end
	table.sort(parts)
	print(string.format("[HeistServer] Bank booted: %s ATM=%d BankRegister=%d Safe=%d, zones=%d, alarmLights=%d, templights=%d",
		table.concat(parts, " "), #atmObjects, #bankRegisterObjects, #safeObjects, #zones, #alarmLights, #templights))
end

-- Gate helper, declared before anything that references it (the StateChanged
-- handler below now calls it, so it must exist as a local by this point).
local function openGateGroup(groupName)
	for _, gate in ipairs(byTag[T.HeistGate] or {}) do
		if gate.part:GetAttribute("GateGroup") == groupName then
			gate:Open()
		end
	end
end

-- Server-authoritative "your bag is filling up" cue (spec addendum,
-- 2026-08-28): fires on genuine Vault entry, not on client-derived duffel
-- display state. Also declared before the StateChanged handler below, which
-- calls it for anyone already standing in the Vault the instant a new
-- session goes Active -- otherwise a player who never left the zone across
-- the Cooldown->Active boundary would never hear it.
local function playDuffelReadyCue(player)
	if bank:GetState() ~= "Active" then return end
	if not bank:IsParticipant(player) then return end
	net:PlayCue(player, "DuffelInitiateSound")
end

-- Fires exactly once per session, the instant VaultDoor.isOpen becomes
-- true (spec addendum, 2026-09-17): ATM/BankRegister/Safe used to unlock
-- immediately at session start via the standard OnSessionStart dispatch --
-- confirmed live these are only physically reachable once the Vault Door
-- opens (past the whole gauntlet), so deferUnlock now holds them locked
-- until this fires. Reset to false whenever the session leaves Active (see
-- StateChanged below), so it re-arms correctly for the next session.
local vaultDoorUnlocked = false

-- State broadcast
bank.StateChanged:Connect(function(state)
	net:BroadcastState("Bank", state, bank:GetEndsAt(), bank:GetCooldownEndsAt())
	if state == "Active" then
		alarm:Start()
		-- CounterDoor is no longer a Gate (spec addendum, 2026-09-05): its 4
		-- static barriers are CounterBarrier components now, opened/closed via
		-- the standard OnSessionStart/Seal registry lifecycle (below, via
		-- TryStart/_seal) instead of a bespoke tag-group call here.
		for _, player in ipairs(zoneService:GetOccupants("Vault")) do
			playDuffelReadyCue(player)
		end
	else
		alarm:Stop()
		vaultDoorUnlocked = false
		if state == "Cooldown" then
			-- Session-end safety net (spec addendum, 2026-09-13): every actual
			-- participant is already detached via the DuffelChanged -> pushDuffel
			-- chain that VoidDuffel triggers during _seal -- this is defensive
			-- redundancy against any missed :Sync, checked against every
			-- currently-connected player, not just this session's roster.
			duffelBagAttachment:ForceDetachAll(Players:GetPlayers())
		elseif state == "Idle" then
			-- "The point buttons become interactable again post-cooldown": a
			-- fresh OpenGate is ready for the next robbery to demolish, unless
			-- the current one (the original, or an earlier respawn) is still
			-- standing because this session never breached the vault.
			ensureOpenGate()
			-- A genuine re-open after a cooldown, never server boot: BankInstance
			-- seeds its initial Idle as a plain field rather than through
			-- _setState, so this signal only ever fires from _rearm.
			net:NotifyLocationOpened("Bank")
		end
	end
end)

-- Button1Lasers/Button2Lasers' bars (Bank.Button1Lasers/Button2Lasers'
-- "BigLazer" parts, GateGroup="LobbyBarrier" left as a location label only --
-- see the WorldSpec comment on that group) each physically swing open AND
-- stop being hazardous the instant THEIR OWN terminal is pressed (spec
-- addendum, 2026-08-30; scoped per-button and decoupled from the other
-- button 2026-09-16) -- fully independent of the other button's terminal,
-- NOT gated on AreTerminalsComplete() the way the old single shared barrier
-- was. AreTerminalsComplete() still gates everything downstream of the
-- barrier itself (HighlightSequencer's stage 2, C4Charge) -- unaffected by
-- this change, which only concerns these 4 bars' own motion/hazard. Each
-- bar declares its own HazardTerminalId (1 or 2, set once in Studio); one
-- parameterized resolver for both buttons, not two near-identical call
-- sites -- open() and DisableHazard() are the same per-button action here,
-- so they're merged into a single sweep rather than two separate ones that
-- could drift out of scope with each other.
local function resolveButtonBarrier(terminalId: number)
	for _, gate in ipairs(byTag[T.HeistGate] or {}) do
		if gate.part:GetAttribute("HazardTerminalId") == terminalId then
			gate:Open()
			if gate.hazardous then gate:DisableHazard() end
		end
	end
end

bank.TerminalsChanged:Connect(function(id)
	resolveButtonBarrier(id)
end)

bank.GuardsCleared:Connect(function()
	openGateGroup("GuardRoom")
end)

-- Per-player "inside the building right now" tracking (spec addendum,
-- 2026-09-06, extended 2026-09-11) -- drives the client's PlayerInZone AND
-- RobberyActive gate for the heist timer. "Inside the building" = Lobby OR
-- Vault OR BankVaultZone (the lobby, the vault loot zone, and the whole
-- underground gauntlet between them -- no gap where the timer would
-- incorrectly disappear mid-heist); Claim is deliberately excluded (it's
-- outside).

-- Same union updateZoneOccupancy uses: Lobby OR Vault OR BankVaultZone --
-- the lobby, the vault, and the whole underground gauntlet between them.
-- This gate is what makes the Bank correct: its VaultZone is 314 studs
-- horizontally from its own StatusBillboardAnchor, so without it an
-- EscapeDistance of 200 would bank the bag the instant it filled, with no
-- getaway at all.
--
-- Declared ahead of updateZoneOccupancy rather than beside the Getaway
-- construction further down, so that both callers share this one expression:
-- a local referenced above its own declaration resolves to a nil global.
function isInsideBank(player)
	return zoneService:IsInside("Lobby", player)
		or zoneService:IsInside("Vault", player)
		or zoneService:IsInside("BankVaultZone", player)
end

local insideBuilding = {}
local function updateZoneOccupancy()
	for _, player in ipairs(Players:GetPlayers()) do
		local inside = isInsideBank(player)
		if insideBuilding[player] ~= inside then
			insideBuilding[player] = inside
			net:BroadcastZoneOccupancy("Bank", player, inside)
		end
	end
end

-- The DuffelBag accessory tracks this SAME base/rate pair (spec addendum,
-- 2026-09-13), computed once here and reused for both the GUI payload and
-- the accessory sync -- identical to the client's own wantDuffel formula
-- (amount > 0 or rate > 0), so the two can never show conflicting state.
local function pushDuffel(player)
	local inVault = zoneService:IsInside("Vault", player)
	local rate = (inVault and bank:GetState() == "Active" and bank:IsParticipant(player))
		and bank:GetAccrualRate(player) or 0
	local amount = bank:GetDuffel(player)
	net:SendDuffel("Bank", player, amount, rate, now(), bank:GetDuffelCap(player))
	duffelBagAttachment:Sync(player, amount > 0 or rate > 0)
end

bank.DuffelChanged:Connect(function(player) pushDuffel(player) end)
zoneService.Entered:Connect(function(role, player)
	if role ~= "Vault" then return end
	pushDuffel(player)
	playDuffelReadyCue(player)
end)
zoneService.Exited:Connect(function(role, player)
	if role == "Vault" then pushDuffel(player) end
end)

-- The payout, moved verbatim out of the old claim-zone Entered handler
-- (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
local function bankBag(player)
	local amount = bank:Claim(player)
	if amount <= 0 then return end
	local banked = math.floor(amount)
	currency:Add(player.UserId, banked)
	net:Toast(player, string.format("Banked %d %s.", banked, Config.CurrencyName))
	-- Cash burst + flying-cash-GUI trigger (spec addendum, 2026-09-09) --
	-- fired after currency:Add so leaderstats.Cash.Value has already
	-- replicated the new total by the time the client reacts to this.
	net:NotifyRobberySuccess(player)
end

-- Distance-based payout, replacing the Claim zone (spec:
-- Getaway-Distance-Claim-And-GUI, 2026-09-19). Constructed here, below both
-- updateZoneOccupancy and bankBag, because it captures isInsideBank (the
-- shared three-role union) and bankBag: Getaway.new asserts on a nil
-- onEscaped, so building it any earlier would fail at boot.
local heistMarkers = workspace:WaitForChild("HeistMarkers", 10)
local bankAnchor = heistMarkers and heistMarkers:WaitForChild("StatusBillboardAnchor", 10)
assert(bankAnchor, "[HeistServer] HeistMarkers has no StatusBillboardAnchor")
local getaway = Getaway.new({
	escapeDistance = Config.EscapeDistance,
	anchor = bankAnchor,
	isInsideBuilding = isInsideBank,
	getDuffel = function(player) return bank:GetDuffel(player) end,
	getPlayers = function() return Players:GetPlayers() end,
	onEscaped = bankBag,
})

-- Heist layers 2026-11-17 (Task 6): the gold bar banks GoldBarValue once its carrier is out of the
-- building (same isInsideBank) and EscapeDistance from the same anchor as the bag.
local goldGetaway = CarryGetaway.new({
	escapeDistance = Config.EscapeDistance,
	anchor = bankAnchor,
	isInsideBuilding = isInsideBank,
	matches = function(carried) return carried == goldBar end,
	value = Config.GoldBarValue,
	carryState = carryState,
	currency = currency,
	net = net,
	getPlayers = function() return Players:GetPlayers() end,
	addActiveRobbery = require(ServerScriptService.Wanted.WantedService).addActiveRobbery,
})

-- Police and wanted (fix rounds 1-2): a participant of the Bank's Active session counts as seen while still
-- at the robbery (Lobby, Vault or BankVaultZone, or within EscapeDistance of the anchor: Getaway:IsNear).
require(game:GetService("ServerScriptService").Wanted.WantedService).addActiveRobbery(function(player)
	return bank:GetState() == "Active" and bank:IsParticipant(player) and getaway:IsNear(player)
end)

-- Heist police and Bank guards (2026-11-20): police sent into the vault from the robbery's start (Config.HeistPolice)
-- and armed police from the vault door's opening (Config.HeistPoliceVault), at HeistMarkers.HeistPoliceSpawn1..3
-- round the corner from TeleporterBankB's arrival. A bank component: it starts with the session, leaves at the seal.
local heistPoliceMarkers = HeistPolice.markersIn(heistMarkers)
assert(#heistPoliceMarkers >= 1, "[HeistServer] HeistMarkers has no HeistPoliceSpawn marker")
local heistPolice = HeistPolice.new({
	bank = bank,
	plan = Config.HeistPolice,
	vaultPlan = Config.HeistPoliceVault,
	markers = heistPoliceMarkers,
	isInside = isInsideBank,
	now = now,
})
bank:RegisterComponent(heistPolice)

-- Trigger: a weapon equipped inside the lobby zone. Both conditions are read
-- server-side; a spoofed client equip achieves nothing. Two entry points feed
-- one shared function, because the trigger must fire in EITHER order: equip
-- while already inside the zone, or walk in already holding the weapon.
local TRIGGER_DEBOUNCE = 1.0
local recentTriggerAttempt = {}
-- Fires once per player per cap-fill, not once per heartbeat tick while they
-- sit at cap. Cleared when they drop back below cap (VoidDuffel/Claim) so a
-- second fill notifies again.
local duffelFullNotified = {}

local function hasEquippedWeapon(character): boolean
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and CollectionService:HasTag(child, T.Weapon) then
			return true
		end
	end
	return false
end

-- Debounced so re-entering the zone or re-equipping/re-holstering repeatedly
-- (e.g. boundary jitter at the BankZone edge) cannot spam TryStart or the
-- toasts it sends. bank:TryStart's own already_active/cooldown guards make
-- a duplicate call harmless either way; this only stops the event spam.
local function tryTriggerRobbery(player)
	-- Supplies Robbery (spec addendum, 2026-09-19): belt-and-braces on top of
	-- CarryState:PickUp's own Unequipped-based safeguard.
	if carryState:IsCarrying(player) then
		net:Toast(player, Config.SupplyCarryingRefusalMessage)
		return
	end

	local nowClock = os.clock()
	local last = recentTriggerAttempt[player]
	if last and (nowClock - last) < TRIGGER_DEBOUNCE then return end
	recentTriggerAttempt[player] = nowClock

	local ok, reason = bank:TryStart(player)
	if ok then
		-- No personal Toast (2026-09-13): NotifyRobberyTriggered fires to ALL
		-- clients including this one, so a separate personal "Alarm triggered"
		-- message was duplicate information for the player already being told.
		-- Removed here as well as in LocationServer -- the Bank does not go
		-- through that factory, so fixing only the shared copy would have left
		-- this duplicate behind.
		net:NotifyRobberyTriggered("Bank", player.Name)
		-- Police and wanted (2026-11-17): the robbery's participants get the Bank's alarm heat. The Bank
		-- enrols through the gauntlet, so the player who set it off may not be a participant yet.
		local robbers = bank:GetParticipants()
		if not table.find(robbers, player) then table.insert(robbers, player) end
		require(game:GetService("ServerScriptService").Wanted.WantedService).onAlarm("Bank", robbers)
		return
	end
	if reason == "cooldown" then
		local remaining = math.max(0, (bank:GetCooldownEndsAt() or 0) - now())
		net:Toast(player, string.format("Vault sealed. %d:%02d remaining.",
			remaining // 60, math.floor(remaining % 60)))
	end
end

-- Entry point A: weapon equipped while already inside the zone.
zoneService.Entered:Connect(function(role, player)
	if role ~= "Lobby" then return end
	local character = player.Character
	if character and hasEquippedWeapon(character) then
		tryTriggerRobbery(player)
	end
end)

local function watchCharacter(player, character)
	-- Entry point B: zone entered while the weapon is already equipped.
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		if not CollectionService:HasTag(child, T.Weapon) then return end
		if not zoneService:IsInside("Lobby", player) then return end
		tryTriggerRobbery(player)
	end)

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			-- Catches every death cause, including guards and falls that the
			-- hazard components never see. Die, never Eject/teleport: standard
			-- Roblox respawn (the regular SpawnLocation) proceeds untouched.
			if bank:GetState() == "Active" and bank:IsParticipant(player) then
				forfeit:Die(bank, player, "died")
			end
		end)
	end
end

require(ReplicatedStorage.Utility.safePlayerAdded)(function(player)
	if player.Character then watchCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(character) watchCharacter(player, character) end)
	-- City (phase 3 Task 5): a character removed WITHOUT dying (LoadCharacter, anything that
	-- skips Died) forfeits like a death. The bag is keyed by Player and the city spawn is past
	-- EscapeDistance, so otherwise the respawn banked it. The vault teleporters and the forfeit
	-- eject move the character with PivotTo and never fire this. After a real death the player
	-- is already off the roster, so the CharacterRemoving that follows does nothing.
	player.CharacterRemoving:Connect(function()
		if bank:GetState() == "Active" and bank:IsParticipant(player) then
			forfeit:Die(bank, player, "died")
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	-- The bag is not persisted, so leaving mid-run loses it by construction.
	bank:RemoveParticipant(player)
	-- Without this, _duffels keeps a strong reference to the stale Player
	-- instance forever (silent cleanup, not a forfeiture -- no signal, no toast).
	bank:ForgetPlayer(player)
	zoneService:ForgetPlayer(player)
	forfeit:Forget(player)
	-- Same cleanup LocationServer:ForgetPlayer does: without it Getaway's
	-- fired-once latch keeps a strong reference to the departed Player.
	getaway:Forget(player)
	goldGetaway:Forget(player)
	duffelBagAttachment:Forget(player)
	recentTriggerAttempt[player] = nil
	duffelFullNotified[player] = nil
	recentLaserHit[player] = nil
	insideBuilding[player] = nil
	-- Regression found via adversarial review, 2026-09-16: this one was
	-- missed when SubmitSafeCode's debounce table was added -- every
	-- sibling per-player table above gets cleared here, this one didn't.
	lastSafeSubmit[player] = nil
end)

-- One heartbeat drives the session clock, occupancy, accrual and the alarm.
-- Hazards run on a faster sweep because a missed laser contact is unacceptable.
task.spawn(function()
	local sessionInterval = 1 / Config.HeartbeatRate
	local accumulator = 0
	local lastTick = now()

	local hazardInterval = 1 / Config.HazardQueryRate
	local hazardAccumulator = 0

	while true do
		local dt = RunService.Heartbeat:Wait()
		accumulator += dt
		hazardAccumulator += dt

		if hazardAccumulator >= hazardInterval then
			hazardAccumulator = 0
			for _, laser in ipairs(byTag[T.HeistLaser] or {}) do
				laser:Update()
			end
			-- Cheap no-op for the three non-hazardous gates (CounterDoor,
			-- GuardRoom): Gate:Update() returns before touching anything else.
			for _, gate in ipairs(byTag[T.HeistGate] or {}) do
				gate:Update()
			end
		end

		if accumulator < sessionInterval then continue end
		local elapsed = now() - lastTick
		lastTick = now()
		accumulator = 0

		bank:Step()
		zoneService:Update()
		alarm:Update()
		updateZoneOccupancy()
		-- Last of the sweep, so the getaway's isInsideBuilding reads the
		-- occupancy this same tick's zone pass just established rather than the
		-- previous tick's -- the same ordering LocationServer:Tick uses. Outside
		-- the Active branch below because it needs no state check of its own:
		-- every branch in Getaway:Step is gated on the player still holding a
		-- bag, and _seal voids every participant's bag, so once a session ends
		-- this steps to a no-op on its own. Keeping it out here is what holds it
		-- adjacent to the zone pass it reads, and keeps its fired-once latch
		-- re-arming every tick rather than only while Active.
		getaway:Step()
		goldGetaway:Step()
		-- Heist police and Bank guards (2026-11-20): the guards stand at all times (a killed one comes back, a
		-- provoked one fights outside a session), so they update in every state; the heist police act while Active.
		for _, post in ipairs(byTag[T.HeistGuardPost] or {}) do
			post:Update()
		end
		heistPolice:Update()

		if bank:GetState() == "Active" then
			for _, player in ipairs(zoneService:GetOccupants("Vault")) do
				bank:Accrue(player, elapsed)
				if bank:GetDuffel(player) >= Config.DuffelCap then
					if not duffelFullNotified[player] then
						duffelFullNotified[player] = true
						net:Toast(player, "Duffel Full. Get clear of the building to bank it.")
					end
				else
					duffelFullNotified[player] = nil
				end
			end
			for _, charge in ipairs(byTag[T.HeistC4Point] or {}) do
				charge:Update()
			end
			vaultDoor:Update()
			highlightSequencer:Update()

			-- ATM/BankRegister/Safe unlock the instant the Vault Door finishes
			-- opening (spec addendum, 2026-09-17) -- same edge-triggered
			-- isOpen-transition polling HighlightSequencer already does just
			-- above, fired exactly once per session via vaultDoorUnlocked.
			if vaultDoor.isOpen and not vaultDoorUnlocked then
				vaultDoorUnlocked = true
				for _, atm in ipairs(atmObjects) do atm:Unlock() end
				for _, register in ipairs(bankRegisterObjects) do register:Unlock() end
				for _, safe in ipairs(safeObjects) do safe:Unlock() end
				depositBoxes:Unlock()
				heistPolice:OnVaultOpened() -- heist police (2026-11-20): the armed waves start
			end
		end
	end
end)


