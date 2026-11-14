# Prompt: AK47 Shop-Display Upside-Down Fix + Integrate 11 New Guns

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode and
`screen_capture` verification). It is self-contained.

## Context — read this first

**On the previous prompt document:** `FPS-Pistol-3D-Display-Fix-Persistent-Loadout-Slots.md` exists
in this same folder but has **not** been applied yet — confirmed live: `script_grep` for
`ShopViewRotation` returns zero matches anywhere in the place, and neither `Deagle` nor `AK47` carry
that attribute. **Its Part 2 (persistent ownership + loadout slots) HAS been applied** — confirmed
live: `SetLoadoutSlotRequest` exists and is wired exactly as that document specifies, in both
`WeaponaryShopController` and `WeaponShopService`. So: the loadout-slot system is live and this
document builds on top of it; the pistol shop-display rotation fix is not live yet, and this
document introduces the same underlying mechanism (`ShopViewRotation`) fresh, since it's needed here
too, for a different weapon. If you apply that older document as well (in either order), you're
describing the same code twice — that's harmless, just don't be confused by the overlap.

**On `screen_capture`:** the known limitation from earlier prompts is specifically about **2D GUI**
content in Play mode (confirmed broken). The work in this document is different: Part 1 is that same
2D shop GUI (so the same limitation applies — you'll need to ask the person running this to look and
report back). Part 2's orientation work is the **3D world model and first-person viewmodel** — actual
3D scene content, not a GUI overlay — which is a different code path and may well capture fine. Try
it; don't assume it's broken just because the GUI case was.

---

## Part 1 — AK47 shop display is upside down

### Bug

Screenshot confirms: in the Weaponry Shop's detail panel, the AK47's spinning 3D preview renders
upside down (right-side-up geometry flipped along its own roll axis — distinct from the
horizontal/vertical problem the Pistol category has, which is a separate, still-unfixed issue
described in the other document).

### Fix — same mechanism as the (unapplied) pistol fix, introduced here since it doesn't exist yet

**`ServerScriptService.Weapons.Scripts.WeaponShopService`** — add `"ShopViewRotation"` to
`CATALOG_ATTRIBUTES`:

```lua
local CATALOG_ATTRIBUTES = { "Category", "Price", "damage", "rateOfFire", "magazineSize", "range", "ShopViewRotation" }
```

**`StarterPlayer.StarterPlayerScripts.WeaponaryShopController`**, inside `showDetail`, replace:

```lua
		local isMelee = entry:GetAttribute("Category") == "Melee"
		local displayRotation = if isMelee then MELEE_EXTRA_ROTATION * GUN_DISPLAY_ROTATION else GUN_DISPLAY_ROTATION
```

with:

```lua
		-- Per-weapon override for weapons whose raw stored orientation doesn't match the shared
		-- default. Absent on a weapon = exactly the previous behavior, so every already-correct
		-- weapon is untouched by this change.
		local rotationOverride = entry:GetAttribute("ShopViewRotation") :: Vector3?
		local displayRotation
		if rotationOverride then
			displayRotation = CFrame.Angles(
				math.rad(rotationOverride.X),
				math.rad(rotationOverride.Y),
				math.rad(rotationOverride.Z)
			)
		else
			local isMelee = entry:GetAttribute("Category") == "Melee"
			displayRotation = if isMelee then MELEE_EXTRA_ROTATION * GUN_DISPLAY_ROTATION else GUN_DISPLAY_ROTATION
		end
```

(Skip this whole code change if you're applying the other document in the same sitting — it
describes the identical edit.)

### Set the override on AK47 and iterate visually

Run once:

```lua
local ServerStorage = game:GetService("ServerStorage")
local ak47 = ServerStorage.Weapons:FindFirstChild("AK47")
if ak47 then
	-- Starting hypothesis: the default formula (CFrame.Angles(90,0,0)) gets AK47 the right way
	-- round (horizontal, correctly spinning -- not reported as wrong) but flipped along its own
	-- barrel axis. A 180 roll on top of the existing pitch is the natural first thing to try.
	ak47:SetAttribute("ShopViewRotation", Vector3.new(90, 0, 180))
end
```

