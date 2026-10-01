--!strict
-- Monster Index: every monster grouped by rarity, with its mutations. Only
-- variants the player has owned (bought, stolen, hatched or gifted) are
-- revealed; the rest stay as dark silhouettes with hidden details.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Monsters = require(Shared:WaitForChild("Monsters"))
local Mutations = require(Shared:WaitForChild("Mutations"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Lang = require(script.Parent.Lang)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local MUTATION_ORDER = { "None", "Gold", "Diamond", "Fire", "Rainbow" }
local NORMAL_COLOR = Color3.fromRGB(110, 170, 120)

local MonsterIndex = {}

local function discovered(): { [string]: { [string]: boolean } }
	local raw = player:GetAttribute("Discovered")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(data) == "table" then data else {}
end

local function fillViewport(viewport: ViewportFrame, monsterId: string)
	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("MonsterTemplates")
		local template = templates:WaitForChild(monsterId) :: Model
		local model = template:Clone()
		model.Parent = viewport
		local cf, size = model:GetBoundingBox()
		local distance = math.max(size.X, size.Y, size.Z) * 1.5 + 1
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		local eye = cf.Position + Vector3.new(distance * 0.45, size.Y * 0.25, -distance)
		camera.CFrame = CFrame.lookAt(eye, cf.Position)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end)
end

type Row = {
	Monster: Monsters.Monster,
	Viewport: ViewportFrame,
	Name: TextLabel,
	Stats: TextLabel,
	Chips: { [string]: TextLabel },
}

function MonsterIndex.Mount(gui: ScreenGui)
	local openButton = Ui.Button(gui, {
		Name = "IndexButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 110),
		Size = UDim2.fromOffset(110, 30),
		BackgroundColor3 = Color3.fromRGB(70, 110, 200),
	})
	Ui.Scaled(openButton)
	Lang.Bind(openButton, "raw", function()
		return { text = "📖 " .. Lang.T("ui.index") }
	end)

	local window, title = Ui.Window(gui, "MonsterIndex", Vector2.new(620, 560))
	Lang.Bind(title, "ui.indexTitle")

	local progress = Ui.Label(window, {
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 22),
		TextColor3 = Ui.Colors.Money,
	})
	local hint = Ui.Label(window, {
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 0, 18),
		TextColor3 = Ui.Colors.SubText,
	})
	Lang.Bind(hint, "ui.indexHint")

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 90)
	list.Size = UDim2.new(1, -20, 1, -100)
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

	local rows: { Row } = {}
	local headers: { { Label: TextLabel, Rarity: string } } = {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, rarity in Rarities.List do
		local pool = table.clone(Monsters.ByRarity[rarity.Name] or {})
		if #pool == 0 then
			continue
		end
		table.sort(pool, function(a, b)
			return a.Price < b.Price
		end)
		local header = Ui.Label(list, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -8, 0, 24),
			TextColor3 = if rarity.Name == "Secret" then Color3.fromRGB(200, 200, 210) else rarity.Color,
		})
		table.insert(headers, { Label = header, Rarity = rarity.Name })

		for _, monster in pool do
			local card = Instance.new("Frame")
			card.LayoutOrder = nextOrder()
			card.Size = UDim2.new(1, -8, 0, 84)
			card.BackgroundColor3 = Ui.Colors.Card
			card.Parent = list
			Ui.Corner(card, 10)

			local viewport = Instance.new("ViewportFrame")
			viewport.AnchorPoint = Vector2.new(0, 0.5)
			viewport.Position = UDim2.new(0, 6, 0.5, 0)
			viewport.Size = UDim2.fromOffset(72, 72)
			viewport.BackgroundColor3 = Color3.fromRGB(80, 65, 120)
			viewport.Ambient = Color3.fromRGB(200, 200, 200)
			viewport.LightColor = Color3.new(1, 1, 1)
			viewport.Parent = card
			Ui.Corner(viewport, 10)
			fillViewport(viewport, monster.Id)

			local name = Ui.Label(card, { Position = UDim2.fromOffset(86, 4), Size = UDim2.new(1, -96, 0, 26) })
			local stats = Ui.Label(card, {
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(86, 30),
				Size = UDim2.new(1, -96, 0, 18),
				TextColor3 = Ui.Colors.Money,
			})

			local chipRow = Instance.new("Frame")
			chipRow.Position = UDim2.fromOffset(86, 54)
			chipRow.Size = UDim2.new(1, -96, 0, 22)
			chipRow.BackgroundTransparency = 1
			chipRow.Parent = card
			local chipLayout = Instance.new("UIListLayout")
			chipLayout.FillDirection = Enum.FillDirection.Horizontal
			chipLayout.Padding = UDim.new(0, 4)
			chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
			chipLayout.Parent = chipRow
			local chips = {}
			for index, mutation in MUTATION_ORDER do
				local chip = Ui.Label(chipRow, {
					LayoutOrder = index,
					Size = UDim2.new(0.2, -4, 1, 0),
					BackgroundTransparency = 0,
					Font = Enum.Font.GothamBold,
				})
				Ui.Corner(chip, 6)
				local pad = Instance.new("UIPadding")
				pad.PaddingTop = UDim.new(0, 3)
				pad.PaddingBottom = UDim.new(0, 3)
				pad.Parent = chip
				chips[mutation] = chip
			end

			table.insert(rows, { Monster = monster, Viewport = viewport, Name = name, Stats = stats, Chips = chips })
		end
	end

	local totalVariants = #Monsters.List * #MUTATION_ORDER

	local function refresh()
		local seen = discovered()
		local count = 0
		for _, header in headers do
			header.Label.Text = Lang.T("rarity." .. header.Rarity)
			header.Label.TextXAlignment = Lang.Align()
		end
		for _, row in rows do
			local variants = seen[row.Monster.Id] or {}
			local known = next(variants) ~= nil
			row.Viewport.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			row.Name.Text = if known then row.Monster.DisplayName else Lang.T("ui.unknown")
			row.Name.TextColor3 = if known then Ui.Colors.Text else Ui.Colors.SubText
			row.Stats.Text = if known
				then Lang.T("label.priceIncome", { price = Format.Money(row.Monster.Price), income = Format.Money(row.Monster.Income) })
				else Lang.T("ui.unknown")
			row.Name.TextXAlignment = Lang.Align()
			row.Stats.TextXAlignment = Lang.Align()
			for mutation, chip in row.Chips do
				local has = variants[mutation] == true
				if has then
					count += 1
				end
				local info = Mutations.ByName[mutation]
				chip.Text = if has then (if mutation == "None" then Lang.T("ui.normal") else Lang.T("mutation." .. mutation)) else "?"
				chip.BackgroundColor3 = if has then (info and info.Color or NORMAL_COLOR) else Color3.fromRGB(35, 30, 50)
				chip.TextColor3 = if has then Color3.fromRGB(20, 20, 30) else Color3.fromRGB(120, 115, 140)
				if has and mutation == "None" then
					chip.BackgroundColor3 = NORMAL_COLOR
				end
			end
		end
		progress.Text = Lang.T("ui.discovered", { count = count, total = totalVariants })
	end

	refresh()
	player:GetAttributeChangedSignal("Discovered"):Connect(refresh)
	Lang.Changed:Connect(refresh)

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
	end)
end

return MonsterIndex
