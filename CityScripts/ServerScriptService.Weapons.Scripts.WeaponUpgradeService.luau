-- Spends Cash to raise a player's damage upgrade level for one weapon TYPE (not one Tool
-- instance). Weapons are lost on death under the pickup system, so tying a purchased upgrade to a
-- Tool instance would wipe it on the next death; the level lives on the Player instead.
--
-- The damage bonus is always recomputed as stock damage + level * DAMAGE_PER_LEVEL, read fresh from
-- ServerStorage.Weapons each time -- never incrementally added to whatever a Tool's current damage
-- attribute happens to be -- so repeated upgrades cannot drift or double-apply.
--
-- Persisted as the upgrade LEVEL only, never the damage figure it implies: damage is in Schema.DERIVED
-- and is recomputed from stock damage + level on every grant. Storing the number would freeze a
-- balance change out of every existing player's weapons, silently.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)
local UpgradeConfig = require(ReplicatedStorage.Weapons.UpgradeConfig)

local WEAPONS_FOLDER = ServerStorage.Weapons
local upgradeRequest = ReplicatedStorage.Weapons.Remotes.UpgradeRequest

-- Warn once at start-up if two weapon names fold onto the same upgrade attribute.
do
	local names = {}
	for _, tool in WEAPONS_FOLDER:GetChildren() do
		table.insert(names, tool.Name)
	end
	UpgradeConfig.assertNoCollisions(names)
end

-- Applies the new level to every copy of this weapon the player currently holds (equipped or in
-- the backpack), so an upgrade takes effect immediately rather than only on the next pickup.
local function applyToHeldWeapons(player: Player, weaponName: string, stockDamage: number, newLevel: number)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local tool = container and container:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			tool:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + newLevel * UpgradeConfig.DAMAGE_PER_LEVEL)
		end
	end
end

-- Restores each weapon's upgrade level onto the attribute the rest of the game reads, and re-applies
-- the damage it implies to anything already in hand.
--
-- That second half exists because hydrator order is not guaranteed: WeaponShopService's hydrator hands
-- out the restored Tools, and grantWeapon computes their damage from this attribute. If it runs first,
-- it computes from an upgrade level of 0 and the player spends the session with stock damage on an
-- upgraded weapon. Re-applying here lands correctly in both orders without either service having to
-- know which registered first.
local function hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end

	for weaponName, level in profile.Data.weaponUpgrades do
		if typeof(level) == "number" and level > 0 then
			player:SetAttribute(UpgradeConfig.attributeFor(weaponName), level)

			local stockTemplate = WEAPONS_FOLDER:FindFirstChild(weaponName)
			local stockDamage = stockTemplate and stockTemplate:IsA("Tool")
				and stockTemplate:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
			if typeof(stockDamage) == "number" then
				applyToHeldWeapons(player, weaponName, stockDamage, level)
			end
		end
	end
end

ProfileGateway.registerHydrator(hydrate)

upgradeRequest.OnServerEvent:Connect(function(player: Player, weaponName: any)
	-- Everything below is validated server-side: the client only names a weapon, it never sends a
	-- level, a cost, or a damage number.
	if typeof(weaponName) ~= "string" then
		return
	end

	local stockTemplate = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (stockTemplate and stockTemplate:IsA("Tool")) then
		return
	end
	local stockDamage = stockTemplate:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
	if typeof(stockDamage) ~= "number" then
		return
	end

	-- You may only upgrade a weapon you own. Checked against the replicated ownership attribute rather
	-- than WeaponShopService's private table, because the attribute is this project's established
	-- ownership signal and is set on all four paths that can grant a weapon (hydrate's restore loop,
	-- both starting-weapon seeds, and purchase) -- and because reaching across for the private table
	-- would couple these two services for no gain.
	--
	-- This gap predates persistence: the client could always fire this remote for an unowned weapon and
	-- buy a level on it. It only became worth closing here because Task 5 made the level DURABLE -- what
	-- used to evaporate at logout now survives forever, so the same exploit went from session-scoped to
	-- permanent.
	if player:GetAttribute(UpgradeConfig.ownedAttributeFor(weaponName)) ~= true then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		return
	end

	local attributeName = UpgradeConfig.attributeFor(weaponName)
	local currentLevel = player:GetAttribute(attributeName) or 0
	local nextLevel = currentLevel + 1
	local cost = UpgradeConfig.COST_PER_LEVEL * nextLevel
	if cash.Value < cost then
		return
	end

	cash.Value -= cost
	player:SetAttribute(attributeName, nextLevel)
	applyToHeldWeapons(player, weaponName, stockDamage, nextLevel)
	-- After the live upgrade, never instead of it. The LEVEL, never `stockDamage + level * ...`: that
	-- product is derived, and a persisted copy of it would outlive the UpgradeConfig it came from.
	ProfileGateway.mirror(player, function(profile)
		profile.Data.weaponUpgrades[weaponName] = nextLevel
	end)
end)
