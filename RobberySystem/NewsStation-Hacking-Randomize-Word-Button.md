# Change Log: NewsStation Hacking — Randomise Word Button

**Date:** 2026-09-12
**Status:** Applied (confirmed live in `Net.lua`)

## Summary
NewsStation's hacking puzzle (`MasterComputer.lua`) requires unscrambling 3 sequential anagram rounds drawn from a 24-word pool, with no way to skip a word a player got stuck on. Added a "Randomise Word" button giving 3 total re-roll chances shared across the whole attempt — not 3 per round — per an explicit design decision confirmed with the user before writing the prompt, since it materially changes puzzle difficulty (3 total vs. up to 9 across all rounds).

## Changes requested
- Server (`MasterComputer.lua`): track `randomizesRemaining` per attempt; a new `_onRandomizeRequested` handler swaps the current round's word (marking the old one used, so it can't resurface later in the same attempt) without advancing `roundIndex`.
- Networking (`Net.lua`): new `RandomizeWordRequested` remote + `OnRandomizeWordRequested` handler, following the file's established one-remote-per-event style.
- Client (`WordScrambleClient.lua`): new button reflecting the live remaining-count, disabled at 0.
- Tests: new `MasterComputerSpec` cases, including one pinning down "3 total, not 3 per round" specifically, since that's the behavior most likely to get silently reverted later.
- GUI: the new button had to be authored in Studio via `execute_luau`, per this project's established "no runtime `Instance.new()` for custom puzzle GUIs" convention.

## Confirmed outcome (as of this log)
`ReplicatedStorage.HeistShared.Remotes.RandomizeWordRequested` and `Net:OnRandomizeWordRequested` both exist exactly as specified, confirmed by reading `Net.lua` directly during a later prompt's research pass.

## Notes
- This was the first prompt in the series to require a direct clarifying question before drafting, rather than resolving ambiguity via a documented default — the difficulty-affecting fork was judged too consequential to guess.
