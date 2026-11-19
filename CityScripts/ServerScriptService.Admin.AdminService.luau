-- Admin service (2026-11-20, admin-design.md). ReplicatedStorage.AdminRemote (RemoteFunction) runs every admin
-- action through Admin.Actions' dispatcher (role, validation, cooldown, log); ReplicatedStorage.AdminAnnounce
-- (RemoteEvent) carries filtered announcements to every client (NotificationClient shows them). Roles are read once
-- per join (Admin.Roles). A character's admin states (frozen, god, invisible, speed, fly, noclip) end with its death.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(script.Parent.Actions)
local Roles = require(script.Parent.Roles)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local function remote(className: string, name: string): Instance
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = ReplicatedStorage
	return made
end

local announce = remote("RemoteEvent", "AdminAnnounce") :: RemoteEvent
local dispatcher = Actions.newDispatcher(Actions.liveContext(announce))
local adminRemote = remote("RemoteFunction", "AdminRemote") :: RemoteFunction
adminRemote.OnServerInvoke = dispatcher.call

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Once(function()
			Actions.clearCharacter(character)
		end)
	end
end

safePlayerAdded(function(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	Roles.load(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	dispatcher.forget(player)
	Actions.forgetPlayer(player)
end)
