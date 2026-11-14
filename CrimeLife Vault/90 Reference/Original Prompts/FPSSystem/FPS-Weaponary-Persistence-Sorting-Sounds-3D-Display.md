# Prompt: Weapon Ownership Persistence, Price-Sorted Shop, Purchase/Upgrade Sounds, 3D Rotating Weapon Display

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Context, confirmed live before writing this — read this first

**The inventory-reset bug, reproduced live, not assumed:** granted a player a Deagle directly (bypassing the shop), killed their character, waited for the actual new character to spawn, then checked `Backpack` contents. Result: only `Crowbar` survived — the Deagle was gone. This place's respawn flow does **not** preserve `Backpack` contents across death on its own; nothing in `WeaponShopService` or `EquipService` was clearing it either — the respawn itself wipes it down to whatever `StarterPack` re-grants. Fixing this means treating ownership as data that's *tracked and restored*, not assumed to persist by default.

**A correction to the previous prompt's own design, found while fixing this:** that prompt cloned `Crowbar` into `StarterPack` so every spawn would re-grant it — but it also let `Crowbar` count toward nothing (the ownership cap only ever looked at live `Backpack`/`Character` contents, which happened to include Crowbar, but the *tracked* ownership model below doesn't naturally extend to something granted by a completely separate mechanism). Rather than keep two different code paths for "how a player ends up holding a weapon" (`StarterPack` engine behavior for Crowbar, tracked-and-restored for everything else), this folds Crowbar into the *same* ownership-tracking-and-restore system as purchased weapons — it's simply seeded as already-owned the moment a player joins. One mechanism, no special case, and it correctly counts as one of the 4 slots (so a player owns Crowbar + up to 3 purchased weapons by default, and can swap the Crowbar itself away for a 4th purchased weapon if they want an all-gun loadout).

**3D display, confirmed feasible live:** `ServerStorage.Weapons.<name>.Blaster` (e.g. inspected `AK47.Blaster`) is a clean, self-contained `Model` of plain `MeshPart`s (`Body`, `Trim*`, `Magazine`, etc.) with no rig, animation, or joint dependency — safe to clone and spin freely in a `ViewportFrame`.

---

## Part 1 — Revert the `StarterPack` Crowbar grant

**`StarterPack`** — delete the `Crowbar` Tool that was added there. It's superseded by Part 2's unified ownership system.
```lua
local StarterPack = game:GetService("StarterPack")
local existing = StarterPack:FindFirstChild("Crowbar")
if existing then
	existing:Destroy()
end
```

### Verify
- `StarterPack` has no `Crowbar` child afterward.

---

## Part 2 — `WeaponShopService`: track ownership, restore on every respawn, sort-friendly catalog, 3D model

