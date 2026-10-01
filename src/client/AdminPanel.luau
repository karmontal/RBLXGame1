--!strict
-- Admin panel: tap-to-run buttons (no typing needed) for Owner/Admin players.
-- Buttons build the same commands as the console; the server checks
-- permissions for every one and replies with a localized message.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Monetization"))
local Monsters = require(Shared:WaitForChild("Monsters"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Lang = require(script.Parent.Lang)
local Ui = require(script.Parent.Ui)

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand") :: RemoteFunction
local player = Players.LocalPlayer

local MUTATIONS = { "None", "Gold", "Diamond", "Fire", "Rainbow" }

local AdminPanel = {}

local function section(parent: Instance, order: number, titleKey: string?, cellHeight: number?, columns: number?): Frame
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -6, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	if titleKey then
		local title = Ui.Label(holder, {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 20),
			TextColor3 = Color3.fromRGB(255, 220, 80),
		})
		Lang.Bind(title, titleKey)
		local function align()
			title.TextXAlignment = Lang.Align()
		end
		align()
		Lang.Changed:Connect(align)
	end

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = 1
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = holder
	local gridLayout = Instance.new("UIGridLayout")
	local cols = columns or 3
	gridLayout.CellSize = UDim2.new(1 / cols, -6, 0, cellHeight or 34)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	return grid
end

local function scroller(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 5
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

function AdminPanel.Mount(gui: ScreenGui, sideBar: Frame)
	local openButton = Ui.Button(sideBar, {
		Name = "AdminButton",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(100, 40),
		BackgroundColor3 = Ui.Colors.Red,
		Visible = false,
	})
	Lang.Bind(openButton, "raw", function()
		return { text = "🛡️ " .. Lang.T("ui.admin") }
	end)

	local window, title = Ui.Window(gui, "AdminPanel", Vector2.new(680, 480))
	Lang.Bind(title, "raw", function()
		return { text = "🛡️ " .. Lang.T("ui.admin") }
	end)

	-- Status line ---------------------------------------------------------------
	local status = Ui.Label(window, {
		Font = Enum.Font.GothamMedium,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -6),
		Size = UDim2.new(1, -24, 0, 30),
		TextWrapped = true,
		TextColor3 = Ui.Colors.SubText,
		Text = "",
	})

	local busy = false
	local function run(command: string)
		if busy then
			return
		end
		busy = true
		status.Text = "..."
		local ok, result = pcall(function()
			return remote:InvokeServer(command)
		end)
		status.Text = if ok then Lang.Render(result) else Lang.T("code.noServer")
		busy = false
	end

	-- Tabs ----------------------------------------------------------------------
	local tabBar = Instance.new("Frame")
	tabBar.Position = UDim2.fromOffset(12, 46)
	tabBar.Size = UDim2.new(1, -24, 0, 32)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function showTab(name: string)
		for key, page in pages do
			page.Visible = key == name
			tabButtons[key].BackgroundColor3 = if key == name then Ui.Colors.Accent else Ui.Colors.Card
		end
	end
	local function addTab(name: string, labelKey: string, order: number): Frame
		local button = Ui.Button(tabBar, {
			LayoutOrder = order,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			BackgroundColor3 = Ui.Colors.Card,
		})
		Lang.Bind(button, labelKey)
		button.Activated:Connect(function()
			showTab(name)
		end)
		tabButtons[name] = button
		local page = Instance.new("Frame")
		page.Name = name
		page.Position = UDim2.fromOffset(12, 84)
		page.Size = UDim2.new(1, -24, 1, -124)
		page.BackgroundTransparency = 1
		page.Visible = false
		page.Parent = window
		pages[name] = page
		return page
	end

	local playersPage = addTab("Players", "ui.tabPlayers", 1)
	local monstersPage = addTab("Monsters", "ui.tabMonsters", 2)
	local serverPage = addTab("Server", "ui.tabServer", 3)

	-- Target selection (shared by Players + Monsters tabs) --------------------
	local target: string? = nil -- player Name or "all"
	local targetLabels: { TextLabel } = {}
	local function targetName(): string
		if target == "all" then
			return Lang.T("ui.everyone")
		end
		return target or "—"
	end
	local function refreshTargetLabels()
		for _, label in targetLabels do
			label.Text = Lang.T("ui.selected", { name = targetName() })
		end
	end
	Lang.Changed:Connect(refreshTargetLabels)

	local function withTarget(build: (string) -> string): () -> ()
		return function()
			if not target then
				status.Text = Lang.T("ui.pickPlayer")
				return
			end
			run(build(target))
		end
	end

	-- Players tab -----------------------------------------------------------
	local playerList = scroller(playersPage, UDim2.fromScale(0, 0), UDim2.new(0.34, -6, 1, 0))
	local playerButtons: { [string]: TextButton } = {}
	local function refreshPlayerList()
		for _, button in playerButtons do
			button:Destroy()
		end
		table.clear(playerButtons)
		local entries = { { id = "all", text = Lang.T("ui.everyone") } }
		for _, other in Players:GetPlayers() do
			table.insert(entries, { id = other.Name, text = other.DisplayName })
		end
		for index, entry in entries do
			local button = Ui.Button(playerList, {
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, 34),
				Text = entry.text,
				BackgroundColor3 = if target == entry.id then Ui.Colors.Accent else Ui.Colors.Card,
			})
			button.Activated:Connect(function()
				target = entry.id
				refreshPlayerList()
				refreshTargetLabels()
			end)
			playerButtons[entry.id] = button
		end
		if target and target ~= "all" and not Players:FindFirstChild(target) then
			target = nil
			refreshTargetLabels()
		end
	end
	Players.PlayerAdded:Connect(refreshPlayerList)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayerList)
	end)
	Lang.Changed:Connect(refreshPlayerList)

	local actions = scroller(playersPage, UDim2.new(0.34, 6, 0, 0), UDim2.new(0.66, -6, 1, 0))
	local playersTarget = Ui.Label(actions, {
		LayoutOrder = 0,
		Size = UDim2.new(1, -6, 0, 22),
		TextColor3 = Ui.Colors.Money,
	})
	table.insert(targetLabels, playersTarget)

	local function button(grid: Frame, labelKey: string | () -> string, color: Color3?, onClick: () -> ()): TextButton
		local b = Ui.Button(grid, { BackgroundColor3 = color or Ui.Colors.Card })
		if type(labelKey) == "function" then
			local function render()
				b.Text = labelKey()
			end
			render()
			Lang.Changed:Connect(render)
		else
			Lang.Bind(b, labelKey)
		end
		b.Activated:Connect(onClick)
		return b
	end

	local cashGrid = section(actions, 1, "ui.cash")
	for _, amount in { { "+10K", 10_000 }, { "+100K", 100_000 }, { "+1M", 1_000_000 } } do
		button(cashGrid, function()
			return amount[1]
		end, Ui.Colors.Green, withTarget(function(t)
			return ":givecash " .. t .. " " .. amount[2]
		end))
	end

	local durationHours: number? = 1
	local durationGrid = section(actions, 2, "ui.duration")
	local durationButtons: { [TextButton]: number? } = {}
	local function refreshDurations()
		for b, hours in durationButtons do
			b.BackgroundColor3 = if hours == durationHours then Ui.Colors.Accent else Ui.Colors.Card
		end
	end
	for _, option in { { "ui.hour1", 1 }, { "ui.hour24", 24 }, { "ui.forever", nil } } do
		local b = button(durationGrid, option[1] :: string, nil, function()
			durationHours = option[2] :: number?
			refreshDurations()
		end)
		durationButtons[b] = option[2] :: number?
	end
	refreshDurations()

	local passGrid = section(actions, 3, "ui.passPerks", 34, 2)
	for _, pass in Monetization.GamePasses do
		button(passGrid, "item." .. pass.Key .. ".name", Color3.fromRGB(70, 110, 200), withTarget(function(t)
			return ":givepass " .. t .. " " .. pass.Key .. (if durationHours then " " .. durationHours else "")
		end))
	end
	local removeGrid = section(actions, 4, nil, 34, 1)
	button(removeGrid, "ui.removePerks", Ui.Colors.Gray, function()
		if not target then
			status.Text = Lang.T("ui.pickPlayer")
			return
		end
		local who = target
		for index, pass in Monetization.GamePasses do
			if index > 1 then
				task.wait(0.35) -- server allows ~3 commands per second
			end
			run(":removepass " .. who .. " " .. pass.Key)
		end
	end)

	local miscGrid = section(actions, 5, "ui.actions")
	button(miscGrid, "ui.luckyEgg", Ui.Colors.Orange, withTarget(function(t)
		return ":luckyegg " .. t .. " 1"
	end))
	button(miscGrid, "ui.unlockBase", nil, withTarget(function(t)
		return ":unlock " .. t
	end))
	button(miscGrid, "ui.fast", nil, withTarget(function(t)
		return ":speed " .. t .. " 32"
	end))
	button(miscGrid, "ui.normalSpeed", nil, withTarget(function(t)
		return ":speed " .. t .. " 16"
	end))
	button(miscGrid, "ui.teleport", nil, withTarget(function(t)
		return ":tp " .. t
	end))
	button(miscGrid, "ui.bring", nil, withTarget(function(t)
		return ":bring " .. t
	end))
	button(miscGrid, "ui.kick", Ui.Colors.Red, withTarget(function(t)
		return ":kick " .. t
	end))

	local ownerGrid = section(actions, 6, nil, 34, 2)
	button(ownerGrid, "ui.makeAdmin", Color3.fromRGB(200, 150, 30), withTarget(function(t)
		return ":admin " .. t
	end))
	button(ownerGrid, "ui.removeAdmin", Ui.Colors.Gray, withTarget(function(t)
		return ":unadmin " .. t
	end))

	-- Monsters tab ----------------------------------------------------------
	local monstersScroll = scroller(monstersPage, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	local monstersTarget = Ui.Label(monstersScroll, {
		LayoutOrder = 0,
		Size = UDim2.new(1, -6, 0, 22),
		TextColor3 = Ui.Colors.Money,
	})
	table.insert(targetLabels, monstersTarget)

	local selectedMutation = "None"
	local mutationGrid = section(monstersScroll, 1, "ui.mutation", 32, 5)
	local mutationButtons: { [string]: TextButton } = {}
	local function refreshMutations()
		for name, b in mutationButtons do
			b.BackgroundColor3 = if name == selectedMutation then Ui.Colors.Accent else Ui.Colors.Card
		end
	end
	for _, name in MUTATIONS do
		mutationButtons[name] = button(mutationGrid, if name == "None" then "ui.none" else "mutation." .. name, nil, function()
			selectedMutation = name
			refreshMutations()
		end)
	end
	refreshMutations()

	local selectedMonster: string? = nil
	local monsterGrid = section(monstersScroll, 2, "ui.tabMonsters", 34, 3)
	local monsterButtons: { [string]: TextButton } = {}
	local function refreshMonsters()
		for id, b in monsterButtons do
			local rarity = Rarities.ByName[Monsters.ById[id].Rarity]
			b.BackgroundColor3 = if id == selectedMonster then Ui.Colors.Accent else rarity.Color:Lerp(Color3.new(0, 0, 0), 0.45)
		end
	end
	for _, monster in Monsters.List do
		monsterButtons[monster.Id] = button(monsterGrid, function()
			return monster.DisplayName
		end, nil, function()
			selectedMonster = monster.Id
			refreshMonsters()
		end)
	end
	refreshMonsters()

	local monsterActions = section(monstersScroll, 3, nil, 38, 2)
	button(monsterActions, "ui.giveToTarget", Ui.Colors.Green, function()
		if not selectedMonster then
			status.Text = Lang.T("ui.pickMonster")
		elseif not target then
			status.Text = Lang.T("ui.pickPlayer")
		else
			run(":givemonster " .. target .. " " .. selectedMonster .. " " .. selectedMutation)
		end
	end)
	button(monsterActions, "ui.spawnOnBelt", Ui.Colors.Orange, function()
		if not selectedMonster then
			status.Text = Lang.T("ui.pickMonster")
		else
			run(":spawn " .. selectedMonster .. " " .. selectedMutation)
		end
	end)

	-- Server tab --------------------------------------------------------------
	local serverScroll = scroller(serverPage, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))

	local function textRow(order: number, titleKey: string, placeholderKey: string, actionKey: string, onSubmit: (string) -> ())
		local grid = section(serverScroll, order, titleKey, 40, 1)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Parent = grid
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, -96, 1, 0)
		box.BackgroundColor3 = Ui.Colors.Card
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 16
		box.Text = ""
		box.ClearTextOnFocus = false
		box.TextColor3 = Ui.Colors.Text
		box.PlaceholderColor3 = Color3.fromRGB(150, 140, 180)
		box.Parent = row
		Ui.Corner(box, 8)
		Lang.Bind(box, placeholderKey)
		local send = Ui.Button(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 90, 1, 0),
			BackgroundColor3 = Ui.Colors.Green,
		})
		Lang.Bind(send, actionKey)
		local function submit()
			if box.Text ~= "" then
				onSubmit(box.Text)
				box.Text = ""
			end
		end
		send.Activated:Connect(submit)
		box.FocusLost:Connect(function(enter)
			if enter then
				submit()
			end
		end)
	end

	textRow(1, "ui.announcement", "ui.announcePlaceholder", "ui.send", function(text)
		run(":announce " .. text)
	end)
	local adminsGrid = section(serverScroll, 2, nil, 36, 1)
	button(adminsGrid, "ui.listAdmins", nil, function()
		run(":admins")
	end)
	textRow(3, "ui.console", "ui.consolePlaceholder", "ui.run", function(text)
		run(text)
	end)

	-- Visibility ----------------------------------------------------------------
	local function refreshRole()
		local role = player:GetAttribute("Role")
		openButton.Visible = role ~= nil
		(ownerGrid.Parent :: Frame).Visible = role == "Owner"
		if not role then
			window.Visible = false
		end
	end
	player:GetAttributeChangedSignal("Role"):Connect(refreshRole)
	refreshRole()

	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refreshPlayerList()
			refreshTargetLabels()
		end
	end)

	showTab("Players")
	refreshPlayerList()
	refreshTargetLabels()
end

return AdminPanel
