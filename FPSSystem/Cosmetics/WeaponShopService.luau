-- Three responsibilities: (1) build a replicated read-only catalog of sellable weapons once at
-- server start, since ServerStorage never replicates and the shop needs stats/prices/a 3D model for
-- weapons the player doesn't own yet; (2) track weapon ownership (permanent and uncapped once
-- bought) plus the 4 loadout slots that decide which owned weapons are actually granted into the
-- Backpack, and restore those slots on every respawn -- this place's respawn flow does NOT preserve
-- Backpack contents on its own. Slot state is the single source of truth; the Backpack is a
-- disposable view of it, rebuilt every spawn. Crowbar is seeded as owned and in slot 1, and goes
-- through the exact same restore path as anything bought; (3) handle purchase and equip requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local UpgradeConfig = require(ReplicatedStorage.Weapons.UpgradeConfig)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)
local CosmeticsService = require(game:GetService("ServerScriptService").Cosmetics.Scripts.CosmeticsService)
local ProfileGateway = require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway)

local WEAPONS_FOLDER = ServerStorage.Weapons
local buyRequest = ReplicatedStorage.Weapons.Remotes.BuyRequest
local setLoadoutSlotRequest = ReplicatedStorage.Weapons.Remotes.SetLoadoutSlotRequest

local STARTING_WEAPON = "Crowbar"

-- ============================================
-- CATALOG
-- ============================================
local previousCatalog = ReplicatedStorage.Weapons:FindFirstChild("Catalog")
if previousCatalog then
	previousCatalog:Destroy()
end

local catalogFolder = Instance.new("Folder")
catalogFolder.Name = "Catalog"

local CATALOG_ATTRIBUTES = { "Category", "Price", "damage", "rateOfFire", "magazineSize", "range", "ShopViewRotation" }

for _, template in WEAPONS_FOLDER:GetChildren() do
	-- Category, not Price: every weapon has a Category, only sellable ones have a Price. Keying
	-- on Price silently excluded Crowbar (and any other owned-only weapon) from the catalog
	-- entirely, so it could never appear even in the Melee tab it belongs to.
	if template:IsA("Tool") and template:GetAttribute("Category") then
		local entry = Instance.new("Folder")
		entry.Name = template.Name
		for _, attrName in CATALOG_ATTRIBUTES do
			entry:SetAttribute(attrName, template:GetAttribute(attrName))
		end
		entry:SetAttribute("iconId", template.TextureId)

		-- A standalone copy of the weapon's visual body, for the shop's 3D rotating display: a
		-- clean MeshPart assembly with no rig/animation dependency, safe to clone.
		local blaster = template:FindFirstChild("Blaster")
		if blaster then
			blaster:Clone().Parent = entry
		end

		entry.Parent = catalogFolder
	end
end

catalogFolder.Parent = ReplicatedStorage.Weapons

-- ============================================
-- OWNERSHIP (permanent once purchased, uncapped, PERSISTED via ProfileGateway) + LOADOUT SLOTS
-- (exactly 4, govern only what's granted into the Backpack)
-- ============================================
local MAX_LOADOUT_SLOTS = 4

local ownedWeapons: { [Player]: { [string]: boolean } } = {}
local equippedSlots: { [Player]: { [number]: string } } = {}

-- Clones a fresh copy of a weapon with the player's current upgrade level already applied. Shared
-- by a fresh purchase and a post-respawn restore, so "upgrade level carries onto a new clone"
-- cannot drift between the two call sites.
local function grantWeapon(player: Player, weaponName: string, container: Instance)
	local template = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		return
	end

	local weapon = template:Clone()
	local upgradeLevel = player:GetAttribute(UpgradeConfig.attributeFor(weaponName)) or 0
	if upgradeLevel > 0 then
		local stockDamage = template:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
		if typeof(stockDamage) == "number" then
			weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + upgradeLevel * UpgradeConfig.DAMAGE_PER_LEVEL)
		end
	end
	weapon.Parent = container
	-- Dressed here rather than at the two call sites because both the respawn restore and the equip
	-- path funnel through this function; skinning at the choke point is what stops the two drifting.
	-- Guarded because this is appearance code sitting inside the weapon-granting path. grantWeapon is
	-- called in a loop by restoreEquippedWeapons and immediately before publishSlots in the equip
	-- branch, so an unguarded throw here would silently drop later loadout slots or desync the slot
	-- attributes the client renders. A failed skin must cost the player a colour, never a weapon.
	local ok, err = pcall(CosmeticsService.applyToTool, player, weapon)
	if not ok then
		warn("[Cosmetics] failed to skin " .. weaponName .. ": " .. tostring(err))
	end
