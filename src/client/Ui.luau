--!strict
-- Small UI helpers shared by the HUD, shop, codes and admin panel, plus a
-- global UI scale that shrinks everything on phones.

local Workspace = game:GetService("Workspace")

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(28, 22, 44),
	Card = Color3.fromRGB(55, 45, 85),
	Accent = Color3.fromRGB(150, 80, 255),
	Green = Color3.fromRGB(40, 190, 90),
	Red = Color3.fromRGB(220, 60, 70),
	Orange = Color3.fromRGB(255, 160, 30),
	Gray = Color3.fromRGB(90, 90, 105),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(205, 205, 230),
	Money = Color3.fromRGB(120, 255, 140),
}

local scales: { UIScale } = {}

-- 1.0 on a ~1080p screen, smaller on phones/tablets (never below 0.6).
local function computeScale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1280, size.Y / 720), 0.6, 1)
end

local function refreshScales()
	local value = computeScale()
	for _, scale in scales do
		scale.Scale = value
	end
end

-- Adds a UIScale that follows the screen size.
function Ui.Scaled<T>(object: T & GuiObject): T
	local scale = Instance.new("UIScale")
	scale.Scale = computeScale()
	scale.Parent = object
	table.insert(scales, scale)
	return object
end

function Ui.Corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

function Ui.Stroke(parent: Instance, color: Color3?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.new(0, 0, 0)
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = 0.3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

function Ui.Label(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Ui.Colors.Text
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function Ui.Button(parent: Instance, props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Ui.Colors.Accent
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Ui.Colors.Text
	button.TextScaled = true
	button.AutoButtonColor = true
	for key, value in props do
		(button :: any)[key] = value
	end
	button.Parent = parent
	Ui.Corner(button, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = button
	return button
end

-- A centered modal window with a title and a close button.
function Ui.Window(gui: ScreenGui, name: string, maxSize: Vector2): (Frame, TextLabel, TextButton)
	local window = Instance.new("Frame")
	window.Name = name
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.92, 0.85)
	window.BackgroundColor3 = Ui.Colors.Panel
	window.Visible = false
	window.ZIndex = 5
	window.Parent = gui
	Ui.Corner(window, 14)
	Ui.Stroke(window, Ui.Colors.Accent, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = window

	local title = Ui.Label(window, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -64, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = Ui.Button(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Ui.Colors.Red,
		Text = "✕",
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)
	return window, title, close
end

local camera = Workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = Workspace.CurrentCamera
	if newCamera then
		newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
		refreshScales()
	end
end)

return Ui
