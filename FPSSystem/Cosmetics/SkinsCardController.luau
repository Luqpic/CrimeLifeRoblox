--!strict
-- The Skins card: a detached panel beside the weapon shop's detail view, replacing the old in-panel
-- SkinRow + BuyStrip (see the retired SkinRowController). One chip per palette; clicking an owned
-- one asks the server to equip it and recolours the spinning preview immediately so the choice reads
-- before the round trip. Clicking a locked one PREVIEWS it on the 3D model, and clicking that same
-- chip again buys it -- see the note above paintChip for why a purchase takes two clicks.
--
-- Built natively -- Frames/UICorner/UIStroke -- to the Figma spec (iRetcvpbMMD190DJA9Mwrm, node
-- 147:6, "SLICE - SkinsCard" 240x580). The only image is the spray-can icon beside each
-- price (SpraypaintConstants.ICON_ASSET_ID).
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
local SoundService = game:GetService("SoundService")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)
local SpraypaintConstants = require(ReplicatedStorage.Spraypaint.Constants)
local Sounds = require(ReplicatedStorage.UI.Sounds)
local CashBurst = require(ReplicatedStorage.UI.CashBurst)
local Transitions = require(ReplicatedStorage.UI.Transitions)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local equipRemote = ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest
local promptGamepass = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase
local buyRemote = ReplicatedStorage.Spraypaint.Remotes.BuySkinRequest

local CARD_SIZE = UDim2.fromOffset(240, 580)
local GAP = 20 -- between the shop panel's right edge and the card's left edge
local SLIDE_OFFSET = 40 -- how far right the card starts before tweening in

-- How much wider WeaponaryShopController's responsive-scale formula must treat the shop as while
-- this card is open. ONE card footprint, not two: the shop slides left by half of it (SHOP_SHIFT
-- below) so the shop and the card sit centred TOGETHER, and a centred pair of width
-- shop + GAP + card is exactly what that symmetric fit formula measures.
--
-- The previous version kept the shop centred on its own and reserved the card's overhang on BOTH
-- sides, which shrank the shop far further than the card needed -- the "click a weapon and it
-- suddenly becomes small" the user reported. At the user's ~1283-point viewport the pair
-- (920 + 20 + 240 = 1180) now fits at full scale, so the shop does not shrink there at all; it only
-- scales down on a viewport genuinely too narrow for both.
--
-- SLIDE_OFFSET is deliberately not reserved: the card is fully transparent at the start of its
-- slide-in and the end of its slide-out, so the distance it travels past its resting spot is never
-- visible.
local RESERVED_WIDTH = CARD_SIZE.X.Offset + GAP

local OPEN_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local STROKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local COLOR_FILL = Color3.fromHex("171A22")
local COLOR_STROKE = Color3.fromHex("2A2F3C")
local COLOR_WELL = Color3.fromHex("12141A")
local COLOR_ACCENT = Color3.fromHex("CBF23C")
local COLOR_CHIP_STROKE = Color3.fromHex("2A2E38")
local COLOR_LOCK = Color3.fromHex("8A8F9A")
local COLOR_DENIED = Color3.fromHex("FF4B4B") -- the shop's own DENIED_COLOR
local HOVER_EXTRA_THICKNESS = 2 -- the weapon cards' StrokeHover adds the same
-- The purchase burst throws spray cans instead of coins, so a skin bought with Spraypaint does not
-- read as a Cash spend. Tinted accent because the icon is white (see FPS-Weaponry-Category-Icons.md).
local SPRAY_BURST = { image = SpraypaintConstants.ICON_ASSET_ID, color = COLOR_ACCENT, size = 30 }

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

-- This card's own responsive scale -- mirrors the exact ResponsiveScale-on-a-ScreenGui pattern
-- WeaponaryShopController (and, previously, UIScaleController) already use elsewhere in this game.
-- Verified empirically (temporary Edit-mode instances, then discarded) that a UIScale parented to a
-- ScreenGui multiplies every descendant's Offset Size AND Position by its Scale, using the
-- ScreenGui's own origin as the fixed reference point -- which is exactly why targetPosition below
-- divides its computed absolute pixel target back down by scaleRatio before assigning it.
local cardScale = Instance.new("UIScale")
cardScale.Name = "ResponsiveScale"
cardScale.Parent = cardGui

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

