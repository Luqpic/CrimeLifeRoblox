# Prompt: 3D Display Orientation/Framing Fixes, Baton Rebuilt as a True Crowbar Duplicate, "Owned" Shop Tab

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Context, confirmed live before writing this — read this first

**A tooling limitation, disclosed rather than papered over:** `screen_capture` is not producing usable output for Play-mode 2D GUI content in this environment (returns a blank/void image regardless of parameters — this appears to capture the 3D edit-time viewport, not a running client's actual rendered frame with GUI overlays). The orientation fix below was derived and cross-checked using direct CFrame vector math (`GetBoundingBox`, `UpVector`/`RightVector`/`LookVector`, cross/dot products) rather than a screenshot, which is why the previous pass's fix, while mathematically consistent, still came out wrong in a way pure vector math alone couldn't have caught (see below) — the "flip it" direction in Part 1 is applied directly from your report, not re-derived from scratch, since there's no way to visually re-confirm it from this end. Please report back if it's still not right after this change; the next step would be an additional 180° correction on top, not starting over.

**Why the previous Baton "didn't work at all," confirmed live:** it was cloned from `ServerStorage.EnemyTemplates.Security.Baton` — a Tool built independently during an earlier pass, not a copy of the player Crowbar. Whatever made it not work was somewhere in that independently-built mechanism. Rebuilding it as a true duplicate of the *current* Crowbar Tool sidesteps needing to find that bug at all — it now has byte-identical mechanics by construction.

**A real risk found while planning that duplicate, and designed around rather than ignored:** `ReplicatedStorage.Blaster.ViewModels.Crowbar`'s first-person model is a single plain `Part` (not a detailed mesh — it's a simple block, `SpecialMesh`-free) that carries its `BodyJoint` `Motor6D`, `MuzzleAttachment`, and swing-trail `Attachment`s (`TrailStart`/`TrailEnd`/`Trail`) **directly on that same part**. Destroying and replacing it wholesale (to swap in a detailed baton mesh) would destroy that joint and those attachments along with it, breaking the viewmodel's hand-positioning and swing trail — a different, more subtle way for "the Baton doesn't work" to resurface. So: the **world model** (third-person, what everyone actually sees) gets a full mesh swap, confirmed safe because it's a self-contained assembly with no external joint pointing into it (confirmed live: the enemy Baton's own Blaster.Body has its own complete `MuzzleAttachment`/`Trail` set already). The **viewmodel** (first-person, only the wielder sees it, already just an abstract block) gets a safe recolor instead of a mesh swap — full duplication of the folder structure (so it's genuinely independent, not shared with Crowbar's), just not a structural mesh replacement on the part that would risk breaking its rig.

---

## Part 1 — Flip the "upside down" gun orientation

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**, in `showDetail`, flip the sign of the base rotation:
```lua
local GUN_DISPLAY_ROTATION = CFrame.Angles(math.rad(90), 0, 0)
```
(was `math.rad(-90)`.)

### Verify
- AK47 (and other guns) no longer render upside down. If it's *still* upside down after this, that means the fix needs an additional 180° on top rather than a different sign — report back rather than me guessing further blind.

---

## Part 2 — Melee weapons display vertically upright, not horizontally

