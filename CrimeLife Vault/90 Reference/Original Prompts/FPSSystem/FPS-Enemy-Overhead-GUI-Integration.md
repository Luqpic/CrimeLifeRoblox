# Prompt: Wire the Prebuilt "EnemyGUI" Billboard onto All 6 Enemies, Replacing the Default Nameplate

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**What exists right now, confirmed live:** `Workspace.Part.EnemyGUI` is a `BillboardGui` sitting on a
small, invisible (`Transparency = 1`), unanchored test `Part` in `Workspace` — clearly just a staging
spot to build and preview the GUI, not a live integration. Its structure:

```
EnemyGUI (BillboardGui, StudsOffset = (0, 2.1, 0), Size = {5,0},{1.2,0})
└─ GUI (Frame)
   ├─ Info (Frame)
   │  └─ Name (TextLabel) — has its own child Script named "Text"
   └─ HealthGUI (Frame)
      ├─ Healthbar (Frame)
      ├─ HealthNum (TextLabel)
      └─ HealthManager (Script)
```

**The two embedded scripts already do exactly what's needed — they were just never wired to an actual
enemy.** `HealthManager`'s full source:

```lua
local Humanoid = script.Parent.Parent.Parent.Parent.Parent:FindFirstChild("Humanoid")

while true do
	wait(0.1)
	script.Parent.HealthNum.Text = math.floor(Humanoid.Health) .. " / " .. math.floor(Humanoid.MaxHealth)
	local pie = (Humanoid.Health / Humanoid.MaxHealth)
	script.Parent.Healthbar.Size = UDim2.new(pie, 0, 1, 0)
end
```

and `Info.Name`'s child `Text` script:

```lua
local Name = script.Parent.Parent.Parent.Parent.Parent.Parent.Name
script.Parent.Text = Name
```

Both resolve their target by walking a fixed number of `.Parent` hops — 5 for `HealthManager` to reach
a `Humanoid`, 6 for the name script to reach the character's own `.Name` property. **That hop count is
exactly right for parenting `EnemyGUI` directly onto a rig's `Head`** (`EnemyGUI → Head → character` is
the same two-hop shape as the current `EnemyGUI → Part → character`), so neither script needs rewriting
— only *where* the whole `EnemyGUI` billboard is parented needs to change, from the disposable test
`Part` to each enemy's actual `Head`.

**A real trap worth knowing about, hit while researching this (not touched by this document, but
worth remembering if either script is ever edited again):** `Info.Name` and `Name.Text`, written as
plain dot-access, silently resolve to the *property* of the same name (every `Instance` has a `.Name`
string property; every `TextLabel` has a `.Text` string property) instead of the child object also
named `"Name"`/`"Text"`. That's exactly why the two child objects here had to be located via
`:FindFirstChild("Name")` / `:FindFirstChild("Text")` while researching this, not `.Name`/`.Text`. The
existing scripts avoid the trap by only ever using `.Parent` (never landing on an ambiguous name).

