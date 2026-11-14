# Prompt: Add a "Randomise Word" Button to the NewsStation Hacking Puzzle (3 chances per attempt)

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Context, confirmed before writing this — read this first

NewsStation's hacking chain (`ServerScriptService.Heist.Components.MasterComputer`) is a server-authoritative "Criminal Word Scramble" puzzle, not literally Wordle: the player is shown an anagram of a hidden word and must type the real word. It requires **3 sequential rounds** (`ROUND_COUNT = 3`), each drawing a random, not-yet-used-this-attempt word from a **24-word pool** (`WORDS` — confirmed exactly 24 entries: THEFT, ALIBI, SUSPECT, WITNESS, EVIDENCE, BURGLAR, MOTIVE, ROBBERY, DETECTIVE, FELONY, VERDICT, GETAWAY, ARREST, WARRANT, CRIMINAL, SMUGGLER, HOSTAGE, RANSOM, FRAUD, FORGERY, TRESPASS, VANDALISM, KIDNAP, BRIBERY). Completing all 3 rounds ("breached") reveals a shared 4-digit code used by NewsStation's 3 `Safe` props. There is currently **no way to skip or change a word once assigned** and no penalty for wrong guesses — the only friction is a player being unable to unscramble that specific word.

Confirmed state shape (read directly from the code, not assumed):
- Per-player attempt state lives in `MasterComputer._attempts[player] = { roundIndex, currentWord, usedWords }`, created fresh in `_onTriggered` and cleared on exit (`_onExitRequested`), on full completion, and on `Seal`.
- `pickWord(usedWords)` already excludes anything in `usedWords` for that attempt — this is the exact mechanism to reuse so a randomized-away word never resurfaces later in the same attempt.
- The client (`StarterPlayer.StarterPlayerScripts.WordScrambleClient`) never receives the true word, only `scramble(word)` output, and the server independently normalizes/validates every guess (`_onSubmitGuess`) — this trust boundary must not change.
- **All puzzle GUI is pre-built in `StarterGui` and authored via `execute_luau`, never via runtime `Instance.new()` from the LocalScript** — this is an explicit, stated convention in this project (see `WordScrambleClient.lua`'s own header comment). The relevant GUI lives at `StarterGui.WordScrambleGui.MainFrame.PuzzleContainer`, alongside the existing `RoundLabel`, `ScrambledLabel`, `GuessBox`, `SubmitButton`, `FeedbackLabel`.
- `ServerScriptService.Heist.Tests.MasterComputerSpec` is a full, passing spec suite for this exact component (stubNet/tempModel/makeClock helpers already exist) — this is TDD-practicing code; add to this suite, don't work around it.

**Confirmed design decision (already settled — do not re-derive or change):** the player gets **3 randomize-chances total per hacking attempt**, shared across all 3 rounds combined (spending 2 on round 1 leaves only 1 for the rest of the attempt) — not 3 fresh chances per round. The budget resets only when the player exits and re-triggers a new attempt, or when a new heist session starts (`OnSessionStart`).

---

## What to build

### 1. Server — `MasterComputer.lua`

- When a fresh attempt is created in `_onTriggered`, add `randomizesRemaining = 3` to the attempt table alongside the existing fields.
- Add `MasterComputer:_onRandomizeRequested(player)`:
  - If there's no active attempt for this player, no-op (same guard style as `_onSubmitGuess`).
  - If `attempt.randomizesRemaining <= 0`, no-op — the server is the enforcement backstop even though the client should already disable its button at 0.
  - Otherwise: mark the current word used (`attempt.usedWords[attempt.currentWord] = true`) so it can't come back later this attempt, decrement `attempt.randomizesRemaining`, pick a new word via the existing `pickWord(attempt.usedWords)`, set it as `attempt.currentWord` and mark it used too. Do **not** touch `roundIndex`.
  - Push the new word the same way `_onSubmitGuess`'s round-advance branch already does: `self.net:OpenWordScrambleGui(player, { roundIndex = attempt.roundIndex, roundCount = ROUND_COUNT, scrambled = scramble(attempt.currentWord), randomizesRemaining = attempt.randomizesRemaining })`.
- Add `randomizesRemaining = attempt.randomizesRemaining` to the **other** two existing `OpenWordScrambleGui` call sites too (`_onTriggered`'s round-1 open, and `_onSubmitGuess`'s round-advance branch) — the remaining count needs to stay visible/accurate at every round transition, not just right after a randomize.
- Wire the new listener in `MasterComputer.new`, matching the existing `OnWordScrambleGuessSubmitted`/`OnWordScrambleExitRequested` pattern: `self.net:OnRandomizeWordRequested(function(player) self:_onRandomizeRequested(player) end)`.

### 2. Networking — `Net.lua` + a new RemoteEvent

- Read `ServerScriptService.Heist.Services.Net` first to see exactly how `OnWordScrambleExitRequested` (a no-payload client→server request) is implemented, and mirror that pattern precisely for a new `OnRandomizeWordRequested`.
- Create a new `RemoteEvent` named `RandomizeWordRequested` under `ReplicatedStorage.HeistShared.Remotes`, parented and named consistently with its siblings (via `execute_luau`, not left for the LocalScript to create).

### 3. Client — `WordScrambleClient.lua`

- `WaitForChild` a new `randomizeButton` under `puzzleContainer` (built in Studio per the ground rule above — style it to match `SubmitButton`: read `SubmitButton`'s actual properties via `inspect_instance` first and match its font/colors/corner radius rather than guessing new values).
- Track the current `randomizesRemaining` from every `OpenWordScrambleGui` payload (all three server call sites now send it) and reflect it directly in the button, e.g. `randomizeButton.Text = string.format("Randomise Word (%d left)", remaining)`; disable it (`.Active = false` + the same dimmed-appearance convention this file already uses via `setInputEnabled`) once `remaining <= 0`.
- On `randomizeButton.Activated`, guard on the button actually being enabled (don't fire while at 0), then `FireServer()` on the new remote — no payload, matching `exitRemote`'s call shape.
- Do this inside/alongside the existing `openRound(payload)` function so every round-open, round-advance, and randomize event updates the button consistently from one seam, rather than a second parallel handler.

### 4. Tests — extend `MasterComputerSpec.lua`

Reuse the existing `stubNet`/`tempModel`/`makeClock` helpers exactly as they are. Add:
- Requesting randomize with chances remaining swaps to a different, previously-unused word; decrements `randomizesRemaining`; leaves `roundIndex` unchanged.
- The randomized-away word never resurfaces later in the same attempt (simulate several randomizes + round advances, assert against `usedWords`).
- Requesting randomize at `randomizesRemaining == 0` is a no-op: no new net call fires, `currentWord`/`roundIndex` unchanged, no error.
- `randomizesRemaining` resets to 3 on a fresh `_onTriggered` (both a brand-new attempt and after exit-and-retrigger), and is tracked independently per player.
- Spending randomizes on round 1 leaves fewer available in round 2/3 of the *same* attempt (proves the "3 total, not 3 per round" semantics — this is the one behavior most likely to get silently reverted by a future change, so pin it explicitly).

---

## Verification checklist

- [ ] Full existing spec suite (`TestRunner`/`RunAll`, including the new `MasterComputerSpec` cases) passes.
- [ ] Play-test at NewsStation: trigger the hack, click Randomise repeatedly — counter reads 3 → 2 → 1 → 0, button visibly disables at 0, the scrambled word changes each click without advancing the round counter.
- [ ] A word declined via Randomise does not reappear later in the same attempt, across all 3 rounds.
- [ ] Completing all 3 rounds (with or without having used any randomizes) still reveals the code exactly as before.
- [ ] Exit mid-attempt, re-trigger: counter is back to 3.
- [ ] A second player hacking the same MasterComputer in the same session has their own independent counter.
- [ ] Nothing about the Bank, SlowFoods, or Gas2Go hacking/robbery flows is touched — this component and its GUI are NewsStation-exclusive.
- [ ] No new sound, and no new remote beyond `RandomizeWordRequested`, was introduced beyond what's specified above.
