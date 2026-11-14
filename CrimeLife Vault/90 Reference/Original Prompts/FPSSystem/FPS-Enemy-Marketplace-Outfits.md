# Prompt: Dress the 6 Enemy Templates Using Scouted Marketplace Accessories + BodyColors

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**Confirmed live, immediately before writing this:** all 6 rigs under `ServerStorage.EnemyTemplates`
(`Thug`, `Criminal`, `Armed Criminal`, `Security`, `Police`, `Armed Police`) are standard R15 models,
19 children each (`Humanoid`, `Body Colors`, one pre-equipped weapon `Tool`, `HumanoidRootPart`, and the
15 R15 limb `MeshPart`s). **None of the 6 currently has any `Accessory`, `Shirt`, or `Pants` instance —
this is a pure addition, not a replace.** Every limb `MeshPart` carries its own `WrapTarget` component
(confirmed on all 15 limbs, all 6 rigs), which is exactly what makes a rig compatible with modern
**Layered Clothing** accessories (3D-mesh clothing that wraps the body, via a matching `WrapLayer` on
the accessory) — so the volumetric-looking hoodie/vest/cap pieces in the reference mockup are achievable
with real clothing, not just flat texture-wrap `Shirt`/`Pants`.

**Why plain pants/shirts are done with `BodyColors`, not a marketplace search:** every rig already
has a `Body Colors` (`BodyColors`) instance, currently unset/default. Generic-color searches
("gray cargo pants," "navy police pants," "white shirt necktie," "black long sleeve shirt") returned
almost nothing but spam/junk on this marketplace — asset search quality for plain solid-color base
clothing is poor. Recoloring `BodyColors` is instant, has zero risk of inserting a broken/mismatched
mesh, and reuses a mechanism the rig already has. It's used below for every plain base layer (pants on
all 6, base shirt color under a vest, Security's plain white shirt). Only the *distinctive* garments
(hoodie, safety vest, tactical vest, balaclava, cap, police shirt, duty belt) are real marketplace
accessories.

**These asset picks are text-matched only, not visually verified — a required live-verification step,
not a guess dressed up as certainty.** `search_asset` returns names/descriptions/thumbnail *URLs*, not
renderable images — every asset ID below was chosen by matching search-result text to the mockup's
description, never by actually seeing it. Every category below lists a **primary** and at least one
**fallback** asset ID for exactly this reason. After inserting the primary, actually look at it in
Studio before wiring it onto all 6 rigs — if it's broken, empty, or clearly the wrong item, move to the
fallback rather than forcing the primary through.

**Three explicit decisions made with the user before this was written (not silently assumed):**
- **Armed Police gets no helmet.** Marketplace search for a tactical helmet+goggles returned only weak
  matches (one literally described as "Just a Mesh" — i.e. not confirmed to be a wearable `Accessory`
  at all). Decided: skip it. Armed Police is visually distinguished from Armed Criminal by vest choice
  and identical head/face treatment (balaclava) is intentional, not an oversight.
- **Security's white-shirt-and-tie becomes a white torso recolor with no physical tie.** No tie
  accessory exists in the free-tier search results. The tie detail is dropped; the white shirt color
  is kept via `BodyColors`.
- **Criminal's safety vest is the closest real match, "Yellow Safety Vest," not literally orange.**
  Orange-specific searches returned only spam. Yellow was accepted as close enough for a hi-vis vest
  silhouette.

**Also decided, lower-stakes:** sneakers/footwear (Thug) and a flashlight accessory (Security) were in
the original mockup but have no meaningful free marketplace presence worth chasing — both are skipped
as optional polish, not treated as missing requirements.

**Templates, not spawned instances:** every `EnemyTemplate` is the clone source `EnemySpawner` copies
on every spawn (confirmed: `character.Name = "Enemy"` is set unconditionally after cloning). Editing
these 6 template `Model`s once is sufficient — no `EnemySpawner` code changes needed, and no existing
enemy-in-progress needs touching (session has no persistence; a server restart is the natural point
these take effect).

