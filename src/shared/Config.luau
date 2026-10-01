--!strict
-- Tunable gameplay constants. Everything balance-related lives here.

local Config = {
	StartingCash = 100,
	SlotsPerPlot = 10,
	MaxPlots = 8,

	-- Conveyor
	ConveyorLength = 240,
	ConveyorSpeed = 8, -- studs per second
	SpawnInterval = 3, -- seconds between monsters on the belt
	BuyDistance = 14,

	-- Income
	IncomeTick = 1, -- seconds
	SellRefund = 0.5, -- fraction of buy price returned when selling

	-- Stealing
	StealDistance = 12,
	StealHoldDuration = 1.5,
	CarryWalkSpeed = 12,
	CarryTimeout = 60, -- seconds before a carried monster snaps back home
	CatchDistance = 6, -- owner this close to the thief recovers the monster

	-- Base lock
	LockDuration = 60,
	LockCooldown = 30, -- after the lock expires

	-- Rebirth
	RebirthBaseCost = 1_000_000,
	RebirthCostGrowth = 2.5,
	RebirthIncomeBonus = 0.5, -- +50% income per rebirth

	-- Data
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120,
}

return Config
