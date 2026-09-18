# Change Log: Banner Title Centring and UI Fades

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Summary
Two changes brought over from the Robbery System place so both projects behave the same way before they are merged. Panel titles sat off-centre inside their green banner plates, and the five HUD buttons showed and hid their panels instantly with no transition.

## Changes
- Titles on all five panels re-centred inside their banner plates, re-exported and re-uploaded; `BannerPlate` images updated for Weaponary Shop, Player Card, Quest Log, Cash Shop and Gamepass Shop.
- New `ReplicatedStorage.UI.Transitions` — the same module as the Robbery place, identical code rather than a reimplementation.
- New `StarterPlayer.StarterPlayerScripts.UiTransitionBinder` — fades the HUD chrome and the four panel frames. Combat elements fade faster than chrome so the reticle is not sluggish.
- `PlayerCardController` — the card now fades in on open and fades out before being destroyed.

## Notes
- The titles are baked into the plate artwork, so centring them is an export change, not a layout property.
- `UI.Panels` owns `HUD_GUIS` and `setHudHidden` and was left untouched; the binder attaches to visibility rather than replacing that ownership.
- Both copies of `Transitions` were diffed to confirm they are byte-identical in executable content, so the merge has nothing to reconcile.
