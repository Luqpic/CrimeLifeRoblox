# Prompt: Weapon Stat Billboard + Cash Currency + Damage Upgrades

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Scope and interpretation calls made before writing this

- The reference photo is a full gun-shop panel (upgrade slots, rebirth locks, equip-to-slot) from a different game — used here only for its **visual language** (colored stat pills: purple/damage, green/ammo, orange/fire-rate, bold name header), not as a literal spec. The request itself explicitly asks for something simpler ("Just use a simple clean UI... Create a simple cash currency for now"), so none of the rebirth/lock/slot machinery from the photo is built here.
- The billboard (stats) and the upgrade action are combined into **one** panel, not two separate systems — the photo shows them combined, and building a second separate screen-space shop UI for upgrades alone would be more machinery than "simple... for now" calls for. If a separate full-screen shop is actually wanted later, that's an easy follow-up once this is in and confirmed working.
- Currency needs a way to be earned, or upgrades are permanently unusable from the first session — added a small, clearly-flagged kill-reward hook (reusing an event that already exists) since "create a simple cash currency" without any way to gain it would ship a non-functional feature.
- "For every level, increase the same number as that level into damage" is read as `bonusDamage = level` (flat, not cumulative-sum) — level 3 means +3 damage total, not +1+2+3.
- Upgrades are **per-player, per-weapon-type** (not per Tool instance) — given weapons are lost on every death under the current pickup system, tying upgrades to a specific Tool instance would wipe all progress on the next death, which can't be the intent of a purchased upgrade. "For now" (no DataStore) means this resets when the server restarts, matching the currency's own stated scope.
- Cost formula (`50 * nextLevel`, no level cap) and starting cash (`500`) are unspecified in the request — reasonable placeholders, flagged as tunable, not final balance.

## Architecture note — why this can't just read `ServerStorage.Weapons` from the client

`ServerStorage` never replicates to clients at all — a LocalScript cannot see anything under it, not even to read an Attribute. Since the billboard is a client-side UI that needs to display a weapon's stats, those stats have to be mirrored onto something that *does* replicate — the pickup Model itself, which already lives in `Workspace`. `WeaponPickup.lua` is extended below to do exactly that, once per pickup at server start.

---

## Part 1 — Cash currency

**New script: `ServerScriptService.Weapons.Scripts.CashService`**
```lua
-- Cash currency: native leaderstats (shows automatically in the default Roblox leaderboard, no
-- custom HUD needed for "simple... for now"), plus a kill reward -- the only way to earn cash
-- today. Included even though only the currency itself was explicitly requested, because a
-- currency with no way to increase it would make the upgrade system in Part 2 permanently unusable.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(game.ReplicatedStorage.Enemy.Constants)

local STARTING_CASH = 500
local CASH_PER_KILL = 50

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Reuses the existing Eliminated BindableEvent ShotResolver already fires on every kill (player
-- or enemy shooter) -- no new event needed.
local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated
eliminatedEvent.Event:Connect(function(shooter: Player | Model, humanoid: Humanoid)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end

	-- Only reward eliminating an enemy, never another player, so this can't be farmed via PvP.
	local character = humanoid.Parent
	if not (character and CollectionService:HasTag(character, Constants.ENEMY_TAG)) then
		return
	end

	local leaderstats = shooter:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value += CASH_PER_KILL
	end
end)
```

### Verify
- Join: `Cash 500` appears in the native leaderboard (Tab).
- Kill an enemy: Cash increases by 50. Killing another player (if ever relevant) does not award cash.

---

## Part 2 — Weapon damage upgrades

**New RemoteEvent: `ReplicatedStorage.Weapons.Remotes.UpgradeRequest`**

**New script: `ServerScriptService.Weapons.Scripts.WeaponUpgradeService`**
```lua
-- Spends Cash to raise a player's damage upgrade level for one weapon TYPE (not one Tool
-- instance). Damage bonus is always recomputed as stock damage + level, read fresh from
-- ServerStorage.Weapons each time -- never incrementally added to whatever a Tool's current
-- damage attribute happens to be -- so repeated upgrades can't drift or double-apply.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)

local WEAPONS_FOLDER = ServerStorage.Weapons
local upgradeRequest = ReplicatedStorage.Weapons.Remotes.UpgradeRequest

local COST_PER_LEVEL = 50 -- cost of level N is COST_PER_LEVEL * N; keep in sync with the billboard's own copy of this constant

local function upgradeAttributeName(weaponName: string): string
	return "WeaponUpgrade_" .. weaponName
end

-- Applies the new level to every instance of this weapon the player currently holds (equipped or
-- in the backpack), so an upgrade takes effect immediately rather than only on the next pickup.
local function applyToHeldWeapons(player: Player, weaponName: string, stockDamage: number, newLevel: number)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		local tool = container and container:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			tool:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + newLevel)
		end
	end
end

upgradeRequest.OnServerEvent:Connect(function(player: Player, weaponName: any)
	if typeof(weaponName) ~= "string" then
		return
	end

	local stockTemplate = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (stockTemplate and stockTemplate:IsA("Tool")) then
		return
	end
	local stockDamage = stockTemplate:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
	if typeof(stockDamage) ~= "number" then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash then
		return
	end

	local currentLevel = player:GetAttribute(upgradeAttributeName(weaponName)) or 0
	local nextLevel = currentLevel + 1
	local cost = COST_PER_LEVEL * nextLevel
	if cash.Value < cost then
		return
	end

	cash.Value -= cost
	player:SetAttribute(upgradeAttributeName(weaponName), nextLevel)
	applyToHeldWeapons(player, weaponName, stockDamage, nextLevel)
end)
```

