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
-- deps = { bank, robPromptTemplate, ripPromptTemplate, repickupPromptTemplate, robAmount,
--   ripAmount, onPickup(player, ripObject), onRefused?, playRobSound?, isBlocked?,
--   hasDuffel?, clock? }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)
local SupplyObject = require(ReplicatedStorage.SharedSystems.SupplyObject)
local CARRY_SPEED_CAP = require(ReplicatedStorage.Movement.Constants).CARRY_SPEED_CAP

local ATMRipOut = {}
ATMRipOut.__index = ATMRipOut

function ATMRipOut.new(model: Model, deps)
	assert(type(deps.onPickup) == "function", "ATMRipOut requires onPickup")
	local self = setmetatable({ model = model, ripped = false }, ATMRipOut)
	-- RobbableObject first: both take the part nearest the model's pivot, and SupplyObject then
	-- makes that part the PrimaryPart (which moves the pivot onto it).
	self.rob = RobbableObject.new(model, {
		bank = deps.bank,
		promptTemplate = deps.robPromptTemplate,
		amount = deps.robAmount,
		onRefused = deps.onRefused,
		playRobSound = deps.playRobSound,
		isBlocked = deps.isBlocked,
		onRobbed = function() self.rip:Close() end,
	})
	self.rip = SupplyObject.new(model, {
		bank = deps.bank,
		promptTemplate = deps.ripPromptTemplate,
		repickupPromptTemplate = deps.repickupPromptTemplate,
		cashOutAmount = deps.ripAmount,
		bankOnly = true,
		speedCap = CARRY_SPEED_CAP,
		enforceHold = true,
		clock = deps.clock,
		onRefused = deps.onRefused,
		isBlocked = deps.isBlocked,
		hasDuffel = deps.hasDuffel,
		onPickup = function(player, ripObject)
			self.ripped = true
			self.rob:Close()
			deps.onPickup(player, ripObject)
		end,
	})
	return self
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
	if not self.ripped then return end
	self.ripped = false
	self.rip:OnSessionStart()
	self.rip:Close()
end

function ATMRipOut:Destroy()
	self.rob:Destroy()
	self.rip:Destroy()
end

return ATMRipOut
