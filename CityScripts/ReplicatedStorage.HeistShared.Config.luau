--!strict
local Config = {}

-- Heist duration: 10min -> 5min -> 8min. Cooldown: 30min -> 20min -> 30min
-- (spec addenda, 2026-09-02 and 2026-09-04). Every countdown/UI/timer-expiry
-- path reads this one value -- see BankInstance.TryStart/_seal and
-- HeistClient's "HEIST"/"SEALED" labels -- so each balance change stays a
-- single-line edit here, never a duplicated literal elsewhere.
Config.SessionDuration = 600 -- 10 minutes (spec addendum, 2026-09-09), up from 8
Config.CooldownDuration = 1800
Config.DuffelCap = 15000 -- up from 10000 (spec addendum, 2026-09-09)
-- Studs the player must get from this location's StatusBillboardAnchor,
-- measured horizontally and only once clear of the building, before a
-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
-- neighbouring locations 165-205 apart it reads as "about one block over"
-- without pushing the player through another location's grounds.
-- A starting value, not a tuned one -- expect to adjust after playtesting.
-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
-- from inside the vault if Getaway's inside-the-building gate were ever
-- removed. See Getaway's own header.
Config.EscapeDistance = 200
Config.AccrualPerSecond = 133
Config.GuardCount = 4
Config.HeartbeatRate = 10
Config.HazardQueryRate = 20
Config.AutosaveInterval = 120

-- Gate behaviour
Config.GateTweenTime = 0.8

-- CounterDoor's 4 static barriers (spec addendum, 2026-09-05): tween-only
-- Transparency/CanCollide toggle, no positional movement, so this is its
-- own named duration, independent of GateTweenTime.
Config.CounterBarrierTweenTime = 0.5

-- Bank Clerk NPC reaction-sequence animations (spec addendum, 2026-09-05).
-- Raw numeric IDs, matching Config.Sounds' convention -- BankClerk.lua is
-- responsible for prefixing "rbxassetid://" itself.
Config.BankClerkAnimations = {
	Idle = "125474693216077",
	Surprised = "102739588935526",
	Scared = "88601399527319",
}

-- Laser defaults; per-instance attributes override these. Restored to known-
-- good values on 2026-08-27 after live drift (DutyCycle=3, FadeTime=1.6,
-- HazardThreshold=2) left the on-window with zero solid phase and made the
-- beam lethal ~0.06s into its fade-in — defeating the telegraph entirely.
-- If you want different numbers, set them here explicitly rather than via
-- the Properties panel; DutyCycle/HazardThreshold are bounded (0..1) by
-- what they represent (a cycle fraction, a Transparency value) and out-of-
-- range values break the fade math, not just "feel different".
Config.LaserCycleTime = 2.4
Config.LaserDutyCycle = 0.5
-- Telegraph: fade in/out either side of the solid phase, so danger is
-- visible before it's lethal. FadeTime is symmetric (same for in and out)
-- and per-instance attribute FadeTime overrides it, same pattern as above.
Config.LaserFadeTime = 0.4
-- Hazard is live only while Transparency is at or below this — i.e. only
-- once the beam has mostly faded in, not during the warning fade.
Config.LaserHazardThreshold = 0.2

-- Lasers now damage rather than forfeit outright, so a player can be hit,
-- retreat, and survive — like guards, unlike every other hazard.
Config.LaserDamageFraction = 0.25 -- fraction of MaxHealth per hit
Config.LaserDamageCooldown = 0.75 -- seconds of post-hit invulnerability

-- Guards
-- Police and wanted Task 3 (2026-11-17): was 0, so guards fired and hurt nobody. Fix round 1 set the Police
-- template's DamageOverride (12); fix round 2 halved it to 6: four guards at 12 killed a robber in the open
-- in 2.3 s.
Config.GuardDamage = 6
Config.GuardFireInterval = 0.9
Config.GuardSightRange = 120
Config.GuardActivationRange = 60

