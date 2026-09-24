# Change Log: Quest Givers Dressed as Law Enforcement

**Date:** 2026-09-24
**Status:** Applied — outfits verified by screenshot in Edit and Play. Talking to a quest giver was NOT
verified: automated input could not trigger any quest prompt, with or without an outfit (see Notes), so
a person should press E on one. The place is not saved to disk by this change.

## Summary
The six quest givers were plain grey dummies. They now wear the law-enforcement uniforms already stored
on the police-side enemies, rising with the quest tier: those who send you after criminals are the law.

| Quest giver | Outfit (from `ServerStorage.EnemyTemplates`) |
|---|---|
| Level 1, Level 10 | Security — cap, armband, utility belt |
| Level 20, Level 35 | Police — peaked cap, badge, belt, baton, watch |
| Level 50, Level 70 | SWAT (`Armed Police`) — helmet, balaclava, armband, vest, back shield |

## Changes
- `Workspace.Quests.<each NPC>` — the template's Shirt, Pants and BodyColors cloned in (replacing the
  grey BodyColors), and every Accessory added through `Humanoid:AddAccessory`, so each one welds to its
  own attachment. Accessory parts are non-colliding, non-queryable, non-touching and massless, so nothing
  changes about how an NPC is approached or shot past. Each NPC records its source as an `Outfit`
  attribute.
- Weapons are deliberately not copied: an enemy's gun or baton is a Tool, not part of the outfit.
  (Police's holstered baton and SWAT's back shield ARE accessories — part of the uniform — and come along.)
- Nothing else touched: the NPCs stay anchored, their faces, billboards and prompts are unchanged.

## Verification
- Before/after screenshots of all six; in Play every accessory stayed attached (farthest handle 2.0–3.1
  studs from the head, i.e. worn, not fallen), each NPC still has its one prompt, roots still anchored,
  0 server errors.

## Notes
- **Prompt check, inconclusive in the harness.** Driving the quest prompt by script and by a real E key
  press showed nothing and fired no `Triggered`. An A/B test ruled out the outfits: the Level 10 giver with
  its outfit removed failed identically, in the same session. The prompts are `RequiresLineOfSight = false`,
  so accessories cannot block them in any case; they are `Style = Custom` (drawn by the place's own prompt
  UI), which is the likely reason automation cannot see them. Worth one real press to confirm.
- The Security shirt is a marketplace asset with "RO-GHOUL" printed on the back — that is the enemy
  template's own shirt, carried over unchanged.
- Level ranges are split two givers per tier (1/10, 20/35, 50/70) since there are six givers and three
  outfits.
