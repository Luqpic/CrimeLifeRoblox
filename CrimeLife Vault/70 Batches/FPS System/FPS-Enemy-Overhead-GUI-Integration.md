# Change Log: Enemies Get the Custom Name and Health Display

**Date:** 2026-09-16
**Status:** Applied

## Summary
The overhead name-and-health display that had been built and left sitting on a test block in the
world is now on every enemy. Roblox's own plain nameplate, which would otherwise have drawn on top of
it, is switched off. The bar tracks damage as it happens and the whole display now disappears when an
enemy dies rather than hanging over the body reading zero.

## Changes
- `ReplicatedStorage.GuiTemplates.EnemyGUI` — the display, moved out of the world to sit with the
  other interface templates as the single copy everything else copies from. Its health script gained
  a few lines to hide the display once health reaches zero.
- `Workspace.Part` — the test block it had been sitting on, removed. It existed only to hold the
  display while it was being designed.
- `ServerStorage.EnemyTemplates` — all six templates have Roblox's built-in floating name and health
  display turned off.
- `ServerScriptService.Enemy.Scripts.EnemySpawner` — attaches a copy of the display to each enemy's
  head as it spawns.

## Notes
- The display is attached when an enemy spawns rather than built into the six templates, and that
  ordering is the whole point rather than a preference. Every freshly copied enemy has all of its
  scripts destroyed on spawn, without exception. Built into a template, the two scripts that drive
  this display would have been destroyed before they ever ran. Attaching afterwards leaves them
  untouched, and nothing strips an enemy a second time.
- Neither of the two scripts needed rewriting. Both find what they need by counting steps up the
  tree, and the number of steps from the display down to the character is the same whether it hangs
  off a test block or off an enemy's head. Only where the display lives changed.
- The height above the head had never been checked against an actual enemy by anyone. It was checked
  here, by putting the display on a real enemy and looking at it: it sits clear of the head with a
  comfortable gap and needed no adjustment.
- There is a genuine trap in this display worth recording. The name label is called "Name" and its
  script is called "Text", and both of those collide with properties that already exist on the things
  holding them, so ordinary ways of referring to them quietly return the property instead of the
  object. The existing scripts sidestep it by never naming either one. Anyone editing them later
  should keep it that way.
- The name shown is the generic "Enemy" every spawned enemy is renamed to, which is what the display
  was already built to show. Each enemy does separately remember which type it came from, so showing
  "Thug" or "Security" instead is available whenever that is wanted.
