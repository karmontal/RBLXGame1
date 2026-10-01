--!strict
-- Stone leaderboard by the plaza fountain: players in this server ranked by
-- cash, cash per second and rebirths. Names and numbers are plain text; the
-- headings are localized per player (Loc).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local MapLayout = require(Shared.MapLayout)
local Loc = require(script.Parent.Loc)

local REFRESH = 2
local ROWS = Config.MaxPlots

type Column = {
	Attribute: string,
	Format: (number) -> string,
	Rows: { { Name: TextLabel, Value: TextLabel } },
}

local LeaderboardService = {}

local columns: { Column } = {}

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(text :: any)[key] = value
	end
	text.Parent = parent
	return text
end

local function buildBoard(map: Instance)
	local center = Vector3.new(MapLayout.Plaza.Center.X, 0, MapLayout.Plaza.Center.Y)
	local spot = center + Vector3.new(0, 0, -(MapLayout.Plaza.Radius - 3))
	local facing = CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1)) -- faces the fountain/spawn

	local folder = Instance.new("Folder")
	folder.Name = "Leaderboard"
	folder.Parent = map

	local stone = Color3.fromRGB(105, 102, 98)
	for _, side in { -1, 1 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(2, 20, 2)
		post.CFrame = facing * CFrame.new(side * 19, 10, 0)
		post.Color = stone
		post.Material = Enum.Material.Cobblestone
		post.Parent = folder
	end
	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Size = Vector3.new(36, 15, 1)
	board.CFrame = facing * CFrame.new(0, 11.5, 0)
	board.Color = Color3.fromRGB(40, 30, 55)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = folder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local title = label(gui, {
		Position = UDim2.fromScale(0.02, 0.01),
		Size = UDim2.fromScale(0.96, 0.13),
		TextColor3 = Color3.fromRGB(255, 215, 80),
	})
	Loc.Label(title, "lb.title")

	local specs = {
		{ key = "lb.cash", attribute = "Cash", format = Format.Money, color = Color3.fromRGB(120, 255, 140) },
		{ key = "lb.income", attribute = "Income", format = function(v: number): string
			return Format.Money(v) .. "/s"
		end, color = Color3.fromRGB(140, 210, 255) },
		{ key = "lb.rebirths", attribute = "Rebirths", format = function(v: number): string
			return tostring(math.floor(v))
		end, color = Color3.fromRGB(255, 200, 90) },
	}
	for i, spec in specs do
		local panel = Instance.new("Frame")
		panel.Position = UDim2.fromScale(0.015 + (i - 1) * 0.33, 0.16)
		panel.Size = UDim2.fromScale(0.31, 0.82)
		panel.BackgroundColor3 = Color3.fromRGB(60, 46, 85)
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel

		local heading = label(panel, {
			Position = UDim2.fromScale(0.04, 0.01),
			Size = UDim2.fromScale(0.92, 0.12),
			TextColor3 = spec.color,
		})
		Loc.Label(heading, spec.key)

		local rows = {}
		for r = 1, ROWS do
			local y = 0.15 + (r - 1) * (0.84 / ROWS)
			local h = 0.84 / ROWS - 0.01
			local name = label(panel, {
				Position = UDim2.fromScale(0.04, y),
				Size = UDim2.fromScale(0.58, h),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "",
			})
			local value = label(panel, {
				Position = UDim2.fromScale(0.62, y),
				Size = UDim2.fromScale(0.34, h),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = spec.color,
				Text = "",
			})
			table.insert(rows, { Name = name, Value = value })
		end
		table.insert(columns, { Attribute = spec.attribute, Format = spec.format, Rows = rows })
	end
end

local function refresh()
	local players = Players:GetPlayers()
	for _, column in columns do
		local entries = {}
		for _, player in players do
			local value = player:GetAttribute(column.Attribute)
			if type(value) == "number" then
				table.insert(entries, { Name = player.DisplayName, Value = value })
			end
		end
		table.sort(entries, function(a, b)
			return a.Value > b.Value
		end)
		for r, row in column.Rows do
			local entry = entries[r]
			if entry then
				row.Name.Text = r .. ". " .. entry.Name
				row.Value.Text = column.Format(entry.Value)
				row.Name.TextColor3 = if r == 1 then Color3.fromRGB(255, 215, 80) else Color3.new(1, 1, 1)
			else
				row.Name.Text = ""
				row.Value.Text = ""
			end
		end
	end
end

function LeaderboardService.Start(map: Instance)
	buildBoard(map)
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
