-- Quest Log panel. Mirrors WeaponaryShopController's open/close shape, including reusing the shared
-- MenuFovBlur so the shop, player card and quest log all contribute to the same reference-counted
-- FOV/blur treatment rather than each implementing their own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local questsRoot = ReplicatedStorage:WaitForChild("Quests")
local QuestConfig = require(questsRoot:WaitForChild("QuestConfig"))
local MenuFovBlur = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MenuFovBlur"))
local Effects = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Effects"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local gui = Instance.new("ScreenGui")
gui.Name = "QuestLogGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = guiTemplates:WaitForChild("QuestLog"):Clone()
panel.Visible = false
panel.Parent = gui

local closeButton = panel.TitleBar.CloseButton
local questList = panel.QuestList
-- Taken out of the list and kept as the prototype, so the list starts genuinely empty.
local entryTemplate = questList.QuestEntry:Clone()
questList.QuestEntry:Destroy()

local isOpen = false

-- Figma QuestLog palette, kept here rather than reached for through Theme because nothing in this
-- codebase requires Theme yet.
local ACCENT = Color3.fromHex("CBF23C")
local INSET = Color3.fromHex("12141A")
local DEEP = Color3.fromHex("0E1016")
local MUTED = Color3.fromHex("8A92A6")
local LINE = Color3.fromHex("2A2F3C")

local function refresh()
	-- Only Frames are cleared, which leaves the UIListLayout in place.
	for _, child in questList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for questId, quest in QuestConfig.Quests do
		local state = player:GetAttribute(QuestConfig.stateAttributeFor(questId))
		if state ~= QuestConfig.STATE_ACCEPTED and state ~= QuestConfig.STATE_READY_TO_TURN_IN then
			continue -- the log lists active quests only: never-offered and completed ones are not shown
		end

		local progress = (player:GetAttribute(QuestConfig.progressAttributeFor(questId)) :: number?) or 0
		local entry = entryTemplate:Clone()
		entry.NameLabel.Text = string.upper(quest.name)
		-- The count moved out of the description and into its own right-aligned column (Figma
		-- QuestLog), so the description no longer has "(7/10)" tacked onto the end of the sentence.
		entry.DescriptionLabel.Text = quest.description
		local progressLabel = entry:FindFirstChild("ProgressLabel")
		if progressLabel then
			progressLabel.Text = `{progress}/{quest.objectiveTarget}`
		end

		-- Claimable quests get the acid pill and an acid outline on the whole entry; active ones stay
		-- muted. This is the only visual difference between the two states in the design.
		local claimable = state == QuestConfig.STATE_READY_TO_TURN_IN
		local status = entry:FindFirstChild("Status")
		if status then
			status.BackgroundColor3 = if claimable then ACCENT else INSET
			local statusStroke = status:FindFirstChildOfClass("UIStroke")
			if statusStroke then
				statusStroke.Transparency = if claimable then 1 else 0
			end
			local statusLabel = status:FindFirstChild("Label")
			if statusLabel then
				statusLabel.Text = if claimable then "CLAIM" else "ACTIVE"
				statusLabel.TextColor3 = if claimable then DEEP else MUTED
			end
		end
		local entryStroke = entry:FindFirstChildOfClass("UIStroke")
		if entryStroke then
			entryStroke.Color = if claimable then ACCENT else LINE
		end

		entry.ProgressBar.Fill.Size = UDim2.fromScale(math.clamp(progress / quest.objectiveTarget, 0, 1), 1)
		entry.Parent = questList
	end
end

local Panels = require(game:GetService("ReplicatedStorage"):WaitForChild("UI"):WaitForChild("Panels"))
-- Forward declaration: closeLog is defined below openLog, and openLog needs to hand it to Panels.
local closeLog: () -> ()

local function openLog()
	if isOpen then
		return
	end
	isOpen = true
	-- Exclusive: closes whichever other panel is up, and hides the HUD behind this one.
	Panels.opened("QuestLog", closeLog)
	panel.Visible = true
	MenuFovBlur.open()
	refresh()
end

function closeLog()
	if not isOpen then
		return
	end
	isOpen = false
	panel.Visible = false
	MenuFovBlur.close()
	Panels.closed("QuestLog")
end

-- Motion + hover/click audio come from the shared module, identical to every other close X in
-- this place and in Robbery System. Nothing button-specific here on purpose.
Effects.bindClose(closeButton)
closeButton.MouseButton1Click:Connect(closeLog)

local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local questsButton = inventoryGui:WaitForChild("questsButton")
local badge = questsButton:WaitForChild("Badge")
local badgeCount = badge:WaitForChild("Count")

-- Counts quests finished but not yet claimed, so the button advertises a waiting reward even while
-- the log is closed. Kept separate from refresh(): the badge must stay correct whether or not the
-- panel is open, whereas rebuilding the list only matters while it is visible.
--
-- Declared above the listener below on purpose -- a closure built before this point would resolve
-- the name as a global and call nil.
local function refreshBadge()
	local ready = 0
	for questId in QuestConfig.Quests do
		if player:GetAttribute(QuestConfig.stateAttributeFor(questId)) == QuestConfig.STATE_READY_TO_TURN_IN then
			ready += 1
		end
	end
	badge.Visible = ready > 0
	badgeCount.Text = tostring(ready)
end

-- Quest state replicates as player attributes, so this one listener keeps an open log live through
-- accepting, every kill counted, and turning in -- no polling and no manual refresh.
player.AttributeChanged:Connect(function(attributeName: string)
	if not attributeName:match("^Quest_") then
		return
	end
	refreshBadge()
	if isOpen then
		refresh()
	end
end)

refreshBadge()

questsButton.MouseButton1Click:Connect(function()
	if isOpen then
		closeLog()
	else
		openLog()
	end
end)
