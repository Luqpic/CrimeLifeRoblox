# Player Nameplates, Level-Up Fix, MultiExport

**Place:** `FPS System.rbxl` · Follows `FPS-Figma-UI-Bugfix-Pass-5.md`

---

## Bug 7 — PVP nameplates + view-card prompt

New `StarterPlayer.StarterPlayerScripts.PlayerNameplates` (client-only).

**Nameplate.** A `BillboardGui` on every player's head in the Figma `EnemyGUI` treatment — display
name in white with a dark text stroke, a `#0E1016` track with a `#2A2F3C` hairline, a `#FF4B4B`
fill, and the remaining health right-aligned. Players and NPCs now read as one system.

**Roblox's default overhead UI** is suppressed with `Humanoid.DisplayDistanceType = None`. That is a
per-Humanoid property, so it is reapplied on every `CharacterAdded` rather than once at startup.

**View-card prompt.** Every *other* player's `HumanoidRootPart` gets a `ViewCardPrompt`
(`E`, 12 studs, no line-of-sight requirement). Triggering it fires
`ReplicatedStorage.UI.OpenPlayerCard`, a new `BindableEvent` that `PlayerCardController` answers by
calling `openCard(target)`.

The BindableEvent exists because `openCard` is a local function inside that controller's closure;
exposing it would mean restructuring the file. `/view <username>` already proved the card renders an
arbitrary player correctly, so the card side needed no changes at all.

Health is refreshed from both `HealthChanged` **and** `MaxHealth` — `HealthChanged` alone misses a
level-up's max-health increase and would leave the bar showing a stale fraction until the next hit.

### Verified

```
Humanoid.DisplayDistanceType = None                    PASS (Roblox default off)
nameplate name="SOLAR" health="100" fill=#FF4B4B       PASS
ViewCardPrompt count = 0 solo (none on your own char)  PASS (by design)
ReplicatedStorage.UI.OpenPlayerCard present            PASS
```

> **Not verified: the prompt itself.** A solo playtest has no second player, so no prompt is created
> — correctly, since you do not get one on yourself. The prompt-creation branch and the
> BindableEvent round trip have not been exercised against a real second client. Worth one two-player
> test.

## Bug 8 — level-up popup stuck on screen *(regression I introduced, twice over)*

Two separate causes, both mine.

1. Pass 5 added a `Caption` label. `LevelingHud` fades the popup by tweening the frame's
   `BackgroundTransparency`, the label's `TextTransparency` and the stroke's `Transparency` — the new
   caption was in none of them, so it never faded.
2. Pass 5 also set the template's `BackgroundTransparency = 0` and stroke `Transparency = 0` to match
   the Figma frame. **A template's property values are the clone's resting state**, so the panel and
   its acid outline were on screen from spawn. This is the identical mistake that put the death scrim
   over the HUD in pass 2.

Fixed at both ends: the template now rests fully transparent, **and** `LevelingHud` asserts all four
transparencies to 1 at startup so a future template edit cannot park the popup on screen again.
`popupLabel` now reads `LEVEL {n}` rather than `LEVEL UP! Lv. {n}`, since the caption says "LEVEL UP".

### Verified — full cycle, not just the rest state

```
rest:   bg=1.00 caption=1.00 label=1.00 stroke=1.00   PASS (invisible)
shown:  bg=0.20 caption=0.00 label=0.00 stroke=0.00   PASS (appears)
hidden: bg=1.00 caption=1.00 label=1.00 stroke=1.00   PASS (clears fully)
```

## MultiExport — already gone

Nothing to delete. `StarterGui.ScreenGui` and its 1,155 descendants had already been removed — you
did it yourself among your own changes. Confirmed: 0 instances named `MultiExport` anywhere in the
game, and **0 instances still pointing at `rbxassetid://0`**.

`StarterGui` now holds only `Bobbing Camera`, `Custom Inventory` and `QuestResponsesGui`.

## Pattern worth naming

Three bugs this conversation have the same shape: **a template's property value is the clone's
resting state, and every sub-element carries its own transparency that nothing else drives.** The
death scrim, the dialogue plate, and now the level-up popup twice. Styling a template to match a
Figma frame sets how it looks *when shown*; anything that fades needs its hidden state asserted in
code, for every part independently.

## Still open

- `ReplicatedStorage.UI.Theme` is still dead code — nothing requires it.
- Quest CLAIM/ACTIVE swap still unobserved in game (structure verified, no quest was claimable).
- Two-player test for the view-card prompt.
