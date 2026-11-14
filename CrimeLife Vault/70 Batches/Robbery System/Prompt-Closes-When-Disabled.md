# Change Log: Prompt Face Closes When Its Prompt Is Disabled

**Date:** 2026-09-19
**Status:** Applied (confirmed live)

## Summary
Pressing a Bank Heist button left its prompt on screen. The button had already done its job -- its
white highlight was gone -- but the "E" stayed floating in front of it.

## Cause
**Disabling a ProximityPrompt that is currently on screen does not fire `PromptHidden`.**

The custom face is created on `PromptShown` and destroyed on `PromptHidden`, so a prompt the game
switches off mid-display never gets the close signal and its billboard is simply left behind. The
evidence was already on record from an earlier session: a live billboard was observed adorned to
`Bank.Button2.Part` while that prompt read `Enabled = false`.

## Changes
- `PromptUiController` -- while a face is up, the prompt's own `Enabled` flag is watched. When it
  goes false the face fades out and destroys itself, exactly as it would on `PromptHidden`. The
  watch is torn down on hide, so it cannot outlive the face it belongs to.

## Notes
- Verified live: with the face on screen, setting `Enabled = false` left 1 billboard mid-fade and 0
  once the fade completed. Previously it stayed at 1 indefinitely.
- This is general, not Bank-specific -- any prompt the game gates by `Enabled` gets the same
  behaviour.
