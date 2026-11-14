# Prompt: Hotbar Icon/Text Clash Fix, Drag-and-Drop Feel (Glow, Drop Feedback, Mouse-Follow Fix)

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/mouse-simulation verification). It is self-contained.

## Context, confirmed live before writing this — read this first

**Icon/text clash, reproduced live:** granted the player a weapon and inspected the live hotbar slot — `toolIcon.Visible = true` **and** `toolName.Visible = true` simultaneously, matching the screenshot exactly. Root cause in `StarterGui."Custom Inventory".InventoryController.SETTINGS`'s `toolObjectMetatable:updateIcon()`:
```lua
if textureId == "" or textureId == nil then
	frame.toolName.Visible = true
	...
else
	frame.toolName.Visible = SETTINGS.ALWAYS_SHOW_TOOL_NAME  -- currently true
	...
```
`SETTINGS.ALWAYS_SHOW_TOOL_NAME = true` was harmless while every weapon's `TextureId` was empty (the name was always the only thing shown), but now that real icons exist for all 16 weapons, both render stacked on top of each other. This is a one-line config fix, not a logic rewrite — the toggle already exists for exactly this purpose.

**Mouse-follow offset, measured live, not guessed:** simulated an actual drag (`user_mouse_input`: move to a hotbar slot, mouse down, move to `(650, 450)`) and read the dragged frame's real `AbsolutePosition` back: the frame's center landed at `(649.5, 506.5)` — X matched the mouse exactly, Y was **56.5px below** it. That matches the hardcoded `+ 57` in `updateFramePos`'s position line exactly:
```lua
frame.Position = UDim2.new(0, mousePos.X - (CellSize.X.Offset / 2), 0, mousePos.Y - (CellSize.Y.Offset / 2) + 57)
```
No GuiInset or other compensation is actually needed — X already centers correctly with no offset at all, and removing the `+ 57` makes Y match it. This was confirmed empirically before writing the fix below, not assumed.

**No static outline exists on `toolButton` anymore** — confirmed live (`UIStroke` was removed in an earlier pass for a cleaner look). The glow effect below is added dynamically only while a slot is actively being dragged, not baked into the template.

---

## Part 1 — Icon replaces the name, doesn't stack with it

**`StarterGui."Custom Inventory".InventoryController.SETTINGS`**:
```lua
SETTINGS.ALWAYS_SHOW_TOOL_NAME = false
```
(was `true`.) Nothing else needs to change — `updateIcon()` already branches correctly once this flips; a weapon that somehow still has no `TextureId` keeps showing its name as a fallback (that branch is unconditional, not gated by this setting).

