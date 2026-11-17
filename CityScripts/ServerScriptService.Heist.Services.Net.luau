--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
Net.__index = Net

local REMOTE_NAMES = {
	"HeistState", "DuffelState", "Toast", "PlayCue", "ZoneOccupancy", "RobberySuccess",
	-- Safe (spec addendum, 2026-09-16): the FIRST client -> server signal in
	-- this whole project. Every prior remote is ToClient-only (see 6.8's
	-- tripwire below) because nothing before this needed the client to tell
	-- the server anything. A 4-digit code guess is different in kind from
	-- "currency, position, or time" (what 6.8 actually guards against): it is
	-- an unprivileged CLAIM, never trusted at face value -- Safe:TrySubmitCode
	-- re-validates session state and the real server-held code before acting,
	-- exactly the "client says it did something, server verifies everything"
	-- discipline Terminal.validate/C4Charge.validate already establish. The
	-- amount granted is still a fixed server-side constant (Config.
	-- SafeRobAmount), never client-supplied -- a wrong guess can only ever be
	-- rejected, never can it grant, alter, or reveal currency/position/time.
	"OpenSafeGui", "SubmitSafeCode",
	-- Supplies Robbery (spec addendum, 2026-09-19). DropSupplies and
	-- SubmitSupplierChoice are the 2nd/3rd client -> server remotes in this
	-- project, same justification as SubmitSafeCode's own comment above:
	-- both are unprivileged CLAIMS, never trusted at face value.
	-- DropSupplies just calls CarryState:Drop, which is already a no-op for
	-- a player who isn't actually carrying. SubmitSupplierChoice only ever
	-- means "Yes was clicked" -- the actual grant re-checks CarryState at
	-- that exact moment via CarryState:Consume, and the amount granted is
	-- still a fixed server-side constant (Config.SupplyCashOutAmount), never
	-- client-supplied. "No" needs no remote at all -- handled purely
	-- client-side.
	"DropSupplies", "SubmitSupplierChoice", "SupplierResult",
	-- LockedDoor lockpicking (spec addendum, 2026-09-2X). LockpickStopRequested
	-- is the project's 4th client -> server remote, same justification as
	-- SubmitSafeCode/DropSupplies/SubmitSupplierChoice: an unprivileged CLAIM
	-- ("stop the needle now"), never trusted at face value --
	-- LockedDoor:_onStopRequested re-derives the needle's TRUE angle from its
	-- own server-held startTime and the server's own clock, never from
	-- anything the client reports. One OPTIONAL payload value (spec
	-- correction, 2026-09-2X): the client's own locally-read
	-- workspace:GetServerTimeNow() at click-time, used only as WHEN to
	-- evaluate the still fully server-computed formula (bounded lag
	-- compensation), never as an angle or success claim -- see LockedDoor's
	-- own MAX_LATENCY_COMPENSATION comment for the full reasoning.
	"OpenLockpickGui", "LockpickStopRequested", "LockpickUpdate", "LockpickSolved",
	-- The exit/"X" button (spec addendum, 2026-09-2X): a clean, no-penalty
	-- bail-out -- the client hides its own GUI immediately and this remote
	-- just tells the server to drop its attempt state too, so a stray/late
	-- LockpickStopRequested arriving after the player already exited can't
	-- confusingly still be evaluated against a puzzle they think is closed.
	"LockpickExitRequested",
	-- MasterComputer's Criminal Word Scramble hacking chain (NewsStation
	-- follow-up pass, word-scramble revision -- replaces an earlier
	-- Connect-the-Dots design). SubmitWordScrambleGuess is this project's
	-- 5th client -> server remote, same justification as SubmitSafeCode/
	-- DropSupplies/SubmitSupplierChoice/LockpickStopRequested's own comments
	-- above: an unprivileged CLAIM ("here's my typed guess"), never trusted
	-- at face value -- MasterComputer:_onSubmitGuess re-derives correctness
	-- independently by normalizing and comparing against the real,
	-- server-held word, exactly the same discipline as Safe:TrySubmitCode/
	-- LockedDoor:_onStopRequested. The client is never sent the true word,
	-- only its scrambled letters (see OpenWordScrambleGui's own comment
	-- below).
	"OpenWordScrambleGui", "SubmitWordScrambleGuess", "WordScrambleResult", "RevealHackCode",
	-- The exit/"X" button, same clean no-penalty bail-out as
	-- LockpickExitRequested above -- clears this player's in-progress attempt
	-- server-side so a stray/late SubmitWordScrambleGuess arriving after exit
	-- can't be evaluated against a puzzle they think is closed.
	"WordScrambleExitRequested",
	-- The "Randomise Word" button: swap the current round's word for a
	-- different one, 3 times per attempt total (shared across all 3 rounds,
	-- not 3 per round). No payload -- the server owns the whole budget and
	-- re-checks it on every request, so this is only ever a REQUEST, never a
	-- claim about how many chances remain. A client that spams it past 0 is
	-- simply ignored (MasterComputer:_onRandomizeRequested no-ops), and the
	-- replacement word is chosen server-side via the same pickWord exclusion
	-- the round-advance path already uses -- the client never learns any
	-- word, only its scrambled letters.
	"RandomizeWordRequested",
	-- Global notification popups (spec addendum). Both are ToClient broadcasts
	-- carrying nothing the client could exploit: a location name it already
	-- learns from HeistState anyway, and a player name already visible on every
	-- nameplate. They exist alongside HeistState rather than being derived from
	-- it because they are EVENTS ("this just happened"), not state -- a client
	-- joining mid-session must not retroactively pop a card for a robbery that
	-- started before it connected, which is exactly what deriving them from a
	-- state snapshot would do.
	"LocationOpened", "RobberyTriggered",
	-- Heist layers 2026-11-17: the News Station broadcast hijack card, same ToClient family.
	"BroadcastHijacked",
}

