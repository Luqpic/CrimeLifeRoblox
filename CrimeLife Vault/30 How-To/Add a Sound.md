---
type: howto
tags: [howto, audio]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Hover-Sound.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Polish-And-Denied-Feedback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Figma-Image-Export-Pipeline.md", "CLAUDE.md (Known traps)"]
---

# Add a Sound

CrimeLife has no central sound table. A sound goes where its owner already keeps sounds: the weapon's `Sounds` folder, the shared `UI.Sounds` module, or a named constant in its controller. System: [[Weapons and Blaster]], [[HUD and UI Shell]].

Skills: `roblox-audio`.

## Steps
1. **Weapon sounds:** a `Sound` in the Tool's `Sounds` folder by role: `Shoot1`..`Shoot3`, `Equip`, `MagOut`, `MagIn`, `Charger`, `Impact` (played at a blast point by `ShotResolver.explode`). Borrow a whole set with the build script's `sounds` field ([[Add a Gun]]). Equip and melee swing play explicitly from `ViewModelController`; reload cues ride the `MagOut` / `MagIn` / `Charger` markers. A single long reload sound on the first cue means silencing the later ones.
2. **UI sounds:** `ReplicatedStorage.UI.Sounds` (`hover()`, `click()`, `denied()`, `bind(button)`, `CLICK_SOUND_ID`). One shared hover and one shared click for everything; find-or-create against `SoundService`, never a copy per button.
3. **Controller sounds:** named `*_SOUND_ID` constants (`WeaponaryShopController.PURCHASE_SOUND_ID`, `UPGRADE_SOUND_ID`, `HOVER_SOUND_ID`; `QuestFeedbackController.COMPLETE_SOUND_ID`); the level-up sound is `GuiTemplates.LevelUpPopup.LevelUpSound`.
4. **3D sounds** heard by everyone: parent to an Attachment at the spot (the RPG impact uses one in Terrain), with a roll-off distance.
5. **The asset must be usable by the place.** Inaccessible assets throw authorization errors in Studio and play nothing (the "unauthorized-sound noise" in many logs).

## Files to touch
The Tool's `Sounds` folder, `UI.Sounds`, or the owning controller.

## Check
- Read back which sounds played and their ids in Play.
- `PlaybackLoudness` compares assets; it ignores `Volume`, so it does not measure applied gain.
- Claude cannot hear: the report says "not heard" until a person listens.

## Done before
[[FPS-Equip-Sound-Fix-And-Crowbar-Hit-Sync]], [[FPS-Loadout-Bugfixes-Sounds-VFX]], [[FPS-Shop-Hover-Sound]], [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]], [[FPS-Inventory-Slot-Click-Sound-And-Hover-Outline]], [[FPS-Shop-Polish-And-Denied-Feedback]], [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]], [[Shared-UI-Effects-FOV-Blur-And-Sounds]].
