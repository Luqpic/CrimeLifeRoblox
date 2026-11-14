---
type: howto
tags: [howto, ui, notifications]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/FPSSystem/Cosmetics/NotificationController.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Queue-While-Panel-Open.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Card-Fix-And-Weapon-HUD-Move.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Blank-Card-ZIndexBehavior.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons.md"]
---

# Add a Notification

A new toast in the bottom-right card stack (FPS place). System: [[Notifications]].

Skills: `roblox-ui`.

## Steps
1. **Call the one module** from a client script: `ReplicatedStorage.Modules.NotificationController.show(message, title?, detail?)`. `detail = { text, icon, iconColor? }` adds one icon-led line under the message (the card grows 64 -> 84 px). Do not build a second toast.
2. **Server events reach the client as replicated attributes** on the player (`Spraypaint`, `Level`, `XP`, `Quest_<id>_Completions`); a client controller watches them and calls `show`. When one event changes several attributes, debounce (`SpraypaintHud` reads once, 0.1 s after the first change) so it lands as one card.
3. Leave queueing alone: while `UI.Panels.current()` is set, cards queue (cap 8, oldest dropped) and flush 0.12 s apart when the panel closes.
4. Existing callers to copy: `QuestFeedbackController`, `SpraypaintHud`.

## Files to touch
The calling client controller only.

## Check
- Drive it through a real event (change the attribute on the server in Play, or a real click), never by calling `show` from `execute_luau`: that `require` builds a separate module instance and draws a GUI nobody sees.
- With a panel open: no card; after closing: cards arrive in order.
- If a card renders blank, suspect `ZIndexBehavior` (Global sorts by absolute ZIndex), not transparency.

## The Robbery place
Robbery has its own global robbery notifications and location status billboards ([[Robbery Heists and Getaway]]). They are a separate system; do not route FPS toasts into them.

## Done before
[[Notification-Card-Fix-And-Weapon-HUD-Move]], [[Notification-Queue-While-Panel-Open]], [[Notification-Blank-Card-ZIndexBehavior]], [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]], [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]], [[Global-Notifications-And-Location-Status-Billboards]].
