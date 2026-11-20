---
type: reference
tags: [reference, pipeline, animation, viewmodel, blender]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/ViewmodelAnimations/README.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-KeyframeSequence-Export.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-Animation-Linear-Easing.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Viewmodel-Hands-Off-Weapon.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Melee-Viewmodel-Swing.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Fall-Animation-Dead-Asset.md", "docs/GUIDE-Walker-Animation-Pipeline.md §0-§5, §7", "Roblox-Claude-Workflow.md §10.2"]
---

# Animation Pipeline

Two routes. **Route A** is what CrimeLife actually runs: first-person viewmodel motion authored in code, with an export to editable KeyframeSequences. **Route B** is the generic Blender rig-and-clip pipeline carried over from another project; it is **not yet used in CrimeLife** and is kept here so the method is ready when a character, enemy or NPC clip is needed. Recipe: [[Add a Viewmodel Animation]]. Systems: [[Viewmodels and Weapon Animation]], [[Melee]], [[Movement and Stamina]].

## Where CrimeLife's animation comes from today

| What | Source |
|---|---|
| Viewmodel equip, carry, recoil, reload, melee swing (28 weapons, 2026-09-20) | Procedural Motor6D motion in `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` |
| Viewmodel shipped `Animation` assets | Inert: 28 viewmodels share 11 `AnimationId`s across three generic kits (rifle on 19, pistol on 7, melee on 2). Kept for rollback |
| Melee swing in first person | Code: the rigid-body arc in `ViewModelController` (no uploaded clip) |
| Character locomotion | `StarterCharacterScripts.Animate2` with asset ids; dead fall and climb assets were replaced by Roblox's default R15 clips on 2026-09-19 |
| Enemy and character weapon clips | Existing asset ids on the templates and Tools |

## Route A: viewmodel motion (CrimeLife)

### The rig
`ReplicatedStorage.Blaster.ViewModels.*` are `Root -> Body -> {Magazine, RightArm, ChargingHandle}`, with `LeftArm` under `Magazine` on magazine-fed weapons and under `Body` on melee and shotguns. They carry an `AnimationController` and `Animator`, no `Humanoid`, and are separate from the character rig. Arms are whole (no elbow or wrist joints); revolvers have no cylinder joint. Extra moving pieces are joints the build script adds (`Body -> Pump`, `Body -> Round`). Viewmodels are built by the re-runnable build script with a donor-skeleton swap ([[Add a Gun]]).