-- C4 breach (replaces "both terminals -> teleport unlocked" with "both
-- terminals -> plant C4 -> countdown -> explosion -> teleport unlocked")
Config.C4CountdownDuration = 5
-- How long the cloned ExplosionEffect/ExplosionSound are left playing before
-- being destroyed (spec addendum, 2026-08-29 -- the whole C4/prompt sequence
-- is now clone-based, not toggle-based). Not tied to any asset's actual
-- length; just a fixed visual/audio window.
Config.C4ExplosionEffectDuration = 2
-- How long OpenGate's blown-apart debris parts are left physically
-- simulating before being destroyed (spec addendum, 2026-08-29). Mandatory
-- cleanup, not polish: unanchored simulating parts left indefinitely are a
-- known lag source.
Config.GateDebrisLifetime = 4
-- How much bigger the cloned ExplosionEffect's particles/emission volume
-- are made than the shared template (spec addendum, 2026-09-01). Applied to
-- the CLONE only, in C4Charge, never to the template itself -- the template
-- is a real, possibly-shared VFX prop, so scaling it in place would resize
-- it everywhere else it's used too.
Config.C4ExplosionVisualScale = 3

-- Flat amount credited per successful "Rob ATM machine" hold (spec
-- addendum, 2026-09-14) -- same one-time-per-session flat-value mechanic as
-- SlowFoods' RestaurantShared.Config.RegisterRobAmount, just a different
-- number for a different location.
Config.ATMRobAmount = 3000
-- The Bank's OWN cash registers (spec addendum, 2026-09-14, confirmed same
-- day) -- separate objects from both SlowFoods' registers and the Bank's
-- ATMs. Confirmed equal to SlowFoods' RegisterRobAmount (2000), NOT the
-- Bank ATM's 3000 -- deliberately not assumed equal to either without
-- confirmation, since the Bank's own duffel cap/session length differ from
-- both.
Config.BankRegisterRobAmount = 2000
-- Safe (spec addendum, 2026-09-16): gated behind a correct 4-digit code
-- submission, not just holding the prompt -- see Heist.Components.Safe and
-- Heist.Components.SafeCode. Confirmed: the two physical Safe.Safe props
-- share ONE session code but are independently robbable -- cracking one
-- does not mark the other robbed, so this amount can be earned twice per
-- session (once per safe) with the same code.
Config.SafeRobAmount = 5000

