# Change Log: Baton Viewmodel Hands and Third-Person Attachment

**Date:** 2026-09-15
**Status:** Applied

## Summary
Fixed the baton appearing without hands in first person and dangling by the character's foot instead of being held in third person. Both came from the same earlier rebuild, where the baton was duplicated from the crowbar and then had the enemy baton's model swapped in: the swapped-in model was still attached to the enemy template's own handle rather than the baton's, and the first-person model was missing the joints that position the player's arms.

## Changes
- `ServerStorage.Weapons.Baton` — the visible world model is now attached to the baton's own handle. It was still pointing at the enemy template's handle, an unrelated object elsewhere in the place, which left the model attached to nothing and falling under gravity rather than being held.
- `ReplicatedStorage.Blaster.ViewModels.Baton` — removed a leftover attachment on the first-person model that the crowbar's equivalent does not have, since the first-person model is positioned entirely by its joints.
- `ReplicatedStorage.Blaster.ViewModels.Baton` — added the two missing arm joints, copied from the crowbar's first-person model. Without them nothing positioned the hands at all, which is why no arms were visible.

## Notes
- This was applied directly in the session that diagnosed it rather than drafted first, because each step was a mechanical property edit backed by a direct comparison against the known-good crowbar rig. The change log was written afterwards so the archive stays complete.
- Verified afterwards against the crowbar: both attachments now mirror it exactly, both arm joints are present with matching offsets, and the first-person model's full set of joints and swing-trail points survived intact. The only structural differences left between the two weapons are the intended model differences.
- The record of this fix states the first-person model was recoloured but deliberately not model-swapped. It has in fact been model-swapped — it carries its own mesh, unlike the crowbar's. The rig survived that anyway, so the risk that motivated leaving it alone did not materialise, but the record was inaccurate on that point.
- The arm joints were copied from the crowbar unchanged, and the two first-person models are very differently shaped: the crowbar's is long front-to-back while the baton's is tall and shallow. Measured, the arms sit a little under half a stud in front of where the baton actually is. The hands will now render, which was the reported bug, but they are unlikely to line up with the weapon. This was left alone rather than guessed at, since where a hand should sit on a grip is a visual judgement and screen capture does not work here.
- The baton's hold position matches neither the crowbar it was duplicated from nor the enemy baton its model came from, so its origin is unclear. Worth revisiting together with the arm placement above if the weapon still looks wrong in hand.
