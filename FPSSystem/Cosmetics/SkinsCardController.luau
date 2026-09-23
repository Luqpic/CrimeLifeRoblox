--!strict
-- The Skins card: a detached panel beside the weapon shop's detail view, replacing the old in-panel
-- SkinRow + BuyStrip (see the retired SkinRowController). One chip per palette; clicking an owned
-- one asks the server to equip it and recolours the spinning preview immediately so the choice reads
-- before the round trip. Clicking a locked one either prompts the Vip pass or fires the Spraypaint
-- purchase directly -- see the change log for why the old two-step "click to reveal a buy strip,
-- click again to confirm" flow was dropped rather than moved: the price is now printed on the chip
-- itself, so the confirm step no longer has anything to disclose that a click doesn't already show.
--
-- Built natively -- Frames/UICorner/UIStroke -- to the Figma spec (iRetcvpbMMD190DJA9Mwrm, node
-- 147:6, "SLICE - SkinsCard" 240x580). No image import: Studio's asset upload is blocked in this
-- environment (see SkinRowController's old SprayIcon note for the same constraint hit earlier).
--
-- Lives in its OWN ScreenGui, ZIndexBehavior.Sibling, DisplayOrder above WeaponaryShopGui's.
-- WeaponaryShopGui is ZIndexBehavior.Global (Instance.new("ScreenGui") always is) -- under Global
-- every descendant sorts by absolute ZIndex instead of drawing with its parent, so a panel with a
-- higher ZIndex than its own children paints over its own text (this shipped twice already; see
-- Notification-Blank-Card-ZIndexBehavior.md). Flipping WeaponaryShopGui itself to Sibling was
-- considered and rejected: under Global a higher ZIndex wins regardless of tree position, so
-- flipping the whole shop's behaviour risks silently re-layering every other panel inside it. A
-- second, Sibling ScreenGui sidesteps the trap without touching the shop at all.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)
local SpraypaintConstants = require(ReplicatedStorage.Spraypaint.Constants)
local Transitions = require(ReplicatedStorage.UI.Transitions)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local equipRemote = ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest
local promptGamepass = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase
local buyRemote = ReplicatedStorage.Spraypaint.Remotes.BuySkinRequest

local CARD_SIZE = UDim2.fromOffset(240, 580)
local GAP = 20 -- between the shop panel's right edge and the card's left edge
local SLIDE_OFFSET = 40 -- how far right the card starts before tweening in

local OPEN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local STROKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local COLOR_FILL = Color3.fromHex("171A22")
local COLOR_STROKE = Color3.fromHex("2A2F3C")
local COLOR_WELL = Color3.fromHex("12141A")
local COLOR_ACCENT = Color3.fromHex("CBF23C")
local COLOR_CHIP_STROKE = Color3.fromHex("2A2E38")
local COLOR_LOCK = Color3.fromHex("8A8F9A")

-- Matches the shop's own headings (DetailName, TitleLabel) -- see FPS-Figma-1to1-Image-Export-And-
-- Font-Fix.md for why this is the live face rather than what ReplicatedStorage.UI.Theme claims
-- (Theme is dead code; nothing reads it).
local FONT_HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

local SkinsCardController = {}

-- Must match CosmeticsService.attributeFor on the server. Duplicated rather than shared because the
-- server module lives in ServerScriptService, which the client cannot require (see the identical
-- note on the retired SkinRowController).
local function attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

local function ownsVip(): boolean
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor("Vip")) == true
end

-- Mirrors CosmeticsService.ownsPalette on the server, branch for branch -- see SkinRowController's
-- original note on why this duplication is deliberate.
local function ownsPalette(palette): boolean
	if palette.source == "Vip" then
		return ownsVip()
	end
	if palette.source == "Spraypaint" then
		return player:GetAttribute(SpraypaintConstants.ownedAttributeFor(palette.key)) == true
	end
	return true
end

-- ============================================
-- BUILD (once -- the catalogue is the same for every weapon; only the equipped ring, which is per
-- weapon, and the lock/ownership state, which is per player rather than per weapon, ever change).
-- ============================================

