# Prompt: Fix Enemy Search-State Behavior — Stop Spinning, Stop Chasing a Dead Target

Paste this whole document to Claude Code (with Roblox Studio MCP access, targeting the `FPS System.rbxl` place). It is self-contained.

**Bug reports (two, same root area):**
1. After a player dies, the enemy that killed them walks to the corpse and visibly spins/rotates in place continuously, instead of a one-time "look around."
2. Separately: enemies shouldn't chase/path toward a target at all once it has died — running at and lingering near a dead body reads as unrealistic. Losing track of a still-*living* target (it fled out of detection range) should keep working as it does today — only the "target died" case needs to change.

Both live in `ServerScriptService.Enemy.Scripts.EnemyAI`'s Chase/Attack/Search state handling, so both fixes are given together here.

---

## Part 1 — Stop the continuous spin at the arrival point

**Root cause:** when a target is lost, the enemy enters `STATE.Search` and paths toward `lastKnownPosition`. Once within 6 studs of it, `_thinkSearch` runs:

```lua
local offset = lastKnown - self.rootPart.Position
if Vector3.new(offset.X, 0, offset.Z).Magnitude < 6 then
	-- Arrived at the last known position: look around rather than immediately giving up.
	self:_stopMoving()
	self.rootPart.CFrame = self.rootPart.CFrame * CFrame.Angles(0, math.rad(50), 0)
else
	self:_followPath(lastKnown, self.config.chaseSpeed, now)
end
```

The comment's intent is a single "look around" gesture. But `_thinkSearch` re-runs on every `THINK_INTERVAL` (0.25s), and nothing stops this branch from re-firing every tick as long as the enemy stays within that 6-stud radius — which it will, since a stationary point (or a corpse) doesn't move away. Each tick multiplies in *another* 50° turn: over the full `SEARCH_DURATION` (5s) that's ~20 ticks × 50° ≈ 1000° of rotation, which reads as continuous spinning.

For comparison, `_thinkPatrol`'s arrival-and-dwell logic gets this right: it clears `pathDestination` on arrival so the "I've arrived" branch can't re-trigger on the next tick. `_thinkSearch` has no equivalent one-shot guard — that's the actual defect.

**Interpretation call:** this fix preserves the existing single 50° turn amount, `SEARCH_DURATION`, and detection/re-acquisition behavior exactly — it only stops the turn from repeating.

### `EnemyAI.new` — add a new field to the `self` table

Add `hasLookedAround = false,` alongside the other Search-related state fields (near `searchUntil`):
```lua
		patrolDwellUntil = 0,
		searchUntil = 0,
		hasLookedAround = false,
		fireGeneration = 0,
```

### `EnemyAI:_setState` — reset the flag on every fresh entry into Search

Change:
```lua
	elseif newState == STATE.Search then
		self.searchUntil = os.clock() + Constants.SEARCH_DURATION
```
to:
```lua
	elseif newState == STATE.Search then
		self.searchUntil = os.clock() + Constants.SEARCH_DURATION
		self.hasLookedAround = false
```
(This only runs on an actual state *transition* into Search — `_setState` early-returns if already in that state — so the flag correctly stays `true` for the rest of that Search session once the enemy has turned, and is only reset the next time it freshly enters Search again later.)

### `EnemyAI:_thinkSearch` — gate the rotation

Change:
```lua
	local offset = lastKnown - self.rootPart.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 6 then
		-- Arrived at the last known position: look around rather than immediately giving up.
		self:_stopMoving()
		self.rootPart.CFrame = self.rootPart.CFrame * CFrame.Angles(0, math.rad(50), 0)
	else
		self:_followPath(lastKnown, self.config.chaseSpeed, now)
	end
```
to:
```lua
	local offset = lastKnown - self.rootPart.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude < 6 then
		-- Arrived at the last known position: look around ONCE rather than immediately giving up.
		-- Gated by hasLookedAround so this fires exactly one time per Search-state entry -- left
		-- unconditional, it re-added another 50 degrees every THINK_INTERVAL for the whole
		-- SEARCH_DURATION (~20 ticks), which read as the enemy continuously spinning in place next
		-- to wherever it lost its target (most visibly: standing over a player's corpse).
		self:_stopMoving()
		if not self.hasLookedAround then
			self.hasLookedAround = true
			self.rootPart.CFrame = self.rootPart.CFrame * CFrame.Angles(0, math.rad(50), 0)
		end
	else
		self:_followPath(lastKnown, self.config.chaseSpeed, now)
	end
```

