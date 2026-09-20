# FPS System weapon viewmodel animation pass

Installed in the existing FPS System.rbxl Studio session. These are procedural first-person Motor6D animations, not published Roblox animation assets or Animation Editor timelines.

## Coverage

All 28 weapon viewmodels have equip, idle breathing, movement/sprint, attack and recovery. Firearms also have aim transitions and reload poses scaled to existing reload durations. Profiles distinguish magazine, rocking magazine, top-loading, bullpup, shell and revolver actions. Crowbar and Baton have three swings whose contact poses land at the existing swingDelay.

The new `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` owns the cloned viewmodel joints. `ViewModelController` drives it; `BlasterController` supplies aim and reload-cancel events. Gameplay damage, ammo, reload durations, firing cadence and character animation calls are unchanged. Original Animation instances remain in the model templates.

## Verification

- 28 real rigs: 7,102 assertions covering finite motion, settling, cancellation, skipped-frame sound markers, sustained firing, reset and all three timed melee contact poses.
- Live controller smoke test on all 28 weapons: equip, attack, reload/cancel, aim, third-person toggle, destroy.
- Sampled live first-person poses: AK47 idle/reload/aim, Mateba reload, Mossberg reload, Crowbar impact.
- Existing project tests previously reported 26/26 passing during implementation.

## Limits

The imported rigs have whole arms rather than elbow/wrist chains. Revolvers lack cylinder joints and pump shotguns lack separate fore-end joints; their motions therefore use the existing weapon and hand joints. Existing inaccessible sound assets produced authorization errors in Studio; sound playback requires those assets to be accessible. Sampled poses and numerical tests are not a full artistic review of every weapon from every camera/FOV.

## Editing and rollback

Tune profiles, reload tracks and swing poses in `WeaponViewmodelMotion`. Local source mirrors are provided here; changing a local file alone does not update Studio. `WeaponViewmodelMotion.spec.luau` corresponds to `ServerStorage.WeaponViewmodelMotionTests` (not an automatic production runner).

The `baseline` directory contains the two original controller sources. To revert this animation pass, restore those two Studio ModuleScripts. The motion module and test module can then be removed; original asset references and model geometry were not replaced.
