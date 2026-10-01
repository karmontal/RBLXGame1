--!strict
-- Spawns random monsters on the belt and sells them to players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Monsters = require(Shared.Monsters)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)
local MonsterModels = require(script.Parent.MonsterModels)
local PlotService = require(script.Parent.PlotService)

type BeltItem = {
	Model: Model,
	MonsterId: string,
	Mutation: string,
	Price: number,
	Distance: number,
	Sold: boolean,
}

local ConveyorService = {}

local rng = Random.new()
local items: { BeltItem } = {}
local beltStart: Vector3
local beltEnd: Vector3
local folder: Folder

local totalWeight = 0
for _, rarity in Rarities.List do
	totalWeight += rarity.Weight
end

local function rollMonster(): string
	local roll = rng:NextNumber() * totalWeight
	for _, rarity in Rarities.List do
		roll -= rarity.Weight
		if roll <= 0 then
			local pool = Monsters.ByRarity[rarity.Name]
			if pool and #pool > 0 then
				return pool[rng:NextInteger(1, #pool)].Id
			end
		end
	end
	return Monsters.List[1].Id
end

local function despawn(item: BeltItem)
	local index = table.find(items, item)
	if index then
		table.remove(items, index)
	end
	item.Model:Destroy()
end

local function onBuy(item: BeltItem, player: Player)
	if item.Sold then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local itemRoot = item.Model.PrimaryPart
	if not root or not itemRoot or (root.Position - itemRoot.Position).Magnitude > Config.BuyDistance then
		return
	end
	local plot = PlotService.GetPlot(player)
	if not plot or not PlotService.FreeSlot(plot) then
		PlotService.Notify(player, "Your base is full! Sell a monster first.", "error")
		return
	end
	if not PlotService.TrySpend(player, item.Price) then
		PlotService.Notify(player, "Not enough cash! Need " .. Format.Money(item.Price), "error")
		return
	end
	item.Sold = true
	PlotService.AddMonster(player, { Id = item.MonsterId, Mutation = item.Mutation })
	local mutation = if item.Mutation ~= "None" then item.Mutation .. " " else ""
	PlotService.Notify(player, "You bought " .. mutation .. item.MonsterId .. "!", "cash")
	despawn(item)
end

local function spawnItem()
	local monsterId = rollMonster()
	local mutation = Mutations.Roll(rng)
	local price = MonsterModels.PriceOf(monsterId, mutation.Name)
	local model = MonsterModels.Build(monsterId, mutation.Name, { Price = price })

	local item: BeltItem = {
		Model = model,
		MonsterId = monsterId,
		Mutation = mutation.Name,
		Price = price,
		Distance = 0,
		Sold = false,
	}

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Format.Money(price)
	prompt.ObjectText = model.Name
	prompt.MaxActivationDistance = Config.BuyDistance - 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		onBuy(item, player)
	end)

	model:PivotTo(CFrame.lookAt(beltStart, beltEnd))
	model.Parent = folder
	table.insert(items, item)

	local rarity = Rarities.ByName[Monsters.ById[monsterId].Rarity]
	if rarity.Order >= 5 or mutation.Multiplier >= 4 then
		for _, player in Players:GetPlayers() do
			PlotService.Notify(player, "A " .. rarity.Name .. " " .. monsterId .. " appeared on the belt!", "rare")
		end
	end
end

function ConveyorService.Init(startPos: Vector3, endPos: Vector3)
	beltStart = startPos
	beltEnd = endPos
	folder = Instance.new("Folder")
	folder.Name = "BeltMonsters"
	folder.Parent = workspace
end

function ConveyorService.Start()
	local length = (beltEnd - beltStart).Magnitude
	local direction = (beltEnd - beltStart).Unit

	task.spawn(function()
		while true do
			spawnItem()
			task.wait(Config.SpawnInterval)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for i = #items, 1, -1 do
			local item = items[i]
			item.Distance += Config.ConveyorSpeed * dt
			if item.Distance >= length then
				despawn(item)
			else
				local position = beltStart + direction * item.Distance
				item.Model:PivotTo(CFrame.lookAt(position, position + direction))
			end
		end
	end)
end

return ConveyorService