---

## Part 2 — Stop chasing/searching for a target that has already died

**Root cause:** `_thinkChase` and `_thinkAttack` both treat "lost my target" as a single case — `_targetHumanoid()` returns `nil` both when the target's humanoid has died (`Health <= 0`) and when the target is simply unreachable (player disconnected, character not loaded). Either way, today's code drops into `STATE.Search` and paths toward `lastKnownPosition` — exactly the corpse's location when the reason was death. That's what makes an enemy visibly run at and linger near a dead body. Losing a target that merely fled while still alive is the *other* case Search already exists for, and must keep working exactly as it does today.

The fix distinguishes the two cases with one small helper, and skips straight to `Patrol` — no Search, no pathing toward the corpse at all — only when the target is confirmed dead.

### `EnemyAI` — add a helper right after `_targetHumanoid`

```lua
-- True only if we still have a target AND its humanoid exists but has died (Health <= 0) -- as
-- opposed to simply being unreachable (player disconnected, character not loaded). This is what
-- lets Chase/Attack tell "the target died" (give up immediately, ignore the corpse entirely)
-- apart from "lost track of a still-living target" (searching its last known position is
-- correct and unchanged).
function EnemyAI:_isTargetDead(): boolean
	local player = self.target
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health <= 0
end
```

### `EnemyAI:_thinkChase` — give up immediately on death

Change:
```lua
	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		self:_setState(STATE.Search)
		return
	end
```
to:
```lua
	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		-- Dead means ignore it entirely and return to Patrol -- searching a corpse's last known
		-- position is exactly the "runs at the dead body" behavior being fixed here. Anything else
		-- (player disconnected, character not yet loaded) keeps the existing Search behavior.
		self:_setState(if self:_isTargetDead() then STATE.Patrol else STATE.Search)
		return
	end
```

### `EnemyAI:_thinkAttack` — same change

Change:
```lua
	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		self:_setState(STATE.Search)
		return
	end
```
to:
```lua
	local targetHumanoid = self:_targetHumanoid()
	if not targetHumanoid then
		self:_setState(if self:_isTargetDead() then STATE.Patrol else STATE.Search)
		return
	end
```

`if...then...else` as an expression is already used elsewhere in this codebase (e.g. `ShotResolver`'s `damagePerRay`), so this matches existing style. Nothing else changes — `_setState(STATE.Patrol)` already does the correct full disengage (clears the target, `lastKnownPosition`, and any in-progress path), and the enemy resumes wandering around its own spawn point exactly as it does after any other Patrol re-entry.

---

## Verification checklist

- [ ] Get killed while an enemy is in Attack range: it stops advancing on your corpse immediately and returns to patrolling around its own spawn point, rather than walking up to the body first.
- [ ] Get killed while an enemy is still in Chase (not yet in Attack range): confirm it does not close the remaining distance to your now-dead body either.
- [ ] Fled-while-alive case (must be unaffected): let an enemy chase you, then break line of sight and run far enough to exceed its `DetectionRadius` while still alive — confirm it still paths to your last known position and does the Part 1 one-time look-around turn (no spin), exactly as before.
- [ ] While an enemy is searching for a still-living lost target, let it re-spot you — confirm it re-enters Chase normally.
- [ ] Confirm retaliation (`onDamagedBy`) and normal target acquisition (`_findVisibleTarget`) are unaffected — both already skip dead humanoids when picking a target, and continue to do so.
- [ ] Confirm ordinary Patrol/Chase/Attack facing and path-following behavior otherwise looks unchanged — these fixes only touch the "target lost" branches of `_thinkChase`/`_thinkAttack` and the Search-state arrival branch.
