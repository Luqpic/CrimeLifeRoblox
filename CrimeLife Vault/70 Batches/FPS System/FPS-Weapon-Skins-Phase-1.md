# Change Log: Weapon Skins, Phase 1

**Date:** 2026-09-23
**Status:** All eight verification rows plus the damage-path-clean check and all three unit suites
confirmed live in `FPS System.rbxl` (Server datamodel, one Play session) with real before/after
numbers — see Verification below. Two items are geometrically confirmed but explicitly NOT visually
confirmed and still need a person: the Acid chip's equipped ring (screenshot tooling is unusable in
this environment) and the Vip pass tile's prompt behaviour (the game pass id is unconfigured until
the place is published). See Notes for both.

## Summary
Phase 1 ships eight weapon skins (5 free — Stock, Carbon, Sandstorm, Crimson, Acid — and 3 Vip-locked
— Gold, Obsidian, Arctic), each a dark-to-light colour ramp, selectable per weapon from a scrollable
chip row in the weapon detail panel. A skin recolours only the weapon's visible geometry — never
character parts, never the HUD — is applied identically to the world Tool and the first-person
viewmodel, is stamped as a `SkinId` attribute that survives death and respawn without a DataStore,
and is granted or refused by the server, never the client. This log is the Phase 1 close-out: no new
feature code, only measurement against the eight-row verification table the spec defined, plus the
three unit suites.

## Cause
The central design decision is that `SkinApplier` keys a skin on each part's **visibility and
relative luminance inside the weapon's `Blaster` sub-model**, never on part names. This was not the
first approach — a part-name map (recolour anything named `Body`/`TrimA`..`TrimD`) is what the
palette catalogue started as, and it was disproved during Phase 1's own build: measured, 11 of the
29 viewmodels carry parts named `Mesh1`..`Mesh8`/`MagazineMesh`, and on those weapons the
conventionally-named parts are **invisible donor skeleton** left behind by the viewmodel build
script's mesh-swap process, while the `Mesh*` parts are what actually renders. The Spas 12 viewmodel
is the extreme case: `Body` and `TrimA`..`TrimD` sit at `Transparency = 1` while `Mesh1`..`Mesh4` are
the only visible geometry. A name-keyed palette would have tinted the invisible skeleton and left the
weapon looking completely unskinned in first person for 38% of the armoury — a defect that would not
show up in any screenshot of the world Tool, only in the one view (first person) players spend the
most time in.

This verification pass turned up a live second example of the same pattern by accident: the **Glock
17** viewmodel used for the damage and rig tests (see Verification rows 2–3) also mixes both kinds of
part in one model — `Body`, `TrimA`, `TrimB`, `TrimC` are invisible (`Transparency = 1`) while
`Mesh1`..`Mesh5` and `Magazine` are visible and correctly carried the applied skin colour. Confirms
the Cause reasoning is not a one-weapon edge case.

Keying on each part's own luminance instead of its name means one palette definition dresses every
weapon, present or future, without a per-weapon exception list, and each weapon keeps its own
existing dark-to-light contrast rather than going flat under a skin. Measured across the full
viewmodel set: 229 total `Blaster` parts, 158 visible, 71 invisible — the invisible fraction
(31%) is close to, and consistent with, the 11/29 (38%) weapon-level figure above.

## Changes
Shipped in earlier Phase 1 tasks, confirmed present and correct by this pass:
- `ReplicatedStorage.Cosmetics.Palettes` (ModuleScript) — the 8-palette catalogue: `key`, `name`,
  `source` (`Free`/`Vip`), `swatch`, and a 3-stop `ramp` per palette.
- `ReplicatedStorage.Cosmetics.SkinApplier` (ModuleScript) — `apply`/`remove`/`applyKey`, scoped to
  the Tool's `Blaster` sub-model, filtered to `Transparency < 1`, luminance-ranked against each
  part's current `.Color`. In the shipped path that is always the just-restored stock colour, not a
  leftover skin's: `applyKey` calls `remove()` before `apply()`, and `remove()` clears the recorded
  `SkinOriginalColor` attribute before `apply()`'s ranking step ever reads it, so the attribute is
  nil at ranking time and `.Color` (which `remove()` just set back to stock) is what `apply()`
  actually ranks against. Re-skinning still never ranks against a previous skin's result — the
  result is identical — but not by the attribute-read mechanism this line previously named.