### Steps
1. **Classify the weapon** by mechanism, not shop category: `rock`, `rifle`, `bullpup`, `top`, `pistol`, `revolver`, `shell`, `pump`, `melee` (the `profiles` table).
2. **Author in code** in `WeaponViewmodelMotion`: per-weapon profile, `showcase` carry and grip poses (AK47, Glock 17, Mossberg 590 approved; the rest inherit their family's), reload tracks, three melee swing poses. Timings come from Tool attributes (`reloadTime`, `swingDelay`), never hardcoded.
3. **Keyframes are linear** through the single `ease(t)` hook. Aim, sprint and move blends and the critically damped recoil spring are not keyframes and stay as they are.
4. **Sway is pivot-level:** idle breathing, walk bob, sprint lean and ADS offset come out of `Motion:step` as one pivot offset that `ViewModelController` applies with `PivotTo`. Never bake them into joint clips.
5. **Hands on the weapon:** `Motion.new` cancels each hand's off-plane drift by walking the Motor6D chain (`C0 * C1:Inverse()` per hop) into weapon-body space. A weapon that still reads wrong needs a per-weapon grip marker, not more inference.
6. **Test numerically** ([[Unit Test Runner]]): `WeaponViewmodelMotion.spec` (7,102 assertions on 28 rigs), `WeaponClassMotion.spec` (27 class and grip checks), `ScopeAlignment.spec`, `MeleeStability.spec`; plus a live smoke test (equip, attack, reload and cancel, aim, third-person toggle, destroy).
7. **Export for editing:** `FPSSystem/ViewmodelAnimations/ExportKeyframeSequences.luau` rebuilds `ServerStorage.ViewmodelKeyframeSequences` from the live module (49 sequences: one class representative per folder, plus AK47, Glock 17, Mossberg 590 by name). All poses Linear, weight 1; firearm Shoot is the recoil spring resampled (60 Hz integrate, 30 Hz keys); `KeyframeMarker`s `MagOut`, `MagIn`, `Charger` at the sound cues. Faithfulness check: interpolate between keys and compare with the live module (worst 0.00028 studs on 2026-09-20).
8. **Edit in the Animation Editor:** the editor binds only to rigs in Workspace and loads only from the rig's `AnimSaves` **ObjectValue**. Staged rigs live in `workspace.ViewmodelAnimationRigs` (twelve, root part anchored only, CanCollide off), each with its clip set copied into `AnimSaves`. Re-running the exporter rebuilds the master only; refresh the copies too.
9. **To go asset-driven** (not done): publish each KeyframeSequence (Save to Roblox, a person, because the Studio MCP cannot upload animations), paste the ids into each viewmodel's `Animations` folder, then restore the two controllers in `FPSSystem/ViewmodelAnimations/baseline/`. Re-author against the nine classes, not the 28 weapons. Sway stays procedural either way.

### Traps
- **Edit-mode module cache serves the stale module.** Tooling that requires a module it just edited must clone-require it, or it measures and exports old behaviour (cost a full diagnostic cycle).
- The melee `Reload` slot is dead: `Motion:reload` returns early for melee and both melee Tools have `reloadTime = 0`.
- A missing `profiles` entry makes `Motion.new` assert and first person never starts.
- Synthetic mouse input does not reach Studio here: a swing proven on a timeline still needs one real click.

## Route B: Blender rig and clips (generic, not yet used in CrimeLife)

The method from another project's guide (`docs/GUIDE-Walker-Animation-Pipeline.md`, `Roblox-Claude-Workflow.md` §10.2). Its rig-specific sections and its project's group, ids and places do not apply here. Before first use, record CrimeLife's own: the animation place, the owning group, and where the Open Cloud key lives (never print it). None of these is recorded for CrimeLife yet.

### Two delivery routes
| | Plain R15 rigs (most characters and enemies) | Rigs built from many parts or badly welded accessories |
|---|---|---|
| Ships as | Animation ids only, pasted into the existing models | A hybrid model: the part rig kept and hidden, a skinned mesh and bones on the HumanoidRootPart, one clip drives both |
| Death | Ragdoll ([[Ragdoll]]) | A death clip, then swap back to parts and ragdoll |

### Steps (headless Blender, `B=/Applications/Blender.app/Contents/MacOS/Blender`)
1. **Start of session:** `list_roblox_studios`, pick the animation place by name, `get_studio_state`; if the developer is in Play, wait. Ask open questions with the picker (personality, route, which actions).
2. **Rig what should move:** an Accessory is welded and will not animate; add a `Motor6D` and disable its `AccessoryRigidConstraint`.
3. **Dump the rig** (a Luau script writes every joint's C0/C1 and part sizes to `rig.json`).
4. **Export geometry:** select only the rigs, right-click > Export Selection as OBJ. Never File > Export as .obj on a big place: it hangs Studio for good.
5. **Build** the skinned rig (OBJ groups matched to parts, skinned rigidly to bones, materials merged); keep a `.rest.blend`.
6. **Animate by script, one style per personality.** A new character is a new style or a rig option, never a forked engine; shared fixes go in the shared library.
7. **Check with numbers, then preview** (an mp4 per clip on a lazy-loading `index.html`) and wait for the developer's OK before upload.
8. **Export and package** as KeyframeSequences in `.rbxmx`; name clips `<RigName>_<Action>`.
9. **Upload** through Open Cloud under the game's owner; record every id. A changed clip is a new version of the same id.
10. **Test in Studio Play:** tracks load (`Length > 0`), feet on the floor, attack hit time correct. Wait a minute after an upload.
11. **Record** the id table and mapping in a vault note, plus any new trap.

### Clip rules (measure, do not eyeball)
- Faithful to the original rig, one to one. Smooth: eased moves and a light smoothing pass; worst joint move about 35° per frame or less.
- Every one-shot starts and ends on the idle's first pose; loops are seamless.
- Feet flat on the floor in planted moves (0.00 above the floor), unless the character floats by design; no vertical bob in planted moves.
- Attacks move the upper body only. Walk speed matches WalkSpeed, measured on the planted foot's mesh, not the ankle bone.

### Generic traps
- Never pose a template in Edit (`Animator:StepAnimations`); pose a throwaway clone. Setting `Motor6D.Transform` to identity in Edit does not move parts back; play a one-keyframe identity clip.
- A just-loaded track reads `Length` 0, Priority Action and Looped false until the asset loads: wait for `Length > 0`, set priority and looping in code by clip name. A dead asset stays at `Length` 0 forever (CrimeLife's fall and climb).
- `KeyframeSequenceProvider:RegisterKeyframeSequence` ids work only while the sequence stays referenced.
- A fresh upload fetched too early is cached empty; start a new Play.
- Studio de-duplicates mesh uploads by content: nudge a vertex to force a new upload. A skin texture can load and still draw blank: screenshot every hybrid.
- An avatar's leg length is not its `HipHeight`. `Humanoid.MoveDirection` reads 0 under `MoveTo`: gate "moving" on root velocity.
- Explicit springs explode at low frame rates (an unfocused Studio runs at about 15 fps): integrate in fixed substeps. CrimeLife met the same frame-time amplification in [[FPS-Landing-Jolt-Root-Cause]].
- Never keep a backup folder where the upload script globs for clips; read each uploaded asset back before handing ids over.
- Render at most three Blender jobs in parallel; Blender 5 has no FFMPEG image format (render PNG frames, encode with ffmpeg).

**CrimeLife's first Route B clips (2026-11-20):** `Crime*` in `Blender/_pipeline/animate_player.py` on the OBT player rig; the city plays group 4998611's `Player_*` clips (ids in `Blender/_enemies/ids.json`). Upload with `upload_anims.py 4998611 --prefix Player_Crime`; the first try was refused (403: the key's account may not create Animation assets for the group). Ids live in `ReplicatedStorage.Combat.Clips`. [[2026-11-20 Interaction Animations and Takedown Prompt]]

Related: [[Blender Pipeline]], [[Trailer and Cinematic Pipeline]].
