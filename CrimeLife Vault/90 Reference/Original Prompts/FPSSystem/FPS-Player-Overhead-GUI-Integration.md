# Prompt: Reuse the Enemy Name/Health Billboard on Players Too, Suppress Their Built-In Nameplate

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained, but
**depends on the enemy integration already having been applied** — confirmed live, it has: `Workspace.Part`
is gone, `ReplicatedStorage.GuiTemplates.EnemyGUI` exists with the death-hide line already added to its
`HealthManager` script, and all 6 `EnemyTemplates`' Humanoids already have `HealthDisplayType = AlwaysOff`
/ `NameDisplayDistance = 0`.

## Context — read this first

**"The same health and name" means literally the same prefab, not a rebuild.** This document clones
`ReplicatedStorage.GuiTemplates.EnemyGUI` — the exact instance already wired onto every enemy — onto
players too, rather than building a second, separately-styled billboard. The pre-built `Text` script
inside it reads `character.Name`; for a player-owned character that's already the player's actual
Roblox username (not the generic `"Enemy"` placeholder enemies get), so it shows something meaningful
for players with zero extra changes needed.

**Confirmed live: nothing currently suppresses the built-in nameplate for players either.** A
codebase-wide search for `HealthDisplayType` and `NameDisplayDistance` turned up no hits at all before
the enemy document above added the enemy-side ones — players are still on Roblox's stock defaults
(`DisplayWhenDamaged` / `100`), so the same built-in nameplate this document is meant to replace is
still fully active on every player right now.

**Players have no static "template" to edit once, unlike enemies.** Confirmed live: there is no
`StarterPlayer.StarterCharacter` — this game uses ordinary Roblox character loading, not a fixed rig
template sitting somewhere editable in Studio. So, unlike the enemy templates (a one-time property edit
in `ServerStorage`), suppressing the player nameplate has to happen from a script, at spawn time.

**`LevelingService.applyMaxHealth` is the right hook for the suppression — confirmed by reading its
full current source.** It already runs on every path that touches a player's `Humanoid`: initial spawn,
every level-up, and the admin `/setlevel` override. Adding the two display-suppressing lines there means
one well-justified insertion point covers every spawn path, instead of needing to duplicate the fix
across three call sites.

**The billboard attachment itself is a *different* hook — it must run exactly once per spawn, not on
every `applyMaxHealth` call.** `applyMaxHealth` runs again on every level-up and on `/setlevel`, both of
which happen to an *already-spawned* character — cloning the billboard there too would stack a second
copy on top of the first every time a player levels up. The actual clone is instead added next to
`applyMaxHealth`'s two existing call sites in `onPlayerAdded` (the `CharacterAdded` connection, and the
"character already exists" fallback for the same timing reasons that dual path already exists), which
between them fire exactly once per real spawn — with a small guard against a second call anyway.

**A red herring, ruled out by checking live rather than assumed from its name:** `Workspace.UI.OverheadGui`
looked, from its name alone, like it might already be an unused player-nameplate prefab — the same
situation `EnemyGUI` was in before the last document. Checked live: its `InformationLabel`'s current
`Text` is `"X2 Purifier [Gamepass]"` — it's a floating promotional label for a gamepass/perk, unrelated
to player names or health. **Not touched by this document.**

**One cosmetic-only change:** the clone attached to a player is renamed from `"EnemyGUI"` to
`"NameplateGui"` purely so a player's `Head` doesn't read "EnemyGUI" in the Explorer — the clone's
internal structure and both embedded scripts are completely untouched, so the same `.Parent`-hop
traversal covered in the enemy document still resolves correctly (renaming an instance never changes
its position in the hierarchy).

---

## Part 1 — `LevelingService`: suppress the built-in nameplate, attach the billboard once per spawn

**`ServerScriptService.Weapons.Scripts.LevelingService`** — add one local near the top, right after the
existing:

```lua
local LevelingConstants = require(ReplicatedStorage.Leveling.Constants)
```

add:

```lua
-- Same prefab already wired onto every enemy (see the EnemyGUI prompt). Reused as-is, not rebuilt, so
-- players and enemies show literally the same name+health billboard design.
local enemyGuiTemplate = ReplicatedStorage:WaitForChild("GuiTemplates"):WaitForChild("EnemyGUI")
```

`applyMaxHealth` currently reads:

```lua
local function applyMaxHealth(character: Model, level: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = 100 + LevelingConstants.MAX_HEALTH_PER_LEVEL * (level - 1)
	humanoid.Health = humanoid.MaxHealth
end
```

add two lines at the end of it:

