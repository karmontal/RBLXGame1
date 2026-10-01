--!strict
-- Builds the whole map in code from Shared.MapLayout: a closed castle with
-- stone walls and towers, a belt that winds between eight asymmetric rooms
-- (each door faces the belt and has an iron portcullis), a central plaza
-- with a fountain, gardens and torches. Rojo produces the place with no
-- binary assets.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MapLayout = require(Shared.MapLayout)
local Loc = require(script.Parent.Loc)

export type PlotParts = {
	Index: number,
	Model: Model,
	Origin: CFrame, -- floor-level center; local -Z points at the door
	Floor: BasePart,
	Gate: Model, -- iron portcullis: lowered while the base is locked
	GateUp: CFrame,
	GateDown: CFrame,
	LockButton: BasePart,
	CollectPad: BasePart,
	RebirthPillar: BasePart,
	Sign: TextLabel,
	Pedestals: { BasePart },
	Spawn: CFrame,
}

local HALF = MapLayout.Half
local PLOT_SIZE = MapLayout.RoomSize
local BELT_WIDTH = MapLayout.BeltWidth
local BELT_TOP = 1
local ROOM_WALL_HEIGHT = 14
local DOOR_WIDTH = 16
local DOOR_HEIGHT = 11
local CASTLE_WALL_HEIGHT = 40
local CASTLE_WALL_THICKNESS = 8

local STONE = Color3.fromRGB(150, 146, 140)
local DARK_STONE = Color3.fromRGB(105, 102, 98)
local IRON = Color3.fromRGB(55, 55, 62)

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

local function sign(parent: BasePart, textKey: string, size: UDim2, offset: Vector3): TextLabel
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
	Loc.Label(label, textKey)
	label.Parent = gui
	return label
end

