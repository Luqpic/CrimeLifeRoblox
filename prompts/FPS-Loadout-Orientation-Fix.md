# Prompt: Fix Backwards Gun Orientation (AKM, Scar L, Kriss Vector)

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Bug

In third-person / other-players' view, three of the six weapons added in the FPS loadout expansion are held backwards — the stock points away from the character and the muzzle points back toward their own body/face, instead of the muzzle pointing away toward the aim direction. Confirmed visually on:
- AKM
- Scar L
- Kriss Vector

HCAR, M1911, Mateba 2006M, and the original Blaster/AutoBlaster are all correctly oriented. Do not touch those.

## Confirmed root cause (already diagnosed — do not re-derive, just verify and apply)

This is a **world-model mesh orientation bug**, not a `Grip` problem. Evidence:

- `StarterPack.AKM.Grip` (Position and Rotation) is byte-identical to `StarterPack.HCAR.Grip` — every weapon shares the same Tool Grip convention, confirmed unaffected.
- The bug is in each broken weapon's gun-body Model, specifically `Body`'s baked `CFrame`/`Rotation`, which is rotated exactly 180° around the local Y axis relative to the working weapons:
  - `StarterPack.HCAR.Blaster.Body.Rotation` = `(90, 0, 180)` ✅ (matches `StarterPack.AutoBlaster.Blaster.Body.Rotation`, the template)
  - `StarterPack.AKM.Blaster.Body.Rotation` = `(-90, 0, 0)` ❌ (180° off on Y)
  - `StarterPack["Scar L"].Blaster.Body.Rotation` = `(-90, 0, 0)` ❌
  - `StarterPack["Kriss Vector"].Blaster.Body.Rotation` = `(-90, 0, 0)` ❌
- `Body`'s siblings (`TrimA`/`TrimB`/etc., `Magazine`) are attached via `WeldConstraint`, which preserves whatever relative offset existed when the weld was created. That means the fix must move `Body` and its welded siblings together, as one rigid unit, not edit `Body.CFrame` alone (that would desync the welds).

## The fix (world model — apply this first, high confidence)

For each of the three broken weapons, rotate the **inner gun-body Model** (the `Model` named `Blaster` that contains `Body`/`Trim*`/`Magazine`/`MuzzleAttachment` — not the Tool itself, not its `Handle`) by 180° around its own current pivot using `Model:PivotTo`, which moves every welded part together and preserves their relative arrangement:

```lua
local StarterPack = game:GetService("StarterPack")
local FIX_180_Y = CFrame.Angles(0, math.rad(180), 0)

local brokenGunModels = {
	StarterPack.AKM.Blaster,
	StarterPack["Scar L"].Blaster,
	StarterPack["Kriss Vector"].Blaster,
}

for _, gunModel in brokenGunModels do
	gunModel:PivotTo(gunModel:GetPivot() * FIX_180_Y)
end
```

Do not modify `Tool.Grip` on any of these three — it's already correct and shared with every other weapon.

After applying: enter Play mode, equip each of the three weapons, and use `screen_capture` from a third-person / other-player angle (or check `StarterPack.<Tool>.Blaster.Body.Rotation` now reads `(90, 0, 180)` like the working guns) to confirm the muzzle now points away from the character, matching how HCAR/AutoBlaster look. If the gun renders correctly but its position looks slightly off-center from the hand (possible since the 180° rotation pivots around `Body`'s own origin, which isn't necessarily the gun's midpoint), do a small position nudge along the model's local Z axis to reseat it in the grip — don't second-guess the rotation itself, just the position offset if needed.

## Viewmodel (first-person) — verify before touching, likely already fine

The first-person viewmodel (`ReplicatedStorage.Blaster.ViewModels.<Gun>.Blaster.Body`) is positioned at runtime by a `Motor6D` (`BodyJoint`, connecting `Root` → `Body`), not by `Body`'s raw stored `CFrame`. Motor6D overrides whatever `CFrame` is saved on the part, so the same "Body's static Rotation looks 180° off" signature that's present here too does **not** necessarily mean the rendered first-person view is wrong — it depends on how `BodyJoint.C0`/`C1` were authored.

Already checked: `BodyJoint.C1` (the offset in `Body`'s own local space) is byte-identical between `AKM` and `HCAR`, meaning the joint rig itself is consistent. Only `C0` (the Root-side offset, which is expected to vary per gun since each gun's grip point differs) is different — that's normal, not necessarily a bug.

**Do this:**
1. Enter Play mode, equip AKM, Scar L, and Kriss Vector one at a time, and `screen_capture` the first-person view for each.
2. If the muzzle correctly points away from the camera and the grip looks natural (comparable to how AutoBlaster/HCAR look in first person) — leave it alone. Don't preemptively edit the Motor6D.
3. If (and only if) one is actually backwards in first person too: do **not** copy another weapon's `C0` wholesale (its `Position` component is gun-specific — copying it will misplace the grip). Instead, only correct `BodyJoint.C0`'s rotation component, keeping its `Position` unchanged, and verify empirically in Play mode — try both `C0 = C0.Rotation * CFrame.Angles(0, math.rad(180), 0) + C0.Position` and the reverse composition order, since Motor6D composition order affects the result and is faster to confirm visually than to re-derive analytically. Re-`screen_capture` after each attempt before deciding it's fixed.

## Verification checklist

- [ ] `StarterPack.AKM.Blaster.Body.Rotation`, `StarterPack["Scar L"].Blaster.Body.Rotation`, `StarterPack["Kriss Vector"].Blaster.Body.Rotation` all read `(90, 0, 180)`, matching the working weapons.
- [ ] Third-person screen capture of all three weapons shows the muzzle pointing away from the character, stock near the hands/shoulder.
- [ ] No changes made to `Tool.Grip` on any weapon.
- [ ] No changes made to HCAR, M1911, Mateba 2006M, Blaster, or AutoBlaster.
- [ ] First-person view checked via screenshot for all three; only touched if actually confirmed wrong.
