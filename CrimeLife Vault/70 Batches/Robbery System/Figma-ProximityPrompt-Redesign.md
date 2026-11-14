# Change Log: Figma Proximity Prompt Design

**Date:** 2026-09-19
**Status:** Applied (structure and sweep verified live; appearance needs an eyeball)

## Summary
The default Roblox proximity prompt (grey pill, key letter, action and object text) is replaced everywhere by a Figma design: a rounded dark square carrying only the key letter, with a circular progress ring around it. No action or object text -- the prompt says which key, and nothing else.

Design lives on Figma page **05 · ProximityPrompt**, alongside idle / 25% / 60% / 100% reference states.

## Changes
- New `ReplicatedStorage.UI.PromptUI` -- builds the billboard and owns the ring sweep. Byte-identical in both places (6560 bytes, matching checksums).
- New `StarterPlayerScripts.PromptUiController` -- forces every prompt to `Custom` style and drives create / sweep / destroy off `ProximityPromptService`. Also byte-identical (3498 bytes).
- Three slices exported at 4x and uploaded: the rounded plate, the dark ring track, and an accent half-ring.
- Every ProximityPrompt in the place set to `Style = Custom`, so the default face is gone.

## Notes
- **The ring is a circle rather than following the square outline.** A hold has to sweep the ring progressively, and Roblox can only reveal a shape by clipping it with rectangles. A circle sweeps exactly using the standard two-half-disc technique; a rounded-rect perimeter cannot, because its corner arcs never line up with a straight clip edge. The first Figma pass drew a rounded-rect ring and was rebuilt as a circle for this reason.
- The half-ring slice is a filled donut SECTOR, not a stroked arc. Stroking an arc in Figma closes it back to the centre, which exported a chord line straight through the middle.
- The two half-discs park at DIFFERENT rotations (180 and 0). Parking both at 180 puts the second one inside its own clip, so the ring reads as completely full the moment progress reaches one half -- caught before shipping and noted in the module.
- Sweep verified linear: filled arc measured 0 / 90 / 180 / 270 / 360 degrees at progress 0 / .25 / .5 / .75 / 1.
- `Style = Custom` is re-asserted at runtime as well as saved on each prompt, so a prompt added later cannot draw Roblox's own text alongside this one.
- Prompts with `HoldDuration = 0` trigger instantly, so their ring stays an outline; the sweep only means something for hold prompts.
- The on-screen result has not been eyeballed: `screen_capture` returns a blank frame for the play view, so it cannot photograph a running GUI. Geometry, structure and sweep were verified numerically.

11 prompts converted in this place. Hold durations here run to 8 seconds (the safes and barriers), so the progress ring carries real weight -- verified against the Illegal Supplier prompt, which built its billboard 0.4s after approach with the default face suppressed.