**Not touched by this document:** each rig's pre-equipped weapon `Tool` (`Crowbar`, `AKM`, `Baton`,
`Mateba 2006M`, `Scar L`) is unchanged. The mockup calls Armed Police's weapon an "SMG" while the rig
actually carries `Scar L` (a rifle) — that's a pre-existing naming/identity mismatch in the weapon
system, out of scope here; this document only adds clothing/accessories.

---

## Part 0 — shared staging setup and helper functions

Run once, in `Command Bar` or a temporary `Script`, in `Edit` mode (this only inserts and rearranges
instances — no gameplay code is added, so nothing needs to run at runtime):

```lua
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local staging = ServerStorage:FindFirstChild("EnemyOutfitStaging")
if staging then
	staging:Destroy() -- idempotent re-run
end
staging = Instance.new("Folder")
staging.Name = "EnemyOutfitStaging"
staging.Parent = ServerStorage

-- Inserts one asset by id, finds the actual wearable instance inside it (an Accessory, Shirt, or
-- Pants can arrive wrapped in a container Model depending on how the asset was authored), and
-- returns that instance still parented under `staging` (NOT yet cloned onto any rig).
local function insertAsset(assetId, friendlyName)
	local ok, result = pcall(function()
		return game:GetObjects("rbxassetid://" .. assetId)
	end)
	if not ok or not result or not result[1] then
		warn(`Failed to insert asset {assetId} ("{friendlyName}") — try the fallback id for this slot.`)
		return nil
	end

	local root = result[1]
	root.Parent = staging

	if root:IsA("Accessory") or root:IsA("Shirt") or root:IsA("Pants") then
		return root
	end

	-- Wrapped in a container Model: search its descendants for the real wearable instance.
	local found = root:FindFirstChildWhichIsA("Accessory", true)
		or root:FindFirstChildWhichIsA("Shirt", true)
		or root:FindFirstChildWhichIsA("Pants", true)
	if not found then
		warn(`Asset {assetId} ("{friendlyName}") inserted but contains no Accessory/Shirt/Pants — inspect it manually, likely the wrong asset. Try the fallback id.`)
		return nil
	end
	return found
end

-- Clones `wearable` onto `template` (an EnemyTemplates.* Model). Accessories go through
-- Humanoid:AddAccessory (correctly resolves the WrapLayer/WrapTarget pairing already confirmed
-- present on every limb of every rig); Shirt/Pants are classic clothing and just parent directly
-- into the character model.
local function wear(template, wearable)
	if not wearable then
		return
	end
	local clone = wearable:Clone()
	if clone:IsA("Accessory") then
		local humanoid = template:FindFirstChildOfClass("Humanoid")
		humanoid:AddAccessory(clone)
	else
		clone.Parent = template
	end
end

-- BodyColors' *Color3 properties are actually typed BrickColor (a longstanding Roblox API quirk,
-- not a typo) — BrickColor.new(Color3) snaps to the nearest official BrickColor, which sidesteps
-- ever needing to get an exact BrickColor name string right.
local function setBodyColors(template, torsoRGB, armRGB, legRGB)
	local bodyColors = template:FindFirstChildOfClass("BodyColors")
	local torso = BrickColor.new(Color3.fromRGB(unpack(torsoRGB)))
	local arm = BrickColor.new(Color3.fromRGB(unpack(armRGB)))
	local leg = BrickColor.new(Color3.fromRGB(unpack(legRGB)))
	bodyColors.TorsoColor3 = torso
	bodyColors.LeftArmColor3 = arm
	bodyColors.RightArmColor3 = arm
	bodyColors.LeftLegColor3 = leg
	bodyColors.RightLegColor3 = leg
end

print("Staging ready. Proceed to Parts 1-6.")
```

### Verify

