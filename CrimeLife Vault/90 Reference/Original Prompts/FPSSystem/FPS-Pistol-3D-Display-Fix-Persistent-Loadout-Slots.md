# Prompt: Pistol 3D Display Rotation Fix + Persistent Ownership with Explicit Loadout Slots

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode
verification). It is self-contained.

## Context — read this first

Two unrelated bugs, both in the Weaponry Shop (`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`
+ `ServerScriptService.Weapons.Scripts.WeaponShopService`). Every claim below was verified live
against the actual running Studio instance immediately before writing this — nothing here is
assumed from older prompt documents.

**A correction to an older document's claim, found while researching this:**
`FPS-Weaponary-Catchup-Owned-Tab-Baton-Viewmodel-Tab-Layout-Stun-Recovery.md` states that `showDetail`
"now derives each model's orientation from its own bounding-box axes... a fixed rotation framed 12 of
17 weapons correctly, the per-model derivation frames 17 of 17" and instructs future work to leave
the orientation block alone. **That is not what the live script contains.** The live
`WeaponaryShopController` still uses the older category-based blanket rotation
(`GUN_DISPLAY_ROTATION` / `MELEE_EXTRA_ROTATION`, switched only on `Category == "Melee"`), with no
bounding-box-axis derivation anywhere in the file. Whether that derivation was ever actually applied
and later lost, or the older document's claim was simply wrong, is not knowable from here — but the
bug you're reporting today (all Pistols wrong) is fully consistent with the blanket-rotation code
that is actually live, and is exactly what that code would produce. Trust what's below, not that
older document's orientation section.

**Known tooling limitation, already documented by an earlier session in this exact project**
(`FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab.md`): `screen_capture` does not produce
usable output for Play-mode 2D GUI content in this environment — it appears to capture the 3D
edit-time viewport, not a running client's actual rendered frame with GUI overlays. That means the
rotation fix in Part 1 **cannot be self-verified by screenshot**. It's derived from direct comparison
of the weapons' actual stored orientations (evidence below — this is not a guess), applied as
attribute-driven and trivially re-tunable, and the verification step explicitly asks you (the person
running Play mode) to look at it and report back, exactly like that earlier session had to. Do not
skip that step or claim it's fixed without it actually being looked at.

---

## Part 1 — Pistol 3D display shows barrel vertical instead of horizontal

### Root cause (measured, not guessed)

`WeaponaryShopController.showDetail` applies one of exactly two rotations to every weapon's cloned
`Blaster` display model, chosen only by `Category == "Melee"` vs. everything else:

```lua
local GUN_DISPLAY_ROTATION = CFrame.Angles(math.rad(90), 0, 0)
local MELEE_EXTRA_ROTATION = CFrame.Angles(0, 0, math.rad(90))
...
local isMelee = entry:GetAttribute("Category") == "Melee"
local displayRotation = if isMelee then MELEE_EXTRA_ROTATION * GUN_DISPLAY_ROTATION else GUN_DISPLAY_ROTATION
```

Every `AutoRifle` and `Shotgun` weapon shares this same non-melee branch with every `Pistol` weapon.
But their **raw, as-stored pivot orientations are not the same shape of problem**, confirmed by
reading `WorldPivot.Rotation` directly off the live `Blaster` models in `ServerStorage.Weapons`:

- `AK47.Blaster` (AutoRifle, confirmed correctly displayed today): raw pivot has its local Up axis
  pointing along world **Z** and its local Back axis along world **Y** — i.e. it's stored **lying on
  its side**. `GUN_DISPLAY_ROTATION` (a 90° rotation) is exactly what stands a side-lying model back
  upright with the barrel horizontal.
- `Deagle.Blaster` (Pistol): raw pivot has its local Up axis pointing along world **Y already** — i.e.
  it's stored **standing upright**, not lying on its side. Applying the same 90° "stand it up"
  correction that fixes AK47 over-rotates an already-upright pistol, tipping its barrel from
  horizontal to vertical — which is exactly "facing top-bottom."

`M1911` and `Mateba 2006M` are the other two `Category == "Pistol"` weapons (confirmed via
`ServerStorage.Weapons.*` attributes — these three are the entire Pistol category) and are expected
to share the same upright-storage convention, so all three are almost certainly affected, not just
the one in your screenshot.

