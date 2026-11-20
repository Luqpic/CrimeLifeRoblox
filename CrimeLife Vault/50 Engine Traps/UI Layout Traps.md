---
type: trap
tags: [trap, ui, layout, gui]
updated: 2026-11-20
sources: ["CLAUDE.md (Known traps)", "70 Batches/FPS System/*.md and 70 Batches/Robbery System/*.md (cited per trap)", "OBT Vault/50 Engine Traps/UI Layout Traps.md (generic traps)"]
---

# UI Layout Traps

ScreenGui layout, drawing order and text. The shared UI code is described in [[HUD and UI Shell]]; the rules in [[GUI Rules]]. "(Known trap)" marks the list in `CLAUDE.md`; "(OBT)" marks a generic engine trap found on the developer's other project.

## Padding, anchors and position

### UIPadding offsets the children, not the frame (Known trap)
- **Symptom:** a right-anchored price pill moved 88 px left, straight onto the BUY / UPGRADE label.
- **Cause:** `UIPadding` offsets a GuiObject's children as well as its text. A `PaddingRight = 88` meant to reserve room moved the pill instead.
- **Fix:** give a button a `Label` child rather than padding the button.
- **Bit us:** [[FPS-Figma-UI-Bugfix-Pass-3]] (the pass-2 fix measured the padding arithmetic and reported PASS on a broken layout); the same trap caused the original icon overlap.

### AnchorPoint and Position must agree (Known trap)
- **Symptom:** `AnchorPoint (0, 0.5)` with `Position.Y = 0` puts a bar's centre on its track's top edge. A `GuessBox` anchored at its centre but positioned as if top-left rendered about 125 px left of its own outline.
- **Bit us:** [[Slice-Transparency-And-Anchor-Fixes]] (Robbery System).

### AbsolutePosition is measured below the top-bar inset (Known trap)
- **Symptom:** an overlay that ignores the inset lands about 36 px high; a careless comparison "found" a ~58 px misalignment that was exactly one inset.
- **Cause:** measured live: `reported AbsolutePosition.Y = offsetY * scale - (insetY if IgnoreGuiInset else 0)`, and at render time the inset is added back for both settings, so `trueScreenY = reportedAbsoluteY + insetY` whatever `IgnoreGuiInset` says.
- **Fix:** add `GuiService:GetGuiInset()` back on both sides of a comparison. The real delta in that case was 0.28 px (`UDim2.fromOffset` integer truncation).
- **Bit us:** [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]], [[FPS-Death-Screen-You-Died-And-Alignment]] (a ScreenGui with `IgnoreGuiInset = true`).

## Layouts own their children

### A UIListLayout owns position and often size (Known trap)
- **Symptom:** animating a slot's Size did nothing.
- **Cause:** the hotbar and the inventory grid rewrite every slot's size on each layout pass; direct animation is silently discarded.
- **Fix:** drive the pop with a scale modifier (`UIScale`), not the slot's size. Measured on a live slot first.
- **Bit us:** [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]].

### AutomaticSize around a wrapping UIListLayout explodes (OBT)
- A Frame with AutomaticSize XY around a wrapping list measured 21,495,824 px wide on a phone emulator. Size it from `UIListLayout.AbsoluteContentSize` with Offset padding.

### ScrollingFrame CanvasSize scale is a fraction of the parent (OBT)
- Compute the canvas from content in Offset, or use `AutomaticCanvasSize` and read `AbsoluteCanvasSize` back. Under aspect-ratio-sized rows the automatic canvas ran about 2 px short a row.

### A UIAspectRatioConstraint with FitWithinMaxSize can size a row to 0 x 0 (OBT)
- For an item whose height follows its width use `AspectType = ScaleWithParentSize`, `DominantAxis = Width`.

## Clipping and shapes

### ClipsDescendants cuts deliberate overhangs
- **Symptom:** banner titles clipped on WeaponaryShop and QuestLog only.
- **Cause:** the banner overhangs the panel's top-left corner (Figma places it at -19, -21), and these two panels alone had `ClipsDescendants = true`.
- **Fix:** `ClipsDescendants = false`; the ScrollingFrames inside clip themselves.
- **Bit us:** [[FPS-Figma-UI-Bugfix-Pass]].

### ClipsDescendants does not clip a rotated descendant
- Two rotated half-discs behind half-width clips drew wherever their rotation put them, so a progress ring sat half-lit at rest. [[Prompt-Circle-Liquid-And-Glow]], [[Prompt-Size-And-Ring-Starts-Empty]].

### UICorner does not affect ClipsDescendants
- Clipping is always rectangular: a rounded clip around the liquid left square corners inside a rounded plate. [[Prompt-Liquid-Shape-And-Hover-Lift]].

### UICorner does not mask a CanvasGroup
- The group accepted the property but never clipped its children: a square prompt with a rounded stroke drawn over it. [[Prompt-Circle-Liquid-And-Glow]].