local cardGui = Instance.new("ScreenGui")
cardGui.Name = "SkinsCardGui"
cardGui.ResetOnSpawn = false
cardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
cardGui.DisplayOrder = 6 -- above WeaponaryShopGui's 5
cardGui.IgnoreGuiInset = true
cardGui.Enabled = false
cardGui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "SkinsCard"
card.Size = CARD_SIZE
card.BackgroundColor3 = COLOR_FILL
card.BorderSizePixel = 0
card.Parent = cardGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = COLOR_STROKE
cardStroke.Thickness = 1
cardStroke.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 24)
title.Position = UDim2.fromOffset(0, 20)
title.Text = "SKINS"
title.TextColor3 = COLOR_ACCENT
title.FontFace = FONT_HEAVY
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextYAlignment = Enum.TextYAlignment.Center
title.Parent = card

local well = Instance.new("ScrollingFrame")
well.Name = "ScrollWell"
well.Position = UDim2.fromOffset(16, 62)
well.Size = UDim2.fromOffset(208, 502)
well.BackgroundColor3 = COLOR_WELL
well.BorderSizePixel = 0
well.ClipsDescendants = true
well.ScrollingDirection = Enum.ScrollingDirection.Y
well.ScrollBarThickness = 3
well.ScrollBarImageColor3 = COLOR_ACCENT
well.CanvasSize = UDim2.new(0, 0, 0, 0)
well.AutomaticCanvasSize = Enum.AutomaticSize.Y
well.Parent = card

local wellCorner = Instance.new("UICorner")
wellCorner.CornerRadius = UDim.new(0, 12)
wellCorner.Parent = well

local wellPadding = Instance.new("UIPadding")
wellPadding.PaddingTop = UDim.new(0, 10)
wellPadding.PaddingBottom = UDim.new(0, 10)
wellPadding.PaddingLeft = UDim.new(0, 10)
wellPadding.PaddingRight = UDim.new(0, 10)
wellPadding.Parent = well

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(84, 84)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = well

-- Which weapon the card is currently dressing. Held out here, not captured in a per-chip closure,
-- for the same reason WeaponaryShopController keeps currentDetailWeapon out of showDetail: the click
-- handlers below are connected exactly once, at build time, so a closure would pin whichever weapon
-- was on screen first.
local currentWeaponName: string? = nil
local currentPreviewModel: Instance? = nil

local chips: { [string]: TextButton } = {}

local function repaint()
	if not currentWeaponName then
		return
	end
	local current = player:GetAttribute(attributeFor(currentWeaponName))
	if typeof(current) ~= "string" then
		current = Palettes.DEFAULT_KEY
	end
	-- Mirrors CosmeticsService.equippedKeyFor on the server: degrades an unknown key, or a palette
	-- the player no longer owns, to Stock -- see SkinRowController's original note on why.
	local currentPalette = Palettes.byKey(current)
	if not currentPalette or not ownsPalette(currentPalette) then
		current = Palettes.DEFAULT_KEY
	end

	for key, chip in chips do
		local stroke = chip:FindFirstChildOfClass("UIStroke")
		if stroke then
			local equipped = key == current
			TweenService:Create(stroke, STROKE_TWEEN, {
				Color = equipped and COLOR_ACCENT or COLOR_CHIP_STROKE,
				Thickness = equipped and 2 or 1,
			}):Play()
		end
	end

	if currentPreviewModel then
		local ok, err = pcall(SkinApplier.applyKey, currentPreviewModel, current)
		if not ok then
			warn("[Cosmetics] failed to dress the " .. currentWeaponName .. " preview with " .. tostring(current) .. ": " .. tostring(err))
		end
	end
end

-- Re-evaluates every chip's locked visuals in place. Ownership is never cached in a click-handler
-- closure: a chip bought mid-view must equip on the very next click, not prompt for a pass or a
-- price the player has already paid.
local function refreshLocks()
	for _, palette in Palettes.list do
		local chip = chips[palette.key]
		if not chip then
			continue
		end
		local owned = ownsPalette(palette)
		chip.BackgroundTransparency = owned and 0 or 0.35
		local lock = chip:FindFirstChild("Lock")
		if lock then
			lock.Visible = not owned
		end
		local priceLabel = chip:FindFirstChild("PriceLabel")
		if priceLabel then
			priceLabel.Visible = not owned
		end
	end
end

-- A priced chip is PRIMED on the first click and only bought on the second, within ARM_WINDOW.
-- The old DetailPanel BuyStrip was a separate confirm control; this card replaced it, and without
-- something in its place a single stray click spent the price outright with no undo. That was
-- survivable at 250; the curve now reaches 4400, which is several hundred kills.
--
-- The primed state reuses the accent stroke the equipped ring uses, which is unambiguous here
-- because only an UNOWNED chip can be primed and only an OWNED one can be equipped -- the two
-- states can never appear on the same chip. The price label carrying the word CONFIRM is what
-- tells them apart at a glance.
local ARM_WINDOW = 3
local armedPalette = nil
local armedThread: thread? = nil

