# Prompt: Fix Three Shop GUI Overflow Bugs (Baton 3D View, Weapon Grid, Upgrade/Equip Buttons)

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

Three unrelated overflow bugs, each root-caused live against the actual instances, not guessed from
the screenshots alone.

---

## Bug 1 — Baton's shop 3D preview is wrong orientation and oversized

### Root cause, confirmed live

`ServerStorage.Weapons.Baton.Blaster.Body` is a plain `Part` with a `SpecialMesh` child (`MeshId`
`11820238`, `Scale` `1.3, 1.3, 1.3`) — **every other weapon in this game uses a `MeshPart` directly**,
not a `Part`+`SpecialMesh` combo. That distinction matters here specifically: `Model:GetBoundingBox()`
— which `WeaponaryShopController.showDetail` uses to both derive each weapon's display orientation
(longest/middle/thinnest axis) and to compute the camera framing distance — measures a `MeshPart`'s
true rendered footprint correctly, but for a plain `Part`, the reported extents come from the `Part`'s
own `Size` (`0.3, 1, 0.3` here), which has no required relationship to what a `SpecialMesh` actually
renders at `Scale 1.3`. The derivation is working against the wrong numbers for this one weapon,
which is why it's the one weapon (out of 28) showing this problem: wrong axis picked (reads
horizontal instead of vertical) and the camera framed far closer than the real mesh needs (reads
oversized/cropped).

This is not a bug in the shop's orientation system itself — don't touch
`WeaponaryShopController.showDetail`. It's that Baton was never actually built the way every other
weapon is.

### Fix — convert Baton's world-model Body to a real MeshPart

Run once (Command Bar, or a temporary `Script` deleted afterward):

```lua
local ServerStorage = game:GetService("ServerStorage")

local worldBaton = ServerStorage.Weapons.Baton
local blaster = worldBaton.Blaster
local oldBody = blaster.Body

local mesh = oldBody:FindFirstChildOfClass("SpecialMesh")
assert(mesh, "Baton.Blaster.Body has no SpecialMesh -- stop and re-check before continuing")

local weldConstraint = oldBody:FindFirstChild("WeldConstraint")
local muzzleAttachment = oldBody:FindFirstChild("MuzzleAttachment")
local trailStart = oldBody:FindFirstChild("TrailStart")
local trailEnd = oldBody:FindFirstChild("TrailEnd")
local trail = oldBody:FindFirstChild("Trail")

local newBody = Instance.new("MeshPart")
newBody.Name = "Body"
newBody.MeshId = mesh.MeshId
newBody.TextureID = mesh.TextureId -- MeshPart's property is capitalized "TextureID", unlike SpecialMesh's
newBody.Color = oldBody.Color
newBody.Material = oldBody.Material
newBody.Reflectance = oldBody.Reflectance
newBody.Anchored = oldBody.Anchored
newBody.CanCollide = oldBody.CanCollide
newBody.CanTouch = oldBody.CanTouch
newBody.CanQuery = oldBody.CanQuery
newBody.Massless = oldBody.Massless
newBody.CastShadow = oldBody.CastShadow
newBody.CFrame = oldBody.CFrame
newBody.Parent = blaster

-- A fresh MeshPart auto-sizes to the mesh asset's native dimensions once MeshId is set and it's
-- parented into the DataModel (may need a frame to stream in). Unlike a Part+SpecialMesh combo,
-- MeshPart.Size DOES directly control the rendered scale, so multiplying the auto-computed native
-- size by the old SpecialMesh.Scale factor preserves the same visual scale that was authored.
task.wait()
local nativeSize = newBody.Size
newBody.Size = Vector3.new(nativeSize.X * mesh.Scale.X, nativeSize.Y * mesh.Scale.Y, nativeSize.Z * mesh.Scale.Z)

if weldConstraint then
	if weldConstraint.Part0 == oldBody then
		weldConstraint.Part0 = newBody
	end
	if weldConstraint.Part1 == oldBody then
		weldConstraint.Part1 = newBody
	end
	weldConstraint.Parent = newBody
end
if muzzleAttachment then
	muzzleAttachment.Parent = newBody
end
if trailStart then
	trailStart.Parent = newBody
end
if trailEnd then
	trailEnd.Parent = newBody
end
if trail then
	trail.Parent = newBody
end

blaster.PrimaryPart = newBody
oldBody:Destroy()

print("Baton world-model Body converted to MeshPart. New Size:", newBody.Size)
```

This only touches the **world model** (`ServerStorage.Weapons.Baton`), which is what the shop's 3D
preview clones (`WeaponShopService`'s catalog builder clones `template.Blaster` directly) and what
other players/enemies see in third person. It does not touch
`ReplicatedStorage.Blaster.ViewModels.Baton` (the first-person view) — that wasn't reported broken,
and it's positioned via a `Motor6D` rather than `GetBoundingBox()`, so it isn't subject to this
specific bug. Leave it alone; don't expand scope to "fix it too" without it actually needing it.

### Verify

- [ ] `ServerStorage.Weapons.Baton.Blaster.Body` is now a `MeshPart`, not a `Part`+`SpecialMesh`.
- [ ] The shop's 3D preview for Baton now shows it correctly oriented (vertical, matching how it
      should read) and correctly scaled (fully visible within the viewport box, not cropped or
      oversized) — confirmed by actually opening the shop and looking, not assumed from the code.
