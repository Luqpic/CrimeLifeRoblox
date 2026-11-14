# Prompt: Give Baton Its Own First-Person Viewmodel (Real Mesh, Not Crowbar's)

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode and
`screen_capture` verification). It is self-contained.

## Context — read this first, including a correction to what was asked

**The two world (third-person) models are already identical — verified, not assumed.** Compared
`ServerStorage.Weapons.Baton.Blaster.Body` against `ServerStorage.EnemyTemplates.Security.Baton.Blaster.Body`
directly: same `MeshId` (`11820238`), same `TextureId` (`11820143`), same `Size` (`0.3, 1, 0.3`), same
`Scale` (`1.3, 1.3, 1.3`), same `Color`/`Material`/`Reflectance`. There is nothing to swap here — both
already show the exact same real baton mesh. If the request was specifically about this world model,
it's already done and nothing needs to change.

**What's actually different, and almost certainly what's being seen as "two different meshes":**
`ServerStorage.Weapons.Baton` has **no `viewModel` attribute set at all** — confirmed live, it's
simply absent from the Tool's attribute list (every other weapon has one, e.g. `AK47`'s is
`"AK47"`). An earlier prompt document claimed it was set to `"Crowbar"`; that isn't what's actually
there. With `viewModel` unset, `ReplicatedStorage.Blaster.Scripts.ViewModelController.new` looks up
`viewModels[nil]` and calls `:Clone()` on whatever that returns — this either errors outright or
silently fails, so equipping Baton right now almost certainly shows nothing/broken in first person
for the player wielding it, while everyone else (other players looking at you, or looking at a
Security enemy) sees the correct real mesh in third person the whole time. That mismatch — your own
broken first-person view vs. the correct mesh everyone else sees — is what this document fixes. If
this isn't what you meant, say so, but the evidence points here clearly.

## The fix

Build a real `ReplicatedStorage.Blaster.ViewModels.Baton`, reusing `Crowbar`'s viewmodel rig
(Root/arms/animations — Baton has no animations of its own, same as today) but with `Body` built
from the actual baton mesh instead of Crowbar's plain colored block.

Run once:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local viewModels = ReplicatedStorage.Blaster.ViewModels
local worldBaton = ServerStorage.Weapons.Baton
local worldBody = worldBaton.Blaster.Body -- the real mesh, already proven correct in third person

local existing = viewModels:FindFirstChild("Baton")
if existing then
	existing:Destroy()
end

-- Whole rig (Root, LeftArm, RightArm, AnimationController, Animations, AnimSaves) duplicated
-- wholesale from Crowbar, same reasoning as every other viewmodel in this game: the rig and
-- animations are shared, only the visible weapon body differs.
local batonViewModel = viewModels.Crowbar:Clone()
batonViewModel.Name = "Baton"
batonViewModel.Parent = viewModels

local blaster = batonViewModel.Blaster
local oldBody = blaster.Body

-- Move the joint and attachments off the old (Crowbar-shaped) Body before replacing it, so the
-- swing trail and the hand rigging carry over unchanged onto the new Body.
local bodyJoint = oldBody:FindFirstChild("BodyJoint")
local muzzleAttachment = oldBody:FindFirstChild("MuzzleAttachment")
local trailStart = oldBody:FindFirstChild("TrailStart")
local trailEnd = oldBody:FindFirstChild("TrailEnd")
local trail = oldBody:FindFirstChild("Trail")

local newBody = Instance.new("Part")
newBody.Name = "Body"
newBody.Anchored = false
newBody.CanCollide = false
newBody.CanTouch = false
newBody.CanQuery = false
newBody.Massless = true
newBody.Material = Enum.Material.Metal
newBody.Color = worldBody.Color
newBody.Reflectance = worldBody.Reflectance
-- Same size/CFrame as the OLD (Crowbar) Body, not the world model's -- this Part sits in the rig
-- slot the Motor6D below expects; only its visual mesh comes from the world model.
newBody.Size = oldBody.Size
newBody.CFrame = oldBody.CFrame

local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.FileMesh
mesh.MeshId = worldBody.Mesh.MeshId
mesh.TextureId = worldBody.Mesh.TextureId
mesh.Scale = worldBody.Mesh.Scale
mesh.Parent = newBody

newBody.Parent = blaster

if bodyJoint then
	bodyJoint.Part1 = newBody
	bodyJoint.Parent = newBody
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

oldBody:Destroy()
blaster.PrimaryPart = newBody

worldBaton:SetAttribute("viewModel", "Baton")

print("Baton viewmodel built with the real mesh. viewModel attribute =", worldBaton:GetAttribute("viewModel"))
```

### The part that needs your eyes

Copying the old (Crowbar) `Body`'s `Size`/`CFrame` gets the new mesh into roughly the right slot, but
the real baton mesh is a different shape (a thin stick vs. Crowbar's block) at a different visual
scale (`Mesh.Scale` from the world model, `1.3x`) — the same "CFrame math alone doesn't guarantee the
visible mesh lands correctly" caveat that's applied to every other mesh-swap in this project. Enter
Play mode, equip Baton, look at first person (this is 3D world content, not the shop's 2D GUI, so
`screen_capture` has a real chance of working here — try it before falling back to asking the user to
look):

- If the baton floats away from the hand, or clips badly, adjust `newBody.CFrame` (a small offset
  along its own local axes) or `bodyJoint.C1` — prefer nudging `CFrame`/position first since `C0`/`C1`
  were correctly calibrated for the rig and shouldn't need touching unless the mesh's own pivot is
  unusually placed.
- Swing it and confirm the trail still draws from roughly the blade/tip, not floating off to the
  side — the `TrailStart`/`TrailEnd` attachments kept their old relative offsets from the swap, which
  may not line up with the new, differently-shaped mesh.

### Verify

- [ ] `ReplicatedStorage.Blaster.ViewModels.Baton` exists, with the real baton mesh (not Crowbar's
      block) on its `Body`.
- [ ] `ServerStorage.Weapons.Baton`'s `viewModel` attribute reads `"Baton"`.
- [ ] Equipping Baton in first person shows the real baton mesh, correctly positioned in the hand —
      confirmed by looking, not assumed from the CFrame copy alone.
- [ ] Swinging it still plays the swing animation and the trail effect, positioned reasonably on the
      weapon.
- [ ] Third-person view (your own character seen by another player, or a Security enemy) is
      completely unchanged — this document never touches either world model.
- [ ] Equipping Crowbar afterward is completely unaffected — its own viewmodel was cloned from, not
      modified.

## Notes for whoever applies this

- Every fact above (the identical world meshes, the missing `viewModel` attribute, the Trail/Motor6D
  structure) was verified live via `inspect_instance` immediately before this was written — including
  the correction to an earlier prompt document's incorrect claim about Baton's `viewModel` value.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
