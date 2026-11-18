--!strict
local Forfeit = {}
Forfeit.__index = Forfeit

-- Five distinct events mean "this run is over for you": laser contact, guard
-- damage, the death pit, timer expiry, and dying in the lobby with a full bag.
-- They all land here. Duplicating this logic even twice would guarantee that
-- one copy eventually forgets to clear the bag, which is a currency dupe.
function Forfeit.new(deps)
	assert(deps and type(deps.teleport) == "function", "Forfeit requires a teleport function")
	assert(type(deps.exitCFrame) == "function", "Forfeit requires an exitCFrame function")

	return setmetatable({
		teleport = deps.teleport,
		notify = deps.notify or function() end,
		exitCFrame = deps.exitCFrame,
		-- Optional (final review I2, 2026-11-18): the CarryState whose heavy carries an inside eject takes.
		carryState = deps.carryState,
		log = deps.log or function(msg) print("[Forfeit] " .. msg) end,
		-- player -> runId of the run in which they were already forfeited.
		_appliedRun = {},
	}, Forfeit)
end

-- Shared core: void the duffel, drop participation, notify, log. The
-- idempotency latch is keyed by run only, not by which of Eject/Die reaches
-- it first -- so whichever one wins for a given player this run, the other
-- is guaranteed a no-op rather than double-forfeiting or (worse) still
-- teleporting a player the loser thinks it owns.
function Forfeit:_forfeit(instance, player, cause: string): boolean
	local runId = instance:GetRunId()
	if self._appliedRun[player] == runId then
		return false
	end
	self._appliedRun[player] = runId

	local lost = instance:VoidDuffel(player)
	instance:RemoveParticipant(player)

	local okNotify, errNotify = pcall(self.notify, player, cause)
	if not okNotify then warn("[Forfeit] notify failed: " .. tostring(errNotify)) end

	self.log(string.format("run %d: %s forfeited %d (%s)", runId, tostring(player), math.floor(lost), cause))
	return true
end

-- Forced eject: the session ended (e.g. the 10-minute timer expiring) while
-- this player was still alive. Always forfeits -- the run is over whether or
-- not the player is still on the premises. Only physically moves them to
-- ExitSpawn when `isInside` is true (spec addendum, 2026-09-11): the caller
-- (HeistServer/SlowFoodsServer) computes this from its own real-time zone
-- occupancy tracking (the same ZoneService already used for the heist-timer
-- GUI) and passes it in explicitly -- Forfeit itself stays location-agnostic
-- and never touches zones. A player who already left the premises must not
-- be yanked back to ExitSpawn out of nowhere; a player still inside gets the
-- teleport exactly as before. Never call this from a death path.
function Forfeit:Eject(instance, player, cause: string, isInside: boolean): boolean
	if not self:_forfeit(instance, player, cause) then return false end

	if isInside then
		-- Final review I2 (2026-11-18, controller ruling): the timer's eject never moves loot. A heavy
		-- carry (an object with a speedCap: the gold bar, the ripped ATM) is lost inside, like the bag;
		-- the getaway it skips is the carry out of the building.
		local carried = self.carryState and self.carryState:GetCarried(player)
		if carried and type(carried.speedCap) == "number" then
			self.carryState:Consume(player)
		end
		local ok, err = pcall(self.teleport, player, self.exitCFrame())
		if not ok then warn("[Forfeit] teleport failed: " .. tostring(err)) end
	end

	return true
end

-- Death: Humanoid.Died fired, from any cause (laser, guard, death pit).
-- Forfeits only -- NEVER teleports, under any cause. The player's own
-- death/respawn (Roblox's standard SpawnLocation) proceeds completely
-- untouched by this system.
function Forfeit:Die(instance, player, cause: string): boolean
	return self:_forfeit(instance, player, cause)
end

function Forfeit:Forget(player)
	self._appliedRun[player] = nil
end

return Forfeit