The framing-distance logic added around this rotation (correct-orientation-before-measuring-bounds)
is unrelated and correct — **do not touch that part.**

### The fix — attribute-driven per-weapon override, zero risk to the 14 already-correct weapons

Add an optional `ShopViewRotation` attribute (a `Vector3` of XYZ Euler **degrees**) that any weapon
Tool in `ServerStorage.Weapons` can set to override the display rotation. When absent, behavior is
byte-identical to today — this is the same "attribute overrides a shared default, absent means use
the existing behavior" convention already used throughout this codebase (`templateConfig`,
`UpgradeConfig`, every optional `Constants.*_ATTRIBUTE` on a weapon).

**`ServerScriptService.Weapons.Scripts.WeaponShopService`** — add `"ShopViewRotation"` to
`CATALOG_ATTRIBUTES` so it replicates onto each catalog entry:

```lua
local CATALOG_ATTRIBUTES = { "Category", "Price", "damage", "rateOfFire", "magazineSize", "range", "ShopViewRotation" }
```

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**, inside `showDetail`, replace:

```lua
		local isMelee = entry:GetAttribute("Category") == "Melee"
		local displayRotation = if isMelee then MELEE_EXTRA_ROTATION * GUN_DISPLAY_ROTATION else GUN_DISPLAY_ROTATION
```

with:

```lua
		-- Per-weapon override for weapons whose raw stored orientation doesn't match the shared
		-- default (e.g. a model authored/placed standing upright instead of lying on its side).
		-- Absent on a weapon = exactly the previous behavior, so every already-correct weapon is
		-- untouched by this change.
		local rotationOverride = entry:GetAttribute("ShopViewRotation") :: Vector3?
		local displayRotation
		if rotationOverride then
			displayRotation = CFrame.Angles(
				math.rad(rotationOverride.X),
				math.rad(rotationOverride.Y),
				math.rad(rotationOverride.Z)
			)
		else
			local isMelee = entry:GetAttribute("Category") == "Melee"
			displayRotation = if isMelee then MELEE_EXTRA_ROTATION * GUN_DISPLAY_ROTATION else GUN_DISPLAY_ROTATION
		end
```

### Set the override on the three Pistol weapons and iterate visually — this is the part that needs your eyes

Run once (Command Bar, or a temporary `Script` deleted afterwards):

```lua
local ServerStorage = game:GetService("ServerStorage")
local weapons = ServerStorage.Weapons

for _, name in { "Deagle", "M1911", "Mateba 2006M" } do
	local tool = weapons:FindFirstChild(name)
	if tool then
		-- Starting hypothesis, reasoned from the pivot comparison above, not visually confirmed:
		-- these are already stored upright, so they may need NO stand-up correction at all.
		tool:SetAttribute("ShopViewRotation", Vector3.new(0, 0, 0))
	end
end
```

Then: enter Play mode, open the Weaponry Shop (`B`), open each of Deagle / M1911 / Mateba 2006M in
the detail panel, and look at it. You are looking for the same thing the working rifles show: the
gun reads barrel-horizontal, right-side-up, and as it auto-spins around the vertical axis it visibly
tumbles side-to-side rather than just twirling in place around its own barrel.

If `(0, 0, 0)` isn't right, do not re-derive from scratch — try these in order, re-entering Play mode
and looking again after each, until one reads correctly:

1. `Vector3.new(0, 90, 0)`
2. `Vector3.new(0, -90, 0)`
3. `Vector3.new(90, 0, 0)` (the original blanket value, in case the upright-storage read above was
   wrong for one specific weapon even though it matched for the pivot comparison)
4. `Vector3.new(0, 0, 90)`

Apply the same value to all three unless one visibly needs a different value than the other two — the
pivot comparison above only directly measured `Deagle`; if `M1911` or `Mateba 2006M` turns out to need
something different, that's fine, set it per-weapon, that's exactly why this is an attribute and not a
single shared constant.

**Report back which value (or combination) actually looked right for each of the three**, so this can
be recorded for next time instead of re-discovered.

### Verify

- [ ] All three Pistol weapons (Deagle, M1911, Mateba 2006M) display barrel-horizontal in the shop's
      detail viewport, matching how the rifles/shotguns already look — confirmed by actually looking
      in Play mode, not assumed from the code change alone.
