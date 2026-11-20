--!strict
-- Weapon gacha (2026-11-20): the pure draw. No services, no randomness of its own: the caller passes the uniform
-- numbers, so the specs (Gacha_Test) can drive every branch.
local Draw = {}

local ORDER = { "Common", "Rare", "Epic", "Legendary" }

-- One rarity from a uniform `u` in [0, 1) and `odds` (rarity -> chance). sinceEpic / sinceLegendary: rolls since the
-- last Epic-or-better / Legendary; reaching a pity limit on this roll upgrades it.
function Draw.rarity(u: number, odds: { [string]: number }, sinceEpic: number, sinceLegendary: number, pityEpic: number, pityLegendary: number): string
	if sinceLegendary + 1 >= pityLegendary then
		return "Legendary"
	end
	local pick, last = nil, "Common"
	local acc = 0
	for _, rarity in ORDER do
		local chance = odds[rarity] or 0
		if chance > 0 then
			last = rarity
			acc += chance
			if pick == nil and u < acc then
				pick = rarity
			end
		end
	end
	pick = pick or last -- u past the sum through rounding: the last rarity on offer
	if sinceEpic + 1 >= pityEpic and (pick == "Common" or pick == "Rare") then
		pick = "Epic"
	end
	return pick
end

-- The pity counters after a roll of `rarity`.
function Draw.advance(rarity: string, sinceEpic: number, sinceLegendary: number): (number, number)
	if rarity == "Legendary" then
		return 0, 0
	elseif rarity == "Epic" then
		return 0, sinceLegendary + 1
	end
	return sinceEpic + 1, sinceLegendary + 1
end

-- `count` rolls: the rarities in order and the counters after them. A roll of ten or more holds at least one Rare
-- or better (the last roll becomes Rare when all were Common). nextU returns the next uniform number.
function Draw.roll(count: number, odds: { [string]: number }, sinceEpic: number, sinceLegendary: number, nextU: () -> number, pityEpic: number, pityLegendary: number): ({ string }, number, number)
	local rarities = {}
	local anyRarePlus = false
	for i = 1, count do
		local rarity = Draw.rarity(nextU(), odds, sinceEpic, sinceLegendary, pityEpic, pityLegendary)
		if i == count and count >= 10 and not anyRarePlus and rarity == "Common" then
			rarity = "Rare"
		end
		anyRarePlus = anyRarePlus or rarity ~= "Common"
		sinceEpic, sinceLegendary = Draw.advance(rarity, sinceEpic, sinceLegendary)
		table.insert(rarities, rarity)
	end
	return rarities, sinceEpic, sinceLegendary
end

return Draw
