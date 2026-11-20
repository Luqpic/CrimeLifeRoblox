--!strict
-- Weapon gacha server (developer, 2026-11-20 evening). A roll is paid with cash (Standard crate) or Premium keys
-- (bought with Robux), drawn by ReplicatedStorage.Gacha.Draw with the player's pity counters, and granted through the
-- weapon shop's own grant (Admin.Hooks.giveWeapon: ownership, the first free slot, the profile); a weapon the player
-- already owns pays Config.DUPLICATE_CASH instead. Keys and pity counters live in the profile (Schema gachaKeys,
-- gachaSinceEpic, gachaSinceLegendary; gachaReceipts holds the handled key PurchaseIds).
--
-- Paid random items (Roblox policy): cash can be bought with Robux, so every roll counts. checkPolicy publishes
-- GachaAllowed on the player from PolicyService (a failed check counts as restricted); a restricted player cannot
-- roll and buys weapons directly as before (WeaponShopService refuses direct buys from everyone else). The odds are
-- on the crate page before any roll.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Gacha.Config)
local Draw = require(ReplicatedStorage.Gacha.Draw)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway) :: any

local GachaService = {}

local MAX_RECEIPTS = 100

type State = { keys: number, sinceEpic: number, sinceLegendary: number }
local states: { [Player]: State } = {}
local busy: { [Player]: boolean } = {}
local random = Random.new()

local function publish(player: Player, state: State)
	player:SetAttribute("GachaKeys", state.keys)
end

local function mirror(player: Player, state: State)
	ProfileGateway.mirror(player, function(profile)
		profile.Data.gachaKeys = state.keys
		profile.Data.gachaSinceEpic = state.sinceEpic
		profile.Data.gachaSinceLegendary = state.sinceLegendary
	end)
end

ProfileGateway.registerHydrator(function(player, profile)
	local data = profile.Data
	local state = {
		keys = tonumber(data.gachaKeys) or 0,
		sinceEpic = tonumber(data.gachaSinceEpic) or 0,
		sinceLegendary = tonumber(data.gachaSinceLegendary) or 0,
	}
	states[player] = state
	publish(player, state)
end)

-- Rarity -> weapon names, from the Tools in ServerStorage.Weapons (their Rarity attribute, set in Edit).
local function pool(): { [string]: { string } }
	local byRarity: { [string]: { string } } = {}
	for _, tool in ServerStorage.Weapons:GetChildren() do
		local rarity = tool:IsA("Tool") and Config.rarityOf(tool)
		if rarity then
			byRarity[rarity] = byRarity[rarity] or {}
			table.insert(byRarity[rarity], tool.Name)
		end
	end
	return byRarity
end

local function cashOf(player: Player): any
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return if cash and cash:IsA("ValueBase") then cash else nil
end

-- A state before (or without) a loaded profile, so a player whose data failed to load can still roll; the hydrator
-- replaces it when the profile arrives (like every service's PlayerAdded default).
function GachaService.ensure(player: Player)
	if not states[player] then
		local state = { keys = 0, sinceEpic = 0, sinceLegendary = 0 }
		states[player] = state
		publish(player, state)
	end
end

function GachaService.checkPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local allowed = ok and typeof(info) == "table" and info.ArePaidRandomItemsRestricted == false
	if player.Parent == Players then
		player:SetAttribute("GachaAllowed", allowed)
	end
end

-- `count` (1 or 10) rolls of `crate` ("Standard" with cash, "Premium" with keys). Returns ok and the results
-- ({ weapon, rarity, duplicate, cash }) or ok false and a message for the player.
function GachaService.roll(player: Player, count: unknown, crate: unknown): (boolean, any)
	if count ~= 1 and count ~= 10 then
		return false, "Invalid roll."
	end
	if crate ~= "Standard" and crate ~= "Premium" then
		return false, "Invalid crate."
	end
	if player:GetAttribute("GachaAllowed") ~= true then
		return false, "Crates are not available for your account."
	end
	local state = states[player]
	local cash = cashOf(player)
	local giveWeapon = (require(ServerScriptService.Admin.Hooks) :: any).giveWeapon
	if not (state and cash and giveWeapon) then
		return false, "Still loading. Try again in a moment."
	end
	if busy[player] then
		return false, "Opening a crate already."
	end
	local rolls = count :: number
	local price = if rolls == 10 then Config.TEN_ROLL_PRICE else Config.ROLL_PRICE
	if crate == "Standard" then
		if cash.Value < price then
			return false, "Not enough cash."
		end
		cash.Value -= price
	else
		if state.keys < rolls then
			return false, "Not enough Premium keys."
		end
		state.keys -= rolls
	end
	busy[player] = true

	local rarities
	rarities, state.sinceEpic, state.sinceLegendary = Draw.roll(rolls, Config.ODDS[crate :: string], state.sinceEpic,
		state.sinceLegendary, function()
			return random:NextNumber()
		end, Config.PITY_EPIC, Config.PITY_LEGENDARY)

	local byRarity = pool()
	local results = {}
	for _, rarity in rarities do
		local names = byRarity[rarity] or byRarity.Common or {}
		local weapon = names[random:NextInteger(1, math.max(1, #names))]
		local entry = { weapon = weapon, rarity = rarity, duplicate = false, cash = 0 }
		local ok, message = false, "no weapon"
		if weapon then
			ok, message = giveWeapon(player, weapon)
		end
		if not ok then
			-- A weapon already owned pays its duplicate cash; any other failure gives that roll's cost back.
			entry.duplicate = message == "already owned"
			entry.cash = if entry.duplicate then Config.DUPLICATE_CASH[rarity] else math.floor(price / rolls)
			if crate == "Premium" and not entry.duplicate then
				state.keys += 1
				entry.cash = 0
			end
			cash.Value += entry.cash
		end
		table.insert(results, entry)
	end
	mirror(player, state)
	publish(player, state)
	busy[player] = nil
	return true, results
end

-- A Premium key purchase (MonetizationService's ProcessReceipt). True once granted, or already granted for this
-- PurchaseId; false while the player's data is not loaded (the receipt stays open and is retried).
function GachaService.grantKeys(player: Player, keys: number, purchaseId: string): boolean
	local state = states[player]
	local profile = ProfileGateway.get(player)
	if not (state and profile) then
		return false
	end
	local handled = profile.Data.gachaReceipts
	if typeof(handled) ~= "table" then
		handled = {}
		profile.Data.gachaReceipts = handled
	end
	if table.find(handled, purchaseId) then
		return true
	end
	state.keys += keys
	table.insert(handled, purchaseId)
	while #handled > MAX_RECEIPTS do
		table.remove(handled, 1)
	end
	mirror(player, state)
	publish(player, state)
	return true
end

function GachaService.forget(player: Player)
	states[player] = nil
	busy[player] = nil
end

return GachaService
