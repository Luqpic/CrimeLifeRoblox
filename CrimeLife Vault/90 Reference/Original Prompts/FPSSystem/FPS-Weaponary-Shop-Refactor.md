# Prompt: Weaponary Shop — Replace World Pickups with a Purchase/Upgrade Shop, 4-Weapon Ownership Cap

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Context, confirmed live before writing this — read this first

**How equipping actually works today, confirmed by reading `EquipService`/`InventoryController`:** a player can *own* many Tools in their Backpack, but only *one* is ever held in-hand at a time (`Humanoid:EquipTool`, standard Roblox behavior — it auto-unequips whatever was previously held). The hotbar's `slotAmount` just controls how many owned tools get number-key shortcuts; anything beyond that already spilled into a separate scrollable "Inventory" overflow panel, which is *also* directly clickable to equip. This means "carry 4 at once" is best implemented as an **ownership cap**, not a new multi-equip mechanic — nothing about `EquipService` itself needs to change.

**The old overflow Inventory panel becomes structurally dead once ownership is capped at 4** (`slotAmount`): a player can never own a 5th tool to overflow into it. That's the real reason `openButton` (and the panel it toggles) can go — not just visual redundancy.

**Reuse, not rebuild — confirmed by reading the actual scripts:**
- `ServerScriptService.Weapons.Scripts.WeaponUpgradeService` and `ReplicatedStorage.Weapons.UpgradeConfig` already do exactly what "Upgrade" needs (cost `COST_PER_LEVEL * nextLevel`, currently 50/level; validated server-side; applied to whichever copies of that weapon type the player currently holds). **Nothing in this file changes.** The shop's Upgrade button fires the exact same `UpgradeRequest` remote the old billboard did.
- `ServerScriptService.Weapons.Scripts.EquipService` needs **no changes** — see above.
- The old acquisition pattern (`WeaponPickup.lua`'s `template:Clone()`, carrying over `player:GetAttribute(UpgradeConfig.attributeFor(weaponName))` onto the fresh clone so a purchased weapon shows up at its already-upgraded damage) is reused verbatim inside the new buy handler below.

**Live-confirmed current state:**
- All 16 weapon pickup Models sit loose directly in `Workspace` (not in a subfolder) — `AK47`, `AKM`, `AMB-17`, `AUG A-3`, `Crowbar`, `Deagle`, `FN P-90`, `HCAR`, `Kriss Vector`, `M16A1`, `M1911`, `MP9`, `Mateba 2006M`, `Mossberg 590`, `Scar L`, `Sig MPX` — each a Model with a `Highlight`, `ProximityPrompt`, and a `Weapon` `StringValue`.
- `ServerStorage.Weapons` already holds all 16 Tool templates — the single source of truth for cloning, unchanged by this refactor.
- `InventoryController.SETTINGS`'s `module.slotAmount` is currently `6`.
- `ReplicatedStorage.Weapons.Remotes` currently has `EquipRequest` and `UpgradeRequest`; this adds a third, `BuyRequest`.

**A category ambiguity, flagged rather than silently resolved:** of the 11 rifle-pattern weapons, 4 (`MP9`, `Kriss Vector`, `Sig MPX`, `FN P-90`) are statistically SMGs (850-1200 RPM, low per-shot damage) versus the other 7's true-rifle profile (480-750 RPM). The requested category list has no SMG bucket, so they're folded into Auto-Rifles below — but every weapon's category is a **Tool attribute**, not a hardcoded list, specifically so this can be reclassified (or a 5th category added, given "more guns are coming") by changing one attribute, not code.

**Pricing** — ranked by a blended read of sustained DPS, per-shot damage, range, and recoil control. Placeholder balance, not a rigid formula — meant to be tuned:

| Weapon | Category | Price | | Weapon | Category | Price |
|---|---|---|---|---|---|---|
| AK47 | AutoRifle | 200 | | Deagle | Pistol | 550 |
| MP9 | AutoRifle | 250 | | M1911 | Pistol | 600 |
| Sig MPX | AutoRifle | 300 | | HCAR | AutoRifle | 700 |
| FN P-90 | AutoRifle | 350 | | Mossberg 590 | Shotgun | 750 |
| Scar L | AutoRifle | 400 | | M16A1 | AutoRifle | 800 |
| AUG A-3 | AutoRifle | 425 | | Mateba 2006M | Pistol | 950 |
| AMB-17 | AutoRifle | 450 | | | | |
| AKM | AutoRifle | 475 | | | | |
| Kriss Vector | AutoRifle | 500 | | | | |

`Crowbar` gets a `Category` of `"Melee"` but **no `Price` attribute at all** — that absence is the actual "not for sale" signal the rest of this system checks against, not a separate flag.

---

## Part 1 — Weapon data: `Category` and `Price` attributes

Run once (Command Bar or a temporary `Script`, deleted after):
```lua
local ServerStorage = game:GetService("ServerStorage")
local weapons = ServerStorage.Weapons

local DATA = {
	AK47 = { category = "AutoRifle", price = 200 },
	MP9 = { category = "AutoRifle", price = 250 },
	["Sig MPX"] = { category = "AutoRifle", price = 300 },
	["FN P-90"] = { category = "AutoRifle", price = 350 },
	["Scar L"] = { category = "AutoRifle", price = 400 },
	["AUG A-3"] = { category = "AutoRifle", price = 425 },
	["AMB-17"] = { category = "AutoRifle", price = 450 },
	AKM = { category = "AutoRifle", price = 475 },
	["Kriss Vector"] = { category = "AutoRifle", price = 500 },
	Deagle = { category = "Pistol", price = 550 },
	M1911 = { category = "Pistol", price = 600 },
	HCAR = { category = "AutoRifle", price = 700 },
	["Mossberg 590"] = { category = "Shotgun", price = 750 },
	M16A1 = { category = "AutoRifle", price = 800 },
	["Mateba 2006M"] = { category = "Pistol", price = 950 },
	Crowbar = { category = "Melee" }, -- no price: not sellable, this is the signal BuyService checks
}

local updated = 0
for weaponName, data in DATA do
	local tool = weapons:FindFirstChild(weaponName)
	if tool and tool:IsA("Tool") then
		tool:SetAttribute("Category", data.category)
		if data.price then
			tool:SetAttribute("Price", data.price)
		end
		updated += 1
	else
		warn(`Weapon data assignment: no Tool named "{weaponName}" found`)
	end
end
print(`Assigned Category/Price to {updated}/16 weapons`)
```

### Verify
- `updated` prints `16`, no warnings.
- `Crowbar` has `Category = "Melee"` and **no** `Price` attribute (confirm via Explorer, not just the script's own success).

---

## Part 2 — Crowbar becomes the free starting weapon

**Move `ServerStorage.Weapons.Crowbar` is NOT what changes** — that stays as the upgrade/reference template, same as every other weapon. Instead, **clone** a fresh Crowbar into `StarterPack` (not `StarterGui` — `StarterPack` is the mechanism for "every player spawns holding this Tool"; `StarterGui` is for UI):
```lua
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local existing = StarterPack:FindFirstChild("Crowbar")
if existing then
	existing:Destroy()
end

local crowbar = ServerStorage.Weapons.Crowbar:Clone()
crowbar.Parent = StarterPack
```

### Verify
- A fresh player joining (or respawning) starts with a Crowbar already in their Backpack/hand, with no shop interaction needed.
- Dying and respawning still leaves them with the Crowbar (StarterPack is re-granted on every spawn, same as default Roblox behavior) — confirm this doesn't stack duplicate Crowbars on repeated respawns (it won't: StarterPack contents are cloned fresh into Backpack on every spawn, replacing whatever the previous character had, which is destroyed with it).

---

## Part 3 — Archive the old world pickups, remove now-dead scripts

**Move all 16 pickup Models out of `Workspace`**, preserved rather than deleted:
```lua
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local archiveFolder = ServerStorage:FindFirstChild("ArchivedWeaponPickups")
if not archiveFolder then
	archiveFolder = Instance.new("Folder")
	archiveFolder.Name = "ArchivedWeaponPickups"
	archiveFolder.Parent = ServerStorage
end

local PICKUP_NAMES = {
	"AK47", "AKM", "AMB-17", "AUG A-3", "Crowbar", "Deagle", "FN P-90", "HCAR",
	"Kriss Vector", "M16A1", "M1911", "MP9", "Mateba 2006M", "Mossberg 590", "Scar L", "Sig MPX",
}

local moved = 0
for _, name in PICKUP_NAMES do
	local pickup = Workspace:FindFirstChild(name)
	if pickup and pickup:FindFirstChild("Weapon") then -- the StringValue every real pickup has, guards against grabbing an unrelated same-named part
		pickup.Parent = archiveFolder
		moved += 1
	end
end
print(`Archived {moved}/16 pickup stations`)
```

**Delete two now-dead scripts** — both exist solely to serve world pickups that no longer exist in `Workspace`:
- `ServerScriptService.Weapons.Scripts.WeaponPickup` — its `CollectionService:GetTagged("WeaponPickup")` loop will find nothing once the pickups are archived; the shop's `BuyService` (Part 4) fully replaces what it did.
- `StarterPlayer.StarterPlayerScripts.WeaponStatBillboard` — same reasoning; its floating stat panel had nothing left to attach to. The shop's detail panel (Part 5) shows the same information.

`ReplicatedStorage.GuiTemplates.WeaponStatPanel` (the template that script cloned) is left in place, unused — harmless to leave, safe to delete later if wanted, not touched here since nothing else currently depends on removing it.

### Verify
- `Workspace` has zero weapon pickup Models left; `ServerStorage.ArchivedWeaponPickups` has all 16.
- No errors on server start from the two deleted scripts being gone (nothing else required them).
- Walking around the map no longer shows any weapon pickup prompts or stat billboards anywhere.

---

## Part 4 — `BuyRequest` remote and `WeaponShopService`

**`ReplicatedStorage.Weapons.Remotes`** — add a new `RemoteEvent` named `BuyRequest`, alongside the existing `EquipRequest`/`UpgradeRequest`.

**New `ServerScriptService.Weapons.Scripts.WeaponShopService`**:
```lua
-- Two responsibilities: (1) build a replicated read-only catalog of sellable weapons once at server
-- start, since ServerStorage never replicates and the shop needs to show stats/prices for weapons
-- the player doesn't own yet; (2) handle purchase requests, reusing the exact "carry the player's
-- existing upgrade level onto a fresh clone" pattern WeaponPickup.lua used to.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local UpgradeConfig = require(ReplicatedStorage.Weapons.UpgradeConfig)

local WEAPONS_FOLDER = ServerStorage.Weapons
local buyRequest = ReplicatedStorage.Weapons.Remotes.BuyRequest

local MAX_OWNED_WEAPONS = 4

-- ============================================
-- CATALOG (built once, read by every client's shop UI)
-- ============================================
local catalogFolder = Instance.new("Folder")
catalogFolder.Name = "Catalog"
catalogFolder.Parent = ReplicatedStorage.Weapons

local CATALOG_ATTRIBUTES = { "Category", "Price", "damage", "rateOfFire", "magazineSize", "range" }

for _, template in WEAPONS_FOLDER:GetChildren() do
	if template:IsA("Tool") and template:GetAttribute("Price") then
		local entry = Instance.new("Folder")
		entry.Name = template.Name
		for _, attrName in CATALOG_ATTRIBUTES do
			entry:SetAttribute(attrName, template:GetAttribute(attrName))
		end
		entry:SetAttribute("iconId", template.TextureId)
		entry.Parent = catalogFolder
	end
end

-- ============================================
-- BUY HANDLING
-- ============================================
local function findOwnedTool(player: Player, weaponName: string): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in { backpack, character } do
		local tool = container and container:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

local function countOwnedWeapons(player: Player): number
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local count = 0
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					count += 1
				end
			end
		end
	end
	return count
end

buyRequest.OnServerEvent:Connect(function(player: Player, weaponName: any, swapOutWeaponName: any)
	if typeof(weaponName) ~= "string" then
		return
	end
	if swapOutWeaponName ~= nil and typeof(swapOutWeaponName) ~= "string" then
		return
	end

	local template = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		return
	end

	local price = template:GetAttribute("Price")
	if typeof(price) ~= "number" then
		return -- not sellable (e.g. Crowbar)
	end

	if findOwnedTool(player, weaponName) then
		return -- already own it -- the client should be sending UpgradeRequest instead
	end

	-- Validated BEFORE anything is destroyed or charged: a client cannot swap out a weapon it
	-- doesn't actually own, which would otherwise be a free extra slot.
	local swapOutTool: Tool? = nil
	if swapOutWeaponName then
		swapOutTool = findOwnedTool(player, swapOutWeaponName)
		if not swapOutTool then
			return
		end
	end

	local currentCount = countOwnedWeapons(player)
	local projectedCount = currentCount - (swapOutTool and 1 or 0) + 1
	if projectedCount > MAX_OWNED_WEAPONS then
		return -- still over the cap even with the proposed swap; client should have asked for one
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < price then
		return
	end

	if swapOutTool then
		swapOutTool:Destroy()
	end

	cash.Value -= price

	local weapon = template:Clone()
	local upgradeLevel = player:GetAttribute(UpgradeConfig.attributeFor(weaponName)) or 0
	if upgradeLevel > 0 then
		local stockDamage = template:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
		if typeof(stockDamage) == "number" then
			weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + upgradeLevel)
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		weapon.Parent = backpack
	end
end)
```

### Verify
- `ReplicatedStorage.Weapons.Catalog` has 15 entries (every weapon except Crowbar) after server start, each with `Category`/`Price`/`damage`/`rateOfFire`/`magazineSize`/`range`/`iconId` attributes matching its `ServerStorage.Weapons` template.
- Buying a weapon while owning fewer than 4: succeeds, cash deducted, weapon appears in Backpack.
- Buying while already owning 4, with no `swapOutWeaponName`: silently rejected (client's job to prompt for a swap first — see Part 6).
- Buying with a `swapOutWeaponName` that isn't actually owned: rejected, nothing charged, nothing destroyed.
- Buying a weapon that's already owned: rejected (this path is for `UpgradeRequest` instead).
- Buy a weapon, upgrade it a couple levels, swap it out for something else, then buy it back: it comes back at its previously-upgraded damage, for free — confirms upgrade levels persist independent of current ownership.
- Attempting to buy Crowbar via the remote directly (bypassing the UI): rejected, since it has no `Price` attribute.

---

## Part 5 — Shop GUI templates

Run once (Command Bar or a temporary `Script`, deleted after) — builds the shop shell and the small per-weapon card template:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConstants = require(ReplicatedStorage.Movement.Constants)

local templates = ReplicatedStorage:WaitForChild("GuiTemplates")

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local DAMAGE_COLOR = Color3.fromRGB(120, 90, 230)
local AMMO_COLOR = Color3.fromRGB(90, 200, 100)
local FIRE_RATE_COLOR = Color3.fromRGB(230, 165, 60)
local RANGE_COLOR = Color3.fromRGB(80, 170, 220)
local BUY_COLOR = Color3.fromRGB(50, 200, 90)
local UPGRADE_COLOR = Color3.fromRGB(200, 45, 45) -- matches the billboard's own upgrade button color

local function statRow(name: string, labelText: string, color: Color3, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = color
	row.BackgroundTransparency = 0.15

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.05, 0)
	label.Size = UDim2.fromScale(0.45, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromScale(0.5, 0)
	value.Size = UDim2.fromScale(0.45, 1)
	value.Font = Enum.Font.GothamBold
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = row

	return row
end

-- ============================================
-- WeaponaryShop shell
-- ============================================
do
	local root = Instance.new("Frame")
	root.Name = "WeaponaryShop"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(920, 580)
	root.BackgroundColor3 = PANEL_COLOR
	root.BackgroundTransparency = 0.05

	local rootCorner = Instance.new("UICorner")
	rootCorner.CornerRadius = UDim.new(0, 12)
	rootCorner.Parent = root

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 60)
	titleBar.BackgroundColor3 = Color3.new(0, 0, 0)
	titleBar.BackgroundTransparency = 0.2
	titleBar.Parent = root

	local titleBarCorner = Instance.new("UICorner")
	titleBarCorner.CornerRadius = UDim.new(0, 12)
	titleBarCorner.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -80, 1, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = "WEAPONARY"
	titleLabel.Parent = titleBar

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -16, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(34, 34)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "\u{2715}"
	closeButton.Parent = titleBar

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0.3, 0)
	closeCorner.Parent = closeButton

	-- Left inventory column (also doubles as the swap picker)
	local inventoryColumn = Instance.new("Frame")
	inventoryColumn.Name = "InventoryColumn"
	inventoryColumn.Position = UDim2.new(0, 20, 0, 76)
	inventoryColumn.Size = UDim2.new(0, 160, 1, -96)
	inventoryColumn.BackgroundTransparency = 1
	inventoryColumn.Parent = root

	local swapPrompt = Instance.new("TextLabel")
	swapPrompt.Name = "SwapPrompt"
	swapPrompt.Size = UDim2.new(1, 0, 0, 40)
	swapPrompt.BackgroundTransparency = 1
	swapPrompt.Font = Enum.Font.GothamBold
	swapPrompt.TextScaled = true
	swapPrompt.TextWrapped = true
	swapPrompt.TextColor3 = Color3.fromRGB(255, 210, 90)
	swapPrompt.Text = "Select a weapon to replace"
	swapPrompt.Visible = false
	swapPrompt.Parent = inventoryColumn

	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "Slots"
	slotsContainer.Position = UDim2.new(0, 0, 0, 44)
	slotsContainer.Size = UDim2.new(1, 0, 1, -44)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = inventoryColumn

	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotsLayout.Padding = UDim.new(0, 10)
	slotsLayout.Parent = slotsContainer

	for i = 1, 4 do
		local slot = Instance.new("ImageButton")
		slot.Name = "Slot" .. i
		slot.LayoutOrder = i
		slot.Size = UDim2.new(1, 0, 0, 100)
		slot.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
		slot.BackgroundTransparency = 0.3
		slot.Image = ""
		slot.AutoButtonColor = false
		slot.Parent = slotsContainer

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
		slotCorner.Parent = slot

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Position = UDim2.fromScale(0.5, 0.08)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Size = UDim2.fromScale(0.7, 0.6)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = ""
		icon.Parent = slot

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.fromScale(0.5, 0.95)
		nameLabel.Size = UDim2.fromScale(0.92, 0.28)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Text = ""
		nameLabel.Parent = slot

		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyLabel"
		emptyLabel.Size = UDim2.fromScale(1, 1)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextScaled = true
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
		emptyLabel.Text = "Empty"
		emptyLabel.Parent = slot
	end

	-- Right shop area
	local shopArea = Instance.new("Frame")
	shopArea.Name = "ShopArea"
	shopArea.Position = UDim2.new(0, 200, 0, 76)
	shopArea.Size = UDim2.new(1, -220, 1, -96)
	shopArea.BackgroundTransparency = 1
	shopArea.Parent = root

	local categoryTabs = Instance.new("Frame")
	categoryTabs.Name = "CategoryTabs"
	categoryTabs.Size = UDim2.new(1, 0, 0, 36)
	categoryTabs.BackgroundTransparency = 1
	categoryTabs.Parent = shopArea

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.Parent = categoryTabs

	for i, categoryName in { "All", "Melee", "Pistol", "AutoRifle", "Shotgun" } do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab" .. categoryName
		tab.LayoutOrder = i
		tab.Size = UDim2.fromOffset(130, 36)
		tab.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
		tab.BackgroundTransparency = 0.3
		tab.Font = Enum.Font.GothamBold
		tab.TextScaled = true
		tab.TextColor3 = Color3.new(1, 1, 1)
		tab.Text = categoryName == "AutoRifle" and "Auto-Rifles" or (categoryName == "Shotgun" and "Shotguns" or categoryName)
		tab.Parent = categoryTabs

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
		tabCorner.Parent = tab
	end

	local weaponGrid = Instance.new("ScrollingFrame")
	weaponGrid.Name = "WeaponGrid"
	weaponGrid.Position = UDim2.new(0, 0, 0, 46)
	weaponGrid.Size = UDim2.new(1, 0, 1, -46)
	weaponGrid.BackgroundTransparency = 1
	weaponGrid.BorderSizePixel = 0
	weaponGrid.ScrollBarThickness = 6
	weaponGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
	weaponGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	weaponGrid.Parent = shopArea

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(130, 150)
	gridLayout.CellPadding = UDim2.fromOffset(12, 12)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = weaponGrid

	-- Detail panel (shown instead of the grid when a card is clicked)
	local detailPanel = Instance.new("Frame")
	detailPanel.Name = "DetailPanel"
	detailPanel.Position = UDim2.new(0, 0, 0, 46)
	detailPanel.Size = UDim2.new(1, 0, 1, -46)
	detailPanel.BackgroundTransparency = 1
	detailPanel.Visible = false
	detailPanel.Parent = shopArea

	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.fromOffset(90, 32)
	backButton.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
	backButton.BackgroundTransparency = 0.3
	backButton.Font = Enum.Font.GothamBold
	backButton.TextScaled = true
	backButton.TextColor3 = Color3.new(1, 1, 1)
	backButton.Text = "\u{2039} Back"
	backButton.Parent = detailPanel

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	backCorner.Parent = backButton

	local detailIcon = Instance.new("ImageLabel")
	detailIcon.Name = "DetailIcon"
	detailIcon.Position = UDim2.new(0, 0, 0, 44)
	detailIcon.Size = UDim2.fromOffset(180, 180)
	detailIcon.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	detailIcon.ScaleType = Enum.ScaleType.Fit
	detailIcon.Image = ""
	detailIcon.Parent = detailPanel

	local detailIconCorner = Instance.new("UICorner")
	detailIconCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	detailIconCorner.Parent = detailIcon

	local detailName = Instance.new("TextLabel")
	detailName.Name = "DetailName"
	detailName.Position = UDim2.new(0, 200, 0, 44)
	detailName.Size = UDim2.new(1, -200, 0, 44)
	detailName.BackgroundTransparency = 1
	detailName.Font = Enum.Font.GothamBold
	detailName.TextScaled = true
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.TextColor3 = Color3.new(1, 1, 1)
	detailName.Text = ""
	detailName.Parent = detailPanel

	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Position = UDim2.new(0, 200, 0, 96)
	statsContainer.Size = UDim2.new(1, -200, 0, 168)
	statsContainer.BackgroundTransparency = 1
	statsContainer.Parent = detailPanel

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, 6)
	statsLayout.Parent = statsContainer

	statRow("Damage", "Damage", DAMAGE_COLOR, 1).Parent = statsContainer
	statRow("FireRate", "Fire Rate", FIRE_RATE_COLOR, 2).Parent = statsContainer
	statRow("Magazine", "Magazine", AMMO_COLOR, 3).Parent = statsContainer
	statRow("Range", "Range", RANGE_COLOR, 4).Parent = statsContainer

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Position = UDim2.new(0, 0, 0, 240)
	priceLabel.Size = UDim2.fromOffset(180, 40)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextScaled = true
	priceLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	priceLabel.Text = ""
	priceLabel.Parent = detailPanel

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Position = UDim2.new(0, 0, 0, 290)
	actionButton.Size = UDim2.fromOffset(180, 60)
	actionButton.BackgroundColor3 = BUY_COLOR
	actionButton.Font = Enum.Font.GothamBold
	actionButton.TextScaled = true
	actionButton.TextColor3 = Color3.new(1, 1, 1)
	actionButton.Text = "BUY"
	actionButton.Parent = detailPanel

	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0.2, 0)
	actionCorner.Parent = actionButton

	root.Parent = templates
