-- Hover/press motion, click audio and menu FOV+blur for every dialog in this place.
--
-- This is the counterpart to the "FPS System" place's StarterPlayerScripts.HudButtonEffects, and
-- it exists for the same stated reason: one file that drives every button identically, instead of
-- per-button scripts that drift apart. It uses the SAME shared modules as that place
-- (ReplicatedStorage.Modules.MenuFovBlur, ReplicatedStorage.UI.Sounds) and the same motion
-- constants (ReplicatedStorage.UI.Effects), so merging the two is a folder union.
--
-- ONE DELIBERATE DIFFERENCE, and why:
-- FPS System calls MenuFovBlur.open()/close() explicitly from each controller's show/hide. That
-- works there because its menus are only ever opened and closed by the player. Here they are not:
-- the lockpick GUI force-closes on death, on the session ending, and when ANOTHER player solves
-- the same door; the safe entry closes on Bank seal and on respawn; the supplier dialog closes on
-- CharacterRemoving. Threading an explicit close() through every one of those paths is exactly the
-- kind of thing that eventually misses one and strands the blur on with no source left to clear
-- it. So visibility is OBSERVED instead: whatever hides the GUI, for whatever reason, releases its
-- reference. The module and its API are unchanged -- only the trigger is -- and FPS System can
-- adopt the same observer at merge time without touching MenuFovBlur itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Effects"))
local Sounds = require(ReplicatedStorage.UI:WaitForChild("Sounds"))
local MenuFovBlur = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MenuFovBlur"))
local UITheme = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("UITheme"))
local Transitions = require(ReplicatedStorage.UI:WaitForChild("Transitions"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Bounded waits throughout: a renamed or missing element must degrade to "no effect on that one"
-- rather than yielding forever and leaving the whole HUD without audio.
local function get(parent: Instance?, name: string, timeout: number?): Instance?
	if not parent then return nil end
	return parent:WaitForChild(name, timeout or 10)
end

local function bind(button: Instance?, style: string?)
	if button and button:IsA("GuiButton") then
		Effects.bind(button, { style = style })
	end
end

-- Close buttons ask for the shared contract instead of naming a style, so this place and FPS System
-- cannot drift apart on what an X looks like or does. See Effects.bindClose.
local function bindClose(button: Instance?)
	if button and button:IsA("GuiButton") then
		Effects.bindClose(button)
	end
end

-- Invisible hit targets (the lockpick's full-panel click area, the duffel "+" which is still baked
-- into its panel) get audio only -- there is nothing drawn to move.
local function bindSoundOnly(button: Instance?)
	if button and button:IsA("GuiButton") then
		Sounds.bind(button)
	end
end

----------------------------------------------------------------- dialog buttons
-- The Illegal Supplier is absent from this file on purpose. Its conversation is no longer a
-- ScreenGui with Yes/No/X buttons -- it moved onto the DialogModule billboard engine shared with
-- the "FPS System" place (see SupplierDialogueController), whose response rows carry their own
-- hover paint and tick sounds inside DialogModule itself.

task.spawn(function()
	local upgrade = get(playerGui, "DuffelUpgradeGui")
	local f = upgrade and get(upgrade, "DialogFrame")
	bind(f and f:FindFirstChild("X2Button"), "rotate")
	bind(f and f:FindFirstChild("X4Button"), "rotate")
	bindClose(f and f:FindFirstChild("ExitButton"))
end)

task.spawn(function()
	local hack = get(playerGui, "HackCodeGui")
	local f = hack and get(hack, "DialogFrame")
	bind(f and f:FindFirstChild("CloseButton"), "rotate")
end)

task.spawn(function()
	local lock = get(playerGui, "LockpickGui")
	local t = lock and get(lock, "Track")
	bindClose(t and t:FindFirstChild("ExitButton"))
	bindSoundOnly(t and t:FindFirstChild("StopButton"))
end)

task.spawn(function()
	local ws = get(playerGui, "WordScrambleGui")
	local mf = ws and get(ws, "MainFrame")
	bindClose(mf and mf:FindFirstChild("ExitButton"))
	local pc = mf and get(mf, "PuzzleContainer")
	bind(pc and pc:FindFirstChild("SubmitButton"), "rotate")
	bind(pc and pc:FindFirstChild("RandomizeButton"), "rotate")
end)

-- HeistHUD / HeistModals are built at runtime by HeistClient, so their children appear after this
-- script starts.
task.spawn(function()
	local hud = get(playerGui, "HeistHUD", 20)
	if hud then
		bind(get(hud, "DropSuppliesButton", 20), "rotate")
		-- The "+" darkens rather than moves: it sits hard against the fill bar, so growing or
		-- tilting it would collide with the bar beside it.
		for _, location in ipairs({ "Bank", "SlowFoods", "Gas2Go", "NewsStation" }) do
			local widget = hud:FindFirstChild(location .. "Duffel")
			bind(widget and widget:FindFirstChild("UpgradeButton"), "tint")
		end
	end
	local modals = get(playerGui, "HeistModals", 20)
	local safe = modals and get(modals, "SafeCodeEntry", 20)
	bind(safe and get(safe, "Submit", 10), "rotate")
end)

-- Chrome images are re-asserted from UITheme at run time so the Studio-authored value can never
-- drift from the module. That drift is not hypothetical: after the buttons were split into their
-- own slices, StarterGui still held the OLD panel images with the buttons baked in, so every
-- dialog drew its buttons twice -- visible the moment a hover rotated one of them.
task.spawn(function()
	local PANELS = {
		{ "DuffelUpgradeGui", "DialogFrame", "Upgrade" },
		{ "HackCodeGui", "DialogFrame", "HackCode" },
		{ "LockpickGui", "Track", "Lockpick" },
		{ "WordScrambleGui", "MainFrame", "WordScramble" },
	}
	for _, spec in ipairs(PANELS) do
		local gui = get(playerGui, spec[1])
		local frame = gui and get(gui, spec[2])
		local chrome = frame and frame:FindFirstChild("Chrome")
		local want = UITheme.Assets[spec[3]]
		if chrome and want and chrome.Image ~= want then
			warn(string.format("[UiButtonEffects] %s chrome was stale (%s) -- corrected to %s",
				spec[1], chrome.Image, want))
			chrome.Image = want
		end
	end
end)

-------------------------------------------- menu FOV + blur, and ambient-HUD focus
-- One open-count drives BOTH effects: a modal dims the world AND hides the ambient HUD, so the
-- puzzle is the only thing on screen. Counted rather than boolean because modals can overlap and
-- because several of them force-close from paths they did not initiate.
local modalCount = 0
local ambient: { ScreenGui } = {}
-- City (phase 3 Task 4): the one cash readout is Custom Inventory.cashDisplay (G5), a frame inside
-- city HUD chrome that UiTransitionBinder fades by Enabled, so only its Visible is flipped here.
local cashFrame: GuiObject? = nil

local function applyFocus()
	local focused = modalCount > 0
	for _, screen in ipairs(ambient) do
		screen.Enabled = not focused
	end
	if cashFrame then cashFrame.Visible = not focused end
end

-- Disabling the whole ScreenGui (rather than each element's Visible) is deliberate: HeistClient's
-- render loop rewrites dropButton.Visible and drives slide transitions every frame, so per-element
-- hiding would be undone immediately. A disabled ScreenGui stops rendering regardless, and nothing
-- has to be restored by hand -- the loop's own state is still correct when it comes back.
task.spawn(function()
	local hud = get(playerGui, "HeistHUD", 20)
	if hud then table.insert(ambient, hud) end
	local inventory = get(playerGui, "Custom Inventory", 20)
	cashFrame = inventory and get(inventory, "cashDisplay", 20) :: GuiObject?
	-- The heist cards now go through the city's notification stack, which holds them while a modal
	-- (registered with UI.Panels) is open (2026-11-18), so there is no heist notification GUI to hide.
	-- Bound so applyFocus's plain Enabled flip below CROSS-FADES instead of cutting. No callbacks:
	-- the ambient HUD is not a modal, it never contributes to the focus count.
	for _, screen in ipairs(ambient) do
		Transitions.bindScreen(screen)
	end
	applyFocus()
end)

-- Visibility is observed through UI.Transitions rather than directly, because Transitions briefly
-- re-shows a GUI in order to play its exit animation. Watching the raw property here would see
-- that as a spurious show/hide pair and flicker the blur on every close; its onShow/onHide report
-- the LOGICAL state only.
local function watchModal(root: Instance?, kind: string)
	if not root then return end
	local release: (() -> ())? = nil
	local function onShow()
		if release then return end
		local releaseBlur = MenuFovBlur.acquire()
		modalCount += 1
		applyFocus()
		release = function()
			releaseBlur()
			modalCount = math.max(modalCount - 1, 0)
			applyFocus()
		end
	end
	local function onHide()
		if release then
			release()
			release = nil
		end
	end

	local opts = { onShow = onShow, onHide = onHide }
	if kind == "screen" then
		Transitions.bindScreen(root :: ScreenGui, opts)
		if (root :: ScreenGui).Enabled then onShow() end
	else
		Transitions.bindFrame(root :: GuiObject, opts)
		if (root :: GuiObject).Visible then onShow() end
	end
end

task.spawn(function()
	watchModal(get(playerGui, "LockpickGui"), "screen")
	watchModal(get(playerGui, "WordScrambleGui"), "screen")
	watchModal(get(playerGui, "HackCodeGui"), "screen")
	-- These two are driven by Visible on the frame, not Enabled on the ScreenGui.
	local upgrade = get(playerGui, "DuffelUpgradeGui")
	watchModal(upgrade and get(upgrade, "DialogFrame"), "frame")
	local modals = get(playerGui, "HeistModals", 20)
	watchModal(modals and get(modals, "SafeCodeEntry", 20), "frame")
end)
