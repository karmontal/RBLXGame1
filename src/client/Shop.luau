--!strict
-- Shop window: Game Passes and Developer Products with their Roblox icons and
-- live prices. Purchases are prompted here; the server grants them.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Monetization"))
local Lang = require(script.Parent.Lang)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Shop = {}

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

-- Translated name/description, falling back to store.json text for new items.
local function itemText(item: Monetization.Item, field: string): string
	local key = "item." .. item.Key .. "." .. field
	local text = Lang.T(key)
	if text == key then
		return if field == "name" then item.Name else item.Description
	end
	return text
end

local function fetchInfo(item: Monetization.Item, infoType: Enum.InfoType): (number?, number?)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(item.Id, infoType)
	end)
	if not ok or not info then
		return nil, nil
	end
	local iconId = tonumber(info.IconImageAssetId)
	return tonumber(info.PriceInRobux), if iconId and iconId > 0 then iconId else nil
end

local function makeCard(list: ScrollingFrame, item: Monetization.Item, isPass: boolean, order: number)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 72)
	card.BackgroundColor3 = Ui.Colors.Card
	card.Parent = list
	Ui.Corner(card, 10)

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 6, 0.5, 0)
	icon.Size = UDim2.fromOffset(60, 60)
	icon.BackgroundColor3 = Color3.fromRGB(80, 65, 120)
	icon.ScaleType = Enum.ScaleType.Crop
	icon.Parent = card
	Ui.Corner(icon, 10)
	local fallback = Ui.Label(icon, { Text = FALLBACK_ICONS[item.Key] or "⭐", Size = UDim2.fromScale(1, 1) })

	local name = Ui.Label(card, {
		Position = UDim2.fromOffset(74, 6),
		Size = UDim2.new(1, -184, 0, 26),
	})
	local description = Ui.Label(card, {
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(74, 34),
		Size = UDim2.new(1, -184, 0, 32),
		TextWrapped = true,
		TextColor3 = Ui.Colors.SubText,
	})

	local button = Ui.Button(card, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(96, 40),
	})

	local robux: number? = nil
	local function refresh()
		name.Text = itemText(item, "name")
		description.Text = itemText(item, "desc")
		name.TextXAlignment = Lang.Align()
		description.TextXAlignment = Lang.Align()
		if item.Id == 0 then
			button.Text = Lang.T("ui.soon")
			button.BackgroundColor3 = Ui.Colors.Gray
			button.Active = false
		elseif isPass and player:GetAttribute("Pass_" .. item.Key) then
			button.Text = Lang.T("ui.owned")
			button.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
			button.Active = false
		else
			button.Text = if robux then "R$ " .. robux else Lang.T("ui.buy")
			button.BackgroundColor3 = Ui.Colors.Green
			button.Active = true
		end
	end

	if item.Id ~= 0 then
		task.spawn(function()
			local price, iconId = fetchInfo(item, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			robux = price
			if iconId then
				icon.Image = "rbxassetid://" .. iconId
				fallback.Visible = false
			end
			refresh()
		end)
	end
	refresh()
	Lang.Changed:Connect(refresh)
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

function Shop.Mount(gui: ScreenGui, sideBar: Frame)
	local openButton = Ui.Button(sideBar, {
		Name = "ShopButton",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(100, 40),
		BackgroundColor3 = Ui.Colors.Orange,
	})
	Lang.Bind(openButton, "raw", function()
		return { text = "🛒 " .. Lang.T("ui.shop") }
	end)

	local window, title = Ui.Window(gui, "Shop", Vector2.new(500, 520))
	Lang.Bind(title, "ui.shop")

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 48)
	list.Size = UDim2.new(1, -20, 1, -58)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function header(key: string)
		local label = Ui.Label(list, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -8, 0, 26),
			TextColor3 = Color3.fromRGB(255, 220, 80),
		})
		Lang.Bind(label, key)
		local function align()
			label.TextXAlignment = Lang.Align()
		end
		align()
		Lang.Changed:Connect(align)
	end

	header("ui.passes")
	for _, pass in Monetization.GamePasses do
		makeCard(list, pass, true, nextOrder())
	end
	header("ui.boosts")
	for _, product in Monetization.Products do
		makeCard(list, product, false, nextOrder())
	end

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
	end)
end

return Shop
