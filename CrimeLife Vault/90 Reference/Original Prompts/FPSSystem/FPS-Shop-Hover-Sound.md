# Prompt: Reuse the Dialogue Hover Tick Sound on the Shop and Weapon Card Buttons

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**The exact sound, confirmed live, not guessed:** the hover sound in the dialogue response billboard
is `END_TICK_SOUND` in `DialogModule.lua`, which points at `ReplicatedStorage.DialogModule.sounds.tick2`
— `SoundId = "rbxassetid://10066931761"`, `Volume = 0.5`. This document reuses that exact asset id,
not a new one.

**Scope, read directly from what was asked:** "the shop guis" = every interactive control inside the
Weaponry Shop panel that doesn't already play a sound on hover (`CloseButton`, `BackButton`, the
category tabs, the 4 inventory slots) plus the two buttons that already have a *visual* hover effect
from an earlier pass but no sound (`ActionButton`, `EquipButton`). "the weapons gui inside of the
weaponary" = the `WeaponCard` template used in the shop grid, which also already has a visual hover
effect with no sound. Not touched: `weaponaryButton`/`playerCardButton`/`questsButton` (the external
trigger buttons) — those already have their own distinct "Bounce On Click" hover effect from the
UltimateUIPack integration, and weren't named in the request; adding a second, different hover sound
on top of that existing effect would be an unrequested change to something that already has its own
considered feel.

**One shared sound, not eight new ones:** `ActionButton`, `EquipButton`, and `WeaponCard` each carry
their own independent, self-contained hover-effect `LocalScript` (matching the UltimateUIPack's own
per-object convention), while `CloseButton`/`BackButton`/the tabs/the slots are all wired centrally in
`WeaponaryShopController`. Rather than creating a separate `Sound` instance in each of those places,
every location does the same cheap find-or-create check against one `SoundService` child named
`UIHoverSound` — whichever script happens to run first creates it, every other one just plays it.
This avoids both a new shared module (unnecessary for six lines) and four-plus duplicate `Sound`
instances competing in `SoundService`.

---

## Part 1 — `WeaponaryShopController`: close, back, category tabs, inventory slots

Add near the existing `purchaseSound`/`upgradeSound` setup:

```lua
local HOVER_SOUND_ID = "rbxassetid://10066931761"

local hoverSound = SoundService:FindFirstChild("UIHoverSound")
if not hoverSound then
	hoverSound = Instance.new("Sound")
	hoverSound.Name = "UIHoverSound"
	hoverSound.SoundId = HOVER_SOUND_ID
	hoverSound.Volume = 0.5
	hoverSound.Parent = SoundService
end
```

Add a hover connection for `closeButton`, right after the existing `closeButton.MouseButton1Click:Connect(closeShop)`:

```lua
closeButton.MouseEnter:Connect(function()
	hoverSound:Play()
end)
```

Add one for `backButton`, right after its existing click handler block:

```lua
backButton.MouseEnter:Connect(function()
	hoverSound:Play()
end)
```

In the category tabs loop, currently:

```lua
for _, tab in categoryTabs:GetChildren() do
	if tab:IsA("TextButton") then
		tab.MouseButton1Click:Connect(function()
```

add one line right after the `if tab:IsA("TextButton") then` line:

```lua
for _, tab in categoryTabs:GetChildren() do
	if tab:IsA("TextButton") then
		tab.MouseEnter:Connect(function()
			hoverSound:Play()
		end)
		tab.MouseButton1Click:Connect(function()
```

In the inventory slots loop, currently:

```lua
for i = 1, 4 do
	local slot = slotsContainer:WaitForChild("Slot" .. i) :: ImageButton
	slot.MouseButton1Click:Connect(function()
```

add one line the same way:

```lua
for i = 1, 4 do
	local slot = slotsContainer:WaitForChild("Slot" .. i) :: ImageButton
	slot.MouseEnter:Connect(function()
		hoverSound:Play()
	end)
	slot.MouseButton1Click:Connect(function()
```

### Verify

- [ ] Hovering the shop's close button, the back button, every category tab, and all 4 inventory
      slots plays the tick sound — including empty slots (they're still valid hover/click targets
      during slot-picking).
- [ ] Only one `UIHoverSound` exists in `SoundService` after opening the shop (confirm no duplicates).
- [ ] None of the existing click behaviors changed — this only adds `MouseEnter` connections.