end

-- ============================================
-- WeaponCard (cloned once per weapon shown in the grid)
-- ============================================
do
	local card = Instance.new("ImageButton")
	card.Name = "WeaponCard"
	card.BackgroundColor3 = PANEL_COLOR
	card.BackgroundTransparency = 0.1
	card.Image = ""
	card.AutoButtonColor = false

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromScale(0.5, 0.06)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Size = UDim2.fromScale(0.8, 0.55)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = ""
	icon.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Position = UDim2.fromScale(0.5, 0.64)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Size = UDim2.fromScale(0.92, 0.2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = ""
	nameLabel.Parent = card

	local priceOrOwned = Instance.new("TextLabel")
	priceOrOwned.Name = "PriceOrOwned"
	priceOrOwned.Position = UDim2.fromScale(0.5, 0.85)
	priceOrOwned.AnchorPoint = Vector2.new(0.5, 0)
	priceOrOwned.Size = UDim2.fromScale(0.92, 0.14)
	priceOrOwned.BackgroundTransparency = 1
	priceOrOwned.Font = Enum.Font.GothamBold
	priceOrOwned.TextScaled = true
	priceOrOwned.TextColor3 = Color3.fromRGB(255, 220, 120)
	priceOrOwned.Text = ""
	priceOrOwned.Parent = card

	card.Parent = templates
end

print("Weaponary shop templates built.")
```

### Verify
- `ReplicatedStorage.GuiTemplates.WeaponaryShop` and `.WeaponCard` both exist with the structure described above.
- Only run this once; re-running duplicates them.

---

## Part 6 — `WeaponaryShopController` (client)

**New `StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**:
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local catalog = ReplicatedStorage.Weapons:WaitForChild("Catalog")
local buyRequest = ReplicatedStorage.Weapons.Remotes.BuyRequest
local upgradeRequest = ReplicatedStorage.Weapons.Remotes.UpgradeRequest
local UpgradeConfig = require(ReplicatedStorage.Weapons.UpgradeConfig)

local MAX_OWNED_WEAPONS = 4
local FADE_TIME = 0.25

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
local detailIcon = detailPanel:WaitForChild("DetailIcon")
local detailName = detailPanel:WaitForChild("DetailName")
local statsContainer = detailPanel:WaitForChild("StatsContainer")
local priceLabel = detailPanel:WaitForChild("PriceLabel")
local actionButton = detailPanel:WaitForChild("ActionButton")

local BUY_COLOR = Color3.fromRGB(50, 200, 90)
local UPGRADE_COLOR = Color3.fromRGB(200, 45, 45)

local isOpen = false
local pendingBuyWeapon: string? = nil -- set while waiting for the player to pick a slot to swap out

-- ============================================
-- OWNERSHIP HELPERS
-- ============================================
local function getOwnedTools(): { Tool }
	local tools = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					table.insert(tools, child)
				end
			end
		end
	end
	return tools
end

local function isOwned(weaponName: string): boolean
	for _, tool in getOwnedTools() do
		if tool.Name == weaponName then
			return true
		end
	end
	return false
end

-- ============================================
-- INVENTORY COLUMN (also the swap picker)
-- ============================================
local function refreshInventoryColumn()
	local owned = getOwnedTools()
	for i = 1, 4 do
		local slot = slotsContainer:FindFirstChild("Slot" .. i) :: ImageButton
		local icon = slot:WaitForChild("Icon") :: ImageLabel
		local nameLabel = slot:WaitForChild("NameLabel") :: TextLabel
		local emptyLabel = slot:WaitForChild("EmptyLabel") :: TextLabel

		local tool = owned[i]
		if tool then
			icon.Image = tool.TextureId
			nameLabel.Text = tool.Name
			icon.Visible = true
			nameLabel.Visible = true
			emptyLabel.Visible = false
		else
			icon.Image = ""
			nameLabel.Text = ""
			icon.Visible = false
			nameLabel.Visible = false
			emptyLabel.Visible = true
		end
	end
end

local function setSwapMode(active: boolean)
	swapPrompt.Visible = active
	for i = 1, 4 do
		local slot = slotsContainer:FindFirstChild("Slot" .. i) :: ImageButton
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		if active and slot:FindFirstChild("EmptyLabel") and not slot.EmptyLabel.Visible then
			TweenService:Create(slot, tweenInfo, { BackgroundTransparency = 0.6 }):Play()
		else
			TweenService:Create(slot, TweenInfo.new(0.15), { BackgroundTransparency = 0.3 }):Play()
		end
	end
end

for i = 1, 4 do
	local slot = slotsContainer:WaitForChild("Slot" .. i) :: ImageButton
	slot.MouseButton1Click:Connect(function()
		if not pendingBuyWeapon then
			return
		end
		local owned = getOwnedTools()
		local target = owned[i]
		if not target then
			return -- can't swap into an already-empty slot; buying should have gone through directly
		end
		buyRequest:FireServer(pendingBuyWeapon, target.Name)
		pendingBuyWeapon = nil
		setSwapMode(false)
	end)
end

-- ============================================
-- WEAPON GRID
-- ============================================
local currentCategory = "All"

local function formatFireRate(rpm: number): string
	return `{rpm} RPM`
end

local function showDetail(weaponName: string)
	local entry = catalog:FindFirstChild(weaponName)
	if not entry then
		return
	end

	weaponGrid.Visible = false
	detailPanel.Visible = true

	detailIcon.Image = entry:GetAttribute("iconId") or ""
	detailName.Text = weaponName

	statsContainer.Damage.Value.Text = tostring(entry:GetAttribute("damage"))
	statsContainer.FireRate.Value.Text = formatFireRate(entry:GetAttribute("rateOfFire"))
	statsContainer.Magazine.Value.Text = tostring(entry:GetAttribute("magazineSize"))
	statsContainer.Range.Value.Text = tostring(entry:GetAttribute("range"))

	if isOwned(weaponName) then
		local level = player:GetAttribute(UpgradeConfig.attributeFor(weaponName)) or 0
		local nextLevel = level + 1
		local cost = UpgradeConfig.COST_PER_LEVEL * nextLevel
		priceLabel.Text = `Upgrade cost: \u{1F4B0}{cost}`
		actionButton.Text = `UPGRADE (Lv.{nextLevel})`
		actionButton.BackgroundColor3 = UPGRADE_COLOR
	else
		local price = entry:GetAttribute("Price")
		priceLabel.Text = `\u{1F4B0}{price}`
		actionButton.Text = "BUY"
		actionButton.BackgroundColor3 = BUY_COLOR
	end

	local function onAction()
		if isOwned(weaponName) then
			upgradeRequest:FireServer(weaponName)
			task.delay(0.1, function()
				if detailPanel.Visible and detailName.Text == weaponName then
					showDetail(weaponName) -- refresh the shown level/cost after the purchase resolves
				end
			end)
			return
		end

		if #getOwnedTools() >= MAX_OWNED_WEAPONS then
			pendingBuyWeapon = weaponName
			setSwapMode(true)
			return
		end

		buyRequest:FireServer(weaponName, nil)
	end

	if actionButton:GetAttribute("connected") ~= true then
		actionButton:SetAttribute("connected", true)
		actionButton.MouseButton1Click:Connect(function()
			onAction()
		end)
	end
	-- Rebinding the click handler on every showDetail call would stack duplicate connections; the
	-- attribute guard above ensures it's only ever connected once, and onAction always reads the
	-- CURRENT weaponName via the closure captured at the time of the click, not a stale one --
	-- because this whole function is redefined fresh each time showDetail runs.
end

backButton.MouseButton1Click:Connect(function()
	detailPanel.Visible = false
	weaponGrid.Visible = true
	if pendingBuyWeapon then
		pendingBuyWeapon = nil
		setSwapMode(false)
	end
end)

local function buildGrid()
	for _, child in weaponGrid:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	local order = 0
	for _, entry in catalog:GetChildren() do
		local category = entry:GetAttribute("Category")
		if currentCategory == "All" or category == currentCategory then
			order += 1
			local card = guiTemplates.WeaponCard:Clone()
			card.LayoutOrder = order
			card.Name = entry.Name
			card:WaitForChild("Icon").Image = entry:GetAttribute("iconId") or ""
			card:WaitForChild("NameLabel").Text = entry.Name

			local priceOrOwned = card:WaitForChild("PriceOrOwned") :: TextLabel
			if isOwned(entry.Name) then
				priceOrOwned.Text = "OWNED"
				priceOrOwned.TextColor3 = Color3.fromRGB(120, 220, 140)
			else
				priceOrOwned.Text = `\u{1F4B0}{entry:GetAttribute("Price")}`
				priceOrOwned.TextColor3 = Color3.fromRGB(255, 220, 120)
			end

			card.MouseButton1Click:Connect(function()
				showDetail(entry.Name)
			end)

			card.Parent = weaponGrid
		end
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
local function openShop()
	if isOpen then
		return
	end
	isOpen = true
	shop.Visible = true
	shop.Size = UDim2.fromOffset(870, 545)
	refreshInventoryColumn()
	buildGrid()
	detailPanel.Visible = false
	weaponGrid.Visible = true

	TweenService:Create(
		shop,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(920, 580) }
	):Play()