-- Shared with the client so both sides compute the display from identical
-- maths. The server sends a base, a rate and a timestamp; the client fills in
-- the frames. Nothing streams, so there is no traffic while a player loots and
-- no client-reported value for the server to trust.
function Net.extrapolate(base: number, ratePerSecond: number, sinceServerTime: number, nowServerTime: number, cap: number): number
	local elapsed = math.max(0, nowServerTime - sinceServerTime)
	return math.min(cap, base + ratePerSecond * elapsed)
end

function Net.setup()
	local shared = ReplicatedStorage:FindFirstChild("HeistShared")
	assert(shared, "ReplicatedStorage.HeistShared is missing")

	local folder = shared:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end

	local remotes = {}
	for _, name in ipairs(REMOTE_NAMES) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		remotes[name] = remote
	end

	return setmetatable({ folder = folder, remotes = remotes }, Net)
end

-- location (e.g. "Bank", "SlowFoods") lets one shared remote carry every
-- independent robbery site's state; the client keys its own session table
-- by this field rather than assuming a single global session (spec
-- addendum, 2026-09-06).
function Net:BroadcastState(location: string, state: string, endsAt: number?, cooldownEndsAt: number?)
	self.remotes.HeistState:FireAllClients({
		location = location,
		state = state,
		endsAt = endsAt,
		cooldownEndsAt = cooldownEndsAt,
	})
end

function Net:SendDuffel(location: string, player, base: number, ratePerSecond: number, sinceServerTime: number, cap: number)
	self.remotes.DuffelState:FireClient(player, {
		location = location,
		base = base,
		rate = ratePerSecond,
		since = sinceServerTime,
		cap = cap,
	})
end

-- Per-player, per-location "are you physically inside this site's building
-- right now" signal (spec addendum, 2026-09-06) -- drives the client's
-- PlayerInZone AND RobberyActive gate for the heist timer. Deliberately
-- per-player (FireClient), not a broadcast: occupancy is different for
-- every player, unlike RobberyActive which is the same for everyone.
function Net:BroadcastZoneOccupancy(location: string, player, inside: boolean)
	self.remotes.ZoneOccupancy:FireClient(player, { location = location, inside = inside })
end

function Net:Toast(player, message: string)
	self.remotes.Toast:FireClient(player, message)
end

-- Server-authoritative cue trigger: tells one client to play a pre-placed,
-- per-character Sound by name (e.g. "DuffelInitiateSound"). The client never
-- decides for itself that a cue-worthy event happened; it only ever plays
-- what the server tells it to.
function Net:PlayCue(player, name: string)
	self.remotes.PlayCue:FireClient(player, name)
end

-- Fired at the exact moment a claim succeeds (spec addendum, 2026-09-09) --
-- server-authoritative TRIGGER only, no payload: the client reads its own
-- new total off the already-replicated leaderstats.Cash.Value rather than
-- trusting a number carried over the wire, so CashClaimVFX's counter tween
-- can never drift from the real, server-set balance.
function Net:NotifyRobberySuccess(player)
	self.remotes.RobberySuccess:FireClient(player)