Still in `showDetail`, add a category-aware rotation and a slower spin rate for melee weapons:
```lua
local GUN_DISPLAY_ROTATION = CFrame.Angles(math.rad(90), 0, 0)
local MELEE_EXTRA_ROTATION = CFrame.Angles(0, 0, math.rad(90))
local GUN_ROTATION_SPEED = math.rad(40) -- degrees/second, expressed in radians
local MELEE_ROTATION_SPEED = math.rad(20) -- slower -- melee weapons read larger/closer in the box
```
Replace the model-setup block inside `showDetail` with:
```lua
	local blasterTemplate = entry:FindFirstChild("Blaster")
	if blasterTemplate then
		local displayModel = blasterTemplate:Clone()
		displayModel.Parent = detailViewport

		local isMelee = entry:GetAttribute("Category") == "Melee"
		local displayRotation = if isMelee then MELEE_EXTRA_ROTATION * GUN_DISPLAY_ROTATION else GUN_DISPLAY_ROTATION
		local rotationSpeed = if isMelee then MELEE_ROTATION_SPEED else GUN_ROTATION_SPEED

		-- Orientation is corrected FIRST, then the bounding box is measured -- measuring before
		-- correcting would describe the model's raw, uncorrected axes, not the ones actually facing
		-- the camera once displayed, which is what framing needs to be based on.
		local rawCFrame = displayModel:GetPivot()
		local boundsCFrame, rawSize = displayModel:GetBoundingBox()
		displayModel:PivotTo(displayRotation * CFrame.new(-boundsCFrame.Position) * rawCFrame)

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
		currentSpinConnection = RunService.RenderStepped:Connect(function(dt)
			displayModel:PivotTo(displayModel:GetPivot() * CFrame.Angles(0, rotationSpeed * dt, 0))
		end)
	end
```
(This replaces the whole model-setup block from Part 3/5 of the previous prompt — the centering, camera, and spin-connection logic have all moved here since framing now depends on the corrected, not raw, bounding box.)

### Verify
- Crowbar and Baton both display vertically (standing upright), not lying horizontally like the guns.
- Guns are unaffected — still horizontal, upright, barrel-side profile.
- Baton no longer visibly clips/overflows the viewport box at any point during its spin; its rotation is noticeably slower than a gun's.
- Switching between a gun and a melee weapon in the detail view correctly swaps both the orientation and the spin speed each time, not just on the first selection.

---

## Part 3 — Rebuild the Baton as a true Crowbar duplicate

Run once (Command Bar or a temporary `Script`, deleted after) — replaces the previous attempt entirely:
```lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local weaponsFolder = ServerStorage.Weapons
local viewModelsFolder = ReplicatedStorage.Blaster.ViewModels
local batonMeshSource = ServerStorage.EnemyTemplates.Security.Baton:FindFirstChild("Blaster")

-- Remove the previous attempt entirely.
local existingBaton = weaponsFolder:FindFirstChild("Baton")
if existingBaton then
	existingBaton:Destroy()
end
local existingBatonViewModel = viewModelsFolder:FindFirstChild("Baton")
if existingBatonViewModel then
	existingBatonViewModel:Destroy()
end

-- 1. Duplicate the Crowbar Tool wholesale -- mechanics, scripts, animations, sounds, everything --
-- guaranteeing identical behavior by construction rather than by re-syncing individual attributes.
local baton = weaponsFolder.Crowbar:Clone()
baton.Name = "Baton"
baton.Parent = weaponsFolder

-- 2. Reskin the WORLD model (third-person, what everyone sees): safe to fully replace, confirmed
-- live to be a self-contained assembly with its own MuzzleAttachment/Trail, no external joint
-- pointing into it.
local oldWorldBlaster = baton:FindFirstChild("Blaster")
if oldWorldBlaster and batonMeshSource then
	local newWorldBlaster = batonMeshSource:Clone()
	newWorldBlaster.Name = "Blaster"
	newWorldBlaster.Parent = baton
	oldWorldBlaster:Destroy()
end

-- 3. Duplicate the viewmodel folder wholesale too, so it's a genuinely independent copy -- but
-- reskin it with a recolor only, NOT a mesh swap (see Context for why a mesh swap here is risky).
local batonViewModel = viewModelsFolder.Crowbar:Clone()
batonViewModel.Name = "Baton"
batonViewModel.Parent = viewModelsFolder

local viewModelBody = batonViewModel:FindFirstChild("Body", true)
if viewModelBody and viewModelBody:IsA("BasePart") then
	viewModelBody.Color = Color3.fromRGB(17, 17, 17) -- matches the enemy Baton's own "Really black"
	viewModelBody.Material = Enum.Material.Metal
end

-- 4. Baton-specific data: its own viewmodel (not Crowbar's), shop listing, and its one real
-- mechanical difference from Crowbar.
baton:SetAttribute("viewModel", "Baton")
baton:SetAttribute("Category", "Melee")
baton:SetAttribute("Price", 500)
baton:SetAttribute("stunDuration", 1)

print(`Baton rebuilt as a Crowbar duplicate. damage={baton:GetAttribute("damage")} knockback={baton:GetAttribute("knockbackForce")} swingDelay={baton:GetAttribute("swingDelay")} viewModel={baton:GetAttribute("viewModel")}`)
```