local function prompt(parent: BasePart, actionKey: string, holdDuration: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	Loc.Prompt(p, actionKey)
	p.HoldDuration = holdDuration or 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute("OwnerOnly", 0) -- set to the owner's UserId by PlotService
	p.Parent = parent
	return p
end


local function vertical(cframe: CFrame): CFrame
	-- Cylinders extend along X; rotate so they stand upright.
	return cframe * CFrame.Angles(0, 0, math.pi / 2)
end

local function torch(parent: Instance, cframe: CFrame, range: number?)
	local holder = part({
		Name = "Torch",
		Size = Vector3.new(0.8, 2.4, 0.8),
		CFrame = cframe,
		Color = Color3.fromRGB(90, 60, 35),
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = parent,
	})
	local flame = Instance.new("Fire")
	flame.Size = 3
	flame.Heat = 4
	flame.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = range or 22
	light.Brightness = 1.6
	light.Parent = holder
end

function WorldBuilder.BuildGround(): Folder
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	part({
		Name = "Outside",
		Size = Vector3.new(1400, 2, 1400),
		Position = Vector3.new(0, -1.2, 0),
		Color = Color3.fromRGB(96, 150, 80),
		Material = Enum.Material.Grass,
		Parent = map,
	})
	part({
		Name = "CastleFloor",
		Size = Vector3.new(HALF * 2, 2, HALF * 2),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(128, 124, 118),
		Material = Enum.Material.Slate,
		Parent = map,
	})

	-- Outer walls with battlements.
	local walls = Instance.new("Folder")
	walls.Name = "CastleWalls"
	walls.Parent = map
	local outer = HALF + CASTLE_WALL_THICKNESS / 2
	local span = HALF * 2 + CASTLE_WALL_THICKNESS * 2
	for _, side in { { Vector3.new(0, 0, -outer), 0 }, { Vector3.new(0, 0, outer), 0 }, { Vector3.new(-outer, 0, 0), 90 }, { Vector3.new(outer, 0, 0), 90 } } do
		local position, angle = side[1] :: Vector3, side[2] :: number
		local base = CFrame.new(position) * CFrame.Angles(0, math.rad(angle), 0)
		part({
			Name = "Wall",
			Size = Vector3.new(span, CASTLE_WALL_HEIGHT, CASTLE_WALL_THICKNESS),
			CFrame = base * CFrame.new(0, CASTLE_WALL_HEIGHT / 2, 0),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
			Parent = walls,
		})
		for offset = -span / 2 + 5, span / 2 - 5, 12 do
			part({
				Name = "Merlon",
				Size = Vector3.new(6, 5, CASTLE_WALL_THICKNESS),
				CFrame = base * CFrame.new(offset, CASTLE_WALL_HEIGHT + 2.5, 0),
				Color = STONE,
				Material = Enum.Material.Cobblestone,
				Parent = walls,
			})
		end
		-- Torches and banners on the inner face.
		local inward = if position.Magnitude > 0 then -position.Unit else Vector3.zero
		for offset = -HALF + 30, HALF - 30, 60 do
			local along = base.RightVector * offset
			local spot = Vector3.new(position.X, 0, position.Z) + along + inward * (CASTLE_WALL_THICKNESS / 2 + 0.6)
			torch(walls, CFrame.new(spot + Vector3.new(0, 14, 0)), 30)
		end
		for offset = -HALF + 60, HALF - 60, 120 do
			local along = base.RightVector * offset
			local spot = Vector3.new(position.X, 0, position.Z) + along + inward * (CASTLE_WALL_THICKNESS / 2 + 0.3)
			part({
				Name = "Banner",
				Size = Vector3.new(8, 16, 0.3),
				CFrame = CFrame.lookAt(spot + Vector3.new(0, 26, 0), spot + Vector3.new(0, 26, 0) + inward),
				Color = Color3.fromRGB(120, 50, 170),
				Material = Enum.Material.Fabric,
				CanCollide = false,
				Parent = walls,
			})
		end
	end

	-- Towers: round at the corners, square in the middle of each side.
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			local center = Vector3.new(cx * (HALF + 4), 0, cz * (HALF + 4))
			part({
				Name = "Tower",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(56, 36, 36),
				CFrame = vertical(CFrame.new(center + Vector3.new(0, 28, 0))),
				Color = DARK_STONE,
				Material = Enum.Material.Cobblestone,
				Parent = walls,
			})
			part({
				Name = "TowerTop",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(4, 40, 40),
				CFrame = vertical(CFrame.new(center + Vector3.new(0, 58, 0))),
				Color = STONE,
				Material = Enum.Material.Cobblestone,
				Parent = walls,
			})
		end
	end
	for _, spot in { Vector3.new(0, 0, -HALF - 4), Vector3.new(0, 0, HALF + 4), Vector3.new(-HALF - 4, 0, 0), Vector3.new(HALF + 4, 0, 0) } do
		part({
			Name = "GateTower",
			Size = Vector3.new(24, 50, 24),
			Position = spot + Vector3.new(0, 25, 0),
			Color = DARK_STONE,
			Material = Enum.Material.Cobblestone,
			Parent = walls,
		})
	end

	-- Plaza with a fountain and a ring of pillars; players spawn here.
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = map
	local plazaCenter = Vector3.new(MapLayout.Plaza.Center.X, 0, MapLayout.Plaza.Center.Y)
	part({
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, MapLayout.Plaza.Radius * 2, MapLayout.Plaza.Radius * 2),
		CFrame = vertical(CFrame.new(plazaCenter + Vector3.new(0, 0.2, 0))),
		Color = Color3.fromRGB(220, 214, 200),
		Material = Enum.Material.Marble,
		Parent = plaza,
	})
	part({
		Name = "FountainBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 22, 22),
		CFrame = vertical(CFrame.new(plazaCenter + Vector3.new(0, 1.5, 0))),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
		Parent = plaza,
	})
	part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 19, 19),
		CFrame = vertical(CFrame.new(plazaCenter + Vector3.new(0, 3, 0))),
		Color = Color3.fromRGB(80, 170, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Parent = plaza,
	})
	local spout = part({
		Name = "FountainSpout",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 3, 3),
		CFrame = vertical(CFrame.new(plazaCenter + Vector3.new(0, 7, 0))),
		Color = Color3.fromRGB(230, 225, 215),
		Material = Enum.Material.Marble,
		Parent = plaza,
	})
	local water = Instance.new("ParticleEmitter")
	water.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	water.Speed = NumberRange.new(8, 10)
	water.SpreadAngle = Vector2.new(15, 15)
	water.Lifetime = NumberRange.new(0.8, 1.1)
	water.Rate = 40
	water.Acceleration = Vector3.new(0, -30, 0)
	water.Size = NumberSequence.new(0.5)
	water.EmissionDirection = Enum.NormalId.Right -- cylinder axis points up
	water.Parent = spout
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local spot = plazaCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (MapLayout.Plaza.Radius + 6)
		part({
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(16, 3, 3),
			CFrame = vertical(CFrame.new(spot + Vector3.new(0, 8, 0))),
			Color = Color3.fromRGB(225, 220, 210),
			Material = Enum.Material.Marble,
			Parent = plaza,
		})
		torch(plaza, CFrame.new(spot + Vector3.new(0, 17.2, 0)), 20)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = plazaCenter + Vector3.new(0, 0.5, 24)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(225, 215, 190)
	spawn.Material = Enum.Material.Marble
	spawn.Parent = plaza

	-- Gardens and trees in the empty corners.
	local gardens = Instance.new("Folder")
	gardens.Name = "Gardens"
	gardens.Parent = map
	for _, rect in MapLayout.Gardens do
		local x, z, w, d = rect[1], rect[2], rect[3], rect[4]
		part({
			Name = "Grass",
			Size = Vector3.new(w, 0.3, d),
			Position = Vector3.new(x + w / 2, 0.15, z + d / 2),
			Color = Color3.fromRGB(90, 160, 75),
			Material = Enum.Material.Grass,
			Parent = gardens,
		})
	end
	for _, spot in MapLayout.Trees do
		local base = Vector3.new(spot.X, 0, spot.Y)
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, 2.5, 2.5),
			CFrame = vertical(CFrame.new(base + Vector3.new(0, 5, 0))),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			Parent = gardens,
		})
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(13, 13, 13),
			Position = base + Vector3.new(0, 13, 0),
			Color = Color3.fromRGB(70, 140, 60),
			Material = Enum.Material.Grass,
			Parent = gardens,
		})
	end

	return map