Enter Play mode, open the shop, open AK47's detail panel, look at it (or use `screen_capture` if it
turns out to work for this). If `(90, 0, 180)` isn't right, try next, in order:

1. `Vector3.new(90, 180, 0)`
2. `Vector3.new(-90, 0, 0)`
3. `Vector3.new(90, 0, 0)` combined with `MELEE_EXTRA_ROTATION`'s 90° Z roll, i.e. `Vector3.new(90, 0, 90)`

Report which value looked right.

### Verify

- [ ] AK47 displays right-side-up in the shop's 3D preview, spinning correctly, matching how a
      correctly-oriented rifle should look.
- [ ] Every other weapon's shop display is unchanged (none of them got this attribute).

---

## Part 2 — Integrate 11 new guns from `Workspace."New Guns"`

### What's there, confirmed live

`Workspace."New Guns"` contains exactly 11 raw models, no `Tool` wrapper, no `Handle`, no
attachments, no attributes — just each gun's visible `MeshPart`s (named generically `MeshPart`,
`MeshPart`, `MeshPart`... no semantic sub-names), grouped as:

- **`Pistols/`**: `MP443`, `PB`, `S&W 29`, `Glock 17`
- **`Shotguns/`**: `Benelli M4`, `Itacha Mag-10`, `Spas 12`
- **Ungrouped** (directly under `New Guns`): `M14 EBR`, `AR-18`, `HK G3`, `APS`

All 11 raw models share the **exact same raw storage orientation** (`WorldPivot.Rotation` measured
identical across `Glock 17`, `AR-18`, and `Spas 12` — almost certainly true for all 11 since they
were evidently imported as one batch). That matters: it means whatever orientation correction gets
worked out for one representative model applies to the rest of its group unchanged — you are not
solving 11 independent unknowns, you're solving up to 4 (one per donor group below).

### Design decisions, stated explicitly

- **Real-world stats, not literal ballistics** — matching how the existing 17 weapons already work
  (a Deagle doesn't deal a realistic .50AE joule count, it deals `35`, tuned so a magnum revolver
  hits much harder per shot than a 5.56 rifle's `10`-`18`). The table below follows that same
  internal balance curve while reflecting each real gun's actual character (caliber class, fire
  mode, magazine size, controllability) relative to the 17 weapons already in the game.
- **Fire mode determined from the real weapon, not forced into "auto or burst"**: `M14 EBR` is
  real-world issued almost exclusively as a semi-auto designated-marksman rifle (the "EBR"
  modernization specifically de-emphasizes its full-auto capability) — it's set to `Semi` here, not
  `Auto`/`Burst`, because that's what's actually accurate. `AR-18` and `HK G3` are genuine
  select-fire rifles issued/used full-auto — set to `Auto`. `Burst` already exists as a working fire
  mode in this codebase (`M16A1` uses it) but none of these 11 happen to be a real-world weapon best
  represented by it — if you disagree with a specific call below, it's a one-attribute change.
- **`APS` identity is ambiguous** and worth flagging rather than silently guessing: the name most
  commonly refers to the Stechkin machine pistol, but this one is grouped by hand with rifles/battle
  rifles, not with the other pistols, and has rifle-scale mesh complexity (7 parts, vs. 4-5 for the
  actual pistols). Best guess used below: the Russian APS *underwater rifle* (a genuine shoulder-fired,
  full-auto-only firearm) — a compact, specialized full-auto weapon, which is what's reflected in the
  stats. If this isn't the gun the mesh actually represents, the stats are a reasonable placeholder
  regardless; only the flavor/name-accuracy would be off, not the integration.
- **Icons are placeholders**: `TextureId = ""` on every new weapon, deliberately — this is the exact
  same icon-less pattern already shipped and verified working for Baton (name-only card, no broken
  image box). Not a shortcut standing in for "real" work; it's the established convention for "no
  icon yet."
