# Prompt: Weaponary Shop Overflow, Empty-Slot Text, Baton Icon, and Enemy Stun Enforcement

## Context for whoever applies this

This is the user's fourth pass on the Weaponary shop / Baton weapon. The user has reported
"the Baton came out as a Crowbar" three times now. **That diagnosis is only half right, and this
document corrects it with evidence, not another guess.**

Live investigation via Roblox Studio MCP (`inspect_instance`, `script_grep`) on the actual running
Studio instance confirmed:

- `ServerStorage.Weapons.Baton.Blaster` has exactly ONE child, `Body` — matching the enemy Baton's
  single-part mesh. **The world-model reskin worked.**
- `ReplicatedStorage.Blaster.ViewModels.Baton.Blaster.Body` has `Color = (0.067, 0.067, 0.067)`
  (dark metal) and `Material = Metal` — **the first-person viewmodel recolor worked.**
- `ServerStorage.Weapons.Baton.TextureId` is still `rbxassetid://131164107547501` —
  **this is Crowbar's own icon, never cleared when Baton was cloned from it.**

That one forgotten property is what the user actually saw as "it came out as a Crowbar": this
single `TextureId` feeds THREE separate UI surfaces —
`StarterGui."Custom Inventory".InventoryController` (hotbar/backpack icon),
`ServerScriptService.Weapons.Scripts.WeaponShopService` (which copies `template.TextureId` into
the shop catalog's `iconId` attribute at server start), and from there both the shop's weapon-grid
card and the shop's 4-slot inventory column. Every one of the most visible places a player looks
was quietly showing Crowbar's icon. The mesh, the viewmodel, the stun mechanic, and the swing
mechanic were never actually broken.

Separately, from the screenshot the user attached: the shop's category tabs overflow past the
panel's right edge, and the "Empty" placeholder text in unfilled inventory-column slots renders
oversized. Both are also root-caused below with exact numbers, not guessed.

**No new/guessed Roblox asset IDs are used anywhere in this document.** The Baton fix clears the
wrong icon rather than inventing a placeholder image ID — see "Fix 3" for why, and how to drop in
a real icon later with zero code changes.

---

## Fix 1 — Category tabs overflow past the shop panel

### Root cause (measured, not assumed)

- `ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea` is sized `UDim2.new(1, -220, 1, -96)`
  relative to the shop root. The shop root is `870x545` while closed and tweens to `920x580` on
  open (see `WeaponaryShopController.lua`, `openShop()`). So `ShopArea`'s width is **650px closed,
  700px open**.
- `CategoryTabs` is `{1,0},{0,36}` — full width of `ShopArea` — containing 6 `TextButton`s
  (`TabAll`, `TabOwned`, `TabMelee`, `TabPistol`, `TabAutoRifle`, `TabShotgun`), each hardcoded to
  `UDim2.fromOffset(130, 36)`, laid out by a `UIListLayout` with `Padding = UDim.new(0, 8)`.
- Required width for 6 tabs: `6 × 130 + 5 × 8 = 820px`. Available width: **650–700px**. The
  overflow is exactly `120–170px`, which is precisely the "Shotguns" tab (and part of
  "Auto-Rifles") being cut off past the panel edge in the screenshot.

### Why a dynamic fix, not a hardcoded one

A hardcoded per-tab width (e.g. `108px`) would only be correct for exactly 6 tabs and would drift
out of sync the moment a 7th category is added later (the user has already said more guns are
coming). This codebase already solves an identical "fit N things into an available width" problem
computationally in `StarterGui."Custom Inventory".InventoryController.SETTINGS` — this fix follows
that same precedent instead of introducing a second, magic-number way of doing it. It also
self-corrects across the shop's own open/close width tween (650px → 700px), which a fixed number
would not.

### Change — `StarterPlayer.StarterPlayerScripts.WeaponaryShopController`

Add this near the top, after `categoryTabs` is resolved (after line ~59), and call it once at
startup plus whenever the container is resized (covers the open/close tween automatically):

```lua
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
```

No other change needed: every tab already has `TextScaled = true` with no fixed `TextSize`
dependency, so a narrower button just shrinks its own label proportionally — confirmed via
`inspect_instance` on `TabAutoRifle` (`TextScaled = true`, `TextSize = 8` base/unused). Text will
not overflow the shrunk buttons.

---

## Fix 2 — Oversized "Empty" text in inventory-column slots

### Root cause (measured)

`ReplicatedStorage.GuiTemplates.WeaponaryShop.InventoryColumn.Slots.Slot1.EmptyLabel` has
`TextScaled = true` and `Size = {1,0},{1,0}` (fills the entire slot) with **no
`UITextSizeConstraint`**. `TextScaled` with nothing capping it means the font balloons to fill the
whole slot frame — exactly the giant "Empty" text visible in the screenshot.

### Fix — add a cap, same pattern already used elsewhere in this codebase

`StarterPlayer.StarterPlayerScripts.IndicatorClient` already solves this exact problem
(`Instance.new("UITextSizeConstraint")` at line 97) — reuse that pattern rather than inventing a
new one. Apply to **every** `EmptyLabel` under `InventoryColumn.Slots` (there are 4, `Slot1`–`Slot4`,
one per owned-weapon slot):

```lua
-- Run once, e.g. from WeaponaryShopController.lua near the other one-time GUI setup, right after
-- slotsContainer is resolved.
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
```

(Alternatively apply this directly and permanently in Studio to the `EmptyLabel` template inside
`ReplicatedStorage.GuiTemplates.WeaponaryShop.InventoryColumn.Slots.Slot1..4` — either the template
or a one-time runtime pass works; the runtime pass above is included so this document is
copy-paste-applicable without manually touching 4 GUI instances by hand.)

---

## Fix 3 — Baton's icon (the real "came out as a Crowbar" bug)

### The fix

Clear the inherited icon rather than guessing a replacement asset ID (per standing policy: never
guess Roblox asset IDs).

```lua
-- One-time server fix-up. Run in Command Bar (Edit mode) or drop into a server script that runs
-- once at server start, guarded so re-running it is harmless.
local batonTool = game:GetService("ServerStorage").Weapons:FindFirstChild("Baton")
if batonTool and batonTool.TextureId ~= "" then
	batonTool.TextureId = ""
end
```

This is deliberately NOT a placeholder emoji/glyph asset — Tool `TextureId` only accepts an image
(`rbxassetid://...` or `""`), it cannot hold text. Blanking it makes Baton behave exactly like any
other icon-less weapon already does in this codebase today (confirmed convention in
`InventoryController.SETTINGS:updateIcon()`): the hotbar/backpack slot already hides the icon and
shows the weapon's name text instead when `TextureId == ""` — nothing new needs to be built there.

The shop's own two icon displays (`WeaponaryShopController.buildGrid()`'s card icon, and
`refreshInventoryColumn()`'s slot icon) currently do NOT have that same "hide on empty" guard —
they just always set `icon.Image = <possibly-empty string>`, which happens to render as a blank
image (not a broken/red icon), but for full consistency with the hotbar's established pattern,
add the same one-line guard in both places:

**`buildGrid()`**, replace:
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

**`refreshInventoryColumn()`**, replace:
```lua
if tool then
	icon.Image = tool.TextureId
	nameLabel.Text = tool.Name
	icon.Visible = true
	nameLabel.Visible = true
	emptyLabel.Visible = false
```
with:
```lua
if tool then
	local textureId = tool.TextureId
	icon.Image = textureId
	icon.Visible = textureId ~= ""
	nameLabel.Text = tool.Name
	nameLabel.Visible = true
	emptyLabel.Visible = false
```

Both grid cards and inventory-column slots already always render the weapon's name label
separately regardless of icon state, so nothing goes unlabeled — Baton will show as a
named-but-icon-less entry everywhere, consistently, instead of silently wearing Crowbar's icon in
some places.

**When a real Baton icon image exists later:** just set
`ServerStorage.Weapons.Baton.TextureId = "rbxassetid://<the real id>"` once. No code changes
needed — the catalog rebuilds `iconId` from `TextureId` at every server start, the hotbar already
listens for `TextureIdChanged`, and the shop rebuilds icons on every open.

---

## Fix 4 — Enemy stun enforcement was never actually applied

### Root cause (this is new — not previously reported by the user, found during this investigation)

The user's original ask was "ensure it can stun players/enemies too upon hit." The generic
attribute-based stun mechanic (`StunnedUntil`, stamped by `ShotResolver` on any hit from a weapon
with a `stunDuration` attribute — which `Baton` already has, confirmed live at `stunDuration = 1`)
was written into an earlier prompt for THREE places: `ShotResolver` (writer),
`SprintAuthority` (player-side enforcement), and `EnemyAI` (enemy-side enforcement).

Live verification via `script_grep` this session found:
- `ServerScriptService.Blaster.Scripts.ShotResolver` — **live**, stamps `StunnedUntil` correctly.
- `ServerScriptService.Movement.Scripts.SprintAuthority` — **live**, reads it and freezes a
  stunned player's `WalkSpeed` to 0.
- `ServerScriptService.Enemy.Scripts.EnemyAI` — **zero matches for `StunnedUntil` anywhere in the
  file.** The enemy-side half was written into the earlier prompt document but never actually
  landed in the live script. This is why hitting an enemy with the Baton did nothing visible: the
  stun was being stamped correctly, nothing was ever reading it on the enemy side.

### Fix — `ServerScriptService.Enemy.Scripts.EnemyAI`

Add a `wasStunned` field to the state table in `EnemyAI.new` (alongside the other explicit fields,
e.g. right after `thinking = false,`):

```lua
		thinking = false,
		destroyed = false,
		nextThinkTime = 0,
		-- True on the previous think while StunnedUntil (see ShotResolver) was in the future.
		-- Lets the stun handling in `think` tell "just became stunned" / "still stunned" /
		-- "just recovered" apart with one flag instead of three separate checks.
		wasStunned = false,

		connections = {},
```

Then in `EnemyAI:think`, insert the stun check right after the existing dead/health checks and
before the state dispatch (i.e. right before `if self.state == STATE.Patrol then`):

```lua
	-- Shared signal written by ShotResolver on a hit from a weapon declaring stunDuration -- the
	-- same attribute SprintAuthority reads to freeze a stunned PLAYER. An enemy has no sprint
	-- system to hook into, so it is enforced directly here instead.
	local stunnedUntil = self.rootPart:GetAttribute("StunnedUntil") or 0
	local isStunned = now < stunnedUntil
	if isStunned then
		if not self.wasStunned then
			-- Just got stunned: kill any in-progress automatic-fire loop and cancel movement
			-- immediately rather than waiting for the current path/attack to finish naturally.
			self:_stopFiring()
			self:_stopMoving()
			self.wasStunned = true
		end
		self.humanoid.WalkSpeed = 0
		return
	elseif self.wasStunned then
		self.wasStunned = false
		-- The stun killed an automatic weapon's fire loop (see _stopFiring above); if we are
		-- still in Attack once the stun lifts, that loop does not restart on its own.
		if self.state == STATE.Attack and self:_isAutomatic() then
			self:_startAutoFire()
		end
	end

	if self.state == STATE.Patrol then
```

No other change needed: once the stun lifts, the very next think tick runs the normal
`_thinkPatrol` / `_thinkChase` / `_thinkAttack` dispatch as usual, and `_followPath` already
resets `WalkSpeed` to the correct value for whatever state the enemy is in.

---

## Testing checklist (apply in this order)

1. Open the Weaponary shop (`B` key or the button) at both the closed (870px) and mid-tween
   states — confirm all 6 category tabs are fully visible and never crossed the panel's right
   edge, at any panel width.
2. Open a shop slot that's empty (fewer than 4 owned weapons) — confirm "Empty" now renders at a
   normal, readable size instead of filling the slot.
3. Buy the Baton (500 cash). Confirm:
   - Hotbar/backpack slot shows "Baton" text (no icon, no Crowbar icon).
   - Shop's weapon-grid card and the 4-slot inventory column both show "Baton" with no icon —
     never Crowbar's icon.
   - Equip it, swing it at another player: confirm the target's movement freezes (`WalkSpeed = 0`)
     for ~1 second (`stunDuration`), matching Crowbar's own melee feel/animation/hit registration
     (already shared code — this was never broken).
4. Swing the Baton at a live enemy (not a player): confirm the enemy visibly stops moving AND
   stops firing (if mid-`Attack`) for ~1 second, then resumes chasing/attacking normally
   afterward. This is the specific behavior that was completely absent before this fix (verified
   live: no `StunnedUntil` reference existed anywhere in `EnemyAI` prior to this prompt).
5. Confirm an enemy that gets stunned while mid-automatic-weapon fire actually stops shooting
   during the stun window, and resumes firing correctly once it ends (covers the
   `_startAutoFire`/`_stopFiring` interaction in Fix 4 — this is the one edge case worth watching
   closely since a broken restart would look like "the enemy went silent forever" instead of
   "stunned for 1 second").

## Notes for whoever applies this

- Every fix above is additive/corrective to code already confirmed live in this session via
  direct Studio inspection — nothing here is a guess about what's currently broken.
- Once applied and verified against the checklist above, per the user's standing workflow: do NOT
  commit this prompt document to the git repo. Instead write a short plain-prose changelog entry
  (see the repo's existing changelog template/history under `FPSSystem/`) and commit that instead,
  one commit per logical change, then push.
