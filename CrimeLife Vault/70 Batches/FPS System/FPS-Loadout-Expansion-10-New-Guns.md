# Change Log: Loadout Expansion — Ten New Weapons

**Date:** 2026-09-15
**Status:** Applied — built and structurally verified; in-game appearance not yet confirmed

## Summary
Turned ten raw imported gun meshes into fully working weapons: three rifles, five pistols and two shotguns, each with a handle, a welded world model, a first-person viewmodel with hands, sounds, animations, stats and a shop price. Fire modes and categories follow each weapon's real-world counterpart. Nothing in the shop or catalog needed changing — both already build themselves from whatever weapons exist.

## Changes
- `ServerStorage.Weapons` — ten new weapons: M14 EBR, AR-18 and HK G3 as rifles; APS, PB, MP443, Glock 17 and S&W 29 as pistols; Itacha Mag-10 and Benelli M4 as shotguns. Each carries its own stats, price and fire mode, and borrows sounds and animations from the established weapon of its category.
- `ReplicatedStorage.Blaster.ViewModels` — a first-person viewmodel per new weapon, each with its own mesh, its own welds and its own arm joints.

## Notes
- The APS is filed as a pistol on full automatic, which is what the real one is; the M14 EBR is semi-automatic only, matching the real marksman variant rather than the "auto or burst" default. Both were deliberate.
- The supplied build script could not be run as written. It called a bounding-box method that exists on models but not on individual parts, which would have failed every one of the ten — and failed only after the weapon had already been created and its raw mesh consumed, leaving a half-built weapon that a re-run would then skip. It was corrected before running.
- The same script's viewmodel step reproduced the exact fault that broke the baton. Copying a weapon's model does not redirect connections that point outside the copied part of the tree, so every new viewmodel's parts would have stayed attached to the world model's handle instead of their own body — measured as seven wrong connections on a single test copy, with none corrected. The viewmodel connections are now rebuilt explicitly against each viewmodel's own body.
- The reference weapons disagree about where their arm joints live and what they attach to: the rifle and shotgun attach the left hand to the body, while the pistol attaches it to the magazine, and each keeps those joints in a different place. Assuming one layout left five of the ten weapons with no arm joints at all and a duplicated body joint. Those five were rebuilt with layout-agnostic handling.
- The raw meshes are now copied rather than consumed, so the staging folder survives a failed build and the whole thing stays re-runnable. The folder can be deleted once all ten are confirmed good in game.
- Every new weapon was checked for the baton class of fault: no connection on any of the twenty new objects points outside its own weapon, and none is left dangling. Hand and grip placement is derived from each reference weapon by proportion, which is a best effort and cannot be confirmed from data — each weapon still needs looking at in first and third person.
