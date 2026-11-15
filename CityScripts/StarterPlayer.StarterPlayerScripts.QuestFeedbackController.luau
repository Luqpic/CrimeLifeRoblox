-- Personal feedback when one of this player's own quests completes: the shine effect on their
-- character, a sound, and a bottom-left toast. Driven off the same reactive player attributes the
-- rest of the quest system replicates through, the way WeaponaryShopController already reacts to
-- WeaponUpgrade_/WeaponOwned_/LoadoutSlot.
--
-- There is deliberately no centre-screen banner: the toast already announces the completion, and
-- showing both said the same thing twice.
--
-- Deliberately not broadcast: this acknowledges the player's own completion rather than announcing
-- it to everyone nearby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local questsRoot = ReplicatedStorage:WaitForChild("Quests")
local QuestConfig = require(questsRoot:WaitForChild("QuestConfig"))
local NotificationController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NotificationController"))

local player = Players.LocalPlayer

local COMPLETE_SOUND_ID = "rbxassetid://95148743653937"
local SHINE_EMIT_COUNT = 30

local completeSound = Instance.new("Sound")
completeSound.Name = "QuestCompleteSound"
completeSound.SoundId = COMPLETE_SOUND_ID
completeSound.Volume = 0.7
completeSound.Parent = SoundService

-- Completion count last seen per quest. Feedback fires when the count INCREASES, not when state
-- reads Completed: a repeatable quest's state returns to "" the moment it is turned in, and a
-- one-shot latch would fire only the first time it was ever finished.
local lastSeenCompletions: { [string]: number } = {}

-- False until QuestService says the saved counts are restored. Flipped by this script's own signal, not
-- read live, so a restore and its flag arriving together are still handled in the order they were set.
local questsRestored = player:GetAttribute(QuestConfig.RESTORED_ATTRIBUTE) == true
player:GetAttributeChangedSignal(QuestConfig.RESTORED_ATTRIBUTE):Connect(function()
	questsRestored = player:GetAttribute(QuestConfig.RESTORED_ATTRIBUTE) == true
end)

local function playBrightEffect()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	-- Re-emits the shine particle LevelUpVFX already attaches to every character at spawn, rather
	-- than adding a second emitter that looks the same.
	local shine = rootPart and rootPart:FindFirstChild("LevelUpShine")
	if shine and shine:IsA("ParticleEmitter") then
		shine:Emit(SHINE_EMIT_COUNT)
	end
end

local function onCompletionsChanged(questId: string)
	local count = (player:GetAttribute(QuestConfig.completionsAttributeFor(questId)) :: number?) or 0
	local previous = lastSeenCompletions[questId] or 0
	lastSeenCompletions[questId] = count
	if not questsRestored then
		return -- the saved count arriving at join: a seed, not a completion
	end
	if count <= previous then
		return -- unchanged, or reset downward; only a genuine increment is a completion
	end

	local quest = QuestConfig.Quests[questId]
	if not quest then
		return
	end

	playBrightEffect()
	completeSound:Play()
	-- Title carries "QUEST COMPLETE" on the acid headline, so the message itself is just the quest
	-- name -- previously the whole sentence went into the one-line message label.
	NotificationController.show(quest.name, "QUEST COMPLETE")
end

for questId in QuestConfig.Quests do
	-- Seeded from the current value first, so completions banked before this script ran (a rejoin,
	-- or a slow-loading client) do not replay their feedback on startup.
	lastSeenCompletions[questId] = (player:GetAttribute(QuestConfig.completionsAttributeFor(questId)) :: number?) or 0
	player:GetAttributeChangedSignal(QuestConfig.completionsAttributeFor(questId)):Connect(function()
		onCompletionsChanged(questId)
	end)
end
