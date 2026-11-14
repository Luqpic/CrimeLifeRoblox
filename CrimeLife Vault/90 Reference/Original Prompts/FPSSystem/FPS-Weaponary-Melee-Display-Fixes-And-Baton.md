# Prompt: Shop Melee Visibility, Detail-View Tabs, 3D Display Orientation, Stun Mechanic + Baton

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Context, confirmed live before writing this — read this first

**Why Crowbar never showed in the Melee tab:** `WeaponShopService` only adds a weapon to the replicated `Catalog` if it has a `Price` attribute — `if template:IsA("Tool") and template:GetAttribute("Price") then`. Crowbar deliberately has no `Price` (that absence is what makes it unbuyable), so it was silently excluded from the catalog entirely, meaning it could never appear in any category tab, including the one it actually belongs to. The fix switches the inclusion check from `Price` to `Category` — every weapon has a `Category`, only sellable ones have a `Price`, and the client already handles a category entry with no price correctly (it only ever reads `Price` on the *not-owned* branch, and Crowbar is always owned).

**The 3D orientation bug, root-caused with actual CFrame math, not a screenshot guess:** computed `AK47`'s `Blaster.Body` basis vectors directly. The muzzle sits along the model's **local -X** (confirmed via the `MuzzleAttachment`'s measured local offset), not the Roblox-conventional -Z — this mesh's "forward" doesn't match the generic per-part convention. More importantly: after centering, the model's pivot `UpVector` was `(0, 0, 1)` — pointing straight at/away from the camera, not toward screen-up — which is exactly "lying flat." Applying a `-90°` rotation about the world X axis and re-reading the vectors confirmed the fix: `UpVector` became `(0, 1, ~0)` (matches the camera's up) and the barrel ended up pointing horizontally across the screen. Verified by computation, not assumed.

**Stun needs to work for both players and enemies, and those are two separate systems today:** a player's movement is authoritatively managed by `ServerScriptService.Movement.Scripts.SprintAuthority` (which already composes a stamina-lockout clamp and a landing-recovery clamp on `Humanoid.WalkSpeed`); an enemy's movement is managed entirely by `ServerScriptService.Enemy.Scripts.EnemyAI`'s own think-loop, which would otherwise immediately re-assert a nonzero `WalkSpeed` on its very next think tick. Neither system should call into the other, and `ShotResolver` (the one place that resolves every hit, player and enemy alike) shouldn't need to know which kind of target it just hit. The fix is a single shared attribute (`StunnedUntil`, stamped by `ShotResolver` on a hit from any weapon that declares `stunDuration`) that each movement system independently checks and enforces on its own next tick — the same "shared signal, independently enforced" pattern already used for `IsSprinting`/`CanSprint`.

**The existing enemy Baton, confirmed live, is stale the exact same way Thug's Crowbar was:** `ServerStorage.EnemyTemplates.Security.Baton` has `knockbackForce = 15` and **no `swingDelay` attribute at all**, while the current `Crowbar` has `knockbackForce = 90` and `swingDelay = 0.2`. The new player-purchasable Baton is cloned from this enemy copy (reusing its already-authored mesh/sounds, per "reuse the mechanism of a crowbar") but has its `damage`/`knockbackForce`/`swingDelay` explicitly synced to the *current* Crowbar's values rather than trusting the drifted copy.

**Two deliberate simplifications, flagged rather than silently done:**
- The new Baton has **no icon asset** — none was provided, and per this project's own established convention, an asset ID is never guessed. It'll show correctly with a blank icon box and its name still legible (the same graceful fallback every weapon had before its icon existed), until a real icon is supplied.
- The Baton's **first-person viewmodel reuses Crowbar's** (`viewModel = "Crowbar"`) rather than a new dedicated rig — building a whole separate first-person asset for a weapon explicitly described as "reuse the mechanism of a crowbar" is out of scope. Third-person world model, stats, and the stun effect are all genuinely Baton-specific; only the first-person hands/animation are shared with Crowbar.

---

## Part 1 — Include ownership-only weapons (Crowbar, and now Baton) in the shop catalog

**`ServerScriptService.Weapons.Scripts.WeaponShopService`** — in the catalog-building loop:
```lua
for _, template in WEAPONS_FOLDER:GetChildren() do
	if template:IsA("Tool") and template:GetAttribute("Category") then
```
(was `template:GetAttribute("Price")`.) Nothing else in the loop changes — `entry:SetAttribute("Price", template:GetAttribute("Price"))` already safely sets a `nil` value (a no-op) for weapons with no price.

### Verify
- Open the shop's Melee tab: Crowbar now appears, marked "OWNED", clickable through to its stats (with the Upgrade button, not Buy — see Part 4/5 for why upgrading it is legitimate).
- Every other category and "All" still show exactly what they did before — this change only adds entries, never removes any.

---

## Part 2 — Hide the category tabs while a weapon's detail view is open

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`** — in `showDetail`, alongside the existing visibility toggles:
```lua
	weaponGrid.Visible = false
	categoryTabs.Visible = false
	detailPanel.Visible = true
```
In `backButton`'s click handler:
```lua
backButton.MouseButton1Click:Connect(function()
	stopSpin()
	detailPanel.Visible = false
	categoryTabs.Visible = true
	weaponGrid.Visible = true
	if pendingBuyWeapon then
		pendingBuyWeapon = nil
		setSwapMode(false)
	end
end)
```
And in `openShop`, ensure a fresh open always starts on the grid with tabs visible (defensive, in case the shop is reopened while previously left mid-detail-view):
```lua
	detailPanel.Visible = false
	categoryTabs.Visible = true
	weaponGrid.Visible = true
```

### Verify
- Selecting a weapon hides the category row entirely, leaving only the "‹ Back" button to navigate away from the detail view.
- Clicking Back restores the category tabs and the grid, in their correct filtered/selected state.
- Closing and reopening the shop while a detail view was showing starts fresh on the grid with tabs visible, not stuck mid-detail.

---

## Part 3 — Fix the 3D display's orientation

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**, in `showDetail`, add the corrective rotation right after centering:
```lua
		local boundsCFrame, boundsSize = displayModel:GetBoundingBox()
		local centered = CFrame.new(-boundsCFrame.Position) * displayModel:GetPivot()
		displayModel:PivotTo(CFrame.Angles(math.rad(-90), 0, 0) * centered)
```
(replaces the previous single-line `displayModel:PivotTo(CFrame.new(-boundsCFrame.Position) * displayModel:GetPivot())`.)

### Verify
- AK47's detail view now shows the gun upright and side-on, barrel horizontal — not lying flat.
- Check at least one pistol (e.g. Deagle) and Crowbar too — this correction was derived from AK47's specific mesh data; confirm the same `-90°` correction reads correctly for weapons of very different shapes, and flag back if any specific weapon still looks wrong (it would mean that one model was authored with a different convention, not that this fix is wrong in general).

---

## Part 4 — Stun mechanic (shared signal, enforced independently by each movement system)

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
	-- Seconds a hit from this weapon locks the target's movement for, read by ShotResolver. Unset/0
	-- for every weapon except ones that declare it (e.g. the Baton).
	STUN_DURATION_ATTRIBUTE = "stunDuration",
```

**`ServerScriptService.Blaster.Scripts.ShotResolver`**, in `applyDamage`, right after the existing knockback block:
```lua
		-- Stun: stamped as a plain attribute on the target's RootPart rather than calling into
		-- SprintAuthority or EnemyAI directly -- those are separate systems owning player and enemy
		-- movement respectively, and neither should depend on ShotResolver or on each other. Each one
		-- enforces the lockout independently by reading this same shared signal on its own next tick.
		-- Uses os.clock(), matching the clock both SprintAuthority and EnemyAI already tick against.
		local stunDuration = weapon:GetAttribute(Constants.STUN_DURATION_ATTRIBUTE)
		if typeof(stunDuration) == "number" and stunDuration > 0 then
			local rootPart = taggedHumanoid.RootPart
			if rootPart then
				rootPart:SetAttribute("StunnedUntil", os.clock() + stunDuration)
			end
		end
```

**`ServerScriptService.Movement.Scripts.SprintAuthority`**, in `tick`, add a `stunnedUntil` read right after the existing `isMovingFast` line:
```lua
			local isMovingFast = getHorizontalSpeed(rootPart) >= Constants.MIN_DRAIN_SPEED
			local stunnedUntil = rootPart:GetAttribute("StunnedUntil") or 0
```
Fold it into the sprint-grant check:
```lua
			local granted = state.intent and not lockedOut and os.clock() >= state.landingRecoveryUntil and os.clock() >= stunnedUntil
```
Add a third movement clamp, alongside the existing `lockedOut` and landing-recovery ones:
```lua
			if os.clock() < stunnedUntil then
				local humanoid = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.WalkSpeed > 0 then
					humanoid.WalkSpeed = 0
				end
			end
```

**`ServerScriptService.Enemy.Scripts.EnemyAI`**, in `think`, add right after the existing dead/destroyed early-outs, before any state-specific thinking:
```lua
	-- Stun: a weapon-applied lockout (see ShotResolver), read the same way a player's own movement
	-- authority (SprintAuthority) reads it. Returns before any of the state machine below runs, so
	-- the normal think loop can never re-assert a nonzero WalkSpeed out from under the stun.
	local stunnedUntil = self.rootPart:GetAttribute("StunnedUntil") or 0
	if now < stunnedUntil then
		self.humanoid.WalkSpeed = 0
		self:_stopFiring()
		return
	end

	if self.state == STATE.Patrol then
```

### Verify
- Hit a player with a weapon that has `stunDuration` set (the Baton, once Part 5 is applied): their `WalkSpeed` drops to 0 for exactly that long, sprint cannot be engaged during it, and normal movement resumes automatically afterward with no lingering lock.
- Hit an AI enemy with the same weapon: it stops moving *and* stops firing for the duration, then resumes its normal state machine afterward — confirm it doesn't immediately un-stun itself on its next think tick (the bug this design specifically avoids).
- Every weapon without `stunDuration` set: completely unaffected, `StunnedUntil` never gets written for hits from them.
- Stun stacking with an existing lockout or landing-recovery clamp on a player: whichever is more restrictive wins, neither cancels the other early.

---

## Part 5 — Add the Baton

Run once (Command Bar or a temporary `Script`, deleted after):
```lua
local ServerStorage = game:GetService("ServerStorage")

local sourceBaton = ServerStorage.EnemyTemplates.Security.Baton
local weaponsFolder = ServerStorage.Weapons

local existing = weaponsFolder:FindFirstChild("Baton")
if existing then
	existing:Destroy()
end

local baton = sourceBaton:Clone()
baton.Name = "Baton"
baton.Parent = weaponsFolder

-- Synced to the CURRENT Crowbar's tuned values, not the enemy copy's stale ones (see Context).
local crowbar = weaponsFolder.Crowbar
baton:SetAttribute("damage", crowbar:GetAttribute("damage"))
baton:SetAttribute("knockbackForce", crowbar:GetAttribute("knockbackForce"))
baton:SetAttribute("swingDelay", crowbar:GetAttribute("swingDelay"))

-- Baton-specific: shop listing and its one real differentiator from Crowbar.
baton:SetAttribute("Category", "Melee")
baton:SetAttribute("Price", 500)
baton:SetAttribute("stunDuration", 1)

-- Reuses Crowbar's existing first-person viewmodel/animations rather than a new dedicated rig --
-- see Context for why that's a deliberate scope decision, not an oversight.
baton:SetAttribute("viewModel", "Crowbar")

print(`Baton created: damage={baton:GetAttribute("damage")} knockback={baton:GetAttribute("knockbackForce")} price={baton:GetAttribute("Price")} stun={baton:GetAttribute("stunDuration")}s`)
```

### Verify
- `ServerStorage.Weapons.Baton` exists with `damage`/`knockbackForce`/`swingDelay` exactly matching the current `Crowbar`'s values, plus its own `Category`, `Price`, and `stunDuration`.
- Baton appears in the shop's Melee tab and "All", priced at 500, purchasable and upgradeable exactly like any other weapon (reusing `WeaponUpgradeService` — nothing there needed to change, since it already works generically off `GetAttribute(DAMAGE_ATTRIBUTE)` for any weapon name).
- Equip a purchased Baton: swinging it in first person shows Crowbar's viewmodel/animation, but the world-visible weapon and its stats/behavior are the Baton's own.
- Hit a target with the Baton: deals the same damage as the current Crowbar, and additionally stuns them for 1 second (per Part 4) — confirm both effects land together on the same hit, not just one.
- Confirm Crowbar itself is completely unaffected by any of this (no stun, same as always) — the stun is Baton-specific, not something that leaked onto the weapon it was cloned from.

## Verification checklist

- [ ] Crowbar (and Baton) visible and correctly marked "OWNED"/purchasable respectively in the shop's Melee tab.
- [ ] Category tabs are hidden while viewing a weapon's stats; only "‹ Back" is visible; state resets correctly on reopen.
- [ ] 3D display shows weapons upright and side-on, not lying flat, across multiple weapon shapes (rifle, pistol, melee).
- [ ] Stun correctly locks movement (and enemy firing) for players and enemies alike, composes correctly with existing player movement clamps, and never lingers or fails to reassert on an enemy's next think tick.
- [ ] Baton exists, matches Crowbar's current damage/knockback/swing timing exactly, adds a 1s stun, is purchasable/upgradeable through the normal shop flow, and doesn't affect Crowbar itself.