- [ ] AutoRifle, Shotgun, and Melee weapons are visually unchanged (they take the untouched default
      branch — if any of them regressed, `ShopViewRotation` was set on the wrong weapon by mistake).
- [ ] The framing/distance logic (camera positioning) still works correctly for all weapons — this
      prompt does not change it, so a regression there means something else was accidentally edited.

---

## Part 2 — Persistent weapon ownership with explicit Equip/Dequip loadout slots

### What's live today, and why buying past 4 destroys a weapon

This is not a bug in the sense of "broken code" — it's the previous prompt's deliberate design
(`FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md`), now confirmed live: `WeaponShopService`
tracks `ownedWeapons[player]` capped at `MAX_OWNED_WEAPONS = 4`. Buying a 5th weapon requires the
client to name a `swapOutWeaponName`; the server then **destroys that weapon's live `Tool` and
deletes it from `ownedWeapons`** — it is not just unequipped, it is permanently un-owned, and buying
it back costs full price again. `getOwnedTools()`/`isOwned()` on the client derive purely from "is
there a `Tool` with this name currently in my `Backpack`/`Character` right now" — there is no concept
of "owned but not currently held" anywhere in the system.

This part replaces that design with what you asked for: **ownership is permanent and uncapped once
purchased; the 4 physical slots govern only which owned weapons are currently granted into the
Backpack, and moving a weapon out of a slot never loses it.**

**Design decision, stated explicitly so you can correct it if this isn't what you meant:** buying a
weapon no longer auto-equips it into a free slot, even if one is open. Buying only grants ownership.
Equipping — choosing which of the 4 slots a weapon occupies — is always the separate, explicit action
you described ("the player can still choose which slot he wants to equip" even when a slot is free).
This also means ownership itself has no cap anymore; only the 4 loadout slots are capped. If you
actually wanted a ceiling on total owned weapons (distinct from the 4-slot cap), say so and that's a
one-constant change to add back.

This does **not** touch `EquipService` / the "Custom Inventory" package's own equip system — that
governs which of your Backpack's Tools is actively in your hands right now, a separate layer that
sits on top of whatever this system puts in the Backpack. Do not merge these two concepts or add a
second remote that does what `EquipRequest` already does.

### Part 2a — `ReplicatedStorage.Weapons.Remotes`: one new RemoteEvent

Add `SetLoadoutSlotRequest` (a `RemoteEvent`), alongside the existing `EquipRequest` /
`UpgradeRequest` / `BuyRequest`. Fired by the client as `(weaponName: string, slotIndex: number?)`:
- `slotIndex` given (1-4): equip `weaponName` into that slot, displacing whatever was there.
- `slotIndex` omitted/`nil`: dequip `weaponName` from whichever slot it currently occupies.

### Part 2b — `UpgradeConfig`: share the sanitizer, add an ownership attribute name

Replace the whole module with:

```lua
-- Shared definition of the damage-upgrade scheme AND the per-weapon ownership signal, required by
-- the server services and the client shop UI so neither the cost formula nor the attribute naming
-- can drift between them.
local UpgradeConfig = {}

-- Cost of level N is COST_PER_LEVEL * N. Placeholder, not final balance.
UpgradeConfig.COST_PER_LEVEL = 50

-- Roblox attribute names allow only letters, digits and underscores, and SetAttribute THROWS on
-- anything else -- so "Scar L", "AUG A-3", "Mateba 2006M" etc. would all error on purchase/upgrade
-- while simple names worked. Every illegal character is folded to an underscore. Shared by both
-- attribute families below so there is exactly one place that does this folding.
local function sanitize(weaponName: string): string
	return (string.gsub(weaponName, "[^%w_]", "_"))
end

local UPGRADE_PREFIX = "WeaponUpgrade_"
local OWNED_PREFIX = "WeaponOwned_"

function UpgradeConfig.attributeFor(weaponName: string): string
	return UPGRADE_PREFIX .. sanitize(weaponName)
end

-- Where a player's ownership of a weapon TYPE is replicated to their own client. Session-only, set
-- once on purchase, matching how the underlying ownership table itself is session-only (no
-- DataStore anywhere in this codebase yet).
function UpgradeConfig.ownedAttributeFor(weaponName: string): string
	return OWNED_PREFIX .. sanitize(weaponName)
end

-- Folding to underscores could in principle map two different weapon names onto one attribute
-- ("M-16" and "M 16" both become "M_16"), which would silently share state between them. Checked
-- once at start-up against the real weapon list. Two different prefixes can never collide with each
-- other, only within the same prefix, so this checks each family separately.
function UpgradeConfig.assertNoCollisions(weaponNames: { string })
	for _, prefixFn in { UpgradeConfig.attributeFor, UpgradeConfig.ownedAttributeFor } do
		local byAttribute: { [string]: string } = {}
		for _, name in weaponNames do
			local attribute = prefixFn(name)
			local previous = byAttribute[attribute]
			if previous then
				warn(
					`UpgradeConfig: "{previous}" and "{name}" both map to the attribute "{attribute}", so they `
						.. `would share state. Rename one of them.`
				)
			end
			byAttribute[attribute] = name
		end
	end
end

return UpgradeConfig
```

