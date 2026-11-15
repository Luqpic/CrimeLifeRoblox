-- Three responsibilities: (1) tag every quest-giver NPC Invulnerable at server start, from the same
-- QuestConfig data everything else reads, so a new quest's NPC is protected automatically without a
-- second place remembering to do it; (2) track quest acceptance/progress/completion per player,
-- saved in the profile through ProfileGateway (quests, questCompletions), replicated via Player Attributes exactly like Level/Cash/WeaponUpgrade already are;
-- (3) handle accept/turn-in requests and the kill-count objective.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)

local acceptQuestRequest = ReplicatedStorage.Quests.Remotes.AcceptQuestRequest
local turnInQuestRequest = ReplicatedStorage.Quests.Remotes.TurnInQuestRequest
local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated

-- Hands XP off to LevelingService, so level-up thresholds and the max-health-per-level side effect
-- stay owned by the one place that already implements them correctly rather than being duplicated
-- here. A persistent BindableEvent in its own Events folder, matching Blaster.Events.Eliminated --
-- deliberately NOT created at runtime by this script, which would make the reference depend on this
-- script having loaded before LevelingService.
local grantXpEvent = ServerScriptService.Quests.Events.GrantXp

local INVULNERABLE_TAG = "Invulnerable"

-- ============================================
-- NPC SETUP -- tag every quest-giver from data, once, at server start
-- ============================================
local questsFolder = Workspace:FindFirstChild("Quests")
for questId, quest in QuestConfig.Quests do
	local npc = questsFolder and questsFolder:FindFirstChild(quest.npcName)
	if npc then
		CollectionService:AddTag(npc, INVULNERABLE_TAG)
	else
		warn(`QuestService: no NPC named "{quest.npcName}" under Workspace.Quests for quest "{questId}"`)
	end
end

-- ============================================
-- STATE (saved: restored by hydrate, written by save after every change)
-- ============================================
-- questId -> {progress: number, state: string}. Absent questId = never accepted.
local playerQuests: { [Player]: { [string]: { progress: number, state: string } } } = {}

local function publishQuestAttributes(player: Player, questId: string)
	local quests = playerQuests[player]
	local entry = quests and quests[questId]
	player:SetAttribute(QuestConfig.stateAttributeFor(questId), entry and entry.state or "")
	player:SetAttribute(QuestConfig.progressAttributeFor(questId), entry and entry.progress or 0)
end

-- Mirrors one quest's entry and its completions count into the profile. A no-op while unbound.
local function save(player: Player, questId: string)
	local quests = playerQuests[player]
	local entry = quests and quests[questId]
	local completions = player:GetAttribute(QuestConfig.completionsAttributeFor(questId))
	ProfileGateway.mirror(player, function(profile)
		profile.Data.quests[questId] = entry and { state = entry.state, progress = entry.progress } or nil
		profile.Data.questCompletions[questId] = (typeof(completions) == "number" and completions > 0) and completions or nil
	end)
end

-- Same shape as WeaponUpgradeService.hydrate. Runs before the bind; may run before safePlayerAdded.
local function hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end
	local quests, completions = QuestConfig.restore(profile.Data.quests, profile.Data.questCompletions)
	playerQuests[player] = quests
	for questId in QuestConfig.Quests do
		publishQuestAttributes(player, questId)
		player:SetAttribute(QuestConfig.completionsAttributeFor(questId), completions[questId] or 0)
	end
end

ProfileGateway.registerHydrator(hydrate)

safePlayerAdded(function(player: Player)
	playerQuests[player] = playerQuests[player] or {} -- the hydrator may have run first
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerQuests[player] = nil
end)

-- Accept and turn-in both require standing at the giver, as the dialogue does on the client.
local function canReach(player: Player, quest): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local npc = questsFolder and questsFolder:FindFirstChild(quest.npcName)
	local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")
	if not npcRoot then
		return false
	end
	return QuestConfig.withinReach(root.Position, npcRoot.Position)
end

-- ============================================
-- ACCEPT
-- ============================================
acceptQuestRequest.OnServerEvent:Connect(function(player: Player, questId: any)
	if typeof(questId) ~= "string" then
		return
	end
	local quest = QuestConfig.Quests[questId]
	if not quest then
		return
	end
	if not canReach(player, quest) then
		return
	end

	local quests = playerQuests[player]
	if not quests then
		return
	end
	if quests[questId] then
		return -- already accepted, in progress, ready, or completed -- accept is one-shot
	end

	local level = (player:GetAttribute("Level") :: number?) or 1
	if level < quest.requiredLevel then
		return -- client should already be refusing to offer this; server is the real gate
	end

	quests[questId] = { progress = 0, state = QuestConfig.STATE_ACCEPTED }
	publishQuestAttributes(player, questId)
	save(player, questId)
end)

-- ============================================
-- KILL TRACKING -- KillCount objective only, matching what's implemented today
-- ============================================
eliminatedEvent.Event:Connect(function(shooter: Player | Model, humanoid: Humanoid)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end
	local character = humanoid.Parent
	local enemyTemplate = character and character:GetAttribute("EnemyTemplate")
	if not enemyTemplate then
		return
	end

	local quests = playerQuests[shooter]
	if not quests then
		return
	end

	for questId, entry in quests do
		if entry.state ~= QuestConfig.STATE_ACCEPTED then
			continue
		end
		local quest = QuestConfig.Quests[questId]
		if not quest or quest.objectiveType ~= "KillCount" or quest.objectiveEnemyTemplate ~= enemyTemplate then
			continue
		end

		entry.progress += 1
		if entry.progress >= quest.objectiveTarget then
			entry.progress = quest.objectiveTarget
			entry.state = QuestConfig.STATE_READY_TO_TURN_IN
		end
		publishQuestAttributes(shooter, questId)
		save(shooter, questId)
	end
end)

-- ============================================
-- TURN IN
-- ============================================
turnInQuestRequest.OnServerEvent:Connect(function(player: Player, questId: any)
	if typeof(questId) ~= "string" then
		return
	end
	local quest = QuestConfig.Quests[questId]
	if not quest then
		return
	end
	if not canReach(player, quest) then
		return
	end

	local quests = playerQuests[player]
	local entry = quests and quests[questId]
	if not entry or entry.state ~= QuestConfig.STATE_READY_TO_TURN_IN then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value += quest.rewardCash
	end
	grantXpEvent:Fire(player, quest.rewardXp)

	-- Incremented before the state change below. For a repeatable quest the state returns to ""
	-- immediately, so this counter is the only thing that records the completion -- and the only
	-- signal the client's completion feedback can key off.
	local completionsAttribute = QuestConfig.completionsAttributeFor(questId)
	player:SetAttribute(completionsAttribute, ((player:GetAttribute(completionsAttribute) :: number?) or 0) + 1)

	if quest.repeatable then
		-- Cleared, not marked Completed: the entry going away is what lets the player accept it
		-- again, and resets progress to 0 for the next run.
		quests[questId] = nil
	else
		entry.state = QuestConfig.STATE_COMPLETED
	end
	publishQuestAttributes(player, questId)
	save(player, questId)
end)
