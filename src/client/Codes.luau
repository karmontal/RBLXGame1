--!strict
-- "Codes" button + small window to redeem marketing codes. The server
-- (CodeService) validates everything and answers with a localized message.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(script.Parent.Lang)
local Ui = require(script.Parent.Ui)

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode") :: RemoteFunction

local Codes = {}

function Codes.Mount(gui: ScreenGui, sideBar: Frame)
	local openButton = Ui.Button(sideBar, {
		Name = "CodesButton",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(100, 40),
		BackgroundColor3 = Ui.Colors.Accent,
	})
	Lang.Bind(openButton, "raw", function()
		return { text = "🎁 " .. Lang.T("ui.codes") }
	end)

	local window, title = Ui.Window(gui, "Codes", Vector2.new(380, 210))
	window.Size = UDim2.new(0.9, 0, 0, 210)
	Lang.Bind(title, "ui.redeemTitle")

	local input = Instance.new("TextBox")
	input.Position = UDim2.fromOffset(14, 50)
	input.Size = UDim2.new(1, -28, 0, 44)
	input.BackgroundColor3 = Ui.Colors.Card
	input.Font = Enum.Font.FredokaOne
	input.PlaceholderColor3 = Color3.fromRGB(160, 150, 190)
	input.Text = ""
	input.TextScaled = true
	input.TextColor3 = Ui.Colors.Text
	input.ClearTextOnFocus = false
	input.Parent = window
	Ui.Corner(input, 10)
	Lang.Bind(input, "ui.codePlaceholder")

	local redeem = Ui.Button(window, {
		Position = UDim2.fromOffset(14, 102),
		Size = UDim2.new(1, -28, 0, 42),
		BackgroundColor3 = Ui.Colors.Green,
	})
	Lang.Bind(redeem, "ui.redeem")

	local status = Ui.Label(window, {
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(14, 152),
		Size = UDim2.new(1, -28, 0, 44),
		TextWrapped = true,
		Text = "",
	})

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
			success, message = false, { k = "code.noServer" }
		end
		status.Text = Lang.Render(message)
		status.TextColor3 = if success then Ui.Colors.Money else Color3.fromRGB(255, 120, 120)
		if success then
			input.Text = ""
		end
		redeem.Text = Lang.T("ui.redeem")
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
end

return Codes