- `ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest` (RemoteEvent) — the one client-to-server
  entry point for equipping a skin.
- `ServerScriptService.Cosmetics.Scripts.CosmeticsService` (ModuleScript) — ownership
  (`ownsPalette`), the per-weapon replicated attribute (`EquippedSkin_<sanitised weapon name>`),
  `applyToTool`/`refresh`, and `handleEquipRequest` (type check → armoury check → ownership check →
  write → refresh, in that order).
- `ServerScriptService.Weapons.Scripts.WeaponShopService` — `grantWeapon` (the single choke point for
  both a fresh equip and a post-respawn restore) now calls `CosmeticsService.applyToTool`, guarded
  with `pcall` so a skin failure costs a colour, never the weapon.
- `ReplicatedStorage.Blaster.Scripts.ViewModelController` — `dressViewModel` applies the equipped
  `SkinId` to the freshly-built viewmodel after `WeaponViewmodelMotion` has solved its joints, and a
  `GetAttributeChangedSignal("SkinId")` connection re-dresses it live if the skin changes while
  equipped.
- `StarterPlayer.StarterPlayerScripts.SkinRowController` (ModuleScript) + `SkinRow`
  (`ReplicatedStorage.GuiTemplates.WeaponaryShop.ShopArea.DetailPanel.SkinRow`, a `ScrollingFrame`) —
  8 skin chips, 3 shown Vip-locked, scrollable inside the panel's fixed 290x60 slot.
- `ServerStorage.UnitTest.Cases.Palettes_Test`, `SkinApplier_Test`, `CosmeticsOwnership_Test`
  (ModuleScripts) — the three suites re-run below.

This pass created no new shipped instances. Verification-only scaffolding (a granted `Glock 17`, a
cloned, anchored `Offender` dummy used as a damage target) was created and destroyed inside the one
Play session used for testing; nothing was left behind in the place.

## Verification
All numbers below were measured live in one Play session against `FPS System.rbxl`
(`Roblox_Studio` MCP, Server/Client datamodels), driving the real client→server remotes
(`BuyRequest`, `SetLoadoutSlotRequest`, `EquipRequest`, `EquipSkinRequest`) rather than calling
server-internal functions directly, except where noted.

1. **Renders in third person — PASS.** Granted and equipped a `Glock 17` into the player's
   character (`SolarAudio`), read `Color` off the **live** Tool inside `Character`, not the
   `ServerStorage` template. Stock baseline: `Body (0.325,0.325,0.329)`, `TrimA (0.514,0.471,0.369)`,
   `TrimB (0.220,0.220,0.224)`, `TrimC (0.369,0.365,0.373)`, `TrimD (0.639,0.635,0.647)`. After
   `EquipSkinRequest("Glock 17","Carbon")`: `Body (0.114,0.122,0.145)`, `TrimA (0.188,0.200,0.235)`,
   `TrimB (0.071,0.075,0.090)`, `TrimC (0.129,0.137,0.165)`, `TrimD (0.306,0.329,0.384)` — all five
   parts moved onto the Carbon ramp, sampled by relative luminance as designed.

