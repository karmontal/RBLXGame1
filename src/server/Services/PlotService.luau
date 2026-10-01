--!strict
-- Player bases: plot assignment, monster slots, cash, passive income,
-- collecting, the base lock, selling and rebirths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local MonsterModels = require(script.Parent.MonsterModels)
local Loc = require(script.Parent.Loc)
local WorldBuilder = require(script.Parent.WorldBuilder)

type OwnedMonster = DataService.OwnedMonster
type PlotParts = WorldBuilder.PlotParts

export type Slot = {
	Pedestal: BasePart,
	Model: Model?,
	Data: OwnedMonster?,
	Stolen: boolean,
}

export type Plot = {
	Parts: PlotParts,
	Owner: Player?,
	Slots: { Slot },
	LockedUntil: number,
	LockReadyAt: number,
	LockLabel: TextLabel,
	PendingLabel: TextLabel,
	RebirthLabel: TextLabel,
	GateLowered: boolean,
}

local PlotService = {}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}
local notifyRemote: RemoteEvent

-- Set by StealService: called when a non-owner triggers a Steal prompt.
PlotService.StealHandler = nil :: ((thief: Player, plot: Plot, slotIndex: number) -> ())?

local function billboardLabel(parent: BasePart, offset: Vector3, color: Color3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Parent = gui
	return label
end

-- Slides the room's iron portcullis down (locked) or up (open) over ~0.6s.
local function setGate(plot: Plot, lowered: boolean)
	if plot.GateLowered == lowered then
		return
	end
	plot.GateLowered = lowered
	local gate = plot.Parts.Gate
	local from = gate:GetPivot()
	local to = if lowered then plot.Parts.GateDown else plot.Parts.GateUp
	task.spawn(function()
		local steps = 15
		for i = 1, steps do
			if plot.GateLowered ~= lowered then
				return -- reversed mid-way; the newer call takes over
			end
			gate:PivotTo(from:Lerp(to, i / steps))
			task.wait(0.04)
		end
	end)
end

-- Sends a localized toast: the client renders Locale key + args in its language.
function PlotService.Notify(player: Player, key: string, args: { [string]: any }?, kind: string?)
	notifyRemote:FireClient(player, { k = key, a = args }, kind or "info")
end

-- Game pass ownership is mirrored onto the player as "Pass_<Key>" attributes
-- by MonetizationService.
function PlotService.HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function PlotService.IncomeMultiplier(player: Player): number
	local profile = DataService.Get(player)
	local multiplier = 1 + (if profile then profile.Rebirths else 0) * Config.RebirthIncomeBonus
	if PlotService.HasPass(player, "DoubleCash") then
		multiplier *= 2
	end
	return multiplier
end

function PlotService.RebirthCost(rebirths: number): number
	return Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths
end

local function refreshStats(player: Player)
	local profile = DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not leaderstats then
		return
	end
	(leaderstats:FindFirstChild("Cash") :: NumberValue).Value = profile.Cash;
	(leaderstats:FindFirstChild("Rebirths") :: IntValue).Value = profile.Rebirths
	local income = 0
	for _, monster in profile.Slots do
		income += MonsterModels.IncomeOf(monster.Id, monster.Mutation)
	end
	player:SetAttribute("Income", income * PlotService.IncomeMultiplier(player))
	player:SetAttribute("Cash", profile.Cash)
	player:SetAttribute("Rebirths", profile.Rebirths)
	local plot = plotOf[player]
	if plot then
		Loc.Label(plot.RebirthLabel, "label.rebirthCost", { amount = Format.Money(PlotService.RebirthCost(profile.Rebirths)) })
	end
end

function PlotService.AddCash(player: Player, amount: number)
	local profile = DataService.Get(player)
	if profile then
		profile.Cash += amount
		refreshStats(player)
	end
end

function PlotService.TrySpend(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or profile.Cash < amount then
		return false
	end
	profile.Cash -= amount
	refreshStats(player)
	return true
end

function PlotService.GetPlot(player: Player): Plot?
	return plotOf[player]
end

function PlotService.IsInside(plot: Plot, position: Vector3): boolean
	local half = WorldBuilder.PlotSize() / 2
	local relative = plot.Parts.Origin:PointToObjectSpace(position)
	return math.abs(relative.X) <= half and math.abs(relative.Z) <= half and relative.Y > -5 and relative.Y < 25
end

function PlotService.IsLocked(plot: Plot): boolean
	return os.clock() < plot.LockedUntil
end

function PlotService.FreeSlot(plot: Plot): number?
	for index, slot in plot.Slots do
		if not slot.Data then
			return index
		end
	end
	return nil
end

local function addSlotPrompts(plot: Plot, slotIndex: number, model: Model)
	local root = model.PrimaryPart :: BasePart
	local owner = plot.Owner :: Player
	local data = plot.Slots[slotIndex].Data :: OwnedMonster

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	Loc.Prompt(sell, "prompt.sell", { amount = Format.Money(MonsterModels.PriceOf(data.Id, data.Mutation) * Config.SellRefund) })
	sell.ObjectText = model.Name
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell.HoldDuration = 0.6
	sell.MaxActivationDistance = 8
	sell.RequiresLineOfSight = false
	sell:SetAttribute("OwnerOnly", owner.UserId)
	sell.Parent = root
	sell.Triggered:Connect(function(player)
		if player ~= plot.Owner or plot.Slots[slotIndex].Data ~= data then
			return
		end
		PlotService.RemoveMonster(plot, slotIndex)
		PlotService.AddCash(player, MonsterModels.PriceOf(data.Id, data.Mutation) * Config.SellRefund)
		PlotService.Notify(player, "n.sold", { monster = "@monster:" .. data.Id .. ":" .. data.Mutation })
	end)

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	Loc.Prompt(steal, "prompt.steal")
	steal.ObjectText = model.Name
	steal.HoldDuration = Config.StealHoldDuration
	steal.MaxActivationDistance = 8
	steal.RequiresLineOfSight = false
	steal:SetAttribute("NotOwner", owner.UserId)
	steal.Parent = root
	steal.Triggered:Connect(function(player)
		if player == plot.Owner or not PlotService.StealHandler then
			return
		end
		PlotService.StealHandler(player, plot, slotIndex)
	end)
end

local function renderSlot(plot: Plot, slotIndex: number)
	local slot = plot.Slots[slotIndex]
	if slot.Model then
		slot.Model:Destroy()
		slot.Model = nil
	end
	if not slot.Data or slot.Stolen or not plot.Owner then
		return
	end
	local data = slot.Data :: OwnedMonster
	local model = MonsterModels.Build(data.Id, data.Mutation, {
		IncomeMultiplier = PlotService.IncomeMultiplier(plot.Owner),
	})
	local top = slot.Pedestal.CFrame * CFrame.new(0, slot.Pedestal.Size.Y / 2, 0)
	model:PivotTo(top)
	model.Parent = plot.Parts.Model
	slot.Model = model
	addSlotPrompts(plot, slotIndex, model)
end

-- Places a monster in the player's first free slot. Returns false if full.
function PlotService.AddMonster(player: Player, monster: OwnedMonster): boolean
	local plot = plotOf[player]
	local profile = DataService.Get(player)
	if not plot or not profile then
		return false
	end
	local index = PlotService.FreeSlot(plot)
	if not index then
		return false
	end
	plot.Slots[index].Data = monster
	profile.Slots[tostring(index)] = monster
	renderSlot(plot, index)
	refreshStats(player)
	return true
end

function PlotService.RemoveMonster(plot: Plot, slotIndex: number): OwnedMonster?
	local slot = plot.Slots[slotIndex]
	local data = slot.Data
	slot.Data = nil
	slot.Stolen = false
	renderSlot(plot, slotIndex)
	local owner = plot.Owner
	if owner then
		local profile = DataService.Get(owner)
		if profile then
			profile.Slots[tostring(slotIndex)] = nil
		end
		refreshStats(owner)
	end
	return data
end

-- Hide/show a monster while a thief carries it. Data stays with the owner
-- until the theft succeeds.
function PlotService.SetStolen(plot: Plot, slotIndex: number, stolen: boolean)
	plot.Slots[slotIndex].Stolen = stolen
	renderSlot(plot, slotIndex)
end

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
end

-- The client only shows prompts tagged OwnerOnly to the matching user.
local function setOwnerPrompts(plot: Plot, userId: number)
	for _, part in { plot.Parts.LockButton, plot.Parts.RebirthPillar } do
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:SetAttribute("OwnerOnly", userId)
		end
	end
end

function PlotService.Assign(player: Player): Plot?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local plot: Plot? = nil
	for _, candidate in plots do
		if not candidate.Owner then
			plot = candidate
			break
		end
	end
	if not plot then
		return nil
	end
	local assigned = plot :: Plot
	assigned.Owner = player
	assigned.LockedUntil = 0
	assigned.LockReadyAt = 0
	Loc.Label(assigned.Parts.Sign, "label.base", { player = player.DisplayName })
	setOwnerPrompts(assigned, player.UserId)
	plotOf[player] = assigned
	player:SetAttribute("PlotIndex", assigned.Parts.Index)

	setupLeaderstats(player)
	for key, monster in profile.Slots do
		local index = tonumber(key)
		if index and assigned.Slots[index] then
			assigned.Slots[index].Data = monster
		else
			profile.Slots[key] = nil
		end
	end
	for index in assigned.Slots do
		renderSlot(assigned, index)
	end
	refreshStats(player)
	return assigned
end

function PlotService.Unassign(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	plot.Owner = nil
	plot.LockedUntil = 0
	Loc.Label(plot.Parts.Sign, "label.emptyBase")
	Loc.Clear(plot.PendingLabel)
	Loc.Clear(plot.LockLabel)
	setGate(plot, false)
	setOwnerPrompts(plot, 0)
	for index, slot in plot.Slots do
		slot.Data = nil
		slot.Stolen = false
		renderSlot(plot, index)
	end
end

-- Re-applies multipliers after a game pass is bought mid-session.
function PlotService.Refresh(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	refreshStats(player)
	for index in plot.Slots do
		renderSlot(plot, index)
	end
end

-- Ends a base lock and its cooldown immediately (admin command).
function PlotService.Unlock(player: Player): boolean
	local plot = plotOf[player]
	if not plot then
		return false
	end
	plot.LockedUntil = 0
	plot.LockReadyAt = 0
	return true
end

function PlotService.SpawnCFrame(player: Player): CFrame?
	local plot = plotOf[player]
	return plot and plot.Parts.Spawn
end

local function onCollect(plot: Plot, hit: BasePart)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or player ~= plot.Owner then
		return
	end
	local profile = DataService.Get(player)
	if not profile or profile.PendingCash <= 0 then
		return
	end
	local amount = profile.PendingCash
	profile.PendingCash = 0
	PlotService.AddCash(player, amount)
	PlotService.Notify(player, "n.collected", { amount = Format.Money(amount) }, "cash")
end

local function onLock(plot: Plot, player: Player)
	if player ~= plot.Owner then
		return
	end
	local now = os.clock()
	if now < plot.LockReadyAt then
		PlotService.Notify(player, "n.lockWait", { seconds = math.ceil(plot.LockReadyAt - now) }, "error")
		return
	end
	local superLock = PlotService.HasPass(player, "SuperLock")
	plot.LockedUntil = now + (if superLock then Config.SuperLockDuration else Config.LockDuration)
	plot.LockReadyAt = plot.LockedUntil + (if superLock then Config.SuperLockCooldown else Config.LockCooldown)
	PlotService.Notify(player, "n.locked")
end

local function onRebirth(plot: Plot, player: Player)
	local profile = DataService.Get(player)
	if player ~= plot.Owner or not profile then
		return
	end
	local cost = PlotService.RebirthCost(profile.Rebirths)
	if profile.Cash < cost then
		PlotService.Notify(player, "n.rebirthNeed", { amount = Format.Money(cost) }, "error")
		return
	end
	for _, slot in plot.Slots do
		if slot.Stolen then
			PlotService.Notify(player, "n.rebirthStealing", nil, "error")
			return
		end
	end
	profile.Rebirths += 1
	profile.Cash = Config.StartingCash
	profile.PendingCash = 0
	profile.Slots = {}
	for index, slot in plot.Slots do
		slot.Data = nil
		renderSlot(plot, index)
	end
	refreshStats(player)
	PlotService.Notify(player, "n.rebirthDone", { mult = string.format("%.1f", PlotService.IncomeMultiplier(player)) }, "cash")
end

-- Pushes non-owners out of locked bases.
local function enforceLock(plot: Plot)
	local locked = PlotService.IsLocked(plot)
	setGate(plot, locked)
	local now = os.clock()
	if locked then
		Loc.Label(plot.LockLabel, "label.lockActive", { seconds = math.ceil(plot.LockedUntil - now) })
	elseif now < plot.LockReadyAt then
		Loc.Label(plot.LockLabel, "label.lockReady", { seconds = math.ceil(plot.LockReadyAt - now) })
	else
		Loc.Label(plot.LockLabel, "label.lockIdle")
	end
	if not locked then
		return
	end
	local outside = plot.Parts.Origin * CFrame.new(0, 4, -WorldBuilder.PlotSize() / 2 - 8)
	for _, player in Players:GetPlayers() do
		if player ~= plot.Owner then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and PlotService.IsInside(plot, root.Position) then
				(character :: Model):PivotTo(outside)
			end
		end
	end
end

function PlotService.Init(plotParts: { PlotParts }, notify: RemoteEvent)
	notifyRemote = notify
	for _, parts in plotParts do
		local slots = {}
		for _, pedestal in parts.Pedestals do
			table.insert(slots, { Pedestal = pedestal, Model = nil, Data = nil, Stolen = false })
		end
		local plot: Plot = {
			Parts = parts,
			Owner = nil,
			Slots = slots,
			LockedUntil = 0,
			LockReadyAt = 0,
			GateLowered = false,
			LockLabel = billboardLabel(parts.LockButton, Vector3.new(0, 3, 0), Color3.fromRGB(255, 120, 120)),
			PendingLabel = billboardLabel(parts.CollectPad, Vector3.new(0, 3, 0), Color3.fromRGB(120, 255, 140)),
			RebirthLabel = billboardLabel(parts.RebirthPillar, Vector3.new(0, 5, 0), Color3.fromRGB(255, 220, 80)),
		}
		table.insert(plots, plot)

		parts.CollectPad.Touched:Connect(function(hit)
			onCollect(plot, hit)
		end)
		local lockPrompt = parts.LockButton:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
		lockPrompt.Triggered:Connect(function(player)
			onLock(plot, player)
		end)
		local rebirthPrompt = parts.RebirthPillar:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
		rebirthPrompt.Triggered:Connect(function(player)
			onRebirth(plot, player)
		end)
	end
end

function PlotService.Start()
	-- Passive income goes into the base's pending pile; walk on the pad to collect.
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTick)
			for player, plot in plotOf do
				local profile = DataService.Get(player)
				if profile then
					local income = (player:GetAttribute("Income") :: number?) or 0
					profile.PendingCash += income * Config.IncomeTick
					if PlotService.HasPass(player, "AutoCollect") then
						PlotService.AddCash(player, profile.PendingCash)
						profile.PendingCash = 0
						Loc.Label(plot.PendingLabel, "label.autoCollect")
					else
						Loc.Label(plot.PendingLabel, "label.collect", { amount = Format.Money(profile.PendingCash) })
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, plot in plots do
				if plot.Owner then
					enforceLock(plot)
				end
			end
		end
	end)
end

return PlotService
