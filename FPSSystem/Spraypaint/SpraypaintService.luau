-- Spraypaint: a currency earned by killing NPCs and levelling up, spent on skins.
--
-- The earn path is two LISTENERS on signals the game already broadcasts, so no existing file is
-- modified. ShotResolver, KillStatsService and LevelingService are working code in the damage and
-- progression paths, and Phase 1's hardest lesson was that economy and appearance code must not be
-- able to break them. Not touching them at all is stronger than guarding them.
--
-- Session-only. Nothing here persists, matching Cash, Leveling and the kill counters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(ReplicatedStorage.Spraypaint.Constants)
local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)
local CosmeticsService = require(ServerScriptService.Cosmetics.Scripts.CosmeticsService)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)

local SpraypaintService = {}

-- The level each player was last seen at. A baseline, not a cache: LevelingService sets Level inside
-- onPlayerAdded, so without this every player would collect a level-up award simply for joining.
--
-- Named in Schema.DERIVED and therefore never persisted, so a RESTORE has to re-seed it: see the
-- post-hydrator at the bottom of this file. The seed taken in safePlayerAdded below is taken before the
-- gateway's yielding load resolves, so it is only ever nil or LevelingService's default 1 -- never the
-- restored level.
local lastLevel: { [Player]: number } = {}

-- A weapon's OWN balance only -- never includes the shared bucket. typeof-guarded on weaponName
-- itself, not just the attribute read: Constants.balanceAttributeFor throws on a non-string (the same
-- gsub-on-nil crash the old ownedAttributeFor sanitiser was already exposed to), and a caller passing
-- through an unvalidated value must get 0 back rather than an error.
function SpraypaintService.balanceOf(player: any, weaponName: unknown): number
	if typeof(weaponName) ~= "string" then
		return 0
	end
	local value = player:GetAttribute(Constants.balanceAttributeFor(weaponName))
	return if typeof(value) == "number" then value else 0
end

function SpraypaintService.sharedBalanceOf(player: any): number
	local value = player:GetAttribute(Constants.SHARED_ATTRIBUTE)
	return if typeof(value) == "number" then value else 0
end

-- What a weapon can actually spend right now: its own balance plus the shared bucket it falls back
-- to. This is the figure the shop panel shows and the figure spend() checks against.
function SpraypaintService.spendableBalanceOf(player: any, weaponName: unknown): number
	return SpraypaintService.balanceOf(player, weaponName) + SpraypaintService.sharedBalanceOf(player)
end

-- Restores the persisted balances and owned skins onto the attributes the rest of the game reads.
-- Attributes stay the live source during a session; the profile is the copy that outlives it.
--
-- `profile` is normally supplied by the gateway's own hydrator loop, which runs before the profile is
-- bound (see ProfileGateway.registerHydrator below) -- ProfileGateway.get(player) would still be nil
-- at that point. The fallback lookup exists only so a direct call, such as a test that has already
-- bound a stand-in with Gateway._bind, still works without threading a profile through by hand.
function SpraypaintService.hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end
	for weaponName, amount in profile.Data.spraypaint do
		if typeof(amount) == "number" then
			player:SetAttribute(Constants.balanceAttributeFor(weaponName), amount)
		end
	end
	player:SetAttribute(Constants.SHARED_ATTRIBUTE, profile.Data.spraypaintShared or 0)
	for paletteKey in profile.Data.skinsOwned do
		player:SetAttribute(Constants.ownedAttributeFor(paletteKey), true)
	end
end

-- Guarded rather than trusted: a negative grant would be a silent deduction, and the callers are rate
-- tables that a later edit could get wrong. NaN and infinity both pass a bare `amount <= 0` check
-- (NaN compares false to everything; infinity is merely large) -- reachable only through the
-- single-UserId `/setlevel` admin path today, but an infinite balance makes spend's balance check
-- false forever, making every skin free permanently, so it is guarded here regardless. Shared by both
-- grant functions below so the rule can only drift once, not twice.
local function isValidAmount(amount: unknown): boolean
	return typeof(amount) == "number" and amount == amount and amount ~= math.huge and (amount :: number) > 0
end