**Why the two scripts must be attached from `ReplicatedStorage`, not baked onto the 6 `ServerStorage`
templates:** `EnemySpawner.trySpawn` calls `stripClientScripts(character)` immediately after cloning a
template, which destroys **every** `Script`/`LocalScript` descendant of the clone (confirmed by reading
the full function — it's an unconditional `IsA("BaseScript")` check, not a client-specific one). Baking
`EnemyGUI` onto the `ServerStorage.EnemyTemplates.*` models directly would mean both scripts get
destroyed the instant an enemy spawns, before ever running. The fix used below is standard for this
codebase: clone `EnemyGUI` from a `ReplicatedStorage` prefab and parent it onto the character **after**
`stripClientScripts` has already run — one new line in `EnemySpawner.trySpawn`, no change to the
strip step itself, and the scripts run completely normally from that point on since nothing strips a
character a second time.

**One added line, not a rewrite:** confirmed live, `Humanoid.Health` never goes negative in Roblox, so
`pie` (`Health / MaxHealth`) is already always in `[0, 1]` — the existing math needs no clamping. The
only real gap is that the loop never turns anything *off*, so a dead enemy would keep showing "0 / 100"
and an empty bar above its ragdoll until the corpse itself is eventually destroyed. Since the entire
point of this document is "replace the healthbar" and a healthbar that visibly gets stuck at zero reads
as broken, one line is added to hide the whole billboard once health hits zero.

**Also confirmed live, identical across all 6 templates (`Thug`, `Criminal`, `Armed Criminal`,
`Security`, `Police`, `Armed Police`):** every one currently has `Humanoid.HealthDisplayType =
DisplayWhenDamaged` and `Humanoid.NameDisplayDistance = 100` — this *is* Roblox's own built-in floating
name+health display, already active on all 6. Left alone, it would render right on top of the new
custom GUI. Both are turned off on all 6 templates below so only `EnemyGUI` shows.

**Not changed:** the name text itself. The existing `Text` script shows `character.Name`, which is the
literal string `"Enemy"` for every archetype (confirmed live — `EnemySpawner` renames every clone to
`"Enemy"` and keeps the real archetype only in an `EnemyTemplate` attribute, for kill-tracking). This
document leaves that alone rather than silently deciding you want per-archetype names instead of the
generic label that's already built — see the optional tweak at the very end if you *do* want "Thug" /
"Security" / etc. to show instead of "Enemy".

---

## Part 1 — relocate `EnemyGUI` into `ReplicatedStorage.GuiTemplates`, add the death-hide line

Run once, in Edit mode:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local guiTemplates = ReplicatedStorage:FindFirstChild("GuiTemplates")
if not guiTemplates then
	guiTemplates = Instance.new("Folder")
	guiTemplates.Name = "GuiTemplates"
	guiTemplates.Parent = ReplicatedStorage
end

local existing = guiTemplates:FindFirstChild("EnemyGUI")
if existing then
	existing:Destroy() -- idempotent re-run
end

local sourcePart = Workspace:FindFirstChild("Part")
local sourceGui = sourcePart and sourcePart:FindFirstChild("EnemyGUI")
assert(sourceGui, "Workspace.Part.EnemyGUI not found -- has it moved since this was written?")

sourceGui.Parent = guiTemplates -- MOVE, not clone: exactly one canonical copy should exist

-- Only ever existed to hold EnemyGUI during design/testing; empty and purposeless now that the
-- billboard itself has moved out. Confirmed above it had exactly one child (EnemyGUI) before this ran.
sourcePart:Destroy()

print("EnemyGUI moved to ReplicatedStorage.GuiTemplates; the old test Part is removed.")
```

Then, in the Script Editor, open `ReplicatedStorage.GuiTemplates.EnemyGUI.GUI.HealthGUI.HealthManager`
(its new location after the move above) and add the 3 lines marked below — everything else in the
script is unchanged:

```lua
local Humanoid = script.Parent.Parent.Parent.Parent.Parent:FindFirstChild("Humanoid")

while true do
	wait(0.1)
	
	script.Parent.HealthNum.Text = math.floor(Humanoid.Health) .. " / " .. math.floor(Humanoid.MaxHealth)
	
	local pie = (Humanoid.Health / Humanoid.MaxHealth)
	script.Parent.Healthbar.Size = UDim2.new(pie, 0, 1, 0)

	if pie <= 0 then
		script.Parent.Parent.Parent.Enabled = false
	end
end
```

Do not touch `Info.Name`'s `Text` script — it needs no changes (see Context).

### Verify

- [ ] `ReplicatedStorage.GuiTemplates.EnemyGUI` exists with its full original structure intact
      (`GUI.Info.Name` + its `Text` script, `GUI.HealthGUI.Healthbar`/`HealthNum`/`HealthManager`).
- [ ] `Workspace.Part` no longer exists.
- [ ] `HealthManager`'s source has the 3 new lines added, nothing else changed.

---

## Part 2 — suppress the built-in nameplate on all 6 templates

Run once:

```lua
local ServerStorage = game:GetService("ServerStorage")

for _, template in ServerStorage.EnemyTemplates:GetChildren() do
	local humanoid = template:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
	end
end

print("Built-in overhead nameplate suppressed on all enemy templates.")
```

### Verify

- [ ] All 6 templates' `Humanoid.HealthDisplayType` is `AlwaysOff` and `NameDisplayDistance` is `0`.

---

## Part 3 — `EnemySpawner`: attach `EnemyGUI` to every spawned enemy's `Head`

**`ServerScriptService.Enemy.Scripts.EnemySpawner`** — add one local near the top, alongside the
other module-scope requires (right after the existing `local templateConfig = ...` line):

```lua
local enemyGuiTemplate = ReplicatedStorage.GuiTemplates:WaitForChild("EnemyGUI")
```

In `trySpawn`, add the attach call right after the existing per-spawn stat setup, which currently reads:

```lua
	humanoid.MaxHealth = config.maxHealth
	humanoid.Health = config.maxHealth
	humanoid.WalkSpeed = config.walkSpeed
```

becomes:

```lua
	humanoid.MaxHealth = config.maxHealth
	humanoid.Health = config.maxHealth
	humanoid.WalkSpeed = config.walkSpeed

	-- Replaces Roblox's own built-in nameplate (suppressed on the templates themselves -- see the
	-- EnemyGUI prompt's Part 2). Attached here, well after stripClientScripts ran above, so the two
	-- scripts riding inside this clone are never touched by it -- see Context for why that ordering
	-- is exactly what makes this safe to just clone-and-parent with no further wiring.
	local head = character:FindFirstChild("Head")
	if head then
		enemyGuiTemplate:Clone().Parent = head
	end
```

No other line in this file needs to change — confirmed by reading the complete current file before
writing this.

### Verify

- [ ] Spawn one enemy of each of the 6 types in Play mode. Each shows the custom name+health billboard
      above its head, not Roblox's default nameplate.
- [ ] The health bar shrinks and the number updates as the enemy takes damage.
- [ ] Killing an enemy hides the billboard (bar + name both disappear) once health reaches 0, rather
      than lingering at "0 / <max>" over the ragdoll.
- [ ] The billboard's height/size above the head looks reasonable at default view distance — the
      `StudsOffset`/`Size` values were carried over unchanged from the original design-time placement
      and were never visually confirmed against the actual rig height by anyone drafting this; nudge
      `EnemyGUI.StudsOffset` in `ReplicatedStorage.GuiTemplates.EnemyGUI` directly if it reads too high
      or too low once you actually see it in Play mode.
- [ ] Enemy movement, detection, chasing, ragdoll-on-death, and quest-kill-tracking (via the
      `EnemyTemplate` attribute) are all unaffected — this document only ever added a non-physical
      `BillboardGui` and two `Humanoid` display properties, nothing that touches AI/combat scripts.

## Master verification checklist

- [ ] All 6 enemy types show the custom `EnemyGUI` name+health billboard instead of Roblox's default
      one, correctly tracking damage in real time.
- [ ] The billboard disappears on death instead of freezing at 0 health.
- [ ] `ReplicatedStorage.GuiTemplates.EnemyGUI` is the single canonical copy; `Workspace.Part` is gone.
- [ ] Nothing about enemy AI, combat, ragdolling, or quest kill-tracking changed.

## Notes for whoever applies this

- Every fact above (the exact script sources, the `.Parent`-hop counts, the `stripClientScripts`
  behavior, the identical `HealthDisplayType`/`NameDisplayDistance` values across all 6 templates) was
  verified live immediately before this was written.
- **Optional, not applied here — a deliberate choice left to you, not decided silently:** if you'd
  rather each enemy's nameplate show its actual type ("Thug", "Security", ...) instead of the generic
  "Enemy" every clone is renamed to, change `Info.Name`'s `Text` script from
  `script.Parent.Text = Name` (reading the character's `.Name`, always `"Enemy"`) to instead read
  `character:GetAttribute("EnemyTemplate")` — the attribute `EnemySpawner` already sets on every spawn
  specifically to preserve this information after the rename. This document leaves the generic label in
  place rather than assuming which one you want.
- Per the standing workflow: draft-and-research only unless you tell this session to apply directly.
  Once applied and verified, write a short plain-prose changelog entry following the template used by
  the existing entries under `FPSSystem/`, commit, then push — do not commit this prompt document
  itself (the repo is public).