### Verify
- `ServerStorage.Weapons.Baton`'s `damage`/`knockbackForce`/`swingDelay`/every other combat attribute matches `Crowbar`'s exactly (confirmed by construction, but check anyway) — no manual "sync" step needed or present.
- Buy a Baton and actually swing it at a target: it deals damage, applies knockback, and now also stuns (Part 4 of the previous prompt) — confirms it fully works, unlike the previous attempt.
- Third-person: Baton visibly looks like a baton (the reskinned world mesh), not a crowbar.
- First-person: Baton's viewmodel is a distinctly-colored (dark metal) block rather than Crowbar's — a modest but safe visual difference; the swing trail and hand positioning both still work correctly, confirming the joint/attachments survived the duplicate-and-recolor approach.
- Crowbar itself is completely unaffected by any of this.

---

## Part 4 — "Owned" section in the shop

**`ReplicatedStorage.GuiTemplates.WeaponaryShop`** — add a 6th category tab. Run once:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConstants = require(ReplicatedStorage.Movement.Constants)
local categoryTabs = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.CategoryTabs

local tab = Instance.new("TextButton")
tab.Name = "TabOwned"
tab.LayoutOrder = 2 -- right after "All"; existing tabs after it keep their relative order via UIListLayout
tab.Size = UDim2.fromOffset(130, 36)
tab.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
tab.BackgroundTransparency = 0.3
tab.Font = Enum.Font.GothamBold
tab.TextScaled = true
tab.TextColor3 = Color3.new(1, 1, 1)
tab.Text = "Owned"
tab.Parent = categoryTabs

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
tabCorner.Parent = tab
```

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**, in `buildGrid`, change the category-matching logic:
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
(replaces the previous `if currentCategory == "All" or category == currentCategory then` line and its `local category = entry:GetAttribute("Category")` above it.)

No other changes needed — the tab-click handler already reads `tab.Name:gsub("^Tab", "")` generically, so `TabOwned` becomes `currentCategory = "Owned"` automatically, and the existing `backpack.ChildAdded`/`ChildRemoved` listeners already rebuild the grid live while the shop is open, which is exactly what keeps the "Owned" tab's contents current as purchases happen.

### Verify
- A new "Owned" tab appears between "All" and "Melee".
- Selecting it shows exactly your currently-owned weapons (Crowbar plus anything purchased), across all categories, price-sorted the same as every other tab.
- Buying or swapping a weapon while the "Owned" tab is active updates its contents immediately, without needing to switch tabs and back.
- Every other tab's behavior is completely unchanged.

## Verification checklist

- [ ] Guns display right-side up (not upside down); melee weapons display vertically upright (not horizontal); neither regressed the other.
- [ ] No weapon visibly overflows/clips the viewport box at any point during its spin; melee weapons spin noticeably slower than guns.
- [ ] Baton is a fully working, independent duplicate of Crowbar (same combat stats, own reskinned world model, own recolored viewmodel, own stun effect) — confirmed by actually hitting something with it, not just by inspecting attributes.
- [ ] "Owned" tab exists, shows exactly the player's current weapons, and stays live-updated while the shop is open.
