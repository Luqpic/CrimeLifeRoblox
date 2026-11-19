-- Admin service (2026-11-20, admin-design.md). ReplicatedStorage.AdminRemote (RemoteFunction) runs every admin
-- action through Admin.Actions' dispatcher (role, validation, cooldown, log); ReplicatedStorage.AdminAnnounce
-- (RemoteEvent) carries filtered announcements to every client (NotificationClient shows them). Roles are read once
-- per join (Admin.Roles). A character's admin states (frozen, god, invisible, speed, fly, noclip) end with its death.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

-- The panel and its code reach only a player with a role: ServerStorage.AdminPanel's two ScreenGuis are cloned into
-- that player's PlayerGui on role gain (join included) and removed on role loss. Other clients never receive them.
local panelFolder = ServerStorage:WaitForChild("AdminPanel", 10)
local HELPER_ACTIONS = Actions.helperActions()
local ENEMY_TYPES = Actions.enemyTypes()

-- The role rides on the delivered GUIs (attribute AdminRole), never on the Player. A role lost or lowered first ends
-- the owner states it allowed (review I1); on loss the GUIs see AdminRole go (the panel closes, fly, noclip and
-- spectate stop) and are removed a moment later.
Roles.onChanged(function(player: Player, role: string?)
	if role ~= "owner" and player.Character then
		Actions.clearCharacter(player.Character)
	end
	if not role then
		Actions.forgetPlayer(player)
	end
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not (panelFolder and playerGui) then
		return
	end
	for _, name in { "AdminHudGui", "AdminPanelGui" } do
		local existing = playerGui:FindFirstChild(name)
		if existing then
			existing:SetAttribute("AdminRole", role)
			if not role then
				task.delay(1, function()
					if not Roles.get(player) then
						existing:Destroy()
					end
				end)
			end
		elseif role then
			local gui = panelFolder:FindFirstChild(name)
			if gui then
				gui = gui:Clone()
				gui:SetAttribute("AdminRole", role)
				gui:SetAttribute("HelperActions", HELPER_ACTIONS)
				gui:SetAttribute("EnemyTypes", ENEMY_TYPES)
				gui.Parent = playerGui
			end
		end
	end
end)

safePlayerAdded(function(player: Player)
	-- A new body ends the old one's spectate on the server too (review I2: the client stops on its own respawn).
	player.CharacterAdded:Connect(function(character)
		Actions.forgetPlayer(player)
		watchCharacter(character)
	end)
	-- A body removed alive (respawn, leave) drops its states and their connections like a death does.
	player.CharacterRemoving:Connect(Actions.clearCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	Roles.load(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	dispatcher.forget(player)
	Actions.forgetPlayer(player)
end)