local function disarm()
	if armedThread then
		task.cancel(armedThread)
		armedThread = nil
	end
	local palette = armedPalette
	armedPalette = nil
	if not palette then
		return
	end
	local chip = chips[palette.key]
	if not chip then
		return
	end
	local priceLabel = chip:FindFirstChild("PriceLabel")
	if priceLabel and palette.price then
		priceLabel.Text = tostring(palette.price)
		priceLabel.TextColor3 = Color3.new(1, 1, 1)
	end
	local stroke = chip:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, STROKE_TWEEN, { Color = COLOR_CHIP_STROKE, Thickness = 1 }):Play()
	end
end

local function arm(palette)
	disarm() -- only ever one primed chip; priming a second stands the first down
	local chip = chips[palette.key]
	if not chip then
		return
	end
	armedPalette = palette
	local priceLabel = chip:FindFirstChild("PriceLabel")
	if priceLabel then
		priceLabel.Text = "CONFIRM"
		priceLabel.TextColor3 = COLOR_ACCENT
	end
	local stroke = chip:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, STROKE_TWEEN, { Color = COLOR_ACCENT, Thickness = 2 }):Play()
	end
	-- Stands itself down rather than waiting indefinitely: a chip left primed across a whole
	-- browsing session is the same accidental-purchase hazard one click later.
	armedThread = task.delay(ARM_WINDOW, disarm)
end

for index, palette in Palettes.list do
	local chip = Instance.new("TextButton")
	chip.Name = palette.key
	chip.Text = ""
	chip.AutoButtonColor = false
	chip.LayoutOrder = index
	chip.BackgroundColor3 = palette.swatch
	chip.BorderSizePixel = 0
	chip.Parent = well

	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 8)
	chipCorner.Parent = chip

	local chipStroke = Instance.new("UIStroke")
	chipStroke.Color = COLOR_CHIP_STROKE
	chipStroke.Thickness = 1
	chipStroke.Parent = chip

	-- Lock glyph, built on every chip and toggled Visible by refreshLocks -- a Vip chip shows it with
	-- no price beneath (there is nothing to disclose but the pass), a Spraypaint chip shows it with
	-- one. Free chips never lock, so theirs simply never becomes Visible.
	local lock = Instance.new("Frame")
	lock.Name = "Lock"
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.new(0.5, 0, 0.5, palette.price and -6 or 0)
	lock.Size = UDim2.fromOffset(24, 28)
	lock.Visible = false
	lock.ZIndex = 2
	lock.Parent = chip

	local shackle = Instance.new("Frame")
	shackle.Name = "Shackle"
	shackle.AnchorPoint = Vector2.new(0.5, 0)
	shackle.Position = UDim2.fromScale(0.5, 0)
	shackle.Size = UDim2.fromOffset(15, 15)
	shackle.BackgroundTransparency = 1
	shackle.ZIndex = 2
	shackle.Parent = lock

	local shackleCorner = Instance.new("UICorner")
	shackleCorner.CornerRadius = UDim.new(1, 0)
	shackleCorner.Parent = shackle

	local shackleStroke = Instance.new("UIStroke")
	shackleStroke.Color = COLOR_LOCK
	shackleStroke.Thickness = 3
	shackleStroke.Parent = shackle

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromOffset(24, 15)
	body.BackgroundColor3 = COLOR_LOCK
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = lock

	local bodyCorner = Instance.new("UICorner")
	bodyCorner.CornerRadius = UDim.new(0, 3)
	bodyCorner.Parent = body

	-- Present only on Spraypaint entries (Palettes.Palette.price is optional for exactly this
	-- reason) -- a Vip chip has nothing to print here.
	if palette.price then
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Name = "PriceLabel"
		priceLabel.BackgroundTransparency = 1
		priceLabel.Size = UDim2.new(1, 0, 0, 14)
		priceLabel.Position = UDim2.new(0, 0, 1, -16)
		priceLabel.FontFace = FONT_HEAVY
		priceLabel.TextSize = 11
		priceLabel.TextColor3 = Color3.new(1, 1, 1)
		priceLabel.TextXAlignment = Enum.TextXAlignment.Center
		priceLabel.Text = tostring(palette.price)
		priceLabel.Visible = false
		priceLabel.ZIndex = 2
		priceLabel.Parent = chip
	end

	chip.MouseButton1Click:Connect(function()
		if not currentWeaponName then
			return
		end
		-- Read ownership fresh rather than capturing it at build time: a chip bought or unlocked
		-- while this same card is open must act on what is true now, not what was true when the
		-- card was built (it is built exactly once, at module load).
		if not ownsPalette(palette) then
			if palette.source == "Vip" then
				-- MonetizationService already disables the prompt for an unconfigured pass id, so
				-- this is safe to fire before the place is published. No priming needed: the
				-- Robux prompt is itself a confirmation step, and Roblox owns that dialog.
				disarm()
				promptGamepass:FireServer("Vip")
			elseif armedPalette == palette then
				-- Second click on the primed chip: this is the purchase.
				disarm()
				buyRemote:FireServer(palette.key, currentWeaponName)
			else
				arm(palette)
			end
			return
		end
		disarm()
		equipRemote:FireServer(currentWeaponName, palette.key)
		if currentPreviewModel then
			-- Guarded the same way every other cosmetics call site is: a failed skin must cost the
			-- player a colour, never break the card.
			local ok, err = pcall(SkinApplier.applyKey, currentPreviewModel, palette.key)
			if not ok then
				warn("[Cosmetics] failed to skin " .. currentWeaponName .. " preview with " .. palette.key .. ": " .. tostring(err))
			end
		end
	end)

	chips[palette.key] = chip
