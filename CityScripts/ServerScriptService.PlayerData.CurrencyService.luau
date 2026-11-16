--!strict
-- CurrencyService (city bridge, phase 3): the Robbery place's CurrencyAdapter API, writing only
-- player.leaderstats.Cash, which the city's CashService owns and persists (its Value listener
-- mirrors into the profile). API and return values: CityMerge/phase3/currency-api.md.
-- Never creates leaderstats, never yields, never touches a DataStore.
local Players = game:GetService("Players")

local currency = {}

-- Test seam: CurrencyBridge_Test swaps this to resolve a stand-in player.
function currency._playerFor(userId: number): Instance?
	return Players:GetPlayerByUserId(userId)
end

local function cashValue(userId): IntValue?
	if type(userId) ~= "number" then return nil end
	local player = currency._playerFor(userId)
	local stats = player and player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then return cash end
	return nil
end

local function isSaneAmount(amount): boolean
	if type(amount) ~= "number" then return false end
	if amount ~= amount then return false end -- NaN
	if amount == math.huge or amount == -math.huge then return false end
	return amount > 0
end

function currency:Get(userId: number): number
	local cash = cashValue(userId)
	return cash and cash.Value or 0
end

-- The city loads the balance itself (CashService); Load only reads it.
function currency:Load(userId: number): number
	return self:Get(userId)
end

-- Fractional credits are floored, as in the Robbery adapter; a refused call returns the unchanged balance.
function currency:Add(userId: number, amount): number
	local cash = cashValue(userId)
	if not cash then return 0 end
	if not isSaneAmount(amount) then return cash.Value end
	cash.Value += math.floor(amount)
	return cash.Value
end

-- Persistence belongs to CashService: nothing is ever pending here.
function currency:PendingCount(): number
	return 0
end

function currency:Save(_userId: number): boolean
	return true
end

function currency:FlushAll() end

function currency:Release(_userId: number) end

return currency
