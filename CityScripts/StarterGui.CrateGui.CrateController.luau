-- Weapon gacha (developer, 2026-11-20 evening): the crate page. Opened from the weapon panel (CRATES on an unowned
-- weapon fires ReplicatedStorage.Gacha.OpenCrates). Standard crates cost cash, Premium crates take keys bought with
-- Robux; the odds are on the page before any roll. A roll spins the reel of weapon cards and slows onto the prize
-- (the best one of ten); ten rolls then show all ten. The server (GachaService) draws and grants; this only shows.
-- Built in Edit (StarterGui.CrateGui): Panel (hidden until opened), CardTemplate (cloned for the reel and the grid).
-- Fitted to the screen by UIScaleController like every panel (the reel strip sizes itself, so it is not measured).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Gacha.Config)
local remotes = ReplicatedStorage.Gacha.Remotes
local catalog = ReplicatedStorage.Weapons:WaitForChild("Catalog")
local player = Players.LocalPlayer

local gui = script.Parent
local panel = gui:WaitForChild("Panel")
local cardTemplate = gui:WaitForChild("CardTemplate")
local reel = panel:WaitForChild("Reel")
local strip = reel:WaitForChild("Strip")
local resultLabel = panel:WaitForChild("Result")
local grid = panel:WaitForChild("Grid")
local keysLabel = panel:WaitForChild("Keys")
local standard = panel:WaitForChild("Standard")
local premium = panel:WaitForChild("Premium")

local CARD_WIDTH = 116
local CARD_GAP = 8
local REEL_CARDS = 44
local PRIZE_INDEX = 38
local SPIN = TweenInfo.new(3.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local RARITY_RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }

local rolling = false