```lua
local function applyMaxHealth(character: Model, level: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = 100 + LevelingConstants.MAX_HEALTH_PER_LEVEL * (level - 1)
	humanoid.Health = humanoid.MaxHealth

	-- Replaces Roblox's own built-in nameplate with the custom billboard attachNameplateGui clones
	-- below -- the same way this was already turned off on every enemy template. Re-set on every call
	-- (spawn, level-up, admin /setlevel) rather than once: this is the one function guaranteed to run
	-- on every path that already touches this character's Humanoid, so nothing else has to separately
	-- remember to enforce it.
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
end
```

Add a new function right after `applyMaxHealth`:

```lua
-- Attaches once per real spawn -- deliberately NOT called from applyMaxHealth, which also runs on
-- every level-up and on the admin /setlevel path, both against an already-spawned, already-decorated
-- character. Cloning there too would stack a second billboard on top of the first every level-up.
local function attachNameplateGui(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or head:FindFirstChild("NameplateGui") then
		return
	end
	local gui = enemyGuiTemplate:Clone()
	-- Renamed only so a player's Head doesn't read "EnemyGUI" in the Explorer -- cosmetic only, the
	-- clone's structure and both embedded scripts are untouched, so they resolve the character exactly
	-- as documented in the enemy prompt.
	gui.Name = "NameplateGui"
	gui.Parent = head
end
```

In `onPlayerAdded`, currently:

```lua
	player.CharacterAdded:Connect(function(character: Model)
		applyMaxHealth(character, playerLevels[player] or level.Value)
	end)
	if player.Character then
		applyMaxHealth(player.Character, playerLevels[player] or level.Value)
	end
```

becomes:

```lua
	player.CharacterAdded:Connect(function(character: Model)
		applyMaxHealth(character, playerLevels[player] or level.Value)
		attachNameplateGui(character)
	end)
	if player.Character then
		applyMaxHealth(player.Character, playerLevels[player] or level.Value)
		attachNameplateGui(player.Character)
	end
```

No other line in this file needs to change — confirmed by reading the complete current file before
writing this. `setLevelRequest`'s handler and `grantXp`'s level-up loop both already go through
`applyMaxHealth`, so the display suppression is enforced on those paths automatically; neither needs its
own `attachNameplateGui` call since neither one is a spawn.

### Verify

- [ ] Join (or spawn another test character) and confirm Roblox's default floating name+health display
      is gone, replaced by the custom billboard showing your own username and a full health bar.
- [ ] Damage yourself (or have another player/enemy do it) and confirm the bar shrinks and the number
      updates in real time, for every player watching, not just the one taking damage.
- [ ] Die and confirm the billboard disappears instead of freezing at "0 / &lt;max&gt;" (same behavior
      already verified for enemies, via the shared `HealthManager` script).
- [ ] Respawn and confirm exactly one `NameplateGui` exists under the new character's `Head` — not zero,
      not two.
- [ ] Level up (or use the admin `/setlevel` command) while alive and confirm this does **not** create a
      second billboard on the same character — the nameplate should keep working exactly as before,
      just reflecting the new max health once you take damage again.
- [ ] With two or more players in the server, confirm each one sees every other player's nameplate
      correctly positioned above the correct head — not swapped, not all stacked on one player.
- [ ] `PlayerCardController`'s separate on-demand player-info card (a different feature entirely) still
      works unaffected — it reads `Humanoid`/`Player` properties directly, not the built-in overhead
      display this document suppresses.

## Master verification checklist

- [ ] Every player shows the same custom name+health billboard as enemies, instead of Roblox's default
      built-in one.
- [ ] The billboard attaches exactly once per spawn and never duplicates across level-ups or admin
      level changes.
- [ ] `Workspace.UI.OverheadGui` (the gamepass label) is untouched and still shows whatever it showed
      before this document.
- [ ] Nothing about leveling, max-health-per-level, the admin `/setlevel` command, or XP granting
      changed — this document only adds two `Humanoid` display properties and one billboard clone to
      paths that already existed.

## Notes for whoever applies this

- Every fact above (the confirmed-applied state of the enemy document, the absence of any existing
  `HealthDisplayType`/`NameDisplayDistance` reference anywhere in the codebase, the complete current
  source of `LevelingService`, `Workspace.UI.OverheadGui`'s actual live content) was verified live
  immediately before this was written.
- Per the standing workflow: draft-and-research only unless you tell this session to apply directly.
  Once applied and verified, write a short plain-prose changelog entry following the template used by
  the existing entries under `FPSSystem/`, commit, then push — do not commit this prompt document
  itself (the repo is public).