-- Which palette is equipped on the weapon on screen, degraded to Stock for an unknown key or one the
-- player no longer owns -- mirrors CosmeticsService.equippedKeyFor on the server (see
-- SkinRowController's original note on why).
local function equippedKey(): string
	if not currentWeaponName then
		return Palettes.DEFAULT_KEY
	end
	local current = player:GetAttribute(attributeFor(currentWeaponName))
	local palette = if typeof(current) == "string" then Palettes.byKey(current) else nil
	if not palette or not ownsPalette(palette) then
		return Palettes.DEFAULT_KEY
	end
	return palette.key
end

-- A locked chip is PREVIEWED on the first click and only bought on the second. The preview dresses
-- the spinning 3D model in that palette so the player can judge a skin before paying for it, and the
-- second click on the same chip is the purchase. So one stray click only ever shows a colour -- it
-- can never spend up to 8200 -- and the step before buying now does something useful.
--
-- No timeout. A preview stays up until the player picks another chip, goes BACK, closes the shop, or
-- the card is re-targeted at another weapon. The old primed state timed out after 3s only because it
-- had nothing to show; a preview that snapped away while the player was still looking at it would be
-- worse than no preview at all.
local previewPalette = nil
local hoveredKey: string? = nil
-- Palette keys this card has asked the server to sell, so the burst and purchase sound play only for
-- a purchase made here, not for ownership arriving any other way (a restored profile, a grant).
local awaitingBurst: { [string]: boolean } = {}

-- The chip's one UIStroke carries three states -- equipped, previewed, hovered -- so ONE function owns
-- it. Separate tweens for each (the equipped ring, the preview ring, a hover thickening) would each
-- overwrite the others mid-flight. Equipped and previewed both draw the accent ring, which cannot be
-- ambiguous: only an OWNED chip can be equipped and only an UNOWNED one previewed. Hover adds +2 on
-- top of whichever base applies, as the weapon cards' StrokeHover does.
local function paintChip(key: string, equipped: string)
	local chip = chips[key]
	local stroke = chip and chip:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end
	local ringed = key == equipped or (previewPalette ~= nil and previewPalette.key == key)
	local thickness = (if ringed then 2 else 1) + (if key == hoveredKey then HOVER_EXTRA_THICKNESS else 0)
	TweenService:Create(stroke, STROKE_TWEEN, {
		Color = if ringed then COLOR_ACCENT else COLOR_CHIP_STROKE,
		Thickness = thickness,
	}):Play()
end

local function paintAllChips()
	local equipped = equippedKey()
	for key in chips do
		paintChip(key, equipped)
	end
end

-- The price row reads "<icon> 1500" at rest and "<icon> BUY 1500" in accent while that chip is being
-- previewed, cueing the second click.
local function paintPrice(palette)
	local chip = chips[palette.key]
	local price = chip and chip:FindFirstChild("PriceLabel")
	if not price or not palette.price then
		return
	end
	local previewing = previewPalette == palette
	local color = if previewing then COLOR_ACCENT else Color3.new(1, 1, 1)
	local amount = price:FindFirstChild("Amount")
	if amount and amount:IsA("TextLabel") then
		amount.Text = if previewing then "BUY " .. palette.price else tostring(palette.price)
		amount.TextColor3 = color
	end
	local icon = price:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		icon.ImageColor3 = color
	end
end

-- Dresses the spinning model in the previewed palette if there is one, else in what is equipped.
-- Guarded the same way every other cosmetics call site is: a failed skin must cost the player a
-- colour, never break the card.
local function dressPreview()
	if not currentPreviewModel then
		return
	end
	local key = if previewPalette then previewPalette.key else equippedKey()
	local ok, err = pcall(SkinApplier.applyKey, currentPreviewModel, key)
	if not ok then
		warn("[Cosmetics] failed to dress the " .. tostring(currentWeaponName) .. " preview with " .. key .. ": " .. tostring(err))
	end
end

local function repaint()
	if not currentWeaponName then
		return
	end
	-- A preview that has become the equipped skin -- the purchase went through and the server
	-- auto-equipped it -- is no longer a preview. Cleared only once the equip has actually landed, so
	-- the model does not flash back to the old skin in the gap between ownership replicating and the
	-- equip replicating.
	if previewPalette and equippedKey() == previewPalette.key then
		previewPalette = nil
	end
	paintAllChips()
	dressPreview()
end

local function clearPreview()
	local palette = previewPalette
	if not palette then
		return
	end
	previewPalette = nil
	paintPrice(palette)
	paintAllChips()
	dressPreview()
end

local function preview(palette)
	local previous = previewPalette
	previewPalette = palette
	if previous and previous ~= palette then
		paintPrice(previous)
	end
	paintPrice(palette)
	paintAllChips()
	dressPreview()
end

-- Refused purchase, the same feedback the weapon BUY button's denyAction gives: the denied tone, and
-- a red flash that settles back. On a chip it is the OUTLINE that turns red, not the fill -- the fill
-- is the palette's own colour, and turning it red would show the player a skin that does not exist.
local function denyChip(palette)
	Sounds.denied():Play()
	local chip = chips[palette.key]
	local stroke = chip and chip:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end
	local toRed = TweenService:Create(stroke, TweenInfo.new(0.12), { Color = COLOR_DENIED, Thickness = 3 })
	toRed.Completed:Connect(function()
		task.delay(0.25, function()
			paintChip(palette.key, equippedKey())
		end)
	end)
	toRed:Play()
end

-- Re-evaluates every chip's locked visuals in place. Ownership is never cached in a click-handler
-- closure: a chip bought mid-view must equip on the very next click, not ask for a price the player
-- has already paid.
local function refreshLocks()
	for _, palette in Palettes.list do
		local chip = chips[palette.key]
		if not chip then
			continue
		end
		local owned = ownsPalette(palette)
		chip.BackgroundTransparency = if owned then 0 else 0.35
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

	-- Hover: +2 on the outline and the shared hover tone, as the weapon cards do (see StrokeHover on the
	-- WeaponCard template). Routed through paintChip, which owns this stroke.
	chip.MouseEnter:Connect(function()
		hoveredKey = palette.key
		Sounds.hover():Play()
		paintChip(palette.key, equippedKey())
	end)
	chip.MouseLeave:Connect(function()
		if hoveredKey == palette.key then
			hoveredKey = nil
		end
		paintChip(palette.key, equippedKey())
	end)

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

	-- Present only on priced entries (Palettes.Palette.price is optional). The spray-can icon sits
	-- beside the figure so it reads as Spraypaint rather than Cash; a horizontal list keeps the pair
	-- centred however wide the text is ("500" or "BUY 8200").
	if palette.price then
		local price = Instance.new("Frame")
		price.Name = "PriceLabel"
		price.BackgroundTransparency = 1
		price.Size = UDim2.new(1, 0, 0, 14)
		price.Position = UDim2.new(0, 0, 1, -16)
		price.Visible = false
		price.ZIndex = 2
		price.Parent = chip

		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.Padding = UDim.new(0, 3)
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Parent = price

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(11, 11)
		icon.Image = SpraypaintConstants.ICON_ASSET_ID
		icon.ImageColor3 = Color3.new(1, 1, 1)
		icon.LayoutOrder = 1
		icon.ZIndex = 2
		icon.Parent = price

		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.BackgroundTransparency = 1
		amount.AutomaticSize = Enum.AutomaticSize.X
		amount.Size = UDim2.fromOffset(0, 14)
		amount.FontFace = FONT_HEAVY
		amount.TextSize = 11
		amount.TextColor3 = Color3.new(1, 1, 1)
		amount.Text = tostring(palette.price)
		amount.LayoutOrder = 2
		amount.ZIndex = 2
		amount.Parent = price
	end

	chip.MouseButton1Click:Connect(function()
		if not currentWeaponName then
			return
		end
		-- Ownership is read fresh rather than captured at build time: a chip bought while this same
		-- card is open must act on what is true now, not on what was true when the card was built.
		if not ownsPalette(palette) then
			if palette.source == "Vip" then
				-- Unused while Vip is on hold (no palette carries this source); kept so restoring Vip is
				-- a data change. The Robux prompt is itself the confirmation step, and Roblox owns it.
				clearPreview()
				Sounds.click():Play()
				promptGamepass:FireServer("Vip")
			elseif previewPalette == palette then
				-- Second click on the previewed chip: the purchase. Affordability is checked here purely
				-- as feedback -- the server still validates every purchase, so this cannot be used to
				-- buy anything.
				local balance = player:GetAttribute(SpraypaintConstants.ATTRIBUTE)
				if typeof(balance) ~= "number" or balance < palette.price then
					denyChip(palette)
					return
				end
				Sounds.click():Play()
				awaitingBurst[palette.key] = true
				buyRemote:FireServer(palette.key, currentWeaponName)
			else
				Sounds.click():Play()
				preview(palette)
			end
			return
		end
		Sounds.click():Play()
		clearPreview()
		equipRemote:FireServer(currentWeaponName, palette.key)
		if currentPreviewModel then
			-- Recolours the model before the round trip so the choice reads immediately.
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
		-- A purchase this card fired has landed: spray cans burst out of the chip that bought it, the
		-- Spraypaint counterpart of the weapon shop's coin burst. Keyed on the replicated ownership
		-- flag, as the weapon shop keys its burst on WeaponOwned_, so it plays only once the server has
		-- actually charged -- never on a click the server went on to refuse.
		for key in awaitingBurst do
			if name == SpraypaintConstants.ownedAttributeFor(key) and player:GetAttribute(name) == true then
				awaitingBurst[key] = nil
				local palette = Palettes.byKey(key)
				local chip = chips[key]
				local purchaseSound = SoundService:FindFirstChild("WeaponPurchaseSound")
				if purchaseSound and purchaseSound:IsA("Sound") then
					purchaseSound:Play()
				end
				if chip and palette then
					CashBurst.burstFrom(chip, palette.price, SPRAY_BURST)
				end
			end
		end
		refreshLocks()
		repaint()
	end
end)

-- ============================================
-- OPEN / CLOSE
-- ============================================

local isCardOpen = false

-- Live only while the card is open: re-seats the card whenever the shop panel itself moves or
-- resizes. This is the actual fix -- the shop's AbsolutePosition/AbsoluteSize change on a viewport
-- resize (and now on the shop's own scale shrinking to make room, see WeaponaryShopController), and
-- targetPosition used to be applied exactly once, at open(), with nothing re-running it. Both
-- "not sticky" and "no visible tween" were that same one cause: the pair never fit the viewport, not
-- a missing call site (open()/close() were already wired correctly). Disconnected on close.
local shopPositionConnection: RBXScriptConnection? = nil
local shopSizeConnection: RBXScriptConnection? = nil

-- AbsolutePosition is always true screen-space, regardless of the source ScreenGui's own
-- IgnoreGuiInset -- but this card's ScreenGui ignores the inset (see the header note on why), so the
-- inset has to be added back onto the shop's AbsolutePosition or the card sits ~36px high. Same
-- correction UI.CashBurst already makes for the same reason.
--
-- `scaleRatio` scales GAP along with everything else this card renders (see cardScale above), so the
-- gap does not visually dominate once the pair has shrunk to fit a narrow viewport. The result is
-- divided back down by scaleRatio because cardGui's own UIScale will multiply this Position's Offset
-- by that same scaleRatio again when it renders -- see cardScale's comment for why.
local function targetPosition(shopFrame: GuiObject, scaleRatio: number): UDim2
	local inset = GuiService:GetGuiInset()
	local pos = shopFrame.AbsolutePosition + inset
	local size = shopFrame.AbsoluteSize
	local absoluteX = pos.X + size.X + GAP * scaleRatio
	local absoluteY = pos.Y
	return UDim2.fromOffset(absoluteX / scaleRatio, absoluteY / scaleRatio)
end

-- The shop's current scale, recovered by measurement rather than by reaching into
-- WeaponaryShopController's own UIScale instance: shopFrame.AbsoluteSize.Y is the shop's REAL
-- rendered height, already carrying whatever scale WeaponaryShopController's ResponsiveScale is
-- currently applying, and CARD_SIZE.Y.Offset (580) is the shop's own authored full-open height --
-- the two are the same authored value by design (see the header note on "tops aligned"). Reading the
-- resulting property back this way is what the project's own rule (verify the result, not the
-- arithmetic) asks for here.
local function currentScaleRatio(shopFrame: GuiObject): number
	return shopFrame.AbsoluteSize.Y / CARD_SIZE.Y.Offset
end

-- The card's slide is an OFFSET from where the shop says the card should sit, not a tween of the
-- card's own Position. The card is glued to the shop (reseat on every shop move), and the shop now
-- slides left to make room at the same moment the card slides in -- a tween on card.Position would
-- be overwritten by that glue on the first frame of the shop's slide, and the card would just
-- appear. Tweening this value instead makes the two motions add: the card rides with the shop AND
-- slides in relative to it, every frame.
local slideValue = Instance.new("NumberValue")
slideValue.Name = "SkinsCardSlide"
local trackedShop: GuiObject? = nil

-- Re-seats the card against `shopFrame`'s CURRENT, already-measured geometry, plus whatever
-- distance its slide still has to travel. Runs on every shop move and resize, and on every frame
-- of the card's own slide.
local function reseat(shopFrame: GuiObject)
	local scaleRatio = currentScaleRatio(shopFrame)
	cardScale.Scale = scaleRatio
	card.Position = targetPosition(shopFrame, scaleRatio) + UDim2.fromOffset(slideValue.Value, 0)
end

slideValue.Changed:Connect(function()
	if trackedShop then
		reseat(trackedShop)
	end
end)

local function untrack()
	trackedShop = nil
	if shopPositionConnection then
		shopPositionConnection:Disconnect()
		shopPositionConnection = nil
	end
	if shopSizeConnection then
		shopSizeConnection:Disconnect()
		shopSizeConnection = nil
	end
end

-- Kept live through the CLOSE animation as well as while open. On BACK the shop slides right to
-- re-centre while the card slides out, and a card that stopped tracking the moment close began
-- would be left standing still for the shop to slide across.
local function track(shopFrame: GuiObject)
	untrack()
	trackedShop = shopFrame
	shopPositionConnection = shopFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		reseat(shopFrame)
	end)
	shopSizeConnection = shopFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		reseat(shopFrame)
	end)