end

refreshLocks()

-- One connection covering every ownership signal, rather than one per palette: AttributeChanged
-- fires with the name, so a Spraypaint skin added later needs no new wiring here. Registered once,
-- at module load, rather than per weapon: unlike the equipped ring, ownership does not depend on
-- which weapon is on screen.
player.AttributeChanged:Connect(function(name: string)
	if name == MonetizationConstants.ownedAttributeFor("Vip") or name:sub(1, 10) == "SkinOwned_" then
		refreshLocks()
		repaint()
	end
end)

-- ============================================
-- OPEN / CLOSE
-- ============================================

local isCardOpen = false

-- AbsolutePosition is always true screen-space, regardless of the source ScreenGui's own
-- IgnoreGuiInset -- but this card's ScreenGui ignores the inset (see the header note on why), so the
-- inset has to be added back onto the shop's AbsolutePosition or the card sits ~36px high. Same
-- correction UI.CashBurst already makes for the same reason.
local function targetPosition(shopFrame: GuiObject): UDim2
	local inset = GuiService:GetGuiInset()
	local pos = shopFrame.AbsolutePosition + inset
	local size = shopFrame.AbsoluteSize
	return UDim2.fromOffset(pos.X + size.X + GAP, pos.Y)
end

-- Opens the card beside `shopFrame` (the shop's own outer panel, not the detail sub-panel -- the
-- card's height matches the shop's full-open height, and "tops aligned" means aligned to that outer
-- frame). Returns a repaint function so the caller can refresh the equipped ring on attribute change
-- without reopening the card.
function SkinsCardController.open(shopFrame: GuiObject, weaponName: string, previewModel: Instance?): () -> ()
	currentWeaponName = weaponName
	currentPreviewModel = previewModel
	-- Re-targeting at another weapon must not carry a primed chip across: the player's next click
	-- would then buy against a weapon they were no longer looking at when they primed it.
	disarm()
	refreshLocks()
	repaint()

	local target = targetPosition(shopFrame)
	if isCardOpen then
		-- Already open and simply re-targeted at a different weapon -- reseat without replaying the
		-- entrance tween.
		card.Position = target
		return repaint
	end
	isCardOpen = true

	card.Position = target + UDim2.fromOffset(SLIDE_OFFSET, 0)
	Transitions.set(card, 1)
	cardGui.Enabled = true
	TweenService:Create(card, OPEN_TWEEN, { Position = target }):Play()
	Transitions.fade(card, 0, OPEN_TWEEN.Time)

	return repaint
end

function SkinsCardController.close()
	if not isCardOpen then
		return
	end
	isCardOpen = false
	currentWeaponName = nil
	currentPreviewModel = nil
	disarm()

	local target = card.Position + UDim2.fromOffset(SLIDE_OFFSET, 0)
	TweenService:Create(card, CLOSE_TWEEN, { Position = target }):Play()
	Transitions.fade(card, 1, CLOSE_TWEEN.Time, function()
		cardGui.Enabled = false
	end)
end

return SkinsCardController