end

local function findLiveTool(player: Player, weaponName: string): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in { backpack, character } do
		local tool = container and container:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

-- Republishes the 4 slots as attributes -- the single source of truth the client reads for
-- rendering the inventory column and the Equip/Dequip button state. Called after every change
-- rather than patched incrementally, so the replicated state can never drift from `equippedSlots`.
local function publishSlots(player: Player)
	local slots = equippedSlots[player]
	if not slots then
		return
	end
	for i = 1, MAX_LOADOUT_SLOTS do
		player:SetAttribute("LoadoutSlot" .. i, slots[i] or "")
	end
end

local function restoreEquippedWeapons(player: Player)
	local slots = equippedSlots[player]
	if not slots then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, weaponName in slots do
		-- Idempotent: this can legitimately run more than once for the same character (the
		-- already-present-character path plus CharacterAdded), and a second pass must not hand out
		-- a duplicate.
		if not backpack:FindFirstChild(weaponName) then
			grantWeapon(player, weaponName, backpack)
		end
	end
end

local function isWeaponOwned(player: Player, weaponName: string): boolean
	local owned = ownedWeapons[player]
	return owned ~= nil and owned[weaponName] == true
end

-- Writes the WHOLE ownership and loadout tables, never just the slot that changed: equipping moves a
-- weapon OUT of one slot and INTO another, so writing only the destination would leave the source slot
-- stale in the profile and duplicate the weapon on the next join. Both tables are tiny (<= 37 keys,
-- <= 4 slots), so a full copy each time is cheaper than tracking deltas correctly.
--
-- Copied rather than aliased: ownedWeapons[player] is cleared on PlayerRemoving and mutated in place
-- elsewhere, and ProfileStore may be serialising Data on its own autosave timer at that moment.
--
-- Slot indices are written as STRINGS, and that is not cosmetic. A DataStore serialises through JSON,
-- which has no integer keys, and a sparse integer-keyed table does not survive it. Measured with
-- HttpService, which uses the same encoder:
--
--   { [1] = "Crowbar", [3] = "Glock 17" }  ->  ["Crowbar"]          -- slot 3 destroyed outright
--   { [2] = "Glock 17" }                   ->  { "2": "Glock 17" }  -- key comes back as a string
--   { ["1"] = "Crowbar", ["3"] = "Glock 17" } -> round-trips exactly
--
-- ProfileStore's Studio mock keeps the table in memory and reproduces none of this, so the integer
-- version passes every Studio test and drops a live player's third and fourth slots. hydrate reads
-- these back through tonumber, so it accepts either form.
local function loadoutForProfile(player: Player): { [string]: string }
	local out = {}
	for index, weaponName in equippedSlots[player] or {} do
		out[tostring(index)] = weaponName
	end
	return out
end

local function mirrorLoadout(player: Player)
	ProfileGateway.mirror(player, function(profile)
		profile.Data.weaponsOwned = table.clone(ownedWeapons[player] or {})
		profile.Data.loadout = loadoutForProfile(player)
	end)
end