-- Supplies Robbery (spec addendum, 2026-09-19): SlowFoods/Gas2Go-only
-- side mechanic -- picking up a supply object starts a Carry State (see
-- SharedSystems.CarryState/SupplyObject) with no immediate payout; the
-- flat amount below is only ever granted at the single, shared Illegal
-- Supplier NPC, bypassing DuffelBag/cap entirely (spec: "a flat, direct
-- currency grant").
Config.SupplyCashOutAmount = 10000
-- How long a DROPPED (voluntary Drop, or death-while-carrying) supply
-- object stays out in the world, re-promptable, before it silently
-- disappears for the remainder of that session (spec: "a reasonable fixed
-- window, e.g. 15-30 seconds").
Config.SupplyDespawnTime = 20
-- Reuses the SAME idle animation already confirmed for Bank Clerks/
-- Cashiers (Config.BankClerkAnimations.Idle) -- the Illegal Supplier only
-- ever needs a single idle loop, never the Surprised/Scared reactions, so
-- this is its own standalone entry rather than a second three-state table.
Config.IllegalSupplierIdleAnim = "125474693216077"
-- Single shared source of truth (spec addendum, 2026-09-2X): this exact
-- wording is referenced identically from all 3 location scripts (HeistServer,
-- SlowFoodsServer, Gas2GoServer), at both the isBlocked-rejection point AND
-- the weapon-equip-trigger gate in each -- generalized to "Supplies" rather
-- than "box" so the identical string reads correctly at Gas2Go (barrels)
-- too, not just SlowFoods (boxes). Was previously duplicated as 6 separate
-- literal strings across those 3 files; centralized here so a future
-- wording change is a single-line edit again.
Config.SupplyCarryingRefusalMessage = "You need to drop the Supplies first before robbing."

-- Global notification popups (spec addendum): the human-readable phrase for
-- each location, used to compose "<Phrase> is open." and "<player> is robbing
-- <phrase>.". Lives here rather than beside either caller because BOTH sides
-- need it -- the server names the location in its broadcast, the client
-- composes the sentence -- and this module is already required by both (see
-- SupplyCarryingRefusalMessage above for the same one-source-of-truth
-- reasoning). The leading article is lower-case because the mid-sentence use
-- ("... is robbing the Bank.") is the one that cannot be derived from the
-- other; the sentence-initial use just capitalizes the first letter, which is
-- correct for all four ("The Bank is open.", "SlowFoods is open.").
Config.LocationPhrase = table.freeze({
	Bank = "the Bank",
	SlowFoods = "SlowFoods",
	Gas2Go = "the Gas Station",
	NewsStation = "the News Station",
})

-- Persistence
Config.DataStoreName = "HeistCurrency_v1"
Config.CurrencyName = "Cash"
Config.SessionLockStaleAfter = 90

-- Sound asset IDs, supplied by the project owner, stored as full rbxassetid
-- URIs (NOT bare numeric strings -- Sound.SoundId is a content reference,
-- and a bare number is silently accepted but never resolves to anything,
-- which is exactly how this went silently wrong before: see the spec doc's
-- debug addendum write-up). Every Sound instance in this system is
-- PRE-PLACED in the world/StarterCharacterScripts (spec addendum,
-- 2026-08-28) -- scripts only ever reference and :Play()/:Stop() these
-- existing objects by explicit path, never construct them, and none of them
-- read this table at runtime. It exists only so a one-off Studio setup
-- script has one place to copy an ID from -- if you ever need to
-- (re)assign a SoundId by hand, use these values verbatim, prefix and all.
Config.Sounds = {
	ButtonClick = "rbxassetid://7309103844",
	BarrierMove = "rbxassetid://101175803696900",
	AlarmLoop = "rbxassetid://7041558418",
	Explosion = "rbxassetid://138533090376585",
	BagReady = "rbxassetid://9114203006",
	DuffelFull = "rbxassetid://17208380755",
	CashOut = "rbxassetid://112283037672337",
	-- Same asset as RestaurantShared.Config.Sounds.RegisterRob (spec
	-- addendum, 2026-09-14) -- ATMRobSound itself is a STATIC pre-placed
	-- Sound instance on each ATM's attach part, same pattern as
	-- RegisterRobSound, never constructed or read from this table at
	-- runtime.
	ATMRob = "rbxassetid://111982320099998",
	-- Same asset again (spec addendum, 2026-09-14) -- the Bank's own
	-- registers' RegisterRobSound is a third static pre-placed Sound
	-- instance using this ID, same pattern as ATMRob/RegisterRob above.
	BankRegisterRob = "rbxassetid://111982320099998",
	-- Same asset a fourth time (spec addendum, 2026-09-16) -- the Safe's own
	-- SafeRobSound, same static pre-placed pattern as the three above.
	SafeRob = "rbxassetid://111982320099998",
	-- Needs a real asset ID from the project owner -- HeistShared.SoundTemplates
	-- .C4TickSound is built with SoundId = "" until this is filled in.
	C4Tick = "107785733040651",
	-- Documentation only, matching every entry above's own convention --
	-- SupplyPickupSound/SupplyDropSound are STATIC pre-placed Sound
	-- instances on each supply object's attach part, never constructed or
	-- read from this table at runtime (spec addendum, 2026-09-2X). The
	-- Illegal Supplier's own RedemptionKachingSound reuses ATMRob's exact
	-- value verbatim (the same shared kaching asset used everywhere else in
	-- this project) rather than a fifth duplicate entry here.
	SupplyPickup = "rbxassetid://106586585181583",
	SupplyDrop = "rbxassetid://5762208048",
}

Config.Tags = table.freeze({
	HeistBank = "HeistBank",
	HeistGate = "HeistGate",
	HeistAccessBarrier = "HeistAccessBarrier",
	HeistTerminal = "HeistTerminal",
	HeistTeleporter = "HeistTeleporter",
	HeistLaser = "HeistLaser",
	HeistGuardPost = "HeistGuardPost",
	HeistCoverPoint = "HeistCoverPoint",
	HeistDeathVolume = "HeistDeathVolume",
	HeistExitSpawn = "HeistExitSpawn",
	HeistZone = "HeistZone",
	HeistC4Point = "HeistC4Point",
	HeistATM = "HeistATM",
	BankRegister = "BankRegister",
	-- Safe (spec addendum, 2026-09-16): tags the two physical Safe.Safe
	-- models directly -- NOT the Workspace.Bank.Safe wrapper, which has no
	-- Highlight of its own (see Heist.Components.Safe's own boot assert).
	BankSafe = "BankSafe",
	CounterBarrier = "CounterBarrier",
	BankClerk = "BankClerk",
	Weapon = "Weapon",
	-- SlowFoods (spec addendum, 2026-09-06): a second, independent robbery
	-- location. Distinct tag names throughout, even where a Bank-equivalent
	-- tag already exists (HeistAccessBarrier, HeistZone, HeistExitSpawn) --
	-- CollectionService tags are game-wide, so a shared tag name would make
	-- BOTH locations' independent ComponentRegistry sweeps bind to EACH
	-- OTHER'S parts too (e.g. SlowFoods sealing the Bank's entrance).
	SlowFoodsZone = "SlowFoodsZone",
	SlowFoodsExitSpawn = "SlowFoodsExitSpawn",
	SlowFoodsAccessBarrier = "SlowFoodsAccessBarrier",
	Cashier = "Cashier",
	CashRegister = "CashRegister",
	NPCSpawner = "NPCSpawner",
	-- Gas2Go (spec addendum, 2026-09-14): a third, independent robbery
	-- location, following the SlowFoods style (no obby/gauntlet/C4) --
	-- distinct tag names throughout, same reasoning as the SlowFoods tags
	-- above (a shared tag name would make independent registry sweeps bind
	-- to each other's parts).
	Gas2GoZone = "Gas2GoZone",
	Gas2GoExitSpawn = "Gas2GoExitSpawn",
	Gas2GoAccessBarrier = "Gas2GoAccessBarrier",
	Gas2GoRegister = "Gas2GoRegister",
	Gas2GoATM = "Gas2GoATM",
	Gas2GoCashier = "Gas2GoCashier",
	-- Supplies Robbery (spec addendum, 2026-09-19): distinct per-location tag
	-- names, same reasoning as every other per-location pair above -- a
	-- shared tag would make SlowFoods' and Gas2Go's independent registry
	-- sweeps bind to each other's supply objects. The Illegal Supplier NPC
	-- itself needs no tag: it's a singleton, already manually placed, and
	-- referenced directly by path (workspace["Illegal Supplier"]).
	SlowFoodsSupplyBox = "SlowFoodsSupplyBox",
	Gas2GoBarrel = "Gas2GoBarrel",
})

-- Debug stays mutable so integration runs can shorten the lifecycle.
Config.Debug = { FastLifecycle = false }

local FAST = { SessionDuration = 10, CooldownDuration = 20 }

function Config.effective(key: string): number
	if Config.Debug.FastLifecycle and FAST[key] then
		return FAST[key]
	end
	return (Config :: any)[key]
end

return table.freeze(Config)
