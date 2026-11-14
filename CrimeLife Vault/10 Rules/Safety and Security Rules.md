---
type: rule
tags: [rule, security, safety, data]
updated: 2026-11-14
sources: ["OBT Vault/10 Rules/Safety and Security Rules.md (adapted)", "CrimeLifeRoblox/FPSSystem/Persistence/ProfileGateway.luau", "docs/superpowers/plans/2026-09-23-persistence-phase-3.md", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "70 Batches/Robbery System/Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades.md"]
---

# Safety and Security Rules

## Rule

- **No secrets anywhere.** No Open Cloud key, Figma token, API token, cookie or webhook URL goes into the vault, a report, a log, a commit or a script. Keys stay in their files (for example `~/.roblox_key`) and are never printed.
- **Test saves only against the ProfileStore Mock.** `ProfileGateway.useMockStore()` swaps in `ProfileStore.New(STORE_NAME, Schema.template).Mock` and is ignored outside Studio. Never read or write production DataStores from a session.
- **Never pass `Steal = true`** for a player load: it bypasses the session lock that prevents duplication ([[Persistence and Saves]]).
- **`ServerStorage.ProfileStore` is vendored third-party code. Never edit it.**
- **`ServerScriptService.UnitTestRunner` stays `Disabled`.** If it ran at server start, `ProfileGateway_Test` would call `useMockStore()` mid-session and repoint the live store, so any round trip measured afterwards measures a different table ([[FPS-Persistence-Phase-3]], [[Unit Test Runner]]).
- **The server is the authority.** A client panel is never trusted: guard prompts and remotes on the server, not by hiding them on the client ([[Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades]]). `ShotResolver` is server authority for hits, knockback and stun.
- **Free models and Creator Store inserts go to a review folder first.** Insert into a folder in `ServerStorage` (scripts do not run there), list every `LuaSourceContainer`, read each one, keep only what you need. For clothing and accessories prefer Roblox's own catalog items.
- **Never write a check that sends anything outward** (webhooks, HTTP posts to outside hosts).

## Why

- Persistence phase 3 ([[FPS-Persistence-Phase-3]]) built the save layer on ProfileStore with every test on the Mock store, "which operates on a fake DataStore forgotten at server shutdown"; the plan forbids `Steal = true`.
- On OBT (same developer, same Mac) free-model packs carried hidden malicious scripts more than once (a `CoreValidation` script, a `Runtime` script under a SurfaceAppearance, an obfuscated `require`). The review rule is carried over as-is.
- [[Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades]]: "the client panel is not authoritative and a second client could still fire the remote."

## How to apply

- Before any insert: review folder, script list, read each script, then move the asset.
- Before ending a batch: no test objects left in StarterGui or Workspace; the UnitTestRunner still Disabled.
- Remote and economy work: load `roblox-security` ([[Roblox Skills]]).
