local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local makeValidateRunningState = require(script.validateRunningState)
local validateRunningState = makeValidateRunningState()
local SprintAuthority = require(script.Parent.SprintAuthority)

local runEvent = ReplicatedStorage:WaitForChild("UpdateRunningState")

local function onUpdateRunningState(player: Player, isRunning: boolean)
	if not validateRunningState.validate(player, isRunning) then
		return
	end

	-- The client only reports INTENT here; SprintAuthority decides whether it is granted (it owns
	-- stamina and is the single writer of the shared IsSprinting attribute), so a player with no
	-- stamina left cannot sprint by asking nicely.
	SprintAuthority.setIntent(player, isRunning)
end

local function onPlayerRemoving(player: Player)
	validateRunningState.cleanup(player)
end

SprintAuthority.start()

runEvent.OnServerEvent:Connect(onUpdateRunningState)
Players.PlayerRemoving:Connect(onPlayerRemoving)
