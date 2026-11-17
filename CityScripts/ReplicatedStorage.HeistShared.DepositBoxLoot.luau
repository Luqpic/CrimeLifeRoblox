--!strict
-- Heist layers 2026-11-17 (Task 6): what the Bank's deposit boxes hold this run. Pure.
-- With probability goldChance one box (any of them) holds the gold bar; every other box is cash
-- two times in three and empty otherwise.
local DepositBoxLoot = {}

function DepositBoxLoot.roll(rng: Random, count: number, goldChance: number): { string }
	local goldIndex = if rng:NextNumber() < goldChance then rng:NextInteger(1, count) else nil
	local contents = table.create(count)
	for i = 1, count do
		if i == goldIndex then
			contents[i] = "gold"
		else
			contents[i] = if rng:NextInteger(1, 3) <= 2 then "cash" else "empty"
		end
	end
	return contents
end

return DepositBoxLoot
