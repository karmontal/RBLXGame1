--!strict
-- Shop window: Game Passes and Developer Products. Purchases are prompted
-- here; the server grants them (MonetizationService).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Monetization"))

local player = Players.LocalPlayer

local Shop = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- Shown until (or instead of) the item's Roblox icon loads.
local FALLBACK_ICONS: { [string]: string } = {
	DoubleCash = "💰",
	SuperLock = "🔒",
	SpeedBoost = "👟",
	AutoCollect = "🧲",
	CashSmall = "💵",
	CashLarge = "💎",
	LuckyEgg = "🥚",
}

-- Live price and icon from Roblox (the icon is the one uploaded with the item).
local function fetchInfo(item: Monetization.Item, infoType: Enum.InfoType): (string, number?)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(item.Id, infoType)
	end)
	if not ok or not info then
		return "Buy", nil
	end
	local price = if info.PriceInRobux then "R$ " .. tostring(info.PriceInRobux) else "Buy"
	local iconId = tonumber(info.IconImageAssetId)
	return price, if iconId and iconId > 0 then iconId else nil
end

local function makeCard(list: Frame, item: Monetization.Item, isPass: boolean, order: number)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 86)
	card.BackgroundColor3 = Color3.fromRGB(55, 45, 85)
	card.Parent = list
	corner(card, 10)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.fromOffset(70, 70)
	icon.BackgroundColor3 = Color3.fromRGB(80, 65, 120)
	icon.ScaleType = Enum.ScaleType.Crop
	icon.Image = ""
	icon.Parent = card
	corner(icon, 12)
	local fallback = text(icon, {
		Text = FALLBACK_ICONS[item.Key] or "⭐",
		Size = UDim2.fromScale(1, 1),
	})

	text(card, {
		Text = item.Name,
		Position = UDim2.fromOffset(88, 8),
		Size = UDim2.new(1, -218, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	text(card, {
		Text = item.Description,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(88, 42),
		Size = UDim2.new(1, -218, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(210, 210, 235),
	})

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(112, 44)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.Parent = card
	corner(button, 8)

	local function refresh()
		if item.Id == 0 then
			button.Text = "Soon"
			button.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
			button.Active = false
		elseif isPass and player:GetAttribute("Pass_" .. item.Key) then
			button.Text = "Owned ✓"
			button.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
			button.Active = false
		else
			button.BackgroundColor3 = Color3.fromRGB(40, 190, 90)
			button.Active = true
		end
	end

	if item.Id ~= 0 then
		button.Text = "..."
		task.spawn(function()
			local price, iconId = fetchInfo(item, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			if iconId then
				icon.Image = "rbxassetid://" .. iconId
				fallback.Visible = false
			end
			if not (isPass and player:GetAttribute("Pass_" .. item.Key)) then
				button.Text = price
			end
		end)
	end
	refresh()
	if isPass then
		player:GetAttributeChangedSignal("Pass_" .. item.Key):Connect(refresh)
	end

	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		else
			MarketplaceService:PromptProductPurchase(player, item.Id)
		end
	end)
end

local function header(list: Frame, label: string, order: number)
	text(list, {
		Text = label,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 30),
		TextColor3 = Color3.fromRGB(255, 220, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

function Shop.Mount(gui: ScreenGui)
	local openButton = Instance.new("TextButton")
	openButton.Name = "ShopButton"
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 16, 0.5, 0)
	openButton.Size = UDim2.fromOffset(110, 52)
	openButton.BackgroundColor3 = Color3.fromRGB(255, 170, 30)
	openButton.Font = Enum.Font.FredokaOne
	openButton.Text = "🛒 SHOP"
	openButton.TextScaled = true
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Parent = gui
	corner(openButton, 12)

	local window = Instance.new("Frame")
	window.Name = "Shop"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.new(0.9, 0, 0.8, 0)
	window.BackgroundColor3 = Color3.fromRGB(30, 24, 50)
	window.Visible = false
	window.Parent = gui
	corner(window, 16)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 560)
	sizeLimit.Parent = window

	text(window, {
		Text = "SHOP",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(220, 60, 70)
	close.Font = Enum.Font.FredokaOne
	close.Text = "X"
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = window
	corner(close, 10)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 60)
	list.Size = UDim2.new(1, -24, 1, -72)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	header(list :: any, "Game Passes", nextOrder())
	for _, pass in Monetization.GamePasses do
		makeCard(list :: any, pass, true, nextOrder())
	end
	header(list :: any, "Boosts", nextOrder())
	for _, product in Monetization.Products do
		makeCard(list :: any, product, false, nextOrder())
	end

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
end

return Shop
