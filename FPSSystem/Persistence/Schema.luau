-- The persisted profile's shape. Data only: no behaviour, no ProfileStore, no services.
--
-- Lives in ReplicatedStorage rather than beside the gateway so the tests can read it without pulling
-- in the server's session machinery.
local Schema = {}

-- Bumped when a field's MEANING changes, which makes that change a migration rather than a silent
-- misreading of old data. Adding a field needs no bump: ProfileStore's Reconcile fills it from the
-- template.
Schema.VERSION = 2

Schema.template = {
	-- v2: one balance PER WEAPON rather than one scalar for the whole player -- kills and level-ups
	-- credit the weapon that earned them. [weaponName] = number. See ProfileGateway.migrate for how a
	-- v1 profile's old scalar comes across.
	spraypaint = {},
	-- The v1 scalar's landing place after migration: a single figure any weapon may draw on once its
	-- OWN balance in `spraypaint` above is exhausted. Grandfathering, not a second currency -- nothing
	-- in normal play grants this except the level-up award when no weapon is equipped to credit.
	spraypaintShared = 0,
	skinsOwned = {},      -- [paletteKey] = true
	equippedSkin = {},    -- [weaponName] = paletteKey
	-- New-player starting balance -- not a placeholder zero. CashService.STARTING_CASH reads this
	-- value directly rather than holding its own copy, so the two cannot drift. This is written
	-- durably into every new player's saved profile, so a debug/test amount belongs as a session-only
	-- override in CashService, never as a change here.
	cash = 500,
	level = 1,
	xp = 0,
	-- Keyed by Stats.Constants' ATTRIBUTE names, not the faction names, so the saved table and
	-- KillStatsService's in-memory counts are the same shape with no translation between them.
	kills = {},           -- { CriminalKills = n, PoliceKills = n }
	weaponsOwned = {},    -- [weaponName] = true
	-- The upgrade LEVEL. The damage it implies is in DERIVED below and is recomputed on every grant.
	weaponUpgrades = {},  -- [weaponName] = level
	-- Sparse integer keys do not survive a real DataStore round trip as integers (JSON has no integer
	-- keys), so readers must accept string keys too. ProfileStore's Studio mock does NOT reproduce
	-- this, which is what makes it an invisible-in-testing failure.
	loadout = {},         -- [slotIndex] = weaponName
}

-- Values that are COMPUTED from something else and must never be written.
--
-- Each of these already has a single source: NextLevelXP from level, a Tool's SkinId from the player's
-- equipped-skin attribute, a weapon's damage from its upgrade level, the catalogue from ServerStorage
-- at server start, and lastLevel from the level seen at join. Persisting any of them means a stale
-- copy outliving its source and then contradicting it.
Schema.DERIVED = { "NextLevelXP", "SkinId", "damage", "catalogue", "lastLevel" }

return Schema
