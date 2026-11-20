---
type: batch
tags: [batch, city, animation, robbery, combat, blender]
updated: 2026-11-20
sources: ["[[2026-11-20 Combat Bugs Interaction Animations Takedown Prompt]] (parts 4 and 6)", "Play checks, 2026-11-20 late evening", "Blender/_pipeline/animate_player.py (Crime section)", "CityMerge/after-import.md ('Interaction animations and takedown prompt 2026-11-20')"]
---

# 2026-11-20 Interaction Animations and Takedown Prompt

Parts 4 and 6 of [[Current Work]]'s late-evening request. Built natively. **The five new clips are made but not uploaded** (see Blocked).

## Asked for
- "Add animations for robbing the cash register, using teh safe, hacking teh computer so otehr players can see you interact with them" (picker: "Every interaction"; "Upload straight away").
- "There should be a prompt to silent take down if possible (add animation for takedown)" (picker: "Prompt + chokehold"; when spotted mid-takedown: "It still finishes").

## What changed
- **New clips** (Blender, OBT player rig, a new `--only` section in `Blender/_pipeline/animate_player.py`; packaged as `Blender/_enemies/Player/Player_Crime*.rbxmx`):
  - `CrimeRegister`: 30 f loop, hands take turns grabbing from a drawer.
  - `CrimeType`: 24 f loop, typing at a desk.
  - `CrimePickUp`: 24 f, a squat and lift.
  - `CrimeChoke`: 48 f = 1.6 s, the attacker's chokehold.
  - `CrimeStagger`: 15 f, an enemy's headshot stagger.
  - Checks: worst joint move 1.4 to 30.6 degrees a frame (rule: 35 or less; the first choke had 37.2 and its release was lengthened), loops close exactly, feet never below the idle's floor height.
  - `Player.blend` was backed up as `Player.before_crime.blend`. The split step rewrote every `Player_*.rbxmx`, so the old ones were restored from a scratch backup: they are byte-identical to before, and only the five new files are new.
- **`ReplicatedStorage.Combat.Clips`** (new): every combat and robbery clip id in one place, plus uses with fallbacks.
  - Uploaded group clips used now: `Choked` 84852849800147 (the takedown's victim), `RepairKneel` 121944371724979 and `RepairLoop` 90730140087815 (kneeling work), `DeviceBrowse` 115684067438169 (stand-in for grabbing and typing until those upload).
  - The `Crime*` ids are left blank until the upload.
- **`StarterPlayerScripts.InteractionAnimations`** (new LocalScript): the clip plays on the player's own character, so everyone sees it.
  - While a robbery prompt is held, picked by its ActionText:
    - Rob register, Rob ATM machine, Rip Out ATM, Steal Supplies: Register.
    - Crack Safe, Attach C4, Pick Lock, deposit: kneel down, then the kneeling loop.
  - While a minigame is open: `LockpickGui` keeps the kneel; `HackCodeGui` and `WordScrambleGui` play Type.
  - A one-shot PickUp on "Pick Up ..." and "Steal Supplies".
- **Takedown prompt:** `CombatActions` puts a client-side ProximityPrompt "Takedown" (ObjectText "Silent", E / pad X / tap, no hold) on the back of the enemy it would take down. The crosshair hint now shows FINISH only.
- **Chokehold:** `Finishers` takes the takedown in 1.6 s:
  - The enemy is stunned, and both roots are anchored with the player 1.6 studs behind, facing the same way.
  - The enemy plays `Choked`, the player plays `CrimeChoke` once uploaded.
  - The kill and the +50 % bonus land at the end, even if another enemy sees it.
  - `TakenDown` and `TakingDown` attributes stop a second takedown meanwhile.
- **`HitReaction`:** a headshot stagger plays `CrimeStagger` once uploaded (until then, the stun as before).

## Verified (Play)
- **Takedown:** crouched behind a stunned, unaware Smuggler (85 HP): the prompt sat on its HumanoidRootPart and the hint stayed hidden. E: both anchored from 0.8 to 2.1 s, the enemy played `Choked` (84852849800147), then died (0 HP) and both were released.
- **Register:** during a SlowFoods robbery, holding E on "Rob register" played the Register use (its stand-in `DeviceBrowse`, looped, weight 1); releasing E stopped it.
- City 394 / 394 / 0; heist 764 passed / 0 failed. Edit read-back: the 5 scripts match their mirrors; no test leftovers.

## Uploaded (2026-11-20, on the developer's "check again")
The upload went through on the second try (the key's permission had been fixed):
- `CrimeRegister` 86275032162106
- `CrimeType` 94136719654492
- `CrimePickUp` 96438680246946
- `CrimeChoke` 123284190249472
- `CrimeStagger` 119918548663254

They are in `ReplicatedStorage.Combat.Clips.ids` (2,688 / 619078488). Play, place version 69:
- All five load on the client with the right lengths (0.5 to 1.6 s).
- The register hold plays CrimeRegister (looped, weight 1).
- The takedown plays CrimeChoke (1.6 s) on the player and Choked on the Offender, which then died.
- A headshot reaction (`HitReaction.react`, live) plays CrimeStagger on the enemy. Its first play on that enemy read length 0, still downloading.
- 12 real AUG shots aimed at an enemy's head made no headshot: the ray stops on its hat or hair (not `Head`).

## Blocked (first try, resolved)
**Upload refused:** Open Cloud answered 403 PERMISSION_DENIED, "unauthorized to create an Animation asset as Group 4998611". The key in `~/.roblox_key` belongs to an account that may not create Animation assets for the group. Under the scope rule, the developer fixes it: a group API key with Assets read and write, or that permission for the key's account. Then:
1. `python3 Blender/_pipeline/upload_anims.py 4998611 --prefix Player_Crime`
2. Put the five ids into `ReplicatedStorage.Combat.Clips.ids` (CrimeRegister, CrimeType, CrimePickUp, CrimeChoke, CrimeStagger) and into the mirror.

## Not verified
- The kneel clips at a safe, a lockpick or C4, and the minigame hold (same mechanism as the register).
- How the stand-in clips look at a register.
- The takedown seen from a second player.
- The new clips in the game, since they are not uploaded.

## Saved
Studio saved to Roblox (version 68, Save, never Publish). NOT published. Nothing pushed.

## Links
[[Animation Pipeline]] · [[Robbery Prompts]] · [[Enemies and Spawner]] · [[Melee]] · [[2026-11-20 Combat Feel]] · [[Current Work]]