-- Restores ownership and the 4 slots, then hands out the Tools.
--
-- Registered as a plain hydrator, NOT a post-hydrator, and that is load-bearing: CosmeticsService
-- registers a POST-hydrator that re-dresses every Tool the player is carrying, so the Tools have to
-- exist by the time that runs. Restoring here means the persisted skin lands on a restored weapon for
-- free, with no cosmetics code in this file beyond the applyToTool call grantWeapon already makes.
--
-- May run before or after the safePlayerAdded handler below (the gateway yields on a DataStore round
-- trip, so it usually lands last, but that is not guaranteed) -- it builds the tables itself either
-- way, and the handler's own seed is guarded on them not existing.
local function hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end

	local owned = {}
	for weaponName in profile.Data.weaponsOwned do
		owned[weaponName] = true
		player:SetAttribute(UpgradeConfig.ownedAttributeFor(weaponName), true)
	end

	local slots = {}
	for slotIndex, weaponName in profile.Data.loadout do
		-- tonumber because a sparse integer-keyed table does NOT round-trip through a real DataStore as
		-- integers: JSON has no integer keys, so { [2] = "Glock 17" } comes back as { ["2"] = ... }.
		-- ProfileStore's Studio mock keeps them as numbers, so reading only one of the two forms would
		-- pass every Studio test and silently empty every live player's loadout.
		local index = tonumber(slotIndex)
		if index and index >= 1 and index <= MAX_LOADOUT_SLOTS and typeof(weaponName) == "string" and owned[weaponName] then
			slots[index] = weaponName
		end
	end

	-- Seeded ONLY when the profile holds no weapons AT ALL, which is what distinguishes a brand-new
	-- profile from a returning player who deliberately re-slotted or sold their starting weapon.
	-- Keying this off an empty LOADOUT instead would hand the Crowbar back on every single join to
	-- anyone who moved it out of a slot.
	if next(owned) == nil then
		owned[STARTING_WEAPON] = true
		slots[1] = STARTING_WEAPON
		player:SetAttribute(UpgradeConfig.ownedAttributeFor(STARTING_WEAPON), true)
		-- Written straight into the profile rather than through mirror, which is deliberately a no-op
		-- for the whole of the hydrator phase. Recording the seed makes "no weapons at all" a state a
		-- profile passes through exactly once in its life.
		profile.Data.weaponsOwned = table.clone(owned)
		profile.Data.loadout = { ["1"] = STARTING_WEAPON }
	end

	ownedWeapons[player] = owned
	equippedSlots[player] = slots
	publishSlots(player)

	-- The Backpack is a disposable view of the slots (see the header), so it is reconciled, not added
	-- to: if the safePlayerAdded handler below already ran and granted the default Crowbar before this
	-- did, that Tool is stale the moment the real loadout is restored, and restoreEquippedWeapons only
	-- ever ADDS. Measured: without this the player joins holding Crowbar plus their restored weapons.
	local wanted = {}
	for _, weaponName in slots do
		wanted[weaponName] = true
	end
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and not wanted[tool.Name] then
					tool:Destroy()
				end
			end
		end
	end
	restoreEquippedWeapons(player)
end

safePlayerAdded(function(player: Player)
	-- Defaults only when hydrate has not already built this player's state. An unconditional seed here
	-- would overwrite a just-restored loadout whenever this handler happened to run second. The
	-- symmetry is what makes both orderings land on restored state: whichever runs first creates, and
	-- hydrate always wins because it overwrites rather than merges.
	if not ownedWeapons[player] then
		ownedWeapons[player] = { [STARTING_WEAPON] = true }
		equippedSlots[player] = { [1] = STARTING_WEAPON }
		player:SetAttribute(UpgradeConfig.ownedAttributeFor(STARTING_WEAPON), true)
		publishSlots(player)
		-- Deliberately NOT mirrored. During the hydrator phase mirror is a no-op anyway, and after the
		-- bind this branch is reachable only when ownedWeapons[player] is still nil -- which means
		-- hydrate threw and _runHydrators swallowed it. Mirroring here would then write the default
		-- { Crowbar } over the player's real saved ownership and loadout, so the one case it could
		-- "cover" is the exact case where it destroys data. The fresh-profile seed is recorded by
		-- hydrate, straight into profile.Data, which is the only place that can tell a new profile from
		-- a failed restore.
	end

	player.CharacterAdded:Connect(function()
		restoreEquippedWeapons(player)
	end)

	-- safePlayerAdded also fires for players already in the game, whose character may already
	-- exist. CharacterAdded never fires for that one, so without this a player would hold nothing
	-- until their first death.
	if player.Character then
		restoreEquippedWeapons(player)
	end
end)

