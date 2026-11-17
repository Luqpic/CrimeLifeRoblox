--!strict
-- Distance-based payout gate (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
--
-- Replaces the Claim-zone cash-out at all four locations. A bag banks when its
-- owner is clear of the building AND at least `escapeDistance` studs from the
-- location's anchor.
--
-- Two design points that are load-bearing, not incidental:
--
--   * Distance is HORIZONTAL. Every location's StatusBillboardAnchor floats
--     40-120 studs above its building so the billboard reads from ground
--     level; a 3D distance would credit that height as escape progress.
--
--   * `isInsideBuilding` is INJECTED rather than computed here. The Bank's
--     definition is a three-role union (Lobby OR Vault OR BankVaultZone --
--     the lobby, the vault, and the underground gauntlet between them) while
--     the other three are a single interior role. Both consumers already own
--     that expression; duplicating it here would be a third copy to drift.
--     It is also what keeps the Bank correct: its VaultZone is 314 studs
--     horizontally from its own anchor, so without this gate any
--     escapeDistance below ~314 would bank the bag the moment it filled.
--
-- Deliberately knows nothing about workspace, zones, currency or remotes: it
-- takes plain callbacks so GetawaySpec can drive it without a DataModel.

local Getaway = {}
Getaway.__index = Getaway

local function horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function Getaway.new(cfg)
	assert(type(cfg) == "table", "Getaway requires a config table")
	assert(type(cfg.escapeDistance) == "number" and cfg.escapeDistance > 0,
		"Getaway requires a positive escapeDistance")
	assert(type(cfg.isInsideBuilding) == "function", "Getaway requires isInsideBuilding")
	assert(type(cfg.getDuffel) == "function", "Getaway requires getDuffel")
	assert(type(cfg.onEscaped) == "function", "Getaway requires onEscaped")
	assert(type(cfg.getPlayers) == "function", "Getaway requires getPlayers")

	local getAnchorPosition = cfg.getAnchorPosition
	if not getAnchorPosition then
		local anchor = cfg.anchor
		assert(anchor, "Getaway requires either anchor (a BasePart) or getAnchorPosition")
		getAnchorPosition = function() return anchor.Position end
	end

	return setmetatable({
		escapeDistance = cfg.escapeDistance,
		getAnchorPosition = getAnchorPosition,
		isInsideBuilding = cfg.isInsideBuilding,
		getDuffel = cfg.getDuffel,
		onEscaped = cfg.onEscaped,
		getPlayers = cfg.getPlayers,
		-- A player mid-respawn has no character; treat that as "not escaped
		-- yet" rather than erroring -- this runs on a heartbeat and must not
		-- take the location's loop down mid-session.
		getPosition = cfg.getPosition or function(player)
			local character = player.Character
			local root = character and character.PrimaryPart
			return root and root.Position or nil
		end,
		-- Fired-once latch, same edge-triggered discipline as timerShown /
		-- duffelFullNotified elsewhere in this project. Needed even though
		-- onEscaped normally zeroes the bag, because bank:Claim returns 0 when
		-- the session is no longer Active -- without the latch that case would
		-- re-fire every tick for the rest of the session.
		_fired = {},
	}, Getaway)
end

-- Studs still needed before this player's bag banks, or nil when they are not
-- in a position to bank at all (no bag, still inside, no character). The
-- server does not transmit this -- the client computes the same number from
-- the same inputs. It exists so a spec can assert against what is rendered.
function Getaway:DistanceRemaining(player): number?
	if self.getDuffel(player) <= 0 then return nil end
	if self.isInsideBuilding(player) then return nil end
	local position = self.getPosition(player)
	if not position then return nil end
	local travelled = horizontalDistance(position, self.getAnchorPosition())
	return math.max(0, self.escapeDistance - travelled)
end

-- Is this player still at the robbery: inside the building, or horizontally closer to the anchor than
-- escapeDistance? (Police and wanted, 2026-11-17: an Active robbery keeps its participants "seen" only while
-- this holds.) No character counts as not near.
function Getaway:IsNear(player): boolean
	if self.isInsideBuilding(player) then return true end
	local position = self.getPosition(player)
	if not position then return false end
	return horizontalDistance(position, self.getAnchorPosition()) < self.escapeDistance
end

function Getaway:Step()
	for _, player in ipairs(self.getPlayers()) do
		if self.getDuffel(player) <= 0 then
			-- Bag gone (banked, voided or never had one): re-arm for the next.
			self._fired[player] = nil
		elseif not self._fired[player] and not self.isInsideBuilding(player) then
			local position = self.getPosition(player)
			if position then
				local travelled = horizontalDistance(position, self.getAnchorPosition())
				if travelled >= self.escapeDistance then
					self._fired[player] = true
					self.onEscaped(player)
					-- If onEscaped cleared the bag (the common case: bank:Claim
					-- zeroes it), re-arm immediately rather than waiting for a
					-- future Step to observe duffel==0 -- if the bag is refilled
					-- before that Step runs, that branch is never reached and the
					-- latch would stay stuck true, permanently blocking a second
					-- payout. onEscaped implementations that deliberately leave
					-- the bag alone (bank:Claim returning 0 post-session) still
					-- latch correctly, since getDuffel stays > 0 here.
					if self.getDuffel(player) <= 0 then
						self._fired[player] = nil
					end
				end
			end
		end
	end
end

function Getaway:Forget(player)
	self._fired[player] = nil
end

return Getaway
