-- Owns everything that touches MarketplaceService: opening purchase prompts on a client's behalf,
-- granting cash when a developer-product receipt arrives, and publishing gamepass ownership.
--
-- Cash is granted by writing leaderstats.Cash -- the same IntValue CashService creates and
-- WeaponUpgradeService spends from. Deliberately NOT a second currency store: one value means a
-- purchase and a weapon upgrade can never disagree about what a player can afford.
--
-- Every product and gamepass id in Monetization.Constants is a placeholder 0 today. Both paths
-- below therefore refuse unconfigured ids instead of calling MarketplaceService with one, which
-- would throw in the player's face. When this template is integrated into the production place, the
-- only change needed is filling those ids in.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Monetization.Constants)
local PassOwnership = require(script.Parent.PassOwnership)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)
local validateNumber = require(ServerScriptService.Utility.TypeValidation.validateNumber)

local promptProductRemote = ReplicatedStorage.Monetization.Remotes.PromptProductPurchase
local promptGamepassRemote = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase

-- ============================================
-- GRANTING
-- ============================================
local function grantCash(player: Player, amount: number): boolean
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		return false
	end
	cash.Value += amount
	return true
end

-- ============================================
-- PURCHASE PROMPTS (client-initiated)
-- ============================================
-- The client sends a KEY, never an id. A key is validated against the table below; an id from a
-- client would be an arbitrary-prompt primitive, letting a crafted client pop any product in any
-- universe through this game's name.
local function tierForKey(key: string): Constants.CashTier?
	for _, tier in Constants.CashTiers do
		if tier.key == key then
			return tier
		end
	end
	return nil
end

local function gamepassForKey(key: string): Constants.Gamepass?
	for _, pass in Constants.Gamepasses do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

promptProductRemote.OnServerEvent:Connect(function(player: Player, key: any)
	if typeof(key) ~= "string" then
		return
	end
	local tier = tierForKey(key)
	if not tier or not Constants.isConfigured(tier.productId) then
		-- Unconfigured is the normal state in this template place, so this is a debug print rather
		-- than a warn: it is expected, not a fault.
		print(`MonetizationService: cash tier "{key}" has no product id configured yet`)
		return
	end
	MarketplaceService:PromptProductPurchase(player, tier.productId)
end)

promptGamepassRemote.OnServerEvent:Connect(function(player: Player, key: any)
	if typeof(key) ~= "string" then
		return
	end
	local pass = gamepassForKey(key)
	if not pass or not Constants.isConfigured(pass.gamepassId) then
		print(`MonetizationService: gamepass "{key}" has no id configured yet`)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.gamepassId)
end)

-- ============================================
-- RECEIPTS
-- ============================================
-- Returning NotProcessedYet for an unknown product is deliberate: Roblox retries the receipt later,
-- so a product added after a purchase still grants. Returning PurchaseGranted for something we did
-- not actually grant would consume the receipt and silently rob the player.
MarketplaceService.ProcessReceipt = function(receiptInfo)
	if not validateNumber(receiptInfo.ProductId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- The buyer left before the receipt landed. Not granted, not consumed -- it will be retried
		-- when they next join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local tier = Constants.tierForProductId(receiptInfo.ProductId)
	if not tier then
		warn(`MonetizationService: receipt for unknown product {receiptInfo.ProductId}; not consuming it`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not grantCash(player, tier.amount) then
		warn(`MonetizationService: could not grant {tier.amount} cash to {player.Name}; leaving receipt open`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================
-- GAMEPASS OWNERSHIP
-- ============================================
-- Published as player attributes (GamepassOwned_<key>) so the shops read ownership the same way they
-- read Level, Cash and WeaponOwned_* -- no extra remote. One path for every pass, the heist duffel
-- passes included (2026-11-18): PassOwnership checks at join, re-asks a failed check after 30 s, and
-- confirms a reported purchase with the web check before publishing it (a pass bought mid-session
-- takes effect without a rejoin).
safePlayerAdded(PassOwnership.publish)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(PassOwnership.onPurchaseFinished)
