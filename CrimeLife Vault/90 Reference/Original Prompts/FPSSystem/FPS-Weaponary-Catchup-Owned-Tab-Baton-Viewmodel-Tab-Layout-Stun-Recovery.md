# Prompt: Catch-Up Pass — Owned Tab, Baton Viewmodel, Tab Width, Empty Label, Icon Guards, Stun Recovery

Paste this whole document into Claude Code with Roblox Studio MCP access. It is self-contained.

## Context — read this first

This is a **recovery pass**. Two earlier prompt documents
(`FPS-Weaponary-3D-Display-Fixes-Baton-Rebuild-Owned-Tab.md` and
`FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes.md`) were applied at some point,
but the live place has since lost part of what they landed while keeping the rest. Every claim
below was re-verified live against the actual running Studio instance immediately before writing
this — nothing here is assumed from the older documents.

**What survived (do NOT re-apply):**

- `ServerStorage.Weapons.Baton` exists as a working Tool, combat attributes matching Crowbar
  (`damage = 45`, `knockbackForce = 90`, `swingDelay = 0.2`, `stunDuration = 1`, `Price = 500`,
  `Category = "Melee"`), world model already reskinned (`Baton.Blaster` has a single `Body` child).
- `Baton.TextureId` is already `""` — the inherited Crowbar icon was already cleared.
- `EnemyAI:think` already has a stun block (reads `StunnedUntil`, zeroes `WalkSpeed`).

**What was superseded and must NOT be reverted:** the earlier "flip `GUN_DISPLAY_ROTATION`" and
"melee extra rotation" fixes are gone because a later pass *replaced* that whole approach.
`showDetail` now derives each model's orientation from its own bounding-box axes
(`WeaponaryShopController` ~lines 229–253). That code's own comment records the measurement: a
fixed rotation framed 12 of 17 weapons correctly, the per-model derivation frames 17 of 17.
**Leave the orientation block alone.** This document does not touch it.

**A structural change since the earlier documents were written:** those documents described
`ReplicatedStorage.Blaster.ViewModels.Crowbar`'s first-person model as "a single plain `Part`".
That is no longer true — `ViewModels.Crowbar.Blaster` now contains `Body` plus `TrimA`–`TrimE`
(6 parts). `Body` still carries the rig-critical children: `BodyJoint` (`Motor6D`),
`MuzzleAttachment`, `TrailStart`, `TrailEnd`, and `Trail`. The original reasoning therefore holds
*more* strongly, not less: the Baton viewmodel below is created by duplication and **recolour
only**, never a mesh swap, because destroying `Body` would take the Motor6D and the swing trail
with it.

**No new Roblox asset IDs are introduced anywhere in this document.**

---

## Part 1 — Category tabs must size themselves

### Why this comes first

Part 2 adds a sixth category tab. `CategoryTabs` is `{1,0},{0,36}` — full width of `ShopArea`,
which is `UDim2.new(1, -220, 1, -96)` against a shop root that is `870x545` closed and tweens to
`920x580` open, so **650px closed, 700px open**. Each tab is hardcoded `UDim2.fromOffset(130, 36)`
with a `UIListLayout` `Padding` of 8.

- Today, 5 tabs: `5 x 130 + 4 x 8 = 682px`. Already overflows the 650px closed state.
- After Part 2, 6 tabs: `6 x 130 + 5 x 8 = 820px`. Overflows both states badly.

So this is not optional polish — Part 2 depends on it.

A computed width rather than a hardcoded one, because the user has said more guns are coming and a
per-tab magic number would drift the moment a 7th category appears. It also self-corrects across
the shop's own open/close tween. `StarterGui."Custom Inventory".InventoryController.SETTINGS`
already solves an identical "fit N things into an available width" problem computationally; this
follows that precedent rather than introducing a second way of doing it.

### Change — `StarterPlayer.StarterPlayerScripts.WeaponaryShopController`

`categoryTabs` is resolved at line 55. Insert this immediately after the
`local actionButton = ...` block (i.e. after line 63, before `local BUY_COLOR`):