### Verify
- With enough Cash, upgrading a weapon type raises its damage by exactly the new level, both on a currently-held copy and on the next fresh pickup.
- Without enough Cash, the request is silently rejected (no partial deduction, no level increment).
- Losing the weapon (dying) and picking a fresh one back up from any station of that type still carries the upgrade — it's tied to the player, not the Tool instance.

---

## Part 3 — Extend `WeaponPickup.lua`: mirror display stats, apply upgrades to fresh pickups

Add near the top (alongside existing requires):
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)

local DISPLAY_ATTRIBUTES = { "damage", "rateOfFire", "magazineSize" }

-- Copies stock display stats onto the pickup Model itself, since ServerStorage never replicates
-- to clients and the billboard (Part 4) needs somewhere client-visible to read them from.
local function mirrorDisplayStats(pickup: Instance, template: Tool)
	for _, attributeName in DISPLAY_ATTRIBUTES do
		pickup:SetAttribute(attributeName, template:GetAttribute(attributeName))
	end
end
```

In `setupPickup(pickup)`, after resolving the `Weapon` StringValue (or add the lookup if not already local there), mirror the stats once:
```lua
local weaponValue = pickup:FindFirstChild("Weapon")
local template = weaponValue and weaponValue:IsA("StringValue") and WEAPONS_FOLDER:FindFirstChild(weaponValue.Value)
if template and template:IsA("Tool") then
	mirrorDisplayStats(pickup, template)
end
```

In `onTriggered`, after cloning (`local weapon = template:Clone()`) but before parenting it into the backpack, apply the player's existing upgrade level so a fresh pickup already reflects prior progress:
```lua
local upgradeLevel = player:GetAttribute("WeaponUpgrade_" .. weaponName) or 0
if upgradeLevel > 0 then
	local stockDamage = template:GetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE)
	if typeof(stockDamage) == "number" then
		weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + upgradeLevel)
	end
end
```

### Verify
- Every pickup Model in `Workspace` has `damage`/`rateOfFire`/`magazineSize` attributes matching its `ServerStorage.Weapons` counterpart, visible in Studio's Properties/Attributes panel without needing Play mode.
- A player who has upgraded a weapon type, then dies and picks it back up from a station, receives a weapon whose damage already includes the upgrade.

---

## Part 4 — Stat + upgrade billboard

**New script: `StarterPlayer.StarterPlayerScripts.WeaponStatBillboard` (LocalScript)**
```lua
-- Floating stat panel above each weapon pickup: name, damage (including this player's own
-- upgrade level), ammo, fire rate, a placeholder icon, and an upgrade button. Built procedurally
-- rather than as a separate GUI asset, so there's nothing extra to keep in sync by hand.
--
-- Reads stats from the Attributes WeaponPickup.lua mirrors onto the pickup Model -- see the
-- architecture note at the top of this document for why that's necessary.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local upgradeRequest = ReplicatedStorage.Weapons.Remotes.UpgradeRequest

local PICKUP_TAG = "WeaponPickup"
local COST_PER_LEVEL = 50 -- must match WeaponUpgradeService.lua's own COST_PER_LEVEL

local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
local DAMAGE_COLOR = Color3.fromRGB(120, 90, 230)
local AMMO_COLOR = Color3.fromRGB(90, 200, 100)
local FIRE_RATE_COLOR = Color3.fromRGB(230, 165, 60)

local function upgradeAttributeName(weaponName: string): string
	return "WeaponUpgrade_" .. weaponName
end

local function createStatRow(parent: Instance, labelText: string, color: Color3, layoutOrder: number): TextLabel
	local row = Instance.new("Frame")
	row.Name = labelText
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundColor3 = color
	row.BackgroundTransparency = 0.15
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.45, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "  " .. labelText
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Size = UDim2.new(0.55, -8, 1, 0)
	value.Position = UDim2.new(0.45, 0, 0, 0)
	value.Font = Enum.Font.GothamBold
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Parent = row

	return value
