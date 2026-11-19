-- ReplicatedStorage.PlayerMovement.Fallback(name) -> the Roblox default R15 clip that stands in for a movement clip
-- that failed to load (StarterCharacterScripts.Movement), or nil when the clip has none: a legs copy, Land,
-- LandHard, Roll and LedgeClimb are then skipped and the move still runs. Pure; ServerStorage.UnitTest.Cases.Fallback_Test.
local DEFAULTS = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
	Jog = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Sprint = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Climb = "rbxassetid://507765644",
	Swim = "rbxassetid://507784897",
	SwimIdle = "rbxassetid://507785072",
}

return function(name: string): string?
	if name:find("Legs$") then
		return nil
	end
	return DEFAULTS[name:match("^(%a+)_[FBLR]$") or name]
end