### Part 2c — `ServerScriptService.Weapons.Scripts.WeaponShopService`: replace ownership + slots

Replace the whole `OWNERSHIP` and `BUY HANDLING` sections (everything from
`local ownedWeapons: { [Player]: { [string]: boolean } } = {}` down to the end of the file) with:

```lua
-- ============================================
-- OWNERSHIP (permanent once purchased, uncapped, session-only -- matches how Cash/Leveling already
-- work, no DataStore) + LOADOUT SLOTS (exactly 4, govern only what's granted into the Backpack)
-- ============================================
local MAX_LOADOUT_SLOTS = 4

local ownedWeapons: { [Player]: { [string]: boolean } } = {}
local equippedSlots: { [Player]: { [number]: string } } = {}

-- Clones a fresh copy of a weapon, with the player's current upgrade level already applied, into
-- the given container. Shared by a fresh equip and a post-respawn restore, so "upgrade level
-- carries onto a new clone" can't drift between the two call sites.
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

-- Republishes the 4 slots as attributes -- the single source of truth the client reads for
-- rendering the inventory column and the Equip/Dequip button state. Called after every change
-- rather than patched incrementally, so the replicated state can never drift from `equippedSlots`.
local function publishSlots(player: Player)
	local slots = equippedSlots[player]
	if not slots then
		return
	end
	for i = 1, MAX_LOADOUT_SLOTS do
		player:SetAttribute("LoadoutSlot" .. i, slots[i] or "")
	end
end

local function restoreEquippedWeapons(player: Player)
	local slots = equippedSlots[player]
	if not slots then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	for _, weaponName in slots do
		-- Idempotent: this can legitimately run more than once for the same character (the
		-- already-present-character path plus CharacterAdded), and a second pass must not hand out
		-- a duplicate.
		if not backpack:FindFirstChild(weaponName) then
			grantWeapon(player, weaponName, backpack)
		end
	end
end

local function isWeaponOwned(player: Player, weaponName: string): boolean
	local owned = ownedWeapons[player]
	return owned ~= nil and owned[weaponName] == true
end

safePlayerAdded(function(player: Player)
	ownedWeapons[player] = { [STARTING_WEAPON] = true }
	equippedSlots[player] = { [1] = STARTING_WEAPON }
	player:SetAttribute(UpgradeConfig.ownedAttributeFor(STARTING_WEAPON), true)
	publishSlots(player)

	player.CharacterAdded:Connect(function()
		restoreEquippedWeapons(player)
	end)

	-- safePlayerAdded also fires for players already in the game, whose character may already
	-- exist. CharacterAdded never fires for that one, so without this a player would hold nothing
	-- until their first death.
	if player.Character then
		restoreEquippedWeapons(player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	ownedWeapons[player] = nil
	equippedSlots[player] = nil
end)

-- ============================================
-- BUY HANDLING -- grants ownership only. Never touches the Backpack or a loadout slot; the player
-- equips separately via SetLoadoutSlotRequest.
-- ============================================
buyRequest.OnServerEvent:Connect(function(player: Player, weaponName: any)
	if typeof(weaponName) ~= "string" then
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

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not cash or cash.Value < price then
		return
	end

	local owned = ownedWeapons[player]
	if not owned then
		return
	end

	cash.Value -= price
	owned[weaponName] = true
	player:SetAttribute(UpgradeConfig.ownedAttributeFor(weaponName), true)
end)

-- ============================================
-- LOADOUT SLOT HANDLING -- equip (with slot choice) or dequip. Never changes ownership.
-- ============================================
setLoadoutSlotRequest.OnServerEvent:Connect(function(player: Player, weaponName: any, slotIndex: any)
	if typeof(weaponName) ~= "string" then
		return
	end
	if slotIndex ~= nil then
		if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > MAX_LOADOUT_SLOTS then
			return
		end
	end
	if not isWeaponOwned(player, weaponName) then
		return -- can't equip/dequip a weapon you don't own
	end

	local slots = equippedSlots[player]
	if not slots then
		return
	end

	local currentSlot: number? = nil
	for i, name in slots do
		if name == weaponName then
			currentSlot = i
			break
		end
	end

	if slotIndex == nil then
		-- DEQUIP
		if not currentSlot then
			return -- not currently equipped, nothing to do
		end
		local equippedCount = 0
		for _ in slots do
			equippedCount += 1
		end
		if equippedCount <= 1 then
			return -- must always keep at least one weapon equipped -- refuse to leave the player unarmed
		end

		slots[currentSlot] = nil
		local tool = findLiveTool(player, weaponName)
		if tool then
			tool:Destroy()
		end
	else
		-- EQUIP into slotIndex, displacing whatever (if anything) currently occupies it
		if currentSlot == slotIndex then
			return -- already there
		end
		if currentSlot then
			slots[currentSlot] = nil -- the weapon moves, it does not duplicate into a second slot
		end

		local displaced = slots[slotIndex]
		if displaced then
			local displacedTool = findLiveTool(player, displaced)
			if displacedTool then
				displacedTool:Destroy()
			end
		end

		slots[slotIndex] = weaponName

		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			local existing = backpack:FindFirstChild(weaponName)
			if existing then
				existing:Destroy() -- defensive: should not exist yet, but never duplicate
			end
			grantWeapon(player, weaponName, backpack)
		end
	end

	publishSlots(player)
end)
```