- **No new animations or sounds.** Every new gun plays its donor weapon's exact Shoot/Reload/Idle/Equip
  animations and exact sound effects, unmodified. This isn't a corner cut — authoring new mocap/audio
  assets isn't something this tooling can do, and no new asset IDs are introduced anywhere in this
  document, matching the standing constraint from earlier prompts in this project.
- **Enemies are out of scope.** This integrates 11 purchasable player weapons into the shop/loadout
  system, matching the 17 that already work that way. It does not add or change any `EnemyTemplates`
  or enemy weapon assignment — none of the existing enemy templates use the fallback fabric-weapon
  path (`Constants.ENEMY_WEAPON_NAME`) that would even pick up a new weapon automatically, so there's
  nothing to wire there, and adding a new enemy variant wasn't asked for.

### Full weapon spec table

| Name | Category | Fire mode | Damage | Rate of fire | Magazine | Range | Reload (s) | Spread | Recoil min | Recoil max | Impulse | Price | Donor Tool | Donor ViewModel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Glock 17 | Pistol | Semi | 22 | 650 | 17 | 850 | 1.5 | 1.6 | 0, 10 | 3, 14 | 4 | 400 | Deagle | Deagle |
| MP443 | Pistol | Semi | 23 | 600 | 17 | 850 | 1.6 | 1.9 | 0, 12 | 4, 16 | 4 | 450 | Deagle | Deagle |
| PB | Pistol | Semi | 19 | 480 | 8 | 650 | 1.4 | 1.5 | 0, 8 | 2, 10 | 3 | 425 | Deagle | Deagle |
| S&W 29 | Pistol | Semi | 58 | 190 | 6 | 850 | 2.5 | 3.0 | 3, 22 | 8, 32 | 9 | 900 | Mateba 2006M | Mateba 2006M |
| Benelli M4 | Shotgun | Semi | 15\* | 150 | 7 | 550 | 0.45 | 8.5 | 8, 28 | 12, 38 | 6 | 1100 | Mossberg 590 | Mossberg 590 |
| Itacha Mag-10 | Shotgun | Semi | 20\* | 70 | 4 | 600 | 0.65 | 10.0 | 14, 38 | 20, 50 | 9 | 1300 | Mossberg 590 | Mossberg 590 |
| Spas 12 | Shotgun | Semi | 15\* | 100 | 8 | 580 | 0.5 | 9.0 | 9, 30 | 13, 40 | 6 | 950 | Mossberg 590 | Mossberg 590 |
| M14 EBR | AutoRifle | **Semi** | 30 | 350 | 20 | 1000 | 2.0 | 1.2 | 2, 14 | 6, 24 | 4 | 900 | AK47 | AK47 |
| AR-18 | AutoRifle | Auto | 12 | 700 | 30 | 1000 | 1.6 | 1.7 | -2, 6 | 2, 8 | 2 | 350 | AK47 | AK47 |
| HK G3 | AutoRifle | Auto | 22 | 550 | 20 | 1000 | 2.1 | 2.2 | 3, 13 | 6, 20 | 4 | 800 | AK47 | AK47 |
| APS | AutoRifle | Auto | 14 | 750 | 26 | 750 | 1.8 | 3.5 | 1, 10 | 4, 18 | 3 | 600 | AK47 | AK47 |

\* Shotgun `damage` is per-pellet, matching `Mossberg 590`'s convention (`raysPerShot = 8`,
`isShotgun = true`, `knockbackForce` carried over per-row: `55` / `75` / `58` respectively).

### General procedure — read once, applies to all 11

Every one of these gets built the same way a completely new `Baton` was built from `Crowbar` in an
earlier pass: **clone the donor's proven-correct `Tool` (and separately its `ViewModel`) wholesale —
Handle, Grip, Sounds, Scripts, Animations, rig all come along for free, already correct — then
replace only the visible mesh.** This is deliberate, not a shortcut: it means Grip alignment,
first-person hand rigging, and every sound/animation are inherited byte-for-byte from a weapon that
already works, and the only thing that can possibly be wrong is the new mesh's own orientation —
which is exactly the one thing that gets visually verified below rather than assumed.

