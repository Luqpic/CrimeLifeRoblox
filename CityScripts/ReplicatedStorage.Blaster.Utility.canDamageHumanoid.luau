local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConstants = require(ReplicatedStorage.Enemy.Constants)

-- Whether `shooter` is allowed to damage `taggedHumanoid`.
--
-- `shooter` is either a Player (a player-held blaster) or a character Model (an AI enemy firing
-- through the same shared resolver). Both go through this one check, so who-may-damage-whom cannot
-- drift between the player and AI paths. Previously named canPlayerDamageHumanoid.
local function canDamageHumanoid(shooter: Player | Model, taggedHumanoid: Humanoid): boolean
	-- If the humanoid is already dead, no need to apply more damage
	if taggedHumanoid.Health <= 0 then
		return false
	end

	local taggedCharacter = taggedHumanoid.Parent

	-- Quest-giver NPCs (and anything else tagged Invulnerable) cannot be damaged by anyone. Checked
	-- above the shooter branches below so it applies identically to player fire and AI fire, which
	-- both funnel through this one function.
	if taggedCharacter and CollectionService:HasTag(taggedCharacter, "Invulnerable") then
		return false
	end

	local taggedPlayer = Players:GetPlayerFromCharacter(taggedCharacter)

	if not shooter:IsA("Player") then
		-- An AI enemy. Enemies are hostile to every player regardless of the team system -- they are
		-- deliberately not on a team at all -- but they do not damage each other. An enemy standing
		-- in the line of fire still blocks the shot, it just doesn't take damage from it.
		if taggedCharacter == shooter then
			return false
		end
		if taggedCharacter and CollectionService:HasTag(taggedCharacter, EnemyConstants.ENEMY_TAG) then
			return false
		end
		-- Nor anything tagged Witness (police and wanted, final review 2026-11-17): heist guards and civilians.
		-- A police volley through a Bank guard must not kill it and open the GuardRoom (GuardsCleared); players
		-- still damage guards, and police (Witness and Enemy) as before.
		if taggedCharacter and CollectionService:HasTag(taggedCharacter, "Witness") then
			return false
		end
		return true
	end

	-- If the shooter tagged a non-player humanoid then allow damage
	if not taggedPlayer then
		return true
	end

	if shooter.Neutral or taggedPlayer.Neutral then
		-- If either player is neutral (i.e. not on a team) then allow damage
		return true
	else
		-- Only allow damage if the players are not on the same team
		return shooter.Team ~= taggedPlayer.Team
	end
end

return canDamageHumanoid
