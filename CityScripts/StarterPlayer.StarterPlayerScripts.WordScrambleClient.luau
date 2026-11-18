--!strict
-- MasterComputer's Criminal Word Scramble hacking chain (NewsStation
-- follow-up pass, word-scramble revision) -- drives the pre-built
-- StarterGui.WordScrambleGui/HackCodeGui (authored once via execute_luau,
-- matching this project's own "never runtime Instance.new() for custom
-- puzzle GUIs" convention). The client only ever receives the current
-- word's SCRAMBLED letters (never the true word) and only ever submits the
-- raw guess text it was typed -- the server independently normalizes and
-- validates it (see Net.lua's own SubmitWordScrambleGuess comment for the
-- full trust justification).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("HeistShared")
local remotes = shared:WaitForChild("Remotes")
local soundTemplates = shared:WaitForChild("SoundTemplates")
-- Both GUIs register with the city's panel shell (2026-11-18): one panel at a time (a city panel opened
-- over them closes them through their own close path), the HUD and the star meter out of the way.
local Panels = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Panels"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local wordScrambleGui = playerGui:WaitForChild("WordScrambleGui")
local mainFrame = wordScrambleGui:WaitForChild("MainFrame")
local exitButton = mainFrame:WaitForChild("ExitButton")

-- Fix (polish pass): RoundLabel/ScrambledLabel/GuessBox/SubmitButton/
-- FeedbackLabel are now grouped under PuzzleContainer so "Computer
-- Breached!" can hide the entire puzzle-input portion of the GUI with a
-- single Visible toggle instead of one per element -- previously the
-- message was written into ScrambledLabel itself, cluttered alongside the
-- still-visible TextBox/button/round-counter. BreachedLabel sits OUTSIDE
-- the container (a sibling on MainFrame) so it stays visible while the
-- container is hidden.
local puzzleContainer = mainFrame:WaitForChild("PuzzleContainer")
local breachedLabel = mainFrame:WaitForChild("BreachedLabel")
local roundLabel = puzzleContainer:WaitForChild("RoundLabel")
local scrambledLabel = puzzleContainer:WaitForChild("ScrambledLabel")
local guessBox = puzzleContainer:WaitForChild("GuessBox")
local submitButton = puzzleContainer:WaitForChild("SubmitButton")
local feedbackLabel = puzzleContainer:WaitForChild("FeedbackLabel")
-- "Randomise Word" (spec addendum): swap the current round's word without
-- advancing the round. Lives INSIDE PuzzleContainer so the breach sequence's
-- single container hide takes it down with the rest of the puzzle input.
local randomizeButton = puzzleContainer:WaitForChild("RandomizeButton")
-- Image-chrome refactor (2026-09-18): the randomise pill is baked into the
-- panel slice with NO text, because its label carries a live counter. The
-- button itself is now a transparent hit target and this is what renders.
local randomizeLabel = randomizeButton:WaitForChild("Label")
local UITheme = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("UITheme"))

-- Letter tiles are built at runtime rather than baked into the chrome: WORDS
-- in MasterComputer run 5 ("THEFT") to 9 ("DETECTIVE") letters, so a fixed
-- tile row in the image would break on anything longer than five. A rounded
-- rect with a 1px stroke is something Roblox draws exactly, so nothing is
-- lost by keeping these native.
local letterRow = puzzleContainer:WaitForChild("LetterRow")
local LETTER_GAP = 12

-- The puzzle's round chip, guess box and buttons are BAKED into the panel
-- slice, so hiding PuzzleContainer only removes their live text -- the empty
-- boxes stay drawn. The breach state therefore swaps to a second slice that
-- has none of that furniture, instead of overlaying a message on top of it.
local chrome = mainFrame:WaitForChild("Chrome")

