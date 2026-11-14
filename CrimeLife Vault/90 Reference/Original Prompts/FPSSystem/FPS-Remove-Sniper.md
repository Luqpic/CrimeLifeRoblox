# Prompt: Fully Remove the Sniper (Snipex Alligator)

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Scope

Already confirmed before writing this prompt, so no re-investigation needed:
- The raw source mesh (`Workspace."Snipex Alligator"`) no longer exists — it was already consumed when the weapon was originally built.
- No script anywhere references the string `"Snipex"` except the weapon's own two instances (listed below) — there is no hardcoded fallback dependency to worry about (unlike the earlier Blaster→Deagle rename, which had one).
- `ServerStorage."Gun Pack".Snipex T-rex` is a **different, unrelated, pre-existing asset** that was never part of this weapon — do not touch it.
- `ReplicatedStorage.Blaster.Constants.ZOOM_FOV_ATTRIBUTE` / `ZOOM_CAMERA_OFFSET_ATTRIBUTE` / `ZOOM_SENSITIVITY_ATTRIBUTE`, and the per-weapon zoom logic in `BlasterController:applyZoom()`, were built specifically to give this weapon a distinct scope. No other weapon in the game sets any of these three attributes. Removing the sniper leaves this code with zero consumers.

## Step 1 — Delete the weapon itself

Delete both:
- `StarterPack."Snipex Alligator"` (Tool)
- `ReplicatedStorage.Blaster.ViewModels."Snipex Alligator"` (Model)

That removes every asset that belongs only to this weapon (its Sounds, Handle, Animations, Scripts, world model, and viewmodel all live under these two instances).

## Step 2 — Revert the per-weapon zoom system it required

This is a judgment call, flagged clearly: since nothing else uses per-weapon ADS zoom, leaving the attribute-driven version in `BlasterController` would be dead, untriggerable code — reverting it to the original hardcoded-constants version is what "no traces" implies. If you'd rather keep the generic capability around for a future scoped weapon, skip this step and stop after Step 1 — everything in Step 1 is independent of this.

**`ReplicatedStorage.Blaster.Constants`** — remove these three lines (and the comment directly above them, "Per-weapon ADS overrides..."):
```lua
ZOOM_FOV_ATTRIBUTE = "zoomFov",
ZOOM_CAMERA_OFFSET_ATTRIBUTE = "zoomCameraOffset",
ZOOM_SENSITIVITY_ATTRIBUTE = "zoomSensitivity",
```

**`ReplicatedStorage.Blaster.Scripts.BlasterController`** — revert `applyZoom()` back to:
```lua
function BlasterController:applyZoom()
	-- Camera ownership (FOV/CameraOffset/mouse sensitivity) goes through CameraAuthority so it
	-- resolves correctly against Crouch/Sprint/ShiftLock instead of last-write-wins.
	CameraAuthority.CameraOffset:Set("ADS", CAMERA_OFFSET_ZOOMED)
	CameraAuthority.FieldOfView:Set("ADS", ZOOMED_FOV)
	CameraAuthority.MouseDeltaSensitivity:Set("ADS", ZOOMED_SENSITIVITY_SCALE)

	self.isZoomedIn = true
	self:startAimAssist()
end
```
(`removeZoom()` needs no change — it only ever cleared the `"ADS"` source, independent of which values were set.)

## Verify

- `StarterPack` and `ReplicatedStorage.Blaster.ViewModels` no longer contain anything named "Snipex Alligator".
- The backpack/hotbar no longer offers the sniper; every remaining weapon still equips, fires, reloads, and zooms exactly as before.
- If Step 2 was applied: right-click ADS on any weapon still zooms correctly (using the shared hardcoded defaults again), and a grep for `zoomFov`/`ZOOM_FOV_ATTRIBUTE` across all scripts returns nothing.
- `ServerStorage."Gun Pack".Snipex T-rex` is untouched.