And near the top of the file, alongside the other remote locals, add:

```lua
local setLoadoutSlotRequest = ReplicatedStorage.Weapons.Remotes.SetLoadoutSlotRequest
```

Leave the `CATALOG` section (catalog folder build, `CATALOG_ATTRIBUTES`, `STARTING_WEAPON`,
`WEAPONS_FOLDER`, `buyRequest` local) exactly as-is except for the `CATALOG_ATTRIBUTES` addition in
Part 1. Remove the now-unused `MAX_OWNED_WEAPONS`, `countOwnedWeapons`, and the old `BUY HANDLING`
block's `swapOutWeaponName` handling entirely — none of it is called from anywhere after this change.

### Part 2d — Add `EquipButton` to the shop GUI template

Run once (Command Bar, or a temporary `Script` deleted afterwards):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local detailPanel = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel
local actionButton = detailPanel.ActionButton

if not detailPanel:FindFirstChild("EquipButton") then
	-- Cloned from ActionButton so font, corner radius, text sizing behavior stay identical by
	-- construction. Positioned directly beside it (same row, 10px gap) since ActionButton is at
	-- Position (0, 290), Size (180, 60) and DetailPanel is ~650-700px wide -- plenty of clear space
	-- to its right (confirmed live: nothing else occupies that region).
	local equipButton = actionButton:Clone()
	equipButton.Name = "EquipButton"
	equipButton.Position = UDim2.fromOffset(190, 290)
	equipButton.Text = "EQUIP"
	equipButton.Visible = false
	equipButton.Parent = detailPanel
end

