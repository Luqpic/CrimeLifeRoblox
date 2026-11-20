--!strict
-- Weapon gacha (developer, 2026-11-20 evening): weapons come from crates instead of the buy button. Every number here.
-- Standard crates cost cash; Premium crates open with keys bought with Robux. Odds are shown on the crate page
-- before any roll (paid random items). A weapon's rarity is its Rarity attribute on the Tool in
-- ServerStorage.Weapons (set in Edit); without one it falls back to its old shop price.
local Config = {}

Config.ROLL_PRICE = 300
Config.TEN_ROLL_PRICE = 2700 -- ten rolls, at least one Rare or better

Config.ORDER = { "Common", "Rare", "Epic", "Legendary" }

Config.ODDS = {
	Standard = { Common = 0.60, Rare = 0.28, Epic = 0.10, Legendary = 0.02 },
	Premium = { Common = 0, Rare = 0.72, Epic = 0.22, Legendary = 0.06 },
}

-- Pity, shared by both crates: an Epic or better by roll PITY_EPIC since the last one, a Legendary by roll
-- PITY_LEGENDARY since the last one, at the latest.
Config.PITY_EPIC = 30
Config.PITY_LEGENDARY = 100

-- Cash for a weapon the player already owns.
Config.DUPLICATE_CASH = { Common = 60, Rare = 150, Epic = 400, Legendary = 1000 }

Config.COLORS = {
	Common = Color3.fromRGB(170, 176, 188),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(176, 92, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
}

-- Premium keys (developer products; ids filled once the products exist). robux is the list price shown until the
-- live price is read from MarketplaceService.
Config.KEY_PRODUCTS = {
	{ key = "PremiumKey1", keys = 1, robux = 49, productId = 0 },
	{ key = "PremiumKey10", keys = 10, robux = 399, productId = 0 },
}

function Config.keyProductFor(productId: number): { key: string, keys: number, robux: number, productId: number }?
	for _, product in Config.KEY_PRODUCTS do
		if product.productId ~= 0 and product.productId == productId then
			return product
		end
	end
	return nil
end

function Config.keyProductByKey(key: string): { key: string, keys: number, robux: number, productId: number }?
	for _, product in Config.KEY_PRODUCTS do
		if product.key == key then
			return product
		end
	end
	return nil
end

-- The old shop price's rarity: Common up to 450, Rare up to 700, Epic up to 950, Legendary above.
function Config.rarityForPrice(price: unknown): string?
	if typeof(price) ~= "number" then
		return nil
	end
	if price <= 450 then
		return "Common"
	elseif price <= 700 then
		return "Rare"
	elseif price <= 950 then
		return "Epic"
	end
	return "Legendary"
end

-- A weapon Tool's (or catalog entry's) rarity, or nil when it is not in the crates (the Crowbar, a gamepass weapon).
function Config.rarityOf(item: Instance): string?
	if item:GetAttribute("Gamepass") ~= nil then
		return nil
	end
	local rarity = item:GetAttribute("Rarity")
	if typeof(rarity) == "string" and Config.COLORS[rarity] then
		return rarity
	end
	return Config.rarityForPrice(item:GetAttribute("Price"))
end

-- The odds as players read them: "Common 60%, Rare 28%, Epic 10%, Legendary 2%".
function Config.oddsText(crate: string): string
	local parts = {}
	for _, rarity in Config.ORDER do
		local chance = Config.ODDS[crate][rarity]
		if chance > 0 then
			table.insert(parts, string.format("%s %s%%", rarity, tostring(math.floor(chance * 1000 + 0.5) / 10)))
		end
	end
	return table.concat(parts, ", ")
end

return Config