end

local function closeShop()
	if not isOpen then
		return
	end
	isOpen = false
	pendingBuyWeapon = nil
	setSwapMode(false)

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

closeButton.MouseButton1Click:Connect(closeShop)

-- Keep the inventory column and any open detail/grid state honest while the shop is open, since
-- a purchase resolving mid-browse should be reflected immediately, not only on next open.
local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(function()
	if isOpen then
		refreshInventoryColumn()
		buildGrid()
	end
end)
backpack.ChildRemoved:Connect(function()
	if isOpen then
		refreshInventoryColumn()
		buildGrid()
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
```

### Verify
- Opening the shop (button or `B`) shows a pop-in scale animation; closing fades/shrinks back out — matches the animation style already used elsewhere in this game's HUD.
- The left column shows your actual current 4 (or fewer) owned weapons live, including the free starting Crowbar.
- Clicking a category tab filters the grid correctly; "All" shows every sellable weapon.
- Clicking a weapon card shows its real stats (compare against its live `ServerStorage.Weapons` attributes) and the correct button: green "BUY" with the right price if unowned, red "UPGRADE (Lv.N)" with the right cost if owned.
- Buying with fewer than 4 owned: weapon appears immediately in the left column and in Backpack, card in the grid flips to "OWNED".
- Buying while at 4/4: the 4 slots visibly pulse/highlight and the swap prompt appears; clicking one completes the swap (old weapon gone, new one in its place); clicking Back or closing the shop cancels the pending swap instead of leaving it stuck armed.
- Upgrading: cost/level shown updates immediately after a successful upgrade, without needing to close and reopen the detail panel.
- Pressing `B` while typing in an unrelated text box (if any exist) doesn't unexpectedly toggle the shop — not expected to be an issue here since this project has no other text input while playing, but worth a quick sanity check.

---

## Part 7 — Hotbar: cap at 4, remove the old inventory button, add the shop trigger

**`StarterGui."Custom Inventory".InventoryController.SETTINGS`**:
```lua
local module = {OBJECTS = {}, SETTINGS = {}, slotAmount = 4}
```
(was `6`.)
```lua
SETTINGS.INVENTORY_KEYBIND = nil
```
(was `Enum.KeyCode.Backquote` — this is the module's own documented, already-supported way to disable the overflow Inventory panel's keybind, not a new mechanism.)

**`StarterGui."Custom Inventory".InventoryController`** — guard the `openButton` reference so removing the button doesn't error, since the code currently indexes it unconditionally:
```lua
local openButton = CustomInventoryGUI:FindFirstChild("openButton")
if openButton then
	if inventoryHandler.SETTINGS.OPEN_BUTTON then
		openButton.MouseButton1Down:Connect(function()
			Inventory.Visible = not Inventory.Visible
			local currentState = Inventory.Visible

			inventoryHandler:removeCurrentDescription()
			if currentState then
				showSlots()
			else
				if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
					removeEmptySlots()
				end
			end
		end)
	else
		openButton.Visible = false
	end
end
```
(replaces the existing unconditional `if inventoryHandler.SETTINGS.OPEN_BUTTON then CustomInventoryGUI.openButton... else CustomInventoryGUI.openButton.Visible = false end` block.)

**`StarterGui."Custom Inventory".openButton`** — delete this instance entirely.

**Add the new shop-trigger button**, matching the existing top-right button-stack convention (`openButton` used to occupy this exact slot; `playerCardButton` already sits stacked below where `openButton` was):
```lua
local StarterGui = game:GetService("StarterGui")
local inventoryGui = StarterGui:WaitForChild("Custom Inventory")
local playerCardButton = inventoryGui:WaitForChild("playerCardButton")

local button = Instance.new("ImageButton")
button.Name = "weaponaryButton"
button.AnchorPoint = Vector2.new(1, 0)
button.Position = UDim2.new(1, -20, 0, 20) -- openButton's old slot, now free
button.Size = UDim2.fromOffset(48, 48)
button.BackgroundColor3 = playerCardButton.BackgroundColor3
button.BackgroundTransparency = playerCardButton.BackgroundTransparency
button.Image = ""
button.Parent = inventoryGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.2, 0)
corner.Parent = button

