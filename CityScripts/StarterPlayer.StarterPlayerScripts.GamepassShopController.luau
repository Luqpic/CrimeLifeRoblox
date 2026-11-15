-- The gamepass shop, opened from the bottom-left gamepassButton. Same shell and behaviour as
-- CashShopController; the two differ only in what a tile represents and in the owned state, which
-- cash tiers do not have.
--
-- Ownership is read from the player attributes MonetizationService publishes, the same way the
-- weaponary shop reads WeaponOwned_* -- no remote round-trip to ask what the player has.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Monetization.Constants)
local MenuFovBlur = require(ReplicatedStorage.Modules.MenuFovBlur)
local Sounds = require(ReplicatedStorage.UI.Sounds)
local Effects = require(ReplicatedStorage.UI.Effects)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local promptRemote = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase

local ACCENT = Color3.fromHex("CBF23C")
local INSET = Color3.fromHex("12141A")
local DEEP = Color3.fromHex("0E1016")
local DISABLED_COLOR = Color3.fromHex("2A2F3C")
local DISABLED_TEXT = Color3.fromHex("8A92A6")

local gui = Instance.new("ScreenGui")
gui.Name = "GamepassShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local shop = guiTemplates:WaitForChild("GamepassShop"):Clone()
shop.Visible = false
shop.Parent = gui

local grid = shop:WaitForChild("Grid")
local passTemplate = shop:WaitForChild("PassTemplate")
local closeButton = shop:WaitForChild("TitleBar"):WaitForChild("CloseButton")

local function withThousands(value: number): string
	local grouped = tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function buildTiles()
	for order, pass in Constants.Gamepasses do
		local tile = passTemplate:Clone()
		tile.Name = pass.key
		tile.LayoutOrder = order
		tile.Visible = true
		tile.Parent = grid

		tile.PassName.Text = pass.name
		tile.Description.Text = pass.description

		local buyButton = tile.BuyButton :: TextButton
		local ownedAttribute = Constants.ownedAttributeFor(pass.key)
		local configured = Constants.isConfigured(pass.gamepassId)

		local function refresh()
			if not configured then
				buyButton.Text = "COMING SOON"
				buyButton.BackgroundColor3 = DISABLED_COLOR
				buyButton.TextColor3 = DISABLED_TEXT
				buyButton.AutoButtonColor = false
				buyButton.Active = false
				return
			end
			local tileStroke = tile:FindFirstChildOfClass("UIStroke")
			if player:GetAttribute(ownedAttribute) == true then
				buyButton.Text = "OWNED"
				buyButton.BackgroundColor3 = INSET
				buyButton.TextColor3 = ACCENT
				buyButton.AutoButtonColor = false
				buyButton.Active = false
				-- Highlight the whole card, not just the button: scanning the grid for what you already
				-- own should not mean reading six button labels.
				if tileStroke then
					tileStroke.Color = ACCENT
					tileStroke.Thickness = 2
				end
			else
				buyButton.Text = `R$ {withThousands(pass.robux)}`
				buyButton.BackgroundColor3 = ACCENT
				buyButton.TextColor3 = DEEP
				buyButton.AutoButtonColor = true
				if tileStroke then
					tileStroke.Color = Color3.fromHex("2A2F3C")
					tileStroke.Thickness = 1
				end
				buyButton.Active = true
			end
		end

		refresh()
		-- Re-render on the attribute rather than on the purchase prompt closing: the attribute is
		-- what the server actually decided, and it also covers a pass granted by any other path.
		player:GetAttributeChangedSignal(ownedAttribute):Connect(refresh)

		Sounds.bind(buyButton)
		buyButton.MouseButton1Click:Connect(function()
			if not buyButton.Active then
				return
			end
			promptRemote:FireServer(pass.key)
		end)
	end
end

local Panels = require(game:GetService("ReplicatedStorage"):WaitForChild("UI"):WaitForChild("Panels"))

local isOpen = false

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	shop.Visible = false
	MenuFovBlur.close()
	Panels.closed("GamepassShop")
end

local function open()
	if isOpen then
		close()
		return
	end
	isOpen = true
	-- Exclusive: closes whichever other panel is up, and hides the HUD behind this one.
	Panels.opened("GamepassShop", close)
	shop.Visible = true
	MenuFovBlur.open()
end

-- Motion + hover/click audio come from the shared module, identical to every other close X in
-- this place and in Robbery System. Nothing button-specific here on purpose.
Effects.bindClose(closeButton)
closeButton.MouseButton1Click:Connect(close)

local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local shopButton = inventoryGui:WaitForChild("gamepassButton") :: ImageButton
-- Same hover + click feedback the three original HUD buttons get from their own LocalScripts.
Sounds.bind(shopButton)
shopButton.MouseButton1Click:Connect(open)

buildTiles()
