# Prompt: +5 Damage Per Upgrade Level, Cash Burst FX, Slot Equip Animation, Baton Sound Fix, Stop the Shop's 3D Preview Resetting

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**On the shop's orientation system:** it has been substantially reworked since the last two prompt
documents in this folder — confirmed live, `WeaponaryShopController.showDetail` now derives each
weapon's orientation from its own bounding-box axes rather than a fixed constant, with
`ShopViewRotation` kept only as a residual per-weapon roll correction on top. `AK47` already carries
`ShopViewRotation = (180, 0, 0)`. **This means `FPS-AK47-Display-Fix-11-New-Guns-Integration.md`'s
Part 1 is stale** (its code diff targets the old, no-longer-live `GUN_DISPLAY_ROTATION` constant) —
skip that part if you ever open that document; the AK47 bug it describes already appears to be fixed.
Nothing in this document touches the orientation system — don't re-derive or "improve" it as a side
effect of anything below.

**Root cause of the "GUI resets" bug, found live:** `showDetail(weaponName)` does two unrelated
things in one function — (1) rebuild the 3D preview model from scratch (destroy the old one, clone a
fresh one, re-derive its orientation, restart the spin `RenderStepped` connection) and (2) refresh the
stats text and button labels/colors. Three call sites invoke the *whole* function purely to get (2),
which as a side effect always does (1) too, visibly restarting the spin every time:
`performAction`'s post-upgrade `task.delay(0.1, ...)`, the `WeaponOwned_` attribute listener, and the
`LoadoutSlot` attribute listener. None of those three need the model touched at all — the weapon being
viewed hasn't changed, only its owned/level/slot state has.

## Part 1 — stop the 3D preview from resetting on every action

Split `showDetail` into the full rebuild (still called when the player actually switches to viewing a
different weapon) and a lightweight stats-only refresh (called everywhere else).

In `StarterPlayer.StarterPlayerScripts.WeaponaryShopController`, `showDetail` currently reads (from
`detailName.Text = weaponName` to the end of the function):

```lua
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
		actionButton.Visible = true

		local isEquipped = findEquippedSlot(weaponName) ~= nil
		equipButton.Text = if isEquipped then "DEQUIP" else "EQUIP"
		equipButton.BackgroundColor3 = if isEquipped then DEQUIP_COLOR else EQUIP_COLOR
		equipButton.Visible = true
	else
		equipButton.Visible = false
		local price = entry:GetAttribute("Price")
		if price then
			priceLabel.Text = `\u{1F4B0}{price}`
			actionButton.Text = "BUY"
			actionButton.BackgroundColor3 = BUY_COLOR
			actionButton.Visible = true
		else
			priceLabel.Text = "Not for sale"
			actionButton.Visible = false
		end
	end
end
```

Extract that whole block into its own function, declared alongside `showDetail`'s forward
declaration (`local showDetail` near the top):

```lua
local showDetail
local refreshDetailStats
```

New function, defined near `showDetail` (order relative to `showDetail` doesn't matter since both are
forward-declared locals):

```lua
-- Updates everything in the detail panel EXCEPT the 3D model: text, price, and button
-- state/labels. Safe to call as often as needed for the weapon already being viewed -- unlike
-- showDetail, this never touches the viewport, so it can never restart the spin. Also where the
-- upgrade damage bonus is shown, per DAMAGE_PER_LEVEL below.
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

	if isOwned(weaponName) then
		local nextLevel = level + 1
		local cost = UpgradeConfig.COST_PER_LEVEL * nextLevel
		priceLabel.Text = `Upgrade cost: \u{1F4B0}{cost}`
		actionButton.Text = `UPGRADE (Lv.{nextLevel})`
		actionButton.BackgroundColor3 = UPGRADE_COLOR
		actionButton.Visible = true

		local isEquipped = findEquippedSlot(weaponName) ~= nil
		equipButton.Text = if isEquipped then "DEQUIP" else "EQUIP"
		equipButton.BackgroundColor3 = if isEquipped then DEQUIP_COLOR else EQUIP_COLOR
		equipButton.Visible = true
	else
		equipButton.Visible = false
		local price = entry:GetAttribute("Price")
		if price then
			priceLabel.Text = `\u{1F4B0}{price}`
			actionButton.Text = "BUY"
			actionButton.BackgroundColor3 = BUY_COLOR
			actionButton.Visible = true
		else
			priceLabel.Text = "Not for sale"
			actionButton.Visible = false
		end
	end
end
```

