local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local validateInstance = require(ServerScriptService.Utility.TypeValidation.validateInstance)
local validateShootArguments = require(script.validateShootArguments)
local validateShot = require(script.validateShot)
local validateReload = require(script.validateReload)
local ShotResolver = require(script.Parent.ShotResolver)
local MeleeMoves = require(script.Parent.MeleeMoves)
local Stealth = require(ServerScriptService.Movement.Scripts.Stealth)

local remotes = ReplicatedStorage.Blaster.Remotes
local shootRemote = remotes.Shoot
local reloadRemote = remotes.Reload

-- Thin wrapper around the shared resolver: this function is responsible only for deciding whether
-- to trust the client's request. Everything the shot then does lives in ShotResolver, which the AI
-- enemies call directly.
local function onShootEvent(
	player: Player,
	timestamp: number,
	blaster: Tool,
	origin: CFrame,
	tagged: { [string]: Humanoid }
)
	-- Validate the received arguments
	if not validateShootArguments(timestamp, blaster, origin, tagged) then
		return
	end

	-- Validate that the player can make this shot
	if not validateShot(player, timestamp, blaster, origin) then
		return
	end

	-- Crouch stealth (2026-11-20): gunfire gives the shooter away for a few seconds; a melee swing stays quiet.
	if not blaster:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE) then
		Stealth.expose(player)
	end

	-- Melee combos and heavy swings (combat depth, 2026-11-20): the swing's combo step or heavy, from its timestamp.
	local damageMultiplier, heavy = 1, false
	if blaster:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE) then
		damageMultiplier, heavy = MeleeMoves.onSwing(player, blaster, timestamp)
	end

	ShotResolver.resolveShot({
		shooter = player,
		weapon = blaster,
		origin = origin,
		-- The client's timestamp doubles as the spread seed, so the server reproduces the exact
		-- spread pattern the client drew.
		seed = timestamp,
		claimedTags = tagged,
		damageMultiplier = damageMultiplier,
		heavy = heavy,
	})
end

local function onReloadEvent(player: Player, blaster: Tool)
	-- Validate the received argument
	if not validateInstance(blaster, "Tool") then
		return
	end

	-- Make sure the player is able to reload this blaster
	if not validateReload(player, blaster) then
		return
	end

	local reloadTime = blaster:GetAttribute(Constants.RELOAD_TIME_ATTRIBUTE)
	local magazineSize = blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)

	local character = player.Character
	blaster:SetAttribute(Constants.RELOADING_ATTRIBUTE, true)

	local reloadTask
	local ancestryChangedConnection

	reloadTask = task.delay(reloadTime, function()
		blaster:SetAttribute(Constants.AMMO_ATTRIBUTE, magazineSize)
		blaster:SetAttribute(Constants.RELOADING_ATTRIBUTE, false)
		ancestryChangedConnection:Disconnect()
	end)

	ancestryChangedConnection = blaster.AncestryChanged:Connect(function()
		if blaster.Parent ~= character then
			blaster:SetAttribute(Constants.RELOADING_ATTRIBUTE, false)

			task.cancel(reloadTask)
			ancestryChangedConnection:Disconnect()
		end
	end)
end

local function initialize()
	shootRemote.OnServerEvent:Connect(onShootEvent)
	MeleeMoves.start()
	reloadRemote.OnServerEvent:Connect(onReloadEvent)
end

initialize()
