local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local catalog = ReplicatedStorage.Weapons:WaitForChild("Catalog")
local buyRequest = ReplicatedStorage.Weapons.Remotes.BuyRequest
local upgradeRequest = ReplicatedStorage.Weapons.Remotes.UpgradeRequest
local setLoadoutSlotRequest = ReplicatedStorage.Weapons.Remotes.SetLoadoutSlotRequest
local UpgradeConfig = require(ReplicatedStorage.Weapons.UpgradeConfig)
local MenuFovBlur = require(ReplicatedStorage.Modules.MenuFovBlur)
local Effects = require(ReplicatedStorage.UI.Effects)
local CashBurst = require(ReplicatedStorage.UI.CashBurst)
local SkinRowController = require(script.Parent.SkinRowController)

local FADE_TIME = 0.25

-- Hover outline for the loadout slots, shown only while the equip picker is waiting for a choice.
-- Its own stroke rather than the state stroke refreshInventoryColumn paints, because that one
-- encodes filled-versus-empty through colour and thickness and can be repainted mid-hover.
--
-- Thicker than that stroke's filled 2px so it still reads on an occupied slot, where both are the
-- same accent green on the same edge: hovering a filled slot thickens its outline, hovering an
-- empty one brings a green outline in from nothing.
--
-- Declared up here rather than beside the loop that builds the strokes, because setSlotPickMode
-- clears the outlines when the picker closes and is defined above that loop -- a local declared
-- after it would simply not be in its scope.
local HOVER_STROKE_THICKNESS = 3
local HOVER_STROKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local PURCHASE_SOUND_ID = "rbxassetid://17161225362"
local UPGRADE_SOUND_ID = "rbxassetid://127170375041015"
-- The same tick the dialogue response buttons hover with (ReplicatedStorage.DialogModule.sounds.tick2),
-- reused deliberately so UI hover feedback is one sound across the game rather than one per system.
local HOVER_SOUND_ID = "rbxassetid://10066931761"

local purchaseSound = Instance.new("Sound")
purchaseSound.Name = "WeaponPurchaseSound"
purchaseSound.SoundId = PURCHASE_SOUND_ID
purchaseSound.Volume = 0.7
purchaseSound.Parent = SoundService

local upgradeSound = Instance.new("Sound")
upgradeSound.Name = "WeaponUpgradeSound"
upgradeSound.SoundId = UPGRADE_SOUND_ID
upgradeSound.Volume = 0.7
upgradeSound.Parent = SoundService

-- Find-or-create against the same name the Custom Inventory package uses for its slot click, so
-- equipping from this shop and equipping from the hotbar are one sound rather than two instances of
-- the same asset. Whichever system loads first owns it.
local EQUIP_SOUND_ID = "rbxassetid://111258886624386"
local equipSound = SoundService:FindFirstChild("InventoryEquipSound")
if not equipSound then
	equipSound = Instance.new("Sound")
	equipSound.Name = "InventoryEquipSound"
	equipSound.SoundId = EQUIP_SOUND_ID
	equipSound.Volume = 0.6
	equipSound.Parent = SoundService
end

-- Find-or-create rather than plain create: the per-object hover-effect LocalScripts on ActionButton,
-- EquipButton and every WeaponCard clone need this same sound and each does the identical check, so
-- whichever runs first owns it and the rest share it. One Sound, however many cards the grid holds.
local hoverSound = SoundService:FindFirstChild("UIHoverSound")
if not hoverSound then
	hoverSound = Instance.new("Sound")
	hoverSound.Name = "UIHoverSound"
	hoverSound.SoundId = HOVER_SOUND_ID
	hoverSound.Volume = 0.5
	hoverSound.Parent = SoundService
end

-- Set right before firing BuyRequest, cleared once the resulting Backpack change is observed. This
-- is what stops the purchase sound from also firing on a silent respawn restore, which now also
-- adds Tools to the Backpack and would otherwise chime on every death.
local awaitingPurchaseSound = false

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponaryShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local shop = guiTemplates:WaitForChild("WeaponaryShop"):Clone()
shop.Visible = false
shop.Parent = gui