### A CanvasGroup renders into a texture its own size
- Anything past its bounds is cut, including a halo: size the group to fit the halo (`BOX`, not `PLATE`). [[Prompt-Circle-Liquid-And-Glow]].

### A CanvasGroup's GroupTransparency does not fade its own UIStroke (Known trap)
- Put the stroke on a child, or fade the stroke yourself.

### Two coincident soft-edged shapes bleed
- **Symptom:** a ~1 px rim of the plate showed round the liquid fill, through four different fixes.
- **Cause:** along a shared anti-aliased silhouette the upper shape's alpha falls below 1, so the lower one shows. Border, stroke alignment, inset and opacity changes only changed which colour bled.
- **Fix:** one frame, one shape, one gradient (a two-keypoint hard stop in a `UIGradient`). [[Prompt-Circle-Liquid-And-Glow]].

### A UIStroke at a ScrollingFrame's edge is cut (OBT)
- Give the list padding on every side.

## Drawing order

### ZIndexBehavior is a global on the ScreenGui (Known trap)
- **Symptom:** a notification card rendered blank.
- **Cause:** `Instance.new("ScreenGui")` defaults to `ZIndexBehavior.Global`, which sorts every descendant by absolute ZIndex. `reseat` gave cards ZIndex 4 / 3 / 2 while their text sat at 1 and 2, so a card's background drew over its own children. ScreenGuis made in Studio default to Sibling; script-made ones do not.
- **Fix:** set `ZIndexBehavior = Sibling` on script-made ScreenGuis. Survey at that time: `NotificationGui`, `CashShopGui`, `GamepassShopGui`, `WeaponaryShopGui`, `QuestLogGui`, `DeathScreenGui`, `PromptUiGui`, `AdminLevelGui`, `DamageDirectionIndicator`, `Custom Inventory` and `Freecam` were Global, each one per-element ZIndex away from the same failure. `WeaponaryShopGui` stays Global on purpose (flipping it could re-layer a large panel); the skins card got its own ScreenGui instead.
- **Bit us:** [[Notification-Blank-Card-ZIndexBehavior]], [[Per-Weapon-Spraypaint]], [[FPS-Skins-Card-Detached-And-Palette-Expansion]].
- **Lesson:** reading `Text` and `TextTransparency = 0` proved the label's state, not that it reached the screen; a screen capture settled it in seconds.

### A GuiButton inside another GuiButton takes the click (OBT)
- The parent's `Activated` never fires when you press the child. Wire both, or make the child a Frame.

## Text

### Markup needs RichText; TextScaled can sit at TextSize 8
- `QuestFeedbackController` pushed a sentence with `<font>` markup into a single-line label without `RichText`, with `TextScaled` stuck at 8. [[FPS-Figma-UI-Bugfix-Pass]].

### TextWrapped = false switches TextScaled off (OBT)
- Set `TextWrapped` first, then `TextScaled`.

### TextFits and a failed GetTextBoundsAsync mislead (OBT)
- `TextFits` read false with the full text showing. Measure with `TextService:GetTextBoundsAsync` at the label's size; a failed call is "unknown", not "too big".

### Titles baked into art cannot be centred by layout
- The panel titles are part of the Figma banner slices: re-centring one is an export change. [[FPS-Banner-Title-Centring-And-UI-Fades]].

## Names and lifetime

### Instance.Name collides with a custom Name property (Known trap)
- **Symptom:** ordinary references quietly return a property instead of the object.
- **Cause:** the enemy overhead's label is called "Name" and its script "Text", both colliding with properties on their holders (`button.Text` is the button's string, not a child).
- **Fix:** reach them with `FindFirstChild("Name")` / `FindFirstChild("Text")`, or never name children after properties. [[FPS-Enemy-Overhead-GUI-Integration]].

### PlayerGui contents reset on respawn
- A GUI parented into PlayerGui is thrown away and rebuilt on death unless `ResetOnSpawn = false`; code keeping a reference then talks to a discarded copy. The dialogue reply panel needed it set explicitly, or the "stuck zoomed in after dying" trap would come back. [[FPS-Dialogue-Responses-Clickable-Fix]].

### A cloned GUI keeps its scripts (OBT)
- Strip `LuaSourceContainer`s from a GUI copied only for its look.

Related: [[Engine Traps MOC]] · [[Billboard and World GUI Traps]] · [[Tween and Render Traps]]

- **A CanvasGroup's children did not draw in the Studio capture** (2026-11-20): the stealth vignette's four edge frames under a CanvasGroup at GroupTransparency 0.15 showed nothing; the same frames as plain Frames did. Fade plain frames' BackgroundTransparency for a full-screen overlay. [[2026-11-20 Crouch Stealth]]
- **`UIScaleController` measures a ScreenGui's widest offset-sized descendant** (2026-11-20): a 5,456-wide reel strip shrank the crate page to the 0.4 floor. Give long strips `AutomaticSize` X with offset 0, and do not add a second UIScale (the controller skips a GUI that already has one). [[2026-11-20 Weapon Gacha]]