**World model (`ServerStorage.Weapons.<Name>`, third-person / in-hand):**

1. Clone the donor `Tool` wholesale. Rename it.
2. Record the donor's old `Blaster` model's exact pivot (`donorBlaster:GetPivot()`) before touching
   anything, then delete the cloned Tool's copy of that old `Blaster`.
3. From the raw model in `Workspace."New Guns"` (or its `Pistols`/`Shotguns` subfolder), weld all of
   its `MeshPart`s together into a new `Blaster` Model exactly as the existing weapons are built: the
   largest part becomes `Body` (carries a `WeldConstraint` linking it to `Handle`, matching the
   existing convention observed on every current weapon), the rest become `TrimA`, `TrimB`, ... each
   with its own `WeldConstraint` linking it to `Body`. `PrimaryPart = Body`.
4. `newBlaster:PivotTo(donorBlasterOldPivot)` — this alone reproduces the donor's exact
   position *and* the donor's exact orientation for the new gun's whole welded assembly, since
   `Handle` never moved. **This does not, on its own, guarantee the gun's mesh *itself* points the
   right way** — a `MeshPart`'s visible geometry sits at whatever offset its own asset data defines
   relative to the part's own origin, which is unrelated to CFrame math and varies per mesh. That
   part has to be checked visually (next section), not assumed correct because the math above is
   sound.
5. Add a `MuzzleAttachment` (an `Attachment`) to `Body`, positioned at the muzzle end — same
   reasoning as step 4's caveat, get it in the right neighborhood, confirm visually.
6. Set every attribute from the spec table (`damage`, `fireMode`, `magazineSize`, `range`,
   `rateOfFire`, `reloadTime`, `spread`, `recoilMin`, `recoilMax`, `unanchoredImpulseForce`,
   `Category`, `Price`, `viewModel = <Name>`; add `isShotgun = true` and `raysPerShot = 8` for the
   three shotguns). Set `TextureId = ""` on the Tool (placeholder icon).
7. Parent the finished Tool into `ServerStorage.Weapons`.

**Viewmodel (`ReplicatedStorage.Blaster.ViewModels.<Name>`, first-person):**

1. Clone the donor's entire `ViewModel` wholesale (`Root`, `LeftArm`, `RightArm`,
   `AnimationController`, `Animations`, `AnimSaves`, and its old `Blaster`). Rename it.
2. Inside the clone, find the old `Blaster.Body`'s `BodyJoint` (`Motor6D`) and `MuzzleAttachment` —
   **do not recreate these, move them.** Record their properties, delete the old `Blaster`'s mesh
   parts, build the new `Blaster` from the same raw model exactly as in the world-model steps above
   (weld into `Body`/`TrimA`/..., `PrimaryPart = Body`), position it at the old `Blaster.Body`'s
   exact CFrame as a starting point, then re-parent the *same* `BodyJoint` and `MuzzleAttachment`
   instances onto the new `Body` (updating `BodyJoint.Part1` to point at the new `Body`; `Part0`
   stays `Root`; leave `C0`/`C1` numerically unchanged as the starting point).
3. Leave `Root`, `LeftArm`, `RightArm`, `AnimationController`, `Animations`, and `AnimSaves`
   completely untouched.

### The part that needs your eyes: orientation correction, solved once per donor group

