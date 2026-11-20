local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local makeValidateRunningState = require(script.validateRunningState)
local validateRunningState = makeValidateRunningState()
local SprintAuthority = require(script.Parent.SprintAuthority)
local RollAuthority = require(script.Parent.RollAuthority)
local Stealth = require(script.Parent.Stealth)

local runEvent = ReplicatedStorage:WaitForChild("UpdateRunningState")
-- 2026-11-20: StarterCharacterScripts.Movement rolls at once (the character is the client's) and asks here for the
-- roll's stamina; RollAuthority re-checks and spends it. No arguments are read.
local rollEvent = ReplicatedStorage:WaitForChild("PlayerMovement"):WaitForChild("Roll")

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
	RollAuthority.cleanup(player)
end

SprintAuthority.start()
-- Crouch stealth (2026-11-20): the client reports its crouch here (a boolean); Stealth decides what it is worth.
local crouchEvent = ReplicatedStorage:WaitForChild("PlayerMovement"):WaitForChild("Crouch")
crouchEvent.OnServerEvent:Connect(function(player: Player, on: unknown)
	Stealth.setCrouch(player, on)
end)
Stealth.start()

runEvent.OnServerEvent:Connect(onUpdateRunningState)
rollEvent.OnServerEvent:Connect(function(player: Player)
	RollAuthority.request(player, os.clock())
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)
