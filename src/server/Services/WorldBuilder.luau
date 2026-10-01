--!strict
-- Builds the whole map in code (ground, conveyor, player bases) so the place
-- file can be generated entirely by Rojo with no binary assets.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type PlotParts = {
	Index: number,
	Model: Model,
	Origin: CFrame, -- floor-level center; local -Z points at the door
	Floor: BasePart,
	Barrier: BasePart,
	LockButton: BasePart,
	CollectPad: BasePart,
	RebirthPillar: BasePart,
	Sign: TextLabel,
	Pedestals: { BasePart },
	Spawn: CFrame,
}

local PLOT_SIZE = 56
local WALL_HEIGHT = 10
local DOOR_WIDTH = 16

local WorldBuilder = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function sign(parent: BasePart, text: string, size: UDim2, offset: Vector3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = gui
	return label
end

local function prompt(parent: BasePart, action: string, objectText: string, holdDuration: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = objectText
	p.HoldDuration = holdDuration or 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute("OwnerOnly", 0) -- set to the owner's UserId by PlotService
	p.Parent = parent
	return p
end

function WorldBuilder.BuildGround(): Folder
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	part({
		Name = "Ground",
		Size = Vector3.new(600, 2, 600),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(110, 190, 90),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 24)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = map

	return map
end

-- Returns the belt start/end in world space.
function WorldBuilder.BuildConveyor(map: Folder): (Vector3, Vector3)
	local length = Config.ConveyorLength
	local belt = part({
		Name = "Conveyor",
		Size = Vector3.new(length, 1, 12),
		Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.DiamondPlate,
		Parent = map,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Rail",
			Size = Vector3.new(length, 1.6, 1),
			Position = Vector3.new(0, 0.8, side * 6.5),
			Color = Color3.fromRGB(0, 200, 255),
			Material = Enum.Material.Neon,
			Parent = map,
		})
	end
	local spawner = part({
		Name = "Spawner",
		Size = Vector3.new(8, 14, 14),
		Position = Vector3.new(-length / 2 - 2, 7, 0),
		Color = Color3.fromRGB(255, 120, 200),
		Material = Enum.Material.SmoothPlastic,
		Parent = map,
	})
	sign(spawner, "🥚 MONSTER MACHINE", UDim2.fromOffset(320, 60), Vector3.new(0, 10, 0))
	part({
		Name = "Exit",
		Size = Vector3.new(8, 14, 14),
		Position = Vector3.new(length / 2 + 2, 7, 0),
		Color = Color3.fromRGB(80, 80, 90),
		Material = Enum.Material.SmoothPlastic,
		Parent = map,
	})
	local top = belt.Position.Y + belt.Size.Y / 2
	return Vector3.new(-length / 2, top, 0), Vector3.new(length / 2, top, 0)
end

local function buildPlot(map: Folder, index: number, center: Vector3): PlotParts
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = map

	-- Face the conveyor (local -Z points toward z = 0).
	local origin = CFrame.lookAt(center, Vector3.new(center.X, 0, 0))
	local half = PLOT_SIZE / 2

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = origin * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(235, 225, 200),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	local wallColor = Color3.fromRGB(120, 90, 200)
	local function wall(localCFrame: CFrame, size: Vector3)
		part({
			Name = "Wall",
			Size = size,
			CFrame = origin * localCFrame,
			Color = wallColor,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	wall(CFrame.new(0, WALL_HEIGHT / 2, half), Vector3.new(PLOT_SIZE, WALL_HEIGHT, 1))
	wall(CFrame.new(-half, WALL_HEIGHT / 2, 0), Vector3.new(1, WALL_HEIGHT, PLOT_SIZE))
	wall(CFrame.new(half, WALL_HEIGHT / 2, 0), Vector3.new(1, WALL_HEIGHT, PLOT_SIZE))
	local frontPiece = (PLOT_SIZE - DOOR_WIDTH) / 2
	for _, side in { -1, 1 } do
		wall(
			CFrame.new(side * (DOOR_WIDTH / 2 + frontPiece / 2), WALL_HEIGHT / 2, -half),
			Vector3.new(frontPiece, WALL_HEIGHT, 1)
		)
	end

	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(DOOR_WIDTH, WALL_HEIGHT, 0.6),
		CFrame = origin * CFrame.new(0, WALL_HEIGHT / 2, -half),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})

	local pedestals = {}
	for row = 0, 1 do
		for column = -2, 2 do
			local pedestal = part({
				Name = "Pedestal",
				Size = Vector3.new(6, 1, 6),
				CFrame = origin * CFrame.new(column * 10, 1.5, 4 + row * 14),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.Marble,
				Parent = model,
			})
			table.insert(pedestals, pedestal)
		end
	end

	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(8, 0.4, 8),
		CFrame = origin * CFrame.new(-18, 1.2, -18),
		Color = Color3.fromRGB(60, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	local lockButton = part({
		Name = "LockButton",
		Size = Vector3.new(3, 3, 3),
		CFrame = origin * CFrame.new(18, 2.5, -18),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	prompt(lockButton, "Lock Base", "Lock")

	local rebirthPillar = part({
		Name = "RebirthPillar",
		Size = Vector3.new(4, 6, 4),
		CFrame = origin * CFrame.new(0, 4, half - 3),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	prompt(rebirthPillar, "Rebirth", "Rebirth", 1)

	local signPost = part({
		Name = "SignPost",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin * CFrame.new(0, WALL_HEIGHT + 1, half),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local signLabel = sign(signPost, "Empty Base", UDim2.fromOffset(300, 60), Vector3.new(0, 4, 0))

	return {
		Index = index,
		Model = model,
		Origin = origin,
		Floor = floor,
		Barrier = barrier,
		LockButton = lockButton,
		CollectPad = collectPad,
		RebirthPillar = rebirthPillar,
		Sign = signLabel,
		Pedestals = pedestals,
		Spawn = origin * CFrame.new(0, 4, -10) * CFrame.Angles(0, math.pi, 0),
	}
end

function WorldBuilder.BuildPlots(map: Folder): { PlotParts }
	local plots = {}
	local perSide = Config.MaxPlots // 2
	local spacing = 70
	for i = 1, Config.MaxPlots do
		local sideIndex = (i - 1) % perSide
		local z = if i <= perSide then 70 else -70
		local x = (sideIndex - (perSide - 1) / 2) * spacing
		table.insert(plots, buildPlot(map, i, Vector3.new(x, 0, z)))
	end
	return plots
end

function WorldBuilder.PlotSize(): number
	return PLOT_SIZE
end

return WorldBuilder
