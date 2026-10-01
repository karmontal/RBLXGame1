--!strict
-- Client language state. Starts from the saved choice (player attribute
-- "Lang", set by the server from the profile) or the device's Roblox locale,
-- re-renders every bound text when it changes, and localizes world labels
-- and prompts that the server tagged with LocText / LocAction attributes.

local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local player = Players.LocalPlayer
local setLanguageRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetLanguage") :: RemoteEvent

local Lang = {}

local changed = Instance.new("BindableEvent")
Lang.Changed = changed.Event

local function detect(): string
	local saved = player:GetAttribute("Lang")
	if saved == "en" or saved == "ar" then
		return saved
	end
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if ok and type(locale) == "string" and string.sub(string.lower(locale), 1, 2) == "ar" then
		return "ar"
	end
	return "en"
end

local current = detect()

function Lang.Get(): string
	return current
end

function Lang.IsArabic(): boolean
	return current == "ar"
end

function Lang.T(key: string, args: { [string]: any }?): string
	return Locale.T(current, key, args)
end

function Lang.Render(msg: any): string
	return Locale.Render(current, msg)
end

-- Left in English, right in Arabic (for left-aligned UI text).
function Lang.Align(): Enum.TextXAlignment
	return if current == "ar" then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
end

function Lang.Set(lang: string)
	if lang ~= "en" and lang ~= "ar" or lang == current then
		return
	end
	current = lang
	setLanguageRemote:FireServer(lang)
	changed:Fire(lang)
end

-- Keeps a text object rendered from key/args (args may be a function).
function Lang.Bind(object: TextLabel | TextButton | TextBox, key: string, args: ({ [string]: any } | () -> { [string]: any })?)
	local function render()
		local resolved = if type(args) == "function" then args() else args
		local text = Locale.T(current, key, resolved :: any)
		if object:IsA("TextBox") then
			(object :: TextBox).PlaceholderText = text
		else
			(object :: any).Text = text
		end
	end
	render()
	Lang.Changed:Connect(render)
	return render
end

-- World labels / prompts tagged by the server ---------------------------------

local function decode(value: any): any
	if type(value) ~= "string" then
		return nil
	end
	local ok, msg = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	return if ok then msg else nil
end

local tagged: { [Instance]: boolean } = {}

local function renderTagged(instance: Instance)
	if instance:IsA("TextLabel") then
		local msg = decode(instance:GetAttribute("LocText"))
		instance.Text = if msg then Locale.Render(current, msg) else instance.Text
	elseif instance:IsA("ProximityPrompt") then
		local msg = decode(instance:GetAttribute("LocAction"))
		if msg then
			instance.ActionText = Locale.Render(current, msg)
		end
	end
end

local function watch(instance: Instance)
	if tagged[instance] then
		return
	end
	local attribute = if instance:IsA("TextLabel") then "LocText" elseif instance:IsA("ProximityPrompt") then "LocAction" else nil
	if not attribute then
		return
	end
	tagged[instance] = true
	renderTagged(instance)
	instance:GetAttributeChangedSignal(attribute):Connect(function()
		renderTagged(instance)
	end)
	instance.Destroying:Once(function()
		tagged[instance] = nil
	end)
end

Workspace.DescendantAdded:Connect(watch)
for _, instance in Workspace:GetDescendants() do
	watch(instance)
end

Lang.Changed:Connect(function()
	for instance in tagged do
		renderTagged(instance)
	end
end)

-- The saved choice may arrive after the client started.
player:GetAttributeChangedSignal("Lang"):Connect(function()
	local saved = player:GetAttribute("Lang")
	if (saved == "en" or saved == "ar") and saved ~= current then
		current = saved :: string
		changed:Fire(current)
	end
end)

return Lang