And replace what's left of `showDetail` (everything from `detailName.Text = weaponName` onward) with
a single call:

```lua
	refreshDetailStats(weaponName)
end
```

Now update the three call sites that only need the stats refreshed, not a model rebuild:

**`performAction`** — replace the `task.delay(0.1, function() ... showDetail(weaponName) ... end)`
body's `showDetail(weaponName)` with `refreshDetailStats(weaponName)`.

**The `WeaponOwned_` branch** in the `player.AttributeChanged` listener — replace
`showDetail(currentDetailWeapon)` with `refreshDetailStats(currentDetailWeapon)`.

**The `LoadoutSlot` branch** in the same listener — replace `showDetail(currentDetailWeapon)` with
`refreshDetailStats(currentDetailWeapon)`.

Leave every other `showDetail` call site alone (the weapon card click handler, which is correctly
switching to a new detail view and should rebuild the model).

### Verify

- [ ] Open a weapon's detail panel, let it spin, then buy/upgrade/equip/dequip a DIFFERENT weapon
      from elsewhere (not applicable here since only one panel is open at a time — instead: click
      UPGRADE on the weapon you're viewing) — the model keeps spinning continuously through the
      click, never resets to its starting angle or re-clones.
- [ ] Stats, price, and button labels still update correctly and immediately after every action
      (buy, upgrade, equip, dequip) — only the model rebuild was removed, not the refresh.
- [ ] Clicking a different weapon's card from the grid still rebuilds the model and orientation
      correctly (this path is unchanged).

---

## Part 2 — upgrades add +5 damage per level, and the stat panel shows the accumulated bonus

**`ReplicatedStorage.Weapons.UpgradeConfig`** — add, alongside `COST_PER_LEVEL`:

```lua
-- Flat damage added per upgrade level (level 1 = +5, level 2 = +10, ...), not += level.
UpgradeConfig.DAMAGE_PER_LEVEL = 5
```

**`ServerScriptService.Weapons.Scripts.WeaponUpgradeService`**, in `applyToHeldWeapons`, replace:

```lua
			tool:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + newLevel)
```

with:

```lua
			tool:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + newLevel * UpgradeConfig.DAMAGE_PER_LEVEL)
```

**`ServerScriptService.Weapons.Scripts.WeaponShopService`**, in `grantWeapon`, replace:

```lua
			weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + upgradeLevel)
```

with:

```lua
			weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, stockDamage + upgradeLevel * UpgradeConfig.DAMAGE_PER_LEVEL)
```

(`WeaponShopService` already `require`s `UpgradeConfig` — no new import needed.)

The stat-panel display for the accumulated bonus (`{stockDamage + bonus} (+{bonus})`) is already part
of `refreshDetailStats` in Part 1 — if you're applying this document in order, it's already in place.

### Verify

- [ ] Buying a fresh weapon and upgrading it once raises its actual dealt damage by exactly 5 over
      stock (check the live `Tool`'s `damage` attribute in the Backpack, not just the UI).
      Upgrading a second time raises it by 5 more (10 total), not by 2 or by a compounding amount.
- [ ] The detail panel's Damage stat reads e.g. `45 (+15)` for a weapon at level 3, and just the
      plain stock number (no `(+0)`) at level 0.
- [ ] A freshly-granted weapon (bought, or restored on respawn) at a non-zero upgrade level carries
      the correct total damage immediately, matching `stock + level * 5`.

---

## Part 3 — cash burst that fades out on purchase or upgrade

A short-lived floating `-$<amount>` label near the price, matching the tween-then-destroy shape
`CashService.implode` already uses elsewhere in this game (shrink + fade, then remove) — same idea,
adapted for 2D GUI (rise + fade).

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`** — add near the other constants:

```lua
local CASH_BURST_RISE = UDim2.fromOffset(0, -40)
local CASH_BURST_DURATION = 0.9
local CASH_BURST_COLOR = Color3.fromRGB(255, 90, 90)
```

Add a new function, anywhere alongside the other detail-panel helpers:

```lua
-- A short-lived "-$<amount>" label that rises and fades over the price, confirming a spend just
-- happened. Self-contained: creates its own Instance and destroys itself, so it can be fired from
-- anywhere without the caller tracking its lifetime.
local function showCashBurst(amount: number)
	local burst = Instance.new("TextLabel")
	burst.Name = "CashBurst"
	burst.BackgroundTransparency = 1
	burst.Size = UDim2.fromOffset(180, 30)
	burst.Position = priceLabel.Position
	burst.AnchorPoint = priceLabel.AnchorPoint
	burst.Font = Enum.Font.GothamBold
	burst.TextScaled = true
	burst.Text = `-\u{1F4B0}{amount}`
	burst.TextColor3 = CASH_BURST_COLOR
	burst.TextStrokeTransparency = 0
	burst.ZIndex = priceLabel.ZIndex + 1
	burst.Parent = priceLabel.Parent

	local tween = TweenService:Create(
		burst,
		TweenInfo.new(CASH_BURST_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = priceLabel.Position + CASH_BURST_RISE, TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function()
		burst:Destroy()
	end)
end
```

Trigger it from the two attribute branches that already confirm a successful spend — in the
`WeaponOwned_` branch, after the existing purchase-sound block, add:

```lua
		if currentDetailWeapon and attributeName == UpgradeConfig.ownedAttributeFor(currentDetailWeapon) then
			local entry = catalog:FindFirstChild(currentDetailWeapon)
			local price = entry and entry:GetAttribute("Price")
			if typeof(price) == "number" then
				showCashBurst(price)
			end
		end
```

And in the `WeaponUpgrade_` branch (currently just `upgradeSound:Play()`), replace it with:

```lua
	if attributeName:match("^WeaponUpgrade_") then
		upgradeSound:Play()
		if currentDetailWeapon and attributeName == UpgradeConfig.attributeFor(currentDetailWeapon) then
			local newLevel = player:GetAttribute(attributeName) or 0
			showCashBurst(UpgradeConfig.COST_PER_LEVEL * newLevel)
		end
```

Both are gated on the changed attribute actually being *this weapon's* — not just any purchase/
upgrade anywhere — so the burst only appears when it's relevant to what's on screen, and the amount
is read fresh (catalog price, or `COST_PER_LEVEL * newLevel`) rather than captured speculatively
before the request resolves, so it can't drift from what was actually charged.

### Verify

- [ ] Buying a weapon shows a `-$<price>` burst rising and fading over the price label, exactly
      once per purchase.
- [ ] Upgrading shows `-$<cost>` matching the cost that was actually charged for that level.
- [ ] The burst never appears for an unrelated weapon's purchase/upgrade while a different weapon's
      detail panel happens to be open (shouldn't be reachable today, but confirm the guard holds).
- [ ] No leaked `TextLabel`s accumulate in the panel after repeated purchases/upgrades — each one
      destroys itself when its tween completes.

---

## Part 4 — animate a loadout slot when a weapon is equipped or dequipped into it

**Instance change — run once** (Command Bar, or a temporary `Script` deleted afterward): add a
`UIScale` to each of the 4 slot templates, since none currently has one.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local slotsContainer = ReplicatedStorage.GuiTemplates.WeaponaryShop.InventoryColumn.Slots

for i = 1, 4 do
	local slot = slotsContainer:FindFirstChild("Slot" .. i)
	if slot and not slot:FindFirstChildOfClass("UIScale") then
		local scale = Instance.new("UIScale")
		scale.Name = "PopScale"
		scale.Parent = slot
	end
end
```

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`** — track the previously-rendered slot
contents so only slots that actually changed get animated (equipping one weapon shouldn't replay the
animation on the three slots that didn't change). Add near `pendingEquipWeapon`:

```lua
local lastRenderedSlots: { [number]: string } = {}
```

Replace `refreshInventoryColumn` entirely with:

```lua
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

		-- Pop only the slot(s) whose content actually changed -- not on the shop's first open
		-- (lastRenderedSlots starts empty, which would otherwise pop all 4 on open every time).
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
```

### Verify

- [ ] Equipping a weapon into an empty slot pops just that slot (a quick scale-up bounce), not the
      other three.
- [ ] Equipping into a full slot (displacing the incumbent) pops that one slot once, for the new
      occupant.
- [ ] Dequipping pops the now-empty slot.
- [ ] Opening the shop fresh does not pop all 4 slots on open.
- [ ] Buying/upgrading a weapon that isn't currently in any slot does not pop anything (no slot
      actually changed).

---

## Part 5 — Baton's sounds don't match the Security enemy's

### Confirmed live: every sound differs, not just one

Compared every `Sound` under `ServerStorage.Weapons.Baton.Sounds` against its counterpart under
`ServerStorage.EnemyTemplates.Security.Baton.Sounds` directly:

| Sound | Player Baton `SoundId` | Security Baton `SoundId` |
|---|---|---|
| Equip | `rbxassetid://9113453540` | `rbxassetid://240784215` |
| Hit | `rbxassetid://111155812664366` | `rbxassetid://169259022` |
| Shoot1 | `rbxassetid://6241709963` | `rbxassetid://101164100` |

(`Shoot2`/`Shoot3`/`MagIn`/`MagOut` weren't individually re-verified but follow the identical
folder/name shape in both — same fix applies to the whole folder, not sound-by-sound.) The player's
current sounds also use a much larger `RollOffMinDistance`/`RollOffMaxDistance` (`18.47`/`18470`) than
Security's (`10`/`10000`) — consistent with the whole `Sounds` folder being a leftover from whatever
Baton was originally cloned from, never actually replaced with the Security enemy's dedicated set.

### Fix — replace the whole folder, matching the mesh/viewmodel fix already applied the same way

```lua
local ServerStorage = game:GetService("ServerStorage")

local playerBaton = ServerStorage.Weapons.Baton
local securityBaton = ServerStorage.EnemyTemplates.Security.Baton

playerBaton.Sounds:Destroy()
local newSounds = securityBaton.Sounds:Clone()
newSounds.Parent = playerBaton

print("Baton Sounds replaced with Security's set.")
```

Nothing else references the `Sounds` folder's specific contents by name in a way this would break
(`ViewModelController`/`CharacterAnimationController` look up sounds by name — `Equip`, `Shoot`,
`Reload`/`MagIn`/`MagOut` — not by asset ID, and every one of those names already exists in Security's
folder too, confirmed above).

### Verify

- [ ] Equipping, swinging, and hitting with the player's Baton now plays the same sounds a Security
      enemy's Baton plays.
- [ ] `ServerStorage.EnemyTemplates.Security.Baton.Sounds` is unchanged (cloned from, not moved).
- [ ] No other weapon's sounds were touched.

---

## Master verification checklist

- [ ] The shop's 3D preview never restarts its spin from buying, upgrading, equipping, or
      dequipping the weapon currently being viewed — only switching to a different weapon rebuilds it.
- [ ] Each upgrade level adds exactly +5 damage, cumulative, and the detail panel shows the
      accumulated bonus alongside the stock value.
- [ ] A fading `-$<amount>` burst appears on every successful purchase and upgrade, matching what
      was actually charged.
- [ ] Equipping/dequipping a weapon visibly pops only the affected loadout slot.
- [ ] The player's Baton sounds match the Security enemy's Baton sounds exactly.
- [ ] Nothing about the orientation-derivation system, the existing 28 weapons (17 original + 11
      integrated, if that document has also been applied), or the loadout-slot mechanics regressed.

## Notes for whoever applies this

- Every fact above (the split responsibilities inside `showDetail`, the exact current formulas, the
  Sound ID differences, the missing `UIScale`) was verified live immediately before this was written.
- `script_grep` and `script_read` have been observed to report different line numbers for the same
  script in this project. Match edits on the quoted code, not on line numbers.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write short plain-prose changelog entries (one per logical change is fine, or bundle
  related ones) following the template used by the existing entries under `FPSSystem/`, commit, push.
