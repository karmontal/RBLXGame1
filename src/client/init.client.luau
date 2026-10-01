--!strict
-- Client: HUD (cash, income, rebirths, carrying) in the top-right corner,
-- language toggle, localized toasts, side buttons (shop / codes / admin),
-- owner-specific prompt visibility, rainbow mutation and chat tags.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local Lang = require(script.Lang)
local Ui = require(script.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

-- Our HUD shows cash in the top-right corner, where the default leaderboard sits.
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
			break
		end
		task.wait(1)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Side buttons (left middle, clear of the mobile thumbstick and jump button).
local sideBar = Instance.new("Frame")
sideBar.Name = "SideButtons"
sideBar.AnchorPoint = Vector2.new(0, 0.5)
sideBar.Position = UDim2.new(0, 10, 0.45, 0)
sideBar.Size = UDim2.fromOffset(100, 150)
sideBar.BackgroundTransparency = 1
sideBar.Parent = gui
Ui.Scaled(sideBar)
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 8)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Parent = sideBar

require(script.Shop).Mount(gui, sideBar)
require(script.Codes).Mount(gui, sideBar)
require(script.AdminPanel).Mount(gui, sideBar)

-- Top-right stats -------------------------------------------------------------

local panel = Instance.new("Frame")
panel.Name = "Stats"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -10, 0, 8)
panel.Size = UDim2.fromOffset(170, 62)
panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
panel.BackgroundTransparency = 0.2
panel.Parent = gui
Ui.Corner(panel, 10)
Ui.Scaled(panel)

local cashLabel = Ui.Label(panel, {
	Position = UDim2.fromOffset(10, 4),
	Size = UDim2.new(1, -20, 0, 30),
	TextColor3 = Ui.Colors.Money,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local incomeLabel = Ui.Label(panel, {
	Position = UDim2.fromOffset(10, 36),
	Size = UDim2.new(1, -20, 0, 20),
	TextColor3 = Ui.Colors.SubText,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local rebirthLabel = Ui.Label(panel, {
	Position = UDim2.fromOffset(10, 36),
	Size = UDim2.new(0, 50, 0, 20),
	TextColor3 = Color3.fromRGB(255, 210, 80),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local langButton = Ui.Button(gui, {
	Name = "Language",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 76),
	Size = UDim2.fromOffset(52, 28),
	BackgroundColor3 = Color3.fromRGB(60, 50, 95),
})
Ui.Scaled(langButton)
local function refreshLangButton()
	langButton.Text = if Lang.IsArabic() then "EN" else "ع"
end
refreshLangButton()
langButton.Activated:Connect(function()
	Lang.Set(if Lang.IsArabic() then "en" else "ar")
end)
require(script.MonsterIndex).Mount(gui)

local carryLabel = Ui.Label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.new(0.7, 0, 0, 30),
	TextColor3 = Color3.fromRGB(255, 220, 60),
	TextStrokeTransparency = 0,
	Visible = false,
})
local carryLimit = Instance.new("UITextSizeConstraint")
carryLimit.MaxTextSize = 26
carryLimit.Parent = carryLabel

local function refreshHud()
	cashLabel.Text = Format.Money((player:GetAttribute("Cash") :: number?) or 0)
	incomeLabel.Text = Lang.T("ui.perSec", { amount = Format.Money((player:GetAttribute("Income") :: number?) or 0) })
	local rebirths = (player:GetAttribute("Rebirths") :: number?) or 0
	rebirthLabel.Visible = rebirths > 0
	rebirthLabel.Text = Lang.T("ui.rebirths", { count = rebirths })
	local carrying = player:GetAttribute("Carrying") :: string?
	carryLabel.Visible = carrying ~= nil
	if carrying then
		carryLabel.Text = Lang.T("ui.carrying", { monster = "@monster:" .. carrying })
	end
end
for _, attribute in { "Cash", "Income", "Rebirths", "Carrying" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshHud)
end
Lang.Changed:Connect(function()
	refreshHud()
	refreshLangButton()
end)
refreshHud()

-- Notifications ------------------------------------------------------------

local toastList = Instance.new("Frame")
toastList.AnchorPoint = Vector2.new(0.5, 0)
toastList.Position = UDim2.new(0.5, 0, 0, 88)
toastList.Size = UDim2.new(0.8, 0, 0, 200)
toastList.BackgroundTransparency = 1
toastList.Parent = gui
local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 4)
layout.Parent = toastList

local toastColors = {
	info = Color3.fromRGB(255, 255, 255),
	cash = Color3.fromRGB(120, 255, 140),
	error = Color3.fromRGB(255, 110, 110),
	rare = Color3.fromRGB(255, 200, 60),
}

notifyRemote.OnClientEvent:Connect(function(msg: any, kind: string)
	local toast = Ui.Label(toastList, {
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = toastColors[kind] or toastColors.info,
		TextStrokeTransparency = 0.1,
		Text = Lang.Render(msg),
	})
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = toast
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

-- Chat tags ------------------------------------------------------------------

local TextChatService = game:GetService("TextChatService")

local ROLE_TAGS = {
	Owner = "<font color='#FFD24A'>[OWNER]</font> ",
	Admin = "<font color='#FF5A6E'>[ADMIN]</font> ",
}

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	local tag = sender and ROLE_TAGS[sender:GetAttribute("Role") :: string]
	if tag then
		properties.PrefixText = tag .. message.PrefixText
	end
	return properties
end