- [ ] `ServerStorage.EnemyOutfitStaging` exists and is empty (nothing inserted into it yet).

---

## Part 1 — Thug: beanie + white hoodie + dark pants

```lua
local thug = game.ServerStorage.EnemyTemplates.Thug

local beanie = insertAsset("9122081504", "Beanie hat (for models)") -- fallback: "140040881826136" ("Beenie")
local hoodie = insertAsset("5181450906", "White Hoodie") -- fallback: "5217877806" (also "White Hoodie")

setBodyColors(thug, {255, 255, 255}, {255, 255, 255}, {40, 40, 40}) -- white torso/arms under hoodie, dark pants
wear(thug, beanie)
wear(thug, hoodie)
```

**Beanie is the weakest-confidence pick in this whole document** — the free marketplace has almost no
plain, non-novelty beanie. Actually look at it after inserting: if it's a joke item (propeller, oversized,
clearly broken), it's fine to leave Thug bare-headed rather than force a bad beanie on — a missing hat is
much less noticeable than a silly one.

Sneakers/footwear: intentionally skipped (see Context) — no change needed for this.

### Verify

- [ ] `Thug` has a hoodie accessory that visibly reads as a hoodie, not a floating/misplaced mesh.
- [ ] `Thug`'s legs render dark, torso/arms render white wherever the hoodie doesn't cover them.
- [ ] The pre-equipped `Crowbar` tool is untouched.

---

## Part 2 — Criminal: beanie + yellow safety vest + gray base layer

```lua
local criminal = game.ServerStorage.EnemyTemplates.Criminal

local vest = insertAsset("3681694043", "Yellow Safety Vest") -- fallback: "11467968697" ("Vest V2") or "4581740172" ("Reflective Neon Vest")
-- Reuse the SAME beanie clone already sitting in staging from Part 1 rather than re-inserting.
local criminalBeanie = staging:FindFirstChildOfClass("Accessory")

setBodyColors(criminal, {150, 150, 150}, {150, 150, 150}, {150, 150, 150}) -- gray shirt+pants under the vest
wear(criminal, criminalBeanie)
wear(criminal, vest)
```

If Part 1's beanie was skipped (bad mesh), skip this reuse too — don't insert a second beanie candidate
just for Criminal; a bare head on both is a consistent, acceptable fallback.

### Verify

- [ ] `Criminal` has a visible safety-vest accessory (yellow, not orange — accepted per the decision in
      Context) over gray base clothing.
- [ ] The pre-equipped `M1911` tool is untouched — the reference mockup describes Criminal's weapon as
      a crowbar, but the live rig actually carries `M1911`; that's a pre-existing mismatch (like the
      Armed Police/SMG one noted in Context) and is out of scope for this clothing-only document.

---

## Part 3 — Armed Criminal: balaclava + tactical vest + black base layer

```lua
local armedCriminal = game.ServerStorage.EnemyTemplates["Armed Criminal"]

local balaclava = insertAsset("125114877226923", "Balaclava Black Ski Mask Tactical [ACS] Hood") -- fallback: "119010076986009"
local vestAC = insertAsset("139669271569268", "Tactical Body Armor Military Vest Plate Carrier") -- fallback: "102587778093912" ("Plate Carrier Vest Tactical RP Gear")

setBodyColors(armedCriminal, {25, 25, 25}, {25, 25, 25}, {25, 25, 25}) -- all-black base layer
wear(armedCriminal, balaclava)
wear(armedCriminal, vestAC)
```

### Verify

- [ ] `Armed Criminal` has a balaclava covering the face/head and a tactical vest over black base
      clothing.
- [ ] The pre-equipped `AKM` tool is untouched.

---

## Part 4 — Armed Police: balaclava + a *different* tactical vest + black base layer, no helmet