-- Catalog entries in the crates, by rarity (for the reel's filler cards).
local function crateEntries(): { [string]: { Instance } }
	local byRarity = {}
	for _, entry in catalog:GetChildren() do
		local rarity = Config.rarityOf(entry)
		if rarity then
			byRarity[rarity] = byRarity[rarity] or {}
			table.insert(byRarity[rarity], entry)
		end
	end
	return byRarity
end

local function makeCard(weaponName: string, rarity: string, parent: Instance): Frame
	local card = cardTemplate:Clone()
	card.Name = weaponName
	card.Visible = true
	local entry = catalog:FindFirstChild(weaponName)
	local icon = card:FindFirstChild("Icon") :: ImageLabel
	icon.Image = entry and entry:GetAttribute("iconId") or ""
	;(card:FindFirstChild("NameLabel") :: TextLabel).Text = weaponName
	local rarityLabel = card:FindFirstChild("RarityLabel") :: TextLabel
	rarityLabel.Text = string.upper(rarity)
	rarityLabel.TextColor3 = Config.COLORS[rarity]
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Config.COLORS[rarity]
	end
	card.Parent = parent
	return card
end

-- A filler rarity for the reel, drawn by the Standard odds so the strip looks like the crate.
local function fillerRarity(): string
	local u = math.random()
	local acc = 0
	for _, rarity in Config.ORDER do
		acc += Config.ODDS.Standard[rarity]
		if u < acc then
			return rarity
		end
	end
	return "Common"
end

local function spinTo(prize: { weapon: string, rarity: string })
	for _, child in strip:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local entries = crateEntries()
	for i = 1, REEL_CARDS do
		local card
		if i == PRIZE_INDEX then
			card = makeCard(prize.weapon, prize.rarity, strip)
		else
			local rarity = fillerRarity()
			local list = entries[rarity] or entries.Common or {}
			local entry = list[math.random(1, math.max(1, #list))]
			card = makeCard(entry and entry.Name or "?", rarity, strip)
		end
		card.LayoutOrder = i
	end
	-- The prize card's centre under the marker, a random spot within the card so the stop is not identical.
	local reelWidth = reel.Size.X.Offset -- the strip moves in the reel's own (unscaled) offsets
	local prizeCentre = (PRIZE_INDEX - 1) * (CARD_WIDTH + CARD_GAP) + CARD_WIDTH / 2
	local jitter = (math.random() - 0.5) * (CARD_WIDTH * 0.6)
	strip.Position = UDim2.fromOffset(0, 0)
	local tween = TweenService:Create(strip, SPIN, { Position = UDim2.fromOffset(reelWidth / 2 - prizeCentre - jitter, 0) })
	tween:Play()
	tween.Completed:Wait()
end

local function showResults(results: { any })
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	grid.Visible = #results > 1
	if #results > 1 then
		for i, result in results do
			makeCard(result.weapon or "?", result.rarity, grid).LayoutOrder = i
		end
	end
	local best = results[1]
	for _, result in results do
		if RARITY_RANK[result.rarity] > RARITY_RANK[best.rarity] then
			best = result
		end
	end
	local refund = 0
	for _, result in results do
		refund += result.cash or 0
	end
	local text = if #results == 1 then `{best.weapon} ({string.upper(best.rarity)})` else `Best: {best.weapon} ({string.upper(best.rarity)})`
	if refund > 0 then
		text ..= `. Duplicates paid {refund} cash.`
	end
	resultLabel.Text = text
	resultLabel.TextColor3 = Config.COLORS[best.rarity]
end

local function roll(count: number, crate: string)
	if rolling then
		return
	end
	rolling = true
	grid.Visible = false
	resultLabel.Text = ""
	local ok, answer = pcall(function()
		return remotes.Roll:InvokeServer(count, crate)
	end)
	if not ok or typeof(answer) ~= "table" then
		resultLabel.Text = "Something went wrong. Try again."
		resultLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
		rolling = false
		return
	end
	if not answer.ok then
		resultLabel.Text = tostring(answer.message)
		resultLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
		rolling = false
		return
	end
	local results = answer.results
	local best = results[1]
	for _, result in results do
		if RARITY_RANK[result.rarity] > RARITY_RANK[best.rarity] then
			best = result
		end
	end
	spinTo(best)
	showResults(results)
	rolling = false
end

local function refreshKeys()
	keysLabel.Text = `PREMIUM KEYS: {player:GetAttribute("GachaKeys") or 0}`
end

-- Live Robux prices (managed pricing can differ by region); the list price until the product exists.
local function refreshPrices()
	for _, product in Config.KEY_PRODUCTS do
		local button = premium:FindFirstChild(if product.keys == 1 then "Buy1" else "Buy10") :: TextButton?
		if button then
			local robux = product.robux
			if product.productId ~= 0 then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfoAsync(product.productId, Enum.InfoType.Product)
				end)
				if ok and info and info.PriceInRobux then
					robux = info.PriceInRobux
				end
			end
			button.Text = `{product.keys} {if product.keys == 1 then "KEY" else "KEYS"}  R${robux}`
		end
	end
end

local function open()
	if player:GetAttribute("GachaAllowed") == false then
		return -- the weapon panel still sells directly to this player
	end
	refreshKeys()
	task.spawn(refreshPrices)
	panel.Visible = true
end

local function close()
	if not rolling then
		panel.Visible = false
	end
end

standard:WaitForChild("Roll1").Activated:Connect(function() roll(1, "Standard") end)
standard:WaitForChild("Roll10").Activated:Connect(function() roll(10, "Standard") end)
premium:WaitForChild("Open1").Activated:Connect(function() roll(1, "Premium") end)
premium:WaitForChild("Open10").Activated:Connect(function() roll(10, "Premium") end)
premium:WaitForChild("Buy1").Activated:Connect(function() remotes.BuyKeys:FireServer("PremiumKey1") end)
premium:WaitForChild("Buy10").Activated:Connect(function() remotes.BuyKeys:FireServer("PremiumKey10") end)
panel:WaitForChild("Close").Activated:Connect(close)
ReplicatedStorage.Gacha:WaitForChild("OpenCrates").Event:Connect(open)
player:GetAttributeChangedSignal("GachaKeys"):Connect(refreshKeys)

standard:WaitForChild("Odds").Text = Config.oddsText("Standard")
premium:WaitForChild("Odds").Text = Config.oddsText("Premium")
standard.Roll1.Text = `ROLL  {Config.ROLL_PRICE}`
standard.Roll10.Text = `ROLL 10  {Config.TEN_ROLL_PRICE}`
panel:WaitForChild("Pity").Text = `Epic or better within {Config.PITY_EPIC} rolls, Legendary within {Config.PITY_LEGENDARY}. Duplicates pay cash.`