end

local function buildBillboard(pickup: Model)
	local weaponValue = pickup:FindFirstChild("Weapon")
	if not (weaponValue and weaponValue:IsA("StringValue")) then
		return
	end
	local weaponName = weaponValue.Value

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatPanel"
	billboard.Size = UDim2.new(4.5, 0, 3.4, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 20 -- native distance-based show/hide; no proximity script needed
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = pickup.PrimaryPart
	billboard.Parent = pickup

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	panel.Parent = billboard

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0.08, 0)
	panelCorner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 46)
	header.LayoutOrder = 1
	header.Parent = panel

	-- Placeholder icon: no icon asset provided. Left blank with a neutral backing square rather
	-- than nothing, matching the crowbar/inventory icon fallback convention already used
	-- elsewhere in this project -- swap in a real Image once one exists.
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 46, 0, 46)
	icon.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	icon.Image = ""
	icon.Parent = header

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0.15, 0)
	iconCorner.Parent = icon

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 56, 0, 0)
	nameLabel.Size = UDim2.new(1, -56, 1, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = weaponName
	nameLabel.Parent = header

	local damageValue = createStatRow(panel, "Damage", DAMAGE_COLOR, 2)
	local ammoValue = createStatRow(panel, "Ammo", AMMO_COLOR, 3)
	local fireRateValue = createStatRow(panel, "Fire Rate", FIRE_RATE_COLOR, 4)

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Size = UDim2.new(1, 0, 0, 30)
	upgradeButton.LayoutOrder = 5
	upgradeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	upgradeButton.Font = Enum.Font.GothamBold
	upgradeButton.TextScaled = true
	upgradeButton.TextColor3 = Color3.new(1, 1, 1)
	upgradeButton.Parent = panel

	local upgradeCorner = Instance.new("UICorner")
	upgradeCorner.CornerRadius = UDim.new(0.3, 0)
	upgradeCorner.Parent = upgradeButton

	local function refresh()
		local stockDamage = pickup:GetAttribute("damage") or 0
		local level = player:GetAttribute(upgradeAttributeName(weaponName)) or 0
		local rateOfFire = pickup:GetAttribute("rateOfFire") or 0
		local magazineSize = pickup:GetAttribute("magazineSize") or 0

		if level > 0 then
			damageValue.Text = `{stockDamage + level} (+{level})`
		else
			damageValue.Text = tostring(stockDamage)
		end
		ammoValue.Text = tostring(magazineSize)
		fireRateValue.Text = `{rateOfFire} RPM`

		local nextLevel = level + 1
		local cost = COST_PER_LEVEL * nextLevel
		upgradeButton.Text = `Upgrade Damage (Lv.{nextLevel}) - ${cost}`
	end

	refresh()
	pickup:GetAttributeChangedSignal("damage"):Connect(refresh)
	player:GetAttributeChangedSignal(upgradeAttributeName(weaponName)):Connect(refresh)

	upgradeButton.MouseButton1Click:Connect(function()
		upgradeRequest:FireServer(weaponName)
	end)
end

for _, pickup in CollectionService:GetTagged(PICKUP_TAG) do
	buildBillboard(pickup)
end
CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(buildBillboard)
```

### Verify
- Approach any of the 16 pickups: a dark rounded panel appears above it within ~20 studs, showing the weapon's name, colored Damage/Ammo/Fire Rate rows (matching the reference photo's color language), a gray placeholder icon square, and an "Upgrade Damage (Lv.1) - $50" button — screenshot and confirm it actually renders and is legible, not just structurally present.
- Walking away past 20 studs hides it automatically (native `MaxDistance`, no script needed to verify beyond confirming the value).
- Clicking the upgrade button with enough Cash: damage row updates to show the bonus, button text advances to the next level/cost, Cash decreases.
- Two different pickups of weapons the player has *not* upgraded show `Lv.1` and no `(+N)` suffix; a weapon type already upgraded shows the correct current bonus on every station of that type, not just the one it was purchased at.

## Verification checklist

- [ ] Cash currency visible in the leaderboard, increases on enemy kills only.
- [ ] Upgrade purchase deducts cost, raises damage by exactly the new level, applies to held weapons immediately and to future pickups of that type.
- [ ] Pickup Models carry mirrored `damage`/`rateOfFire`/`magazineSize` attributes.
- [ ] Billboard appears/disappears by distance, shows correct live stats, upgrade button works and updates immediately.
- [ ] No changes to weapon stats for players who haven't upgraded anything.