```lua
local armedPolice = game.ServerStorage.EnemyTemplates["Armed Police"]

-- Same balaclava as Armed Criminal (intentional — see Context on why no helmet was added instead).
local balaclavaAP = staging:FindFirstChildWhichIsA("Accessory") -- the Part 3 balaclava clone source, still in staging
local vestAP = insertAsset("103813788097803", "ACS Vest Tactical Armor Plate Carrier") -- fallback: "71696740279397" ("Tactical Plate Carrier Military Vest Armor RP")

setBodyColors(armedPolice, {25, 25, 25}, {25, 25, 25}, {25, 25, 25}) -- all-black base layer, matches Armed Criminal
wear(armedPolice, balaclavaAP)
wear(armedPolice, vestAP)
```

Deliberately a **different vest asset id from Part 3** (not the same one reused) so Armed Criminal and
Armed Police don't end up wearing the pixel-identical vest — some visual separation between the two
without a helmet to do the job. If, once actually looking at both in Studio, they read as near-identical
anyway, that's an acceptable outcome (see the helmet-skip decision in Context) rather than a bug to chase.

### Verify

- [ ] `Armed Police` has a balaclava and a tactical vest, visually distinct from Armed Criminal's vest
      (different asset, even if the difference is subtle).
- [ ] No helmet was added — confirm this was a deliberate omission, not an accidentally-skipped step.
- [ ] The pre-equipped `Scar L` tool is untouched.

---

## Part 5 — Security: guard cap + white shirt (no tie) + duty belt

```lua
local security = game.ServerStorage.EnemyTemplates.Security

local guardCapPack = insertAsset("110430482179608", "Guard Hats - Security Police Sheriff Warden Cap") -- fallback pack: "101170332654568"
local dutyBelt = insertAsset("4827498507", "Police duty belt") -- fallback: "3322951128" ("Duty Belt Police Real Life")

setBodyColors(security, {235, 235, 235}, {235, 235, 235}, {150, 150, 150}) -- white shirt, gray pants

-- This asset name claims to be a MULTI-CAP PACK (Security/Police/Sheriff/Warden variants bundled
-- together) — unverified, since I can't see its contents without inserting it. `insertAsset` above
-- only returns the FIRST Accessory/Shirt/Pants it finds inside, which may not be the Security variant
-- specifically. After inserting, inspect what actually came in:
print(guardCapPack and guardCapPack.Parent:GetChildren())
-- If the pack contains multiple named cap Accessories (e.g. "SecurityCap", "PoliceCap", ...), grab
-- the Security-appropriate one specifically instead of just using `guardCapPack` as-is:
-- local securityCap = guardCapPack.Parent:FindFirstChild("SecurityCap") or guardCapPack
wear(security, guardCapPack)
wear(security, dutyBelt)
```

### Verify

- [ ] `Security` has *some* guard-style cap and a duty belt.
- [ ] If the inserted pack turned out to contain multiple distinctly-named caps, confirm the one
      actually applied to `Security` is the security-styled one, not an arbitrary first match (a sheriff
      or warden cap looks meaningfully different and would be a silent visual mismatch worth catching).
- [ ] Torso reads white, no tie present (intentional per the decision in Context).
- [ ] The pre-equipped `Baton` tool is untouched.

---

## Part 6 — Police: guard cap (police variant) + blue police shirt + duty belt

