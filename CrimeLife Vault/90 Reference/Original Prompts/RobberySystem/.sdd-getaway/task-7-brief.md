# Task 7 brief — retire the Claim zones (SCRIPT-SIDE ONLY)

## Global Constraints

- **Studio place:** "Robbery System", `placeId: 130328863401144`. Every MCP call needs `studio_id` — get it from `list_roblox_studios`; do not hardcode a stale id.
- **There is no git repository for the game code.** The place lives in Studio. The only git repo in this workflow is the changelog repo at `/Users/luqpic/Documents/Roblox/RobloxFPSsystem`. **Do not write `git commit` steps for Luau changes** — the per-task checkpoint is the spec suite, not a commit.
- **Line numbers from `script_grep` and `script_read` disagree.** Trust `script_read`. Always anchor a `multi_edit` on quoted code, never on a line number.
- **`EscapeDistance = 200`** in all four configs. **Near-complete GUI threshold: remaining ≤ 25% of N** (50 studs at N=200).
- **Never relax `BankInstance:Claim`'s `_state ~= ACTIVE` or `IsParticipant` guards.** That pair is the anti-dupe guarantee. If an implementation wants to, stop and raise it.
- **Horizontal distance only** — zero Y on both vectors before `.Magnitude`. The anchors float 40–120 studs above their buildings.
- **Figma account must be `muhammadluqmanhayyan@gamuda.tech`.** Run `whoami` first. The personal account has a View seat and returns a hollow file with no error.
- **Do not delete any world part without explicit user approval at that moment** (Task 7).

---

## Task 7: Retire the Claim zones

**Files:**
- Modify: `ServerScriptService.HeistServer` (boot asserts)
- Modify: `ServerScriptService.Heist.Tests.WorldSpec`
- Delete: 4 world parts — **with approval**

- [ ] **Step 1: Confirm nothing still reads the Claim role**

```lua
-- Expect zero hits on ZONE-ROLE uses. BankInstance:Claim, CashClaimVFX and
-- RobberySuccess legitimately keep the name -- the point is to catch any
-- zone-role reference the spec did not enumerate.
```

Run `script_grep` for `Claim` and read every hit. Anything still branching on `ZoneRole == "Claim"` or `role ~= "Claim"` must be gone before deleting the parts.

- [ ] **Step 2: Ask the user before deleting anything**

Present exactly these four parts and get explicit approval. Do not proceed on silence, and do not batch this with any other approval.

| Part | Position |
|---|---|
| `Workspace.HeistZones.ClaimZone` | 109.6, 18.5, -131.4 |
| `Workspace.SlowFoodsZones.RestaurantClaimZone` | 45, 7, -272.4 |
| `Workspace.Gas2GoZones.Gas2GoClaimZone` | -101.4, 11.2, -240 |
| `Workspace.NewsStationZones.NewsStationClaimZone` | -215, 7, -269.6 |

- [ ] **Step 3: Update `HeistServer`'s boot validation**

Change `assert(#zones == 6, ...)` to `5` and update its message from `(Lobby, Vault, Claim, 3x BankVaultZone)` to `(Lobby, Vault, 3x BankVaultZone)`. Drop `roles.Claim` from the role assert and `Claim` from its message. Update the `-- 3 original (Lobby, Vault, Claim) + 3 BankVaultZone volumes` comment above it.

- [ ] **Step 4: Delete the four parts**

Only after Step 2's approval.

- [ ] **Step 5: Update `WorldSpec`**

Read the per-location zone manifest assertions and correct the counts. Do not guess which ones move — run the suite and let it tell you.

- [ ] **Step 6: Run the suite**

Expected: `593 passed, 15 failed`. **The count drops by one**: the pre-existing `WorldSpec` failure `ClaimZone: no floor found within 6 studs` disappears with the part. That is the single legitimate change to the baseline in this whole plan. If any *other* baseline failure vanished or appeared, investigate.

- [ ] **Step 7: Confirm a clean boot**

`start_stop_play` and read `get_console_output`. Expected: no `[HeistServer] expected exactly N HeistZone parts` assertion.

---


---

## SCOPE CHANGE — the user chose UNTAGGING, not deletion

The task text above (Steps 2 and 4) describes DELETING four `*ClaimZone` parts. **Do not delete
anything.** I put the three options to the user directly and they chose to retire the zones by
removing their tags while keeping the geometry, because there is no version control for this place
and untagging is reversible.

So your Step 2/4 replacement is:

For each of these four parts, remove its `CollectionService` tag AND its `ZoneRole` attribute:

    Workspace.HeistZones.ClaimZone                      tag "HeistZone"        ZoneRole="Claim"
    Workspace.SlowFoodsZones.RestaurantClaimZone        tag "SlowFoodsZone"    ZoneRole="Claim"
    Workspace.Gas2GoZones.Gas2GoClaimZone               tag "Gas2GoZone"       ZoneRole="Claim"
    Workspace.NewsStationZones.NewsStationClaimZone     tag "NewsStationZone"  ZoneRole="Claim"

Use `CollectionService:RemoveTag(part, tag)` and `part:SetAttribute("ZoneRole", nil)`.
**Never call `:Destroy()`, `:ClearAllChildren()`, or reparent anything.** Do not rename the parts —
their names are the only remaining signal of what they were.

Verify afterwards that `CollectionService:GetTagged` returns: HeistZone 5, SlowFoodsZone 1,
Gas2GoZone 1, NewsStationZone 1 — and that all four parts still EXIST in Workspace.

**Before untagging, confirm how `WorldSpec` counts zones.** If it counts via `GetTagged`, untagging
satisfies it exactly as a deletion would. If it counts by walking the `*Zones` folders' children
instead, untagging will NOT satisfy it and you must tell me rather than deleting the parts or
weakening the assert — that is a decision for me, not you.

## Ordering — there is a deliberately broken window, keep it short

The boot assert and the world state must agree. Whichever you change first, the other is briefly
inconsistent and the Bank will fail to boot. Do the script edits and the untagging back to back,
then verify. Do not leave the session in the inconsistent state.

## Studio gotchas

- `execute_luau` needs `datamodel_type` exactly `Edit`.
- `script_read` needs `target_file` with a `game.` prefix plus `should_read_entire_file` /
  `start_line_one_indexed` / `end_line_one_indexed_inclusive`.
- `script_grep` and `script_read` disagree on line numbers — trust `script_read`, anchor edits on
  quoted code.
- Studio caches `require`; use `TestRunner.freshRequire` for `RunAll`.
- `BankInstance:Claim`, `CashClaimVFX` and `RobberySuccess` all legitimately keep the word "Claim".
  Step 1's grep is looking only for ZONE-ROLE uses (`ZoneRole == "Claim"`, `role ~= "Claim"`).

## Report contract

Full report to `.sdd-getaway/task-7-report.md`: both snapshot byte sizes, before/after of every edit,
the complete Step 1 grep results with your judgement on each hit, and the exact list of failing
assertions with their messages. Return ONLY: status, the failing assertion names/messages, snapshot
sizes, and concerns.