---

## Part 2 — `ActionButton`'s `HoverAndClick` script (Buy/Upgrade button)

Add the same find-or-create near the top, and play it in the existing `MouseEnter` handler:

```lua
--// Hover And Click, adapted from UltimateUIPack.
local btn = script.Parent
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local HOVER_SOUND_ID = "rbxassetid://10066931761"
local hoverSound = SoundService:FindFirstChild("UIHoverSound")
if not hoverSound then
	hoverSound = Instance.new("Sound")
	hoverSound.Name = "UIHoverSound"
	hoverSound.SoundId = HOVER_SOUND_ID
	hoverSound.Volume = 0.5
	hoverSound.Parent = SoundService
end

local origSize = btn.Size
local hoverScl = 1.1
local clickScl = 0.9
local tInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function makeTween(scl)
	local newSize = UDim2.new(
		origSize.X.Scale * scl,
		origSize.X.Offset * scl,
		origSize.Y.Scale * scl,
		origSize.Y.Offset * scl
	)
	return TS:Create(btn, tInfo, { Size = newSize })
end

btn.MouseEnter:Connect(function()
	hoverSound:Play()
	makeTween(hoverScl):Play()
end)

btn.MouseLeave:Connect(function()
	makeTween(1):Play()
end)

btn.MouseButton1Click:Connect(function()
	local shrink = makeTween(clickScl)
	local reset = makeTween(1)
	shrink:Play()
	shrink.Completed:Connect(function()
		reset:Play()
	end)
end)
```

### Verify

- [ ] Hovering the Buy/Upgrade button (whichever state it's in) plays the tick sound alongside its
      existing scale-up, exactly once per hover, not once per frame while hovering.

---

## Part 3 — `EquipButton`'s and `WeaponCard`'s `StrokeHover` scripts

Both templates carry an identical `StrokeHover` script. Apply the same change to **both**:

```lua
--// Stroke Scale On Hover, adapted from UltimateUIPack.
local btn = script.Parent
local stroke = btn.UIStroke
local TS = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local HOVER_SOUND_ID = "rbxassetid://10066931761"
local hoverSound = SoundService:FindFirstChild("UIHoverSound")
if not hoverSound then
	hoverSound = Instance.new("Sound")
	hoverSound.Name = "UIHoverSound"
	hoverSound.SoundId = HOVER_SOUND_ID
	hoverSound.Volume = 0.5
	hoverSound.Parent = SoundService
end

local origThick = stroke.Thickness
local hoverThick = origThick + 2
local tInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function makeTween(thick)
	return TS:Create(stroke, tInfo, { Thickness = thick })
end

btn.MouseEnter:Connect(function()
	hoverSound:Play()
	makeTween(hoverThick):Play()
end)

btn.MouseLeave:Connect(function()
	makeTween(origThick):Play()
end)
```

### Verify

- [ ] Hovering the Equip/Dequip button plays the tick sound alongside its existing stroke-grow.
- [ ] Hovering any weapon card in the grid plays the tick sound alongside its existing stroke-grow —
      every card, since this is on the template (every clone gets its own copy of the fix).
- [ ] Rapidly moving the mouse across several weapon cards in a row plays the sound once per card
      entered, without the sound instances fighting each other or cutting off oddly — `Sound:Play()`
      restarting the same instance each time is fine for a tick this short, but confirm it actually
      sounds fine in practice with many cards in the grid.

## Master verification checklist

- [ ] Every shop control named above plays the tick sound on hover: close, back, category tabs,
      inventory slots, Buy/Upgrade, Equip/Dequip, and every weapon card.
- [ ] Exactly one `UIHoverSound` instance exists in `SoundService`, regardless of how many of the
      above get hovered or how many weapon cards exist in the grid.
- [ ] Nothing else about any of these controls' existing behavior (click actions, visual hover
      tweens, purchase/upgrade sounds, cash burst) changed.
- [ ] The three external trigger buttons (`weaponaryButton`, `playerCardButton`, `questsButton`) are
      unchanged — confirm they still only play their existing bounce effect, no new sound.

## Notes for whoever applies this

- The exact `SoundId` and the current full source of every touched script were verified live
  immediately before this was written.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