local titleBar = shop:WaitForChild("TitleBar")
local closeButton = titleBar:WaitForChild("CloseButton")
local inventoryColumn = shop:WaitForChild("InventoryColumn")
local swapPrompt = inventoryColumn:WaitForChild("SwapPrompt")
local slotsContainer = inventoryColumn:WaitForChild("Slots")
local shopArea = shop:WaitForChild("ShopArea")
local categoryTabs = shopArea:WaitForChild("CategoryTabs")
local weaponGrid = shopArea:WaitForChild("WeaponGrid")
local detailPanel = shopArea:WaitForChild("DetailPanel")
local backButton = detailPanel:WaitForChild("BackButton")
local detailViewport = detailPanel:WaitForChild("DetailViewport") :: ViewportFrame
local skinRow = detailPanel:WaitForChild("SkinRow")
local skinChipTemplate = skinRow:WaitForChild("SkinChip")
local detailName = detailPanel:WaitForChild("DetailName")
local statsContainer = detailPanel:WaitForChild("StatsContainer")
local priceLabel = detailPanel:WaitForChild("PriceLabel")
-- The price now lives as a dark pill INSIDE the buy button, the way the Figma detail state draws
-- it, rather than as a separate icon+text row that duplicated the cash glyph beside it.
-- The cash glyph is a SIBLING of PriceLabel, not a child: a UIPadding on the label offsets its
-- children as well as its text, so while the icon lived inside it the two could only ever move
-- together and the glyphs sat straight on top of the icon.
local priceIcon = detailPanel:WaitForChild("PriceIcon")
local pricePill = detailPanel:WaitForChild("ActionButton"):WaitForChild("Price")
local pricePillLabel = pricePill:WaitForChild("Label")
local categoryChip = detailPanel:WaitForChild("CategoryChip"):WaitForChild("Label")
local descriptionLabel = detailPanel:WaitForChild("Description")

-- Full-bar reference values for the stat tracks. A bar needs a ceiling to read against, and these
-- are the top of each stat's range across the 32-weapon catalogue rather than per-weapon maxima,
-- so the bars stay comparable BETWEEN weapons -- which is the whole point of showing them.
local STAT_MAX = { Damage = 100, FireRate = 1200, Magazine = 100, Range = 1000 }

local function setStatBar(rowName: string, value: number)
	local row = statsContainer:FindFirstChild(rowName)
	local track = row and row:FindFirstChild("Track")
	local fill = track and track:FindFirstChild("Fill")
	if not fill then
		return
	end
	local ratio = math.clamp(value / (STAT_MAX[rowName] or 1), 0, 1)
	-- A zero-width fill still shows its 5px corner radius as a dot, so floor it at nothing visible.
	fill.Visible = ratio > 0.001
	fill.Size = UDim2.new(ratio, 0, 1, 0)
end
local actionButton = detailPanel:WaitForChild("ActionButton")
-- The button's caption is a child TextLabel, not the button's own Text. A TextLabel cannot be inset
-- from its edges without a UIPadding, and a UIPadding on the BUTTON would also offset the price
-- pill (padding moves children, not just text) -- which is exactly what pushed the pill onto the
-- caption. Giving the caption its own instance lets both be positioned independently.
local actionLabel = actionButton:WaitForChild("Label")
local Sounds = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Sounds"))

-- Acid outline on a filled loadout slot, hairline on an empty one.
local SLOT_FILLED_COLOR = Color3.fromHex("CBF23C")
local SLOT_EMPTY_COLOR = Color3.fromHex("2A2F3C")
-- Flash colour when an action is refused for lack of funds.
local DENIED_COLOR = Color3.fromHex("FF4B4B")

-- Cash readout in the title bar, so the price on a weapon card can be judged against what the
-- player actually has without closing the shop. Same leaderstats.Cash the HUD and the cash shop
-- read, so the three can never disagree.
do
	local chip = shop:WaitForChild("TitleBar"):WaitForChild("CashChip")
	local amount = chip:WaitForChild("amount") :: TextLabel

	local function render(value: number)
		local text = tostring(math.floor(value))
		local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		amount.Text = (grouped:gsub("^,", ""))
	end

	task.spawn(function()
		-- leaderstats is created by whichever of CashService/LevelingService runs first and Cash is
		-- added separately, so neither can be assumed present at join.
		local leaderstats = player:WaitForChild("leaderstats", 30)
		local cash = leaderstats and leaderstats:WaitForChild("Cash", 30)
		if not cash then
			return
		end
		render(cash.Value)
		cash.Changed:Connect(render)
	end)
end
local equipButton = detailPanel:WaitForChild("EquipButton") :: TextButton

