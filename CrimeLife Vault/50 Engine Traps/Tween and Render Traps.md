---
type: trap
tags: [trap, render, tween, viewport, mesh]
updated: 2026-11-14
sources: ["CLAUDE.md (Known traps)", "70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/FPS System/FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display.md", "70 Batches/FPS System/FPS-Monetization-Cosmetics-Spec.md", "OBT Vault/50 Engine Traps/Tween and Render Traps.md (generic traps)"]
---

# Tween and Render Traps

Render-driven animation, viewport previews, materials and meshes.

## Render loop

### Tweens stop when Studio stops rendering (Known trap)
- **Symptom:** a card's entrance tween never progresses (`card.Position` caught still at its start, target + 40 px); clicks do not land; RenderStepped reports 0 FPS.
- **Cause:** TweenService and RenderStepped are render-driven. With the Studio viewport collapsed (`ViewportSize` 1, 1), nothing renders; Heartbeat still runs.
- **Fix:** none in code: an environmental failure, not a code fault. Check `ViewportSize` first and report the tween as not verified ([[Studio Host and Instance Id]]).
- **Bit us:** [[FPS-Skins-Card-Detached-And-Palette-Expansion]], [[FPS-Spraypaint-Phase-2]] (for "this whole session").

### Writing a property does not stop a tween on it (OBT)
- A running tween keeps writing every frame; a plain assignment does not cancel it. Cancel the tween, or put the value back with a 0 s tween.

### A RenderStepped follower of a tween runs a frame behind (OBT)
- Update a follower when the value changes, not in a per-frame pass that reads the tween's output.

### An unfocused Studio renders 9 to 16 FPS (OBT)
- Frame-count thresholds and per-frame loops run slower than on a real device.

## Viewport previews

### Spinning about a weapon's authored pivot makes it orbit
- **Symptom:** large rifles in the shop's 3D preview swung round instead of turning in place; pistols looked fine.
- **Cause:** a weapon's authored pivot is not its centre.
- **Fix:** spin about the centred origin; reuse the existing viewport code and tear the spin down when the panel closes. **Bit us:** [[FPS-Weaponary-Persistence-Sorting-Sounds-3D-Display]]; restated in [[FPS-Monetization-Cosmetics-Spec]].

### The preview is oriented from the muzzle marker
- The detail panel's preview faces the weapon by its `MuzzleAttachment`; a weapon without one has no orientation ([[Building Rules]], [[Weapon Shop and Upgrades]]).

## Materials and meshes (OBT)

### A FileMesh SpecialMesh draws as plastic
- A SpecialMesh FileMesh ignores the part's Material; skins that rely on Material need MeshParts.

### A SpecialMesh part's Size says nothing about what it draws
- Do not measure a mesh with its part box.

### Metal turns light greys near-black or blue
- Metal and Reflectance mirror the sky. A metal look is SmoothPlastic without reflectance.

### Roblox draws one side of a face
- Blender renders both sides; render with backface culling to see holes before Studio.

### A Decal or Texture draws on a part with Transparency 1
- Hide a part's Decals and Textures with it.

### A float property never equals what you wrote
- Match your own writes within 0.001, never exactly.

### Particle Rate is capped near 450
- Cost = capped emitters x lifetime; particles draw even behind walls.

Related: [[Engine Traps MOC]] · [[Screen Captures]] · [[Viewmodels and Weapon Animation]]