```lua
-- Tabs carry a fixed Padding but a COMPUTED equal width, so any number of category tabs exactly
-- fills CategoryTabs' width instead of overflowing it. Re-run on resize: the shop's own open/close
-- tween moves ShopArea (and therefore CategoryTabs) between 650px and 700px, and this keeps one
-- calculation correct in both states and for however many categories exist later.
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
	local tabWidth = math.max((available - TAB_PADDING * (#tabs - 1)) / #tabs, 1)
	for _, tab in tabs do
		tab.Size = UDim2.fromOffset(math.floor(tabWidth), TAB_HEIGHT)
	end
end

categoryTabs:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCategoryTabs)
categoryTabs.ChildAdded:Connect(layoutCategoryTabs)
layoutCategoryTabs()
```

The `ChildAdded` connection is what makes this survive a 7th tab being added later without anyone
remembering to re-run the layout.

No other change needed: every existing tab already has `TextScaled = true` (confirmed live on
`TabMelee`: `TextScaled = true`, `TextSize = 8` unused as a base), so a narrower button shrinks its
own label rather than overflowing it.

### Verify
- All tabs fit inside the panel with the shop both closed-width and open-width, with no tab crossing
  the right edge at any point during the open tween.

---

## Part 2 — "Owned" category tab

### Instance change — run once (Command Bar, or a temporary `Script` deleted afterwards)

Cloned from an existing tab rather than built from `Instance.new`, so the corner radius, font,
colours and transparency stay identical by construction instead of being re-specified from
constants that no longer match (confirmed live: the real tabs use `BackgroundColor3 = (0,0,0)` at
`BackgroundTransparency = 0.3`, not the HUD constant an earlier draft assumed).

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local categoryTabs = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.CategoryTabs

if not categoryTabs:FindFirstChild("TabOwned") then
	-- "Owned" sits directly after "All", so every tab currently at or past that slot shifts down
	-- one. Done by relative bump rather than by re-numbering to literals, so it stays correct
	-- whatever the existing tabs happen to be numbered.
	for _, child in categoryTabs:GetChildren() do
		if child:IsA("TextButton") and child.LayoutOrder >= 2 then
			child.LayoutOrder += 1
		end
	end

	local tab = categoryTabs.TabMelee:Clone()
	tab.Name = "TabOwned"
	tab.Text = "Owned"
	tab.LayoutOrder = 2
	tab.Parent = categoryTabs
end
```

### Script change — `WeaponaryShopController`, in `buildGrid`

Replace lines 331–337:

```lua
	local entries = {}
	for _, entry in catalog:GetChildren() do
		local category = entry:GetAttribute("Category")
		if currentCategory == "All" or category == currentCategory then
			table.insert(entries, entry)
		end
	end
```

with:

```lua
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
```

`isOwned` is defined at line 108, well above `buildGrid` at line 324, so it is in scope.

Nothing else is needed: the tab-click handler already derives the category generically via
`tab.Name:gsub("^Tab", "")`, so `TabOwned` becomes `currentCategory = "Owned"` on its own, and the
existing `backpack.ChildAdded` / `ChildRemoved` listeners already rebuild the grid live, which is
what keeps the Owned tab current as purchases and swaps happen.

### Verify
- An "Owned" tab appears between "All" and "Melee".
- It lists exactly the currently-owned weapons across all categories, price-sorted like every other tab.
- Buying or swapping a weapon while "Owned" is the active tab updates it immediately, with no tab switch.
- Every other tab behaves exactly as before.

---

## Part 3 — Baton's own first-person viewmodel

### What is actually missing

`ServerStorage.Weapons.Baton` currently has `viewModel = "Crowbar"`, and
`ReplicatedStorage.Blaster.ViewModels.Baton` does not exist. So in first person the Baton is
literally rendering Crowbar's viewmodel.

### Run once

```lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local viewModels = ReplicatedStorage.Blaster.ViewModels
local baton = ServerStorage.Weapons:FindFirstChild("Baton")
assert(baton, "ServerStorage.Weapons.Baton is missing -- stop and re-check before continuing")

local existing = viewModels:FindFirstChild("Baton")
if existing then
	existing:Destroy()
end

-- Duplicated wholesale so the rig, arms, AnimationController and Animations are independent of
-- Crowbar's rather than shared with them.
local batonViewModel = viewModels.Crowbar:Clone()
batonViewModel.Name = "Baton"
batonViewModel.Parent = viewModels

