# Task 3 brief — EscapeDistance = 200 in all four configs

## Global Constraints (bind every step)

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

---

## Task 3: `EscapeDistance = 200` in all four configs

**Files:**
- Modify: `ReplicatedStorage.HeistShared.Config`, `ReplicatedStorage.RestaurantShared.Config`, `ReplicatedStorage.Gas2GoShared.Config`, `ReplicatedStorage.NewsStationShared.Config`

**Interfaces:**
- Produces: `Config.EscapeDistance` (number) on all four modules. Tasks 4, 5 and 6 read it.

- [ ] **Step 1: Read all four configs**

Read each before editing and place `EscapeDistance` beside the other session tunables (`SessionDuration`, `DuffelCap`, `CooldownDuration`), matching each file's own formatting and comment style. They differ — do not paste one shape into all four.

- [ ] **Step 2: Add the field with its reasoning comment**

In each of the four, add:

```lua
	-- Studs the player must get from this location's StatusBillboardAnchor,
	-- measured horizontally and only once clear of the building, before a
	-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
	-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
	-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
	-- neighbouring locations 165-205 apart it reads as "about one block over"
	-- without pushing the player through another location's grounds.
	-- A starting value, not a tuned one -- expect to adjust after playtesting.
	-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
	-- from inside the vault if Getaway's inside-the-building gate were ever
	-- removed. See Getaway's own header.
	EscapeDistance = 200,
```

- [ ] **Step 3: Verify all four resolve**

```lua
local RS = game:GetService("ReplicatedStorage")
local out = {}
for _, n in ipairs({"HeistShared","RestaurantShared","Gas2GoShared","NewsStationShared"}) do
	table.insert(out, n .. ".EscapeDistance = " .. tostring(require(RS[n].Config).EscapeDistance))
end
return table.concat(out, "\n")
```

Expected: four lines reading `200`. A `nil` means that file's edit did not land.

- [ ] **Step 4: Run the suite**

Expected: still `593 passed, 16 failed`. **If `ConfigSpec`, `RestaurantConfigSpec`, `Gas2GoConfigSpec` or `NewsStationConfigSpec` gains a failure**, that spec asserts an exact key set — add `EscapeDistance` to its expectations rather than removing the field.

---


---

## Scope fence

You may modify exactly these four ModuleScripts, and only by ADDING one field plus its comment:
- `ReplicatedStorage.HeistShared.Config`
- `ReplicatedStorage.RestaurantShared.Config`
- `ReplicatedStorage.Gas2GoShared.Config`
- `ReplicatedStorage.NewsStationShared.Config`

Nothing else. If a `*ConfigSpec` fails because it asserts an exact key set, you MAY add
`EscapeDistance` to that spec's expectations — that is explicitly in scope per Step 4. Do not
change any existing config VALUE, and in particular do not "fix" the two known-failing
`CooldownDuration` assertions (Restaurant expects 1200 but the config says 60; Gas2Go expects 600
but says 60). Those are pre-existing baseline failures and are NOT yours.

## Read before editing

The four files do not share a formatting style. Read each one and match its own comment style and
field ordering. Place `EscapeDistance` beside the other session tunables (`SessionDuration`,
`DuffelCap`, `CooldownDuration`).

## Report contract

Write the full report to `/Users/luqpic/Documents/Roblox/PromptFolder/RobberySystem/.sdd-getaway/task-3-report.md`:
the before/after of each of the four edit sites, the Step 3 verification output, the full Step 4
suite output, and an explicit comparison against the 579+14=593 passed / 16 failed expectation.

Return to me ONLY: status, the four verification lines, the TOTAL line, and any concerns.
