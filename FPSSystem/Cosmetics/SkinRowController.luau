-- The skins row under the weapon detail panel. One chip per palette; clicking one asks the server to
-- equip it and recolours the spinning preview immediately so the choice reads before the round trip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)

local player = Players.LocalPlayer
local equipRemote = ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest
local promptGamepass = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase

local STROKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACCENT_HOVER_TRANSPARENCY = 0.6

local SkinRowController = {}

-- Must match CosmeticsService.attributeFor on the server. Duplicated rather than shared because the
-- server module lives in ServerScriptService, which the client cannot require.
local function attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

local function ownsVip(): boolean
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor("Vip")) == true
end

-- Builds the chips for one weapon. Returns a repaint function so the caller can refresh the equipped
-- outline on attribute change without rebuilding the row.
function SkinRowController.build(
	row: ScrollingFrame,
	chipTemplate: ImageButton,
	weaponName: string,
	previewModel: Instance?
): () -> ()
	for _, child in row:GetChildren() do
		if child:IsA("ImageButton") and child ~= chipTemplate then
			child:Destroy()
		end
	end

	local chips: { [string]: ImageButton } = {}
	local equippedKey: string? = nil

	local function repaint()
		local current = player:GetAttribute(attributeFor(weaponName))
		if typeof(current) ~= "string" then
			current = Palettes.DEFAULT_KEY
		end
		equippedKey = current
		for key, chip in chips do
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = key == current and 0 or 1 }):Play()
			end
		end
	end

	for index, palette in Palettes.list do
		local locked = palette.source == "Vip" and not ownsVip()
		local chip = chipTemplate:Clone()
		chip.Name = palette.key
		chip.Visible = true
		chip.LayoutOrder = index
		chip.Swatch.BackgroundColor3 = palette.swatch
		chip.Swatch.BackgroundTransparency = locked and 0.65 or 0
		chip.Lock.Visible = locked
		chip.Parent = row
		chips[palette.key] = chip

		local stroke = chip:FindFirstChildOfClass("UIStroke")

		chip.MouseEnter:Connect(function()
			if stroke and palette.key ~= equippedKey then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = ACCENT_HOVER_TRANSPARENCY }):Play()
			end
		end)
		chip.MouseLeave:Connect(function()
			if stroke and palette.key ~= equippedKey then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = 1 }):Play()
			end
		end)

		chip.MouseButton1Click:Connect(function()
			if locked then
				-- MonetizationService already disables the prompt for an unconfigured pass id, so
				-- this is safe to fire before the place is published.
				promptGamepass:FireServer("Vip")
				return
			end
			equipRemote:FireServer(weaponName, palette.key)
			if previewModel then
				SkinApplier.applyKey(previewModel, palette.key)
			end
		end)
	end

	repaint()
	return repaint
end

return SkinRowController