-- RECOLOUR ONLY -- deliberately not a mesh swap. Blaster.Body carries BodyJoint (Motor6D),
-- MuzzleAttachment, TrailStart, TrailEnd and Trail; replacing the part would destroy the hand
-- rigging and the swing trail along with it. Every part under Blaster is recoloured (Body plus
-- TrimA..TrimE) so the whole model reads as a baton, not just its core part.
local blaster = batonViewModel:FindFirstChild("Blaster")
if blaster then
	for _, part in blaster:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(17, 17, 17)
			part.Material = Enum.Material.Metal
		end
	end
end

baton:SetAttribute("viewModel", "Baton")

print(`Baton viewmodel created. viewModel attribute = {baton:GetAttribute("viewModel")}`)
```

### Verify
- Equip the Baton in first person: the viewmodel is dark metal and visibly distinct from Crowbar's.
- The swing trail still draws, and the hands/arms are still positioned correctly — this is the
  check that confirms `BodyJoint` and the `Trail*` attachments survived.
- Equip the Crowbar afterwards: completely unchanged, still its own colour, own trail, own rig.

---

## Part 4 — Cap the oversized "Empty" slot text

### Root cause (measured live)

`ReplicatedStorage.GuiTemplates.WeaponaryShop.InventoryColumn.Slots.Slot1.EmptyLabel` has
`TextScaled = true` and `Size = {1,0},{1,0}` with **no `UITextSizeConstraint`** (confirmed: zero
children). `TextScaled` with nothing capping it balloons the font to fill the whole slot.

### Change — `WeaponaryShopController`

`StarterPlayer.StarterPlayerScripts.IndicatorClient` already solves this exact problem with a
`UITextSizeConstraint` (line 97) — reuse that pattern rather than inventing a second one.

There is already a `for i = 1, 4 do` loop at lines 158–174 that resolves each slot to wire its
click handler. Add the constraint inside that existing loop rather than adding a second 1..4 pass.
Insert immediately after `local slot = slotsContainer:WaitForChild("Slot" .. i) :: ImageButton`
(line 159):

```lua
	-- TextScaled with no cap makes "Empty" fill the entire slot frame.
	local emptyLabel = slot:FindFirstChild("EmptyLabel")
	if emptyLabel and not emptyLabel:FindFirstChildOfClass("UITextSizeConstraint") then
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 18
		constraint.MinTextSize = 10
		constraint.Parent = emptyLabel
	end
```

### Verify
- With fewer than 4 owned weapons, the empty slots read "Empty" at a normal size, not filling the slot.

---

## Part 5 — Icon visibility guards

Baton has no icon (`TextureId = ""`), which is correct and deliberate — blanking it rather than
guessing a placeholder asset ID. `InventoryController.SETTINGS:updateIcon()` already establishes
the convention: hide the icon and let the name text carry the weapon when `TextureId == ""`. The
shop's two icon surfaces do not yet follow it — they assign a possibly-empty string unconditionally.

**`refreshInventoryColumn`** (lines 129–134), replace:

```lua
		if tool then
			icon.Image = tool.TextureId
			nameLabel.Text = tool.Name
			icon.Visible = true
```

with:

```lua
		if tool then
			local textureId = tool.TextureId
			icon.Image = textureId
			nameLabel.Text = tool.Name
			icon.Visible = textureId ~= ""
```

**`buildGrid`** (line 346), replace:

```lua
		card:WaitForChild("Icon").Image = entry:GetAttribute("iconId") or ""
```

with:

```lua
		local iconId = entry:GetAttribute("iconId") or ""
		local icon = card:WaitForChild("Icon")
		icon.Image = iconId
		icon.Visible = iconId ~= ""
```

Both surfaces already render the weapon's name separately, so nothing goes unlabeled.

**When a real Baton icon exists later:** set
`ServerStorage.Weapons.Baton.TextureId = "rbxassetid://<the real id>"` once, no code changes — the
catalog rebuilds `iconId` from `TextureId` each server start, and the shop rebuilds icons on open.

### Verify
- Baton shows as a named, icon-less entry in the grid card and in the 4-slot inventory column —
  never wearing Crowbar's icon, and with no broken-image box.
- Every weapon that *does* have an icon still shows it.

---

## Part 6 — Enemy stun recovery (a live bug, not just a missing nicety)

### Root cause (found live this pass)

The stun block currently in `EnemyAI:think` (lines 905–913) is a simplified version:

```lua
	local stunnedUntil = self.rootPart:GetAttribute("StunnedUntil") or 0
	if now < stunnedUntil then
		self.humanoid.WalkSpeed = 0
		self:_stopFiring()
		return
	end