2. **Renders in first person — PASS.** `player.CameraMode` read as `Enum.CameraMode.LockFirstPerson`
   once the weapon was equipped (set by `ViewModelController:enable()`). The live viewmodel (found
   parented to `Workspace`, per `ViewModelController:update`'s per-frame reparent) showed the same
   mixed-part structure the Cause section describes: `Mesh1..Mesh5`/`Magazine` (`Transparency = 0`)
   carried the Carbon ramp (`Mesh1 (0.114,0.122,0.145)`, `Mesh2 (0.188,0.200,0.235)`, `Mesh3
   (0.071,0.075,0.090)`, `Mesh4 (0.129,0.137,0.165)`, `Mesh5 (0.306,0.329,0.384)`), while `Body`,
   `TrimA`, `TrimB`, `TrimC` sat at `Transparency = 1` and were correctly skipped.

3. **Rig undisturbed — PASS.** Measured hand-to-weapon gap on the skinned Glock 17 viewmodel using
   the same off-plane concept as the original fix (nearest point on any visible `Blaster` part's
   oriented bounding box to each arm's weapon-side end): **Left 0.0859, Right 0.0000 studs.**
   Re-measured after equipping `Stock` (removing the skin): **identical, Left 0.0859, Right 0.0000.**
   Both figures sit well inside the established worst-0.25/mean-0.041 envelope from the original
   hands-off-weapon fix, and are bit-for-bit unchanged between skinned and unskinned states, which
   is expected — `SkinApplier` writes only `.Color`, never `.CFrame`/`.Position`/joint data — but is
   now demonstrated rather than assumed.

4. **Removal is exact — PASS.** Equipped `Stock` after `Carbon`. Every one of the 5 live-Tool parts
   returned to exactly its recorded Stock baseline from row 1 (`Body 0.325,0.325,0.329`, etc., all
   five matching to the same precision as the pre-skin read), and `SkinOriginalColor` was absent
   (`attrPresent = false`) on all 5 parts afterward.

5. **Survives respawn — PASS.** With `Carbon` equipped, set the player's `Humanoid.Health = 0`,
   waited ~6s for the default respawn timer. The post-respawn character existed (`Health = 100`) and
   the **new** `Glock 17` Tool instance in the fresh `Backpack` (a different Instance from the
   pre-death one, freshly cloned by `grantWeapon` during the `CharacterAdded` restore) carried
   `SkinId = Carbon` and the identical Carbon-ramp colours (`Body 0.114,0.122,0.145`, etc.) — the
   session-only player attribute survived the character swap with no DataStore involved, as
   designed.

6. **Damage unaffected — PASS.** Fired the same live `Glock 17` Tool at a pinned, anchored
   `ServerStorage.EnemyTemplates.Offender` clone's `UpperTorso` via
   `ShotResolver.resolveShot` directly (same entry point `Blaster`'s Shoot handler and `EnemyAI` both
   use), same origin CFrame and RNG seed both times, health reset to max between shots: **Stock skin:
   22 damage. Carbon skin: 22 damage.** Identical, matching that `ShotResolver` reads only weapon
   attributes (`damage`, headshot multiplier, etc.) and never `Color`.

7. **Server-authoritative — PASS.** Confirmed the player did not own Vip
   (`GamepassOwned_Vip = false`). Fired `EquipSkinRequest("Glock 17", "Gold")` (a Vip-only palette)
   from the client. Server-side, `EquippedSkin_Glock_17` stayed `"Stock"`, the live Tool's `SkinId`
   stayed `"Stock"`, and `Body.Color` stayed at the Stock baseline (`0.325,0.325,0.329`) — the forged
   request was silently refused, exactly as `handleEquipRequest`'s ownership check is supposed to do.

8. **Not in a hot path — PASS.** `CosmeticsService`'s source contains no occurrence of
   `RunService`, `Heartbeat`, or `MarketplaceService` (checked by direct substring search against the
   live `Source` property, not a text-editor read). Ownership reads
   `player:GetAttribute(MonetizationConstants.ownedAttributeFor("Vip"))` only.
   `MonetizationService.publishOwnership` — the only caller of `UserOwnsGamePassAsync` for the Vip
   pass — runs once per player join (confirmed by reading its source), not per frame.

**Damage path is still clean — PASS (`clean`).** Ran the spec's exact check: neither
`ServerScriptService.Blaster.Scripts.ShotResolver` nor
`ServerScriptService.Weapons.Scripts.WeaponUpgradeService`'s `Source` contains `"Cosmetics"`,
`"Palettes"`, or `"SkinApplier"`. Result: `clean`.

**Unit suites — all PASS, matching the expected counts exactly**, run in a fresh Play-mode Server
datamodel (see Notes for why Edit mode gave a false read first):
- `Palettes_Test`: **10/10**
- `SkinApplier_Test`: **14/14**
- `CosmeticsOwnership_Test`: **11/11**

## Notes

**Disproved theory: the unit suites had regressed.** The first run, via `execute_luau` against the
**Edit**-mode datamodel, reported `Palettes_Test` 10/10, `SkinApplier_Test` 13/14 (one failure:
`applyKey with an unknown key falls back to stock even when a skin was already applied` — "expected
3, got 0"), and `CosmeticsOwnership_Test` 6/11 (five failures, all `attempt to call a nil value` on
`CosmeticsService.handleEquipRequest`). Read straight, this looks like a real regression in
`handleEquipRequest`. It was not: `require`-ing a **clone** of
`ServerScriptService.Cosmetics.Scripts.CosmeticsService` in the same Edit-mode command returned a
table with `handleEquipRequest` present and correct, while `require`-ing the original Instance kept
returning a table missing that one key. This is the same fault class the
`FPS-Viewmodel-Hands-Off-Weapon.md` log already named: Studio's Edit-mode `require()` cache can go
stale relative to a script's current `Source` after an in-session edit, and it does not invalidate on
its own. Re-running the identical three suites inside a fresh **Play**-mode Server datamodel (a new
Luau VM, hence a cold `require` cache) gave 10/10, 14/14, 11/11 with no code changes in between. The
practical rule this adds to the existing trap list: **run this project's unit suites from a fresh
Play session, not from an Edit-mode command**, or clone-require every module the suite touches —
Edit mode can fail a clean suite and look exactly like a real bug.

**Spec deletion, unremarked until now.** The original spec's palette entry carried a `rarity` field;
`ReplicatedStorage.Cosmetics.Palettes`'s `Palette` type never picked it up, because nothing in the
shipped feature reads it — the row locks and sorts purely on `source`/`key`, and no panel surfaces a
rarity tier. Deliberate, not a slip, but the earlier logs never said so; recorded here so the
archive shows the deletion was a decision.

**Second live example of the Cause's central claim.** The brief's Cause section was written around
Spas 12. This pass's rig and damage tests happened to use `Glock 17`, and its viewmodel turned out to
be a second, independent case of the same donor-skeleton pattern (`Body`/`TrimA-C` invisible,
`Mesh1-5`/`Magazine` visible) — not cherry-picked, just the weapon chosen for being quick to grant
and cheap. Strengthens rather than changes the Cause.

**Environment traps hit or deliberately avoided this pass** (carried forward because they cost real
time before and will again):
- `screen_capture` returns a magenta placeholder in Play mode — no visual check was attempted; the
  Acid ring's appearance is explicitly left unverified below, not silently assumed.
- A chip scrolled outside `SkinRow`'s clipped window swallows clicks with no error. Not directly
  exercised this pass (skins were equipped via the remote, not the UI), so this trap did not need to
  be worked around here, but the earlier Task 6/7 logs already hit it — flagged in case a future pass
  drives the row through the actual chips.
- `AbsolutePosition` differs between Play sessions because of `WeaponaryShopGui`'s `ResponsiveScale`
  UIScale — not exercised this pass (no `AbsolutePosition` reads were needed for the 8 rows), noted
  for the same reason as above.
- `execute_luau`'s command-bar require cache is separate from a running script's — this is the
  general form of the stale-cache trap actually hit above; see that note.
- `string.gsub` with `(`, `)`, `.` or `-` in the pattern silently no-ops. Not hit this pass —
  `CosmeticsService.attributeFor` already sanitises with a `[^%w_]` character-class pattern, which
  has none of those metacharacters as literals to worry about.
- TweenService is render-driven and stalls at 0 FPS with the Studio viewport collapsed. Not relevant
  to this pass — no tweens were exercised.

## Status
- **Confirmed live, with numbers, this pass:** all eight verification rows, the damage-path-clean
  check, and all three unit suites (10/10, 14/14, 11/11, in a fresh Play session after the Edit-mode
  false-failure was traced and dismissed above).
- **Needs a person — not visually confirmed:** the Acid palette's equipped ring. It was confirmed
  geometrically in Task 6 (a 2px opaque `#CBF23C` stroke at the chip border with a 3px `#171A22` gap
  before the swatch) but never visually, because `screen_capture` is unusable in this environment
  (magenta placeholder in Play mode). A person with a working screenshot path, or eyes on a live
  client, should confirm the ring actually reads against the Acid swatch's own near-identical hue
  before calling the chip design done.
- **Needs a person — blocked on publishing:** the `Vip` game pass id is unconfigured until the place
  is published to Roblox. The pass tile is disabled by existing handling and cannot prompt a
  purchase in this environment. A person with publish access should configure the real game pass id
  and confirm the prompt actually opens once it exists.
