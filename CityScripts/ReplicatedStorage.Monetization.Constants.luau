-- The cash tiers and gamepasses the two shops sell, plus the attribute naming for gamepass
-- ownership. Shared by MonetizationService (which grants) and both shop controllers (which display
-- and prompt), so price, name and id can never drift between what a player is shown and what they
-- are charged.
--
-- EVERY id here is a placeholder 0. This place is a template that gets integrated into a different
-- production place later, and product/gamepass ids are per-universe -- an id created here would be
-- worthless there. A 0 id means "not configured": the shop renders that tile disabled and never
-- prompts, rather than calling MarketplaceService with a bad id and throwing at the player.
local Constants = {}

Constants.UNCONFIGURED_ID = 0

export type CashTier = {
	key: string,
	amount: number,
	robux: number, -- display only; the real price lives on the developer product itself
	productId: number,
	bestValue: boolean,
}

export type Gamepass = {
	key: string,
	name: string,
	description: string,
	robux: number,
	gamepassId: number,
	shop: boolean?, -- false keeps a pass out of the Gamepasses panel (it is sold elsewhere)
}

-- Ordered: the shop grid renders these in sequence, so the order here is the order on screen.
Constants.CashTiers = {
	{ key = "Cash5K", amount = 5000, robux = 49, productId = 0, bestValue = false },
	{ key = "Cash25K", amount = 25000, robux = 199, productId = 0, bestValue = false },
	{ key = "Cash100K", amount = 100000, robux = 749, productId = 0, bestValue = true },
	{ key = "Cash250K", amount = 250000, robux = 1699, productId = 0, bestValue = false },
	{ key = "Cash500K", amount = 500000, robux = 3199, productId = 0, bestValue = false },
	{ key = "Cash1M", amount = 1000000, robux = 5999, productId = 0, bestValue = false },
} :: { CashTier }

Constants.Gamepasses = {
	{ key = "DoubleCash", name = "2X CASH", description = "Double all cash earned", robux = 399, gamepassId = 0 },
	{ key = "DoubleXp", name = "2X XP", description = "Double all XP earned", robux = 399, gamepassId = 0 },
	{ key = "Vip", name = "VIP", description = "Exclusive weapon skins", robux = 799, gamepassId = 0 },
	{ key = "ExtraSlot", name = "EXTRA SLOT", description = "A fifth loadout slot", robux = 249, gamepassId = 0 },
	{ key = "FastReload", name = "FAST RELOAD", description = "25% quicker reloads", robux = 199, gamepassId = 0 },
	{ key = "InfiniteSprint", name = "INFINITE SPRINT", description = "No stamina drain", robux = 599, gamepassId = 0 },
	-- Unlocks the RPG in the Weaponary (the Tool's `Gamepass` attribute names this key). 10904398 is a
	-- STAND-IN: an existing pass the developer owns ("MINOR ADMIN"), so the unlock can be tested for real
	-- in Studio. Replace it with the real RPG pass id in the production universe.
	{ key = "RPG", name = "RPG", description = "Unlocks the RPG rocket launcher", robux = 499, gamepassId = 10904398 },
	-- The heist duffel passes (folded in from the heist's GamepassManager, 2026-11-18): PASTE each real
	-- pass id here, nowhere else. Sold from the duffel upgrade dialog, not the Gamepasses panel
	-- (`shop = false`), so they carry no price (robux 0 is never shown). GamepassManager holds only their
	-- multipliers.
	{ key = "DuffelCapacityX2", name = "DUFFEL X2", description = "Twice the duffel capacity", robux = 0, gamepassId = 0, shop = false },
	{ key = "DuffelCapacityX4", name = "DUFFEL X4", description = "Four times the duffel capacity", robux = 0, gamepassId = 0, shop = false },
	{ key = "DuffelSpeedBoost", name = "DUFFEL SPEED", description = "The duffel fills faster", robux = 0, gamepassId = 0, shop = false },
} :: { Gamepass }

-- Ownership checks (ServerScriptService.Monetization.Scripts.PassOwnership): a reported purchase is
-- confirmed with UserOwnsGamePassAsync up to CONFIRM_ATTEMPTS times, CONFIRM_RETRY_SECONDS apart; a
-- check that fails is asked again after FAILED_CHECK_RETRY_SECONDS (reads never ask).
Constants.CONFIRM_ATTEMPTS = 3
Constants.CONFIRM_RETRY_SECONDS = 2
Constants.FAILED_CHECK_RETRY_SECONDS = 30

function Constants.isConfigured(id: number?): boolean
	return typeof(id) == "number" and id > Constants.UNCONFIGURED_ID
end

-- Where a player's ownership of one gamepass is replicated to their own client. Generated rather
-- than hand-written, exactly like UpgradeConfig.ownedAttributeFor -- the writer (MonetizationService)
-- and the reader (GamepassShopController) must derive the same string from the same place.
function Constants.ownedAttributeFor(key: string): string
	return "GamepassOwned_" .. (string.gsub(key, "[^%w_]", "_"))
end

-- Lookup by developer product id, used by ProcessReceipt. Built on demand rather than cached: the
-- table is six entries and a receipt arrives at most once per purchase.
function Constants.tierForProductId(productId: number): CashTier?
	for _, tier in Constants.CashTiers do
		if tier.productId == productId and Constants.isConfigured(productId) then
			return tier
		end
	end
	return nil
end

return Constants