local function renderScrambled(scrambled: string)
	letterRow:ClearAllChildren()
	local n = #scrambled
	if n == 0 then return end
	local rowWidth = letterRow.AbsoluteSize.X
	if rowWidth <= 0 then rowWidth = 384 end -- first frame, before layout resolves
	local tileW = math.floor((rowWidth - LETTER_GAP * (n - 1)) / n)
	for i = 1, n do
		local tile = Instance.new("Frame")
		tile.Name = "Letter" .. i
		tile.Position = UDim2.fromOffset((i - 1) * (tileW + LETTER_GAP), 0)
		tile.Size = UDim2.fromOffset(tileW, 68)
		tile.BackgroundColor3 = UITheme.Color.raised
		tile.BorderSizePixel = 0
		tile.ZIndex = 3
		tile.Parent = letterRow
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = tile
		local stroke = Instance.new("UIStroke")
		stroke.Color = UITheme.Color.line
		stroke.Thickness = 1
		stroke.Parent = tile
		local ch = Instance.new("TextLabel")
		ch.Name = "Char"
		ch.BackgroundTransparency = 1
		ch.Size = UDim2.fromScale(1, 1)
		ch.FontFace = UITheme.Font.Display
		ch.TextSize = math.min(30, tileW - 16)
		ch.TextColor3 = UITheme.Color.white
		ch.Text = string.sub(scrambled, i, i)
		ch.ZIndex = 4
		ch.Parent = tile
	end
end

local hackCodeGui = playerGui:WaitForChild("HackCodeGui")
local hackCodeDialog = hackCodeGui:WaitForChild("DialogFrame")
local hackCodeCloseButton = hackCodeDialog:WaitForChild("CloseButton")
local hackCodeDigits = {}
for i = 1, 4 do
	hackCodeDigits[i] = hackCodeDialog:WaitForChild("Digit" .. i)
end

-- Bug fix (verification pass): these two constants used to be declared
-- FURTHER DOWN the file, AFTER shakeMainFrame's own definition below. Luau
-- resolves upvalues lexically at the point a closure is defined, so
-- shakeMainFrame was capturing undeclared GLOBALS named SHAKE_OFFSET/
-- SHAKE_DURATION (both nil), not these locals -- meaning it threw
-- "TweenInfo.new first argument expects a number for time" and never ran
-- at all, every single time, confirmed live via the Studio output log.
-- Moved above shakeMainFrame so the closure actually captures them.
local SHAKE_OFFSET = 8
local SHAKE_DURATION = 0.35

local mainFrameRestingPosition = mainFrame.Position
local mainFrameShakeTween = nil
local function shakeMainFrame()
	if mainFrameShakeTween then
		pcall(function() mainFrameShakeTween:Cancel() end)
		mainFrameShakeTween = nil
	end
	mainFrame.Position = mainFrameRestingPosition + UDim2.new(0, SHAKE_OFFSET, 0, 0)
	mainFrameShakeTween = TweenService:Create(
		mainFrame,
		TweenInfo.new(SHAKE_DURATION, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Position = mainFrameRestingPosition })
	mainFrameShakeTween:Play()
end

-- Fix (verification pass): DialogFrame.Size and every child inside it
-- (Digit1-4, Title, CloseButton) are authored with pure pixel Offsets, not
-- Scale. Tweening DialogFrame.Size from (0,0,0,0) -- the previous pass's
-- approach -- collapsed the PANEL's own background to zero pixels while
-- the Offset-positioned children kept their own fixed size and rendered
-- relative to the frame's corner regardless, producing exactly the
-- "floating digits, no visible panel" bug caught live. UIScale scales the
-- whole subtree uniformly around this Frame's own anchor with no such
-- Scale/Offset mismatch -- this is now the standard pop-in mechanism for
-- any pre-built 2D dialog panel in this project.
local hackCodeScale = hackCodeDialog:WaitForChild("UIScale")

-- Bug fix (verification pass): POP_IN_INFO had the exact same
-- lexical-scoping bug as SHAKE_OFFSET/SHAKE_DURATION above -- it was
-- declared FURTHER DOWN, after popInHackCodeGui's own definition, so the
-- closure captured an undeclared global (nil) instead of this local,
-- throwing "Argument 2 missing or nil" from TweenService:Create every
-- time, confirmed live via the Studio output log. Moved above the
-- function that uses it.
local POP_IN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

local function closeHackCodeGui()
	hackCodeGui.Enabled = false
	Panels.closed("HackCode")
end

local hackCodePopTween = nil
local function popInHackCodeGui()
	if hackCodePopTween then
		pcall(function() hackCodePopTween:Cancel() end)
		hackCodePopTween = nil
	end
	hackCodeScale.Scale = 0.1
	hackCodeGui.Enabled = true
	Panels.opened("HackCode", closeHackCodeGui)
	hackCodePopTween = TweenService:Create(hackCodeScale, POP_IN_INFO, { Scale = 1 })
	hackCodePopTween:Play()
end

-- Fix 2 / Addition 3 sequencing state: order-independent with respect to
-- WordScrambleResult("breached") vs RevealHackCode -- whichever arrives
-- first, the OTHER's handler completes the sequence correctly.
local awaitingBreachHold = false
local pendingCode: string? = nil

