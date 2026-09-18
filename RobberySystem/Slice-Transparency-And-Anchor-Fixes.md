# Change Log: Slice Transparency and Anchor Point Fixes

**Date:** 2026-09-18
**Status:** Applied (confirmed live)

## Summary
The imported UI shipped with white boxes behind every badge and ribbon panel, and several panels were visibly misaligned. Two independent causes. First, Figma's export bakes the page background into the image as opaque — a page created through the plugin API defaults to a light grey, so every slice came back with zero transparent pixels. Second, the Studio elements being repositioned had kept their original centre and right anchor points while being given top-left coordinates.

## Changes
- All 23 slices re-exported with the export page's background cleared, then re-uploaded; `UITheme` updated to the new ids.
- `StarterGui` — anchor points reset on the nine elements that had been repositioned, leaving deliberate anchors (screen-centred dialogs, the corner notification stack, the lockpick ring sprites) alone.
- Lockpick ring and zone sprites re-exported white so they can be tinted at runtime.

## Notes
- A `hasAlpha` check does not catch this class of bug: the alpha channel exists, it is simply 255 everywhere. Verifying it required decoding real pixel alpha.
- The same opaque background is why the lockpick's success arc rendered as a solid green rectangle — an opaque image multiplied by a green tint fills the whole rect.
- The mis-anchored `GuessBox` was the clearest symptom: anchored at its centre but positioned as if top-left, it rendered roughly 125px to the left of its own outline.
