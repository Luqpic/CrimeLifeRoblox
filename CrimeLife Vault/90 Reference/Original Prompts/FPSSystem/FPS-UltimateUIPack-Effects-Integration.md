# Prompt: Wire Up UltimateUIPack Effects on the Shop, Player Card, and Weapon Buttons

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**What was actually added, confirmed live:** `StarterGui.UltimateUIPack` — a demo `ScreenGui` from a
third-party asset ("Ultimate UI Pack"), containing example buttons/frames each with their own
self-contained `Tween` `LocalScript` (operating on `script.Parent`, i.e. drag-and-drop style — the
script assumes it's sitting inside the exact button/frame it animates). `MainOpener` is just the
asset's own internal demo-navigation UI (switches between its two showcase panels) — not something to
integrate, ignore it. The actually useful pieces are under `ButtonEffects` (7 button micro-interaction
demos) and `FrameOpenings` (4 frame-open transition demos).

**A naming mismatch worth flagging before using the wrong one:** the demo button named
**"Stroke Visible On Hover"** does *not* do what its name says. Its `Tween` script is actually a
continuous, non-hover-gated "shine sweep" effect (comment: *"a shiny line will appear randomly"*),
requires a `Frame`+`Shine` `ImageLabel` child structure, and never reads `UIStroke` at all — it runs
in an infinite loop regardless of hover state. The button actually named **"Stroke Scale On Hover"**
is the one that does what "stroke hover effect" describes: on `MouseEnter` it tweens `UIStroke.Thickness`
up by 2, reverting on `MouseLeave`. **This document uses "Stroke Scale On Hover" everywhere the request
said "stroke hover button effect"** (weapon cards and the Equip button) — if you specifically wanted
the shine-sweep instead, say so, but as named it wouldn't do what "hover" implies.

**Architectural decision on the FOV+Blur effect:** the demo's `Fov_BTN` script does three things at
once — scales a `Frame` in from `(0,0,0,0)`, tweens camera `FieldOfView`, and tweens a `BlurEffect`.
The Weaponry Shop and Player Card **already have their own working open/close presentations** (the
shop tweens its own `Size`; the card just clones/destroys instantly) — replacing either with the
demo's zero-to-full frame popup would fight the shop's existing tween and be a bigger, unrequested
change to the player card. So this document extracts **only the FOV + Blur portion** into a small
shared module and layers it on top of each menu's existing open/close, leaving both presentations
otherwise untouched. It also does **not** tween `Workspace.CurrentCamera.FieldOfView` directly, the
way the demo script does — this game already has `CameraAuthority.FieldOfView`, a conflict-arbitration
system built exactly to stop independent systems (ADS zoom, sprint, crouch, and now this) from
fighting over the same camera property. Writing straight to the camera here would let opening the
shop silently clobber an active ADS zoom, or vice versa. Route through it instead.

---

## Part 1 — FOV + Blur when the Weaponry Shop or Player Card opens

### New shared module — `ReplicatedStorage.Modules.MenuFovBlur`

```lua
-- Field-of-view + screen blur for menu-style UI (Weaponry Shop, Player Card). Routes FOV through
-- CameraAuthority as a new "Menu" source rather than writing Workspace.CurrentCamera.FieldOfView
-- directly, so this can never silently fight ADS zoom / sprint / crouch for the camera. The blur is
-- a single persistent BlurEffect (created once, not per-open) since nothing else in this game uses
-- Lighting blur yet -- no arbitration needed there, just don't leak a fresh one on every open.
--
-- Reference-counted: open()/close() may be called from more than one menu independently (nothing
-- stops a player from having both the shop and their player card open at once), so the effect only
-- actually applies on the 0->1 transition and only actually clears on the 1->0 transition -- the
-- same idea CameraAuthority itself already uses for MinZoomDistance/MaxZoomDistance.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)

local MENU_FOV = 80
local BLUR_SIZE = 20
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local blur = Instance.new("BlurEffect")
blur.Name = "MenuBlur"
blur.Size = 0
blur.Parent = Lighting

local openCount = 0

local MenuFovBlur = {}

function MenuFovBlur.open()
	openCount += 1
	if openCount > 1 then
		return
	end
	CameraAuthority.FieldOfView:Set("Menu", MENU_FOV)
	TweenService:Create(blur, TWEEN_INFO, { Size = BLUR_SIZE }):Play()
end

function MenuFovBlur.close()
	openCount = math.max(openCount - 1, 0)
	if openCount > 0 then
		return
	end
	CameraAuthority.FieldOfView:Clear("Menu")
	TweenService:Create(blur, TWEEN_INFO, { Size = 0 }):Play()
end

return MenuFovBlur
```

### `ReplicatedStorage.Modules.CameraAuthority` — add the new source

Replace:

```lua
CameraAuthority.FieldOfView = PropertyAuthority.new(camera.FieldOfView, { "ADS", "Sprint", "Crouch" }, function(value: number)
```

with:

```lua
CameraAuthority.FieldOfView = PropertyAuthority.new(camera.FieldOfView, { "Menu", "ADS", "Sprint", "Crouch" }, function(value: number)
```

`"Menu"` sits above `"ADS"` deliberately: opening a menu is a full-screen UI context, and its FOV
should win outright over whatever the camera was mid-zoom doing, not be silently overridden by it.

Leave `CHARACTER_SCOPED_SOURCES` untouched — `"Menu"` doesn't belong there. That list exists so a
source tied to the character's own lifetime (Crouch/Sprint/ADS/ShiftLock) can't outlive a respawn; a
menu being open has nothing to do with the character, and should survive a respawn while the menu
stays open.

### `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` — wire it into the existing open/close

Add near the other `require`s:

```lua
local MenuFovBlur = require(ReplicatedStorage.Modules.MenuFovBlur)
```

In `openShop`, add one line (anywhere after `isOpen = true`):

```lua
	MenuFovBlur.open()
```

In `closeShop`, add one line (anywhere after `isOpen = false`):

```lua
	MenuFovBlur.close()
```

### `StarterPlayer.StarterPlayerScripts.PlayerCardController` — same, for both open paths

Add near the other `require`s:

```lua
local MenuFovBlur = require(ReplicatedStorage.Modules.MenuFovBlur)
```

In `openCard`, add near the top (after `closeCard()` is called, before building the card):

```lua
	MenuFovBlur.open()
```

In `closeCard`, add inside the `if currentCard then` block:

```lua
		MenuFovBlur.close()
```

### Verify

- [ ] Opening the Weaponry Shop increases FOV and blurs the screen; closing it reverses both.
- [ ] Opening your Player Card does the same; closing it reverses both.
- [ ] Opening the shop, then also opening your Player Card while the shop stays open, then closing
      just the Player Card: FOV/blur stay active (the shop is still open) — this is the reference
      count, confirm it actually holds rather than dropping early.
- [ ] Zooming in with a weapon's ADS (right-click) while a menu is open, or opening a menu while
      zoomed in, doesn't produce a visibly broken/fighting FOV — `Menu` should simply win while open.
- [ ] No `BlurEffect` duplicates accumulate in `Lighting` after repeated open/close cycles.

---

## Part 2 — Weaponry Shop trigger button: Click Bounce

**`StarterGui."Custom Inventory".weaponaryButton`** — add a `LocalScript` directly as its child
(matching the asset's own drag-and-drop pattern: the script always operates on `script.Parent`):

```lua
--// Bounce On Click, adapted from UltimateUIPack. Also scales up slightly on hover, which is part
--// of the same packaged effect, not an accidental addition.
local btn = script.Parent
local TS = game:GetService("TweenService")

local origSize = btn.Size
local origPos = btn.Position
local hoverScl = 1.1
local bounceUp = -0.02
local bounceDown = 0.02
local tInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local isClicking = false

local function makeSizeTween(scl)
	local newSize = UDim2.new(
		origSize.X.Scale * scl,
		origSize.X.Offset * scl,
		origSize.Y.Scale * scl,
		origSize.Y.Offset * scl
	)
	return TS:Create(btn, tInfo, { Size = newSize })
end

local function makePosTween(offset)
	local newPos = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale + offset, origPos.Y.Offset)
	return TS:Create(btn, tInfo, { Position = newPos })
end

btn.MouseEnter:Connect(function()
	if not isClicking then
		makeSizeTween(hoverScl):Play()
	end
end)

btn.MouseLeave:Connect(function()
	if not isClicking then
		makeSizeTween(1):Play()
	end
end)

btn.MouseButton1Click:Connect(function()
	isClicking = true
	local tweens = { makeSizeTween(1), makePosTween(bounceUp), makePosTween(bounceDown), makePosTween(0) }
	tweens[1]:Play()
	for i = 1, #tweens - 1 do
		tweens[i].Completed:Connect(function()
			tweens[i + 1]:Play()
		end)
	end
	tweens[#tweens].Completed:Connect(function()
		isClicking = false
	end)
end)
```

### Verify

- [ ] Hovering the shop button scales it up slightly; clicking it plays a quick bounce and still
      opens the shop exactly as before (this script only reads `Size`/`Position`, it doesn't touch
      `MouseButton1Click` handling elsewhere, so `WeaponaryShopController`'s own click handler is
      unaffected).

---

## Part 3 — weapon cards: stroke hover

**`ReplicatedStorage.GuiTemplates.WeaponCard`** — add a `UIStroke` child (it doesn't have one today):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local weaponCard = ReplicatedStorage.GuiTemplates.WeaponCard

if not weaponCard:FindFirstChildOfClass("UIStroke") then
	local stroke = Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.4
	stroke.Parent = weaponCard
end
```

Then add a `LocalScript` as its child (this template is cloned fresh by `buildGrid()` every time the
grid rebuilds, so every card gets its own independent copy, exactly like every other per-card visual):

```lua
--// Stroke Scale On Hover, adapted from UltimateUIPack.
local btn = script.Parent
local stroke = btn.UIStroke
local TS = game:GetService("TweenService")

local origThick = stroke.Thickness
local hoverThick = origThick + 2
local tInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function makeTween(thick)
	return TS:Create(stroke, tInfo, { Thickness = thick })
end

btn.MouseEnter:Connect(function()
	makeTween(hoverThick):Play()
end)

btn.MouseLeave:Connect(function()
	makeTween(origThick):Play()
end)
```

### Verify

- [ ] Hovering any weapon card in the shop grid grows its outline; moving off shrinks it back.
- [ ] Every card in every category tab has this behavior (it's on the template, not a specific card).
- [ ] The card's existing click-to-open-detail behavior is unaffected.

---

## Part 4 — Buy/Upgrade button: Hover & Click

**`ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.ActionButton`** — add a
`LocalScript` as its child. This template is cloned exactly once (when `WeaponaryShopController`
clones the whole shop GUI at startup), so this runs once per player session, same as the rest of the
shop:

```lua
--// Hover And Click, adapted from UltimateUIPack.
local btn = script.Parent
local TS = game:GetService("TweenService")

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

- [ ] Hovering the BUY/UPGRADE button (same button, whichever state it's in) scales it up; clicking
      it plays the shrink-then-reset click feedback, and still actually buys/upgrades exactly as
      before.
- [ ] This script only touches `Size` — confirm it doesn't visually fight `refreshDetailStats`
      setting `Text`/`BackgroundColor3` on the same button on every state change (it shouldn't; they're
      independent properties, but confirm rather than assume).

---

## Part 5 — Equip/Dequip button: stroke hover

**`ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton`** — add a `UIStroke`
(it was originally cloned from `ActionButton`, which also has none) and the same hover script as
Part 3:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local equipButton = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton

if not equipButton:FindFirstChildOfClass("UIStroke") then
	local stroke = Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.4
	stroke.Parent = equipButton
end
```

```lua
--// Stroke Scale On Hover, adapted from UltimateUIPack. Same script as the weapon card template
--// (Part 3) -- duplicated per-instance deliberately, matching how this asset pack's own effects
--// are always self-contained per object rather than shared through a module.
local btn = script.Parent
local stroke = btn.UIStroke
local TS = game:GetService("TweenService")

local origThick = stroke.Thickness
local hoverThick = origThick + 2
local tInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function makeTween(thick)
	return TS:Create(stroke, tInfo, { Thickness = thick })
end

btn.MouseEnter:Connect(function()
	makeTween(hoverThick):Play()
end)

btn.MouseLeave:Connect(function()
	makeTween(origThick):Play()
end)
```

### Verify

- [ ] Hovering the EQUIP/DEQUIP button (whichever state it's in) grows its outline the same way a
      weapon card does; clicking it still equips/dequips exactly as before.
- [ ] The button's existing color swap (blue for EQUIP, gray for DEQUIP, set by `refreshDetailStats`)
      is unaffected — the stroke is a separate visual layer from `BackgroundColor3`.

---

## Master verification checklist

- [ ] Opening the shop or the player card gives an FOV+blur transition; closing reverses it; the two
      menus don't clobber each other's effect if both happen to be open (reference-counted).
- [ ] The shop trigger button bounces on click and grows slightly on hover.
- [ ] Weapon cards in the grid show a growing stroke outline on hover.
- [ ] The Buy/Upgrade button scales on hover and gives a click-shrink bounce.
- [ ] The Equip/Dequip button shows the same growing stroke outline on hover as weapon cards.
- [ ] None of the above changed what any button actually *does* when clicked — every existing
      `MouseButton1Click` handler in `WeaponaryShopController`/`PlayerCardController` is untouched;
      these are purely additive visual layers.
- [ ] `StarterGui.UltimateUIPack` itself is left in place, untouched — it's the source material, not
      something this document deletes or modifies.

## Notes for whoever applies this

- Every fact above (the "Stroke Visible On Hover" naming mismatch, the exact Tween script contents,
  the lack of an existing `UIStroke` on `WeaponCard`/`EquipButton`, the lack of any existing
  `BlurEffect` usage) was verified live immediately before this was written.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