local function showHackCode(code: string)
	for i = 1, 4 do
		hackCodeDigits[i].Text = string.sub(code, i, i)
	end
	popInHackCodeGui()
end

-- UI-cue sounds (spec confirmed): non-positional -- cloned ONCE, here, from
-- HeistShared.SoundTemplates into SoundService, same established convention
-- as the Lockpick puzzle's own fail/success sounds.
local correctSound = soundTemplates:WaitForChild("WordScrambleCorrectSound"):Clone()
correctSound.Parent = SoundService
local incorrectSound = soundTemplates:WaitForChild("WordScrambleIncorrectSound"):Clone()
incorrectSound.Parent = SoundService

-- Polish pass: shortened from 2s to 1s per updated spec (the "2-second
-- LockPick Fail hold" this used to reference doesn't exist in the current
-- codebase -- see the prior pass's note; LockedDoor.lua's rotary-needle
-- mechanic replaced that sequential-pin system's hold entirely). 1s is
-- used directly, matching the explicit request.
local BREACH_DISPLAY_DELAY = 1 -- seconds
local BREACH_FADE_DURATION = 0.35 -- seconds -- "Computer Breached!" fades out before the code-reveal GUI pops in, so the handoff reads as an animated transition rather than an instant cut

-- The remaining-randomise budget is server-held; this is only ever the last
-- value the server told us, used to render the button and to avoid firing a
-- request the server would just ignore. It is never the authority.
local randomizesRemaining = 0

-- The pill's fill is baked into the chrome and cannot be recoloured, so the
-- disabled state is expressed by dimming the LABEL instead of the background.
local RANDOMIZE_ENABLED_COLOR = UITheme.Color.muted
local RANDOMIZE_DISABLED_COLOR = Color3.fromRGB(70, 74, 86)

local function setRandomizeEnabled(enabled: boolean)
	randomizeButton.Active = enabled
	randomizeLabel.TextColor3 = enabled and RANDOMIZE_ENABLED_COLOR or RANDOMIZE_DISABLED_COLOR
	randomizeLabel.TextTransparency = enabled and 0 or 0.45
end

local function setInputEnabled(enabled: boolean)
	guessBox.TextEditable = enabled
	submitButton.Active = enabled
	-- The randomise button follows the same input gate as the guess box --
	-- it must never be clickable during the breach sequence either -- but it
	-- additionally stays disabled once the budget is spent.
	setRandomizeEnabled(enabled and randomizesRemaining > 0)
end

local function closeWordScrambleGui()
	wordScrambleGui.Enabled = false
	guessBox.Text = ""
	feedbackLabel.Text = ""
	Panels.closed("WordScramble")
end

-- The X's path (a NEW, dedicated remote -- deliberately not LockedDoor's own LockpickExitRequested,
-- an unrelated system). Also the close UI.Panels calls when a city panel opens over the puzzle; the
-- server's exit only drops the attempt, so it is harmless during the breach hold too.
-- Declared ABOVE openRound on purpose (fix round 1): openRound hands it to UI.Panels, and a local
-- declared below a function is a nil global inside it (the same trap as POP_IN_INFO above).
local function exitWordScramble()
	remotes:WaitForChild("WordScrambleExitRequested"):FireServer()
	closeWordScrambleGui()
end

-- Single seam: every round-open, round-advance and randomise arrives as an
-- OpenWordScrambleGui payload, so the button's label and enabled state are
-- updated from here only -- deliberately not a second parallel handler that
-- could drift out of step with the round rendering.
local function openRound(payload)
	chrome.Image = UITheme.Assets.WordScramble -- back from any prior breach state
	roundLabel.Text = string.format("ROUND %d / %d", payload.roundIndex, payload.roundCount)
	renderScrambled(payload.scrambled)
	randomizesRemaining = payload.randomizesRemaining or 0
	randomizeLabel.Text = string.format("RANDOMISE WORD  \u{00B7}  %d LEFT", randomizesRemaining)
	feedbackLabel.Text = ""
	guessBox.Text = ""
	setInputEnabled(true)
	puzzleContainer.Visible = true -- undo any breach-sequence hide from a prior attempt
	breachedLabel.Visible = false
	exitButton.Visible = true
	wordScrambleGui.Enabled = true
	Panels.opened("WordScramble", exitWordScramble)
end

local submitRemote = remotes:WaitForChild("SubmitWordScrambleGuess")

