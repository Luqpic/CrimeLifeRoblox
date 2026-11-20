-- Weapon gacha (2026-11-20): wires ReplicatedStorage.Gacha.Remotes to GachaService. Roll (RemoteFunction) returns
-- { ok, results | message }; BuyKeys (RemoteEvent) prompts a Premium key product (granted in MonetizationService's
-- ProcessReceipt).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Gacha.Config)
local GachaService = require(script.Parent.GachaService)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local remotes = ReplicatedStorage.Gacha.Remotes

remotes.Roll.OnServerInvoke = function(player: Player, count: unknown, crate: unknown)
	local ok, result = GachaService.roll(player, count, crate)
	if ok then
		return { ok = true, results = result }
	end
	return { ok = false, message = result }
end

remotes.BuyKeys.OnServerEvent:Connect(function(player: Player, key: unknown)
	local product = typeof(key) == "string" and Config.keyProductByKey(key)
	if product and product.productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.productId)
	end
end)

safePlayerAdded(function(player: Player)
	GachaService.ensure(player)
	GachaService.checkPolicy(player)
end)
Players.PlayerRemoving:Connect(GachaService.forget)
