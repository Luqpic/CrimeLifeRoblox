-- The skins row under the weapon detail panel. One chip per palette; clicking one asks the server to
-- equip it and recolours the spinning preview immediately so the choice reads before the round trip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)

local player = Players.LocalPlayer
local equipRemote = ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest
local promptGamepass = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase

local STROKE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ACCENT_HOVER_TRANSPARENCY = 0.6

local SkinRowController = {}

-- Must match CosmeticsService.attributeFor on the server. Duplicated rather than shared because the
-- server module lives in ServerScriptService, which the client cannot require.
local function attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

local function ownsVip(): boolean
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor("Vip")) == true
end

-- Builds the chips for one weapon. Returns a repaint function so the caller can refresh the equipped
-- outline on attribute change without rebuilding the row.
function SkinRowController.build(
	row: ScrollingFrame,
	chipTemplate: ImageButton,
	weaponName: string,
	previewModel: Instance?
): (() -> (), RBXScriptConnection)
	for _, child in row:GetChildren() do
		if child:IsA("ImageButton") and child ~= chipTemplate then
			child:Destroy()
		end
	end

	local chips: { [string]: ImageButton } = {}
	local equippedKey: string? = nil

	local function repaint()
		local current = player:GetAttribute(attributeFor(weaponName))
		if typeof(current) ~= "string" then
			current = Palettes.DEFAULT_KEY
		end
		-- Mirrors CosmeticsService.equippedKeyFor on the server: it degrades an unknown key, or a
		-- Vip palette the player no longer owns, to Stock. Without the same fallback here the row can
		-- disagree with the weapon the player is actually holding -- e.g. a refunded Vip pass leaves
		-- the server showing Stock while the row still rings (and locks) the old Gold chip, or a
		-- palette removed from Palettes.list leaves the server on Stock while the row rings nothing.
		if not Palettes.byKey(current) or (Palettes.isVipOnly(current) and not ownsVip()) then
			current = Palettes.DEFAULT_KEY
		end
		equippedKey = current
		for key, chip in chips do
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = key == current and 0 or 1 }):Play()
			end
		end

		-- The preview model showDetail hands build() is a freshly cloned, unskinned model, and until
		-- now was only ever dressed from the click handler -- so opening the panel on an
		-- already-equipped weapon rang the right chip while the rotating preview above it stayed
		-- stock until a chip was clicked. Applying here too means it also runs whenever the equipped
		-- skin changes while the panel is open, since this is exactly what repaintSkins already is.
		if previewModel then
			local ok, err = pcall(SkinApplier.applyKey, previewModel, current)
			if not ok then
				warn("[Cosmetics] failed to dress the " .. weaponName .. " preview with " .. tostring(current) .. ": " .. tostring(err))
			end
		end
	end

	-- Re-evaluates every chip's locked visuals in place -- never a rebuild, which would reset the
	-- row's scroll position under the player's finger. Locked state itself is never cached in a
	-- click-handler closure (see below): a chip bought mid-view must equip on the very next click,
	-- not prompt for a pass the player already owns.
	local function refreshLocks()
		for _, palette in Palettes.list do
			local chip = chips[palette.key]
			if not chip then
				continue
			end
			local locked = palette.source == "Vip" and not ownsVip()
			chip.Swatch.BackgroundTransparency = locked and 0.65 or 0
			chip.Lock.Visible = locked
		end
	end

	for index, palette in Palettes.list do
		local locked = palette.source == "Vip" and not ownsVip()
		local chip = chipTemplate:Clone()
		chip.Name = palette.key
		chip.Visible = true
		chip.LayoutOrder = index
		chip.Swatch.BackgroundColor3 = palette.swatch
		chip.Swatch.BackgroundTransparency = locked and 0.65 or 0
		chip.Lock.Visible = locked
		chip.Parent = row
		chips[palette.key] = chip

		local stroke = chip:FindFirstChildOfClass("UIStroke")

		chip.MouseEnter:Connect(function()
			if stroke and palette.key ~= equippedKey then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = ACCENT_HOVER_TRANSPARENCY }):Play()
			end
		end)
		chip.MouseLeave:Connect(function()
			if stroke and palette.key ~= equippedKey then
				TweenService:Create(stroke, STROKE_TWEEN, { Transparency = 1 }):Play()
			end
		end)

		chip.MouseButton1Click:Connect(function()
			-- Read fresh rather than the `locked` computed above: that local is captured once at
			-- build time, so a stale copy would keep prompting for the Vip pass after it was bought
			-- with this same panel open. refreshLocks updates the swatch/lock visuals on ownership
			-- change, but a closure over the old value would never see that change.
			local isLocked = palette.source == "Vip" and not ownsVip()
			if isLocked then
				-- MonetizationService already disables the prompt for an unconfigured pass id, so
				-- this is safe to fire before the place is published.
				promptGamepass:FireServer("Vip")
				return
			end
			equipRemote:FireServer(weaponName, palette.key)
			if previewModel then
				-- Guarded the same way every other cosmetics call site is (CosmeticsService,
				-- WeaponShopService, ViewModelController): a failed skin must cost the player a
				-- colour, never break the shop -- this one fires inside a MouseButton1Click handler,
				-- where an unguarded throw would otherwise be the last unguarded cosmetics call site.
				local ok, err = pcall(SkinApplier.applyKey, previewModel, palette.key)
				if not ok then
					warn("[Cosmetics] failed to skin " .. weaponName .. " preview with " .. palette.key .. ": " .. tostring(err))
				end
			end
		end)
	end

	-- One connection per build, released the same way currentSkinConnection is: showDetail
	-- disconnects the previous build's ownership connection (this second return value) before
	-- building the next weapon's row, so viewing twenty weapons leaves one of these rather than
	-- twenty -- not a second, separately-invented teardown path.
	local ownershipConnection = player:GetAttributeChangedSignal(
		MonetizationConstants.ownedAttributeFor("Vip")
	):Connect(refreshLocks)

	repaint()
	return repaint, ownershipConnection
end

return SkinRowController