-- Credits ONE weapon's balance. `reason` is unused by the logic (kept for call-site readability and
-- for a future audit log) exactly as it was on the pre-split grant.
function SpraypaintService.grant(player: any, weaponName: unknown, amount: number, reason: string): number
	local balance = SpraypaintService.balanceOf(player, weaponName)
	if typeof(weaponName) ~= "string" or not isValidAmount(amount) then
		return balance
	end
	local updated = balance + math.floor(amount)
	player:SetAttribute(Constants.balanceAttributeFor(weaponName), updated)
	ProfileGateway.mirror(player, function(profile)
		profile.Data.spraypaint[weaponName] = updated
	end)
	return updated
end

-- Credits the shared bucket directly. Only SpraypaintService.onLevelChanged calls this today (a
-- level-up with no weapon equipped) -- everything else that earns Spraypaint earns it for a specific
-- weapon through grant() above. Never called to satisfy a kill: "never allocate it arbitrarily to one
-- weapon" cuts the other way too -- the bucket is never allocated a kill's reward either.
function SpraypaintService.grantShared(player: any, amount: number, reason: string): number
	local balance = SpraypaintService.sharedBalanceOf(player)
	if not isValidAmount(amount) then
		return balance
	end
	local updated = balance + math.floor(amount)
	player:SetAttribute(Constants.SHARED_ATTRIBUTE, updated)
	ProfileGateway.mirror(player, function(profile)
		profile.Data.spraypaintShared = updated
	end)
	return updated
end

