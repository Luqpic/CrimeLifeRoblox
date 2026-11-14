# Change Log: Loadout Expansion (6 New Weapons)

**Date:** 2026-09-11
**Status:** Applied

## Summary
Added six new weapons (M1911, Mateba 2006M, AKM, HCAR, Kriss Vector, Scar L) to the existing weapon system as pure content — no new scripts or mechanics, since the game's weapon system is fully data-driven (stats live as Tool attributes, one shared client/server controller drives every weapon). A seventh weapon, FN P-90, was intentionally left unbuilt pending a source mesh.

## Changes
- `StarterPack` — six new Tools added, each cloned from the closest existing template (pistol or auto-rifle) and given its own stats (damage, fire mode, magazine size, range, recoil, etc.) and a placeholder icon shared with its template weapon.
- `ReplicatedStorage.Blaster.ViewModels` — six new first-person viewmodel folders, each built by cloning the matching template and swapping in the new weapon's geometry while keeping all joints/animations intact.
- Raw unrigged source meshes for all six weapons were assembled (named, welded, positioned) and the consumed source models removed from Workspace.

## Notes
- FN P-90 was deliberately left unbuilt — no source mesh existed yet; its intended stats were recorded for later.
- No changes to enemy AI weapon assignment or ammo economy — explicitly out of scope for this pass.
