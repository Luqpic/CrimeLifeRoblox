--!strict
-- Heavy-loot getaway (heist layers 2026-11-17): a carried object matching `matches` banks `value`
-- Cash once its carrier is clear of the building and escapeDistance studs (horizontal) from the
-- anchor. A thin wrapper on Heist.Services.Getaway, which owns the distance maths: the "bag" it
-- watches is 1 while the player carries a matching object and 0 otherwise.
--
-- cfg = { escapeDistance, anchor, isInsideBuilding(player), matches(supplyObject), value,
--   carryState, currency, net, getPlayers(), addActiveRobbery? }. When addActiveRobbery is given
-- (WantedService.addActiveRobbery), a carrier still near the location keeps the robbery active.
local Getaway = require(script.Parent.Getaway)

local CarryGetaway = {}
CarryGetaway.__index = CarryGetaway

function CarryGetaway.new(cfg)
	assert(type(cfg) == "table", "CarryGetaway requires a config table")
	assert(type(cfg.matches) == "function", "CarryGetaway requires matches")
	assert(type(cfg.value) == "number" and cfg.value > 0, "CarryGetaway requires a positive value")
	assert(cfg.carryState and cfg.currency and cfg.net, "CarryGetaway requires carryState, currency and net")

	local self = setmetatable({ _cfg = cfg, _robberyConn = nil }, CarryGetaway)
	self._getaway = Getaway.new({
		escapeDistance = cfg.escapeDistance,
		anchor = cfg.anchor,
		isInsideBuilding = cfg.isInsideBuilding,
		getPlayers = cfg.getPlayers,
		getDuffel = function(player) return if self:_carrying(player) then 1 else 0 end,
		onEscaped = function(player) self:_bank(player) end,
	})
	if cfg.addActiveRobbery then
		self._robberyConn = cfg.addActiveRobbery(function(player) return self:IsNear(player) end)
	end
	return self
end

function CarryGetaway:_carrying(player): boolean
	local carried = self._cfg.carryState:GetCarried(player)
	return carried ~= nil and self._cfg.matches(carried) == true
end

function CarryGetaway:_bank(player)
	local cfg = self._cfg
	if not cfg.carryState:Consume(player) then return end
	cfg.currency:Add(player.UserId, cfg.value)
	cfg.net:Toast(player, string.format("Banked %d Cash.", cfg.value))
	cfg.net:NotifyRobberySuccess(player)
end

function CarryGetaway:Step()
	self._getaway:Step()
end

-- Carrying a matching object AND still at the location (inside, or under escapeDistance).
function CarryGetaway:IsNear(player): boolean
	return self:_carrying(player) and self._getaway:IsNear(player)
end

function CarryGetaway:Forget(player)
	self._getaway:Forget(player)
end

function CarryGetaway:Destroy()
	if self._robberyConn then
		self._robberyConn:Disconnect()
		self._robberyConn = nil
	end
end

return CarryGetaway