print("EquipButton added:", detailPanel:FindFirstChild("EquipButton") ~= nil)
```

### Part 2e — `WeaponaryShopController`: read ownership/slots from attributes, add Equip/Dequip

Add near the other remote locals:

```lua
local setLoadoutSlotRequest = ReplicatedStorage.Weapons.Remotes.SetLoadoutSlotRequest
```

Add near the other `detailPanel` child locals:

```lua
local equipButton = detailPanel:WaitForChild("EquipButton") :: TextButton
```

Add alongside `BUY_COLOR` / `UPGRADE_COLOR`:

```lua
local EQUIP_COLOR = Color3.fromRGB(60, 130, 220)
local DEQUIP_COLOR = Color3.fromRGB(150, 150, 155)
```

Replace `getOwnedTools()` and `isOwned()` entirely with:

```lua
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
```

Replace `refreshInventoryColumn()` entirely with:

```lua
local function refreshInventoryColumn()
	local slots = getEquippedWeaponNames()
	for i = 1, 4 do
		local slot = slotsContainer:FindFirstChild("Slot" .. i) :: ImageButton
		local icon = slot:WaitForChild("Icon") :: ImageLabel
		local nameLabel = slot:WaitForChild("NameLabel") :: TextLabel
		local emptyLabel = slot:WaitForChild("EmptyLabel") :: TextLabel

		local weaponName = slots[i]
		if weaponName then
			-- Read from the catalog, not a live Tool -- a weapon can be equipped while this
			-- client's own Backpack replication hasn't caught up yet, and the catalog always has
			-- the icon regardless of ownership.
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
	end
end
```

Rename `pendingBuyWeapon` to `pendingEquipWeapon` everywhere it appears (it's now used only by the
Equip flow, never by buying). Rename `setSwapMode` to `setSlotPickMode` and replace its body with:

```lua
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
	end
end
```

Replace the `for i = 1, 4 do ... slot.MouseButton1Click:Connect(...) ... end` block entirely with:

```lua
for i = 1, 4 do
	local slot = slotsContainer:WaitForChild("Slot" .. i) :: ImageButton
	slot.MouseButton1Click:Connect(function()
		if not pendingEquipWeapon then
			return
		end
		setLoadoutSlotRequest:FireServer(pendingEquipWeapon, i)
		pendingEquipWeapon = nil
		setSlotPickMode(false)
	end)
end
```

Replace `performAction()` entirely with:

```lua
local function performAction()
	local weaponName = currentDetailWeapon
	if not weaponName then
		return
	end

	if isOwned(weaponName) then
		upgradeRequest:FireServer(weaponName)
		task.delay(0.1, function()
			if detailPanel.Visible and currentDetailWeapon == weaponName then
				showDetail(weaponName)
			end
		end)
		return
	end

	awaitingPurchaseSound = true
	buyRequest:FireServer(weaponName)
end
```

Add a new handler alongside it:

```lua
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
```

In `showDetail`, inside the `if isOwned(weaponName) then` branch (the Upgrade-button setup), add
after the existing `actionButton.Visible = true` line:

```lua
		local isEquipped = findEquippedSlot(weaponName) ~= nil
		equipButton.Text = if isEquipped then "DEQUIP" else "EQUIP"
		equipButton.BackgroundColor3 = if isEquipped then DEQUIP_COLOR else EQUIP_COLOR
		equipButton.Visible = true
```

And in the `else` branch (not owned — Buy or "Not for sale"), add:

```lua
		equipButton.Visible = false