end

-- Opens the card beside `shopFrame` (the shop's own outer panel, not the detail sub-panel -- the
-- card's height matches the shop's full-open height, and "tops aligned" means aligned to that outer
-- frame). Returns a repaint function so the caller can refresh the equipped ring on attribute change
-- without reopening the card.
function SkinsCardController.open(shopFrame: GuiObject, weaponName: string, previewModel: Instance?): () -> ()
	currentWeaponName = weaponName
	currentPreviewModel = previewModel
	-- Re-targeting at another weapon drops any preview: the next click would otherwise buy against a
	-- weapon the player was no longer looking at when they started previewing.
	clearPreview()
	refreshLocks()
	repaint()

	if isCardOpen then
		-- Already open and simply re-targeted at a different weapon -- reseat without replaying the
		-- entrance.
		reseat(shopFrame)
		return repaint
	end
	isCardOpen = true

	track(shopFrame)
	slideValue.Value = SLIDE_OFFSET
	reseat(shopFrame)
	Transitions.set(card, 1)
	cardGui.Enabled = true
	TweenService:Create(slideValue, OPEN_TWEEN, { Value = 0 }):Play()
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
	hoveredKey = nil -- a pointer still on a chip as the card closes never gets MouseLeave
	clearPreview()

	TweenService:Create(slideValue, CLOSE_TWEEN, { Value = SLIDE_OFFSET }):Play()
	Transitions.fade(card, 1, CLOSE_TWEEN.Time, function()
		-- A weapon clicked again before this fade finished has already reopened the card; leave it.
		if isCardOpen then
			return
		end
		untrack()
		cardGui.Enabled = false
	end)
end

-- How far WeaponaryShopController slides the shop left while the card is open, in the shop's own
-- unscaled units (its ScreenGui's UIScale multiplies Position offsets exactly as it multiplies
-- sizes). Half the card's footprint, so the shop and the card sit centred as one unit. The tweens
-- are exported so the shop's slide shares the card's timing and easing and the two read as one
-- motion.
SkinsCardController.SHOP_SHIFT = (CARD_SIZE.X.Offset + GAP) / 2
SkinsCardController.OPEN_TWEEN = OPEN_TWEEN
SkinsCardController.CLOSE_TWEEN = CLOSE_TWEEN
SkinsCardController.RESERVED_WIDTH = RESERVED_WIDTH

return SkinsCardController