- [ ] Third-person: Baton still renders correctly on a character (unchanged visual, just a different
      underlying Instance type) — equip it and look, don't just trust the conversion.
- [ ] The swing `Trail` still draws from the correct position (it moved to the new `Body` unchanged).
- [ ] No other weapon's shop preview regressed.

---

## Bug 2 — the weapon grid renders past the shop panel's rounded corners

### Root cause, confirmed live

`ReplicatedStorage.GuiTemplates.WeaponaryShop` (the shop's root `Frame`, the one with the rounded
`UICorner` giving the panel its rounded-corner look) has **`ClipsDescendants = false`**. A `UICorner`
is purely cosmetic — it does not clip content to the rounded shape by itself. `WeaponGrid` itself
already has `ClipsDescendants = true` (correct), but that only clips WeaponGrid's own children to
WeaponGrid's own rectangle; it does nothing to stop that rectangle's contents from being visible past
the *root panel's* rounded visual edge if a frame's actual rendered container isn't itself clipped
there. With the root not clipping, content can show through to whatever's behind the panel (the
blurred 3D background) right at the edges instead of being cleanly contained by the panel's own shape.

### Fix

**`ReplicatedStorage.GuiTemplates.WeaponaryShop`** — set `ClipsDescendants = true` on the root Frame.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
ReplicatedStorage.GuiTemplates.WeaponaryShop.ClipsDescendants = true
```

This is the minimal fix — clipping cascades from whichever ancestor clips to everything rendering
outside its bounds, so setting it on the root alone contains everything inside it (`ShopArea`,
`WeaponGrid`, `DetailPanel`, all of it), without needing to also flip it on every intermediate Frame.

### Verify

- [ ] Scroll the weapon grid all the way to the bottom (or open a category with enough entries to
      need a partial final row) — the partial row is cleanly cut off at the panel's own rounded edge,
      with no blurred background visible bleeding through where content used to overflow.
- [ ] The shop's rounded corners still look correct (background, tabs, everything else) — this
      change only affects what's allowed to render outside the panel, not the panel's own appearance.
- [ ] Nothing that's *supposed* to render outside the panel (if anything ever relied on that) broke —
      there shouldn't be anything, but confirm the shop still opens/closes and every button still
      works after this change.

---

## Bug 3 — the Upgrade button overlaps the Equip button on hover

### Root cause, confirmed live — a regression from the last effects-integration pass

`ActionButton`'s `HoverAndClick` script (added when the UltimateUIPack effects were wired up) scales
the button to `1.1x` on hover. At its base `Size` of `180x60`, hovering grows it to `198x66`. Since
`ActionButton` is anchored top-left at `Position (0, 290)`, that growth extends its right edge from
`x=180` out to `x=198` — but `EquipButton` sits right next to it at `x=190`, only a 10px gap from
`ActionButton`'s *base* width. The hover-grown width (18px of growth) overruns that 10px gap by 8px,
so hovering Upgrade/Buy visibly overlaps Equip/Dequip. This is a direct side effect of the hover
effect added on top of a layout that was never given room for it — the hover effect itself is working
as designed, the gap between the two buttons just isn't wide enough to contain it.

### Fix — give the buttons enough clearance for the hover growth

**`ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton`** — move it right by
20px, from `x=190` to `x=210` (12px of clearance beyond `ActionButton`'s max hover-grown edge at
`x=198`, comfortably inside the available panel width):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local equipButton = ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.EquipButton
equipButton.Position = UDim2.fromOffset(210, 290)
```

`EquipButton`'s own hover effect (`StrokeHover`, from Part 3/5 of the effects-integration document)
only grows a `UIStroke`'s thickness by a couple of pixels — it doesn't resize the button itself, so it
carries no equivalent overlap risk in the other direction.

### Verify

- [ ] Hover the Upgrade/Buy button with the cursor: it grows as designed, and no longer visually
      overlaps the Equip/Dequip button at any point during the hover-grow animation.
- [ ] Both buttons are still comfortably positioned within the detail panel at the new gap — neither
      one is pushed off the panel's right edge.
- [ ] Both buttons' click actions (buy/upgrade, equip/dequip) still work exactly as before — this is
      a `Position` change only.

---

## Master verification checklist

- [ ] Baton's shop preview is correctly oriented and scaled; every other weapon's preview is
      unchanged.
- [ ] The weapon grid no longer shows content bleeding past the shop panel's rounded corners at any
      scroll position.
- [ ] Hovering Upgrade/Buy never overlaps the Equip/Dequip button.
- [ ] Nothing else about the shop (opening/closing, FOV+blur, the other button effects, buying,
      upgrading, equipping) regressed.

## Notes for whoever applies this

- Every fact above (`Baton.Blaster.Body`'s actual class, `WeaponaryShop`'s `ClipsDescendants` value,
  the exact `HoverAndClick` scale factor and both buttons' exact positions/sizes) was verified live
  immediately before this was written.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
