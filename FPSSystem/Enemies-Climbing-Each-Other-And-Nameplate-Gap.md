# Change Log: Enemies Flying Upward, Equip Sound Audibility, Nameplate Gap

**Date:** 2026-09-19
**Status:** Applied (enemy physics and nameplate confirmed live; equip volume needs an ear check)

## Enemies launching vertically

Reproduced before changing anything, and the numbers named the cause. Over a 45s run with 60 enemies the closest pair sat at a constant **1.56-1.59 studs** -- far closer than two rigs can legitimately stand -- and one rig climbed **365 studs at a constant +7.7 studs/s that never decayed**. A collision impulse decays under gravity; a constant rate means something was driving it continuously.

Two interpenetrating Humanoids each treat the other as ground and step up onto it, so they climb each other indefinitely. They interpenetrate in the first place because every enemy type spawns from a **single** point with a cap of **10**, and `isSpawnPointClear` only keeps rigs away from PLAYERS -- nothing stopped one landing inside another.

- `EnemySpawner` -- spawned rigs now go into an `EnemyCharacter` collision group that does not collide with itself. Only the self-pairing is disabled, so enemies still collide with the world and with players, and weapon raycasts (which run against the default group) are untouched. Same mechanism `RagdollController` already uses for corpses.
- Enemy weapon equip volumes, which an earlier pass had raised along with the player's, were restored -- an enemy equips on spawn and up to 60 spawn.

Measured after: peak rise **0.3 studs**, peak upward velocity **1.6**, all 679 enemy parts in the group.

## Equip sound on guns

The sound was never missing: all 37 weapons carry an equip asset, and equipping through the hotbar's own path demonstrably creates and plays it. The problem is that the gun recordings are simply quiet. Measured peak loudness with every sound at the same volume:

| asset | weapons | peak |
|---|---|---|
| rifles / SMGs | 15 | 18.2 |
| shotguns | 4 | 27.9 |
| pistols | 7 | 59.2 |
| crowbar | 1 | 310.7 |

The crowbar is 17x louder than a rifle, which is why it was the only equip anyone could hear.

- Player weapon equip volumes scaled to land every gun near a comparable level: rifles/SMGs 3.50, shotguns 2.50, pistols 1.20. Nothing was made louder than the crowbar, which was left alone.

## Nameplate gap

The name box ran to 0.569 of the plate while the health bar started at 0.500, so they overlapped by 0.069. The bar now starts at 0.640, giving a **+0.071 gap**. The name's own size and position are untouched.

## Notes
- `Sound.PlaybackLoudness` reports the RAW waveform and ignores `Volume` (verified: the same asset read 28.9 at volume 0.70 and 18.2 at 3.50). So the table above is a valid comparison BETWEEN assets at equal volume, but it cannot measure the gain that was applied. Volume is applied downstream as output gain and is present on the sound that actually plays; the exact numbers are a taste call and may want adjusting by ear.
- Clicking a hotbar slot with the mouse could not be exercised: equipping sets `MouseBehavior` to `LockCenter`, so the cursor is pinned to screen centre. The slot's number-key binding runs the same `manageTool` function and was used instead.
- Noticed while tracing: `DeathScreenGui` sits Visible over the HUD at full health with its overlay fully transparent. It did not cause this bug and was left alone.
