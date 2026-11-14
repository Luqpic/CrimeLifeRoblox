# Prompt: Weapon Pickup System + Custom Inventory Integration

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Current state (already confirmed, don't re-verify from scratch)

- All 16 weapons live in `ServerStorage.Weapons` (moved out of the now-empty `StarterPack`).
- 16 pickup Models exist directly in `Workspace`, one per weapon, named exactly after their weapon (e.g. `Workspace.AK47`, `Workspace."Mateba 2006M"`). Each already has: the assembled world-model mesh, a `Highlight`, a `ProximityPrompt` (already correctly configured: `HoldDuration = 1`, `ActionText = "Equip"`, `KeyboardKeyCode = E`, `RequiresLineOfSight = true` — only `ObjectText` is empty and needs setting), and a `Weapon` StringValue child whose `.Value` names the matching Tool under `ServerStorage.Weapons`.
- No script anywhere currently handles `ProximityPrompt.Triggered` for these — the interaction logic doesn't exist yet.
- `Workspace."Custom Inventory"` is a third-party asset package, structured for manual "ungrouping": its README (`Workspace."Custom Inventory"."READ ME"`) literally says `1) ungroup the folders in the dedicated area, 2) watch the tutorial, 3) delete this script + ThumbnailCamera`. Its real content is nested at `Workspace."Custom Inventory"."Ungroup in StarterGui"."Custom Inventory"` (a `ScreenGui` containing `Inventory`, `hotBar`, `openButton`, and the `InventoryController` LocalScript + its `SETTINGS` ModuleScript) — it does nothing at runtime sitting under `Workspace`; `ScreenGui`s only clone to players from `StarterGui`.
- Read `InventoryController`/`SETTINGS` in full already. Key facts that shape everything below:
  - It's **fully reactive** — `reloadInventory()` scans `player.Backpack:GetChildren()` on spawn and listens to `backpack.ChildAdded`/`character.ChildAdded` for anything added afterward, automatically building hotbar/inventory slots for any `Tool`. **No API call is needed to "register" a picked-up weapon with it** — parenting a Tool into the player's `Backpack` the normal way is the entire integration surface.
  - It **unconditionally disables the native Roblox backpack** on line 12 (`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)`) — it fully replaces the native hotbar, permanently, not just cosmetically alongside it.
  - It already checks `humanoid.Health <= 0` before equipping/unequipping via a click or number-key (in `manageTool()`), **and** exposes a purpose-built `module:lockSlots(unequipCurrentTool)` / `module:unlockSlots()` API specifically for an external script to lock the whole inventory down — this is the intended integration point for "disable the whole inventory on death," not something to reimplement.
  - Its per-slot icon logic already falls back to showing the tool's name as text when `TextureId` is empty (and `SETTINGS.ALWAYS_SHOW_TOOL_NAME = true` means the name shows even when an icon exists) — fully compatible with the earlier work that cleared every weapon's `TextureId` for debug-friendly name display; nothing to change there.

---

## Part 1 — Weapon pickup interaction

### Tag the pickups and fill in the prompt text

Add a new CollectionService tag, `WeaponPickup`, to all 16 pickup Models in `Workspace` — following this codebase's existing convention (`Target`, `RayExclude`, `NonStatic`, `EnemySpawnPoint` are all CollectionService tags, not a folder-scan or hardcoded path list).

For each pickup's `ProximityPrompt`, set `ObjectText` to the pickup Model's own name (which already matches the weapon, e.g. `Workspace.AK47.ProximityPrompt.ObjectText = "AK47"`, `Workspace."Mateba 2006M".ProximityPrompt.ObjectText = "Mateba 2006M"`).

### New script: `ServerScriptService.Weapons.Scripts.WeaponPickup` (Script)

```lua
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local WEAPONS_FOLDER = ServerStorage.Weapons
local PICKUP_TAG = "WeaponPickup"

-- True if the player already carries a Tool with this name, equipped or in the backpack. This is
-- the "nothing happens if you already have it" check -- it's a live possession check, not a
-- one-time flag, so it naturally allows re-acquiring the weapon after losing it (e.g. dying, since
-- a fresh respawn's Backpack starts empty now that StarterPack no longer supplies any weapons).
local function playerHasWeapon(player: Player, weaponName: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	return (backpack and backpack:FindFirstChild(weaponName) ~= nil)
		or (character and character:FindFirstChild(weaponName) ~= nil)
		or false
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	local pickup = prompt.Parent
	local weaponValue = pickup and pickup:FindFirstChild("Weapon")
	if not (weaponValue and weaponValue:IsA("StringValue")) then
		warn(`WeaponPickup: {pickup and pickup:GetFullName() or "?"} has no Weapon StringValue`)
		return
	end

	local weaponName = weaponValue.Value
	if playerHasWeapon(player, weaponName) then
		return
	end

	local template = WEAPONS_FOLDER:FindFirstChild(weaponName)
	if not (template and template:IsA("Tool")) then
		warn(`WeaponPickup: no weapon named "{weaponName}" in {WEAPONS_FOLDER:GetFullName()}`)
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local weapon = template:Clone()
	weapon.Parent = backpack
end

local function setupPickup(pickup: Instance)
	local prompt = pickup:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn(`WeaponPickup: {pickup:GetFullName()} is tagged {PICKUP_TAG} but has no ProximityPrompt`)
		return
	end

	prompt.Triggered:Connect(function(player)
		onTriggered(prompt, player)
	end)
end

for _, pickup in CollectionService:GetTagged(PICKUP_TAG) do
	setupPickup(pickup)
end
CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(setupPickup)
```

Note this deliberately does **not** destroy or hide the pickup Model after granting the weapon — it stays in the world permanently, so the same or any player can re-trigger it later (which is exactly what lets someone re-acquire a weapon after dying, per "unless they lose that weapon").

### Verify
- Interact with a pickup: the matching weapon appears in the Backpack (and, via the Custom Inventory's own reactivity, in its hotbar/inventory UI) within one hold-cycle.
- Interact again with the same pickup while still holding that weapon: nothing happens.
- Die (so the Backpack clears, since `StarterPack` no longer supplies anything) and interact with the same pickup again: the weapon is granted again.
- Two different players can each pick up from the same station independently.

---

## Part 2 — Fix the enemy fallback weapon lookup

`ReplicatedStorage.Enemy.Constants.ENEMY_WEAPON_NAME = "Deagle"` is used by `EnemySpawner.prepareWeapon()` as a fallback **only** for a spawned enemy template that has no Tool of its own — none of the 6 configured templates hit this path (each already carries its own pre-equipped weapon clone), but the lookup itself now points at the wrong place and would break for any future template that relies on it.

**`ServerScriptService.Enemy.Scripts.EnemySpawner`** — change:
```lua
local fallback = game.StarterPack:FindFirstChild(Constants.ENEMY_WEAPON_NAME)
```
to:
```lua
local fallback = ServerStorage.Weapons:FindFirstChild(Constants.ENEMY_WEAPON_NAME)
```
(`ServerStorage` is already required at the top of this file for the `EnemyTemplates` lookup — no new require needed.) Update the adjacent warn message's wording from "in StarterPack" to "in ServerStorage.Weapons" too, and the comment on `ENEMY_WEAPON_NAME` in `ReplicatedStorage.Enemy.Constants` that currently says "Cloned from StarterPack."

### Verify
- Grep for `StarterPack` across all scripts afterward — the only remaining hits should be unrelated (none expected at this point; if any turn up, report them rather than assuming they're fine).

---

## Part 3 — Integrate the Custom Inventory

### Ungroup it, per its own README

1. Move `Workspace."Custom Inventory"."Ungroup in StarterGui"."Custom Inventory"` (the `ScreenGui`) so it's parented directly under `StarterGui`.
2. Delete `Workspace."Custom Inventory"` entirely (the now-empty wrapper Folder, the `"READ ME"` script, and the `ThumbnailCamera` rig — all three are asset-packaging artifacts with no runtime purpose, exactly as the README itself instructs).

### Wire "lock inventory on death" through the exposed API, not a reimplementation

**`StarterGui."Custom Inventory".InventoryController`** — add a death hook using the module's own `lockSlots`/`unlockSlots`, integrated into the existing per-respawn flow rather than as a bolted-on separate script:
```lua
local function reloadInventory(character)
	inventoryHandler:unlockSlots()
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		inventoryHandler:lockSlots(true)
	end)

	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			newTool(tool)
		end
	end
	backpack.ChildAdded:Connect(newTool)
	character.ChildAdded:Connect(newTool)
end
```
(Only the first two lines and the `humanoid`/`Died` block are new — the rest of the function is unchanged, shown for placement context.) `lockSlots(true)` both locks the slots against further clicks/number-keys *and* unequips whatever's currently held (via the module's own `humanoid:UnequipTools()` call inside `lockSlots`), so this single call covers both "can't select a new weapon" and "stop holding the current one" on death. `unlockSlots()` at the top of `reloadInventory` (which already runs on every respawn via `player.CharacterAdded:Connect(reloadInventory)`) resets it for the new life — no separate respawn-handling needed.

### Remove the now-obsolete, now-conflicting old script

**Delete `StarterPlayer.StarterPlayerScripts.InventoryDeathLock`** (added two passes ago, before this Custom Inventory existed). It toggles `Enum.CoreGuiType.Backpack` based on death state — but the Custom Inventory now disables that CoreGui permanently and unconditionally on line 12 of `InventoryController`. Left in place, `InventoryDeathLock`'s respawn handler would call `SetCoreGuiEnabled(Backpack, true)` on every respawn, fighting the Custom Inventory's intent to keep the native backpack off for good. The `lockSlots`/`unlockSlots` wiring above is its replacement, scoped to the system that's actually in use now.

### Verify
- Fresh join: the Custom Inventory hotbar/inventory UI appears, the native Roblox backpack does not, at any point (not just after death).
- Pick up a weapon, equip it via the hotbar: normal first-person gameplay works exactly as before this change.
- Die while holding a weapon: character unequips (matching the earlier `BlasterController` death-camera fix — verify that fix and this one don't fight each other, they shouldn't since they act on different systems), and clicking any hotbar/inventory slot while dead does nothing.
- Respawn: hotbar/inventory is usable again immediately, previous life's weapons are gone (fresh empty Backpack), pickups can be re-triggered to re-equip.

## Verification checklist

- [ ] All 16 pickups tagged `WeaponPickup`, `ObjectText` set to their weapon name.
- [ ] `WeaponPickup` script grants the correct weapon, no duplicates while already owned, re-grantable after loss, pickup objects persist.
- [ ] `EnemySpawner`'s fallback path points at `ServerStorage.Weapons`, not `StarterPack`.
- [ ] Custom Inventory ungrouped into `StarterGui`, packaging artifacts deleted.
- [ ] Death locks the Custom Inventory via `lockSlots`/`unlockSlots`; old `InventoryDeathLock` script removed.
- [ ] No remaining `StarterPack` weapon references anywhere in scripts.