```

`_startAutoFire()` is called from exactly one place: `_setState`, on **entry** into `STATE.Attack`
(line 676). An enemy stunned while already in Attack has its fire loop killed by `_stopFiring()`,
and when the stun lifts it is *still* in Attack — so `_setState` never re-runs and the loop is never
restarted. **A stunned enemy holding an automatic weapon stops firing permanently**, until it
happens to leave and re-enter Attack (target lost → Search → Chase → Attack). That reads in-game as
"the enemy went silent forever", not "stunned for 1 second".

### Change 1 — `EnemyAI.new` state table

Add after `nextThinkTime = 0,` (line 117):

```lua
		-- True while the previous think saw StunnedUntil in the future. One flag distinguishes
		-- "just stunned" / "still stunned" / "just recovered", so recovery work runs exactly once.
		wasStunned = false,
```

### Change 2 — replace the stun block in `EnemyAI:think` (lines 905–913)

```lua
	-- Shared signal written by ShotResolver on a hit from a weapon declaring stunDuration -- the
	-- same attribute SprintAuthority reads to freeze a stunned PLAYER. An enemy has no sprint
	-- system to hook into, so it is enforced directly here.
	local stunnedUntil = self.rootPart:GetAttribute("StunnedUntil") or 0
	if now < stunnedUntil then
		if not self.wasStunned then
			-- Cancel movement and firing once, on entry, rather than re-issuing both every tick.
			self:_stopFiring()
			self:_stopMoving()
			self.wasStunned = true
		end
		self.humanoid.WalkSpeed = 0
		return
	elseif self.wasStunned then
		self.wasStunned = false
		-- _startAutoFire is only ever called on entry into Attack (_setState), so an enemy stunned
		-- while already attacking would otherwise never resume firing. Restarting it bumps
		-- fireGeneration, so this cannot leave two loops running.
		if self.state == STATE.Attack and self:_isAutomatic() then
			self:_startAutoFire()
		end
	end
```

All four helpers used here exist: `_stopMoving` (line 221), `_stopFiring` (355), `_isAutomatic`
(361), `_startAutoFire` (635).

Nothing else needed — once the stun lifts, the next think tick runs the normal
`_thinkPatrol`/`_thinkChase`/`_thinkAttack` dispatch, and `_followPath` already restores the right
`WalkSpeed` for the current state.

### Verify
- Swing the Baton at a live enemy: it visibly stops moving **and** stops firing for ~1 second, then
  resumes chasing/attacking normally.
- **The specific regression check:** stun an enemy that is mid-burst with an *automatic* weapon
  while it is already in Attack. It must resume firing once the stun ends. Before this change it
  goes silent permanently.
- Stun a semi-automatic enemy too — it should be unaffected by the restart branch (`_isAutomatic`
  gates it) and resume its one-shot-per-tick firing normally.

---

## Verification checklist

- [ ] All 6 category tabs fit the panel at both closed and open widths, none clipped.
- [ ] "Owned" tab exists between "All" and "Melee", lists exactly the owned weapons, and stays
      live-updated while the shop is open.
- [ ] Baton has its own dark-metal first-person viewmodel; swing trail and hand positions still work.
- [ ] Crowbar is completely unaffected — own viewmodel, own colour, own trail.
- [ ] "Empty" slot text renders at a normal size.
- [ ] Baton appears named-but-icon-less everywhere; icon-bearing weapons still show their icons.
- [ ] A stunned automatic-weapon enemy resumes firing after the stun — this is the bug fix, check it
      explicitly rather than assuming.
- [ ] The 3D weapon display is untouched: all 17 weapons still frame correctly in the detail
      viewport, guns and melee alike. If this regressed, the orientation block was edited by
      mistake — revert that, it was not in scope.

## Notes for whoever applies this

- Every root cause above was re-verified live via `inspect_instance` / `script_read` / `script_grep`
  against the running Studio instance immediately before this was written.
- Line numbers cited are as `script_read` reports them. Note that `script_grep` reports *different*
  line numbers for the same script (observed skew of ~104 lines in `EnemyAI`) — trust `script_read`,
  or match on the quoted code rather than the number.
- Per the user's standing workflow: do NOT commit this prompt document to the git repo. Once applied
  and verified, write a short plain-prose changelog entry following the template used by the
  existing entries under `FPSSystem/`, commit that instead, one commit per logical change, then push.
