# Figma → Roblox 1:1 Export + The Font Bug That Caused the Mismatch

**Place:** `FPS System.rbxl` · **Figma:** `iRetcvpbMMD190DJA9Mwrm`, page `9:2` "02 · Redesign"

---

## The headline finding

The UI did not look like the Figma because **62% of the text was rendering in a fallback font.**

`ReplicatedStorage.UI.Theme` declared:

```lua
Display = Font.fromName("Archivo", Enum.FontWeight.Heavy)
Body    = Font.fromName("Barlow",  Enum.FontWeight.Medium)
```

with a comment claiming both were "verified with Font.fromName in this place". They were not.
Measured in the live place, `Font.fromName("Archivo", …)` fails with **the same `Temp read failed`
error as a font name invented purely to be wrong**. Roblox's catalogue is a fixed set of 41
families; neither Archivo nor Barlow is in it. Only 7 resolve here: Montserrat, GothamSSm, Arimo,
Roboto, RobotoCondensed, BuilderSans, Oswald.

Audit across the UI: **95 text instances, 59 broken** — 26 × Archivo Heavy, 20 × Barlow SemiBold,
13 × Barlow Medium. Every one silently fell back to the engine default.

No amount of re-spacing or re-exporting would have fixed this. It also would not have been fixed by
the "export whole frames as PNGs" approach, because live text can never be an image.

Also note the Figma actually specifies **Archivo Black** and **Barlow Semi Condensed** — different
families from Archivo and Barlow, so even the intent recorded in `Theme` was off.

## What was done about it

| Figma face | Shipped as |
|---|---|
| Archivo Black — **static** headers | **Baked into the banner image, in real Archivo Black.** Pixel-exact. |
| Archivo Black — **dynamic** text | `Montserrat Heavy` (heaviest available; matches weight, not letterform) |
| Barlow Semi Condensed 600 | `RobotoCondensed SemiBold` |
| Barlow Semi Condensed 500 | `RobotoCondensed Medium` |

`Theme.FontIntent` now records what the Figma actually asks for, so the substitution stays auditable.

Custom font upload is not reachable from here: `Font.fromId` needs a font-family asset, and only
images can be uploaded through this pipeline.

---

## Assets exported from Figma and uploaded

All rendered from the Figma file itself via the REST `/v1/images` endpoint at **4×**, so what ships
is the designer's own vector output rather than re-sourced artwork.

### Icons — 48×48 logical → 192×192, whitened
Whitened after export because the Figma source is acid `#CBF23C` and `ImageColor3` multiplies: a
green source could only ever be darkened, a white one takes any tint.

| Role | Asset ID | Note |
|---|---|---|
| PistolGun | `rbxassetid://114882635515499` | |
| IdCard | `rbxassetid://136486171998216` | |
| RibbonShield | `rbxassetid://81963921483625` | |
| MoneyStack | `rbxassetid://113757455390339` | |
| ShoppingCart | `rbxassetid://110426688033129` | |
| Close | `rbxassetid://82431923505873` | |
| **Ticket** | `rbxassetid://139412870646801` | **was missing from `Theme.Icon` entirely** |
| **Crosshair** | `rbxassetid://72744675982228` | **was missing from `Theme.Icon` entirely** |
| NameplateCaret | `rbxassetid://124968067078234` | triangle; no Roblox primitive |

### Banners
Pre-baked = plate **and** its display type rendered together, so the header is genuine Archivo Black.

| Role | Asset ID | Size (logical) | Position |
|---|---|---|---|
| Weaponary | `rbxassetid://126172357018694` | 302×64 | −19, −21 |
| Profile | `rbxassetid://107875671662051` | 184×56 | −15, −19 |
| Quests | `rbxassetid://128962021981603` | 192×58 | −15, −19 |
| Cash | `rbxassetid://104207249116158` | 178×60 | −17, −19 |
| Gamepasses | `rbxassetid://113297177930426` | 270×60 | −17, −19 |
| Death | `rbxassetid://130775797143022` | 641×98 | 639, 389 |
| **Tintable plate** (9-slice) | `rbxassetid://139350026418829` | — | — |

The tintable plate is white-over-black: `ImageColor3` tints the plate to any colour (acid for the
panels, `#FF4B4B` for the DeathScreen) while black × anything stays black, so the hard drop shadow
survives. `SliceCenter = Rect.new(20, 20, 1080, 220)` was **measured off the exported pixels** — the
right edge slants from x=1195 at the top to x=1091 at the bottom and the shadow band runs below
y=231, so those borders keep the whole slant and shadow out of the stretched region.

It is used only by `WeaponStatPanel`, whose header is the equipped weapon's name and therefore
cannot be baked.

---

## Changes applied

- **6 HUD icons** repointed to the Figma exports and tinted `#CBF23C`, live-verified `IsLoaded=true`
- **5 baked banners** wired onto `WeaponaryShop`, `PlayerCard`, `QuestLog`, `CashShop`,
  `GamepassShop`; their now-redundant `Label` children removed (nothing outside `Theme` reads them)
- **`WeaponStatPanel`** switched to the tintable 9-slice, native label kept
- **59 broken fonts repaired** across `Custom Inventory`, `GuiTemplates`, `Blaster.Scripts`,
  `Workspace.UI`
- **13 further labels** given their exact Figma face *and* Figma `TextSize` — the Cash/Gamepass shop
  bodies (which clone from templates and had never been brought into the design system) and the
  ammo HUD (`21` at 44px Display, `/ 10` at 22px, `DEAGLE · SEMI` at 15px)
- **`Theme` corrected**: accurate asset registry, honest font comments, `applyBakedBanner()` added,
  `applyBanner()` now tints the white plate

## Sound — verified intact

`UI.Sounds` (54 lines) · 3 × `ClickSound` · 2 × `BounceOnClick` · `WeaponaryShopController`
PURCHASE/UPGRADE/HOVER · `QuestFeedbackController` COMPLETE · `LevelUpPopup.LevelUpSound`
(SoundId is empty at rest but set at runtime by `LevelingHud` from `LevelingConstants` — not a bug).
23 GuiButtons still present under `GuiTemplates`, 6 under `Custom Inventory` — no binding target was
destroyed.

---

## Open items

1. **`ReplicatedStorage.UI.Theme` is dead code.** Nothing outside it requires it — no `Theme.Color`,
   `Theme.Icon` or `applyBanner` callers anywhere. Styling is baked onto instances in the `.rbxl`.
   It should become the live source of truth; until then every restyle is manual. This is the real
   "refactor the UI system" item.
2. **`StarterGui.ScreenGui.MultiExport`** — 1,155 descendants, every `Image` = `rbxassetid://0`,
   0 script references. Layer names archived to `FPS-Figma-Frame-Layer-Archive.md`. Awaiting the
   go-ahead to delete.
3. **Pre-existing, unrelated to this work:**
   - `Workspace.UI.OverheadGui.InformationLabel.Script:2` — `Head is not a valid member of Part "Workspace.UI"`
   - ~9 weapon sound assets fail with `User is not authorized to access Asset` (ownership, not wiring)
4. **Geometry not yet driven from the spec.** The exact Figma coordinates for all 23 frames are
   extracted (600-line spec) but only typography and assets have been applied. Positional 1:1 for
   the HUD cluster, hotbar and panel interiors is the next pass.
5. **Weapon render placeholders.** Figma uses `GRADIENT_LINEAR` rectangles as stand-ins for weapon
   art in the shop and hotbar. Real icons need to come from the game, not the design.
