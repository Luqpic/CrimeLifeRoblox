---
type: tool
tags: [tool, skills, workflow]
updated: 2026-11-14
sources: ["Documents/Roblox/.claude/skills/roblox-*/SKILL.md (symlinked at CrimeLifeRoblox/.claude/skills)", "~/.claude/skills/roblox-blender-modelling", "CrimeLifeRoblox/FPSSystem/**/*.luau (grep counts, 2026-11-14)", "OBT Vault/40 Tools/Roblox Skills.md (shape)"]
---

# Roblox Skills

The project has 23 `roblox-*` skills in `Documents/Roblox/.claude/skills/` (also reachable as `CrimeLifeRoblox/.claude/skills`, a symlink to that folder) and one user-level `roblox-blender-modelling` in `~/.claude/skills/`. They are **generic Roblox knowledge**: APIs, pitfalls, recipes. This note routes a CrimeLife task to the right ones.

## How to use them

1. **Load only the 1 to 3 skills that match the task.** Find the task's row in [[#Pick by task]] or the `Skills:` line on the system note it touches, then invoke them with the Skill tool before building. Never load the whole set.
2. **CrimeLife's way wins.** A skill teaches technique and catches bugs; it never justifies rewriting a working CrimeLife system to the skill's pattern. Where they differ, follow [[#Where CrimeLife differs from the skills]] and the neighbouring code ([[Shared Code Extended by Attributes]]).
3. **A new conflict** (a skill recommends something CrimeLife does differently, not listed below): follow CrimeLife, add a row to the table, and mention it in the batch note.

## Pick by task

| The task touches | Load |
|---|---|
| Guns, blaster, `ShotResolver`, damage, knockback, stun, kill credit ([[Weapons and Blaster]]) | `roblox-game-systems`, `roblox-physics` (+ `roblox-security` when a remote changes) |
| Melee: crowbar, baton, knife, swing timing, bleed ([[Melee]]) | `roblox-physics`, `roblox-characters-animation` |
| Viewmodels, first-person motion, KeyframeSequences, reload poses ([[Viewmodels and Weapon Animation]]) | `roblox-characters-animation` (+ `roblox-blender-modelling` for meshes) |
| Enemies, `EnemyAI`, `EnemySpawner`, chase / attack / search, accuracy ([[Enemies and Spawner]]) | `roblox-npc-ai`, `roblox-physics` |
| Quests, dialogue, quest givers, kill tagging ([[Quests and Dialogue]]) | `roblox-game-systems`, `roblox-ui` |
| Weapon shop, upgrades, `BuyRequest` / `UpgradeRequest` ([[Weapon Shop and Upgrades]]) | `roblox-game-systems`, `roblox-security` |
| Cosmetics, skins, palettes, Spraypaint ([[Cosmetics and Skins]], [[Spraypaint]]) | `roblox-game-systems`, `roblox-ui` |
| Gamepasses, RPG pass, Vip, Robux products ([[Gamepasses]]) | `roblox-monetization` (+ `roblox-security` for receipts) |
| Cash, leaderstats, CashBurst ([[Economy and Cash]]) | `roblox-game-systems`, `roblox-security` |
| Leveling, Renown, level-up VFX ([[Leveling and Renown]]) | `roblox-game-systems` |
| Saves, ProfileStore, schema, hydrators ([[Persistence and Saves]]) | `roblox-data-stores` |
| HUD, panels, player card, inventory, hotbar, death screen, notifications | `roblox-ui` (+ `roblox-input` for touch and drag) |
| Nameplates, stat billboards, damage direction ([[Nameplates and Billboards]], [[Damage Direction]]) | `roblox-ui` |
| Camera claims, ADS zoom, lean, sprint, stamina, landing ([[Camera Authority]], [[Movement and Stamina]]) | `roblox-input`, `roblox-characters-animation` |
| Ragdoll, stagger, death physics ([[Ragdoll]]) | `roblox-physics`, `roblox-characters-animation` |
| Robbery prompts, PromptUI, heists, getaway (Robbery System, named only: [[Robbery Prompts]], [[Robbery Heists and Getaway]]) | `roblox-ui`, `roblox-input`, `roblox-networking` |
| A new or changed remote, anything a client sends | `roblox-networking`, `roblox-security` |
| Sound, hover and click sounds, weapon sounds | `roblox-audio` |
| Chat, any player-written text shown to others | `roblox-text-chat` |
| Lighting, parts, props, world dressing | `roblox-world-building` (+ `roblox-performance`) |
| Lag, memory, part counts | `roblox-performance` |
| Unit tests, spec modules, regression | `roblox-testing` (+ `roblox-studio-mcp` for harness behaviour) |
| Driving Studio through the MCP, captures, Play control | `roblox-studio-mcp` ([[Studio MCP Gotchas]] first) |
| Exploit sweep, review of a big change before reporting | `roblox-code-review`, `roblox-security` |
| Image uploads, Figma `/v1/images`, outside APIs | `roblox-open-cloud` (never print a key: [[Safety and Security Rules]]) |
| Luau idioms, types, task library | `roblox-luau` |
| Where a script belongs, replication | `roblox-architecture` |
| Places and teleports between them | `roblox-teleport-matchmaking` (no cross-place teleport is recorded) |
| Toolchain questions | `roblox-tooling` (background only: see below) |
| Badges, events, funnels | `roblox-analytics-liveops` |

## Where CrimeLife differs from the skills

Measured on 2026-11-14 with grep over the **40 `.luau` mirrors** in `CrimeLifeRoblox/FPSSystem/` (the two `ViewmodelAnimations/baseline/` copies left out). The mirrors are a subset of the live place; Studio itself was not scanned, so treat the counts as a sample. Follow CrimeLife's column.

| Topic | The skills suggest | CrimeLife does | Why it stays |
|---|---|---|---|
| Toolchain | Rojo / Script Sync, Wally, StyLua, CI | Studio is the source of truth; scripts are edited live through the MCP and exported to `.luau` mirrors in git. No Rojo or Wally (0 of 40 mention them) | The developer works in Studio; the mirrors are a record, not a build input |
| Types | `--!strict` everywhere | 2 of 40 files are `--!strict` (`UI/CashBurst`, `Cosmetics/SkinsCardController`) | Match the surrounding file; do not add it piecemeal |
| Player data | ProfileStore | **Same**: vendored `ServerStorage.ProfileStore` (MadStudio / loleris) behind `ProfileGateway` + `Schema`; 8 files mention ProfileStore, only the vendored module touches `DataStoreService` (1 of 40). Mock store in Studio ([[Persistence and Saves]]) | Agrees with the skill; never edit the vendored module |
| Input | Input Action System | `UserInputService` (3 files: `BlasterController`, `ViewModelController`, `GuiController`) and `ContextActionService` (1: `WeaponaryShopController`'s shop toggle). 0 use Input Actions | The blaster is built on it |
| UI styling | StyleSheets, tokens | `ReplicatedStorage.UI.*` modules (`Theme`, `Panels`, `Effects`, `Transitions`) over Figma-exported slices at 4x ([[GUI Rules]], [[HUD and UI Shell]]); 0 StyleSheets | One shared look across both places |
| Audio | Audio API (AudioPlayer, Wire) | Classic `Sound`: `Instance.new("Sound")` in 3 files, `SoundService` playback in `ViewModelController`; 0 AudioPlayer | Weapon sounds are bound to animation events on classic Sounds |
| Physics movers | Constraints (LinearVelocity, AlignPosition) | Knockback writes `AssemblyLinearVelocity` and `ApplyImpulseAtPosition` directly in `ShotResolver`; 0 constraint movers, 0 BodyMovers | Works for one-shot impulses; a constraint is the better tool for sustained motion |
| Tests | Jest Lua / TestEZ | An in-place runner: `ServerStorage.UnitTest.RunUnitTest(filter)` over `Cases.*_Test` modules (`t.test`, `t.expect`), plus `*.spec.luau` modules run by hand ([[Unit Test Runner]]). 0 TestEZ / Jest | Existing suites (146 tests on 2026-09-24) |
| Test DataStores | Separate test universe | `ProfileGateway.useMockStore()`, Studio only ([[Safety and Security Rules]]) | No production store is touched from a session |
| Chat | TextChatService | Not used in the mirrors (0 of 40); the place's chat version is not recorded | Check in Studio before any chat work |
| Monetization | `MarketplaceService`, ProcessReceipt | Not in the mirrors (0 of 40); gamepass code lives in Studio only ([[Gamepasses]]) | Read it live before changing it |
| Publishing | Open Cloud place publishing | **Never publish**; the developer saves ([[Save and Publish Rules]]) | Developer's rule |

## Skill catalogue

| Skill | In CrimeLife, mostly for |
|---|---|
| `roblox-analytics-liveops` | Badges, events, funnels (none recorded yet) |
| `roblox-architecture` | Where a new script or module belongs; replication |
| `roblox-audio` | Weapon, hover, click, cash and equip sounds |
| `roblox-blender-modelling` (user-level) | Weapon and prop meshes ([[Blender Pipeline]]) |
| `roblox-characters-animation` | Viewmodel and character animation, Humanoid states, ragdoll ([[Animation Pipeline]]) |
| `roblox-code-review` | A review pass before reporting a large or risky change |
| `roblox-data-stores` | [[Persistence and Saves]] |
| `roblox-game-systems` | Guns, cash, leveling, shop, quests, inventory |
| `roblox-input` | Camera, ADS, lean, keys, touch, drag and drop |
| `roblox-luau` | Luau idioms and pitfalls |
| `roblox-monetization` | [[Gamepasses]], Robux products |
| `roblox-networking` | `BuyRequest`, `UpgradeRequest`, `DamageDirection`, quest remotes |
| `roblox-npc-ai` | [[Enemies and Spawner]], quest givers |
| `roblox-open-cloud` | Image uploads, outside APIs ([[Icon Pipeline]], [[Figma and UI Art Pipeline]]) |
| `roblox-performance` | [[Performance Measurement]] |
| `roblox-physics` | Raycasts, knockback, collision groups (`EnemyCharacter`) |
| `roblox-security` | Remote validation, the economy, server authority |
| `roblox-studio-mcp` | The MCP harness ([[Studio MCP Gotchas]]) |
| `roblox-teleport-matchmaking` | Cross-place work (none recorded) |
| `roblox-testing` | [[Unit Test Runner]] |
| `roblox-text-chat` | Chat and filtered text |
| `roblox-tooling` | Background only: CrimeLife has no Rojo toolchain |
| `roblox-ui` | [[HUD and UI Shell]], panels, billboards, PromptUI |
| `roblox-world-building` | Props, lighting, world dressing |

Related: [[Tools MOC]] · [[Batch Workflow]] · [[Systems MOC]]
