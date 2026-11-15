--!strict
-- Screen-space "cash spent" burst: coins explode outward from a button, then fade where they land.
--
-- Sibling of the Robbery System place's SharedSystems.CashClaimVFX, which plays the INBOUND half of
-- the same idea: coins scatter from the claim toast and then FLY INTO the cash HUD while the counter
-- ticks up. This is the outbound half. Money is leaving, so there is nothing for the coins to fly
-- toward -- they scatter and fade out. Same coin art, same scatter feel, so spending and earning
-- read as one currency rather than two unrelated effects.
--
-- Replaces a red "-1500" TextLabel that rose and faded over the price. The figure was already shown
-- on the price pill the player just clicked, so the label restated it; what it did not convey was
-- that cash had physically left.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local CashBurst = {}

-- The same coin slice the Robbery place bursts with, so the two never drift apart visually.
local COIN_IMAGE = "rbxassetid://134682502484497"
local COIN_SIZE = 48

-- Scatter is quick and eased-out (the "explosion"); the fade follows it. Kept deliberately short --
-- this fires on every buy and upgrade, so a burst that outstays the click reads as lag rather than
-- feedback. Worst case (scatter + max stagger + fade) is about 0.55s.
local SCATTER_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE_STAGGER_MAX = 0.07
local SCATTER_RADIUS_MIN, SCATTER_RADIUS_MAX = 55, 145

-- A bigger spend throws more cash. Clamped at both ends so a cheap upgrade still reads as a burst
-- and an expensive one cannot carpet the screen.
local MIN_COINS, MAX_COINS = 8, 20
local COINS_PER_UNIT = 1 / 400

local function coinCountFor(amount: number?): number
	if type(amount) ~= "number" or amount <= 0 then
		return MIN_COINS
	end
	return math.clamp(MIN_COINS + math.floor(amount * COINS_PER_UNIT), MIN_COINS, MAX_COINS)
end

-- Optional look for the pieces. Omitted, the burst throws the shared coin slice exactly as before, so
-- every existing call is unchanged. The Skins card passes the spray-can icon, so a skin bought with
-- Spraypaint does not read as a Cash spend.
export type BurstStyle = { image: string?, color: Color3?, size: number? }

-- Burst from the centre of `origin`, a GuiObject the player just clicked.
--
-- Each call owns its own ScreenGui and destroys it when the last coin has faded, so repeated
-- spends cannot leak overlays and a burst still in flight is never torn out from under itself.
function CashBurst.burstFrom(origin: GuiObject, amount: number?, style: BurstStyle?)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui or not origin or origin.AbsoluteSize.X == 0 then
		-- No viewport yet, or the button is not laid out. Nothing to burst from; skip rather than
		-- spraying coins at (0,0).
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CashSpendBurst"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	-- AbsolutePosition is measured below the top bar, but this overlay ignores the inset -- so the
	-- inset has to be added back or every burst sits ~36px high.
	local inset = GuiService:GetGuiInset()
	local centre = origin.AbsolutePosition + origin.AbsoluteSize / 2 + inset

	local total = coinCountFor(amount)
	local finished = 0
	local image = style and style.image or COIN_IMAGE
	local color = style and style.color or Color3.new(1, 1, 1)
	local size = style and style.size or COIN_SIZE

	for _ = 1, total do
		local coin = Instance.new("ImageLabel")
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromOffset(centre.X, centre.Y)
		coin.Size = UDim2.fromOffset(size, size)
		coin.BackgroundTransparency = 1
		coin.Image = image
		coin.ImageColor3 = color
		coin.Parent = gui

		local angle = math.random() * math.pi * 2
		local radius = SCATTER_RADIUS_MIN + math.random() * (SCATTER_RADIUS_MAX - SCATTER_RADIUS_MIN)
		local landing = UDim2.fromOffset(
			centre.X + math.cos(angle) * radius,
			centre.Y + math.sin(angle) * radius
		)

		local scatter = TweenService:Create(coin, SCATTER_TWEEN, {
			Position = landing,
			Rotation = (math.random() - 0.5) * 220,
		})

		local scatterConn
		scatterConn = scatter.Completed:Connect(function()
			scatterConn:Disconnect()
			-- Staggered so the cash does not vanish all at once.
			task.delay(math.random() * FADE_STAGGER_MAX, function()
				if not coin.Parent then return end
				local fade = TweenService:Create(coin, FADE_TWEEN, {
					ImageTransparency = 1,
					Size = UDim2.fromOffset(size * 0.6, size * 0.6),
				})
				local fadeConn
				fadeConn = fade.Completed:Connect(function()
					fadeConn:Disconnect()
					coin:Destroy()
					finished += 1
					if finished >= total and gui.Parent then
						gui:Destroy()
					end
				end)
				fade:Play()
			end)
		end)
		scatter:Play()
	end
end

return CashBurst
