--!strict
-- Stealing: a thief picks up a monster from another base and must carry it
-- back into their own base. The monster returns home if the thief dies,
-- leaves, times out, or the owner catches them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MonsterModels = require(script.Parent.MonsterModels)
local PlotService = require(script.Parent.PlotService)

type Plot = PlotService.Plot

type Carry = {
	Thief: Player,
	Victim: Player,
	Plot: Plot,
	SlotIndex: number,
	MonsterId: string,
	Mutation: string,
	Model: Model,
	StartedAt: number,
	PreviousSpeed: number,
}

local StealService = {}

local carries: { [Player]: Carry } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function endCarry(carry: Carry, success: boolean, reason: string?)
	if carries[carry.Thief] ~= carry then
		return
	end
	carries[carry.Thief] = nil
	carry.Model:Destroy()
	carry.Thief:SetAttribute("Carrying", nil)
	local humanoid = humanoidOf(carry.Thief)
	if humanoid then
		humanoid.WalkSpeed = carry.PreviousSpeed
	end

	local slot = carry.Plot.Slots[carry.SlotIndex]
	local stillValid = carry.Plot.Owner == carry.Victim
		and slot.Data ~= nil
		and slot.Stolen
		and (slot.Data :: any).Id == carry.MonsterId

	if not stillValid then
		return
	end

	if success then
		local data = PlotService.RemoveMonster(carry.Plot, carry.SlotIndex)
		if data and PlotService.AddMonster(carry.Thief, data) then
			PlotService.Notify(carry.Thief, "You stole " .. carry.MonsterId .. "!", "cash")
			PlotService.Notify(carry.Victim, carry.Thief.DisplayName .. " stole your " .. carry.MonsterId .. "!", "error")
			return
		end
		-- Thief's base filled up in the meantime: give it back.
		if data then
			PlotService.AddMonster(carry.Victim, data)
		end
		PlotService.Notify(carry.Thief, "Your base is full!", "error")
		return
	end

	PlotService.SetStolen(carry.Plot, carry.SlotIndex, false)
	if reason then
		PlotService.Notify(carry.Thief, reason, "error")
		PlotService.Notify(carry.Victim, "You got your " .. carry.MonsterId .. " back!", "info")
	end
end

local function tryStart(thief: Player, plot: Plot, slotIndex: number)
	local victim = plot.Owner
	local slot = plot.Slots[slotIndex]
	if not victim or victim == thief or carries[thief] or not slot or not slot.Data or slot.Stolen then
		return
	end
	if PlotService.IsLocked(plot) then
		return
	end
	local thiefPlot = PlotService.GetPlot(thief)
	if not thiefPlot or not PlotService.FreeSlot(thiefPlot) then
		PlotService.Notify(thief, "Your base is full!", "error")
		return
	end
	local root = rootOf(thief)
	local humanoid = humanoidOf(thief)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (root.Position - slot.Pedestal.Position).Magnitude > Config.StealDistance then
		return
	end

	local data = slot.Data
	PlotService.SetStolen(plot, slotIndex, true)

	local model = MonsterModels.BuildCarry(data.Id, data.Mutation)
	local modelRoot = model.PrimaryPart :: BasePart
	model:PivotTo(root.CFrame * CFrame.new(0, 3, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = modelRoot
	weld.Parent = modelRoot
	model.Parent = thief.Character

	local carry: Carry = {
		Thief = thief,
		Victim = victim,
		Plot = plot,
		SlotIndex = slotIndex,
		MonsterId = data.Id,
		Mutation = data.Mutation,
		Model = model,
		StartedAt = os.clock(),
		PreviousSpeed = humanoid.WalkSpeed,
	}
	carries[thief] = carry
	humanoid.WalkSpeed = Config.CarryWalkSpeed
	thief:SetAttribute("Carrying", data.Id)
	PlotService.Notify(thief, "Run back to your base!", "info")
	PlotService.Notify(victim, thief.DisplayName .. " is stealing your " .. data.Id .. "! Catch them!", "error")

	humanoid.Died:Once(function()
		endCarry(carry, false, "You dropped it!")
	end)
end

-- Cancels any theft involving this player (as thief or victim).
function StealService.CancelFor(player: Player)
	for _, carry in carries do
		if carry.Thief == player or carry.Victim == player then
			endCarry(carry, false, nil)
		end
	end
end

function StealService.Start()
	PlotService.StealHandler = tryStart

	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, carry in carries do
				local thiefRoot = rootOf(carry.Thief)
				if not thiefRoot or not carry.Model.Parent then
					endCarry(carry, false, "You dropped it!")
					continue
				end
				local thiefPlot = PlotService.GetPlot(carry.Thief)
				if thiefPlot and PlotService.IsInside(thiefPlot, thiefRoot.Position) then
					endCarry(carry, true)
					continue
				end
				if os.clock() - carry.StartedAt > Config.CarryTimeout then
					endCarry(carry, false, "Too slow! It ran home.")
					continue
				end
				local victimRoot = rootOf(carry.Victim)
				if victimRoot and (victimRoot.Position - thiefRoot.Position).Magnitude <= Config.CatchDistance then
					endCarry(carry, false, "Caught by " .. carry.Victim.DisplayName .. "!")
				end
			end
		end
	end)
end

return StealService
