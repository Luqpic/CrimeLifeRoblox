# Change Log: Melee Swing Variation System, Shotgun Shell-by-Shell Reload

**Date:** 2026-09-11
**Status:** Applied

## Summary
Two mechanics were adapted from reference example packages (models/audio from those packages were not kept, only the underlying mechanics, since they use a different sound system than this project). The shared animation system now supports playing a random pick from multiple "shoot" animation variants per weapon, used first by the crowbar. The shotgun's reload was changed from one fixed-duration action refilling the whole magazine to a shell-by-shell loop that can be interrupted by firing.

## Changes
- Shared first-/third-person animation controllers — extended to support multiple randomized shoot-animation variants per weapon; made animation loading defensive (one weapon's broken animation can no longer break loading for others); first- and third-person variant selection now kept in sync.
- Crowbar — given two additional swing animation slots (currently cloned placeholders) and a short metallic trail effect on its striking end during a swing.
- Shotgun — reload changed to a per-shell loop, gated behind a new attribute so every other weapon's reload logic is unaffected; reloading can now be cancelled by firing, unlike every other weapon; reload-time stat recalibrated so a full reload still takes about the same total time as before under the new per-shell math.

## Notes
- The ammo HUD still shows a static "reloading" indicator during the shotgun's shell-by-shell reload rather than a live-updating count — flagged as a possible follow-up.
- The shotgun's existing reload animation was authored for one monolithic reload motion and will likely need to be re-cut to loop naturally per shell.
- Neither change touches hit detection — both still go through the existing shared hit-registration pipeline.
