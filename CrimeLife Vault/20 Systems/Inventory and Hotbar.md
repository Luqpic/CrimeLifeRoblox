---
type: system
tags: [system, ui, inventory, hotbar]
updated: 2026-11-14
sources: ["CLAUDE.md (Instance tree)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weapon-Pickups-And-Inventory-Integration.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Inventory-Button-Fix-And-Hotbar-Slot-Count.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Equip-Bug-Diagnosis-And-Inventory-Button.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Inventory-Slot-Click-Sound-And-Hover-Outline.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Loadout-Slot-Hover-Outline.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-4.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip.md"]
---

# Inventory and Hotbar

**Skills:** `roblox-ui`, `roblox-input` (load these for work here)

## What it does
A third-party "Custom Inventory" replaces the Roblox backpack: a 6-slot hotbar plus an inventory grid, drag-and-drop between them, click or number key to equip, and a lock while dead. It also hosts the HUD button column (see [[HUD and UI Shell]]). The shop's four loadout slots are a separate column inside the Weaponary panel ([[Weapon Shop and Upgrades]]).

## Where it lives
- `StarterGui."Custom Inventory"`: `InventoryController`, its `SETTINGS` module (`manageTool()`, hover/drag effects, `EQUIP_SOUND_ID`, `HOVER_STROKE_*`), `toolButton` template, `openButton`, and the HUD buttons (`weaponaryButton`, `playerCardButton`, `questsButton`, ...).
- `ServerScriptService.Weapons.Scripts.EquipService` (server side of equip requests).
- Loadout slots: `StarterPlayer.StarterPlayerScripts.WeaponaryShopController` (`refreshInventoryColumn`, `setSlotPickMode`).

## How it works
- The inventory reacts to whatever appears in the player's `Backpack`; weapons are cloned in, never registered with the UI.
- Death lock goes through the inventory's own lock/unlock API (`InventoryDeathLock` was removed because it fought it). A forced unequip runs at death.
- Hotbar is 6 slots (was 9); the slot-count loop follows the same setting.
- Slots show the weapon icon only; a weapon with no icon falls back to its name.
- Drag: item centred on the cursor, white pulsing `DragGlow` while held, pop + white flash on settle (driven by a scale modifier, not `Size`). Click versus drag is decided by a movement-distance threshold.
- Hover: background lift plus a lazily created `HoverOutline` UIStroke (accent `#CBF23C`, 2px, 0.12s fade). Click to equip/unequip plays `rbxassetid://111258886624386` on the `wasClick` branch only, so number keys and the death unequip stay silent.
- Equipped slot: `UIGradient` (white -> 59% grey, rotation 90) with `UIGradient.Transparency = 0.35`.
- Loadout slots in the shop: outlined acid 2px when filled, hairline 1px when empty; a separate 3px `HoverOutline` shows only while the equip picker is waiting (`pendingEquipWeapon`), and `setSlotPickMode(false)` clears all four.

## Extend it
- Change slot behaviour in `SETTINGS`; it is capability-sandboxed, so it cannot `require` across the boundary (colours are literals, the equip sound is find-or-create against `SoundService`).
- Do not touch `UI.Effects` for inventory-only behaviour; it is kept byte-identical with the Robbery place.

## Watch out
- `Custom Inventory` carries a restricted `Capabilities` property: a script cannot be parented into it.
- Hotbar and grid rewrite every slot's size on each layout pass; animate a scale modifier, not `Size`.
- The hover effect caches `BackgroundTransparency` as `RestingTransparency` on `MouseEnter`; a write during hover is overwritten. That is why the equipped transparency lives on the gradient.
- Look up the shop slot's state stroke by name (`FindFirstChild("UIStroke")`), not by class: slots hold two strokes.
- While a gun is equipped `MouseBehavior` is `LockCenter`; slot-click tests must use the number-key path or measure cursor movement.
- A single stray mouse-move sets the drag-started flag; use the distance threshold.

## History
- 2026-09-21: loadout slot hover outline, gated to the equip picker, plus equip sound. [[FPS-Loadout-Slot-Hover-Outline]]
- 2026-09-21: inventory slot click sound and hover outline. [[FPS-Inventory-Slot-Click-Sound-And-Hover-Outline]]
- 2026-09-19: clicking a hotbar slot equips. [[Enemy-Spread-Spawn-Rate-And-Slot-Click-Equip]]
- 2026-09-18: equipped slot semi-transparent green gradient; filled loadout slots outlined. [[FPS-Figma-UI-Bugfix-Pass-4]], [[FPS-Shop-Polish-And-Denied-Feedback]]
- 2026-09-13: icon/name clash fixed, drag-and-drop feedback. [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]]
- 2026-09-12: hotbar outline removed. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: inventory button visible; hotbar 9 -> 6 slots. [[FPS-Inventory-Button-Fix-And-Hotbar-Slot-Count]]
- 2026-09-11: equip bug traced by instrumenting the round trip; inventory toggle became a top-right icon button. [[FPS-Equip-Bug-Diagnosis-And-Inventory-Button]]
- 2026-09-11: inventory locked while dead. [[FPS-Spawner-Rework-Enemy-Nerf-Death-Inventory]]
- 2026-09-11: Custom Inventory integrated, replacing the native backpack. [[FPS-Weapon-Pickups-And-Inventory-Integration]]

See [[Batch Log]].
