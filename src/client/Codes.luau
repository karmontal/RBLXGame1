--!strict
-- "Codes" button + small window to redeem marketing codes. The server
-- (CodeService) validates everything; this only sends the text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode") :: RemoteFunction

local Codes = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	corner(b, 10)
	return b
end

function Codes.Mount(gui: ScreenGui)
	local openButton = button(gui, "🎁 CODES", Color3.fromRGB(150, 80, 255))
	openButton.Name = "CodesButton"
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 16, 0.5, 62)
	openButton.Size = UDim2.fromOffset(110, 52)

	local window = Instance.new("Frame")
	window.Name = "Codes"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.new(0.9, 0, 0, 220)
	window.BackgroundColor3 = Color3.fromRGB(30, 24, 50)
	window.Visible = false
	window.Parent = gui
	corner(window, 16)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(420, 220)
	sizeLimit.Parent = window

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -80, 0, 38)
	title.Font = Enum.Font.FredokaOne
	title.Text = "REDEEM CODE"
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = window

	local close = button(window, "X", Color3.fromRGB(220, 60, 70))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(38, 38)

	local input = Instance.new("TextBox")
	input.Position = UDim2.fromOffset(16, 60)
	input.Size = UDim2.new(1, -32, 0, 48)
	input.BackgroundColor3 = Color3.fromRGB(55, 45, 85)
	input.Font = Enum.Font.FredokaOne
	input.PlaceholderText = "Enter code..."
	input.PlaceholderColor3 = Color3.fromRGB(160, 150, 190)
	input.Text = ""
	input.TextScaled = true
	input.TextColor3 = Color3.new(1, 1, 1)
	input.ClearTextOnFocus = false
	input.Parent = window
	corner(input, 10)

	local redeem = button(window, "REDEEM", Color3.fromRGB(40, 190, 90))
	redeem.Position = UDim2.fromOffset(16, 118)
	redeem.Size = UDim2.new(1, -32, 0, 46)

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(16, 172)
	status.Size = UDim2.new(1, -32, 0, 30)
	status.Font = Enum.Font.Gotham
	status.Text = ""
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Parent = window

	local pending = false
	local function submit()
		if pending or input.Text == "" then
			return
		end
		pending = true
		redeem.Text = "..."
		local ok, success, message = pcall(function()
			return remote:InvokeServer(input.Text)
		end)
		if not ok then
			success, message = false, "Couldn't reach the server, try again."
		end
		status.Text = tostring(message)
		status.TextColor3 = if success then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 120, 120)
		if success then
			input.Text = ""
		end
		redeem.Text = "REDEEM"
		pending = false
	end

	redeem.Activated:Connect(submit)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	openButton.Activated:Connect(function()
		window.Visible = not window.Visible
		status.Text = ""
	end)
	close.Activated:Connect(function()
		window.Visible = false
	end)
end

return Codes
