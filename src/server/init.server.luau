--!strict
-- Server entry point: builds the map and wires up all services.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Services
local CodeService = require(Services.CodeService)
local ConveyorService = require(Services.ConveyorService)
local DataService = require(Services.DataService)
local MonetizationService = require(Services.MonetizationService)
local PlotService = require(Services.PlotService)
local StealService = require(Services.StealService)
local WorldBuilder = require(Services.WorldBuilder)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes
local redeemCode = Instance.new("RemoteFunction")
redeemCode.Name = "RedeemCode"
redeemCode.Parent = remotes
remotes.Parent = ReplicatedStorage

local map = WorldBuilder.BuildGround()
local beltStart, beltEnd = WorldBuilder.BuildConveyor(map)
local plotParts = WorldBuilder.BuildPlots(map)

DataService.Init()
PlotService.Init(plotParts, notify)
ConveyorService.Init(beltStart, beltEnd)

DataService.Start()
PlotService.Start()
ConveyorService.Start()
StealService.Start()
MonetizationService.Start()
CodeService.Start(redeemCode)

local function teleportHome(player: Player, character: Model)
	local spawnCFrame = PlotService.SpawnCFrame(player)
	if spawnCFrame then
		character:WaitForChild("HumanoidRootPart", 5)
		task.defer(function()
			character:PivotTo(spawnCFrame)
		end)
	end
end

local function onPlayerAdded(player: Player)
	local profile = DataService.Load(player)
	if not profile or not player.Parent then
		return
	end
	if not PlotService.Assign(player) then
		player:Kick("This server is full, please join another one.")
		return
	end
	task.spawn(function()
		MonetizationService.LoadPasses(player)
		CodeService.LoadPlayer(player)
	end)
	player.CharacterAdded:Connect(function(character)
		teleportHome(player, character)
	end)
	if player.Character then
		teleportHome(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	StealService.CancelFor(player)
	PlotService.Unassign(player)
	DataService.Release(player)
end)