end

-- Server -> ONE client: "show your code-entry GUI for this specific safe"
-- (fired from Safe:_onTriggered via HeistServer's onOpenGui hook). safeId is
-- an opaque integer the client echoes back unchanged in SubmitSafeCode --
-- it never carries meaning the client could exploit, only routes the reply
-- to the right Safe instance server-side.
function Net:OpenSafeGui(player, safeId: number)
	self.remotes.OpenSafeGui:FireClient(player, safeId)
end

-- The one exception to "every remote here is ToClient" -- see REMOTE_NAMES'
-- own comment for why this is safe despite 6.8. callback(player, safeId,
-- digits) -- digits is untrusted client input, validated by the caller
-- (HeistServer) before being handed to any Safe instance.
function Net:OnSafeCodeSubmitted(callback: (player: Player, safeId: number, digits: string) -> ())
	self.remotes.SubmitSafeCode.OnServerEvent:Connect(function(player, safeId, digits)
		callback(player, safeId, digits)
	end)
end

-- Supplies Robbery (spec addendum, 2026-09-19). callback(player) -- no
-- payload; the server re-derives everything it needs (whether the player
-- is actually carrying, and via what CarryState instance) itself rather
-- than trusting anything the client could send.
function Net:OnDropRequested(callback: (player: Player) -> ())
	self.remotes.DropSupplies.OnServerEvent:Connect(function(player)
		callback(player)
	end)
end

-- There is no OpenSupplierDialog remote any more. The supplier's conversation is opened
-- client-side off the NPC's own ProximityPrompt by StarterPlayerScripts.SupplierDialogueController,
-- the same way the "FPS System" place's quest NPCs do it. Only the OUTCOME still crosses the wire,
-- via SubmitSupplierChoice/SupplierResult below, and that remains server-decided.

-- The client's "Yes" click. See REMOTE_NAMES' own comment for why trusting
-- this is safe despite spec 6.8.
function Net:OnSupplierChoiceSubmitted(callback: (player: Player) -> ())
	self.remotes.SubmitSupplierChoice.OnServerEvent:Connect(function(player)
		callback(player)
	end)
end

-- Server -> ONE client: which follow-up text to show after "Yes" --
-- "sold" (the flat grant went through) or "no_supplies" (nothing to sell).
function Net:SupplierResult(player, outcome: string)
	self.remotes.SupplierResult:FireClient(player, outcome)
end

-- Server -> ONE client: start (or restart) the lockpicking GUI with a fresh
-- attempt's parameters. payload = {location, progress, zoneAngle,
-- zoneWidth, angularSpeed, startTime} -- angularSpeed/startTime let the
-- client render the needle's rotation locally every frame using the exact
-- same deterministic formula the server itself uses to validate stops, with
-- zero extra per-frame network traffic.
function Net:OpenLockpickGui(player, payload)
	self.remotes.OpenLockpickGui:FireClient(player, payload)
end

-- The client's "stop the needle" input (click/touch), plus one optional
-- lag-compensation timestamp -- see REMOTE_NAMES' own comment for why
-- trusting this is safe despite spec 6.8.
function Net:OnLockpickStopRequested(callback: (player: Player, clientClickTime: number?) -> ())
	self.remotes.LockpickStopRequested.OnServerEvent:Connect(function(player, clientClickTime)
		callback(player, clientClickTime)
	end)
end

-- Server -> ONE client: either a hit (progress advanced, zone re-randomized
-- and narrowed) or a miss (progress reduced, zone left exactly as it was) --
-- payload includes an `outcome` field ("hit"/"miss") purely for cosmetic
-- flash feedback; the client doesn't need it to know how to render the
-- needle, it just re-syncs to whatever state is given.
function Net:LockpickUpdate(player, payload)
	self.remotes.LockpickUpdate:FireClient(player, payload)
end

-- Server -> ONE client: the whole puzzle is solved (or was already solved
-- by someone else) -- close the GUI.
function Net:LockpickSolved(player)
	self.remotes.LockpickSolved:FireClient(player)
end

-- The client's "X" (exit) click. No payload -- see REMOTE_NAMES' own
-- comment for why trusting this is safe despite spec 6.8.
function Net:OnLockpickExitRequested(callback: (player: Player) -> ())
	self.remotes.LockpickExitRequested.OnServerEvent:Connect(function(player)
		callback(player)
	end)
