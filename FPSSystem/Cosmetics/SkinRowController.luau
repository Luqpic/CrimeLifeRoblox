-- The skins row under the weapon detail panel. One chip per palette; clicking one asks the server to
-- equip it and recolours the spinning preview immediately so the choice reads before the round trip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)
local SpraypaintConstants = require(ReplicatedStorage.Spraypaint.Constants)

local player = Players.LocalPlayer
local equipRemote = ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest
local promptGamepass = ReplicatedStorage.Monetization.Remotes.PromptGamepassPurchase
local buyRemote = ReplicatedStorage.Spraypaint.Remotes.BuySkinRequest

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

-- Mirrors CosmeticsService.ownsPalette on the server, branch for branch. The client duplicates it
-- because ServerScriptService is unreachable from here, so the two must be kept in step deliberately:
-- if they drift, the row rings a chip the weapon is not actually wearing. Gated on SOURCE, not on a
-- price existing, for the same fail-closed reason as the server: a Spraypaint palette added without a
-- price must never fall through to `return true`.
local function ownsPalette(palette): boolean
	if palette.source == "Vip" then
		return ownsVip()
	end
	if palette.source == "Spraypaint" then
		return player:GetAttribute(SpraypaintConstants.ownedAttributeFor(palette.key)) == true
	end
	return true
end

-- One shared list, not a per-build local: there is only ever one BuyStrip instance (a sibling of
-- every weapon's SkinRow, reused across builds), so its BuyButton/CancelButton connections must be
-- torn down against the SAME table hideBuyStrip() clears next time, not a fresh empty one created by
-- the new build() call. A per-build local here left the previous weapon's BUY handler connected --
-- silently stacked on the shared button -- because hideBuyStrip() at the top of build() was only ever
-- clearing its own brand-new, already-empty table.
--
-- Safe as a single shared table specifically because there is exactly one SkinRow and one BuyStrip in
-- this panel -- both are per-panel singletons that build() re-targets on every call, not one pair per
-- weapon. If the shop ever gives each weapon its own row (and its own strip), this table -- and
-- hideBuyStrip's closure over `row` below -- would need to become per-row instead of shared.
local buyConnections: { RBXScriptConnection } = {}

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
		local currentPalette = Palettes.byKey(current)
		-- Unowned now covers a Spraypaint skin as well as a Vip one, matching equippedKeyFor on the
		-- server. Without this the row would ring a Cobalt chip the server had already degraded to
		-- Stock -- the same disagreement the Vip branch was added to prevent.
		if not currentPalette or not ownsPalette(currentPalette) then
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
			local owned = ownsPalette(palette)
			chip.Swatch.BackgroundTransparency = owned and 0 or 0.65
			-- A Vip chip shows a lock, a Spraypaint chip a coin: one says "pay", the other says "play".
			chip.Lock.Visible = not owned and palette.source == "Vip"
			chip.Coin.Visible = not owned and palette.source == "Spraypaint"
		end
	end

	-- Timed rather than unbounded: a missing BuyStrip must not hang showDetail with no chips and no
	-- error. If it never arrives, the row still builds and equips normally -- only the buy path (an
	-- unowned Spraypaint chip's click) goes inert, which is recoverable; a hung panel is not. A shop that
	-- cannot sell beats a shop that will not open.
	local buyStrip = row.Parent:WaitForChild("BuyStrip", 5)
	if not buyStrip then
		warn("[Cosmetics] BuyStrip not found under " .. row.Parent:GetFullName() .. "; the Spraypaint buy path is inert for this session")
	end

	local function hideBuyStrip()
		if not buyStrip then
			return
		end
		buyStrip.Visible = false
		row.Visible = true
		for _, connection in buyConnections do
			connection:Disconnect()
		end
		table.clear(buyConnections)
	end

	local function showBuyStrip(palette)
		if not buyStrip then
			return
		end
		-- Clears the previous palette's button connections before wiring this one, so opening the
		-- strip on three chips in a row does not leave three live BUY handlers on the same button.
		hideBuyStrip()

		local price = palette.price or 0

		buyStrip.PaletteName.Text = palette.name
		buyStrip.PriceLabel.Text = price .. " SPRAYPAINT"

		-- Re-painted on every balance change while the strip is open, not just once at open time: a
		-- one-shot `affordable` here left the control lying -- Spraypaint arriving from a kill mid-strip
		-- would leave the button reading "NOT ENOUGH" while the click handler's own live re-read below
		-- would have allowed the purchase. Registered in buyConnections so hideBuyStrip tears this
		-- down with everything else.
		local function refreshAffordability()
			local affordable = (player:GetAttribute(SpraypaintConstants.ATTRIBUTE) or 0) >= price
			buyStrip.PriceLabel.TextColor3 = if affordable then Color3.fromHex("CBF23C") else Color3.fromHex("FF4B4B")
			buyStrip.BuyButton.BackgroundColor3 = if affordable then Color3.fromHex("CBF23C") else Color3.fromHex("2A2E38")
			buyStrip.BuyButton.TextColor3 = if affordable then Color3.fromHex("171A22") else Color3.fromHex("8A8F9A")
			buyStrip.BuyButton.Text = if affordable then "BUY" else "NOT ENOUGH"
			-- Actually disabled, not merely repainted: the spec asks for a disabled control, and a
			-- button that looks dead but responds is worse than one that does neither.
			buyStrip.BuyButton.Active = affordable
		end
		refreshAffordability()
		table.insert(buyConnections,
			player:GetAttributeChangedSignal(SpraypaintConstants.ATTRIBUTE):Connect(refreshAffordability))

		table.insert(buyConnections, buyStrip.BuyButton.MouseButton1Click:Connect(function()
			-- Re-read the balance at click time rather than trusting what it was when the strip
			-- opened: Spraypaint can arrive from a kill while the strip is on screen, and the server
			-- re-checks anyway, so this only avoids firing a request that is certain to be refused.
			if (player:GetAttribute(SpraypaintConstants.ATTRIBUTE) or 0) < price then
				return
			end
			buyRemote:FireServer(palette.key, weaponName)
			hideBuyStrip()
		end))
		table.insert(buyConnections, buyStrip.CancelButton.MouseButton1Click:Connect(hideBuyStrip))

		row.Visible = false
		buyStrip.Visible = true
	end

	-- A row being rebuilt means a different weapon is on screen, so a strip left open from the last
	-- one must not survive into it.
	hideBuyStrip()

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
			-- Read ownership fresh rather than capturing it at build time: a chip bought or unlocked
			-- while this same panel is open must act on what is true now, not what was true then.
			if not ownsPalette(palette) then
				if palette.source == "Vip" then
					-- MonetizationService already disables the prompt for an unconfigured pass id, so
					-- this is safe to fire before the place is published.
					promptGamepass:FireServer("Vip")
				else
					showBuyStrip(palette)
				end
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

	-- The loop above only ever painted Lock inline (Vip's initial-build state was already known per
	-- chip); it never painted Coin, so an unowned Spraypaint chip's badge stayed hidden until the first
	-- ownership change happened to fire refreshLocks. One call here covers the initial build too.
	refreshLocks()

	-- One connection covering every ownership signal, rather than one per palette: AttributeChanged
	-- fires with the name, so a Spraypaint skin added later needs no new wiring here.
	local ownershipConnection = player.AttributeChanged:Connect(function(name: string)
		if name == MonetizationConstants.ownedAttributeFor("Vip") or name:sub(1, 10) == "SkinOwned_" then
			refreshLocks()
			repaint()
		end
	end)

	repaint()
	return repaint, ownershipConnection
end

return SkinRowController