-- Tabs are laid out with a fixed Padding but a COMPUTED equal width, so any number of category
-- tabs always exactly fills CategoryTabs' width instead of overflowing it. Re-run whenever the
-- container resizes (the shop's own open/close tween changes ShopArea's, and therefore
-- CategoryTabs', width from 650px to 700px), so this one calculation stays correct in both states
-- and for however many categories exist in the future -- not just the 6 that exist today.
local TAB_HEIGHT = 36
local TAB_PADDING = 8

local function layoutCategoryTabs()
	local tabs = {}
	for _, child in categoryTabs:GetChildren() do
		if child:IsA("TextButton") then
			table.insert(tabs, child)
		end
	end
	if #tabs == 0 then
		return
	end

	local available = categoryTabs.AbsoluteSize.X
	local totalPadding = TAB_PADDING * (#tabs - 1)
	local tabWidth = math.max((available - totalPadding) / #tabs, 1)

	for _, tab in tabs do
		tab.Size = UDim2.fromOffset(math.floor(tabWidth), TAB_HEIGHT)
	end
end

categoryTabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCategoryTabs)
layoutCategoryTabs()

-- TextScaled with nothing capping it balloons "Empty" to fill the entire slot frame.
for i = 1, 4 do
	local slot = slotsContainer:FindFirstChild("Slot" .. i)
	local emptyLabel = slot and slot:FindFirstChild("EmptyLabel")
	if emptyLabel and not emptyLabel:FindFirstChildOfClass("UITextSizeConstraint") then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 18
		constraint.MinTextSize = 10
		constraint.Parent = emptyLabel
	end
end

-- Action-button colours, retuned to the redesign palette (ReplicatedStorage.UI.Theme).
--
-- refreshDetailStats writes these onto ActionButton/EquipButton on every state change, so they
-- OVERRIDE the template's colours -- restyling the template alone left BUY rendering in the old
-- bright Roblox green. This script is the one owner of these buttons' colour while the shop is
-- open, so the palette change belongs here.
--
-- BUY is the primary action: Accent fill, and refreshDetailStats pairs it with Deep text. UPGRADE
-- stays distinct from BUY (it spends rather than acquires) and EQUIP/DEQUIP read as secondary.
local BUY_COLOR = Color3.fromRGB(203, 242, 60) -- Theme Accent #CBF23C
local UPGRADE_COLOR = Color3.fromRGB(159, 192, 36) -- Theme AccentDim #9FC024
local EQUIP_COLOR = Color3.fromRGB(18, 20, 26) -- Theme Inset #12141A, with the accent stroke
local DEQUIP_COLOR = Color3.fromRGB(42, 47, 60) -- Theme Line #2A2F3C



local GUN_ROTATION_SPEED = math.rad(40) -- degrees/second, expressed in radians
local MELEE_ROTATION_SPEED = math.rad(20) -- slower -- melee weapons read larger/closer in the box

local isOpen = false
local pendingEquipWeapon: string? = nil -- set while waiting for the player to pick a slot to equip into
-- What each slot rendered last time, so only slots whose contents actually changed get animated.
local lastRenderedSlots: { [number]: string } = {}
-- Which weapon the detail panel is currently showing. Held out here, not captured in a per-call
-- closure: the action button is connected exactly once, so a closure created inside showDetail
-- would pin the FIRST weapon ever viewed and every later Buy/Upgrade would act on that one.
local currentDetailWeapon: string? = nil
local showDetail
local refreshDetailStats
local currentSpinConnection: RBXScriptConnection? = nil
local currentSkinConnection: RBXScriptConnection? = nil
local currentSkinOwnershipConnection: RBXScriptConnection? = nil

local function stopSpin()
	if currentSpinConnection then
		currentSpinConnection:Disconnect()
		currentSpinConnection = nil
	end
	for _, child in detailViewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
end

-- ============================================
-- OWNERSHIP + LOADOUT SLOTS (both replicated as player attributes by WeaponShopService -- the
-- Backpack is a downstream effect of slot state now, never the source of truth for either)
-- ============================================
local function isOwned(weaponName: string): boolean
	return player:GetAttribute(UpgradeConfig.ownedAttributeFor(weaponName)) == true
end

-- slot index (1-4) -> weapon name, only for slots that are actually occupied
local function getEquippedWeaponNames(): { [number]: string }
	local slots = {}
	for i = 1, 4 do
		local name = player:GetAttribute("LoadoutSlot" .. i)
		if typeof(name) == "string" and name ~= "" then
			slots[i] = name
		end
	end
	return slots
end

local function findEquippedSlot(weaponName: string): number?
	for i, name in getEquippedWeaponNames() do
		if name == weaponName then
			return i
		end
	end
	return nil
end

-- ============================================
-- INVENTORY COLUMN (also the swap picker)
-- ============================================
local function refreshInventoryColumn()
	local slots = getEquippedWeaponNames()
	for i = 1, 4 do
		local slot = slotsContainer:FindFirstChild("Slot" .. i) :: ImageButton
		local icon = slot:WaitForChild("Icon") :: ImageLabel
		local nameLabel = slot:WaitForChild("NameLabel") :: TextLabel
		local emptyLabel = slot:WaitForChild("EmptyLabel") :: TextLabel
		local popScale = slot:FindFirstChild("PopScale") :: UIScale?

		local weaponName = slots[i]
		local changed = lastRenderedSlots[i] ~= weaponName
		if weaponName then
			-- Read from the catalog, not a live Tool -- a weapon can be equipped while this client's
			-- own Backpack replication hasn't caught up yet, and the catalog always has the icon
			-- regardless of ownership.
			local entry = catalog:FindFirstChild(weaponName)
			local iconId = (entry and entry:GetAttribute("iconId")) or ""
			icon.Image = iconId
			icon.Visible = iconId ~= ""
			nameLabel.Text = weaponName
			nameLabel.Visible = true
			emptyLabel.Visible = false
		else
			icon.Image = ""
			nameLabel.Text = ""
			icon.Visible = false
			nameLabel.Visible = false
			emptyLabel.Visible = true
		end

		-- Occupied slots take an acid outline so a filled slot reads as filled at a glance, rather
		-- than only by whether it happens to have an icon in it.
		-- By NAME, not by class. The slots now carry a second UIStroke (the hover outline added
		-- below), and FindFirstChildOfClass returns whichever comes first in child order -- which
		-- would silently hand the filled/empty state paint to the hover outline instead.
		local slotStroke = slot:FindFirstChild("UIStroke") :: UIStroke?
		if slotStroke then
			slotStroke.Color = if weaponName then SLOT_FILLED_COLOR else SLOT_EMPTY_COLOR
			slotStroke.Thickness = if weaponName then 2 else 1
		end

		-- Pop only the slot(s) whose content actually changed. Skipped entirely on the shop's first
		-- render, when lastRenderedSlots is still empty and every slot would otherwise count as
		-- changed and pop all four on open.
		if changed and popScale and next(lastRenderedSlots) ~= nil then
			popScale.Scale = 0.75
			TweenService:Create(
				popScale,
				TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end
	lastRenderedSlots = slots
end

local function setSlotPickMode(active: boolean)
	swapPrompt.Visible = active
	swapPrompt.Text = "Select a slot to equip"
	for i = 1, 4 do
		local slot = slotsContainer:FindFirstChild("Slot" .. i) :: ImageButton
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		if active then
			-- Every slot is a valid pick target now (empty ones included), so every slot pulses.
			TweenService:Create(slot, tweenInfo, { BackgroundTransparency = 0.6 }):Play()
		else
			TweenService:Create(slot, TweenInfo.new(0.15), { BackgroundTransparency = 0.3 }):Play()
		end

		-- Leaving pick mode clears the hover outline directly. Picking a slot ends the mode with the
		-- pointer still sitting on that slot, so MouseLeave never fires for it -- without this the
		-- outline stays lit on a panel that has stopped asking for a choice.
		if not active then
			local hoverStroke = slot:FindFirstChild("HoverOutline") :: UIStroke?
			if hoverStroke then
				TweenService:Create(hoverStroke, HOVER_STROKE_TWEEN, { Transparency = 1 }):Play()
			end
		end
	end
end

for i = 1, 4 do
	local slot = slotsContainer:WaitForChild("Slot" .. i) :: ImageButton

	local hoverStroke = Instance.new("UIStroke")
	hoverStroke.Name = "HoverOutline"
	hoverStroke.Color = SLOT_FILLED_COLOR
	hoverStroke.Thickness = HOVER_STROKE_THICKNESS
	hoverStroke.Transparency = 1
	hoverStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hoverStroke.Parent = slot

	-- Gated on pick mode. Outside it these slots are a read-only summary of the loadout -- the click
	-- handler below returns immediately when nothing is pending -- so highlighting one would offer a
	-- choice that clicking does not actually make. The outline appears only while the panel is
	-- genuinely asking which slot to equip into.
	slot.MouseEnter:Connect(function()
		if not pendingEquipWeapon then
			return
		end
		hoverSound:Play()
		TweenService:Create(hoverStroke, HOVER_STROKE_TWEEN, { Transparency = 0 }):Play()
	end)
	-- Deliberately NOT gated: pick mode can end while the pointer is on a slot, and this still has to
	-- be able to put the outline away afterwards.
	slot.MouseLeave:Connect(function()
		TweenService:Create(hoverStroke, HOVER_STROKE_TWEEN, { Transparency = 1 }):Play()
	end)

	slot.MouseButton1Click:Connect(function()
		if not pendingEquipWeapon then
			return
		end
		equipSound:Play()
		setLoadoutSlotRequest:FireServer(pendingEquipWeapon, i)
		pendingEquipWeapon = nil
		setSlotPickMode(false)
	end)
end

-- ============================================
-- DETAIL PANEL
-- ============================================
local function formatFireRate(rpm: number): string
	return `{rpm} RPM`
end

-- Refuses an action the player cannot pay for: flashes the button red and plays the denied tone,
-- then puts the colour back. Checked on the client purely as feedback -- the server still validates
-- every purchase and upgrade, so this cannot be used to buy anything.
local function denyAction()
	local original = actionButton.BackgroundColor3
	Sounds.denied():Play()
	local toRed = TweenService:Create(actionButton, TweenInfo.new(0.12), { BackgroundColor3 = DENIED_COLOR })
	toRed:Play()
	toRed.Completed:Connect(function()
		TweenService:Create(actionButton, TweenInfo.new(0.25), { BackgroundColor3 = original }):Play()
	end)
end

local function currentCash(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function performAction()
	local weaponName = currentDetailWeapon
	if not weaponName then
		return
	end

	local entry = catalog:FindFirstChild(weaponName)
	if entry then
		local cost
		if isOwned(weaponName) then
			local level = player:GetAttribute(UpgradeConfig.attributeFor(weaponName)) or 0
			cost = UpgradeConfig.COST_PER_LEVEL * (level + 1)
		else
			cost = entry:GetAttribute("Price")
		end
		if cost and currentCash() < cost then
			denyAction()
			return
		end
	end

	if isOwned(weaponName) then
		-- Deliberately no local repaint here: the WeaponUpgrade_ attribute listener repaints when
		-- the server's new level actually replicates. The fixed task.delay(0.1) this replaces raced
		-- that replication -- whenever the attribute arrived later than 100ms the panel repainted
		-- with the PRE-upgrade level and nothing refreshed it again, so the Damage stat looked as
		-- though the upgrade had never applied even though the server had already applied it.
		upgradeRequest:FireServer(weaponName)
		return
	end

	awaitingPurchaseSound = true
	buyRequest:FireServer(weaponName)
end

-- Equipping is always an explicit slot choice, even when a slot is free: buying no longer
-- auto-equips, so this is the only path a weapon reaches the Backpack.
local function performEquipAction()
	local weaponName = currentDetailWeapon
	if not weaponName then
		return
	end

	if findEquippedSlot(weaponName) then
		setLoadoutSlotRequest:FireServer(weaponName, nil) -- dequip
	else
		pendingEquipWeapon = weaponName
		setSlotPickMode(true)
	end
end

function showDetail(weaponName: string)
	local entry = catalog:FindFirstChild(weaponName)
	if not entry then
		return
	end

	currentDetailWeapon = weaponName
	weaponGrid.Visible = false
	categoryTabs.Visible = false
	detailPanel.Visible = true

	stopSpin()

	local displayModel
	local blasterTemplate = entry:FindFirstChild("Blaster")
	if blasterTemplate then
		displayModel = blasterTemplate:Clone()
		displayModel.Parent = detailViewport

		local isMelee = entry:GetAttribute("Category") == "Melee"
		local rotationSpeed = if isMelee then MELEE_ROTATION_SPEED else GUN_ROTATION_SPEED

		-- Invisible parts are dropped before anything measures this model. Every calculation below --
		-- the centring, the orientation derivation and the camera distance -- works off the bounding
		-- box, and a weapon whose rig hub is an invisible shaft (the Knife's Body is 3.32 studs of
		-- nothing) has a box far larger than what a player can see. The result is a model shoved to
		-- one side of the frame and shrunk to fit geometry that is not there.
		--
		-- Guarded so a weapon that is somehow all-transparent keeps its parts rather than vanishing.
		local visibleCount = 0
		for _, descendant in displayModel:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				visibleCount += 1
			end
		end
		if visibleCount > 0 then
			for _, descendant in displayModel:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.Transparency >= 1 then
					descendant:Destroy()
				end
			end
		end

		-- Centred on the origin first, so every rotation below turns about the model's own centre
		-- rather than about wherever its pivot happened to be authored.
		local boundsCFrame = displayModel:GetBoundingBox()
		displayModel:PivotTo(CFrame.new(-boundsCFrame.Position) * displayModel:GetPivot())

		-- Stand the model up side-on. A single fixed rotation cannot do this: these meshes were
		-- authored with at least three different "up" conventions. Measured across all 17 weapons,
		-- a fixed 90 degree correction about X framed 12 correctly and left every pistol and melee
		-- weapon wrong. Deriving the orientation per model from its own bounding box instead --
		-- longest extent across the screen, thinnest toward the camera, middle vertical -- frames
		-- 17 of 17, and needs no per-weapon override attribute to do it.
		local oriented, orientedSize = displayModel:GetBoundingBox()
		local axes = {
			{ v = oriented.RightVector, len = orientedSize.X },
			{ v = oriented.UpVector, len = orientedSize.Y },
			{ v = -oriented.LookVector, len = orientedSize.Z },
		}
		table.sort(axes, function(a, b)
			return a.len > b.len
		end)
		local longAxis, midAxis = axes[1].v, axes[2].v
		-- rebuilt via cross products so the basis is guaranteed right-handed
		local thinAxis = longAxis:Cross(midAxis).Unit
		midAxis = thinAxis:Cross(longAxis).Unit
		if isMelee then
			-- Melee stands UP: its longest extent goes to the screen's vertical rather than across it.
			-- A gun reads best lying along its barrel, but a blade or a bar laid flat wastes the tall
			-- viewport and reads as a stick. Z is negated because swapping two axes of a right-handed
			-- basis flips its handedness, and a left-handed basis mirrors the model.
			displayModel:PivotTo(CFrame.fromMatrix(Vector3.zero, midAxis, longAxis, -thinAxis):Inverse() * displayModel:GetPivot())
		else
			displayModel:PivotTo(CFrame.fromMatrix(Vector3.zero, longAxis, midAxis, thinAxis):Inverse() * displayModel:GetPivot())
		end

		-- Per-weapon escape hatch (XYZ Euler degrees), applied ON TOP of the derivation above rather
		-- than instead of it. The derivation picks which axis faces the camera, but a bounding box is
		-- symmetric -- it cannot tell which of the two 180-degree rolls about that axis is "up", so a
		-- model can still come out flipped. This corrects that one residual case. Absent on a weapon
		-- (which is every weapon unless someone sets it) = exactly the pure derived result.
		local rotationOverride = entry:GetAttribute("ShopViewRotation") :: Vector3?
		if rotationOverride then
			displayModel:PivotTo(
				CFrame.Angles(
					math.rad(rotationOverride.X),
					math.rad(rotationOverride.Y),
					math.rad(rotationOverride.Z)
				) * displayModel:GetPivot()
			)
		end

		local _, correctedSize = displayModel:GetBoundingBox()
		local camera = detailViewport:FindFirstChildOfClass("Camera")
		if not camera then
			camera = Instance.new("Camera")
			camera.Parent = detailViewport
		end
		detailViewport.CurrentCamera = camera

		-- Framing distance: spinning around the world Y axis sweeps the model's X/Z footprint
		-- through every angle, so the worst-case visible width across a full spin is the diagonal
		-- of THOSE two dimensions, not the 3D bounding box's overall magnitude -- the vertical (Y)
		-- extent never changes during a Y-axis spin and is checked separately.
		local horizontalDiagonal = math.sqrt(correctedSize.X ^ 2 + correctedSize.Z ^ 2)
		local distance = math.max(horizontalDiagonal, correctedSize.Y) * 0.9
		camera.CFrame = CFrame.new(Vector3.new(0, 0, distance), Vector3.zero)

		if currentSpinConnection then
			currentSpinConnection:Disconnect()
		end
		-- Rotated about the ORIGIN, not the model's own pivot. The bounding box was just centred on
		-- the origin, but a weapon's authored pivot is not its centre -- spinning about the pivot
		-- makes the model orbit instead of turning in place (measured: the M16A1's centre swings
		-- 0.62 studs per revolution that way, versus 0.00 about the origin).
		currentSpinConnection = RunService.RenderStepped:Connect(function(dt)
			displayModel:PivotTo(CFrame.Angles(0, rotationSpeed * dt, 0) * displayModel:GetPivot())
		end)
	end

	-- Rebuilt per weapon because the equipped chip and the locked chips both depend on which weapon
	-- is on screen. Both attribute connections are stored and replaced the same way
	-- currentSpinConnection is, so viewing twenty weapons leaves one of each rather than twenty.
	if currentSkinConnection then
		currentSkinConnection:Disconnect()
	end
	if currentSkinOwnershipConnection then
		currentSkinOwnershipConnection:Disconnect()
	end
	local repaintSkins, skinOwnershipConnection = SkinRowController.build(skinRow, skinChipTemplate, weaponName, displayModel)
	currentSkinConnection = player:GetAttributeChangedSignal(
		"EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
	):Connect(repaintSkins)
	currentSkinOwnershipConnection = skinOwnershipConnection

	refreshDetailStats(weaponName)
end

-- Everything in the detail panel EXCEPT the 3D model: name, stats, price and button state. Safe to
-- call as often as needed for the weapon already on screen -- unlike showDetail it never touches
-- the viewport, so it cannot destroy the display model or restart the spin. Splitting this out is
-- what stops buying/upgrading/equipping from visibly resetting the preview.
function refreshDetailStats(weaponName: string)
	local entry = catalog:FindFirstChild(weaponName)
	if not entry then
		return
	end

	detailName.Text = weaponName

	local stockDamage = entry:GetAttribute("damage")
	local level = player:GetAttribute(UpgradeConfig.attributeFor(weaponName)) or 0
	local bonus = level * UpgradeConfig.DAMAGE_PER_LEVEL
	statsContainer.Damage.Value.Text = if bonus > 0
		then `{stockDamage + bonus} (+{bonus})`
		else tostring(stockDamage)
	statsContainer.FireRate.Value.Text = formatFireRate(entry:GetAttribute("rateOfFire"))
	statsContainer.Magazine.Value.Text = tostring(entry:GetAttribute("magazineSize"))
	statsContainer.Range.Value.Text = tostring(entry:GetAttribute("range"))

	setStatBar("Damage", stockDamage + bonus)
	setStatBar("FireRate", entry:GetAttribute("rateOfFire") or 0)
	setStatBar("Magazine", entry:GetAttribute("magazineSize") or 0)
	setStatBar("Range", entry:GetAttribute("range") or 0)

	-- A melee weapon has no magazine, so the row is hidden rather than shown reading 0 -- which
	-- looked like a stat the crowbar was simply bad at. The UIListLayout closes the gap.
	local isMelee = entry:GetAttribute("Category") == "Melee"
	local magazineRow = statsContainer:FindFirstChild("Magazine")
	if magazineRow then
		magazineRow.Visible = not isMelee
	end

	categoryChip.Text = string.upper(entry:GetAttribute("Category") or "WEAPON")
	descriptionLabel.Text = entry:GetAttribute("Description") or ""

	if isOwned(weaponName) then
		local nextLevel = level + 1
		local cost = UpgradeConfig.COST_PER_LEVEL * nextLevel
		-- No emoji: the money glyph is carried by the MoneyStack ImageLabel beside this label. Having
		-- both meant two different cash visuals in the same row, and the emoji's own advance width
		-- was what pushed this text into the icon.
		priceLabel.Text = `Upgrade to Lv.{nextLevel}`
		priceLabel.Visible = true
		priceIcon.Visible = true
		-- The level moved to the line above: with the cost pill occupying the button's right side
		-- there is only ~94px of label room, and "UPGRADE Lv.2" ran underneath the pill.
		actionLabel.Text = "UPGRADE"
		actionButton.BackgroundColor3 = UPGRADE_COLOR
		actionButton.Visible = true
		pricePillLabel.Text = tostring(cost)
		pricePill.Visible = true

		local isEquipped = findEquippedSlot(weaponName) ~= nil
		equipButton.Text = if isEquipped then "DEQUIP" else "EQUIP"
		equipButton.BackgroundColor3 = if isEquipped then DEQUIP_COLOR else EQUIP_COLOR
		equipButton.Visible = true
	else
		equipButton.Visible = false
		local price = entry:GetAttribute("Price")
		if price then
			-- The pill carries the number, so the separate icon+text row would be a second cash
			-- visual saying the same thing.
			priceLabel.Visible = false
			priceIcon.Visible = false
			actionLabel.Text = "BUY"
			actionButton.BackgroundColor3 = BUY_COLOR
			actionButton.Visible = true
			pricePillLabel.Text = tostring(price)
			pricePill.Visible = true
		else
			-- Reachable now that the catalog is keyed on Category: an owned-only weapon the player
			-- has given up (the Crowbar can be swapped away) has no Price, and the server would
			-- reject a buy for it anyway. Showing a dead BUY button and "money nil" would be worse.
			priceLabel.Text = "Not for sale"
			priceLabel.Visible = true
			priceIcon.Visible = false
			pricePill.Visible = false
			actionButton.Visible = false
		end
	end
end

-- Cash physically leaving the button the player just pressed: coins explode out of it and fade.
-- See UI.CashBurst for why this replaced the red "-<amount>" label, and for how it pairs with the
-- Robbery System place's inbound CashClaimVFX.
--
-- Origin is the action button rather than the price label: the button is what was clicked, and the
-- price pill sits inside it, so the burst still covers the figure it is confirming.
local function showCashBurst(amount: number)
	CashBurst.burstFrom(actionButton, amount)
end

actionButton.MouseButton1Click:Connect(performAction)
equipButton.MouseButton1Click:Connect(performEquipAction)

backButton.MouseEnter:Connect(function()
	hoverSound:Play()
end)

backButton.MouseButton1Click:Connect(function()
	stopSpin()
	detailPanel.Visible = false
	categoryTabs.Visible = true
	weaponGrid.Visible = true
	currentDetailWeapon = nil
	if pendingEquipWeapon then
		pendingEquipWeapon = nil
		setSlotPickMode(false)
	end
end)

-- ============================================
-- WEAPON GRID
-- ============================================
local currentCategory = "All"

local function buildGrid()
	for _, child in weaponGrid:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	local entries = {}
	for _, entry in catalog:GetChildren() do
		local matchesCategory
		if currentCategory == "All" then
			matchesCategory = true
		elseif currentCategory == "Owned" then
			matchesCategory = isOwned(entry.Name)
		else
			matchesCategory = entry:GetAttribute("Category") == currentCategory
		end
		if matchesCategory then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a, b)
		return (a:GetAttribute("Price") or 0) < (b:GetAttribute("Price") or 0)
	end)

	for order, entry in entries do
		local card = guiTemplates.WeaponCard:Clone()
		card.LayoutOrder = order
		card.Name = entry.Name
		local iconId = entry:GetAttribute("iconId") or ""
		local icon = card:WaitForChild("Icon")
		icon.Image = iconId
		icon.Visible = iconId ~= ""
		card:WaitForChild("NameLabel").Text = entry.Name

		local priceOrOwned = card:WaitForChild("PriceOrOwned") :: TextLabel
		if isOwned(entry.Name) then
			priceOrOwned.Text = "OWNED"
			priceOrOwned.TextColor3 = Color3.fromRGB(120, 220, 140)
		elseif entry:GetAttribute("Price") then
			priceOrOwned.Text = `{entry:GetAttribute("Price")}`
			priceOrOwned.TextColor3 = Color3.fromRGB(255, 220, 120)
		else
			priceOrOwned.Text = "\u{2014}"
			priceOrOwned.TextColor3 = Color3.fromRGB(150, 150, 155)
		end

		card.MouseButton1Click:Connect(function()
			showDetail(entry.Name)
		end)

		card.Parent = weaponGrid
	end
end

for _, tab in categoryTabs:GetChildren() do
	if tab:IsA("TextButton") then
		tab.MouseButton1Click:Connect(function()
			currentCategory = tab.Name:gsub("^Tab", "")
			buildGrid()
			for _, otherTab in categoryTabs:GetChildren() do
				if otherTab:IsA("TextButton") then
					otherTab.BackgroundTransparency = (otherTab == tab) and 0 or 0.3
				end
			end
		end)
	end
end

-- ============================================
-- OPEN / CLOSE
-- ============================================
local Panels = require(game:GetService("ReplicatedStorage"):WaitForChild("UI"):WaitForChild("Panels"))
-- Forward declaration: closeShop is defined below openShop, and openShop needs to hand it to Panels.
local closeShop: () -> ()

local function openShop()
	if isOpen then
		return
	end
	isOpen = true
	-- Exclusive: closes whichever other panel is up, and hides the HUD behind this one.
	Panels.opened("WeaponaryShop", closeShop)
	MenuFovBlur.open()
	shop.Visible = true
	shop.Size = UDim2.fromOffset(870, 545)
	refreshInventoryColumn()
	buildGrid()
	detailPanel.Visible = false
	categoryTabs.Visible = true
	weaponGrid.Visible = true
	currentDetailWeapon = nil

	TweenService:Create(
		shop,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(920, 580) }
	):Play()
end

function closeShop()
	if not isOpen then
		return
	end
	isOpen = false
	Panels.closed("WeaponaryShop")
	MenuFovBlur.close()
	pendingEquipWeapon = nil
	currentDetailWeapon = nil
	awaitingPurchaseSound = false
	stopSpin()
	setSlotPickMode(false)

	local closeTween = TweenService:Create(
		shop,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromOffset(870, 545) }
	)
	closeTween:Play()
	closeTween.Completed:Connect(function()
		shop.Visible = false
	end)