end

-- Server -> ONE client: start (or restart) a Word Scramble round. payload =
-- {roundIndex, roundCount, scrambled} -- scrambled is the current word's
-- letters in shuffled order ONLY. The true word is never sent -- the client
-- submits its own raw guess text and MasterComputer normalizes/compares it
-- against the real, server-held word (see SubmitWordScrambleGuess's own
-- comment in REMOTE_NAMES for the full trust justification).
function Net:OpenWordScrambleGui(player, payload)
	self.remotes.OpenWordScrambleGui:FireClient(player, payload)
end

-- The client's typed guess text for the current round. See REMOTE_NAMES'
-- own comment for why trusting this is safe despite 6.8. callback(player,
-- guess) -- guess is untrusted raw client input, normalized and validated
-- by MasterComputer:_onSubmitGuess before anything is granted.
function Net:OnWordScrambleGuessSubmitted(callback: (player: Player, guess: string) -> ())
	self.remotes.SubmitWordScrambleGuess.OnServerEvent:Connect(function(player, guess)
		callback(player, guess)
	end)
end

-- Server -> ONE client: the just-submitted guess was "incorrect" (no
-- penalty -- the client leaves its GuessBox open for another try),
-- "correct" (round advanced -- server always follows with a fresh
-- OpenWordScrambleGui for the next round), or "breached" (the full 3-round
-- chain is complete -- server always follows with RevealHackCode).
function Net:WordScrambleResult(player, outcome: string)
	self.remotes.WordScrambleResult:FireClient(player, outcome)
end

-- Server -> ONE client: the full 3-round chain is complete -- reveals the
-- real, shared 4-digit hack code (the SAME session code the 3 NewsStation
-- Safes validate guesses against), visible only to this player.
function Net:RevealHackCode(player, code: string)
	self.remotes.RevealHackCode:FireClient(player, code)
end

-- The client's "X" (exit) click on the Word Scramble GUI. No payload --
-- see REMOTE_NAMES' own comment for why trusting this is safe despite 6.8.
function Net:OnWordScrambleExitRequested(callback: (player: Player) -> ())
	self.remotes.WordScrambleExitRequested.OnServerEvent:Connect(function(player)
		callback(player)
	end)
end

-- The client's "Randomise Word" click. No payload, same shape as
-- OnWordScrambleExitRequested above -- see REMOTE_NAMES' own comment for
-- why trusting this is safe despite 6.8. The remaining-chances budget is
-- server-held state; nothing the client sends can influence it.
function Net:OnRandomizeWordRequested(callback: (player: Player) -> ())
	self.remotes.RandomizeWordRequested.OnServerEvent:Connect(function(player)
		callback(player)
	end)
end

-- Server -> EVERY client: this location just re-opened after being sealed.
-- Fired from the StateChanged handler's "Idle" branch, which only ever runs
-- on a genuine rearm: BankInstance.new seeds _state = IDLE as a plain field
-- rather than through _setState, so the signal never fires at server boot and
-- no boot-time special-casing is needed here.
function Net:NotifyLocationOpened(location: string)
	self.remotes.LocationOpened:FireAllClients(location)
end

-- Server -> EVERY client: someone just successfully started a robbery here.
-- Fired only from the TryStart success branch, so a refused/debounced attempt
-- never notifies anyone.
function Net:NotifyRobberyTriggered(location: string, playerName: string)
	self.remotes.RobberyTriggered:FireAllClients({ location = location, playerName = playerName })
end

-- Server -> EVERY client: a player hijacked the News Station broadcast (heist layers 2026-11-17).
function Net:NotifyBroadcastHijacked(playerName: string)
	self.remotes.BroadcastHijacked:FireAllClients(playerName)
end

-- Tripwire for spec 6.8. A RemoteFunction would hand the client a
-- request/response channel, so its presence here must always be zero.
--
-- Note the honest limit of this check: Luau cannot enumerate a RemoteEvent's
-- OnServerEvent connections, so "no server-side listener exists" is NOT
-- provable at runtime. That half of 6.8 is held by review and by NetSpec's
-- assertion that no RemoteFunction exists anywhere under HeistShared. Do not
-- add a fake connection-counting loop here to make it look enforced.
function Net:InboundRemoteCount(): number
	local count = 0
	for _, child in ipairs(self.folder:GetChildren()) do
		if child:IsA("RemoteFunction") then
			count += 1
		end
	end
	return count
end

return Net
