# Change Log: Magazines and Pump Fore-Ends on the New Guns

**Date:** 2026-09-24
**Status:** Applied — measured live in play; how it looks mid-reload has not been confirmed by eye
(the reload is faster than a tool round trip, so no screenshot could catch it).

## Summary
Two reports: the new pistols had no magazine, and on some weapons the gun did not move with the
viewmodel when firing. The pistols now drop and reinsert a real magazine on reload. The pump
shotguns' fore-end now racks back with the hand after every shot, where before the hand slid along
a fore-end that stayed still.

## Cause
- **"Not moving with the viewmodel."** A measured sweep of all 34 guns ruled out the obvious
  theory. No gun part moves relative to the weapon body while firing (worst drift 0.000 studs,
  against a body kick of 0.27–1.16). The fault was the pump cycle: `WeaponViewmodelMotion` slides
  the **left hand** 0.55 studs back and forward after each shot on `pump` weapons, and its comment
  says the pump rigs "have no isolated fore-end mesh". The hand racked while the pump stayed put
  (before: hand 0.56, fore-end 0.00). Affected: Remington 870, Sawed-Off 870, SPAS-13, and the
  existing Mossberg 590 and Spas 12.
- **No magazine.** My first build welded every source part to Body. I had judged the magazine as
  "fused into the grip" from a bounding-box highlight, which was wrong: the magazine sits slanted
  inside the grip, so its box covered the whole grip. An exploded view (every part laid out alone)
  showed each pistol ships a separate magazine mesh: GLOCK #5, SIG #8, M45A1 #4, USP #2.

## Changes
- `Workspace.Pistols.*` / `Workspace.Shotguns.*` — the moving pieces are tagged with a
  `MovingPiece` attribute (`Magazine` or `Pump`) so the build reads them as data.
- `ReplicatedStorage.Blaster.ViewModels` (8 rebuilt) — pistol magazines are welded to the donor's
  existing animated `Magazine` part (the left hand already hangs off it). Pump fore-ends are welded
  to a new invisible `Pump` part on a `Body -> Pump` Motor6D (`PumpJoint`). MP-153 is a semi-auto
  with no moving piece. Tools are unchanged apart from the rebuild; third person stays rigid.
- `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` — in the pump branch, `p.Pump` takes
  the hand's translation, so any rig with a `Pump` joint racks with the hand. Rigs without one are
  untouched, because joints are collected generically from Motor6Ds.
- `Blaster/BuildNewPistolsShotguns.luau` (this repo) — the build as a re-runnable script. The
  earlier build existed only in a chat session.

## Verification (play mode, before → after)
| Weapon | Moving piece | Before | After |
|---|---|---|---|
| Remington 870 | fore-end travel on shot | 0.00 (hand 0.56) | 0.55 (hand 0.56, max gap 0.094) |
| Sawed-Off 870 | fore-end travel on shot | 0.00 | 0.55 (gap 0.094) |
| SPAS-13 | fore-end travel on shot | 0.00 | 0.55 (gap 0.094) |
| SIG M17 | magazine travel on reload | 0.00 | 0.94 |
| M45A1 / USP Compact / Glock 18 | magazine travel on reload | 0.00 | 0.95 each |

The remaining 0.094 gap is the hand's own 3° wrist tilt in the authored pose, left as authored.
0 client and 0 server errors, excluding the pre-existing unauthorized-sound noise.

## Notes
- Mossberg 590 and Spas 12 still rack an unmoving fore-end: their fore-end is fused into larger
  meshes (Mossberg `Body`/`TrimA-C`, Spas `Mesh1-4`). The fix is ready for them — give either one a
  separate fore-end mesh on a `Pump` joint and it animates with no code change — but that needs the
  mesh split, which this change does not do.
- Shotguns get no magazine. Every one here is tube-fed and reloads shell by shell, and the donor
  rig has no magazine joint by design.
- In the 34-gun sweep, the two revolvers (Mateba, S&W 29) also showed the left hand moving about
  0.55 relative to the body while firing. That was observed, not investigated.

## Still needs a person
- Watch a pistol reload and a pump cycle in first person. The numbers are right, but the look has not
  been confirmed by eye.
- Save the place.
