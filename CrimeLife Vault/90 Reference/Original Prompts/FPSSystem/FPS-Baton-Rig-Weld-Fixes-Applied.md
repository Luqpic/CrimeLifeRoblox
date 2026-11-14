# Prompt (retroactive record): Baton Viewmodel Hands + Third-Person Gear Appearance Fix

## Note on process

This one was applied DIRECTLY in the same live Studio-MCP session that diagnosed it, rather than
drafted here first and pasted into a fresh session. That was a deliberate one-off: the fix was two
mechanical property edits and two cloned Motor6D instances, each backed by an exact, already-verified
`inspect_instance` diff against the known-good Crowbar rig — nothing here involved a design decision
or a guess. This document exists so the local archive stays complete even though the normal
draft-first flow was skipped. Written immediately after applying, from the same investigation, not
reconstructed after the fact.

## User report

> "There's still a problem with the Baton, the hands isn't visible in the viewmodel. Furthermore,
> the baton itself doesn't appear on the player from a gear perspective." (with a first-person
> screenshot showing a floating baton with no arms, and a third-person screenshot showing a thin
> blade-like object hanging near the character's foot instead of gripped in hand)

This came right after the previous round of fixes (tab overflow / empty-label sizing / Baton icon /
enemy stun enforcement — see `FPS-Weaponary-Tab-Overflow-EmptyLabel-BatonIcon-EnemyStun-Fixes.md`).
The icon/tab/enemy-stun fixes were correct and unrelated; this is a separate, previously
undiscovered rig-wiring bug from the same earlier Baton rebuild (the "wholesale duplicate
Crowbar + swap in the enemy Security.Baton's world mesh" attempt).

## Root causes (confirmed via `inspect_instance`, not assumed)

1. **`ServerStorage.Weapons.Baton.Blaster.Body.WeldConstraint.Part1`** was
   `ServerStorage.EnemyTemplates.Security.Baton.Handle` — the ENEMY template's own Handle, a
   completely different instance in an unrelated part of the tree. It should have been
   `ServerStorage.Weapons.Baton.Handle` (this Tool's own Handle), exactly like Crowbar's equivalent
   weld correctly points to `ServerStorage.Weapons.Crowbar.Handle`.

   Effect: the visible `Blaster.Body` mesh was never actually attached to the invisible `Handle`
   that equips into the player's hand. Being unwelded and unanchored, it just sat wherever it
   happened to be / fell under gravity — matching the screenshot of it hanging near the character's
   foot instead of being held.

2. **`ReplicatedStorage.Blaster.ViewModels.Baton.Blaster.Body.WeldConstraint`** had the identical
   bug (`Part1` also pointed at the enemy template's Handle). Crowbar's viewmodel `Body` has no
   `WeldConstraint` at all — its position is driven entirely by the Motor6D rig (see below) — so
   this was leftover cruft from the clone process, not a valid part of the design. Deleted rather
   than repointed, to match Crowbar's actual structure.

3. **`ReplicatedStorage.Blaster.ViewModels.Baton.LeftArm`** had zero children — no `LeftArmJoint`
   Motor6D — while `ViewModels.Crowbar.LeftArm` has one (`Part0 = Blaster.Body`,
   `Part1 = LeftArm`).

4. **`ReplicatedStorage.Blaster.ViewModels.Baton.RightArm`** — same gap, missing `RightArmJoint`.

   Effect (3 + 4): the viewmodel rig chain is `Root -> (BodyJoint) -> Blaster.Body -> (arm joints)
   -> LeftArm/RightArm`. With the arm joints entirely absent, nothing positioned the hand parts at
   all — they were never part of the rig, hence invisible/not rendering correctly in the first-person
   view.

## Fix applied (`execute_luau`, `datamodel_type: "Edit"`)

```lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1) World-model weld: repoint to Baton's own Handle.
local worldWeld = ServerStorage.Weapons.Baton.Blaster.Body.WeldConstraint
worldWeld.Part1 = ServerStorage.Weapons.Baton.Handle

-- 2) Viewmodel weld: delete (Crowbar's viewmodel has none; the Motor6D rig alone positions it).
ReplicatedStorage.Blaster.ViewModels.Baton.Blaster.Body.WeldConstraint:Destroy()

-- 3 + 4) Clone the missing arm joints from Crowbar's viewmodel, same C0/C1 (arm parts are
-- geometrically identical between the two viewmodels -- verified same Size and local CFrame).
local function ensureArmJoint(jointName, armName)
	local batonArm = ReplicatedStorage.Blaster.ViewModels.Baton[armName]
	if batonArm:FindFirstChild(jointName) then
		return
	end
	local sourceJoint = ReplicatedStorage.Blaster.ViewModels.Crowbar[armName][jointName]
	local joint = Instance.new("Motor6D")
	joint.Name = jointName
	joint.Part0 = ReplicatedStorage.Blaster.ViewModels.Baton.Blaster.Body
	joint.Part1 = batonArm
	joint.C0 = sourceJoint.C0
	joint.C1 = sourceJoint.C1
	joint.Parent = batonArm
end

ensureArmJoint("LeftArmJoint", "LeftArm")
ensureArmJoint("RightArmJoint", "RightArm")
```

Verified applied via the tool's own return value (before/after instance paths for both welds, and
confirmation both new Motor6D joints were created with the correct `Part0`/`Part1`).

## Deliberately NOT touched: `Baton.Grip`

`ServerStorage.Weapons.Baton.Grip.Position` is `(0, -0.17, -0.008)` versus Crowbar's
`(0, 0.43, -3.008)` — a much smaller offset. This could mean the hand-hold pose is subtly off
(e.g. the baton sitting closer to the fist than intended), but the DRAMATIC "hanging near the
foot" symptom is fully explained by the weld bug above (an unwelded part falling under gravity),
not by Grip. Since Grip can't be verified visually from data alone (screen_capture is known broken
in this environment for Play-mode views) and guessing a new numeric offset without visual
confirmation is exactly the kind of unverified guess that caused prior Baton reports to miss the
real bug, this was intentionally left alone pending the user's in-game confirmation. Only revisit
if the user reports the Baton still looks wrong (buried in the hand, wrong angle, etc.) after
re-testing.

## Testing checklist

1. Equip the Baton in first person: confirm hands/arms are now visible holding it (not floating
   with no arms).
2. Equip the Baton in third person (or check another player holding it): confirm it now renders
   attached to the hand, not dangling near the foot/leg.
3. If either still looks wrong, report back with what specifically looks off (buried too deep in
   the hand, angled wrong, etc.) so `Baton.Grip` can be tuned precisely rather than guessed.

## Status

**Applied** directly to the live Studio place (Edit-mode DataModel) via Studio MCP on
2026-09-15. Not yet visually confirmed by the user — pending their re-test per the checklist above.
