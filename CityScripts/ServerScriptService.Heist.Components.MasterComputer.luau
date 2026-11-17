--!strict
-- MasterComputer: NewsStation's hacking chain, a fully server-authoritative
-- Criminal Word Scramble puzzle -- the client is shown a scrambled word and
-- submits a raw text guess; the server independently normalizes and checks
-- it against the real, server-held word, exactly the same "client's own
-- claim is never trusted outright" discipline as
-- Safe:TrySubmitCode/LockedDoor:_onStopRequested/the earlier Connect-the-
-- Dots puzzle this replaces.
local ProximityPromptService = game:GetService("ProximityPromptService")

local MasterComputer = {}
MasterComputer.__index = MasterComputer

local ROUND_COUNT = 3
-- "Randomise Word" chances per ATTEMPT -- shared across all 3 rounds
-- combined, deliberately NOT 3 fresh chances per round: spending 2 in round
-- 1 leaves only 1 for the rest of the attempt. Resets only when the player
-- exits and re-triggers, or when a new session starts. MasterComputerSpec
-- pins this explicitly -- it is the one property of this feature most
-- likely to be silently reverted by a well-meaning future change.
local RANDOMIZES_PER_ATTEMPT = 3

local WORDS = {
	"THEFT", "ALIBI", "SUSPECT", "WITNESS", "EVIDENCE", "BURGLAR", "MOTIVE",
	"ROBBERY", "DETECTIVE", "FELONY", "VERDICT", "GETAWAY", "ARREST",
	"WARRANT", "CRIMINAL", "SMUGGLER", "HOSTAGE", "RANSOM", "FRAUD",
	"FORGERY", "TRESPASS", "VANDALISM", "KIDNAP", "BRIBERY",
}