```lua
local police = game.ServerStorage.EnemyTemplates.Police

local policeShirt = insertAsset("86216394111170", "Blue Police Shirt Officer Uniform Law Enforcement")
-- Reuse the SAME pack already inserted in Part 5 rather than inserting it a second time.
local guardCapPackPolice = staging:FindFirstChild("Guard Hats - Security Police Sheriff Warden Cap")
	or staging:FindFirstChildWhichIsA("Accessory") -- fallback lookup if the pack's container got renamed on insert
local dutyBeltPolice = staging:FindFirstChild("Police duty belt")

setBodyColors(police, {30, 60, 110}, {30, 60, 110}, {20, 40, 80}) -- navy shirt/arms, darker navy pants
-- (`policeShirt` may turn out to be a classic `Shirt` instance rather than an Accessory. A Shirt
-- overrides the BodyColors torso/arm recolor above with its own texture wherever it's rendered — that's
-- expected and fine; the navy BodyColors above exist as a fallback in case it's actually a
-- partial-coverage Accessory instead, so either way Police doesn't end up in mismatched default colors.)
wear(police, policeShirt)
-- If Part 5 identified a specifically-named Police cap variant inside the pack, use that one here
-- instead of `guardCapPackPolice` as a generic fallback:
-- local policeCap = guardCapPackPolice.Parent:FindFirstChild("PoliceCap") or guardCapPackPolice
wear(police, guardCapPackPolice)
wear(police, dutyBeltPolice)
```

### Verify

- [ ] `Police` has a blue police-styled shirt (check whether it landed as a `Shirt` or an `Accessory` —
      note which, it affects how future edits to this rig's clothing should be made) and a guard cap.
- [ ] If the cap pack had distinctly-named variants, confirm `Police` got the police-styled one, not the
      same one applied to `Security` (unless they genuinely turned out to be the same asset, in which
      case that's the pack's actual limit, not a mistake in applying it).
- [ ] Duty belt present.
- [ ] The pre-equipped `Mateba 2006M` tool is untouched.

---

## Part 7 — cleanup

Only after every part above is verified:

```lua
game.ServerStorage.EnemyOutfitStaging:Destroy()
print("EnemyOutfitStaging removed.")
```

### Verify

- [ ] `ServerStorage.EnemyOutfitStaging` no longer exists.
- [ ] Spawn one enemy of each of the 6 types in Play mode and visually confirm every accessory/color
      change actually appears on the *spawned* character, not just the template sitting in
      `ServerStorage` (this is the real proof the clone-on-spawn path picked everything up correctly).
- [ ] Spawned enemies of each type still move, detect, chase, and attack normally — accessories and
      BodyColors changes should not affect `Humanoid`, `AnimationConstraint`, or `BallSocketConstraint`
      behavior at all, but confirm rather than assume, since this is the first time these rigs have
      carried any accessories.

## Master verification checklist

- [ ] All 6 `EnemyTemplates` have visibly different, mockup-appropriate outfits — no two archetypes
      look identical except the two "no helmet" cases (Armed Criminal / Armed Police), which is an
      accepted, deliberate outcome.
- [ ] No accessory floats detached from the body or renders as an obviously broken/missing mesh on any
      of the 6. Any pick that fails this test should have been swapped for its documented fallback
      before this checklist is marked done — not left broken.
- [ ] None of the 6 pre-equipped weapon `Tool`s changed.
- [ ] `EnemyOutfitStaging` is fully cleaned up.
- [ ] Every spawned-enemy behavior (movement, detection, damage, quest-kill-tracking via
      `EnemyTemplate` attribute) is unaffected — this document only ever added cosmetic instances and
      recolored `BodyColors`, nothing that touches `Humanoid`/AI/combat scripts.

## Notes for whoever applies this

- Every asset id above was chosen by matching Creator Store search-result **text** (name + description)
  against the mockup's description — never confirmed by actually seeing a rendered thumbnail or model.
  Treat every single one as "worth trying first," not "guaranteed correct." Use the documented fallback
  the moment a primary pick turns out wrong, rather than spending time forcing it to work.
- The three explicit trade-offs (no Armed Police helmet, no Security tie, yellow-not-orange vest) were
  discussed with the user before this was written — don't try to "fix" these by hunting for better
  assets unless the user asks; they're accepted outcomes, not open problems.
- `BodyColors`' `*Color3` properties being typed `BrickColor` (not `Color3`, despite the name) is a real
  Roblox API quirk, not a mistake in this document — `BrickColor.new(Color3.fromRGB(...))` is the
  correct way to set them precisely without needing to know an exact official BrickColor name string.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