Replace the entire script with:
```lua
-- Three responsibilities: (1) build a replicated read-only catalog of sellable weapons once at
-- server start, since ServerStorage never replicates and the shop needs to show stats/prices/a 3D
-- model for weapons the player doesn't own yet; (2) track weapon ownership per player for the
-- session and restore it on every respawn -- this place's respawn flow does NOT preserve Backpack
-- contents on its own, confirmed live (a manually-granted weapon vanished after one death/respawn
-- cycle, leaving only whatever StarterPack used to re-grant). Ownership here is the single source
-- of truth; the Backpack is a disposable view of it, rebuilt every spawn. Crowbar is seeded as
-- already-owned for every player, going through the exact same restore path as anything bought --
-- not a separate StarterPack grant -- so there is only ever one mechanism for "how a player ends up
-- holding a weapon"; (3) handle purchase requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local UpgradeConfig = require(ReplicatedStorage.Weapons.UpgradeConfig)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local WEAPONS_FOLDER = ServerStorage.Weapons
local buyRequest = ReplicatedStorage.Weapons.Remotes.BuyRequest

local MAX_OWNED_WEAPONS = 4

-- ============================================
-- CATALOG (built once, read by every client's shop UI)
-- ============================================
local previousCatalog = ReplicatedStorage.Weapons:FindFirstChild("Catalog")
if previousCatalog then
	previousCatalog:Destroy()
end

local catalogFolder = Instance.new("Folder")
catalogFolder.Name = "Catalog"

local CATALOG_ATTRIBUTES = { "Category", "Price", "damage", "rateOfFire", "magazineSize", "range" }

for _, template in WEAPONS_FOLDER:GetChildren() do
	if template:IsA("Tool") and template:GetAttribute("Price") then
		local entry = Instance.new("Folder")
		entry.Name = template.Name
		for _, attrName in CATALOG_ATTRIBUTES do
			entry:SetAttribute(attrName, template:GetAttribute(attrName))
		end
		entry:SetAttribute("iconId", template.TextureId)

		-- A standalone copy of the weapon's visual body, for the shop's 3D rotating display.
		-- Confirmed live: a clean MeshPart assembly, no rig/animation dependency, safe to clone.
		local blaster = template:FindFirstChild("Blaster")
		if blaster then
			blaster:Clone().Parent = entry
		end

		entry.Parent = catalogFolder
	end
end

catalogFolder.Parent = ReplicatedStorage.Weapons

-- ============================================
-- OWNERSHIP (session-only, matches how Cash/Leveling already work -- no DataStore)
-- ============================================
local ownedWeapons: { [Player]: { [string]: boolean } } = {}

-- Clones a fresh copy of a weapon, with the player's current upgrade level already applied, into
-- the given container. Shared by both a fresh purchase and a post-respawn restore (Crowbar
-- included), so "upgrade level carries onto a new clone" can't drift between the two call sites.
local function grantWeapon(player: Player, weaponName: string, container: Instance)
	local template = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		return
	end

	local weapon = template:Clone()
	local upgradeLevel = player:GetAttribute(UpgradeConfig.attributeFor(weaponName)) or 0
	if upgradeLevel > 0 then
		local stockDamage = template:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
		if typeof(stockDamage) == "number" then
			weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + upgradeLevel)
		end
	end
	weapon.Parent = container
end

local function restoreOwnedWeapons(player: Player)
	local owned = ownedWeapons[player]
	if not owned then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for weaponName in owned do
		grantWeapon(player, weaponName, backpack)
	end
end

safePlayerAdded(function(player: Player)
	ownedWeapons[player] = { Crowbar = true } -- everyone starts owning the free melee weapon

	player.CharacterAdded:Connect(function()
		restoreOwnedWeapons(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	ownedWeapons[player] = nil
end)

-- ============================================
-- BUY HANDLING
-- ============================================
local function isWeaponOwned(player: Player, weaponName: string): boolean
	local owned = ownedWeapons[player]
	return owned ~= nil and owned[weaponName] == true
end

local function countOwnedWeapons(player: Player): number
	local owned = ownedWeapons[player]
	if not owned then
		return 0
	end
	local count = 0
	for _ in owned do
		count += 1
	end
	return count
end

local function findLiveTool(player: Player, weaponName: string): Tool?
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

	if isWeaponOwned(player, weaponName) then
		return -- already own it -- the client should be sending UpgradeRequest instead
	end

	-- Validated BEFORE anything is destroyed or charged: a client cannot swap out a weapon it
	-- doesn't actually own (Crowbar included), which would otherwise be a free extra slot.
	if swapOutWeaponName and not isWeaponOwned(player, swapOutWeaponName) then
		return
	end

	local currentCount = countOwnedWeapons(player)
	local projectedCount = currentCount - (swapOutWeaponName and 1 or 0) + 1
	if projectedCount > MAX_OWNED_WEAPONS then
		return -- still over the cap even with the proposed swap; client should have asked for one
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < price then
		return
	end

	local owned = ownedWeapons[player]
	if not owned then
		return
	end

	if swapOutWeaponName then
		local swapOutTool = findLiveTool(player, swapOutWeaponName)
		if swapOutTool then
			swapOutTool:Destroy()
		end
		owned[swapOutWeaponName] = nil
	end

	cash.Value -= price
	owned[weaponName] = true

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		grantWeapon(player, weaponName, backpack)
	end
end)
```