end

-- Builds the winding belt and returns its centerline (belt-top height).
function WorldBuilder.BuildConveyor(map: Folder): { Vector3 }
	local folder = Instance.new("Folder")
	folder.Name = "Conveyor"
	folder.Parent = map

	local path: { Vector3 } = {}
	for _, point in MapLayout.Belt do
		table.insert(path, Vector3.new(point.X, BELT_TOP, point.Y))
	end

	local beltColor = Color3.fromRGB(45, 45, 55)
	local railColor = Color3.fromRGB(0, 200, 255)
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local flatA, flatB = Vector3.new(a.X, 0.5, a.Z), Vector3.new(b.X, 0.5, b.Z)
		local length = (flatB - flatA).Magnitude
		local frame = CFrame.lookAt((flatA + flatB) / 2, flatB)
		part({
			Name = "Belt",
			Size = Vector3.new(BELT_WIDTH, 1, length),
			CFrame = frame,
			Color = beltColor,
			Material = Enum.Material.DiamondPlate,
			Parent = folder,
		})
		for _, side in { -1, 1 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.8, 1.4, length),
				CFrame = frame * CFrame.new(side * (BELT_WIDTH / 2 + 0.4), 0.2, 0),
				Color = railColor,
				Material = Enum.Material.Neon,
				Parent = folder,
			})
		end
	end
	-- Round joints so the turns look continuous.
	for i = 2, #path - 1 do
		local joint = Vector3.new(path[i].X, 0, path[i].Z)
		part({
			Name = "JointRim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.9, BELT_WIDTH + 1.6, BELT_WIDTH + 1.6),
			CFrame = vertical(CFrame.new(joint + Vector3.new(0, 0.45, 0))),
			Color = railColor,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		part({
			Name = "Joint",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.02, BELT_WIDTH, BELT_WIDTH),
			CFrame = vertical(CFrame.new(joint + Vector3.new(0, 0.51, 0))),
			Color = beltColor,
			Material = Enum.Material.DiamondPlate,
			Parent = folder,
		})
	end

	-- Monster machine at the start, exit portal at the end.
	local first, second = path[1], path[2]
	local inward = Vector3.new(second.X - first.X, 0, second.Z - first.Z).Unit
	local machine = part({
		Name = "MonsterMachine",
		Size = Vector3.new(22, 22, 12),
		CFrame = CFrame.lookAt(Vector3.new(first.X, 11, first.Z) - inward * 2, Vector3.new(first.X, 11, first.Z) + inward),
		Color = Color3.fromRGB(255, 120, 200),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})
	part({
		Name = "MachineMouth",
		Size = Vector3.new(BELT_WIDTH + 2, 8, 1),
		CFrame = machine.CFrame * CFrame.new(0, -7, -6.2),
		Color = Color3.fromRGB(30, 20, 40),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	sign(machine, "label.machine", UDim2.fromOffset(320, 60), Vector3.new(0, 15, 0))

	local last, beforeLast = path[#path], path[#path - 1]
	local outward = Vector3.new(last.X - beforeLast.X, 0, last.Z - beforeLast.Z).Unit
	local portalFrame = CFrame.lookAt(Vector3.new(last.X, 0, last.Z), Vector3.new(last.X, 0, last.Z) + outward)
	for _, side in { -1, 1 } do
		part({
			Name = "PortalPillar",
			Size = Vector3.new(3, 18, 3),
			CFrame = portalFrame * CFrame.new(side * (BELT_WIDTH / 2 + 3), 9, 0),
			Color = DARK_STONE,
			Material = Enum.Material.Cobblestone,
			Parent = folder,
		})
	end
	part({
		Name = "PortalArch",
		Size = Vector3.new(BELT_WIDTH + 9, 3, 3),
		CFrame = portalFrame * CFrame.new(0, 19.5, 0),
		Color = DARK_STONE,
		Material = Enum.Material.Cobblestone,
		Parent = folder,
	})
	part({
		Name = "Portal",
		Size = Vector3.new(BELT_WIDTH + 3, 17, 0.6),
		CFrame = portalFrame * CFrame.new(0, 9.5, 1),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		Parent = folder,
	})

	return path
end

local DOOR_DIRECTIONS = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local function buildGate(parent: Instance): Model
	local gate = Instance.new("Model")
	gate.Name = "Portcullis"
	local bars = 7
	for i = 0, bars - 1 do
		local x = -DOOR_WIDTH / 2 + 1 + i * ((DOOR_WIDTH - 2) / (bars - 1))
		part({
			Name = "Bar",
			Size = Vector3.new(0.7, DOOR_HEIGHT, 0.7),
			CFrame = CFrame.new(x, 0, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = gate,
		})
		part({
			Name = "Spike",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(x, -DOOR_HEIGHT / 2, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = gate,
		})
	end
	for _, y in { -3, 1, 4.5 } do
		part({
			Name = "Crossbar",
			Size = Vector3.new(DOOR_WIDTH - 0.5, 0.6, 0.6),
			CFrame = CFrame.new(0, y, 0),
			Color = IRON,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = gate,
		})
	end
	gate.Parent = parent
	return gate
end

local function buildRoom(map: Folder, index: number, center: Vector3, doorDirection: Vector3): PlotParts
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = map

	-- Local -Z points out of the door, toward the belt.
	local origin = CFrame.lookAt(center, center + doorDirection)
	local half = PLOT_SIZE / 2

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = origin * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(170, 125, 80),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	local function wall(localCFrame: CFrame, size: Vector3)
		part({
			Name = "Wall",
			Size = size,
			CFrame = origin * localCFrame,
			Color = STONE,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
	end
	local h = ROOM_WALL_HEIGHT
	wall(CFrame.new(0, h / 2, half), Vector3.new(PLOT_SIZE + 2, h, 2))
	wall(CFrame.new(-half, h / 2, 0), Vector3.new(2, h, PLOT_SIZE + 2))
	wall(CFrame.new(half, h / 2, 0), Vector3.new(2, h, PLOT_SIZE + 2))
	local frontPiece = (PLOT_SIZE - DOOR_WIDTH) / 2
	for _, side in { -1, 1 } do
		wall(CFrame.new(side * (DOOR_WIDTH / 2 + frontPiece / 2), h / 2, -half), Vector3.new(frontPiece + 1, h, 2))
	end
	wall(CFrame.new(0, DOOR_HEIGHT + (h - DOOR_HEIGHT) / 2, -half), Vector3.new(DOOR_WIDTH, h - DOOR_HEIGHT, 2))
	-- Battlements on top of the room walls.
	for offset = -half + 3, half - 3, 8 do
		for _, cf in {
			CFrame.new(offset, h + 1.25, half),
			CFrame.new(-half, h + 1.25, offset),
			CFrame.new(half, h + 1.25, offset),
			CFrame.new(offset, h + 1.25, -half),
		} do
			part({
				Name = "Merlon",
				Size = Vector3.new(3, 2.5, 2),
				CFrame = origin * cf * (if cf.Position.X == half or cf.Position.X == -half then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity),
				Color = STONE,
				Material = Enum.Material.Cobblestone,
				Parent = model,
			})
		end
	end

	local gate = buildGate(model)
	local gateDown = origin * CFrame.new(0, DOOR_HEIGHT / 2 + 0.2, -half)
	local gateUp = gateDown * CFrame.new(0, DOOR_HEIGHT - 1.5, 0)
	gate:PivotTo(gateUp)

	torch(model, origin * CFrame.new(-half + 2, 9, half - 2))
	torch(model, origin * CFrame.new(half - 2, 9, half - 2))
	torch(model, origin * CFrame.new(-DOOR_WIDTH / 2 - 2, 9, -half - 1.6))
	torch(model, origin * CFrame.new(DOOR_WIDTH / 2 + 2, 9, -half - 1.6))

	local pedestals = {}
	for row = 0, 1 do
		for column = -2, 2 do
			local pedestal = part({
				Name = "Pedestal",
				Size = Vector3.new(6, 1, 6),
				CFrame = origin * CFrame.new(column * 10, 1.5, 2 + row * 12),
				Color = Color3.fromRGB(235, 232, 225),
				Material = Enum.Material.Marble,
				Parent = model,
			})
			table.insert(pedestals, pedestal)
		end
	end

	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(8, 0.4, 8),
		CFrame = origin * CFrame.new(-16, 1.2, -16),
		Color = Color3.fromRGB(60, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})

	part({
		Name = "LeverBase",
		Size = Vector3.new(3, 2, 3),
		CFrame = origin * CFrame.new(16, 2, -16),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local lockButton = part({
		Name = "LockButton",
		Size = Vector3.new(1, 4, 1),
		CFrame = origin * CFrame.new(16, 4.5, -16) * CFrame.Angles(math.rad(25), 0, 0),
		Color = Color3.fromRGB(220, 50, 50),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	prompt(lockButton, "prompt.lock")

	local rebirthPillar = part({
		Name = "RebirthAltar",
		Size = Vector3.new(6, 5, 4),
		CFrame = origin * CFrame.new(0, 3.5, half - 4),
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	prompt(rebirthPillar, "prompt.rebirth", 1)

	local signPost = part({
		Name = "SignPost",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin * CFrame.new(0, h + 2, -half - 1),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local signLabel = sign(signPost, "label.emptyBase", UDim2.fromOffset(300, 60), Vector3.new(0, 4, 0))

	return {
		Index = index,
		Model = model,
		Origin = origin,
		Floor = floor,
		Gate = gate,
		GateUp = gateUp,
		GateDown = gateDown,
		LockButton = lockButton,
		CollectPad = collectPad,
		RebirthPillar = rebirthPillar,
		Sign = signLabel,
		Pedestals = pedestals,
		Spawn = origin * CFrame.new(0, 4, -8) * CFrame.Angles(0, math.pi, 0),
	}
end

function WorldBuilder.BuildPlots(map: Folder): { PlotParts }
	local plots = {}
	for index, room in MapLayout.Rooms do
		local center = Vector3.new(room.Center.X, 0, room.Center.Y)
		table.insert(plots, buildRoom(map, index, center, DOOR_DIRECTIONS[room.Door]))
	end
	return plots
end

function WorldBuilder.PlotSize(): number
	return PLOT_SIZE
end

return WorldBuilder
