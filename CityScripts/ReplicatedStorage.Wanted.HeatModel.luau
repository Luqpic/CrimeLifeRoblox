--!strict
-- Pure heat arithmetic for the wanted level. Heat is 0..5; stars are its whole part.
local Constants = require(script.Parent.Constants)

local HeatModel = {}

function HeatModel.raise(heat: number, amount: number): number
	return math.clamp(heat + amount, 0, Constants.MAX_HEAT)
end

-- An alarm: heat becomes at least the level, never lower than it was.
function HeatModel.atLeast(heat: number, level: number): number
	return math.max(heat, level)
end

function HeatModel.stars(heat: number): number
	return math.floor(heat)
end

-- One drain step: to the integer below when fractional, else down by 1; never below 0.
function HeatModel.drainStep(heat: number): number
	local whole = math.floor(heat)
	return math.max(if whole == heat then heat - 1 else whole, 0)
end

return HeatModel
