# Change Log: XP on the Kill Toast, New Gun Icons, Experience and Health Icons

**Date:** 2026-09-24
**Status:** Applied. All four placements, the gun icons and the toast figures were verified live in play by
screenshot and readback; the place is not saved to disk by this change.

## Summary
- The Spraypaint kill toast now has a second line, directly under the Spraypaint text, giving the XP from
  the same kill with the Experience icon ("+30 Spraypaint" / "+70 EXP").
- The eight new guns have their shop and hotbar icons.
- The Experience icon is on every player-leveling readout: the XP bar, the level-up popup, the player
  card's XP row and the kill toast. The Health icon is on the player card's HEALTH row.

## Changes
- `ReplicatedStorage.Leveling.Constants` — `XP_ICON_ID`, `HEALTH_ICON_ID` (the single owner of both ids),
  and `totalXp(level, xp)`.
- `ReplicatedStorage.Modules.NotificationController` — `show(message, title, detail?)`. The optional
  `detail = { text, icon, iconColor? }` adds one icon-led line below the message, in the message's own
  font, and grows the card 64 → 84 px (it anchors bottom-right, so it grows upward). The line fades and
  re-seats with the rest of the card. Every existing call is unchanged.
- `StarterPlayer.StarterPlayerScripts.SpraypaintHud` — every Spraypaint/Level/XP change schedules one read
  0.1 s later, so one kill's separately replicated attributes land as one card.
- `StarterPlayer.StarterPlayerScripts.LevelingHud` — a 16 px icon left of the XP bar (tinted the bar's
  fill), and a 28 px icon beside "LEVEL N" on the popup (tinted its lime text) that fades with it.
- `ReplicatedStorage.GuiTemplates.PlayerCard` — `Icon` images in `HealthRow` (red, its bar colour) and
  `LevelRow` (blue, its bar colour); both labels moved 22 px right.
- `ServerStorage.Weapons.*` (8 new guns) — `TextureId` set; `Blaster/BuildNewPistolsShotguns.luau`
  carries the ids so a rebuild keeps them.

## Verification (play mode)
- Toast: a +5 Spraypaint / +70 XP grant that crossed Level 3 → 4 showed "+30 Spraypaint" / "+70 EXP".
  Both are exact: 5 plus the 25 level-up bonus, which lands in the same frame. Card measured 280 × 84,
  detail line 20 px below the message, icon 14 × 14.
- Level-up popup, XP bar icon, player card rows and both shop tabs (4 pistols, 4 shotguns with art)
  checked by screenshot. 0 client and 0 server errors or warnings (excluding the pre-existing
  unauthorized-sound noise).

## Notes
- **XP is derived, not sent.** The `XP` attribute resets on every level-up, so the raw difference reads
  as a loss on a levelling kill. The toast differences `Leveling.Constants.totalXp` instead, which is
  exact across any number of levels, with no new remote or attribute.
- **Disproved during verification: "the toast never fires."** The first two server-driven test cards were
  absent when checked. The cause was measurement: a card lives 4.2 s and the separate check calls
  arrived after it expired. Setting the attributes locally showed the card, and a server grant watched
  as it arrived confirmed it within the same second.
- The XP line appears only on the Spraypaint card. XP with no Spraypaint (a quest reward, a PvP kill,
  which pays no Spraypaint by design) adds no new toast.
- The icons arrived as 24 px black glyphs. They were re-exported white (so `ImageColor3` can tint them)
  and upscaled 4× nearest-neighbour to stay crisp at the popup's 28 px. Gun art was 2048 px and reduced
  to 1024 before upload, as in FPS-AK47-Display-Fix-11-New-Guns-Integration. All ten went through the
  short-lived 127.0.0.1 server with the user's permission; the server was stopped after the upload.
- The shop's blue LEVEL pill keeps its bullet icon on purpose: it is the weapon's upgrade level, not the
  player's.
