-- The cash shop: six tiers, opened from the bottom-left cashShopButton.
--
-- Follows the shape WeaponaryShopController already set -- own ScreenGui, template cloned from
-- GuiTemplates, MenuFovBlur while open -- so the two menus behave identically rather than each
-- inventing an open/close feel.
--
-- No purchase logic lives here. The button sends a tier KEY to the server, which owns the id and
-- the prompt (MonetizationService). A tier with no product id configured renders disabled and never
-- fires, which is every tier in this template place today.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Monetization.Constants)
local MenuFovBlur = require(ReplicatedStorage.Modules.MenuFovBlur)
local Sounds = require(ReplicatedStorage.UI.Sounds)
local Effects = require(ReplicatedStorage.UI.Effects)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local promptRemote = ReplicatedStorage.Monetization.Remotes.PromptProductPurchase

local DISABLED_COLOR = Color3.fromHex("2A2F3C")
local DISABLED_TEXT = Color3.fromHex("8A92A6")

local gui = Instance.new("ScreenGui")
gui.Name = "CashShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local shop = guiTemplates:WaitForChild("CashShop"):Clone()
shop.Visible = false
shop.Parent = gui

local grid = shop:WaitForChild("Grid")
local tierTemplate = shop:WaitForChild("TierTemplate")
local closeButton = shop:WaitForChild("TitleBar"):WaitForChild("CloseButton")
local balanceAmount = shop.TitleBar:WaitForChild("Balance"):WaitForChild("amount") :: TextLabel

-- 1234567 -> "1,234,567". Same formatter as CashHud; duplicated rather than shared because it is
-- three lines and a shared module for it would be more moving parts than the code it saves.
local function withThousands(value: number): string
	local grouped = tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function buildTiles()
	for order, tier in Constants.CashTiers do
		local tile = tierTemplate:Clone()
		tile.Name = tier.key
		tile.LayoutOrder = order
		tile.Visible = true
		tile.Parent = grid

		tile.Amount.Text = withThousands(tier.amount)
		tile.BestValue.Visible = tier.bestValue
		-- The best-value tier also takes an acid outline, so the badge is not the only thing marking
		-- it out -- the badge alone read as decoration sitting on an otherwise identical card.
		local tileStroke = tile:FindFirstChildOfClass("UIStroke")
		if tileStroke then
			tileStroke.Color = if tier.bestValue then Color3.fromHex("CBF23C") else Color3.fromHex("2A2F3C")
			tileStroke.Thickness = if tier.bestValue then 2 else 1
		end

		local buyButton = tile.BuyButton :: TextButton
		local configured = Constants.isConfigured(tier.productId)
		if configured then
			buyButton.Text = `R$ {withThousands(tier.robux)}`
			Sounds.bind(buyButton)
			buyButton.MouseButton1Click:Connect(function()
				promptRemote:FireServer(tier.key)
			end)
		else
			-- Disabled rather than hidden: the tier is real and priced, it just has no id in this
			-- place yet, and hiding it would make the grid look broken instead of pending.
			buyButton.Text = "COMING SOON"
			buyButton.BackgroundColor3 = DISABLED_COLOR
			buyButton.TextColor3 = DISABLED_TEXT
			buyButton.AutoButtonColor = false
			buyButton.Active = false
		end
	end
end

local function bindBalance()
	local leaderstats = player:WaitForChild("leaderstats", 30)
	local cash = leaderstats and leaderstats:WaitForChild("Cash", 30)
	if not cash then
		return
	end
	balanceAmount.Text = withThousands(cash.Value)
	cash.Changed:Connect(function(value: number)
		balanceAmount.Text = withThousands(value)
	end)
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
	Panels.closed("CashShop")
end

local function open()
	if isOpen then
		close()
		return
	end
	isOpen = true
	-- Exclusive: closes whichever other panel is up, and hides the HUD behind this one.
	Panels.opened("CashShop", close)
	shop.Visible = true
	MenuFovBlur.open()
end

-- Motion + hover/click audio come from the shared module, identical to every other close X in
-- this place and in Robbery System. Nothing button-specific here on purpose.
Effects.bindClose(closeButton)
closeButton.MouseButton1Click:Connect(close)

local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local shopButton = inventoryGui:WaitForChild("cashShopButton") :: ImageButton
-- Same hover + click feedback the three original HUD buttons get from their own LocalScripts.
Sounds.bind(shopButton)
shopButton.MouseButton1Click:Connect(open)

buildTiles()
bindBalance()
