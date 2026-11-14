---
type: reference
tags: [reference, research, tycoon, retention, market]
updated: 2026-11-14
sources: ["Web research run 2026-11-14 (source URLs at the foot of this note)"]
---

# Tycoon Market Research 2026-11

What keeps players in Roblox tycoon-type games in 2025 to 2026, researched on 2026-11-14 to shape CrimeLife Tycoon. The product calls made from it are in [[CrimeLife Tycoon Decisions]].

**Read this first.** Roblox's own pages (Creator Hub, newsroom) are solid. Concurrent-player figures come from tracker blogs (RoWatcher, StudioKrew) that contradict each other, so treat every player count as an order of magnitude. RoMonitor and Rolimons were not reached and no developer post-mortem was found. Lines marked *inference* are a reading of the evidence, not a source's claim.

## What Roblox's recommendations reward (confirmed)

From the Creator Hub discovery page and the June 2026 newsroom post. Only players who arrive from Recommended For You are counted.

| Weight | Signal |
|---|---|
| Most important | Play-through rate |
| Most important | First-play bounce (negative; measured under 60 s and 61 to 180 s) |
| Most important | Play days per user at D1, D2 to D7 and D8 to D28 |
| Most important | Playtime per user (capped at 60 minutes per user per day) |
| Important | Intentional co-play days per user (friends joining by join, invite or private server) |
| Important | Qualified play sessions per user |
| Important | Spend days per user, Robux per user |

- The retention window grew from 7 to 28 days in 2026.
- Benchmarks: the top 10% of similar games have D1 at or above 24.1% (Roblox's one published example). Unofficial rules of thumb: D7/D1 above 0.5 and D30/D7 above 0.4.
- No source gives the size of the effect of crews, trading, daily streaks, battle passes or notifications. Measure them with A/B tests instead of assuming.

## What the hits do

| Game | Peak (tracker figures) | Loop |
|---|---|---|
| Grow a Garden | 22.3M (Aug 2025) | Plant, wait in real time, harvest, sell, buy better seeds. Offline growth and timed restocks bring players back; trading is the social layer (*inference*). |
| Steal a Brainrot | 25.8M (Oct 2025), now about 150K to 215K | Units on your base earn passively. Raid other bases and carry the stolen unit out slowly while the owner is alerted and can hit you to take it back. Rebirths. Weekly updates. |
| Escape Tsunami For Brainrots | about 5M (Jan 2026), now about 164K | Collect before a wave resets the map. |
| Classic tycoons (Theme Park Tycoon 2, Retail Tycoon 2) | 5K to 15K each | Build and manage; small but steady. |

- Each event-driven spike fell harder than the last. The games that hold are the ones updated every week (RoWatcher).
- Evergreens (Brookhaven, Adopt Me, Blox Fruits) hold steady without spikes and add customisation or role play, not only bigger numbers.

## Durable patterns

1. Passive or offline income plus a collection ladder that never finishes (*inference*).
2. A weekly update and event cadence; it is the one thing the source says separates survivors from spikes.
3. Player-versus-player risk on top of a home base (steal, defend, take back), kept low-stakes.
4. Rebirth or prestige as the long ladder.
5. Reasons to bring friends: Roblox counts intentional co-play days (confirmed).
6. A payoff in the first minute: bounce under 60 s hurts discovery (confirmed).
7. Persistent world state may hold players better than session resets (weak, early data).

## Crime competitors

| Game | State | What it is |
|---|---|---|
| Jailbreak | All-time peak 173K in June 2026 after a map revamp; current health unconfirmed (trackers disagree) | Round-based cops versus robbers with vehicles |
| Criminality | About 1K to 3K, flagged growing | PvP |
| Mad City | Declining (a blog opinion, not measured) | Jailbreak-like |

**The gap** (*inference*): no crime game pairs a persistent base with heists in a shared open city. Nothing was found on Da Hood-style games, gang or mafia tycoons, or any 2025 to 2026 crime newcomer.

## Audience

- Q3 2026 daily users were 138M, down 9% year on year (the first annual fall); hours fell 15%.
- Over-18s are 29% of age-checked daily players (37% in the US) and the fastest-growing group.
- No tycoon-specific age or mobile-share figure was found.
- No source explains why dropper tycoons faded. *Inference:* they had no social pressure, no live cadence and no collection chase.

## Policy that shapes a crime game (confirmed unless marked)

- **Violence labels:** Minimal, Mild, Moderate, Restricted (18+). Realism pushes the label up; a cartoon low-poly look keeps it down. Repeated cartoon gunfights against NPC police likely land at Mild or Moderate (*inference*; the maturity questionnaire decides).
- **Gambling:** playable or simulated gambling is banned. A casino nobody can bet in is allowed and counts toward Moderate.
- **Account types (April 2026):** Roblox Kids (5 to 8) see games up to Mild; Roblox Select (9 to 15) up to Moderate. A Moderate label loses the Kids accounts.
- **Paid random items:** must be declared, and hidden for players where `ArePaidRandomItemsRestricted` is true.
- **Chat (January 2026):** chat needs an age check and only reaches nearby age bands. 64% of daily players had done the check by the end of Q3 2026. A crew feature must not depend on text chat: use pings, emotes and quick-chat (*inference*).

## Not found

RoMonitor and Rolimons data, developer post-mortems, any measured effect of crews or trading on retention, player counts for war or restaurant tycoons, a mobile-share figure.

## Sources

- https://create.roblox.com/docs/en-us/discovery.md
- https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- https://create.roblox.com/docs/en-us/production/promotion/content-maturity.md
- https://about.roblox.com/newsroom/2026/04/introducing-roblox-kids-and-select-accounts
- https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat
- https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat
- https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441
- https://devforum.roblox.com/t/analytics-similar-experience-benchmarks-broader-access/2210285
- https://create.roblox.com/docs/en-us/production/analytics/retention
- https://www.ggrecon.com/articles/roblox-daily-players-fall-q3-2026/
- https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals
- https://rowatcher.com/news/tycoon-games-the-genre-that-built-roblox-and-still-hasn-t-peaked
- https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like
- https://rowatcher.com/games/245662005/jailbreak
- https://rowatcher.com/games/245662005/jailbreak/dying
- https://rowatcher.com/games/1494262959/criminality/dying
- https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players
- https://studiokrew.com/blog/top-roblox-games-september-2026/
- https://earnaldo.com/blog/mad-city-vs-jailbreak
- https://allthings.how/steal-a-brainrot-roblox-efficient-stealing-events-and-rebirths

Related: [[CrimeLife Tycoon Decisions]], [[Four Places Survey 2026-11-14]], [[Reference MOC]].