### Verify
- Buy a weapon, die, respawn: the purchased weapon (and Crowbar) are both back in the Backpack, with no duplicate Crowbars and nothing lost.
- Repeat across several deaths in a row: ownership stays exactly correct each time, never accumulating extras or dropping anything.
- A player who has never bought anything still starts with exactly one Crowbar, every single spawn, counted as 1 of their 4 slots.
- Buying with only Crowbar owned (3 free slots): succeeds directly, no swap prompt.
- Buying a 4th purchased weapon while already owning Crowbar + 3 purchased: requires a swap, same as before; swapping the Crowbar itself away for a 4th gun works correctly and it does not silently come back on the next respawn (since it's removed from the tracked set, not just the live Backpack).
- Upgrade levels still survive a swap-away-then-buy-back cycle, exactly as before.

---

## Part 3 — Shop grid sorted cheapest to most expensive

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**, in `buildGrid`, replace the card-building loop with one that sorts first:
```lua
local function buildGrid()
	for _, child in weaponGrid:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	local entries = {}
	for _, entry in catalog:GetChildren() do
		local category = entry:GetAttribute("Category")
		if currentCategory == "All" or category == currentCategory then
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
```

### Verify
- The "All" tab lists weapons strictly ascending by price, cheapest first.
- Every category tab's filtered list is also price-sorted, not just "All".

---

## Part 4 — Purchase and upgrade sounds

Still in `WeaponaryShopController`, add near the top (with the other requires/constants):
```lua
local SoundService = game:GetService("SoundService")

local PURCHASE_SOUND_ID = "rbxassetid://17161225362"
local UPGRADE_SOUND_ID = "rbxassetid://127170375041015"

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

-- Set right before firing BuyRequest, cleared once the resulting Backpack change is observed (or
-- after a short timeout if the purchase was rejected and nothing ever arrives). This is what stops
-- the purchase sound from also playing on a silent, no-action respawn restore -- Backpack.ChildAdded
-- fires for that too, and only a genuine buy click should chime.
local awaitingPurchaseSound = false
```
Replace the existing `backpack.ChildAdded` / `backpack.ChildRemoved` connections (the ones that call `refreshInventoryColumn()`/`buildGrid()` while the shop is open) with:
```lua
backpack.ChildAdded:Connect(function(child)
	if awaitingPurchaseSound and child:IsA("Tool") then
		awaitingPurchaseSound = false
		purchaseSound:Play()
	end
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

player.AttributeChanged:Connect(function(attributeName: string)
	if attributeName:match("^WeaponUpgrade_") then
		upgradeSound:Play()
	end
end)
```
In `onAction` (inside `showDetail`), set the flag right before firing the buy request in **both** places it fires — the direct-buy branch and the swap-picker's slot-click handler:
```lua
		if #getOwnedTools() >= MAX_OWNED_WEAPONS then
			pendingBuyWeapon = weaponName
			setSwapMode(true)
			return
		end

		awaitingPurchaseSound = true
		buyRequest:FireServer(weaponName, nil)
```
And in the swap-slot click handler (the loop that binds `slot.MouseButton1Click` for `i = 1, 4`):
```lua
		awaitingPurchaseSound = true
		buyRequest:FireServer(pendingBuyWeapon, target.Name)
		pendingBuyWeapon = nil
		setSwapMode(false)
```
Also reset the flag defensively if the shop closes before a pending purchase ever resolves (e.g. the request was silently rejected), so a stale `true` can't cause a later, unrelated respawn-restore to wrongly chime — in `closeShop`:
```lua
local function closeShop()
	if not isOpen then
		return
	end
	isOpen = false
	pendingBuyWeapon = nil
	awaitingPurchaseSound = false
	setSwapMode(false)
	...
```

### Verify
- Buying a weapon plays the purchase sound exactly once, right as it appears in the inventory column.
- Upgrading a weapon plays the upgrade sound exactly once per click, immediately.
- Dying and respawning (Crowbar and any owned weapons being silently restored) plays **neither** sound — this is the specific case the flag exists to prevent; confirm it doesn't chime.
- Attempt a purchase that should fail (e.g. not enough cash): no sound plays, and a later unrelated respawn doesn't suddenly play one either (confirms the flag doesn't get stuck `true`).

---

## Part 5 — 3D rotating weapon display in the detail panel

**`ReplicatedStorage.GuiTemplates.WeaponaryShop`** — swap the detail panel's icon for a viewport. Run once:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local detailPanel = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel
local oldIcon = detailPanel:FindFirstChild("DetailIcon")

