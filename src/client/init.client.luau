--!strict
-- Client: HUD (cash, income, carrying), notifications, owner-specific prompt
-- visibility and rainbow mutation effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

-- HUD ---------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

require(script.Shop).Mount(gui)
require(script.Codes).Mount(gui)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -16)
panel.Size = UDim2.fromOffset(240, 86)
panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
panel.BackgroundTransparency = 0.25
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local function hudLabel(y: number, height: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, height)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Parent = panel
	return label
end

local cashLabel = hudLabel(8, 40, Color3.fromRGB(120, 255, 140))
local incomeLabel = hudLabel(50, 26, Color3.fromRGB(230, 230, 255))

local carryLabel = Instance.new("TextLabel")
carryLabel.AnchorPoint = Vector2.new(0.5, 0)
carryLabel.Position = UDim2.new(0.5, 0, 0, 70)
carryLabel.Size = UDim2.fromOffset(460, 44)
carryLabel.BackgroundTransparency = 1
carryLabel.Font = Enum.Font.FredokaOne
carryLabel.TextScaled = true
carryLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
carryLabel.TextStrokeTransparency = 0
carryLabel.Visible = false
carryLabel.Parent = gui

local function refreshHud()
	cashLabel.Text = Format.Money((player:GetAttribute("Cash") :: number?) or 0)
	incomeLabel.Text = Format.Money((player:GetAttribute("Income") :: number?) or 0) .. " / sec"
	local carrying = player:GetAttribute("Carrying") :: string?
	carryLabel.Visible = carrying ~= nil
	if carrying then
		carryLabel.Text = "Carrying " .. carrying .. " — run to your base!"
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshHud)
player:GetAttributeChangedSignal("Income"):Connect(refreshHud)
player:GetAttributeChangedSignal("Carrying"):Connect(refreshHud)
refreshHud()

-- Notifications ------------------------------------------------------------

local toastList = Instance.new("Frame")
toastList.AnchorPoint = Vector2.new(0.5, 0)
toastList.Position = UDim2.new(0.5, 0, 0, 120)
toastList.Size = UDim2.fromOffset(480, 300)
toastList.BackgroundTransparency = 1
toastList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = toastList

local toastColors = {
	info = Color3.fromRGB(255, 255, 255),
	cash = Color3.fromRGB(120, 255, 140),
	error = Color3.fromRGB(255, 110, 110),
	rare = Color3.fromRGB(255, 200, 60),
}

notifyRemote.OnClientEvent:Connect(function(text: string, kind: string)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(480, 34)
	toast.BackgroundTransparency = 1
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = toastColors[kind] or toastColors.info
	toast.TextStrokeTransparency = 0.1
	toast.Text = text
	toast.Parent = toastList
	task.delay(2.5, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		toast:Destroy()
	end)
end)

-- Prompt visibility ----------------------------------------------------------
-- OwnerOnly prompts show only to the base owner, NotOwner prompts (Steal) only
-- to everyone else. The server validates every trigger regardless.

local function updatePrompt(prompt: ProximityPrompt)
	local ownerOnly = prompt:GetAttribute("OwnerOnly") :: number?
	local notOwner = prompt:GetAttribute("NotOwner") :: number?
	if ownerOnly ~= nil then
		prompt.Enabled = ownerOnly == player.UserId
	elseif notOwner ~= nil then
		prompt.Enabled = notOwner ~= player.UserId
	end
end

local function watchPrompt(prompt: ProximityPrompt)
	updatePrompt(prompt)
	prompt.AttributeChanged:Connect(function()
		updatePrompt(prompt)
	end)
end

-- Rainbow mutation ------------------------------------------------------------

local rainbow: { [Highlight]: boolean } = {}

local function onDescendant(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		watchPrompt(instance)
	elseif instance:IsA("Highlight") and instance:GetAttribute("Rainbow") then
		rainbow[instance] = true
		instance.Destroying:Once(function()
			rainbow[instance] = nil
		end)
	end
end

Workspace.DescendantAdded:Connect(onDescendant)
for _, instance in Workspace:GetDescendants() do
	onDescendant(instance)
end

RunService.RenderStepped:Connect(function()
	local color = Color3.fromHSV((os.clock() * 0.25) % 1, 0.8, 1)
	for highlight in rainbow do
		highlight.FillColor = color
		highlight.OutlineColor = color
	end
end)
