--!strict
-- Heist layers 2026-11-17 (Task 4): Gas2Go's ATM, two choices on one model. "Rob ATM" is the
-- RobbableObject it always was (into the bag); "Rip Out ATM" is a SupplyObject the player carries
-- (bank-only, slowed to Movement.Constants.CARRY_SPEED_CAP, server-timed hold), banked by the location's CarryGetaway.
-- Using either closes the other until the next session.
--
-- SupplyObject:Seal hides its model, but an ATM nobody ripped out must stand between sessions as
-- it always did: Seal therefore only closes an untouched ATM, and Rearm (cooldown end) puts a
-- ripped one back on its spot, promptless, as it is at Idle today.
--
-- Leftovers (2026-11-18): the ATM vanished once after a death mid-rip (a dropped ATM is physics-active
-- and can leave the world). A copy taken at boot, before either component touches the model, rebuilds a
-- missing or incomplete ATM at Rearm. Both prompts re-measure reach on the server (final review M3), the
-- rip names its getaway location for the carry widget, and Forget(player) drops a begun rip hold.
--
-- deps = { bank, robPromptTemplate, ripPromptTemplate, repickupPromptTemplate, robAmount,
--   ripAmount, onPickup(player, ripObject), onRefused?, playRobSound?, isBlocked?,
--   hasDuffel?, clock?, measure? }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)
local SupplyObject = require(ReplicatedStorage.SharedSystems.SupplyObject)
local CARRY_SPEED_CAP = require(ReplicatedStorage.Movement.Constants).CARRY_SPEED_CAP

local ATMRipOut = {}
ATMRipOut.__index = ATMRipOut

local function countParts(model: Model): number
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

function ATMRipOut.new(model: Model, deps)
	assert(type(deps.onPickup) == "function", "ATMRipOut requires onPickup")
	local self = setmetatable({
		model = model,
		ripped = false,
		rob = nil :: any,
		rip = nil :: any,
		_deps = deps,
		_parent = model.Parent,
		-- Unparented, so its tags never count in CollectionService:GetTagged until a rebuild parents a clone.
		_bootCopy = model:Clone(),
		_partCount = countParts(model),
	}, ATMRipOut)
	self:_build(model)
	return self
end

function ATMRipOut:_build(model: Model)
	local deps = self._deps
	self.model = model
	self.ripped = false
	-- RobbableObject first: both take the part nearest the model's pivot, and SupplyObject then
	-- makes that part the PrimaryPart (which moves the pivot onto it).
	self.rob = RobbableObject.new(model, {
		bank = deps.bank,
		promptTemplate = deps.robPromptTemplate,
		amount = deps.robAmount,
		onRefused = deps.onRefused,
		playRobSound = deps.playRobSound,
		isBlocked = deps.isBlocked,
		checkReach = true,
		measure = deps.measure,
		onRobbed = function() self.rip:Close() end,
	})
	self.rip = SupplyObject.new(model, {
		bank = deps.bank,
		promptTemplate = deps.ripPromptTemplate,
		repickupPromptTemplate = deps.repickupPromptTemplate,
		cashOutAmount = deps.ripAmount,
		bankOnly = true,
		speedCap = CARRY_SPEED_CAP,
		getawayLocation = "Gas2Go",
		enforceHold = true,
		checkReach = true,
		measure = deps.measure,
		clock = deps.clock,
		onRefused = deps.onRefused,
		isBlocked = deps.isBlocked,
		hasDuffel = deps.hasDuffel,
		onPickup = function(player, ripObject)
			self.ripped = true
			self.rob:Close()
			return deps.onPickup(player, ripObject)
		end,
	})
end

function ATMRipOut:_intact(): boolean
	return self.model.Parent ~= nil and countParts(self.model) >= self._partCount
end

function ATMRipOut:OnSessionStart()
	self.ripped = false
	self.rob:OnSessionStart()
	self.rip:OnSessionStart()
end

function ATMRipOut:Seal()
	self.rob:Seal()
	if self.ripped then
		self.rip:Seal()
	else
		self.rip:Close()
	end
end

function ATMRipOut:Rearm()
	if not self:_intact() then
		-- Nobody carries it: a carried ATM is hidden and anchored in place, so only a dropped one can be lost.
		self.rob:Destroy()
		self.rip:Destroy()
		if self.model.Parent then self.model:Destroy() end
		local fresh = self._bootCopy:Clone()
		fresh.Parent = self._parent
		self:_build(fresh) -- standing and promptless, as at Idle
		return
	end
	if not self.ripped then return end
	self.ripped = false
	self.rip:OnSessionStart()
	self.rip:Close()
end

function ATMRipOut:Forget(player)
	self.rob:Forget(player)
	self.rip:Forget(player)
end

function ATMRipOut:Destroy()
	self.rob:Destroy()
	self.rip:Destroy()
end

return ATMRipOut
