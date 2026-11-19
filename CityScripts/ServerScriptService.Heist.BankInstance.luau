--!strict
local Signal = require(game.ReplicatedStorage.HeistShared.Signal)
-- Leftovers (2026-11-18): one grant may not exceed this; NaN and infinities fail the same check.
local MAX_BAG_GRANT = require(game.ReplicatedStorage.HeistShared.Config).MaxBagGrant

local function validGrant(amount): boolean
	return type(amount) == "number" and amount > 0 and amount <= MAX_BAG_GRANT
end

local BankInstance = {}
BankInstance.__index = BankInstance

local IDLE, ACTIVE, COOLDOWN = "Idle", "Active", "Cooldown"

function BankInstance.new(deps)
	assert(deps and deps.config, "BankInstance requires a config")
	assert(type(deps.now) == "function",
		"BankInstance requires an injected clock; never call GetServerTimeNow() in here")

	return setmetatable({
		config = deps.config,
		now = deps.now,
		model = deps.model,
		onForfeit = deps.onForfeit or function() end,
		-- Fired whenever a player (re)joins the roster. HeistServer wires this to
		-- forfeit:Forget(player), so a forfeit latch from an EARLIER episode never
		-- immunises a player who re-enters. BankInstance must not know about
		-- Forfeit; this hook is how HeistServer wires the two together without
		-- either module reaching for the other.
		onParticipantAdded = deps.onParticipantAdded or function() end,
		-- Universal gamepass modifiers (spec addendum, 2026-09-03), injected so
		-- this Bank-specific instance never requires GamepassManager directly --
		-- HeistServer wires the two together, same pattern as onForfeit above.
		-- Default 1x preserves every existing caller that doesn't pass these.
		duffelCapMultiplier = deps.duffelCapMultiplier or function() return 1 end,
		accrualRateMultiplier = deps.accrualRateMultiplier or function() return 1 end,

		_state = IDLE,
		_runId = 0,
		_endsAt = nil,
		_cooldownEndsAt = nil,
		_components = {},
		_participants = {},
		_terminals = {},
		-- Gates TeleporterBankA once the C4 sequence completes. Same lifecycle as
		-- _terminals: survives a seal (so a forfeited/re-entering player doesn't
		-- need to re-blow the door), cleared only at rearm (so a genuinely NEW
		-- robbery requires re-planting).
		_vaultBreached = false,
		_guardsRemaining = 0,
		_guardsClearedFired = false,

		_duffels = {},

		StateChanged = Signal.new(),
		GuardsCleared = Signal.new(),
		TerminalsChanged = Signal.new(),
		VaultBreachedChanged = Signal.new(),
		DuffelChanged = Signal.new(),
	}, BankInstance)
end

function BankInstance:GetState(): string
	return self._state
end

function BankInstance:GetRunId(): number
	return self._runId
end

function BankInstance:GetEndsAt(): number?
	return self._endsAt
end

function BankInstance:GetCooldownEndsAt(): number?
	return self._cooldownEndsAt
end

function BankInstance:GetSecondsRemaining(): number
	if self._state ~= ACTIVE or not self._endsAt then return 0 end
	return math.max(0, self._endsAt - self.now())
end

function BankInstance:RegisterComponent(component)
	table.insert(self._components, component)
end

-- Every component call is isolated: a broken laser must never stop the session
-- clock or prevent the remaining components from being told what to do.
function BankInstance:_eachComponent(methodName: string)
	for _, component in ipairs(self._components) do
		local method = component[methodName]
		if type(method) == "function" then
			local ok, err = pcall(method, component)
			if not ok then
				warn(string.format("[BankInstance] %s failed on a component: %s", methodName, tostring(err)))
			end
		end
	end
end

function BankInstance:_setState(newState: string)
	local oldState = self._state
	if oldState == newState then return end
	self._state = newState
	self.StateChanged:Fire(newState, oldState)
end

function BankInstance:TryStart(player): (boolean, string?)
	if self._state == ACTIVE then return false, "already_active" end
	if self._state == COOLDOWN then return false, "cooldown" end

	self._runId += 1
	self._endsAt = self.now() + self.config.effective("SessionDuration")
	self._cooldownEndsAt = nil
	self._terminals = {}
	self._vaultBreached = false
	-- NOT seeded from Config.GuardCount: a spawn failure would leave this stuck
	-- above zero forever and the guard barrier would never open. Each GuardPost
	-- calls NotifyGuardSpawned() from its own OnSessionStart only after a real
	-- spawn succeeds, via _eachComponent below, so this counts guards that
	-- actually exist in the world, not guards the config merely asked for.
	self._guardsRemaining = 0
	self._guardsClearedFired = false
	self:_setState(ACTIVE)
	self:_eachComponent("OnSessionStart")
	return true