local viewport = Instance.new("ViewportFrame")
viewport.Name = "DetailViewport"
viewport.Position = oldIcon.Position
viewport.Size = oldIcon.Size
viewport.BackgroundColor3 = oldIcon.BackgroundColor3
viewport.BackgroundTransparency = 0
viewport.BorderSizePixel = 0
viewport.Parent = detailPanel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = viewport

if oldIcon then
	oldIcon:Destroy()
end

print("DetailIcon replaced with DetailViewport.")
```

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`** — add `RunService` to the requires:
```lua
local RunService = game:GetService("RunService")
```
Replace `local detailIcon = detailPanel:WaitForChild("DetailIcon")` with:
```lua
local detailViewport = detailPanel:WaitForChild("DetailViewport") :: ViewportFrame
```
Add a module-level local for the active spin connection, alongside `pendingBuyWeapon`:
```lua
local currentSpinConnection: RBXScriptConnection? = nil

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
```
In `showDetail`, replace the old `detailIcon.Image = entry:GetAttribute("iconId") or ""` line with:
```lua
	stopSpin()

	local blasterTemplate = entry:FindFirstChild("Blaster")
	if blasterTemplate then
		local displayModel = blasterTemplate:Clone()
		displayModel.Parent = detailViewport

		-- Center and frame the model generically -- different weapons have very different sizes
		-- and authored pivots, so this reads the model's actual bounding box rather than needing
		-- per-weapon camera tuning.
		local boundsCFrame, boundsSize = displayModel:GetBoundingBox()
		displayModel:PivotTo(CFrame.new(-boundsCFrame.Position) * displayModel:GetPivot())

		local camera = detailViewport:FindFirstChildOfClass("Camera")
		if not camera then
			camera = Instance.new("Camera")
			camera.Parent = detailViewport
		end
		detailViewport.CurrentCamera = camera
		local distance = boundsSize.Magnitude * 0.9
		camera.CFrame = CFrame.new(Vector3.new(0, 0, distance), Vector3.zero)

		local ROTATION_SPEED = math.rad(40) -- radians/second
		currentSpinConnection = RunService.RenderStepped:Connect(function(dt)
			displayModel:PivotTo(displayModel:GetPivot() * CFrame.Angles(0, ROTATION_SPEED * dt, 0))
		end)
	end
```
Call `stopSpin()` wherever the detail view is left, so a spinning model can never keep rendering (or leak a `RenderStepped` connection) after it's no longer visible — in `backButton`'s handler:
```lua
backButton.MouseButton1Click:Connect(function()
	stopSpin()
	detailPanel.Visible = false
	weaponGrid.Visible = true
	if pendingBuyWeapon then
		pendingBuyWeapon = nil
		setSwapMode(false)
	end
end)
```
And in `closeShop`:
```lua
local function closeShop()
	if not isOpen then
		return
	end
	isOpen = false
	pendingBuyWeapon = nil
	awaitingPurchaseSound = false
	stopSpin()
	setSwapMode(false)
	...
```

### Verify
- Opening a weapon's detail view shows its actual 3D gun model spinning continuously in what used to be the icon box, not a static image.
- Different weapons (a small pistol vs. a large rifle) are both reasonably framed — neither tiny nor clipped — without any per-weapon manual tuning.
- Switching between weapons (via Back then a different card) never leaves two models spinning on top of each other, and never leaves a spin running after leaving the detail view or closing the shop entirely.
- No performance hitch from the rotation — it's a single simple model, this should be unnoticeable, but confirm nothing else in the HUD stutters while the detail panel is open.

## Verification checklist

- [ ] Weapon ownership (Crowbar plus anything purchased) survives death/respawn exactly, no loss and no duplication, across repeated deaths.
- [ ] Shop grid is price-sorted ascending in every category, including "All".
- [ ] Purchase sound plays exactly once per successful buy; upgrade sound plays exactly once per successful upgrade; neither ever plays on a silent respawn-restore.
- [ ] Detail panel shows a real spinning 3D model of the selected weapon instead of a static icon, correctly framed for weapons of very different sizes, with no leaked spin state across weapon switches or shop close.