### Verify
- Every hotbar slot and every Inventory-panel slot shows only the weapon's icon, never icon and name overlapping.
- If a weapon somehow has no `TextureId` (shouldn't happen now that all 16 have one), it still falls back to showing its name — confirm this fallback still works, e.g. by temporarily clearing one weapon's `TextureId` and checking, then restoring it.

---

## Part 2 — Dragged icon follows the mouse exactly, not offset below it

**`StarterGui."Custom Inventory".InventoryController.SETTINGS`**, in `updateFramePos` (inside the `GrabConn` handler in `addTool`):
```lua
		local mousePos = Vector2.new(mouse.X, mouse.Y)
		frame.Position = UDim2.new(0, mousePos.X - (CellSize.X.Offset / 2), 0, mousePos.Y - (CellSize.Y.Offset / 2))
```
(removed the `+ 57` at the end of the Y term.)

### Verify
- Grab a weapon from the inventory and drag it: the icon is centered exactly on the cursor, not visibly below it, in both hotbar and inventory-panel starting positions.

---

## Part 3 — White semi-transparent glow while holding a dragged item

Still inside the same `GrabConn` handler, declare two more shared locals alongside the existing ones near the top:
```lua
	local mouseEnd
	local mouseConn
	local newFrame
	local glowStroke: UIStroke? = nil
	local glowTween: Tween? = nil
	local CellSize = inventoryFrame.Frame.Grid.CellSize
```
In `updateFramePos`'s "just started dragging" branch (the `if not object.isGrabbed then ... end` block), right after `frame.Parent = inventoryGui`, add the glow:
```lua
		frame.Size = CellSize
		frame.Parent = inventoryGui

		glowStroke = Instance.new("UIStroke")
		glowStroke.Name = "DragGlow"
		glowStroke.Color = Color3.new(1, 1, 1)
		glowStroke.Thickness = 3
		glowStroke.Transparency = 0.4
		glowStroke.Parent = frame

		-- A slow breathing pulse rather than a static outline, so a held item visibly reads as
		-- "alive" rather than just tagged with a border.
		glowTween = TweenService:Create(
			glowStroke,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.75 }
		)
		glowTween:Play()
```
At the very top of `endGrab` (before any of its existing branching logic), clean it up unconditionally — the same "guaranteed cleanup regardless of which path executes" approach already used elsewhere in this project:
```lua
	local function endGrab()
		mouseEnd:Disconnect()
		mouseConn:Disconnect()
		object.isGrabbed = false

		if glowTween then
			glowTween:Cancel()
		end
		if glowStroke then
			glowStroke:Destroy()
		end

		local droppedGuis = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
		...
```
`TweenService` needs to be required at the top of this module alongside its existing requires:
```lua
local TweenService = game:GetService("TweenService")
```

### Verify
- Pick up a weapon from the inventory: it gets a soft white pulsing outline for as long as it's held, whether dropped on a valid slot or released over empty space.
- Release it (either outcome): the glow is gone immediately, no lingering stroke on the settled frame.
- Drag two different items one after another: no leftover glow from the first stacks onto the second.

---

## Part 4 — Feedback on drop, not a static snap

Add a small shared helper near the top of the module (after the existing requires), used by every place a drag actually resolves:
```lua
-- Brief feedback for a completed drag-drop: a quick size pop plus a white flash that fades out on
-- its own. Self-cleaning (destroys its own UIStroke once the fade finishes), so every call site can
-- just fire-and-forget it.
local function playDropFeedback(frame: ImageButton)
	local flash = Instance.new("UIStroke")
	flash.Name = "DropFlash"
	flash.Color = Color3.new(1, 1, 1)
	flash.Thickness = 4
	flash.Transparency = 0.2
	flash.Parent = frame

	local originalSize = frame.Size
	TweenService:Create(frame, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = originalSize + UDim2.fromScale(0.12, 0.12),
	}):Play()
	task.delay(0.08, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = originalSize,
			}):Play()
		end
	end)

	local fadeTween = TweenService:Create(
		flash,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	)
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		flash:Destroy()
	end)
end
```

**Extend `addTool`'s signature** with a trailing optional flag, and fire the feedback when set:
```lua
function module:addTool(tool: Tool, parent: string, position: number, isUserDrop: boolean?)
```
At the very end of `addTool` (after the existing `tool:SetAttribute("toolAdded", true)` / `ContextActionService:BindAction(...)` block):
```lua
	tool:SetAttribute("toolAdded", true)
	if parent == "HotBar" and position then
		ContextActionService:BindAction(position .. "hotBar", manageTool, false, EnumKeys[position])
	end

	if isUserDrop then
		playDropFeedback(frame)
	end
end
```

**Pass `true` from every drag-resolution call site inside `endGrab`** — the swap branch, the send-to-hotbar branch, and the send-to-inventory branch:
```lua
				if newSlotObject then -- Swap between tools
					wasSwapped = true

					object:DisconnectAll()
					newSlotObject:DisconnectAll()

					self:addTool(newSlotObject.Tool, parent, position, true)
					self:addTool(tool, newSlotObject.Parent, newSlotObject.Position, true)
					...
				elseif newSlot.Parent == hotbar then -- Send to Hotbar
					wasSwapped = true

					object:DisconnectAll()
					self:addTool(tool, "HotBar", tonumber(newSlot.Name), true)
					...
```
```lua
			elseif newSlot:IsA("ImageLabel") and newSlot == inventoryFrame and not wasSwapped and parent == "HotBar" then -- Send to Inventory
				wasSwapped = true
				object:DisconnectAll()
				self:addTool(tool, "Inventory", nil, true)
				...
```

**The snap-back case doesn't go through `addTool` at all** (it just reparents `frame` back), so it needs its own direct call — but only when a real drag actually happened, not on a plain click-to-equip (which flows through this same branch with `object.isGrabbed` never having been set true, since the mouse never moved):
```lua
		if not wasSwapped then
			if newFrame then
				newFrame:Destroy()
			end
			frame.Parent = object:getParentInstance()

			if object.isGrabbed then
				playDropFeedback(frame)
			end

			if SETTINGS.DRAG_OUTSIDE_TO_DROP and dropTool and tool.CanBeDropped then
				...
```

### Verify
- Drag a weapon from the inventory into an empty hotbar slot: a quick pop + white flash plays on the newly settled icon.
- Drag a weapon onto a slot that already has one (swap): both the swapped-in and swapped-out items get the feedback.
- Drag a weapon out and release it over empty space (no valid target): it snaps back to its original slot and still gets the feedback, since a real drag happened.
- Plain click-to-equip (no dragging, just a click): confirm this does **not** trigger the drop feedback — only genuine drags should.

---

## Part 5 — A little extra interactivity: hover brighten on slots

Small, deliberately restrained addition (this project already has hover-triggered tooltips via `MouseEnter`/`MouseLeave`; this adds a visual brighten alongside them, not a replacement). In `addTool`, alongside the existing `object.CONNECTIONS.MouseEnter` / `MouseLeave` connections. The resting transparency is captured fresh on each hover-in rather than incrementally adjusted on hover-out, so repeated hovers can't drift it away from its true value:
```lua
	object.CONNECTIONS.MouseEnter = frame.MouseEnter:Connect(function()
		if object.isGrabbed then
			return
		end
		object:showDescription()
		frame:SetAttribute("RestingTransparency", frame.BackgroundTransparency)
		TweenService:Create(frame, TweenInfo.new(0.12), { BackgroundTransparency = math.max(frame.BackgroundTransparency - 0.15, 0) }):Play()
	end)
	object.CONNECTIONS.MouseLeave = frame.MouseLeave:Connect(function()
		object:removeDescription()
		local resting = frame:GetAttribute("RestingTransparency")
		if resting then
			TweenService:Create(frame, TweenInfo.new(0.12), { BackgroundTransparency = resting }):Play()
		end
	end)
```
This only affects the slot's own background plate, not `toolIcon`/`toolName`, so it doesn't interact with anything from Parts 1-4.

### Verify
- Hover over any populated slot: it visibly brightens slightly; moving away returns it to exactly its previous transparency (equipped slots and disabled slots each return to their own correct resting state, not a hardcoded default).
- Hovering during an active drag (the slot being dragged, or others) doesn't fight with the drag/glow visuals.

## Verification checklist

- [ ] No slot ever shows icon and name overlapping; the no-icon fallback (name-only) still works if ever needed.
- [ ] Dragged item tracks the mouse cursor exactly, not offset below it.
- [ ] Holding a dragged item shows a soft pulsing white glow for the entire hold, cleanly removed on release either way.
- [ ] Every successful drag-drop (swap, send-to-hotbar, send-to-inventory, and snap-back-after-a-real-drag) plays a pop+flash; a plain click-to-equip does not.
- [ ] Hovering any slot brightens it slightly and returns exactly to its prior state on mouse-leave.