local PROMPT_ACTION_TEXT = "Hack"
local PROMPT_OBJECT_TEXT = "Master Computer"
local PROMPT_HOLD_DURATION = 1
-- Polish pass: a player who has already hacked this session sees a
-- different ActionText when the prompt becomes visible to them ("View
-- Code" instead of "Hack") -- purely cosmetic, applied via
-- ProximityPromptService.PromptShown below since ProximityPrompt.ActionText
-- is shared, non-per-player instance state.
local PROMPT_ACTION_TEXT_HACKED = "View Code"

-- Pure puzzle helpers, deliberately free of any Instance/networking state --
-- easy to unit test independently of the component lifecycle around it
-- (same discipline as LockedDoor's own needle math / the earlier Connect-
-- the-Dots generateSet/validateSubmission).

local function shuffleOnce(letters)
	for i = #letters, 2, -1 do
		local j = math.random(1, i)
		letters[i], letters[j] = letters[j], letters[i]
	end
end

-- Re-shuffles until the result differs from the original word -- Fisher-
-- Yates COULD coincidentally reproduce the input, so this guard (not just
-- running the shuffle once) is what actually guarantees a scrambled look.
local function scramble(word: string): string
	local letters = {}
	for i = 1, #word do table.insert(letters, string.sub(word, i, i)) end
	shuffleOnce(letters)
	local result = table.concat(letters)
	local guard = 0
	while result == word and guard < 20 do
		shuffleOnce(letters)
		result = table.concat(letters)
		guard += 1
	end
	return result
end

-- Picks a word not already used this attempt. At most ROUND_COUNT (3)
-- rounds plus RANDOMIZES_PER_ATTEMPT (3) discarded words = 6 of WORDS' 24
-- can ever be consumed in one attempt, so this still cannot exhaust the
-- list -- no fallback path needed for that case.
local function pickWord(usedWords): string
	local candidates = {}
	for _, w in ipairs(WORDS) do
		if not usedWords[w] then table.insert(candidates, w) end
	end
	return candidates[math.random(1, #candidates)]
end

-- Exposed for MasterComputerSpec's own direct unit testing, same "pure
-- helpers exposed for testing" precedent the earlier Connect-the-Dots
-- generateSet/validateSubmission established.
MasterComputer._scramble = scramble
MasterComputer._pickWord = pickWord

-- Identical closest-to-pivot algorithm to RobbableObject/Safe/SupplyObject/
-- LockedDoor -- this model has no PrimaryPart.
local function findAttachPart(model: Model): BasePart
	local pivotPos = model:GetPivot().Position
	local best, bestDist = nil, math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local dist = (d.Position - pivotPos).Magnitude
			if dist < bestDist then
				best, bestDist = d, dist
			end
		end
	end
	assert(best, "MasterComputer requires at least one BasePart descendant")
	return best
end

-- deps = {bank, net, onBreached?}. onBreached(player) (heist layers 2026-11-17) runs the first
-- time each player breaches in a session. Permanent, non-consumable fixture -- toggled .Enabled
-- in sync with RobberyActive, same as LockedDoor's own prompt.
function MasterComputer.new(model: Model, deps)
	assert(model and model:IsA("Model"), "MasterComputer requires a Model")
	assert(deps.bank, "MasterComputer requires bank")
	assert(deps.net, "MasterComputer requires net")

	local part = findAttachPart(model)
	model.PrimaryPart = part

	-- Pre-placed by the project owner (Fix 1, polish pass): toggled in sync
	-- with the prompt's own Enabled state -- stays on for the WHOLE session
	-- once armed, regardless of how many players have hacked it, unlike the
	-- one-shot Register/ATM/Safe highlights which disable after first use.
	local highlight = model:FindFirstChildOfClass("Highlight")
	assert(highlight, "MasterComputer requires a pre-placed Highlight descendant")
	highlight.Enabled = false -- matches RobbableObject/SupplyObject's own "off until armed" construction-time default

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MasterComputerPrompt"
	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = PROMPT_OBJECT_TEXT
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.Enabled = false
	prompt.Parent = part

	local self = setmetatable({
		model = model,
		part = part,
		prompt = prompt,
		highlight = highlight,
		bank = deps.bank,
		net = deps.net,
		onBreached = deps.onBreached,
		-- Keyed by the player value directly, NOT player.UserId -- preserves
		-- compatibility with this project's established fake-string-player
		-- test convention (an earlier build of this same component, in a
		-- different project file, keyed by UserId and broke that convention).
		_hackedBy = {},
		_attempts = {}, -- player -> {roundIndex, currentWord, usedWords, randomizesRemaining}
		_code = nil :: string?,
		_conn = nil,
		_promptShownConn = nil,
	}, MasterComputer)

	self._conn = prompt.Triggered:Connect(function(player)
		self:_onTriggered(player)
	end)
	-- ActionText nicety (polish pass, confirmed wanted): best-effort only --
	-- ProximityPrompt.ActionText has no native per-player variant, so this
	-- sets it the instant the prompt becomes visible TO a specific player,
	-- based on THEIR OWN hackedBy state. If two players approach in the same
	-- instant, one's proximity could transiently affect what the other
	-- briefly sees -- an accepted, explicitly confirmed limitation, not a
	-- bug to chase further.
	self._promptShownConn = ProximityPromptService.PromptShown:Connect(function(shownPrompt, _inputType, player)
		if shownPrompt ~= self.prompt then return end
		self.prompt.ActionText = self._hackedBy[player] and PROMPT_ACTION_TEXT_HACKED or PROMPT_ACTION_TEXT
	end)
	self.net:OnWordScrambleGuessSubmitted(function(player, guess)
		self:_onSubmitGuess(player, guess)
	end)
	self.net:OnWordScrambleExitRequested(function(player)
		self:_onExitRequested(player)
	end)
	self.net:OnRandomizeWordRequested(function(player)
		self:_onRandomizeRequested(player)
	end)

	return self
end

function MasterComputer:_onTriggered(player)
	if self.bank:GetState() ~= "Active" then return end

	-- Addition 3 (polish pass): a player who already completed the puzzle
	-- this session skips it entirely on a re-trigger -- straight to the
	-- code-reveal GUI, covering the "I forgot my code" case. No "breached"
	-- message here -- that specifically marks the moment of FIRST
	-- completion; the client notices no breach-hold is in progress and pops
	-- the reveal GUI straight in.
	if self._hackedBy[player] then
		self.net:RevealHackCode(player, self:GetCode())
		return
	end

	-- Already mid-puzzle: ignore. The GUI is modal but the world is not -- the
	-- player can still walk, so they can re-enter the prompt's radius and
	-- re-trigger it with the scramble still on screen. Without this guard that
	-- silently discards their attempt (fresh word, back to round 1,
	-- randomise budget reset) and pushes a second OpenWordScrambleGui on top of
	-- the open one. Cleared by _onExitRequested / a completed breach / a session
	-- change, so a genuinely NEW attempt after backing out still works.
	if self._attempts[player] then return end

	local word = pickWord({})
	self._attempts[player] = {
		roundIndex = 1,
		currentWord = word,
		usedWords = { [word] = true },
		randomizesRemaining = RANDOMIZES_PER_ATTEMPT,
	}
	self.net:OpenWordScrambleGui(player, {
		roundIndex = 1,
		roundCount = ROUND_COUNT,
		scrambled = scramble(word),
		randomizesRemaining = RANDOMIZES_PER_ATTEMPT,
	})
end

-- "Randomise Word": swap the current round's word for a different one
-- without advancing the round. Purely a REQUEST -- the client sends no
-- payload and the remaining-chances budget is server-held, so a client that
-- spams past 0 is simply ignored here rather than trusted. The discarded
-- word is marked used before the replacement is picked, so pickWord's
-- existing exclusion guarantees it can never resurface later in this same
-- attempt (not in a later round either).
function MasterComputer:_onRandomizeRequested(player)
	local attempt = self._attempts[player]
	if not attempt then return end
	-- Server-side backstop. The client disables its own button at 0, but
	-- that is a courtesy, not the enforcement -- same "never trust the
	-- client's own gate" discipline as _onSubmitGuess.
	if attempt.randomizesRemaining <= 0 then return end

	attempt.usedWords[attempt.currentWord] = true
	attempt.randomizesRemaining -= 1
	local nextWord = pickWord(attempt.usedWords)
	attempt.currentWord = nextWord
	attempt.usedWords[nextWord] = true

	-- roundIndex deliberately untouched -- randomising is not progress.
	self.net:OpenWordScrambleGui(player, {
		roundIndex = attempt.roundIndex,
		roundCount = ROUND_COUNT,
		scrambled = scramble(attempt.currentWord),
		randomizesRemaining = attempt.randomizesRemaining,
	})
end

-- guess is untrusted raw client input (a TextBox's .Text) -- normalized
-- (uppercased, whitespace-stripped) and compared against the server-held
-- true word; the client never independently determines correct/incorrect,
-- same discipline as Safe:TrySubmitCode/LockedDoor:_onStopRequested/the
-- earlier Connect-the-Dots validateSubmission this replaces.
function MasterComputer:_onSubmitGuess(player, guess: string?)
	local attempt = self._attempts[player]
	if not attempt then return end

	local normalized = string.upper(string.gsub(tostring(guess or ""), "%s+", ""))
	if normalized ~= attempt.currentWord then
		self.net:WordScrambleResult(player, "incorrect")
		return -- no penalty -- same word/round stays active, player keeps guessing
	end

	if attempt.roundIndex >= ROUND_COUNT then
		self._hackedBy[player] = true
		self._attempts[player] = nil
		self.net:WordScrambleResult(player, "breached")
		self.net:RevealHackCode(player, self:GetCode())
		if self.onBreached then
			local ok, err = pcall(self.onBreached, player)
			if not ok then warn("[MasterComputer] onBreached failed: " .. tostring(err)) end
		end
		return
	end

	attempt.roundIndex += 1
	local nextWord = pickWord(attempt.usedWords)
	attempt.currentWord = nextWord
	attempt.usedWords[nextWord] = true
	self.net:WordScrambleResult(player, "correct")
	-- randomizesRemaining is carried across the round boundary unchanged --
	-- the budget is per-attempt, not per-round -- and re-sent so the client's
	-- button stays accurate at every round transition, not only right after a
	-- randomise.
	self.net:OpenWordScrambleGui(player, {
		roundIndex = attempt.roundIndex,
		roundCount = ROUND_COUNT,
		scrambled = scramble(nextWord),
		randomizesRemaining = attempt.randomizesRemaining,
	})
end

function MasterComputer:_onExitRequested(player)
	self._attempts[player] = nil
end

function MasterComputer:GetCode(): string?
	return self._code
end

-- RobberyActive becomes true: fresh code, fresh per-player state, prompt
-- re-armed -- same "always fresh regardless of prior-session outcome"
-- discipline as every other per-session component in this codebase.
function MasterComputer:OnSessionStart()
	self._hackedBy = {}
	self._attempts = {}
	self._code = string.format("%04d", math.random(0, 9999))
	self.prompt.Enabled = true
	self.prompt.ActionText = PROMPT_ACTION_TEXT -- revert, in case a stray PromptShown never re-fires before the next approach
	self.highlight.Enabled = true
end

-- Session end: prompt off. hackedBy is deliberately left untouched here --
-- it stays meaningful (a player who already hacked it this session isn't
-- asked to redo the puzzle if a stray submission lands right at Cooldown)
-- until the NEXT OnSessionStart wipes it. _attempts is cleared defensively
-- -- an in-progress attempt can't outlive the session whose code it was
-- generated under.
function MasterComputer:Seal()
	self.prompt.Enabled = false
	self.highlight.Enabled = false
	self._attempts = {}
end

function MasterComputer:Forget(player)
	self._hackedBy[player] = nil
	self._attempts[player] = nil
end

function MasterComputer:Destroy()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._promptShownConn then
		self._promptShownConn:Disconnect()
		self._promptShownConn = nil
	end
end

return MasterComputer
