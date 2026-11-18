--!strict
-- Heist layers 2026-11-17 (Task 6): the Bank vault's wall of deposit boxes. Each box is a
-- LockedDoor (the shared lockpick screen, one live attempt per player across all doors) whose
-- model pivots on its hinge part; a solve swings the door open and pays the solver what the box
-- holds this run: cash into the bag (over the cap), nothing, or the gold bar to carry out.
--
-- Registered on the bank as ONE component (not the doors one by one): LockedDoor:OnSessionStart
-- arms its prompt at session start, but the boxes stay shut until the vault door opens, so
-- OnSessionStart rolls the contents and keeps every door closed and promptless; Unlock (called
-- from HeistServer's vault-door latch) arms them.
--
-- deps = { bank, net, config, carryState, goldBar (SupplyObject: GiveTo, DropAt),
--   roll(count) -> {"cash"|"empty"|"gold"}, location? ("Bank"), now?, generateZoneAngle?, measure? }
-- Final review 2026-11-18: a box is picked only by a participant who is not carrying (I1), each click
-- only from within reach of the box (C1, LockedDoor's measure; specs inject it), and the click-time
-- window is config.DepositBoxClickWindow (M2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LockedDoor = require(ReplicatedStorage.SharedSystems.LockedDoor)

local OPEN_ANGLE = math.rad(100) -- about the hinge part's Y axis; the door panel runs along its +X
local DROP_OUT = 2.5 -- studs in front of the box where a gold bar nobody could take lands

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local DepositBoxes = {}
DepositBoxes.__index = DepositBoxes

function DepositBoxes.new(models: { Model }, deps)
	assert(type(deps.roll) == "function", "DepositBoxes requires roll")
	assert(deps.goldBar and deps.carryState and deps.config, "DepositBoxes requires goldBar, carryState and config")
	local self = setmetatable({
		bank = deps.bank,
		net = deps.net,
		config = deps.config,
		carryState = deps.carryState,
		goldBar = deps.goldBar,
		roll = deps.roll,
		doors = {},
		contents = {},
		_dropAt = {},
		_unlocked = false,
	}, DepositBoxes)
	for i, model in ipairs(models) do
		local pivot = (model.PrimaryPart and model.PrimaryPart.CFrame) or model:GetPivot()
		self.doors[i] = LockedDoor.new(model, {
			bank = deps.bank,
			net = deps.net,
			location = deps.location or "Bank",
			objectText = "Deposit Box",
			openCFrame = pivot * CFrame.Angles(0, OPEN_ANGLE, 0),
			now = deps.now,
			generateZoneAngle = deps.generateZoneAngle,
			measure = deps.measure,
			maxLatencyCompensation = deps.config.DepositBoxClickWindow,
			-- Only this robbery's participants may pick a box (a bystander would empty it for nothing), and not
			-- while carrying (final review I1: carriers can't rob). Asked again on every click.
			canAttempt = function(player)
				return deps.bank:IsParticipant(player) and not deps.carryState:IsCarrying(player)
			end,
			onSolved = function(player) self:_onSolved(i, player) end,
		})
		local handle = model:FindFirstChild("ProximityPart Handle") :: BasePart
		self._dropAt[i] = CFrame.new(handle.Position + pivot.LookVector * DROP_OUT)
	end
	return self
end

function DepositBoxes:_closeAll()
	self._unlocked = false
	for _, door in ipairs(self.doors) do door:Seal() end
end

function DepositBoxes:OnSessionStart()
	self.contents = self.roll(#self.doors)
	self:_closeAll()
end

-- The vault door is open: arm every box (once per session).
function DepositBoxes:Unlock()
	if self._unlocked or self.bank:GetState() ~= "Active" then return end
	self._unlocked = true
	for _, door in ipairs(self.doors) do door:OnSessionStart() end
end

function DepositBoxes:Seal()
	self:_closeAll()
end

function DepositBoxes:_onSolved(i: number, player)
	-- Own guard for every branch (gold included): nothing is paid or given outside an Active session.
	if self.bank:GetState() ~= "Active" then return end
	local kind = self.contents[i]
	self.contents[i] = "empty" -- paid once
	if kind == "cash" then
		if self.bank:AddBonus(player, self.config.DepositBoxCash) then
			self.net:Toast(player, "+" .. withCommas(self.config.DepositBoxCash))
		end
	elseif kind == "gold" then
		-- A carrier never gets here (canAttempt), but the carry itself is the proof of a pickup: anything
		-- else leaves the bar on the floor with its re-pickup prompt.
		if not self.carryState:IsCarrying(player) then
			self.goldBar:GiveTo(player)
		end
		if self.carryState:GetCarried(player) == self.goldBar then
			self.net:Toast(player, string.format("Gold bar! Carry it %d studs clear of the bank.", self.config.EscapeDistance))
		else
			self.goldBar:DropAt(self._dropAt[i])
			self.net:Toast(player, "Gold bar! Your hands are full: it's on the floor.")
		end
	else
		self.net:Toast(player, "Empty.")
	end
end

function DepositBoxes:Destroy()
	for _, door in ipairs(self.doors) do door:Destroy() end
end

return DepositBoxes