local function trySubmit()
	if not guessBox.TextEditable then return end
	local guess = guessBox.Text
	if guess == "" then return end
	submitRemote:FireServer(guess)
end

submitButton.Activated:Connect(trySubmit)
guessBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then trySubmit() end
end)

remotes:WaitForChild("OpenWordScrambleGui").OnClientEvent:Connect(function(payload)
	openRound(payload)
end)

-- "incorrect": no penalty -- leave the round/word exactly as-is, just show
-- feedback and clear the box for another try. "correct": the server always
-- follows with a fresh OpenWordScrambleGui for the next round, so nothing
-- else needs to happen here beyond the cue and clearing feedback.
-- "breached": lock input, show a breach message, then hide -- the
-- read-only code-reveal GUI shows itself independently once RevealHackCode
-- arrives (fired by the server in the same instant as "breached").
remotes:WaitForChild("WordScrambleResult").OnClientEvent:Connect(function(outcome)
	if outcome == "incorrect" then
		incorrectSound:Play()
		feedbackLabel.Text = "Not a match"
		guessBox.Text = ""
		shakeMainFrame()
	elseif outcome == "correct" then
		correctSound:Play()
		feedbackLabel.Text = ""
	elseif outcome == "breached" then
		-- Fix 2 (polish pass): "Computer Breached!" now replaces the ENTIRE
		-- puzzle-input portion of the GUI (PuzzleContainer hidden as one
		-- toggle, ExitButton hidden too so it can't interrupt this short,
		-- non-interactive sequence) rather than overlaying it -- a clean,
		-- isolated message screen instead of the message cluttered together
		-- with now-irrelevant puzzle UI. Held for a fixed delay, THEN swaps
		-- to the code-reveal GUI -- never both at once. RevealHackCode's
		-- payload may already have arrived (or may arrive during the hold)
		-- -- either way it's only ACTED on once the hold completes.
		correctSound:Play()
		setInputEnabled(false)
		-- Swap to the furniture-free slice FIRST, so the message never appears
		-- on top of the baked guess box / submit pill.
		chrome.Image = UITheme.Assets.WordScrambleBreached
		puzzleContainer.Visible = false
		exitButton.Visible = false
		breachedLabel.Text = "Computer Breached!"
		breachedLabel.TextTransparency = 0
		breachedLabel.Visible = true
		awaitingBreachHold = true
		task.delay(BREACH_DISPLAY_DELAY, function()
			-- Fade the message out instead of an instant Visible=false cut,
			-- THEN swap to the code-reveal GUI. Waits for the fade's OWN
			-- duration directly (task.wait) rather than blocking on
			-- fadeTween.Completed:Wait() -- a Tween whose Completed event
			-- never fires for any reason would otherwise strand the player on
			-- this screen forever with input already disabled and no way out.
			TweenService:Create(
				breachedLabel,
				TweenInfo.new(BREACH_FADE_DURATION),
				{ TextTransparency = 1 }):Play()
			task.wait(BREACH_FADE_DURATION)
			awaitingBreachHold = false
			closeWordScrambleGui()
			if pendingCode then
				showHackCode(pendingCode)
				pendingCode = nil
			end
		end)
	end
end)

-- Fix 2 / Addition 3 (polish pass): during an active breach-hold sequence
-- (first-time completion), just cache the code -- the hold's own delay
-- callback above shows it once the "Computer Breached!" message has had
-- its own moment on screen. Otherwise (Addition 3's direct re-view path,
-- where the puzzle was skipped entirely) show it immediately, with only
-- the pop-in, no message, no delay.
remotes:WaitForChild("RevealHackCode").OnClientEvent:Connect(function(code: string)
	if awaitingBreachHold then
		pendingCode = code
		return
	end
	showHackCode(code)
end)

-- No payload, matching exitRemote's call shape below -- the server owns the
-- budget and picks the replacement word. Guarded on the button actually
-- being enabled so a click at 0 never reaches the server (which would
-- no-op anyway -- this is the courtesy half of the gate, not the
-- enforcement).
local randomizeRemote = remotes:WaitForChild("RandomizeWordRequested")
randomizeButton.Activated:Connect(function()
	if not randomizeButton.Active then return end
	if randomizesRemaining <= 0 then return end
	randomizeRemote:FireServer()
end)

exitButton.Activated:Connect(exitWordScramble)

hackCodeCloseButton.Activated:Connect(closeHackCodeGui)
