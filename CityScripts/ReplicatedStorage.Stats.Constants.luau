-- Shared naming for the per-faction kill counters, required by KillStatsService (which writes them)
-- and PlayerCardController (which reads them). Mirrors the role UpgradeConfig and QuestConfig play
-- for their systems: one place the attribute names live so the writer and the reader cannot drift.
local Constants = {}

-- Read off each enemy rig template in ServerStorage.EnemyTemplates. A template with no Faction
-- attribute is counted under neither bucket rather than guessed at -- a silent miscount is worse
-- than a visible zero.
Constants.FACTION_ATTRIBUTE = "Faction"

Constants.CRIMINAL = "Criminal"
Constants.POLICE = "Police"

-- Player attributes, replicated to that player's own client exactly like Level, XP and
-- WeaponOwned_* already are. Saved in the profile (`kills`) through ProfileGateway like Cash and
-- Leveling, since 2026-09-23.
Constants.CRIMINAL_ATTRIBUTE = "CriminalKills"
Constants.POLICE_ATTRIBUTE = "PoliceKills"

-- The attribute a given faction's kills accumulate into, or nil for an unrecognised faction.
function Constants.attributeForFaction(faction: string?): string?
	if faction == Constants.CRIMINAL then
		return Constants.CRIMINAL_ATTRIBUTE
	elseif faction == Constants.POLICE then
		return Constants.POLICE_ATTRIBUTE
	end
	return nil
end

return Constants
