# Change Log: The Six Enemy Types Are Dressed

**Date:** 2026-09-16
**Status:** Applied in part — three garments could not be sourced, see Notes

## Summary
The six enemy types all wore default grey bodies with nothing on them. They now have distinct
outfits. The thug wears a white hoodie and a beanie over dark trousers; the criminal a beanie over
plain grey; the armed criminal a black balaclava and a camouflage plate carrier over all black; the
armed police the same balaclava over all black; security a white shirt, grey trousers and a peaked
cap; and the police a blue uniform shirt with cap over navy. Each is now recognisable at a glance.

## Changes
- `ServerStorage.EnemyTemplates` — all six templates recoloured, and the clothing added to each. The
  templates are what the spawner copies on every spawn, so nothing about the spawner changed and no
  code was touched anywhere.

## Notes
- Three garments in the plan could not be applied: the criminal's hi-vis vest, the armed police's
  vest, and the duty belts for security and police. Every asset put forward for them, primary and
  fallback alike, turned out not to be wearable clothing at all. Of the fourteen asset references in
  the plan only four were genuine wearable accessories. The hi-vis vest was a hundred and thirty
  blank duplicated torso blocks; the duty belt was a whole character with a head and a torso rather
  than a belt; the armed police vest was a shop display rack holding four separate vests including
  one for a chef; and the cap bundle contained two hats named "Irish" and "YG CO", neither of them a
  uniform cap. Two of the listed fallbacks turned out to be the same asset as the primary they were
  meant to replace.
- Replacements were found for two of those gaps by searching again and checking each candidate
  before use: the balaclava now worn by both armed types, and the peaked cap worn by security and
  police. The cap needed converting from the old pre-2020 hat format, which is a wrapper change only
  — the shape and its fitting point are untouched. No replacement worth having turned up for the
  hi-vis vest, the second vest or the belts, so the armed police is currently in black with a
  balaclava and no vest.
- Everything was checked by actually looking at the six rigs rendered side by side, twice, rather
  than by trusting that an asset named after a thing is that thing. That is what caught all of the
  above.
- Several of these assets ship with scripts belonging to their marketplace display stands. Those are
  stripped before anything goes onto a rig — an enemy has no business running a stranger's code.
- The plan stated that the body colour properties take one kind of colour value when they actually
  take another. Following it as written fails immediately on the first rig.
- The staging folder holding the downloaded assets is still in server storage and should be removed
  once the outfits have been seen on spawned enemies in a running game rather than only on the
  templates.
- None of the six pre-equipped weapons was touched, and nothing here affects how enemies move,
  detect, chase or take damage.
