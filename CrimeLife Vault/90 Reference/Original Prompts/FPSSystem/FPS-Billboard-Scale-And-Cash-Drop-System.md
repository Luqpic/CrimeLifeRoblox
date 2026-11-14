# Prompt: Scale Up Stat Billboard, Replace Direct Cash Reward with Tiered Drops

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

---

## Part 1 — Scale the stat billboard up 1.25x

**`StarterPlayer.StarterPlayerScripts.WeaponStatBillboard`** — in `buildBillboard()`, change:
```lua
billboard.Size = UDim2.new(4.5, 0, 3.4, 0)
```
to:
```lua
billboard.Size = UDim2.new(5.625, 0, 4.25, 0)
```
(`4.5 * 1.25` and `3.4 * 1.25`.) Nothing else about the panel changes — internal layout (`UIListLayout`, padding, stat rows) already scales proportionally with the parent's size since none of it uses fixed offsets for width. `StudsOffset` is left untouched since only the size was asked to change; revisit it separately if the larger panel ends up overlapping the gun mesh more than wanted.

### Verify
- Approach a pickup: the panel is visibly ~25% larger, text/rows still fit and aren't clipped or overlapping.

---

## Part 2 — Cash drops instead of a direct reward

Replaces the flat "+50 Cash on every kill" from the previous pass with: a 30% chance per kill to drop a physical, pickupable cash object, whose value depends on the dying enemy's weapon tier (melee < pistol < auto-rifle).

### Move the cash template out of Workspace

`Workspace.Cash` is source material to clone from, not a world object meant to sit there permanently — move it to `ServerStorage.Cash`, matching how every other clone-source template in this project lives in `ServerStorage` (`ServerStorage.Weapons`, `ServerStorage.EnemyTemplates`), not loose in `Workspace`.

Before scripting against it, check and fix two things on the template itself:
1. **`PrimaryPart`** — set it to whichever of `"Smooth Block Model"` / `"Part"` is the main visual body (inspect both, pick the one that makes sense as the anchor point for a `ProximityPrompt` and for positioning).
2. **A `WeldConstraint` between the two parts** — if one doesn't already exist, add it (Part1 = the non-primary part, Part0 = `PrimaryPart`). Without this, unanchoring two independent parts on drop will let them tumble apart from each other instead of falling as one cohesive object.

### `ServerScriptService.Weapons.Scripts.CashService` — replace the direct reward with a tiered drop

Remove the old flat-reward block (`local leaderstats = shooter:FindFirstChild("leaderstats") ... cash.Value += CASH_PER_KILL`) and the now-unused `CASH_PER_KILL` constant. Add:

```lua
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)

local cashTemplate = ServerStorage:WaitForChild("Cash")

-- Placeholders, not balance: tune freely.
local DROP_CHANCE = 0.3
local DESPAWN_TIME = 10
local IMPLODE_TIME = 0.4
local CASH_VALUES = {
	Melee = 20,
	Pistol = 35,
	AutoRifle = 50,
}
local PROMPT_MAX_DISTANCE = 8

-- Determines the dying enemy's difficulty tier from the weapon it was actually holding, reusing
-- the same attributes that already distinguish weapon behavior everywhere else in this codebase
-- (infiniteAmmo for melee, fireMode for the rest) rather than hardcoding a list of enemy template
-- names -- a future 7th enemy type is correctly tiered with zero changes here.
local function getEnemyTier(character: Model): string
	local weapon = character:FindFirstChildOfClass("Tool")
	if not weapon then
		return "Pistol" -- reasonable middle-tier fallback if somehow unarmed
	end
	if weapon:GetAttribute(BlasterConstants.INFINITE_AMMO_ATTRIBUTE) then
		return "Melee"
	end
	if weapon:GetAttribute(BlasterConstants.FIRE_MODE_ATTRIBUTE) == BlasterConstants.FIRE_MODE.AUTO then
		return "AutoRifle"
	end
	return "Pistol"
end

-- Shrinks every part to near-zero and fades to full transparency, then destroys -- shared by both
-- "player collected it" and "it despawned", so both look identical, matching the request that
-- both cases tween out the same way.
local function implode(cashModel: Model)
	local tweenInfo = TweenInfo.new(IMPLODE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in cashModel:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, tweenInfo, {
				Size = Vector3.new(0.05, 0.05, 0.05),
				Transparency = 1,
			}):Play()
		end
	end
	Debris:AddItem(cashModel, IMPLODE_TIME)
end

local function spawnCashDrop(position: Vector3, value: number)
	local cashModel = cashTemplate:Clone()
	cashModel:PivotTo(CFrame.new(position))

	for _, part in cashModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.ObjectText = `${value}`
	prompt.ActionText = "Take"
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.Parent = cashModel.PrimaryPart

	local collected = false
	prompt.Triggered:Connect(function(player: Player)
		if collected then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if not cash then
			return
		end
		collected = true
		cash.Value += value
		implode(cashModel)
	end)

	task.delay(DESPAWN_TIME, function()
		if collected or not cashModel.Parent then
			return
		end
		collected = true -- also blocks a last-instant pickup racing the despawn
		implode(cashModel)
	end)

	cashModel.Parent = workspace
end
```

In the existing `eliminatedEvent.Event:Connect(...)` handler, after the existing shooter/enemy-tag checks, replace the removed reward block with:
```lua
	if math.random() > DROP_CHANCE then
		return
	end

	local character = humanoid.Parent :: Model
	local upperTorso = character:FindFirstChild("UpperTorso")
	local dropPosition = (upperTorso and (upperTorso :: BasePart).Position) or character:GetPivot().Position

	spawnCashDrop(dropPosition, CASH_VALUES[getEnemyTier(character)])
```

### Verify
- Kill enemies of each tier repeatedly: roughly 30% of kills produce a visible cash object falling from around chest height, settling under gravity (confirm it doesn't fall apart into two separately-tumbling parts — this is exactly what the `PrimaryPart`/`WeldConstraint` fix above prevents).
- `ObjectText` on the prompt shows `$<value>` with `Take` as the action, `HoldDuration` is instant (no hold needed).
- Melee-tier drops are worth less than pistol-tier, which are worth less than auto-rifle-tier — confirm across all 6 enemy types, not just one per tier.
- Taking a drop increases the player's Cash by exactly its value and the object shrinks/fades out over ~0.4s rather than vanishing instantly.
- Leaving a drop untouched for 10 seconds makes it shrink/fade out the same way, then it's gone.
- No leftover invisible/zero-size parts lingering in `Workspace` after either case.

## Verification checklist

- [ ] Billboard is 1.25x larger, nothing clipped.
- [ ] `Cash` template relocated to `ServerStorage`, `PrimaryPart` set, parts welded together.
- [ ] Enemy kills no longer grant Cash directly; ~30% instead drop a tiered, pickupable object.
- [ ] Tier value ordering (melee < pistol < auto-rifle) holds across all 6 enemy types.
- [ ] Both collection and despawn end with the same implode tween, no instant disappearance either way.
