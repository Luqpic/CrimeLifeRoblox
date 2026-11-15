-- Shared quest definitions and the attribute-naming scheme, required by both QuestService and every
-- client that needs to read quest state (the NPC dialogue script, the Quest Log GUI). Mirrors
-- UpgradeConfig's role for the weapon-upgrade system -- one place the shape and naming can't drift.
local QuestConfig = {}

export type QuestDefinition = {
	name: string,
	description: string,
	npcName: string, -- must match a Model directly under Workspace.Quests
	requiredLevel: number,
	objectiveType: "KillCount", -- only type implemented today; the shape allows more later
	objectiveEnemyTemplate: string, -- must match an EnemyTemplates model name
	-- Spoken form for dialogue. Separate from the template name because several of these do not
	-- pluralise by adding "s" -- "Security" and "Police" are already plural in speech.
	objectiveEnemyNamePlural: string,
	objectiveTarget: number,
	rewardCash: number,
	rewardXp: number,
	repeatable: boolean, -- true: turning in clears the quest so it can be taken again
}

QuestConfig.Quests = {
	Level1Thugs = {
		name = "A Warning to Thugs",
		description = "Defeat 10 Thugs.",
		npcName = "Level 1 Quest",
		requiredLevel = 1,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Thug",
		objectiveEnemyNamePlural = "Thugs",
		objectiveTarget = 10,
		rewardCash = 500,
		rewardXp = 100,
		repeatable = true,
	},
	Level10Smugglers = {
		name = "Lockdown",
		description = "Defeat 10 Smugglers.",
		npcName = "Level 10 Quest",
		requiredLevel = 10,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Smuggler",
		objectiveEnemyNamePlural = "Smugglers",
		objectiveTarget = 10,
		rewardCash = 900,
		rewardXp = 300,
		repeatable = true,
	},
	Level20Offender = {
		name = "Clean Sweep",
		description = "Defeat 10 Offenders.",
		npcName = "Level 20 Quest",
		requiredLevel = 20,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Offender",
		objectiveEnemyNamePlural = "Offenders",
		objectiveTarget = 10,
		rewardCash = 1600,
		rewardXp = 600,
		repeatable = true,
	},
	Level35Bandits = {
		name = "No Badge, No Mercy",
		description = "Defeat 10 Bandits.",
		npcName = "Level 35 Quest",
		requiredLevel = 35,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Bandits",
		objectiveEnemyNamePlural = "Bandits",
		objectiveTarget = 10,
		rewardCash = 2800,
		rewardXp = 1200,
		repeatable = true,
	},
	Level50Disrupters = {
		name = "Heavy Hitters",
		description = "Defeat 10 Disrupters.",
		npcName = "Level 50 Quest",
		requiredLevel = 50,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Disrupters",
		objectiveEnemyNamePlural = "Disrupters",
		objectiveTarget = 10,
		rewardCash = 4500,
		rewardXp = 2000,
		repeatable = true,
	},
	Level70Saboteurs = {
		name = "Last Stand",
		description = "Defeat 10 Saboteurs.",
		npcName = "Level 70 Quest",
		requiredLevel = 70,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Saboteur",
		objectiveEnemyNamePlural = "Saboteurs",
		objectiveTarget = 10,
		rewardCash = 8000,
		-- Level 70 is the cap, so XP granted here would simply be dropped by LevelingService. This
		-- quest's whole value is in its cash reward instead.
		rewardXp = 0,
		repeatable = true,
	},
} :: { [string]: QuestDefinition }

-- Same illegal-character problem UpgradeConfig already solves for weapon names -- quest ids here are
-- authored as plain identifiers already, but this keeps the attribute-naming scheme consistent and
-- future-proof against a quest id that isn't.
local function sanitize(id: string): string
	return (string.gsub(id, "[^%w_]", "_"))
end

function QuestConfig.stateAttributeFor(questId: string): string
	return "Quest_" .. sanitize(questId) .. "_State"
end

function QuestConfig.progressAttributeFor(questId: string): string
	return "Quest_" .. sanitize(questId) .. "_Progress"
end

-- How many times this player has finished the quest. Needed because a repeatable quest's state
-- returns to "" the instant it is turned in, so state alone can never tell a client that a
-- completion just happened -- an increment here is the only durable signal of that.
function QuestConfig.completionsAttributeFor(questId: string): string
	return "Quest_" .. sanitize(questId) .. "_Completions"
end

-- Values the *_State attribute can hold. Absent/"" means not currently taken -- which for a
-- repeatable quest is also where it lands after being turned in, ready to take again.
QuestConfig.STATE_ACCEPTED = "Accepted"
QuestConfig.STATE_READY_TO_TURN_IN = "ReadyToTurnIn"
QuestConfig.STATE_COMPLETED = "Completed"

return QuestConfig
