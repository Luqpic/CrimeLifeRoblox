# Prompt: Weapon Icon Decals — Upload and Wire Into Hotbar + Billboard

Paste this whole document to Claude Code (with Roblox Studio MCP access and local filesystem/Bash access on the same Mac). It is self-contained.

## Context, confirmed live before writing this — read this first

**The hotbar/inventory icon system needs zero code changes.** `StarterGui."Custom Inventory".InventoryController.SETTINGS`'s `toolObjectMetatable:updateIcon()` already reads `tool.TextureId` directly and sets `frame.toolIcon.Image` from it, and there's already a live `TextureIdChanged` connection that re-runs `updateIcon()` automatically. `TextureId` was deliberately cleared to `""` on every weapon in an earlier pass because no icon art existed yet (see that pass's changelog entry) — the moment `TextureId` is set to a real asset again, the hotbar shows it with no other change needed.

**`upload_image` only accepts http/https URLs, confirmed by direct test** — calling it with a local file path (`/Users/luqpic/Downloads/WeaponIcons/Crowbar.png`) returned `"Error Upload: Only http/https URLs are supported"`. Serving the folder over a temporary local HTTP server and passing `http://127.0.0.1:<port>/<file>` worked correctly and returned a real asset: `Crowbar.png` is **already uploaded** as `rbxassetid://131164107547501` — don't re-upload it, just use this id directly.

**`WeaponStatBillboard`'s icon has no logic behind it today** — the template's `Icon` `ImageLabel` (`ReplicatedStorage.GuiTemplates.WeaponStatPanel.Header.Icon`) is a plain gray placeholder box with `Image = ""`, and nothing in `WeaponStatBillboard.lua` ever sets it. Since `ServerStorage` never replicates to clients, the billboard can only show an icon if the icon id is mirrored onto the pickup `Model` the same way `damage`/`rateOfFire`/`magazineSize` already are (`WeaponPickup.lua`'s `mirrorDisplayStats`) — `TextureId` is a property, not an attribute, so it needs its own line rather than fitting that function's generic loop.

**Filename → weapon name mapping** (from `/Users/luqpic/Downloads/WeaponIcons/`, confirmed by listing the folder — two don't match their Tool name verbatim):

| File | Weapon (`ServerStorage.Weapons.<name>`) |
|---|---|
| `AK47.png` | `AK47` |
| `AKM.png` | `AKM` |
| `AMB-17.png` | `AMB-17` |
| `AUG A-3.png` | `AUG A-3` |
| `Crowbar.png` | `Crowbar` — **already uploaded**, see above |
| `Deagle.png` | `Deagle` |
| `FN-P90.png` | `FN P-90` (note the space/hyphen difference) |
| `HCAR.png` | `HCAR` |
| `Kriss Vector.png` | `Kriss Vector` |
| `M16A1.png` | `M16A1` |
| `M1911.png` | `M1911` |
| `MP9.png` | `MP9` |
| `Mateba 2006M.png` | `Mateba 2006M` |
| `Mossberg 590.png` | `Mossberg 590` |
| `Scar-L.png` | `Scar L` (note the hyphen/space difference) |
| `Sig MPX.png` | `Sig MPX` |

---

## Part 1 — Upload the remaining 15 images and assign `TextureId`

**Step 1: serve the folder over HTTP.**
```bash
cd /Users/luqpic/Downloads/WeaponIcons && nohup python3 -m http.server 8934 --bind 127.0.0.1 > /tmp/weaponicons_http.log 2>&1 &
disown
sleep 1
curl -sI http://127.0.0.1:8934/AK47.png | head -3   # confirm the server is actually serving before proceeding
```

**Step 2: call the `upload_image` MCP tool** with all 15 remaining files at once (skip `Crowbar.png` — already uploaded):
```
imagePaths = [
  "http://127.0.0.1:8934/AK47.png",
  "http://127.0.0.1:8934/AKM.png",
  "http://127.0.0.1:8934/AMB-17.png",
  "http://127.0.0.1:8934/AUG A-3.png",
  "http://127.0.0.1:8934/Deagle.png",
  "http://127.0.0.1:8934/FN-P90.png",
  "http://127.0.0.1:8934/HCAR.png",
  "http://127.0.0.1:8934/Kriss Vector.png",
  "http://127.0.0.1:8934/M16A1.png",
  "http://127.0.0.1:8934/M1911.png",
  "http://127.0.0.1:8934/MP9.png",
  "http://127.0.0.1:8934/Mateba 2006M.png",
  "http://127.0.0.1:8934/Mossberg 590.png",
  "http://127.0.0.1:8934/Scar-L.png",
  "http://127.0.0.1:8934/Sig MPX.png"
]
```
This returns a `{url: rbxassetid}` map. Match each result back to its weapon name using the table above.

**Step 3: stop the local server** (no longer needed once every upload has returned):
```bash
pkill -f "http.server 8934"
```

**Step 4: assign each `rbxassetid` as that weapon's `Tool.TextureId`** in `ServerStorage.Weapons`, plus `Crowbar` using the id already obtained:
```lua
local ServerStorage = game:GetService("ServerStorage")
local weapons = ServerStorage.Weapons

local iconIds = {
	AK47 = "rbxassetid://...",
	AKM = "rbxassetid://...",
	["AMB-17"] = "rbxassetid://...",
	["AUG A-3"] = "rbxassetid://...",
	Crowbar = "rbxassetid://131164107547501", -- already uploaded, do not re-upload
	Deagle = "rbxassetid://...",
	["FN P-90"] = "rbxassetid://...",
	HCAR = "rbxassetid://...",
	["Kriss Vector"] = "rbxassetid://...",
	M16A1 = "rbxassetid://...",
	M1911 = "rbxassetid://...",
	MP9 = "rbxassetid://...",
	["Mateba 2006M"] = "rbxassetid://...",
	["Mossberg 590"] = "rbxassetid://...",
	["Scar L"] = "rbxassetid://...",
	["Sig MPX"] = "rbxassetid://...",
}

local updated = 0
for weaponName, iconId in iconIds do
	local weapon = weapons:FindFirstChild(weaponName)
	if weapon and weapon:IsA("Tool") then
		weapon.TextureId = iconId
		updated += 1
	else
		warn(`Weapon icon assignment: no Tool named "{weaponName}" found`)
	end
end
print(`Assigned icons to {updated}/16 weapons`)
```
(Fill in the `"rbxassetid://..."` placeholders from Step 2's actual returned ids before running this.)

### Verify
- `updated` prints `16`, with no `warn` about a missing weapon name.
- Open the Custom Inventory hotbar in Play mode with a few different weapons equipped: each shows its own real icon, not blank or a generic name-only slot.
- Newly uploaded decals can take a short time to clear Roblox's moderation queue — if an icon shows blank immediately after upload, wait a minute and re-check before assuming something is wrong.
- Spot-check `FN P-90` and `Scar L` specifically, since their filenames didn't match the Tool name directly — confirm the right image landed on the right weapon.

---

## Part 2 — Mirror the icon onto weapon pickups

**`ServerScriptService.Weapons.Scripts.WeaponPickup`** — extend `mirrorDisplayStats`:
```lua
local function mirrorDisplayStats(pickup: Instance, template: Tool)
	for _, attributeName in DISPLAY_ATTRIBUTES do
		pickup:SetAttribute(attributeName, template:GetAttribute(attributeName))
	end
	-- TextureId is a property, not an attribute, so it needs its own line rather than fitting the
	-- generic loop above.
	pickup:SetAttribute("iconId", template.TextureId)
end
```
Nothing else in this script changes — `mirrorDisplayStats` is already called from `setupPickup`, which runs for every pickup at server start and whenever a new one is tagged.

### Verify
- Inspect any weapon pickup Model in Play mode: it now has an `iconId` attribute matching that weapon's `TextureId`.

---

## Part 3 — Show the icon on the stat billboard

**`StarterPlayer.StarterPlayerScripts.WeaponStatBillboard`** — right after `nameLabel.Text = weaponName`, add:
```lua
	local icon = header:WaitForChild("Icon") :: ImageLabel
	icon.Image = pickup:GetAttribute("iconId") or ""
```
This is a one-time read, same as `nameLabel.Text` above it — the icon doesn't change after a pickup is built, so no changed-signal is needed for it (unlike `damage`, which is re-read live for the upgrade system).

### Verify
- Approach any weapon pickup: its stat panel now shows the weapon's actual icon instead of an empty gray square.
- The icon isn't stretched, cropped, or squashed oddly — if it looks wrong, check `Icon`'s `ScaleType` on the template (`ReplicatedStorage.GuiTemplates.WeaponStatPanel.Header.Icon`) and set it to `Enum.ScaleType.Fit` if needed; not expected to be necessary since the source images are square, but worth a visual check rather than assuming.
- Everything else about the panel (damage/ammo/fire-rate rows, upgrade button) is unaffected.

## Verification checklist

- [ ] All 16 weapons have a real `TextureId`; the temporary local HTTP server was stopped afterward.
- [ ] Hotbar/inventory slots show each weapon's correct icon with no code changes beyond `TextureId` itself.
- [ ] Weapon pickups carry an `iconId` attribute mirrored from their template.
- [ ] The stat billboard shows each pickup's correct icon, not a blank placeholder.
- [ ] `FN P-90` and `Scar L` specifically double-checked, since their icon filenames didn't match their Tool names directly.
