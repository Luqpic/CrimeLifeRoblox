# Change Log: The Baton Looked Right to Everyone Except the Person Holding It

**Date:** 2026-09-16
**Status:** Applied

## Summary
The Baton showed the correct baton to everyone else and to anyone watching a Security guard carry
one, but the wielder's own first-person view showed a plain dark stick instead. The first-person
model had never been given the baton's actual mesh — it was still the Crowbar's plain block, simply
recoloured. It now carries the real mesh, and its swing trail and muzzle point have been moved to
match the baton's actual length rather than the crowbar's.

## Changes
- `ReplicatedStorage.Blaster.ViewModels.Baton` — the first-person body now carries the real baton
  mesh, taken from the weapon's own world model.
- The same model's trail and muzzle points moved to the offsets the baton's world model already
  uses, having been left at the crowbar's.

## Notes
- The plan for this change would have replaced the first-person body outright. That part is what both
  arms are attached to, so replacing it would have detached both hands — the same fault that had
  already been hit and fixed once on the eleven new weapons. Adding the mesh to the existing part
  avoids the problem entirely, and is possible because a mesh of this kind is drawn at its own size
  regardless of the part beneath it, so the part never needed replacing.
- The plan also expected the mesh to need rotating into place by eye. It did not. Comparing how each
  of the two weapons sits relative to the hand in their world models — both of which already look
  correct — showed the baton already sits exactly as the crowbar does, so no rotation was warranted
  and none was applied.
- The trail was the one measurable mismatch: it spanned nearly three times the baton's visible
  length, and its muzzle point sat at the wrong end, both inherited from the crowbar's much longer
  block.
- Neither world model was touched, and the Crowbar's own first-person model is unchanged.
