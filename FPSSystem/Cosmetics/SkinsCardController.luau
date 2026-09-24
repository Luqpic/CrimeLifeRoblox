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

-- How much wider WeaponaryShopController's own responsive-scale formula must pretend the shop is,
-- to leave room for this card. Doubled, not just CARD_SIZE.X + GAP + SLIDE_OFFSET: the shop is
-- centre-anchored (AnchorPoint 0.5, 0.5), so a symmetric "does WIDTH fit inside VIEWPORT" formula
-- only ever counts HALF the shop's width against each side of the viewport -- but this card hangs
-- entirely off the shop's RIGHT edge, so the true right-side budget is halfShopWidth + GAP + CARD
-- width, and only DOUBLING that one-sided overhang and adding it to the shop's full width
-- reproduces the real (asymmetric) constraint inside the same symmetric formula. See
-- WeaponaryShopController's ResponsiveScale for the other half of this.
--
-- SLIDE_OFFSET is folded in too, not just the card's resting footprint: the entrance tween's START
-- position sits SLIDE_OFFSET further right than where the card settles, and the brief is explicit
-- that BOTH tween endpoints must land inside the viewport -- budgeting only for the resting position
-- left just ~5px of margin for the slide overshoot at one tested viewport (1120x719), which is not a
-- margin, it's a coincidence. Reserving room for the slide's widest moment up front guarantees both
-- endpoints fit at any viewport size, not just the one that happened to be measured.
local RESERVED_WIDTH = 2 * (CARD_SIZE.X.Offset + GAP + SLIDE_OFFSET)

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

-- Re-seats the card against `shopFrame`'s CURRENT, already-measured geometry -- position and the
-- scale that keeps its own chips/text visually matched to whatever size the shop is presently
-- rendering at. Called once at open() and on every AbsolutePosition/AbsoluteSize change afterwards.
local function reseat(shopFrame: GuiObject)
	local scaleRatio = currentScaleRatio(shopFrame)
	cardScale.Scale = scaleRatio
	card.Position = targetPosition(shopFrame, scaleRatio)
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

	local scaleRatio = currentScaleRatio(shopFrame)
	local target = targetPosition(shopFrame, scaleRatio)
	if isCardOpen then
		-- Already open and simply re-targeted at a different weapon -- reseat without replaying the
		-- entrance tween.
		reseat(shopFrame)
		return repaint
	end
	isCardOpen = true

	cardScale.Scale = scaleRatio
	card.Position = target + UDim2.fromOffset(SLIDE_OFFSET, 0)
	Transitions.set(card, 1)
	cardGui.Enabled = true
	TweenService:Create(card, OPEN_TWEEN, { Position = target }):Play()
	Transitions.fade(card, 0, OPEN_TWEEN.Time)

	-- Tracks the shop panel for as long as the card stays open. A viewport resize, or the shop's own
	-- scale shrinking to make room for this card (see WeaponaryShopController's ResponsiveScale),
	-- changes AbsolutePosition and/or AbsoluteSize -- nothing else re-runs targetPosition() unless
	-- this does.
	shopPositionConnection = shopFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		reseat(shopFrame)
	end)
	shopSizeConnection = shopFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		reseat(shopFrame)
	end)

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

	if shopPositionConnection then
		shopPositionConnection:Disconnect()
		shopPositionConnection = nil
	end
	if shopSizeConnection then
		shopSizeConnection:Disconnect()
		shopSizeConnection = nil
	end

	local target = card.Position + UDim2.fromOffset(SLIDE_OFFSET, 0)
	TweenService:Create(card, CLOSE_TWEEN, { Position = target }):Play()
	Transitions.fade(card, 1, CLOSE_TWEEN.Time, function()
		cardGui.Enabled = false
	end)
end

SkinsCardController.RESERVED_WIDTH = RESERVED_WIDTH

return SkinsCardController