Because a mesh's own geometry-to-origin offset isn't derivable from CFrame comparisons alone (this
project has already hit that wall once, in the AKM/Scar L/Kriss Vector fix — "mathematically
consistent... still came out wrong in a way pure vector math alone couldn't have caught"), don't
trust step 4/5 above to be visually correct on the first try. Instead:

1. Build **one representative gun per donor group** first: `AR-18` (AK47 donor group, covers all 4
   rifles), `Glock 17` (Deagle donor group, covers 3 pistols), `S&W 29` (Mateba donor group, covers
   itself only), `Spas 12` (Mossberg donor group, covers all 3 shotguns).
2. For each representative: equip it, check third person (screen_capture or ask the user to look)
   and first person. If the mesh is misoriented, apply a rotation correction to the whole welded
   `Blaster` group *before* the final `PivotTo` — `blaster:PivotTo(blaster:GetPivot() *
   CFrame.Angles(rx, ry, rz)) ` then proceed with the position step — iterating the angles until it
   reads correctly: barrel pointing away from the character, right-side up, grip in the hand
   naturally.
3. Record the working correction for that donor group. Build the remaining weapons in that same
   group using the identical correction (skip re-deriving it per-weapon — they share the same raw
   import convention, confirmed above).
4. Spot-check at least one more weapon per group after batch-building, to confirm the shared
   correction actually generalized and wasn't a one-off coincidence for the representative.

### Shop / loadout integration — should need zero extra code

Confirmed live: `WeaponShopService`'s catalog builder already loops over every `Tool` in
`ServerStorage.Weapons` with a `Category` attribute, and `WeaponaryShopController` already reads
everything (stats, price, icon, category tab, ownership, equip state) generically off that catalog.
Once the 11 Tools above exist with correct attributes, they should appear for purchase automatically,
with no further code changes. **Verify this is actually true rather than assuming it** — if any of
them fail to appear or behave differently from the existing 17, that's a real gap to close, not
something to paper over.

### Cleanup — last step, only after everything above is confirmed working

Do not delete `Workspace."New Guns"` until every one of the 11 weapons has been individually
confirmed (bought, equipped, fired, reloaded, shows correctly in both third- and first-person) —
it's the only remaining copy of the source meshes, and re-extracting from it is the fallback if
anything about a specific weapon needs redoing. Once confirmed:

```lua
local Workspace = game:GetService("Workspace")
local newGuns = Workspace:FindFirstChild("New Guns")
if newGuns then
	newGuns:Destroy()
end
```

### Verify

- [ ] All 11 weapons exist in `ServerStorage.Weapons` with every attribute from the spec table set
      correctly, `TextureId = ""`, and a working `Blaster` + `Handle` + `Sounds` + `Animations` +
      `Scripts` (all inherited from their donor).
- [ ] All 11 have a working `ReplicatedStorage.Blaster.ViewModels.<Name>` with the rig untouched and
      only the mesh swapped.
- [ ] Every one of the 11 displays correctly oriented in **both** third person and first person —
      checked individually, not assumed from the donor-group correction alone.
- [ ] All 11 appear in the shop, in the correct category tab, buyable, priced correctly, showing
      stats matching the table.
- [ ] All 11 can be bought, equipped into a loadout slot, fired (correct fire mode — especially
      confirm `M14 EBR` is semi-auto, not auto, and the three Burst-eligible-sounding rifles are
      actually `Auto` not `Burst` unless you deliberately changed that), reloaded (shell-by-shell for
      the 3 shotguns), and upgraded, exactly like the existing 17.
- [ ] Icon-less shop cards show the weapon name with no broken-image box, matching Baton.
- [ ] `Workspace."New Guns"` is gone, and nothing else in `Workspace` was touched.
- [ ] The existing 17 weapons are completely unaffected — none of their Tools, ViewModels, sounds, or
      animations were modified, only read from (as donors).

## Master verification checklist

- [ ] AK47's shop display is right-side up.
- [ ] All 11 new guns are fully integrated: correct stats, correct orientation in both views, buyable,
      equippable, functional, and the workspace is cleaned up.
- [ ] Nothing about the existing 17 weapons or the loadout-slot system regressed.

## Notes for whoever applies this

- Every fact above was verified live via `inspect_instance` / `script_read` / `script_grep` /
  `search_game_tree` against the running Studio instance immediately before this was written,
  including which parts of the *other*, still-unapplied prompt document are and aren't live.
- `script_grep` and `script_read` have been observed to report different line numbers for the same
  script in this project. Match edits on the quoted code, not on line numbers.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry (or two, if you'd rather split the AK47 fix
  from the 11-gun integration) following the template used by the existing entries under
  `FPSSystem/`, commit, then push.