-- Draws from the weapon's OWN balance first, and only reaches into the shared bucket for whatever
-- that balance cannot cover -- the fallback order the design calls for, never the reverse. All-or-
-- nothing: an insufficient combined total changes neither balance.
function SpraypaintService.spend(player: any, weaponName: unknown, amount: number): boolean
	if typeof(weaponName) ~= "string" or typeof(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 then
		return false
	end
	local ownBalance = SpraypaintService.balanceOf(player, weaponName)
	local sharedBalance = SpraypaintService.sharedBalanceOf(player)
	if ownBalance + sharedBalance < amount then
		return false
	end
	local fromOwn = math.min(ownBalance, amount)
	local fromShared = amount - fromOwn
	local updatedOwn = ownBalance - fromOwn
	local updatedShared = sharedBalance - fromShared
	player:SetAttribute(Constants.balanceAttributeFor(weaponName), updatedOwn)
	if fromShared > 0 then
		player:SetAttribute(Constants.SHARED_ATTRIBUTE, updatedShared)
	end
	ProfileGateway.mirror(player, function(profile)
		profile.Data.spraypaint[weaponName] = updatedOwn
		if fromShared > 0 then
			profile.Data.spraypaintShared = updatedShared
		end
	end)
	return true
end

-- Production entry point for the Eliminated BindableEvent. Validates the signal's shape strictly,
-- because this receives whatever ShotResolver passes, then delegates the award rule. `weaponName` is
-- the fourth argument ShotResolver now fires (both at the direct-hit site and the bleed-tick site) --
-- the weapon that made the kill, credited below.
function SpraypaintService.onEliminated(attacker: unknown, victimHumanoid: unknown, _appliedDamage: unknown, weaponName: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return
	end
	SpraypaintService.awardForVictim(attacker, victimHumanoid, weaponName)
end

-- The award rule, split from the guard above so it can be tested. A Player cannot be constructed with
-- Instance.new, so no test stand-in can ever satisfy `typeof(attacker) == "Instance"`; splitting keeps
-- that check STRICT in production instead of loosening real validation for test convenience.
--
-- Reads the victim's faction exactly as KillStatsService does, which is what makes PvP worthless here:
-- a player's own character carries no Faction attribute, so it resolves to nil and pays zero.
--
-- A kill with no valid weapon name pays nothing rather than falling back to the shared bucket: the
-- shared bucket is grandfathering for the old scalar balance and the no-weapon-equipped level-up case
-- ONLY, never a home for a kill reward that could not be attributed to a weapon.
function SpraypaintService.awardForVictim(player: any, victimHumanoid: unknown, weaponName: unknown)
	if typeof(victimHumanoid) ~= "Instance" then
		return
	end
	local character = victimHumanoid.Parent
	if not character then
		return
	end
	if typeof(weaponName) ~= "string" then
		return
	end
	local amount = Constants.spraypaintForFaction(character:GetAttribute("Faction"))
	if amount > 0 then
		SpraypaintService.grant(player, weaponName, amount, "kill")
	end
end

-- Level handler. Awards per level GAINED, so a multi-level jump pays for each one rather than once,
-- and never awards on the join-time set or on a restore. Not weapon-specific by nature, so it credits
-- whichever weapon is actually in the player's hand at the moment of the level-up, and the shared
-- bucket when nothing is equipped to credit.
function SpraypaintService.onLevelChanged(player: any)
	local level = player:GetAttribute("Level")
	if typeof(level) ~= "number" then
		return
	end
	local previous = lastLevel[player]
	-- Recorded before either guard below, so the baseline tracks the level even when nothing is paid.
	lastLevel[player] = level

	-- Before the bind, EVERY Level change is restoration rather than progression, by construction: the
	-- gateway runs every hydrator strictly before it sets profiles[player]. Re-baselining instead of
	-- paying is what makes a level change whose `previous` predates the bind impossible to read as a
	-- level-up -- structurally, and not because the attribute signal happens to be deferred and no
	-- hydrator happens to yield today. Both of those are true and both were measured, but a measured
	-- invariant is one refactor away from being neither, and this phase has twice watched "correct by
	-- ordering luck" become "broken".
	--
	-- It costs nothing. The only player who is both unbound and still playing is one whose load failed,
	-- and they are being kicked with nothing saving -- an award paid here would have evaporated anyway.
	-- What it would NOT have done is evaporate quietly: mirror no-ops while unbound, so the award would
	-- have inflated the live attribute, and that attribute is the base the next grant or spend mirrors.
	if ProfileGateway.get(player) == nil then
		return
	end

	if previous == nil or level <= previous then
		return
	end

	local amount = (level - previous) * Constants.LEVEL_SPRAYPAINT
	local character = player.Character
	local equippedTool = character and character:FindFirstChildOfClass("Tool")
	if equippedTool then
		SpraypaintService.grant(player, equippedTool.Name, amount, "level")
	else
		SpraypaintService.grantShared(player, amount, "level")
	end
end

-- The client asks; the server decides. Every condition is re-checked here rather than trusted, so a
-- forged request cannot buy a palette the player cannot afford, nor reach the Vip tier at all.
--
-- Charges `weaponName`'s balance (own balance first, then the shared bucket -- see spend). Validated
-- the same way the auto-equip step below already validated it (Phase 1 measured why: an unvalidated
-- weapon name let a crafted client create unbounded player attributes) -- this is the earlier, and
-- now load-bearing, half of that same check, since it is what decides which balance gets spent.
function SpraypaintService.handleBuyRequest(player: any, paletteKey: unknown, weaponName: unknown): boolean
	if typeof(paletteKey) ~= "string" then
		return false
	end
	local palette = Palettes.byKey(paletteKey)
	if not palette or palette.source ~= "Spraypaint" then
		return false
	end
	if player:GetAttribute(Constants.ownedAttributeFor(paletteKey)) == true then
		return false
	end
	local price = Palettes.priceOf(paletteKey)
	if not price then
		-- Reaching here means a Spraypaint-sourced palette carries no price, which is a catalogue bug
		-- rather than a player action. Refusing loudly beats selling at an unknown price.
		warn("[Spraypaint] palette " .. paletteKey .. " is Spraypaint-sourced but has no price")
		return false
	end
	if typeof(weaponName) ~= "string" then
		return false
	end
	local template = ServerStorage.Weapons:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		return false
	end
	if not SpraypaintService.spend(player, weaponName, price) then
		return false
	end
	player:SetAttribute(Constants.ownedAttributeFor(paletteKey), true)
	ProfileGateway.mirror(player, function(profile)
		profile.Data.skinsOwned[paletteKey] = true
	end)
	return true
end

-- Named (rather than inline in the remote connection) so this seam the test suite can call directly,
-- matching the precedent CosmeticsService.handleEquipRequest already set.
function SpraypaintService.handleBuySkinRequest(player: Player, paletteKey: unknown, weaponName: unknown)
	if not SpraypaintService.handleBuyRequest(player, paletteKey, weaponName) then
		return
	end
	-- Equipped by the SERVER in the same call rather than by a second client remote. The
	-- PURCHASE is what is atomic -- handleBuyRequest above either fully succeeds or changes
	-- nothing (it now also validates weaponName itself, since it is what gets charged). Re-derived
	-- rather than trusted from that success: this half stays independently correct on its own terms.
	if typeof(weaponName) ~= "string" then
		return
	end
	local template = ServerStorage.Weapons:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		return
	end
	player:SetAttribute(CosmeticsService.attributeFor(weaponName), paletteKey)
	-- The equip half of a purchase was going unmirrored: ownership persisted but the auto-equip did
	-- not, so a rejoin after buying-and-wearing a skin in one action showed the weapon back on Stock.
	ProfileGateway.mirror(player, function(profile)
		profile.Data.equippedSkin[weaponName] = paletteKey
	end)
	CosmeticsService.refresh(player, weaponName)
end

function SpraypaintService.start()
	ServerScriptService.Blaster.Events.Eliminated.Event:Connect(SpraypaintService.onEliminated)

	ReplicatedStorage.Spraypaint.Remotes.BuySkinRequest.OnServerEvent:Connect(SpraypaintService.handleBuySkinRequest)

	safePlayerAdded(function(player: Player)
		-- Hydration itself now happens inside ProfileGateway's own join handler (see
		-- ProfileGateway.registerHydrator below), strictly before the profile is bound, so by the time
		-- any code here could observe a bound profile the attribute is already restored. This
		-- initialiser is only a fallback for a player whose load failed and who is about to be kicked --
		-- no hydrator ever runs for them, and without this the attribute would stay nil for that window.
		-- Only the shared bucket needs a default seeded here: a per-weapon balance already reads as 0
		-- through balanceOf's typeof guard when its attribute was never set, so there is nothing to
		-- pre-seed per weapon and no list of weapon names to seed it from.
		--
		-- The attribute set is NOT mirrored. This was the one adoption in the phase that mirrored its
		-- own default, justified as a fallback for a failed load -- but mirror no-ops without a bound
		-- profile, so on a failed load it did nothing at all, and the only state in which the write was
		-- live was the one where it put 0 over a real saved balance.
		if player:GetAttribute(Constants.SHARED_ATTRIBUTE) == nil then
			player:SetAttribute(Constants.SHARED_ATTRIBUTE, 0)
		end
		-- Recorded BEFORE connecting, so the join-time Level set cannot be read as a level-up. This seed
		-- is provisional: the gateway's load yields, so a RESTORED level always lands after it, which is
		-- what the post-hydrator at the bottom of this file re-seeds from.
		lastLevel[player] = player:GetAttribute("Level")
		player:GetAttributeChangedSignal("Level"):Connect(function()
			SpraypaintService.onLevelChanged(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastLevel[player] = nil
	end)
end

-- Registered at require time, so the gateway can restore this service's attributes before any other
-- code -- including this same service's own safePlayerAdded above -- can observe a bound profile.
ProfileGateway.registerHydrator(SpraypaintService.hydrate)

-- Re-seeds the level baseline from the level LevelingService has just restored.
--
-- Braces to onLevelChanged's belt: the unbound guard up there makes an award during restoration
-- unreachable, and this keeps `lastLevel` HONEST once the bind lands, so the first real level-up after a
-- rejoin is measured from the restored level rather than from a pre-restore default. Neither alone is
-- enough for a currency -- the guard without this would re-baseline correctly only by luck of which
-- change arrived last, and this without the guard depends on nothing in the hydrator loop yielding.
--
-- A POST-hydrator, not a hydrator: it reads another service's restored `Level` attribute, and hydrator
-- order is registration order, which is require order. Post-hydrators run after EVERY hydrator, so this
-- reads the restored level whichever service registered first -- including after a hydrator that
-- registers LATE, which the gateway now follows with the post-hydrators for exactly this reason.
--
-- Without it a returning level-12 player was paid (12 - 1) * 25 = 275 spraypaint on every rejoin. The
-- seed in safePlayerAdded above is taken before the gateway's yielding load resolves, so hydration's
-- SetAttribute("Level", 12) always lands afterwards and fires the listener with `previous` = 1. It was
-- silent only when SpraypaintRunner happened to win the require race and the seed was nil -- correct by
-- ordering luck, not by construction. Nothing was written (mirror no-ops before the bind), but the
-- inflated ATTRIBUTE survived as the base the next grant or spend mirrored, so the award was durable.
ProfileGateway.registerPostHydrator(function(player: any)
	lastLevel[player] = player:GetAttribute("Level")
end)

return SpraypaintService
