-- Witnesses: who sees a crime in public, and which guards see a wanted player (police and wanted, Task 3,
-- 2026-11-17).
--
-- A witness is a live model tagged `Witness` (police at spawn; the heist civilian templates BankClerk,
-- Cashier, NewsWorker and ServerStorage.GuardTemplate carry the tag, so their clones do), looking from its
-- Head through Sight.inSight. Guards are the witnesses with the attribute WitnessRole = "Guard" (set on
-- GuardTemplate). sees(): any witness within WITNESS_RANGE (WantedService's public-crime check);
-- guardSees(): any guard within SEEN_RANGE (PoliceDispatcher.isSeen). Both strictly booleans. sees() leaves
-- out `except` (final review 2026-11-17: a hurt victim is not its own witness).
-- _deps (the tag lookup and the line of sight) is injected by Witnesses_Test.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Wanted.Constants)
local Sight = require(script.Parent.Sight)

local Witnesses = {}

Witnesses._deps = {
	-- In Workspace only: the tagged templates themselves sit in ReplicatedStorage and ServerStorage.
	tagged = function()
		local list = {}
		for _, model in CollectionService:GetTagged("Witness") do
			if model:IsDescendantOf(Workspace) then
				table.insert(list, model)
			end
		end
		return list
	end,
	inSight = Sight.inSight,
}

local function anySees(position: Vector3, range: number, guardsOnly: boolean, except: Instance?): boolean
	local witnesses = Witnesses._deps.tagged()
	for _, model in witnesses do
		if model == except then
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local head = model:FindFirstChild("Head")
		if humanoid and humanoid.Health > 0 and head and head:IsA("BasePart")
			and (not guardsOnly or model:GetAttribute("WitnessRole") == "Guard")
			and (head.Position - position).Magnitude <= range
			-- Every witness's body is left out of the rays (fix round 1): a clerk standing in the line of view
			-- does not hide a crime from the guard behind it.
			and Witnesses._deps.inSight(head.Position, position, witnesses) == true
		then
			return true
		end
	end
	return false
end

function Witnesses.sees(position: Vector3, except: Instance?): boolean
	return anySees(position, Constants.WITNESS_RANGE, false, except)
end

function Witnesses.guardSees(position: Vector3): boolean
	return anySees(position, Constants.SEEN_RANGE, true)
end

return Witnesses