end

-- Stage 1 of teardown (spec 4.3): seal access, eject everyone, void every bag.
-- Deliberately does NOT rearm the world; that is stage 2.
function BankInstance:_seal(cause: string)
	self:_eachComponent("Seal")
	for _, player in ipairs(self:GetParticipants()) do
		local ok, err = pcall(self.onForfeit, player, cause)
		if not ok then warn("[BankInstance] onForfeit failed: " .. tostring(err)) end
	end
	self._participants = {}
	self._cooldownEndsAt = (self._endsAt or self.now()) + self.config.effective("CooldownDuration")
	self:_setState(COOLDOWN)
end

-- Stage 2: the world becomes dangerous again.
function BankInstance:_rearm()
	self:_eachComponent("Rearm")
	self._terminals = {}
	self._vaultBreached = false
	self._guardsRemaining = 0
	self._guardsClearedFired = false
	self._endsAt = nil
	self._cooldownEndsAt = nil
	self:_setState(IDLE)
end

-- Loops rather than branches, so a single Step after a long stall (or a huge
-- clock jump in a test) walks through every stage it should have passed.
function BankInstance:Step()
	local now = self.now()
	local guard = 0
	while guard < 4 do
		guard += 1
		if self._state == ACTIVE and self._endsAt and now >= self._endsAt then
			self:_seal("timer_expired")
		elseif self._state == COOLDOWN and self._cooldownEndsAt and now >= self._cooldownEndsAt then
			self:_rearm()
		else
			return
		end
	end
end

-- Admin (2026-11-20, through Admin.Hooks.heists): ends a cooldown now. The normal rearm runs (components,
-- StateChanged, the broadcast and the LocationOpened card). Only from Cooldown: an open or robbed location is
-- left as it is, and its state is the second value.
function BankInstance:ResetCooldown(): (boolean, string?)
	if self._state ~= COOLDOWN then return false, self._state end
	self._cooldownEndsAt = self.now()
	self:Step()
	return true
end

function BankInstance:AddParticipant(player)
	if table.find(self._participants, player) then return end
	table.insert(self._participants, player)
	local ok, err = pcall(self.onParticipantAdded, player)
	if not ok then warn("[BankInstance] onParticipantAdded failed: " .. tostring(err)) end
end

function BankInstance:RemoveParticipant(player)
	local i = table.find(self._participants, player)
	if i then table.remove(self._participants, i) end
end

function BankInstance:IsParticipant(player): boolean
	return table.find(self._participants, player) ~= nil
end

function BankInstance:GetParticipants()
	return table.clone(self._participants)
end

function BankInstance:SetTerminal(id: number): boolean
	if self._state ~= ACTIVE then return false end
	if self._terminals[id] then return false end
	self._terminals[id] = true
	self.TerminalsChanged:Fire(id)
	return true
end

function BankInstance:IsTerminalPressed(id: number): boolean
	return self._terminals[id] == true
end

function BankInstance:AreTerminalsComplete(): boolean
	return self._terminals[1] == true and self._terminals[2] == true
end

function BankInstance:IsVaultBreached(): boolean
	return self._vaultBreached
end

-- Idempotent: a second detonation (should one ever be possible) is a no-op,
-- not a second signal/state change. HeistServer listens to this to refresh
-- the A teleporter's prompt text the moment the vault actually breaches --
-- otherwise it stays showing "Locked" until the next failed Use attempt or
-- session rearm, which reads as broken even though entry already works.
function BankInstance:SetVaultBreached()
	if self._vaultBreached then return end
	self._vaultBreached = true
	self.VaultBreachedChanged:Fire()
end

function BankInstance:GuardsRemaining(): number
	return self._guardsRemaining
end

-- Called by a GuardPost's own OnSessionStart, once, only after its spawn
-- actually succeeds. See TryStart for why this replaces seeding from config.
function BankInstance:NotifyGuardSpawned()
	self._guardsRemaining += 1
end

function BankInstance:NotifyGuardDied()
	if self._guardsRemaining <= 0 then return end
	self._guardsRemaining -= 1
	if self._guardsRemaining == 0 and not self._guardsClearedFired then
		self._guardsClearedFired = true
		self.GuardsCleared:Fire()
	end
end