ProfileGateway.registerHydrator(hydrate)

Players.PlayerRemoving:Connect(function(player: Player)
	ownedWeapons[player] = nil
	equippedSlots[player] = nil
end)

-- ============================================
-- BUY HANDLING -- grants ownership only. Never touches the Backpack or a loadout slot; the player
-- equips separately via SetLoadoutSlotRequest.
-- ============================================
buyRequest.OnServerEvent:Connect(function(player: Player, weaponName: any)
	if typeof(weaponName) ~= "string" then
		return
	end

	local template = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		return
	end

	local price = template:GetAttribute("Price")
	if typeof(price) ~= "number" then
		return -- not sellable (e.g. Crowbar)
	end

	if isWeaponOwned(player, weaponName) then
		return -- already own it -- the client should be sending UpgradeRequest instead
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < price then
		return
	end

	local owned = ownedWeapons[player]
	if not owned then
		return
	end

	cash.Value -= price
	owned[weaponName] = true
	player:SetAttribute(UpgradeConfig.ownedAttributeFor(weaponName), true)
	-- After the live grant, never instead of it: a persistence failure must cost a save, not a weapon.
	mirrorLoadout(player)
end)

-- ============================================
-- LOADOUT SLOT HANDLING -- equip (with slot choice) or dequip. Never changes ownership.
-- ============================================
setLoadoutSlotRequest.OnServerEvent:Connect(function(player: Player, weaponName: any, slotIndex: any)
	if typeof(weaponName) ~= "string" then
		return
	end
	if slotIndex ~= nil then
		if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > MAX_LOADOUT_SLOTS then
			return
		end
	end
	if not isWeaponOwned(player, weaponName) then
		return -- can't equip/dequip a weapon you don't own
	end

	local slots = equippedSlots[player]
	if not slots then
		return
	end

	local currentSlot: number? = nil
	for i, name in slots do
		if name == weaponName then
			currentSlot = i
			break
		end
	end

	if slotIndex == nil then
		-- DEQUIP
		if not currentSlot then
			return -- not currently equipped, nothing to do
		end
		local equippedCount = 0
		for _ in slots do
			equippedCount += 1
		end
		if equippedCount <= 1 then
			return -- must always keep at least one weapon equipped -- refuse to leave the player unarmed
		end

		slots[currentSlot] = nil
		local tool = findLiveTool(player, weaponName)
		if tool then
			tool:Destroy()
		end
	else
		-- EQUIP into slotIndex, displacing whatever (if anything) currently occupies it
		if currentSlot == slotIndex then
			return -- already there
		end
		if currentSlot then
			slots[currentSlot] = nil -- the weapon moves, it does not duplicate into a second slot
		end

		local displaced = slots[slotIndex]
		if displaced then
			local displacedTool = findLiveTool(player, displaced)
			if displacedTool then
				displacedTool:Destroy()
			end
		end

		slots[slotIndex] = weaponName

		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			local existing = backpack:FindFirstChild(weaponName)
			if existing then
				existing:Destroy() -- defensive: should not exist yet, but never duplicate
			end
			grantWeapon(player, weaponName, backpack)
		end
	end

	publishSlots(player)
	-- One mirror for all three slot write sites (dequip, vacate-old-slot, occupy-new-slot). Every path
	-- that mutates `slots` reaches here -- the early returns above all happen before any mutation -- so
	-- a single call after publishSlots cannot miss a branch the way three separate calls could.
	mirrorLoadout(player)
end)
