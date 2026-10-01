--!strict
-- Admin command bar, shown only to players the server marks with a Role
-- attribute (Owner/Admin). Every command is permission-checked on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand") :: RemoteFunction
local player = Players.LocalPlayer

local AdminPanel = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function AdminPanel.Mount(gui: ScreenGui)
	local openButton = Instance.new("TextButton")
	openButton.Name = "AdminButton"
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 16, 0.5, 124)
	openButton.Size = UDim2.fromOffset(110, 52)
	openButton.BackgroundColor3 = Color3.fromRGB(220, 60, 70)
	openButton.Font = Enum.Font.FredokaOne
	openButton.Text = "🛡️ ADMIN"
	openButton.TextScaled = true
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Visible = false
	openButton.Parent = gui
	corner(openButton, 12)

	local window = Instance.new("Frame")
	window.Name = "AdminPanel"
	window.AnchorPoint = Vector2.new(0.5, 1)
	window.Position = UDim2.new(0.5, 0, 1, -16)
	window.Size = UDim2.new(0.95, 0, 0, 300)
	window.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
	window.BackgroundTransparency = 0.1
	window.Visible = false
	window.Parent = gui
	corner(window, 12)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(640, 300)
	sizeLimit.Parent = window

	local output = Instance.new("ScrollingFrame")
	output.Position = UDim2.fromOffset(10, 10)
	output.Size = UDim2.new(1, -20, 1, -70)
	output.BackgroundTransparency = 1
	output.BorderSizePixel = 0
	output.ScrollBarThickness = 6
	output.AutomaticCanvasSize = Enum.AutomaticSize.Y
	output.CanvasSize = UDim2.new()
	output.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = output

	local input = Instance.new("TextBox")
	input.AnchorPoint = Vector2.new(0, 1)
	input.Position = UDim2.new(0, 10, 1, -10)
	input.Size = UDim2.new(1, -20, 0, 44)
	input.BackgroundColor3 = Color3.fromRGB(45, 38, 70)
	input.Font = Enum.Font.Code
	input.PlaceholderText = ":help   (Enter to run)"
	input.PlaceholderColor3 = Color3.fromRGB(150, 140, 180)
	input.Text = ""
	input.TextSize = 18
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.TextColor3 = Color3.new(1, 1, 1)
	input.ClearTextOnFocus = false
	input.Parent = window
	corner(input, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.Parent = input

	local lineCount = 0
	local function log(text: string, color: Color3)
		lineCount += 1
		local line = Instance.new("TextLabel")
		line.LayoutOrder = lineCount
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, -8, 0, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.Font = Enum.Font.Code
		line.TextSize = 15
		line.TextWrapped = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = color
		line.Text = text
		line.Parent = output
		task.defer(function()
			output.CanvasPosition = Vector2.new(0, output.AbsoluteCanvasSize.Y)
		end)
	end

	local history: { string } = {}
	local historyIndex = 0
	local running = false

	local function execute(command: string)
		if running or command == "" then
			return
		end
		running = true
		table.insert(history, command)
		historyIndex = #history + 1
		log("> " .. command, Color3.fromRGB(255, 220, 90))
		local ok, result = pcall(function()
			return remote:InvokeServer(command)
		end)
		log(if ok then tostring(result) else "Couldn't reach the server.", Color3.fromRGB(220, 220, 240))
		running = false
	end

	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local command = input.Text
			input.Text = ""
			execute(command)
			input:CaptureFocus()
		end
	end)

	UserInputService.InputBegan:Connect(function(io)
		if not input:IsFocused() or #history == 0 then
			return
		end
		if io.KeyCode == Enum.KeyCode.Up then
			historyIndex = math.max(1, historyIndex - 1)
			input.Text = history[historyIndex]
		elseif io.KeyCode == Enum.KeyCode.Down then
			historyIndex = math.min(#history + 1, historyIndex + 1)
			input.Text = history[historyIndex] or ""
		end
	end)

	local greeted = false
	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible and not greeted then
			greeted = true
			log("Role: " .. tostring(player:GetAttribute("Role")) .. ". Type :help for commands.", Color3.fromRGB(120, 255, 140))
		end
	end)

	local function refreshRole()
		local hasRole = player:GetAttribute("Role") ~= nil
		openButton.Visible = hasRole
		if not hasRole then
			window.Visible = false
		end
	end
	player:GetAttributeChangedSignal("Role"):Connect(refreshRole)
	refreshRole()
end

return AdminPanel
