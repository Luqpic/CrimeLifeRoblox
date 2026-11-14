---
type: howto
tags: [howto, monetization, gamepass]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Gamepass-Shop-Scrolling-Grid.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Polish-And-Denied-Feedback.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-22-cosmetics-monetisation-design.md"]
---

# Add a Gamepass

A pass the Gamepass shop lists and the server checks. System: [[Gamepasses]].

Skills: `roblox-monetization`, `roblox-security`.

## Steps
1. **Ask the developer** for the pass id, price and icon. The developer creates the pass on Roblox; never invent an id.
2. **Add an entry** to `Monetization.Constants.Gamepasses` (key, `gamepassId`, price). An unset or placeholder id makes `Constants.isConfigured()` false and the tile reads COMING SOON.
3. **Gate on the server** with the player attribute `GamepassOwned_<key>`, set at join by the MarketplaceService check (the RPG verified this with nothing set by hand). Clients only read it. A pass bought mid-session flips the UI live.
4. **A gamepass weapon:** Tool attribute `Gamepass = "<key>"` and **no `Price`**. `WeaponShopService`'s BuyRequest requires `GamepassOwned_<key>` and charges 0; the Weaponary's Gamepass tab lists every Tool with a `Gamepass` attribute; the detail panel shows GAMEPASS · R$<price> (click prompts the pass) or CLAIM · FREE. See [[Add a Gun]].
5. **A Vip-style pass** for cosmetics: palettes with `source = "Vip"` check `GamepassOwned_Vip` ([[Add a Cosmetic Skin]]).
6. The `GamepassShop` grid is a ScrollingFrame, so another pass just adds a row.

## Files to touch
`Monetization.Constants`, the feature's server check, optionally a Tool's `Gamepass` attribute.

## Check
- Pass not owned: click refused, nothing granted. A crafted `BuyRequest` from the client is refused too.
- Ownership faked by setting `GamepassOwned_<key>` on the server in Play: panel flips to CLAIM, claim grants it.
- Grid: measure the canvas and the last card's edge against the window (nothing past the panel).
- The RPG currently uses a stand-in pass id owned by the developer (2026-09-24); it must be replaced with the real pass id before release. The Vip pass id was unconfigured at that time.

## Done before
[[FPS-RPG-Gamepass-Launcher]], [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]], [[FPS-Gamepass-Shop-Scrolling-Grid]], [[FPS-Shop-Polish-And-Denied-Feedback]], [[FPS-Monetization-Cosmetics-Spec]].