local icon = Instance.new("TextLabel")
icon.Name = "icon"
icon.BackgroundTransparency = 1
icon.Size = UDim2.fromScale(1, 1)
icon.Font = Enum.Font.BuilderSans
icon.TextScaled = true
icon.TextColor3 = Color3.new(1, 1, 1)
icon.Text = "\u{1F52B}" -- pistol emoji, matching the placeholder-glyph convention used for the other two buttons
icon.Parent = button
```
`playerCardButton` should be nudged up into the slot `weaponaryButton` now sits above of, so the stack still reads top-to-bottom cleanly — set `playerCardButton.Position = UDim2.new(1, -20, 0, 78)` (unchanged from before, already in the second slot) and confirm `weaponaryButton` sits at the first (top) slot where `openButton` used to be; no further repositioning needed since `openButton`'s old slot is exactly where `weaponaryButton` now goes.

### Verify
- Owning exactly 4 weapons fills all 4 hotbar slots with no overflow; the old scrollable Inventory panel never has anything in it to show (confirm by trying the now-`nil` keybind does nothing, as expected).
- The old backpack-emoji `openButton` is gone from the top-right corner.
- A new button (top-right, same slot `openButton` used to occupy) opens the Weaponary shop; `playerCardButton` still works directly beneath it.
- Pressing `B` also opens/closes the shop.
- Number keys 1-4 still equip the correct hotbar slot; nothing is bound to 5/6 anymore (expected).

## Verification checklist

- [ ] All 16 weapons have correct `Category`; 15 have `Price`, Crowbar has none.
- [ ] Every player starts with a Crowbar via `StarterPack`, every spawn, no shop interaction needed.
- [ ] Workspace has zero weapon pickups left; all 16 archived in `ServerStorage.ArchivedWeaponPickups`; `WeaponPickup.lua` and `WeaponStatBillboard.lua` deleted with no resulting errors.
- [ ] `BuyRequest` correctly enforces: can't buy what you already own, can't exceed 4 owned even via a bogus/missing swap target, can't buy without enough cash, upgrade levels persist through a sell-and-rebuy.
- [ ] Shop UI: category filtering, stat display, Buy→Upgrade button transition, swap-picker flow, and open/close animations all work as described.
- [ ] Old inventory button removed; hotbar capped at 4; new shop button + `B` keybind both work; `playerCardButton` unaffected.
