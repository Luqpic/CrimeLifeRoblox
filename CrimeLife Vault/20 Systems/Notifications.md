---
type: system
tags: [system, ui, notifications]
updated: 2026-11-18
sources: ["CrimeLifeRoblox/FPSSystem/Cosmetics/NotificationController.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Feedback-NPC-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-5.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Card-Fix-And-Weapon-HUD-Move.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Queue-While-Panel-Open.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Blank-Card-ZIndexBehavior.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Global-Notifications-And-Location-Status-Billboards.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/UI-Bug-Fixes-Notification-HUD-Lockpick-Titles.md"]
---

# Notifications

**Skills:** `roblox-ui` (load this for work here)

## What it does
Toast cards for gains and events: quest completion, Spraypaint gains, and the kill toast ("KILLED SABOTEUR" / "+2 Spraypaint" / "+20 EXP"). Cards stack bottom-right like a pile (max 3 visible), and queue while a panel is open. The heists have their own global notifications for location reopen / robbery triggered. In the city **two notification styles are on screen**: the city's bottom-right stack (`NotificationController`, [[Quests and Dialogue]]) and the heist cards (`HeistNotificationGui`); unifying them is open ([[Open Items]]).

## Where it lives
- `ReplicatedStorage.Modules.NotificationController` (mirror: `CrimeLifeRoblox/FPSSystem/Cosmetics/NotificationController.luau`).
- `ReplicatedStorage.GuiTemplates.Notification` (`AccentEdge`, `TitleLabel`, `MessageLabel`).
- Callers: `StarterPlayerScripts.QuestFeedbackController` ([[Quests and Dialogue]]), `StarterPlayerScripts.SpraypaintHud` ([[Spraypaint]]); kill name from `ReplicatedStorage.Blaster.Remotes.KillConfirmed`.
- Heists: `StarterGui.HeistNotificationGui` (renamed from the Robbery place's `NotificationGui` on 2026-11-16 because the city already has a `NotificationGui` container; `NotificationTemplate` with `Header`/`Body`), `StarterPlayerScripts.NotificationClient` (waits `HeistNotificationGui`; `INSET_Y` 108 so its stack's bottom sits on the top edge of the city container, measured card bottom 551 = container top 551), `UiButtonEffects` (its two panel references renamed), remotes `LocationOpened` / `RobberyTriggered` in `Net.lua`.

## How it works
- API: `NotificationController.show(message, title?, detail?)`. `title` defaults to `"NOTICE"`; `message` is `string | Line`, `detail = { text, icon, iconColor? }` adds one icon-led line and grows the card 64 -> 84 px upward.
- Card 280x64, `HOLD_TIME` 4 s, `MAX_VISIBLE` 3 (oldest evicted), `RIGHT_MARGIN` 20, `BOTTOM_MARGIN` 24. Each older card sits 10 px higher and 14 px narrower each side, dimmed 0.3 / 0.6; text and background share one `dim` value.
- No `UIListLayout`: the stack is positioned by hand so re-seat tweens are not overwritten.
- Its `ScreenGui` is built once per client with `ZIndexBehavior = Sibling` and its own `UIScale` (`Scale = 1`) so `UIScaleController` skips it.
- While `UI.Panels.current()` is non-nil, `show` queues (cap 8, oldest dropped); on close the queue flushes 0.12 s apart; a reopen mid-flush cancels the flush.
- `SpraypaintHud` batches one kill's separately replicated attributes into one card (one read 0.1 s after a change); XP is derived from `Leveling.Constants.totalXp`, not sent. Several kills at once read "KILLED BANDITS ×3"; a Spraypaint gain with no kill keeps "SPRAYPAINT".

## Extend it
- New caller: just `require` and `show`; the module table is shared per client. Use `detail` / `Line` for icons.

## Watch out
- Under `ZIndexBehavior.Global` a card's background drew over its own text (blank card).
- A layout owns the position of what it stacks; animating a stacked item does nothing.
- `execute_luau`'s own `require()` builds a separate module instance with its own `NotificationGui`; drive tests through real attribute changes or clicks.
- Fire and poll in a single `execute_luau` call: a card lives about 4.2 s and separate calls miss it.
- Same-frame `SetAttribute` calls coalesce (one "+78" card instead of 12); yield between test writes.
- Do not destroy the module's cached `NotificationGui` while probing; it broke live notifications once.
- Writing the same attribute from Server then Client `execute_luau` in one session threw `Unable to cast Font to Font` and ended Play.

## History
- 2026-11-17: `Net` remote `BroadcastHijacked` and a `NotificationClient` listener show a city-wide card "<name> hijacked the News Station broadcast!" on the existing heist template. [[2026-11-17 Heist Layers]]
- 2026-11-16 (city): Robbery's `NotificationGui` renamed `HeistNotificationGui`, its stack moved clear of the city's. [[2026-11-16 Robbery Systems Into City]]
- 2026-09-24: kill toast titled "KILLED <Name>". [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]]
- 2026-09-24: icons on both toast lines (`message` accepts `Line`). [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- 2026-09-24: XP detail line on the Spraypaint toast. [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]]
- 2026-09-24: blank card fixed with `ZIndexBehavior.Sibling`. [[Notification-Blank-Card-ZIndexBehavior]]
- 2026-09-23: queue while a panel is open. [[Notification-Queue-While-Panel-Open]]
- 2026-09-23: card 420x100 -> 280x64, own `UIScale`, receded-card text/background coupled. [[Notification-Card-Fix-And-Weapon-HUD-Move]]
- 2026-09-23 or earlier: moved to a bottom-right stacked-card pile. No separate change log for this move; it is referenced by [[Notification-Queue-While-Panel-Open]].
- 2026-09-18: slides from top-centre. [[FPS-Figma-UI-Bugfix-Pass-5]]
- 2026-09-18: rebuilt to Figma absolute layout, optional title. [[FPS-Figma-UI-Bugfix-Pass]]
- 2026-09-18 (Robbery): slice scale corrected, body text measured. [[UI-Bug-Fixes-Notification-HUD-Lockpick-Titles]]
- 2026-09-16: first notification (bottom-left) for quest hand-in. [[FPS-Quest-Feedback-NPC-Polish]]
- 2026-09-12 (Robbery): global notifications. [[Global-Notifications-And-Location-Status-Billboards]]

See [[Batch Log]].