-- Duffel contents live here and ONLY here: server memory, never a DataStore,
-- never leaderstats, never a Value object. An unbanked bag therefore has no
-- persistent representation anywhere, so no rejoin, crash or server-hop can
-- turn one into money. That structural property is the core anti-dupe
-- guarantee — it holds even if a validation check elsewhere is wrong.
function BankInstance:GetDuffel(player): number
	return self._duffels[player] or 0
end

-- Base cap times whatever this player's gamepass ownership resolves to
-- (1x/2x/4x, highest-tier-wins). This Bank's Config.DuffelCap is the BASE
-- value a future robbery system's own base constant is multiplied against
-- the exact same way -- the multiplier logic itself never varies by location.
function BankInstance:GetDuffelCap(player): number
	return self.config.DuffelCap * self.duffelCapMultiplier(player)
end

-- Base accrual rate times this player's Duffel Speed+ multiplier (1x if not
-- owned). Exposed publicly, not just used internally by Accrue, so the
-- client-facing rate HeistServer sends for extrapolation can never drift
-- from what Accrue actually applies -- one number, two callers.
function BankInstance:GetAccrualRate(player): number
	return self.config.AccrualPerSecond * self.accrualRateMultiplier(player)
end

function BankInstance:Accrue(player, dt: number): number
	if self._state ~= ACTIVE then return 0 end
	if not self:IsParticipant(player) then return 0 end
	if type(dt) ~= "number" or dt <= 0 then return 0 end

	local current = self:GetDuffel(player)
	local room = self:GetDuffelCap(player) - current
	if room <= 0 then return 0 end

	local added = math.min(self:GetAccrualRate(player) * dt, room)
	self._duffels[player] = current + added
	self.DuffelChanged:Fire(player, self._duffels[player], "accrue")
	return added
end

-- Guarded on BOTH state and roster membership, independent of any forfeit
-- latch: a stale bag must never convert to cash, regardless of what a
-- latch elsewhere believes. This is the second half of the dupe fix — (a)
-- alone (clearing the latch on re-join) is not sufficient, because a sealed
-- session must refuse to pay out even if some other path left a nonzero bag.
function BankInstance:Claim(player): number
	if self._state ~= ACTIVE then return 0 end
	if not self:IsParticipant(player) then return 0 end
	local amount = self:GetDuffel(player)
	if amount <= 0 then return 0 end
	self._duffels[player] = 0
	self.DuffelChanged:Fire(player, 0, "claim")
	return amount
end

-- Discrete, one-time lump-sum grant, distinct from Accrue's per-tick clamp:
-- rejects the WHOLE amount outright if it would exceed the cap, rather than
-- crediting a partial amount up to the room available (spec addendum,
-- 2026-09-06 -- SlowFoods' cash registers grant a flat amount per
-- interaction, not a continuous rate, so "partially rob a register" makes
-- no sense the way "partially fill the last few seconds of accrual" does).
function BankInstance:TryAddDuffel(player, amount: number): (boolean, string?)
	if self._state ~= ACTIVE then return false, "inactive" end
	if not self:IsParticipant(player) then return false, "not_participant" end
	if not validGrant(amount) then return false, "invalid_amount" end

	local current = self:GetDuffel(player)
	local cap = self:GetDuffelCap(player)
	if current + amount > cap then return false, "cap_exceeded" end

	self._duffels[player] = current + amount
	self.DuffelChanged:Fire(player, self._duffels[player], "add")
	return true
end

-- Signature-layer bonus (heist layers 2026-11-17): same guards as TryAddDuffel but NO cap
-- check, so a layer's bonus lands on top of a full bag. Banks through the bag (Claim), and a
-- seal or death voids it like any other bag money.
function BankInstance:AddBonus(player, amount: number): (boolean, string?)
	if self._state ~= ACTIVE then return false, "inactive" end
	if not self:IsParticipant(player) then return false, "not_participant" end
	if not validGrant(amount) then return false, "invalid_amount" end

	self._duffels[player] = self:GetDuffel(player) + amount
	self.DuffelChanged:Fire(player, self._duffels[player], "add")
	return true
end

function BankInstance:VoidDuffel(player): number
	local amount = self:GetDuffel(player)
	self._duffels[player] = 0
	self.DuffelChanged:Fire(player, 0, "void")
	return amount
end

-- Silent cleanup for a player who left the game, NOT a forfeiture: no signal
-- fires (there is no one left to notify), and nothing is banked or voided.
-- Without this, _duffels keeps a strong reference to a stale Player instance
-- forever once they disconnect.
function BankInstance:ForgetPlayer(player)
	self._duffels[player] = nil
end

return BankInstance