end

-- Motion + hover/click audio come from the shared module, identical to every other close X in
-- this place and in Robbery System. This used to play only a hover sound and nothing on click,
-- which is why this X felt different from the other four.
Effects.bindClose(closeButton)
closeButton.MouseButton1Click:Connect(closeShop)

-- Ownership and slot assignment are both replicated as player attributes now, so this single
-- listener keeps the open shop honest through buy, equip and dequip alike -- no Backpack watching,
-- since Backpack contents are a downstream effect of slot state rather than the signal for it.
-- This also survives respawn for free: attributes live on the Player, which is never recreated,
-- unlike the Backpack (which Roblox destroys and rebuilds on every death).
player.AttributeChanged:Connect(function(attributeName: string)
	if attributeName:match("^WeaponUpgrade_") then
		upgradeSound:Play()
		-- Gated on the attribute being THIS weapon's, and the amount read fresh from the level the
		-- server just wrote, so the burst can never show a figure that differs from what was charged.
		if currentDetailWeapon and attributeName == UpgradeConfig.attributeFor(currentDetailWeapon) then
			local newLevel = player:GetAttribute(attributeName) or 0
			showCashBurst(UpgradeConfig.COST_PER_LEVEL * newLevel)
			-- Repaint here, where the new level is guaranteed to have arrived, rather than on a timer.
			if isOpen then
				refreshDetailStats(currentDetailWeapon)
			end
		end
	elseif attributeName:match("^WeaponOwned_") then
		if awaitingPurchaseSound then
			awaitingPurchaseSound = false
			purchaseSound:Play()
		end
		if currentDetailWeapon and attributeName == UpgradeConfig.ownedAttributeFor(currentDetailWeapon) then
			local entry = catalog:FindFirstChild(currentDetailWeapon)
			local price = entry and entry:GetAttribute("Price")
			if typeof(price) == "number" then
				showCashBurst(price)
			end
		end
		if isOpen then
			buildGrid()
			-- Stats only: the weapon on screen has not changed, so rebuilding the 3D model here is
			-- what used to reset the spin on every purchase.
			if currentDetailWeapon then
				refreshDetailStats(currentDetailWeapon)
			end
		end
	elseif attributeName:match("^LoadoutSlot") then
		if isOpen then
			refreshInventoryColumn()
			if currentDetailWeapon then
				refreshDetailStats(currentDetailWeapon) -- Equip/Dequip button label flip
			end
		end
	end
end)

-- ============================================
-- TRIGGER: button + keybind
-- ============================================
local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local weaponaryButton = inventoryGui:WaitForChild("weaponaryButton") :: ImageButton
weaponaryButton.MouseButton1Click:Connect(function()
	if isOpen then
		closeShop()
	else
		openShop()
	end
end)

ContextActionService:BindAction("ToggleWeaponaryShop", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		if isOpen then
			closeShop()
		else
			openShop()
		end
	end
end, false, Enum.KeyCode.B)