```

Wire the button once, alongside `actionButton.MouseButton1Click:Connect(performAction)`:

```lua
equipButton.MouseButton1Click:Connect(performEquipAction)
```

In both `backButton`'s handler and `closeShop()`, rename every `pendingBuyWeapon` reference to
`pendingEquipWeapon` and every `setSwapMode` call to `setSlotPickMode`.

Delete the entire `OWNERSHIP HELPERS` Backpack-scanning section
(`local function getOwnedTools()` and everything in that block), and delete the entire
`bindBackpack` / `backpackConnections` / `player.ChildAdded` Backpack-listening section — Backpack
contents are now a downstream *effect* of slot state, not the signal to key UI refresh off. Replace
the final `player.AttributeChanged:Connect(...)` block (the one that currently only plays the
upgrade sound) with:

```lua
player.AttributeChanged:Connect(function(attributeName: string)
	if attributeName:match("^WeaponUpgrade_") then
		upgradeSound:Play()
	elseif attributeName:match("^WeaponOwned_") then
		if awaitingPurchaseSound then
			awaitingPurchaseSound = false
			purchaseSound:Play()
		end
		if isOpen then
			buildGrid()
			if currentDetailWeapon then
				showDetail(currentDetailWeapon) -- Buy -> Upgrade/Equip flip once ownership replicates
			end
		end
	elseif attributeName:match("^LoadoutSlot") then
		if isOpen then
			refreshInventoryColumn()
			if currentDetailWeapon then
				showDetail(currentDetailWeapon) -- Equip/Dequip button label flip
			end
		end
	end
end)
```

Leave `openShop()` calling `refreshInventoryColumn()` and `buildGrid()` on open exactly as before —
both now read attributes instead of the Backpack, which are already set correctly by the time the
shop can be opened.

### Verify

- [ ] Buy a weapon while already owning 4 others in slots: succeeds immediately, costs the listed
      price, no swap prompt, and the weapon does **not** appear in a Backpack slot yet.
- [ ] Open that weapon's detail panel: it shows both an "UPGRADE" button and an "EQUIP" button (not
      a swap prompt).
- [ ] Click EQUIP with all 4 slots full: the slot picker appears ("Select a slot to equip"), every
      slot pulses (not just occupied ones), clicking any slot — full or empty — equips the new
      weapon there.
- [ ] Equipping into a full slot **keeps** the displaced weapon owned (it still shows "OWNED" in the
      grid, still has its upgrade level, and can be re-equipped for free later) — it is not
      destroyed and does not need to be repurchased. This is the core bug fix; check it explicitly.
- [ ] Click EQUIP on an owned-but-unequipped weapon when a slot IS free: the picker still appears
      (equipping is always an explicit slot choice, never automatic) and clicking the empty slot
      places it there directly with no confirmation needed.
- [ ] With a weapon currently equipped, its detail panel button reads "DEQUIP"; clicking it removes
      it from its slot (the slot goes back to "Empty"), the weapon stays owned, and its `Tool` is
      gone from the Backpack immediately, including if it was the one actively in-hand.
- [ ] Attempting to dequip your only remaining equipped weapon is refused — you can never end up
      with zero equipped weapons.
- [ ] Die and respawn: exactly the weapons currently occupying slots come back, nothing extra,
      nothing missing, in the same slots. Weapons owned-but-not-equipped are not granted into the
      Backpack on respawn.
- [ ] A fresh player still starts with exactly Crowbar, owned and in slot 1.
- [ ] The "Owned" category tab still lists every owned weapon (equipped or not), price-sorted, and
      updates live while the shop stays open through a buy/equip/dequip.
- [ ] Purchase sound plays exactly once per successful buy (now triggered by ownership, not
      Backpack); upgrade sound plays exactly once per upgrade; neither plays on a silent
      respawn-restore.
- [ ] Upgrade levels survive an equip → dequip → re-equip cycle for the same weapon.
- [ ] `EquipService` / the Custom Inventory hand-equip system is unaffected — switching which
      Backpack weapon is actively held still works exactly as before.

---

## Master verification checklist

- [ ] All three Pistol weapons display barrel-horizontal in the shop's 3D viewport; every other
      weapon's display is unchanged.
- [ ] Buying past 4 owned weapons never destroys or un-owns anything.
- [ ] Equip/Dequip buttons appear beside Upgrade for owned weapons and work as specified above,
      including the always-explicit slot choice and the "can't leave yourself unarmed" guard.
- [ ] Ownership, upgrade levels, and slot assignment all survive death/respawn correctly.
- [ ] `EquipService`'s hand-equip system is untouched and still works.

## Notes for whoever applies this

- Every root cause above was re-verified live via `inspect_instance` / `script_read` / `script_search`
  against the running Studio instance immediately before this was written — including the pivot-
  orientation comparison in Part 1 and the discrepancy with the Catch-Up document's orientation claim.
- `script_grep` and `script_read` have been observed to report different line numbers for the same
  script in this project. Match edits on the quoted code shown above, not on any line number.
- `screen_capture` is documented as unreliable for Play-mode GUI in this environment (see Context).
  Part 1's rotation fix genuinely needs a human to look at it in Play mode — don't skip that step or
  report it fixed without doing it.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified (including the Part 1 visual check), write a short plain-prose changelog entry following
  the template used by the existing entries under `FPSSystem/`, commit that instead — one commit,
  since this is one logical change spanning two related fixes to the same shop — then push.
